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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Directions
import androidx.compose.material.icons.filled.LocalGasStation
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow

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
    Column {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BrandMark(s.brand, 40.dp)
        Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
            Text(s.name, fontWeight = FontWeight.Medium, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(
                listOfNotNull(s.suburb, s.distance?.let { "%.1f km".format(it) }, p?.let { ago(it.updatedAt) }).joinToString(" · "),
                fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(p?.let { "%.1f".format(it.price) } ?: "—", fontFamily = Display, fontSize = 22.sp, fontWeight = FontWeight.SemiBold, color = tierColor(tier, dark))
            Text("¢/L", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
    HorizontalDivider(Modifier.padding(start = 68.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.4f))
    }
}

/** "Updated 3 h ago"-style age of a report; empty when the timestamp can't be read. */
fun ago(updatedAt: String, now: java.time.Instant = java.time.Instant.now()): String {
    val t = runCatching { java.time.Instant.parse(updatedAt) }.getOrNull() ?: return ""
    val minutes = (now.epochSecond - t.epochSecond) / 60
    return when {
        minutes < 1 -> "just now"
        minutes < 60 -> "${minutes} min ago"
        minutes < 48 * 60 -> "${minutes / 60} h ago"
        else -> "${minutes / (24 * 60)} days ago"
    }
}

/** Greyed rows shown while the first fetch is in flight, so the list doesn't jump when prices arrive. */
@Composable
fun ListSkeleton() {
    val grey = MaterialTheme.colorScheme.surfaceVariant
    Column(Modifier.fillMaxSize()) {
        repeat(8) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(40.dp).clip(RoundedCornerShape(10.dp)).background(grey))
                Column(Modifier.weight(1f).padding(horizontal = 12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(Modifier.fillMaxWidth(0.55f).height(14.dp).clip(RoundedCornerShape(4.dp)).background(grey))
                    Box(Modifier.fillMaxWidth(0.35f).height(11.dp).clip(RoundedCornerShape(4.dp)).background(grey))
                }
                Box(Modifier.width(56.dp).height(20.dp).clip(RoundedCornerShape(4.dp)).background(grey))
            }
        }
    }
}

@Composable
fun ScreenTitle(text: String, modifier: Modifier = Modifier) {
    Text(text, style = MaterialTheme.typography.headlineMedium, modifier = modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 8.dp))
}

/** The cheapest station in view, riding over the map like the iPhone app's bottom accessory. */
@Composable
fun CheapestCard(station: Station, fuel: Fuel, tier: Tier?, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val dark = LocalDark.current
    val price = station.price(fuel) ?: return
    Surface(
        modifier = modifier.fillMaxWidth().padding(12.dp).clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp), tonalElevation = 3.dp, shadowElevation = 6.dp,
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            BrandMark(station.brand, 40.dp)
            Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                Text("Cheapest ${fuel.code} in view", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(station.name, fontWeight = FontWeight.Medium, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Text("%.1f".format(price.price), fontFamily = Display, fontSize = 26.sp, fontWeight = FontWeight.SemiBold, color = tierColor(tier ?: Tier.Cheap, dark))
        }
    }
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
    val main = s.price(fuel)
    Column(
        Modifier.padding(horizontal = 24.dp).padding(bottom = 32.dp).verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            BrandMark(s.brand, 48.dp)
            Column(Modifier.weight(1f).padding(start = 12.dp)) {
                Text(s.name, style = MaterialTheme.typography.titleLarge)
                Text("${s.address}, ${s.suburb} ${s.state.uppercase()} ${s.postcode}", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            IconButton(onClick = onToggleSaved) {
                Icon(if (saved) Icons.Filled.Star else Icons.Outlined.StarBorder, contentDescription = if (saved) "Saved" else "Save")
            }
        }
        if (main != null) {
            Row(verticalAlignment = Alignment.Bottom, modifier = Modifier.padding(top = 12.dp)) {
                Text("%.1f".format(main.price), fontFamily = Display, fontSize = 48.sp, fontWeight = FontWeight.SemiBold, color = tierColor(tier, dark))
                Text(" ¢/L  ${fuel.code}", fontSize = 15.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(bottom = 8.dp))
            }
            Text(
                listOfNotNull(
                    when (tier) { Tier.Cheap -> "Among the cheapest nearby"; Tier.Expensive -> "Among the dearest nearby"; else -> null },
                    "Updated ${ago(main.updatedAt)}".takeIf { ago(main.updatedAt).isNotEmpty() },
                ).joinToString(" · "),
                fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(Modifier.height(8.dp))
        s.prices.sortedBy { it.fuel }.forEach { p ->
            val chosen = p.fuel == fuel.code
            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(p.fuel, fontWeight = if (chosen) FontWeight.Bold else FontWeight.Normal)
                Text("%.1f ¢/L".format(p.price), fontFamily = Display, color = if (chosen) tierColor(tier, dark) else MaterialTheme.colorScheme.onSurface)
            }
            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
        }
        DataSources.all[s.state.lowercase()]?.let { Text("Prices via ${it.name}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp)) }
        Spacer(Modifier.height(12.dp))
        if (showDirections) Button(onClick = onDirections, modifier = Modifier.fillMaxWidth()) {
            Icon(Icons.Filled.Directions, null, Modifier.size(18.dp)); Text("  Directions")
        }
        OutlinedButton(onClick = onLogFillUp, modifier = Modifier.fillMaxWidth()) {
            Icon(Icons.Filled.LocalGasStation, null, Modifier.size(18.dp)); Text("  Log a fill-up")
        }
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

/** One lazy item holding several stacked children; without the Column they would draw on top of each other. */
fun androidx.compose.foundation.lazy.LazyListScope.sectionItem(content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    item { Column(Modifier.fillMaxWidth(), content = content) }
}
