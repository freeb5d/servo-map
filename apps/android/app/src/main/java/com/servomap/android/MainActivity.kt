package com.servomap.android

import android.Manifest
import android.annotation.SuppressLint
import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration as UiConfig
import android.location.LocationManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

class MainActivity : ComponentActivity() {
    private val vm: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val ui by vm.state.collectAsStateWithLifecycle()
            ServoTheme(ui.settings.theme) { App(vm, ui) { lastKnown() } }
        }
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

private enum class Tab(val label: String, val icon: ImageVector) {
    Nearby("Nearby", Icons.Filled.Map),
    Trends("Trends", Icons.AutoMirrored.Filled.TrendingUp),
    You("You", Icons.Filled.Person),
    Settings("Settings", Icons.Filled.Settings),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun App(vm: MainViewModel, ui: UiState, locate: () -> Pair<Double, Double>?) {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    var showList by rememberSaveable { mutableStateOf(false) }
    var searchText by rememberSaveable { mutableStateOf("") }
    var showFilters by remember { mutableStateOf(false) }
    var askDirections by remember { mutableStateOf<Station?>(null) }
    var logFor by remember { mutableStateOf<Station?>(null) }
    val context = LocalContext.current
    // Wide screens (tablets, foldables, landscape, Android TV) show the list beside the map instead of behind a toggle.
    val wide = LocalConfiguration.current.screenWidthDp >= 840
    val tv = remember { isTelevision(context) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        locate()?.let { (lat, lng) -> vm.setCentre(lat, lng) }
    }
    LaunchedEffect(Unit) {
        permission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
    }
    val visible = ui.visible
    val cheapest = remember(visible, ui.fuel) { visible.filter { it.hasCurrentPrice(ui.fuel) }.minByOrNull { it.price(ui.fuel)!!.price } }

    fun directions(s: Station) {
        val app = NavApp.entries.firstOrNull { it.key == ui.settings.nav }
        if (app == null) askDirections = s else Directions.open(context, app, s)
    }

    Scaffold(
        topBar = {
            if (tab == Tab.Nearby.ordinal) {
                Column(Modifier.statusBarsPadding().padding(horizontal = 16.dp, vertical = 8.dp)) {
                    OutlinedTextField(
                        value = searchText,
                        onValueChange = { searchText = it },
                        placeholder = { Text("Suburb or postcode") },
                        leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
                        trailingIcon = {
                            IconButton(onClick = {
                                searchText = ""
                                val here = locate()
                                if (here != null) vm.setCentre(here.first, here.second)
                                else permission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
                            }) { Icon(Icons.Filled.MyLocation, contentDescription = "Use my location") }
                        },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                        keyboardActions = KeyboardActions(onSearch = { vm.search(searchText) }),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.weight(1f)) { FuelChips(ui.fuel, vm::setFuel) }
                        FilterChip(selected = ui.filters.active, onClick = { showFilters = true }, label = { Text(if (ui.filters.active) "Filters ●" else "Filters") },
                            leadingIcon = { Icon(Icons.Filled.FilterList, contentDescription = null, Modifier.size(18.dp)) })
                    }
                    if (!wide) Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilterChip(selected = !showList, onClick = { showList = false }, label = { Text("Map") }, leadingIcon = { Icon(Icons.Filled.Map, contentDescription = null, Modifier.size(18.dp)) })
                        FilterChip(selected = showList, onClick = { showList = true }, label = { Text("List") }, leadingIcon = { Icon(Icons.AutoMirrored.Filled.List, contentDescription = null, Modifier.size(18.dp)) })
                    }
                }
            }
        },
        bottomBar = {
            NavigationBar {
                Tab.entries.forEach { t ->
                    NavigationBarItem(selected = tab == t.ordinal, onClick = { tab = t.ordinal }, icon = { Icon(t.icon, contentDescription = null) }, label = { Text(t.label) })
                }
            }
        },
    ) { pad ->
        Box(Modifier.padding(pad).fillMaxSize()) {
            when (Tab.entries[tab]) {
                Tab.Nearby -> {
                    if (wide) {
                        Row(Modifier.fillMaxSize()) {
                            Box(Modifier.weight(0.4f).fillMaxHeight()) { ResultsList(visible, ui, vm::select) }
                            Box(Modifier.weight(0.6f).fillMaxHeight()) {
                                StationMap(visible, ui.tiers, ui.fuel, ui.centre, onSelect = vm::select)
                                cheapest?.let { CheapestCard(it, ui.fuel, ui.tiers[it.id], Modifier.align(Alignment.BottomCenter)) { vm.select(it) } }
                            }
                        }
                    } else if (showList) {
                        ResultsList(visible, ui, vm::select)
                    } else {
                        StationMap(visible, ui.tiers, ui.fuel, ui.centre, onSelect = vm::select)
                        cheapest?.let { CheapestCard(it, ui.fuel, ui.tiers[it.id], Modifier.align(Alignment.BottomCenter)) { vm.select(it) } }
                    }
                    if (ui.loading) LinearProgressIndicator(Modifier.fillMaxWidth())
                    ui.error?.let {
                        Text("Couldn't load prices: $it", color = MaterialTheme.colorScheme.error,
                            modifier = Modifier.align(Alignment.TopCenter).padding(16.dp))
                    }
                }
                Tab.Trends -> TrendsScreen(ui, vm)
                Tab.You -> YouScreen(ui, vm, onSelect = vm::select)
                Tab.Settings -> SettingsScreen(ui, vm)
            }
        }

        ui.selected?.let { s ->
            val detail: @Composable () -> Unit = {
                StationDetail(
                    s, ui.fuel, ui.tiers[s.id], s.id in ui.savedIds,
                    onToggleSaved = { vm.toggleSaved(s.id) }, onLogFillUp = { vm.select(null); logFor = s },
                    showDirections = !tv, onDirections = { directions(s) },
                )
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

    if (showFilters) FilterDialog(ui, vm) { showFilters = false }
    askDirections?.let { s ->
        AlertDialog(
            onDismissRequest = { askDirections = null },
            title = { Text("Directions with") },
            text = {
                Column {
                    NavApp.entries.forEach { app ->
                        OutlinedButton(onClick = { Directions.open(context, app, s); askDirections = null }, modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                            Text(app.label)
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(onClick = { askDirections = null }) { Text("Cancel") } },
        )
    }
    logFor?.let { s ->
        FillUpDialog(s, Fuel.fromCode(ui.car.fuel).takeIf { s.price(it) != null } ?: ui.fuel, ui.car.tankLitres, onDismiss = { logFor = null }) { fuel, litres, cents ->
            vm.addFillUp(s, fuel, litres, cents)
            logFor = null
        }
    }
}

fun isTelevision(context: Context): Boolean =
    (context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager).currentModeType == UiConfig.UI_MODE_TYPE_TELEVISION

/** The results list, with a placeholder while the first fetch runs and a hint when nothing matches. */
@Composable
private fun ResultsList(stations: List<Station>, ui: UiState, onSelect: (Station) -> Unit) {
    when {
        stations.isEmpty() && ui.loading -> ListSkeleton()
        stations.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(
                if (ui.filters.active) "No stations match these filters." else "No stations found here. Try another suburb or a wider radius in Settings.",
                color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(24.dp),
            )
        }
        else -> StationList(stations, ui, onSelect)
    }
}
