package com.servomap.android

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri

/** An app that can give driving directions to a station; "other" hands the location to any maps app. */
enum class NavApp(val key: String, val label: String) {
    Google("google", "Google Maps"),
    Waze("waze", "Waze"),
    Other("other", "Other maps app"),
}

object Directions {
    fun intent(app: NavApp, s: Station): Intent = when (app) {
        NavApp.Google -> Intent(Intent.ACTION_VIEW, Uri.parse("google.navigation:q=${s.lat},${s.lng}"))
            .setPackage("com.google.android.apps.maps")
        NavApp.Waze -> Intent(Intent.ACTION_VIEW, Uri.parse("waze://?ll=${s.lat},${s.lng}&navigate=yes"))
        NavApp.Other -> Intent(Intent.ACTION_VIEW, Uri.parse("geo:${s.lat},${s.lng}?q=${s.lat},${s.lng}(${Uri.encode(s.name)})"))
    }

    /** Opens [app]; falls back to any maps app when it is not installed. Returns false when nothing can show a map. */
    fun open(context: Context, app: NavApp, s: Station): Boolean {
        for (candidate in listOf(app, NavApp.Other).distinct()) {
            try {
                context.startActivity(intent(candidate, s))
                return true
            } catch (_: ActivityNotFoundException) {
            }
        }
        return false
    }
}
