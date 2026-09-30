package com.servomap.android

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun FuelChips(selected: Fuel, onSelect: (Fuel) -> Unit, modifier: Modifier = Modifier) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = modifier) {
        items(Fuel.entries) { f ->
            FilterChip(selected = f == selected, onClick = { onSelect(f) }, label = { Text(f.code) })
        }
    }
}

@Composable
fun <T> ChoiceChips(choices: List<Pair<String, T>>, selected: T, onSelect: (T) -> Unit) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        items(choices) { (label, value) ->
            FilterChip(selected = value == selected, onClick = { onSelect(value) }, label = { Text(label) })
        }
    }
}

@Composable
fun Heading(text: String, modifier: Modifier = Modifier) {
    Text(text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier.padding(start = 16.dp, end = 16.dp, top = 20.dp, bottom = 6.dp))
}

@Composable
fun Note(text: String, modifier: Modifier = Modifier) {
    Text(text, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = modifier.padding(horizontal = 16.dp, vertical = 4.dp))
}

@Composable
fun StationRow(s: Station, fuel: Fuel, tier: Tier?, onClick: () -> Unit) {
    val dark = LocalDark.current
    val p = s.price(fuel)
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(s.name, fontWeight = FontWeight.Medium)
            Text(
                listOfNotNull(s.brand, s.suburb, s.distance?.let { "%.1f km".format(it) }).joinToString(" · "),
                fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(p?.let { "%.1f".format(it.price) } ?: "—", fontSize = 20.sp, fontWeight = FontWeight.SemiBold, color = tierColor(tier, dark))
    }
    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.4f))
}

@Composable
fun StationList(stations: List<Station>, ui: UiState, onSelect: (Station) -> Unit) {
    LazyColumn(Modifier.fillMaxSize()) {
        items(stations, key = { it.id }) { s -> StationRow(s, ui.fuel, ui.tiers[s.id]) { onSelect(s) } }
    }
}

@Composable
fun StationDetail(
    s: Station, fuel: Fuel, tier: Tier?, saved: Boolean,
    onToggleSaved: () -> Unit, onLogFillUp: () -> Unit, showDirections: Boolean = true, onDirections: () -> Unit,
) {
    val dark = LocalDark.current
    Column(Modifier.padding(horizontal = 24.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(s.name, fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
        Text("${s.address}, ${s.suburb} ${s.state.uppercase()} ${s.postcode}", color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(8.dp))
        s.prices.sortedBy { it.fuel }.forEach { p ->
            val chosen = p.fuel == fuel.code
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(p.fuel, fontWeight = if (chosen) FontWeight.Bold else FontWeight.Normal)
                Text("%.1f ¢/L".format(p.price), color = if (chosen) tierColor(tier, dark) else MaterialTheme.colorScheme.onSurface)
            }
        }
        DataSources.all[s.state.lowercase()]?.let { Note("Prices via ${it.name}", Modifier.padding(horizontal = 0.dp)) }
        Spacer(Modifier.height(12.dp))
        if (showDirections) Button(onClick = onDirections, modifier = Modifier.fillMaxWidth()) { Text("Directions") }
        OutlinedButton(onClick = onLogFillUp, modifier = Modifier.fillMaxWidth()) { Text("Log a fill-up") }
        OutlinedButton(onClick = onToggleSaved, modifier = Modifier.fillMaxWidth()) { Text(if (saved) "★ Saved" else "☆ Save") }
    }
}

/** Min-to-max band behind the average line; a missing day breaks the line so it never bridges a gap. */
@Composable
fun LineChart(series: List<Snapshot>, modifier: Modifier = Modifier) {
    val line = MaterialTheme.colorScheme.onSurface
    val band = MaterialTheme.colorScheme.surfaceVariant
    Canvas(modifier.fillMaxWidth().height(160.dp)) {
        if (series.size < 2) return@Canvas
        val lo = series.minOf { it.min }
        val span = (series.maxOf { it.max } - lo).coerceAtLeast(0.1)
        val days = series.map { TrendMath.day(it.date)?.toEpochDay() ?: 0L }
        val d0 = days.first()
        val dspan = (days.last() - d0).coerceAtLeast(1L)
        fun x(i: Int) = (days[i] - d0).toFloat() / dspan * size.width
        fun y(v: Double) = size.height - ((v - lo) / span).toFloat() * size.height
        for (run in TrendMath.runs(series)) {
            if (run.size < 2) {
                drawCircle(line, 3.dp.toPx(), Offset(x(run[0]), y(series[run[0]].avg)))
                continue
            }
            val area = Path().apply {
                moveTo(x(run.first()), y(series[run.first()].max))
                run.forEach { lineTo(x(it), y(series[it].max)) }
                run.reversed().forEach { lineTo(x(it), y(series[it].min)) }
                close()
            }
            drawPath(area, band)
            val avg = Path().apply {
                moveTo(x(run.first()), y(series[run.first()].avg))
                run.drop(1).forEach { lineTo(x(it), y(series[it].avg)) }
            }
            drawPath(avg, line, style = Stroke(width = 2.dp.toPx()))
        }
    }
}

/** A row of labelled columns; the cheapest is drawn in the cheap colour. Heights use the value range, not zero. */
@Composable
fun Bars(values: List<Pair<String, Double?>>, cheapestIsLowest: Boolean = true, format: (Double) -> String = { "%.1f".format(it) }) {
    val dark = LocalDark.current
    val present = values.mapNotNull { it.second }
    val lo = present.minOrNull() ?: 0.0
    val hi = present.maxOrNull() ?: 0.0
    val best = if (cheapestIsLowest) lo else hi
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        values.forEach { (label, v) ->
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Box(Modifier.height(90.dp).fillMaxWidth(), contentAlignment = Alignment.BottomCenter) {
                    if (v != null) {
                        val fraction = if (hi > lo) 0.25f + 0.75f * ((v - lo) / (hi - lo)).toFloat() else 0.6f
                        Box(
                            Modifier.fillMaxWidth().fillMaxHeight(fraction).background(
                                if (v == best) tierColor(Tier.Cheap, dark) else MaterialTheme.colorScheme.surfaceVariant,
                            ),
                        )
                    }
                }
                Text(label, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(v?.let(format) ?: "–", fontSize = 11.sp)
            }
        }
    }
}
