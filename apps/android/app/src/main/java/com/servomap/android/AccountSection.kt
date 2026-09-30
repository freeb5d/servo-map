package com.servomap.android

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.DateFormat
import java.util.Date

/** Optional sign-in: saved stations, fill-ups, the car and alert settings follow the account across devices. */
@Composable
fun AccountSection(ui: UiState, vm: MainViewModel) {
    val context = LocalContext.current
    var confirmDelete by remember { mutableStateOf(false) }
    val account = ui.account
    Heading("ACCOUNT")
    if (account == null) {
        Note("Sign in to keep your saved stations, fill-ups and car in sync across devices. It is optional; everything works without it.")
        if (GoogleSignIn.configured) {
            Button(
                onClick = { context.findActivity()?.let(vm::signInWithGoogle) },
                enabled = ui.accountStatus != AccountStatus.SigningIn,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
            ) { Text(if (ui.accountStatus == AccountStatus.SigningIn) "Signing in..." else "Sign in with Google") }
        } else {
            Note("Google sign-in is not set up in this build.")
        }
        ui.accountMessage?.let { Note(it) }
    } else {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(44.dp).clip(CircleShape).background(MaterialTheme.colorScheme.surfaceVariant), contentAlignment = Alignment.Center) {
                Text(initials(account), fontWeight = FontWeight.SemiBold)
            }
            Column(Modifier.weight(1f).padding(start = 12.dp)) {
                Text(account.name ?: account.email ?: "You", fontWeight = FontWeight.Medium)
                Text(
                    ui.lastSynced?.let { "Synced ${DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(it))}" } ?: "Signed in with ${account.provider.replaceFirstChar { it.uppercase() }}",
                    fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = vm::refreshAccount) { Text("Sync now") }
            OutlinedButton(onClick = vm::signOut) { Text("Sign out") }
            TextButton(onClick = { confirmDelete = true }) { Text("Delete account") }
        }
        ui.accountMessage?.let { Note(it) }
    }
    if (confirmDelete) AlertDialog(
        onDismissRequest = { confirmDelete = false },
        title = { Text("Delete your account?") },
        text = { Text("This removes your account and everything synced with it from ServoMap. Your saved stations, log and car stay on this phone.") },
        confirmButton = { TextButton(onClick = { confirmDelete = false; vm.deleteAccount() }) { Text("Delete") } },
        dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Cancel") } },
    )
}

fun initials(account: AccountDto): String {
    val source = account.name ?: account.email ?: ""
    val letters = source.split(' ', '@', '.').filter { it.isNotBlank() }.take(2).map { it.first() }
    return if (letters.isEmpty()) "?" else letters.joinToString("").uppercase()
}

fun hourLabel(h: Int): String = when {
    h == 0 -> "12 am"
    h < 12 -> "$h am"
    h == 12 -> "12 pm"
    else -> "${h - 12} pm"
}

/** Alert switches, home and quiet hours; the phone checks them every few hours and notifies at most once a day. */
@Composable
fun AlertsSection(ui: UiState, vm: MainViewModel, locate: () -> Pair<Double, Double>?) {
    val a = ui.alerts
    val notifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}
    fun askPermission() {
        if (Build.VERSION.SDK_INT >= 33) notifications.launch(Manifest.permission.POST_NOTIFICATIONS)
    }
    Heading("ALERTS")
    SwitchRow("A saved station drops", "By 3¢ or more", a.priceDrop) { on ->
        vm.updateAlerts { it.copy(priceDrop = on) }
        if (on) askPermission()
    }
    SwitchRow("Prices are low near home", "Bottom of the 60-day range; names the cheapest within 5 km", a.cycleLow) { on ->
        vm.updateAlerts { it.copy(cycleLow = on) }
        if (on) askPermission()
    }
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text("Home")
            Text(if (a.homeLat != null) "Set, kept to about 1 km" else "Not set", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        TextButton(onClick = {
            locate()?.let { (lat, lng) -> vm.updateAlerts { it.copy(homeLat = Math.round(lat * 100) / 100.0, homeLng = Math.round(lng * 100) / 100.0) } }
        }) { Text("Use my location") }
    }
    Note("Quiet from")
    Column(Modifier.padding(horizontal = 16.dp)) {
        ChoiceChips((18..23).map { hourLabel(it) to it }, a.quietStart) { h -> vm.updateAlerts { it.copy(quietStart = h) } }
    }
    Note("Until")
    Column(Modifier.padding(horizontal = 16.dp)) {
        ChoiceChips((5..10).map { hourLabel(it) to it }, a.quietEnd) { h -> vm.updateAlerts { it.copy(quietEnd = h) } }
    }
    Note("At most one a day, never during quiet hours (Sydney time). ServoMap checks on this phone every few hours, so an alert can arrive a little after a price changes.")
}

@Composable
fun SwitchRow(title: String, subtitle: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f).padding(end = 12.dp)) {
            Text(title)
            Text(subtitle, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Switch(checked = checked, onCheckedChange = onChange)
    }
}
