package com.servomap.android

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class UiState(
    val fuel: Fuel = Fuel.U91,
    val stations: List<Station> = emptyList(),
    val tiers: Map<String, Tier> = emptyMap(),
    val loading: Boolean = false,
    val error: String? = null,
    val selected: Station? = null,
    val centre: Pair<Double, Double> = SYDNEY,
    val query: String = "",
) {
    companion object {
        val SYDNEY = -33.8688 to 151.2093
    }
}

class MainViewModel : ViewModel() {
    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()
    private var job: Job? = null

    init { reload() }

    fun setFuel(fuel: Fuel) { _state.value = _state.value.copy(fuel = fuel); reload() }

    fun setCentre(lat: Double, lng: Double) { _state.value = _state.value.copy(centre = lat to lng, query = ""); reload() }

    fun select(station: Station?) { _state.value = _state.value.copy(selected = station) }

    /** An empty query goes back to nearby stations. */
    fun search(text: String) { _state.value = _state.value.copy(query = text.trim()); reload() }

    private fun reload() {
        job?.cancel()
        val s = _state.value
        _state.value = s.copy(loading = true, error = null)
        job = viewModelScope.launch {
            try {
                val list = if (s.query.isNotEmpty()) Api.search(s.query, s.fuel)
                else Api.nearby(s.fuel, s.centre.first, s.centre.second, radiusKm = 10)
                val first = list.firstOrNull()
                _state.value = _state.value.copy(
                    stations = list, tiers = tiers(list, s.fuel), loading = false, selected = null,
                    centre = if (s.query.isNotEmpty() && first != null) first.lat to first.lng else _state.value.centre,
                )
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.value = _state.value.copy(loading = false, error = e.message ?: "Could not load prices")
            }
        }
    }
}
