package com.servomap.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.Column

/** Brands to show, how recent a price must be, and how far to look; changes apply as they are made. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun FilterDialog(ui: UiState, vm: MainViewModel, onDismiss: () -> Unit) {
    val present = ui.stations.map { it.family.id }.toSet()
    val brands = Brands.all.filter { it.id in present }
    val f = ui.filters
    val shown = brands.count { it.id !in f.hiddenBrands }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Filters") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(if (shown == brands.size) "Brands · all" else "Brands · $shown of ${brands.size}")
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    brands.forEach { b ->
                        FilterChip(
                            selected = b.id !in f.hiddenBrands,
                            onClick = { vm.setFilters(f.copy(hiddenBrands = if (b.id in f.hiddenBrands) f.hiddenBrands - b.id else f.hiddenBrands + b.id)) },
                            label = { Text(b.name) },
                            leadingIcon = { BrandMark(b.name, 20.dp) },
                        )
                    }
                }
                Text("Price reported within", modifier = Modifier.padding(top = 8.dp))
                ChoiceChips(Filters.freshChoices, f.freshHours) { vm.setFilters(f.copy(freshHours = it)) }
                Text("Compare within", modifier = Modifier.padding(top = 8.dp))
                ChoiceChips(Settings.compareChoices.map { "$it km" to it }, ui.settings.compareKm) { km ->
                    vm.updateSettings { it.copy(compareKm = km) }
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("Done") } },
        dismissButton = { TextButton(enabled = f.active, onClick = { vm.setFilters(Filters()) }) { Text("Reset") } },
    )
}
