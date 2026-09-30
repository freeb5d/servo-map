package com.servomap.android

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.DateFormat
import java.time.YearMonth
import java.util.Date

/** Everything that is the user's own: saved stations, their car and the fill-up log. */
@Composable
fun YouScreen(ui: UiState, vm: MainViewModel, onSelect: (Station) -> Unit) {
    val context = LocalContext.current
    var editCar by remember { mutableStateOf(false) }
    var picking by remember { mutableStateOf(false) }
    var logFor by remember { mutableStateOf<Station?>(null) }
    val now = YearMonth.now()
    val month = LogMath.monthSummary(ui.fillUps, now)
    val habits = LogMath.habits(ui.fillUps)
    val fuel = Fuel.fromCode(ui.car.fuel)
    val cheapest = ui.stations.filter { it.hasCurrentPrice(fuel) }.minByOrNull { it.price(fuel)!!.price }
    val average = ui.areaAverage(fuel)

    LazyColumn(Modifier.fillMaxSize().statusBarsPadding()) {
        item { ScreenTitle("You") }

        item { Heading("SAVED STATIONS") }
        if (ui.saved.isEmpty()) item { Note("Nothing saved yet. Open a station and tap Save.") }
        items(ui.saved, key = { "saved-" + it.id }) { s -> StationRow(s, ui.fuel, ui.tiers[s.id]) { onSelect(s) } }

        item {
            Heading("MY CAR")
            val car = ui.car
            Column(Modifier.fillMaxWidth().clickable { editCar = true }.padding(horizontal = 16.dp, vertical = 8.dp)) {
                Text(car.name.ifBlank { "Add your car" }, fontWeight = FontWeight.Medium, fontSize = 18.sp)
                Text("${car.fuel} · ${car.tankLitres} L tank", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp)
                if (cheapest != null) {
                    val full = car.tankLitres * cheapest.price(fuel)!!.price / 100
                    val extra = average?.let { car.tankLitres * (it - cheapest.price(fuel)!!.price) / 100 }
                    Text(
                        "A full tank at the cheapest nearby (${cheapest.name}) costs %.2f".format(full) +
                            if (extra != null && extra > 0.005) ", about %.2f under the area average.".format(extra) else ".",
                        fontSize = 13.sp, modifier = Modifier.padding(top = 6.dp),
                    )
                }
            }
        }

        item {
            Heading("FILL-UP LOG")
            Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = { picking = true }) { Text("Add a fill-up") }
                if (ui.fillUps.isNotEmpty()) OutlinedButton(onClick = { exportCsv(context, ui.fillUps) }) { Text("Export CSV") }
            }
            if (ui.fillUps.isEmpty()) {
                Note("Log each fill-up to see what you spend and what you save against the area average.")
            } else {
                Note("This month: ${month.count} fill-ups · %.0f L · $%.2f spent · $%.2f saved".format(month.litres, month.spent, month.saved))
                Bars(
                    LogMath.recent(ui.fillUps, 6, now).map { (m, s) -> m.month.name.take(3).lowercase().replaceFirstChar { it.uppercase() } to s.spent.takeIf { it > 0 } },
                    cheapestIsLowest = false, format = { "$%.0f".format(it) },
                )
                habits?.let { h ->
                    Note(
                        "Average fill %.0f L at %.1f¢/L".format(h.averageLitres, h.averagePrice) +
                            (h.averageUnder?.let { if (it >= 0) ", %.1f¢ under the local average".format(it) else ", %.1f¢ over the local average".format(-it) } ?: "") +
                            (h.daysBetween?.let { ", every %.0f days".format(it) } ?: "") +
                            (h.favourite?.let { ". Most visited: ${it.first} (${it.second})." } ?: "."),
                    )
                }
            }
        }
        items(ui.fillUps, key = { "log-" + it.id }) { f ->
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(f.stationName, fontWeight = FontWeight.Medium)
                    Text(
                        "${DateFormat.getDateInstance(DateFormat.MEDIUM).format(Date(f.epochMs))} · ${f.fuel} · %.1f L at %.1f¢".format(f.litres, f.centsPerLitre),
                        fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text("$%.2f".format(f.cost), fontWeight = FontWeight.SemiBold)
                TextButton(onClick = { vm.deleteFillUp(f.id) }) { Text("Delete") }
            }
            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.4f))
        }
        item { Note("", Modifier.padding(bottom = 24.dp)) }
    }

    if (editCar) CarDialog(ui.car, onDismiss = { editCar = false }) { vm.saveCar(it); editCar = false }
    if (picking) StationPickerDialog(
        (ui.saved + ui.stations.take(40)).distinctBy { it.id }, onDismiss = { picking = false },
    ) { picking = false; logFor = it }
    logFor?.let { s ->
        FillUpDialog(s, Fuel.fromCode(ui.car.fuel).takeIf { s.price(it) != null } ?: ui.fuel, ui.car.tankLitres, onDismiss = { logFor = null }) { fuelChoice, litres, cents ->
            vm.addFillUp(s, fuelChoice, litres, cents)
            logFor = null
        }
    }
}

private fun exportCsv(context: Context, log: List<FillUp>) {
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "text/csv"
        putExtra(Intent.EXTRA_SUBJECT, "servomap-fill-ups.csv")
        putExtra(Intent.EXTRA_TEXT, LogMath.csv(log))
    }
    runCatching { context.startActivity(Intent.createChooser(send, "Export fill-ups").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
}

@Composable
fun CarDialog(car: Car, onDismiss: () -> Unit, onSave: (Car) -> Unit) {
    var name by remember { mutableStateOf(car.name) }
    var fuel by remember { mutableStateOf(Fuel.fromCode(car.fuel)) }
    var tank by remember { mutableStateOf(car.tankLitres.toString()) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("My car") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(name, { name = it }, label = { Text("Name, for example Mazda CX-5") }, singleLine = true)
                FuelChips(fuel, { fuel = it })
                OutlinedTextField(
                    tank, { tank = it.filter(Char::isDigit).take(3) }, label = { Text("Tank size (litres)") }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(Car(name.trim(), fuel.code, tank.toIntOrNull()?.coerceIn(10, 300) ?: car.tankLitres)) }) { Text("Save") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

@Composable
fun StationPickerDialog(stations: List<Station>, onDismiss: () -> Unit, onPick: (Station) -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Where did you fill up?") },
        text = {
            if (stations.isEmpty()) Text("No stations loaded yet. Open the map first, or save a station.")
            else LazyColumn { items(stations, key = { it.id }) { s ->
                Column(Modifier.fillMaxWidth().clickable { onPick(s) }.padding(vertical = 10.dp)) {
                    Text(s.name, fontWeight = FontWeight.Medium)
                    Text(s.suburb, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            } }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

@Composable
fun FillUpDialog(station: Station, fuel: Fuel, tankLitres: Int, onDismiss: () -> Unit, onSave: (Fuel, Double, Double) -> Unit) {
    var chosen by remember { mutableStateOf(fuel) }
    var litres by remember { mutableStateOf(tankLitres.toString()) }
    var cents by remember { mutableStateOf(station.price(fuel)?.price?.let { "%.1f".format(java.util.Locale.US, it) } ?: "") }
    val fuels = Fuel.entries.filter { station.price(it) != null }.ifEmpty { listOf(fuel) }
    val ok = (litres.toDoubleOrNull() ?: 0.0) > 0 && (cents.toDoubleOrNull() ?: 0.0) > 0
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(station.name) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                ChoiceChips(fuels.map { it.code to it }, chosen) {
                    chosen = it
                    station.price(it)?.let { p -> cents = "%.1f".format(java.util.Locale.US, p.price) }
                }
                OutlinedTextField(
                    litres, { litres = it }, label = { Text("Litres") }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                )
                OutlinedTextField(
                    cents, { cents = it }, label = { Text("Price paid (cents per litre)") }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                )
            }
        },
        confirmButton = {
            TextButton(enabled = ok, onClick = { onSave(chosen, litres.toDouble(), cents.toDouble()) }) { Text("Log") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}
