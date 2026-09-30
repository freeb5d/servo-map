package com.servomap.android

import android.app.Activity
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

enum class AccountStatus { SignedOut, SigningIn, SignedIn, Failed }

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
    val alerts: AlertSettings = AlertSettings(),
    val account: AccountDto? = null,
    val accountStatus: AccountStatus = AccountStatus.SignedOut,
    val accountMessage: String? = null,
    val lastSynced: Long? = null,
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
            fillUps = store.fillUps(), car = store.car(), alerts = store.alerts(),
            centre = store.lastCentre() ?: UiState.SYDNEY,
        ),
    )
    private val tokens = TokenStore(app)
    val state: StateFlow<UiState> = _state.asStateFlow()
    private var job: Job? = null

    init {
        val account = store.account()
        if (account != null && tokens.read() != null) update { it.copy(account = account, accountStatus = AccountStatus.SignedIn) }
        reload()
        loadSaved()
        refreshAccount()
    }

    private fun update(f: (UiState) -> UiState) { _state.value = f(_state.value) }

    fun setFuel(fuel: Fuel) { update { it.copy(fuel = fuel) }; reload(); loadSaved() }

    fun setCentre(lat: Double, lng: Double) {
        store.saveLastCentre(lat, lng)
        update { it.copy(centre = lat to lng, query = "") }
        reload()
    }

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
        attempt { AccountApi.putSaved(it, ids.toList()) }
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
        attempt { AccountApi.putFillUps(it, listOf(entry.toDto())) }
    }

    fun deleteFillUp(id: String) {
        val log = _state.value.fillUps.filter { it.id != id }
        store.saveFillUps(log)
        update { it.copy(fillUps = log) }
        attempt { AccountApi.deleteFillUp(it, id) }
    }

    fun saveCar(car: Car) {
        store.saveCar(car)
        update { it.copy(car = car) }
        attempt { AccountApi.putCar(it, car.toDto()) }
    }

    fun updateAlerts(change: (AlertSettings) -> AlertSettings) {
        val new = change(_state.value.alerts)
        store.saveAlerts(new)
        update { it.copy(alerts = new) }
        attempt { AccountApi.putAlerts(it, new.toDto()) }
    }

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

    // Account and sync are optional; without an account everything stays on the device.

    fun signInWithGoogle(activity: Activity) {
        if (_state.value.accountStatus == AccountStatus.SigningIn) return
        update { it.copy(accountStatus = AccountStatus.SigningIn, accountMessage = null) }
        viewModelScope.launch {
            try {
                val (idToken, name) = GoogleSignIn.idToken(activity)
                val session = AccountApi.signIn("google", idToken, name)
                tokens.save(session.token)
                store.saveAccount(session.account)
                update { it.copy(account = session.account, accountStatus = AccountStatus.SignedIn) }
                pull(session.token, pushLocal = true)
            } catch (e: CancellationException) {
                throw e
            } catch (e: GoogleSignIn.Cancelled) {
                update { it.copy(accountStatus = if (it.account == null) AccountStatus.SignedOut else AccountStatus.SignedIn) }
            } catch (e: ApiFailure) {
                val message = when (e.code) {
                    0 -> "Could not reach ServoMap to sign in. Check your connection."
                    503 -> "Accounts are not switched on for ServoMap yet. Everything still works on this device."
                    else -> "ServoMap could not verify that sign-in. Try again."
                }
                update { it.copy(accountStatus = AccountStatus.Failed, accountMessage = message) }
            } catch (e: Exception) {
                update { it.copy(accountStatus = AccountStatus.Failed, accountMessage = "Google sign-in did not finish. Try again.") }
            }
        }
    }

    fun signOut() {
        tokens.clear()
        store.saveAccount(null)
        update { it.copy(account = null, accountStatus = AccountStatus.SignedOut, accountMessage = null, lastSynced = null) }
    }

    /** Deletes the account and everything stored with it on the server; this device keeps its copy. */
    fun deleteAccount() {
        val token = tokens.read() ?: return
        viewModelScope.launch {
            try {
                AccountApi.deleteAccount(token)
                signOut()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                update { it.copy(accountMessage = "Could not delete the account. Check your connection and try again.") }
            }
        }
    }

    /** Opening the app or tapping Sync now: take what other devices added. */
    fun refreshAccount() {
        val token = tokens.read() ?: return
        viewModelScope.launch { guarded { pull(token, pushLocal = false) } }
    }

    private suspend fun pull(token: String, pushLocal: Boolean) {
        val me = AccountApi.me(token)
        store.saveAccount(me.account)
        val local = _state.value
        val ids = (local.savedIds.toList() + me.savedStationIds).distinct().toSet()
        val byId = (local.fillUps + me.fillUps.mapNotNull { it.toFillUp() }).associateBy { it.id }
        val log = byId.values.sortedByDescending { it.epochMs }
        val car = me.car?.toCar()?.takeIf { !pushLocal || local.car.isDefault } ?: local.car
        val alerts = me.alerts.applyTo(local.alerts)
        store.saveSavedIds(ids)
        store.saveFillUps(log)
        store.saveCar(car)
        store.saveAlerts(alerts)
        update {
            it.copy(
                account = me.account, savedIds = ids, fillUps = log, car = car, alerts = alerts,
                accountStatus = AccountStatus.SignedIn, lastSynced = System.currentTimeMillis(),
            )
        }
        loadSaved()
        if (pushLocal) {
            AccountApi.putSaved(token, ids.toList())
            val remote = me.fillUps.map { it.id }.toSet()
            AccountApi.putFillUps(token, log.filter { it.id !in remote }.map { it.toDto() })
            if (!car.isDefault) AccountApi.putCar(token, car.toDto())
            AccountApi.putAlerts(token, alerts.toDto())
        }
    }

    /** Pushes one change to the account when signed in; offline failures are dropped, the next launch reconciles. */
    private fun attempt(work: suspend (String) -> Unit) {
        val token = tokens.read() ?: return
        viewModelScope.launch {
            guarded {
                work(token)
                update { it.copy(lastSynced = System.currentTimeMillis()) }
            }
        }
    }

    private suspend fun guarded(block: suspend () -> Unit) {
        try {
            block()
        } catch (e: CancellationException) {
            throw e
        } catch (e: ApiFailure) {
            if (e.code == 401) signOut()
        } catch (e: Exception) {
            // Offline: keep working locally.
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
