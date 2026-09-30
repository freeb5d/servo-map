package com.servomap.android

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Price history by state, today's city comparison, and the best weekday to fill, for the chosen fuel. */
@Composable
fun TrendsScreen(ui: UiState, vm: MainViewModel) {
    LaunchedEffect(Unit) { vm.loadTrends() }
    LaunchedEffect(ui.fuel) { vm.loadCities(ui.fuel) }
    val dark = LocalDark.current
    var picked by rememberSaveable { mutableStateOf<String?>(null) }
    var rangeDays by rememberSaveable { mutableStateOf(30) }

    val byState = ui.series.mapValues { (_, all) -> all.filter { it.fuel == ui.fuel.code }.sortedBy { it.date } }
        .filterValues { it.isNotEmpty() }
    val ordered = byState.entries.sortedBy { it.value.last().avg }
    val current = picked?.takeIf { it in byState } ?: ordered.firstOrNull()?.key
    val cities = CityFacts.ranked(ui.cities[ui.fuel.code].orEmpty())

    LazyColumn(Modifier.fillMaxSize().statusBarsPadding()) {
        item {
            Text("Trends", fontSize = 28.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(16.dp))
            FuelChips(ui.fuel, vm::setFuel, Modifier.padding(horizontal = 16.dp))
            if (ui.trendsLoading) LinearProgressIndicator(Modifier.fillMaxWidth().padding(top = 8.dp))
            if (ui.trendsError) Note("Couldn't load price history. Pull up the tab again to retry.")
        }
        item { Heading("STATES · AVERAGE ¢/L, CHEAPEST FIRST") }
        items(ordered, key = { it.key }) { (state, series) ->
            val latest = series.last()
            val week = TrendMath.change(series, 7)
            Row(
                Modifier.fillMaxWidth().clickable { picked = state }.padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(state.uppercase() + if (state == current) "  ●" else "", fontWeight = FontWeight.Medium)
                    Text("${latest.stationCount} stations", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                if (week != null) {
                    Text(
                        (if (week > 0) "▲ " else if (week < 0) "▼ " else "") + "%.1f".format(kotlin.math.abs(week)) + " wk",
                        fontSize = 13.sp,
                        color = tierColor(if (week > 0.05) Tier.Expensive else if (week < -0.05) Tier.Cheap else null, dark),
                        modifier = Modifier.padding(end = 12.dp),
                    )
                }
                Text("%.1f".format(latest.avg), fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
            }
            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.4f))
        }
        if (current != null) {
            val full = byState.getValue(current)
            val shown = TrendMath.window(full, rangeDays.takeIf { it > 0 })
            item {
                Heading("${current.uppercase()} · ${ui.fuel.code}")
                ChoiceChipsRow(rangeDays) { rangeDays = it }
                LineChart(shown, Modifier.padding(16.dp))
                TrendMath.verdict(shown)?.let { Note(it) }
                Note("Line is the daily average; the band runs from the cheapest to the dearest station.")
            }
            item {
                Heading("BEST DAY TO FILL · ${current.uppercase()} AVERAGE BY WEEKDAY")
                Bars(TrendMath.weekdays(full))
                val days = TrendMath.weekdays(full)
                val cheapest = days.filter { it.second != null }.minByOrNull { it.second!! }
                if (cheapest != null) Note("${cheapest.first} has been the cheapest day on average.")
            }
        }
        item {
            Heading("CITIES · ${ui.fuel.code} TODAY")
            CityFacts.cheapestFact(cities)?.let { Note(it) }
        }
        items(cities, key = { it.id }) { c ->
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(c.name, fontWeight = FontWeight.Medium)
                    Text("${c.stationCount} stations · ${c.state.uppercase()}", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Text("%.1f".format(c.average ?: 0.0), fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
            }
            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.4f))
        }
        item { Note("City figures use prices reported in the last 7 days, within each city's radius of its centre.", Modifier.padding(bottom = 24.dp)) }
    }
}

@Composable
private fun ChoiceChipsRow(selected: Int, onSelect: (Int) -> Unit) {
    Column(Modifier.padding(horizontal = 16.dp)) {
        ChoiceChips(listOf("30 days" to 30, "90 days" to 90, "All" to 0), selected, onSelect)
    }
}
