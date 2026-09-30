package com.servomap.android

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.time.Year

@Composable
fun SettingsScreen(ui: UiState, vm: MainViewModel) {
    val context = LocalContext.current
    val s = ui.settings
    fun open(url: String) { runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } }

    Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState())) {
        ScreenTitle("Settings")

        Heading("APPEARANCE")
        Row(Modifier.padding(horizontal = 16.dp)) {
            ChoiceChips(listOf("System" to "system", "Light" to "light", "Dark" to "dark"), s.theme) { v -> vm.updateSettings { it.copy(theme = v) } }
        }

        Heading("MAP OPENS ON")
        Row(Modifier.padding(horizontal = 16.dp)) {
            ChoiceChips(Fuel.entries.map { it.code to it.code }, s.fuel) { v ->
                vm.updateSettings { it.copy(fuel = v) }
                vm.setFuel(Fuel.fromCode(v))
            }
        }

        Heading("COMPARE WITHIN")
        Row(Modifier.padding(horizontal = 16.dp)) {
            ChoiceChips(Settings.compareChoices.map { "$it km" to it }, s.compareKm) { v -> vm.updateSettings { it.copy(compareKm = v) } }
        }
        Note("Prices are fetched and colour-ranked within this distance of the map centre.")

        Heading("DIRECTIONS")
        Row(Modifier.padding(horizontal = 16.dp)) {
            ChoiceChips(listOf("Ask each time" to "ask") + NavApp.entries.map { it.label to it.key }, s.nav) { v -> vm.updateSettings { it.copy(nav = v) } }
        }

        Heading("DATA SOURCES")
        Note("ServoMap reads each state's official fuel-price feed. Prices are as reported; check the pump.")
        val year = Year.now().value
        DataSources.all.entries.groupBy { it.value.name }.forEach { (_, entries) ->
            val src = entries.first().value
            Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
                Text(src.name + " · " + entries.joinToString(", ") { it.key.uppercase() }, fontWeight = FontWeight.Medium)
                Text(src.note, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                src.attribution(year)?.let { Text(it, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp)) }
                Row {
                    TextButton(onClick = { open(src.url) }) { Text("Visit") }
                    src.reportUrl?.let { TextButton(onClick = { open(it) }) { Text("Report a wrong price") } }
                }
            }
            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.4f))
        }

        Heading("ABOUT")
        Note("ServoMap for Android ${BuildConfig.VERSION_NAME}")
        TextButton(onClick = { open("https://www.servo-map.com") }, modifier = Modifier.padding(start = 8.dp, bottom = 24.dp)) { Text("servo-map.com") }
    }
}
