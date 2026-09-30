package com.servomap.android

import android.Manifest
import android.annotation.SuppressLint
import android.app.UiModeManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.res.Configuration as UiConfig
import android.content.Intent
import android.location.LocationManager
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.TextButton
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

class MainActivity : ComponentActivity() {
    private val vm: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { ServoTheme { App(vm) { lastKnown() } } }
    }

    @SuppressLint("MissingPermission")
    private fun lastKnown(): Pair<Double, Double>? {
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return lm.getProviders(true)
            .mapNotNull { runCatching { lm.getLastKnownLocation(it) }.getOrNull() }
            .maxByOrNull { it.time }
            ?.let { it.latitude to it.longitude }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun App(vm: MainViewModel, locate: () -> Pair<Double, Double>?) {
    val ui by vm.state.collectAsStateWithLifecycle()
    var tab by remember { mutableIntStateOf(0) }
    var searchText by remember { mutableStateOf("") }
    val context = LocalContext.current
    // Wide screens (tablets, foldables, landscape, Android TV) show the list beside the map instead of behind tabs.
    val wide = LocalConfiguration.current.screenWidthDp >= 840
    val tv = remember { isTelevision(context) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        locate()?.let { (lat, lng) -> vm.setCentre(lat, lng) }
    }
    LaunchedEffect(Unit) {
        permission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
    }

    Scaffold(
        topBar = {
            Column(Modifier.statusBarsPadding().padding(horizontal = 16.dp, vertical = 8.dp)) {
                OutlinedTextField(
                    value = searchText,
                    onValueChange = { searchText = it },
                    placeholder = { Text("Suburb or postcode") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(onSearch = { vm.search(searchText) }),
                    modifier = Modifier.fillMaxWidth(),
                )
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                    items(Fuel.entries) { f ->
                        FilterChip(selected = f == ui.fuel, onClick = { vm.setFuel(f) }, label = { Text(f.code) })
                    }
                }
            }
        },
        bottomBar = {
            NavigationBar {
                NavigationBarItem(selected = tab == 0, onClick = { tab = 0 }, icon = { Text("◎") }, label = { Text(if (wide) "Nearby" else "Map") })
                if (!wide) NavigationBarItem(selected = tab == 1, onClick = { tab = 1 }, icon = { Text("≡") }, label = { Text("List") })
                NavigationBarItem(selected = tab == 2, onClick = { tab = 2 }, icon = { Text("★") }, label = { Text("Saved") })
            }
        },
    ) { pad ->
        Box(Modifier.padding(pad).fillMaxSize()) {
            if (tab == 0 && wide) {
                Row(Modifier.fillMaxSize()) {
                    Box(Modifier.weight(0.4f).fillMaxHeight()) { StationList(ui.stations, ui, onSelect = vm::select) }
                    Box(Modifier.weight(0.6f).fillMaxHeight()) {
                        StationMap(ui.stations, ui.tiers, ui.fuel, ui.centre, onSelect = vm::select)
                    }
                }
            } else if (tab == 0) {
                StationMap(ui.stations, ui.tiers, ui.fuel, ui.centre, onSelect = vm::select)
            } else if (tab == 1 && !wide) {
                StationList(ui.stations, ui, onSelect = vm::select)
            } else if (ui.saved.isEmpty()) {
                Text("No saved stations yet. Open a station and tap Save.", color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.align(Alignment.Center).padding(24.dp))
            } else {
                StationList(ui.saved, ui, onSelect = vm::select)
            }
            if (ui.loading) LinearProgressIndicator(Modifier.fillMaxWidth())
            ui.error?.let {
                Text("Couldn't load prices: $it", color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.align(Alignment.TopCenter).padding(16.dp))
            }
        }
        ui.selected?.let { s ->
            val detail: @Composable () -> Unit = {
                StationDetail(s, ui.fuel, ui.tiers[s.id], s.id in ui.savedIds, onToggleSaved = { vm.toggleSaved(s.id) }, showDirections = !tv) {
                    val uri = Uri.parse("geo:${s.lat},${s.lng}?q=${s.lat},${s.lng}(${Uri.encode(s.name)})")
                    try { context.startActivity(Intent(Intent.ACTION_VIEW, uri)) } catch (_: ActivityNotFoundException) {}
                }
            }
            // A bottom sheet is awkward with a remote or keyboard, so wide screens and TVs get a dialog.
            if (wide || tv) {
                AlertDialog(onDismissRequest = { vm.select(null) }, confirmButton = {
                    TextButton(onClick = { vm.select(null) }) { Text("Close") }
                }, text = { detail() })
            } else {
                ModalBottomSheet(onDismissRequest = { vm.select(null) }) { detail() }
            }
        }
    }
}

@Composable
fun StationList(stations: List<Station>, ui: UiState, onSelect: (Station) -> Unit) {
    val dark = isSystemInDarkTheme()
    LazyColumn(Modifier.fillMaxSize()) {
        items(stations, key = { it.id }) { s ->
            val p = s.price(ui.fuel)
            Row(
                Modifier.fillMaxWidth().clickable { onSelect(s) }.padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(s.name, fontWeight = FontWeight.Medium)
                    Text(
                        listOfNotNull(s.brand, s.suburb, s.distance?.let { "%.1f km".format(it) }).joinToString(" · "),
                        fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text(
                    p?.let { "%.1f".format(it.price) } ?: "—", fontSize = 20.sp, fontWeight = FontWeight.SemiBold,
                    color = tierColor(ui.tiers[s.id], dark),
                )
            }
            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.4f))
        }
    }
}

@Composable
fun StationDetail(s: Station, fuel: Fuel, tier: Tier?, saved: Boolean, onToggleSaved: () -> Unit, showDirections: Boolean = true, onDirections: () -> Unit) {
    val dark = isSystemInDarkTheme()
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
        Spacer(Modifier.height(12.dp))
        if (showDirections) Button(onClick = onDirections, modifier = Modifier.fillMaxWidth()) { Text("Directions") }
        OutlinedButton(onClick = onToggleSaved, modifier = Modifier.fillMaxWidth()) { Text(if (saved) "★ Saved" else "☆ Save") }
    }
}

fun isTelevision(context: Context): Boolean =
    (context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager).currentModeType == UiConfig.UI_MODE_TYPE_TELEVISION
