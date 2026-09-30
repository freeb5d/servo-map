package com.servomap.android

import android.content.Context
import android.content.Intent
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** What the widget shows: the cheapest current price near the last known centre, for the map's fuel. */
@Serializable
data class WidgetSnapshot(
    val fuel: String,
    val name: String,
    val suburb: String,
    val price: Double,
    val updatedAt: String,
)

object WidgetData {
    private val json = Json { ignoreUnknownKeys = true }

    /** Fetches fresh prices; on failure falls back to the last snapshot so the widget is never blank. */
    suspend fun load(context: Context): WidgetSnapshot? {
        val store = Store(context)
        val prefs = context.getSharedPreferences("widget", Context.MODE_PRIVATE)
        val fuel = Fuel.fromCode(store.settings().fuel)
        val (lat, lng) = store.lastCentre() ?: UiState.SYDNEY
        val fresh = runCatching {
            Api.nearby(fuel, lat, lng, store.settings().compareKm)
                .filter { it.hasCurrentPrice(fuel) }
                .minByOrNull { it.price(fuel)!!.price }
                ?.let { s ->
                    val p = s.price(fuel)!!
                    WidgetSnapshot(fuel.code, s.name, s.suburb, p.price, p.updatedAt)
                }
        }.getOrNull()
        if (fresh != null) {
            prefs.edit().putString("last", json.encodeToString(WidgetSnapshot.serializer(), fresh)).apply()
            return fresh
        }
        return prefs.getString("last", null)?.let { runCatching { json.decodeFromString(WidgetSnapshot.serializer(), it) }.getOrNull() }
    }
}

/** "Cheapest nearby": one station and its price, styled with the paper and ink tokens. */
class PriceWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = WidgetData.load(context)
        provideContent {
            val ink = ColorProvider(day = Ink.ink, night = Ink.inkDark)
            val muted = ColorProvider(day = Ink.ink2, night = Ink.ink2Dark)
            Column(
                GlanceModifier.fillMaxSize()
                    .background(ColorProvider(day = Ink.paper, night = Ink.paperDark))
                    .cornerRadius(20.dp)
                    .padding(14.dp)
                    .clickable(actionStartActivity(Intent(context, MainActivity::class.java))),
            ) {
                Text("Cheapest ${data?.fuel ?: "fuel"} nearby", style = TextStyle(color = muted, fontSize = 12.sp))
                if (data == null) {
                    Text("Open ServoMap to load prices", style = TextStyle(color = ink, fontSize = 14.sp))
                } else {
                    Text(
                        "%.1f".format(data.price),
                        style = TextStyle(color = ColorProvider(day = Ink.cheap, night = Ink.cheapDark), fontSize = 34.sp, fontWeight = FontWeight.Bold),
                    )
                    Text(data.name, style = TextStyle(color = ink, fontSize = 14.sp, fontWeight = FontWeight.Medium), maxLines = 1)
                    Text(
                        listOf(data.suburb, ago(data.updatedAt)).filter { it.isNotBlank() }.joinToString(" · "),
                        style = TextStyle(color = muted, fontSize = 12.sp), maxLines = 1,
                    )
                }
            }
        }
    }
}

class PriceWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = PriceWidget()
}
