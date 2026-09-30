package com.servomap.android

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

data class UiState(
    val fuel: Fuel = Fuel.U91,
    val stations: List<Station> = emptyList(),
    val tiers: Map<String, Tier> = emptyMap(),
    val loading: Boolean = false,
    val error: String? = null,
    val selected: Station? = null,
    val centre: Pair<Double, Double> = SYDNEY,
    val query: String = "",
    val savedIds: Set<String> = emptySet(),
    val saved: List<Station> = emptyList(),
    val settings: Settings = Settings(),
    val filters: Filters = Filters(),
    val fillUps: List<FillUp> = emptyList(),
    val car: Car = Car(),
    /** state code (lower case) to its daily series, every fuel. */
    val series: Map<String, List<Snapshot>> = emptyMap(),
    /** fuel code to that fuel's city figures. */
    val cities: Map<String, List<CityInsight>> = emptyMap(),
    val trendsLoading: Boolean = false,
    val trendsError: Boolean = false,
) {
    /** The loaded stations that pass the filters. */
    val visible: List<Station> get() = filters.apply(stations, fuel)

    /** Average of the current prices for [fuel] across the loaded stations, or null with none. */
    fun areaAverage(fuel: Fuel): Double? =
        stations.filter { it.hasCurrentPrice(fuel) }.map { it.price(fuel)!!.price }.average().takeIf { !it.isNaN() }

    companion object {
        val SYDNEY = -33.8688 to 151.2093
    }
}

class MainViewModel(app: Application) : AndroidViewModel(app) {
    private val store = Store(app)
    private val initial = store.settings()
    private val _state = MutableStateFlow(
        UiState(
            fuel = Fuel.fromCode(initial.fuel), settings = initial, savedIds = store.savedIds(),
            fillUps = store.fillUps(), car = store.car(),
        ),
    )
    val state: StateFlow<UiState> = _state.asStateFlow()
    private var job: Job? = null

    init {
        reload()
        loadSaved()
    }

    private fun update(f: (UiState) -> UiState) { _state.value = f(_state.value) }

    fun setFuel(fuel: Fuel) { update { it.copy(fuel = fuel) }; reload(); loadSaved() }

    fun setCentre(lat: Double, lng: Double) { update { it.copy(centre = lat to lng, query = "") }; reload() }

    fun select(station: Station?) { update { it.copy(selected = station) } }

    /** An empty query goes back to nearby stations. */
    fun search(text: String) { update { it.copy(query = text.trim()) }; reload() }

    fun setFilters(filters: Filters) { update { it.copy(filters = filters) } }

    fun updateSettings(change: (Settings) -> Settings) {
        val old = _state.value.settings
        val new = change(old)
        store.saveSettings(new)
        update { it.copy(settings = new) }
        if (new.compareKm != old.compareKm) reload()
    }

    fun toggleSaved(id: String) {
        val ids = _state.value.savedIds.let { if (id in it) it - id else it + id }
        store.saveSavedIds(ids)
        update { it.copy(savedIds = ids, saved = it.saved.filter { s -> s.id in ids }) }
        loadSaved()
    }

    /** Fetches the current prices of every saved station; one that fails to load is left out. */
    fun loadSaved() {
        val ids = _state.value.savedIds
        viewModelScope.launch {
            val loaded = ids.mapNotNull { id ->
                try { Api.station(id) } catch (e: CancellationException) { throw e } catch (e: Exception) { null }
            }.sortedBy { it.price(_state.value.fuel)?.price ?: Double.MAX_VALUE }
            update { it.copy(saved = loaded.filter { s -> s.id in it.savedIds }) }
        }
    }

    fun addFillUp(station: Station, fuel: Fuel, litres: Double, centsPerLitre: Double) {
        val entry = FillUp(
            id = UUID.randomUUID().toString(), epochMs = System.currentTimeMillis(), stationId = station.id,
            stationName = station.name, brand = station.brand, fuel = fuel.code, litres = litres,
            centsPerLitre = centsPerLitre, areaAverage = _state.value.areaAverage(fuel),
        )
        val log = (_state.value.fillUps + entry).sortedByDescending { it.epochMs }
        store.saveFillUps(log)
        update { it.copy(fillUps = log) }
    }

    fun deleteFillUp(id: String) {
        val log = _state.value.fillUps.filter { it.id != id }
        store.saveFillUps(log)
        update { it.copy(fillUps = log) }
    }

    fun saveCar(car: Car) { store.saveCar(car); update { it.copy(car = car) } }

    /** Loads every live state's history at once; a state that fails keeps what was loaded before. */
    fun loadTrends() {
        if (_state.value.trendsLoading) return
        update { it.copy(trendsLoading = true, trendsError = false) }
        viewModelScope.launch {
            val states = try { Api.liveStates() } catch (e: CancellationException) { throw e } catch (e: Exception) { emptyList() }
                .ifEmpty { listOf("nsw", "wa", "act", "tas") }
            val results = states.map { st ->
                async { st to try { Api.trends(st) } catch (e: CancellationException) { throw e } catch (e: Exception) { null } }
            }.awaitAll()
            val loaded = results.mapNotNull { (st, series) -> series?.let { st to it } }.toMap()
            update { it.copy(series = it.series + loaded, trendsLoading = false, trendsError = loaded.isEmpty() && it.series.isEmpty()) }
        }
    }

    /** Today's city figures for a fuel; an earlier answer stays on screen if the fetch fails. */
    fun loadCities(fuel: Fuel) {
        viewModelScope.launch {
            try {
                val list = Api.cityInsights(fuel)
                update { it.copy(cities = it.cities + (fuel.code to list)) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // keep whatever is on screen
            }
        }
    }

    private fun reload() {
        job?.cancel()
        val s = _state.value
        update { it.copy(loading = true, error = null) }
        job = viewModelScope.launch {
            try {
                val list = if (s.query.isNotEmpty()) Api.search(s.query, s.fuel)
                else Api.nearby(s.fuel, s.centre.first, s.centre.second, radiusKm = s.settings.compareKm)
                val first = list.firstOrNull()
                update {
                    it.copy(
                        stations = list, tiers = tiers(list, s.fuel), loading = false, selected = null,
                        centre = if (s.query.isNotEmpty() && first != null) first.lat to first.lng else it.centre,
                    )
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                update { it.copy(loading = false, error = e.message ?: "Could not load prices") }
            }
        }
    }
}
