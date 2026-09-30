package com.servomap.android

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

data class Alert(val kind: String, val key: String, val title: String, val body: String)

/**
 * Which alerts to send. A port of packages/worker/src/alerts/rules.ts (decision 0004): the server
 * can only push through APNs, so on Android the same rules run on the phone.
 */
object AlertRules {
    /** A price drop worth a notification, in cents per litre. */
    const val DROP_THRESHOLD = 3.0

    /** Bottom share of the 60-day range that counts as "low". */
    const val LOW_SHARE = 0.15

    private val sydney: ZoneId = ZoneId.of("Australia/Sydney")

    private fun fmt(v: Double) = "%.1f".format(java.util.Locale.US, v)

    /**
     * Drops of [DROP_THRESHOLD]¢ or more since the last check. [seen] holds the last price per
     * "stationId|fuel"; a station seen for the first time sets the baseline and alerts no one.
     */
    fun priceDrops(stations: List<Station>, fuel: Fuel, tankLitres: Int, seen: Map<String, Double>, day: String): List<Alert> =
        stations.mapNotNull { s ->
            val now = s.price(fuel)?.price ?: return@mapNotNull null
            val before = seen["${s.id}|${fuel.code}"] ?: return@mapNotNull null
            val drop = before - now
            if (drop < DROP_THRESHOLD) return@mapNotNull null
            val tank = drop * tankLitres / 100
            Alert(
                "price_drop", "${s.id}|${fuel.code}|$day", "${s.name} dropped ${fmt(drop)}¢",
                "${fuel.code} is ${fmt(now)} now, so a full tank costs $${"%.2f".format(java.util.Locale.US, tank)} less than before.",
            )
        }

    /**
     * When the state average for [fuel] sits in the bottom 15% of its last 60 days, names the
     * cheapest station within 5 km of home. At most one a day.
     */
    fun cycleLow(fuel: Fuel, history: List<Snapshot>, stations: List<Station>, homeLat: Double, homeLng: Double, day: String): Alert? {
        val series = history.filter { it.fuel == fuel.code }.sortedBy { it.date }.takeLast(60)
        val latest = series.lastOrNull() ?: return null
        if (series.size < 14) return null
        val lo = series.minOf { it.avg }
        val hi = series.maxOf { it.avg }
        if (hi - lo < 2 || (latest.avg - lo) / (hi - lo) > LOW_SHARE) return null
        val near = stations
            .mapNotNull { s -> s.price(fuel)?.price?.let { Triple(s, it, haversineKm(homeLat, homeLng, s.lat, s.lng)) } }
            .filter { it.third <= 5 }
            .minByOrNull { it.second }
        return Alert(
            "cycle_low", "${fuel.code}|$day", "Prices near home are low",
            if (near != null) "${fuel.code} is near the bottom of its cycle. ${near.first.name} is cheapest near home at ${fmt(near.second)}."
            else "${fuel.code} averages ${fmt(latest.avg)}, near the bottom of its 60-day range.",
        )
    }

    fun haversineKm(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
        val r = 6371.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLng = Math.toRadians(lng2 - lng1)
        val a = sin(dLat / 2).pow(2) + cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLng / 2).pow(2)
        return 2 * r * asin(sqrt(a))
    }

    fun sydneyHour(now: Instant): Int = ZonedDateTime.ofInstant(now, sydney).hour
    fun sydneyDay(now: Instant): String = ZonedDateTime.ofInstant(now, sydney).toLocalDate().toString()

    /** True inside quiet hours, which may run past midnight (22 to 7). */
    fun isQuiet(hour: Int, start: Int, end: Int): Boolean = if (start > end) hour >= start || hour < end else hour in start until end

    /**
     * Keeps at most one alert a day, never during quiet hours, and never one already sent.
     * Price drops win over cycle lows.
     */
    fun select(alerts: List<Alert>, now: Instant, settings: AlertSettings, log: List<AlertLogEntry>): Alert? {
        if (isQuiet(sydneyHour(now), settings.quietStart, settings.quietEnd)) return null
        val day = sydneyDay(now)
        if (log.any { it.day == day }) return null
        return alerts.sortedBy { if (it.kind == "price_drop") 0 else 1 }
            .firstOrNull { a -> log.none { it.kind == a.kind && it.key == a.key } }
    }
}

/** Runs the alert rules against live prices and shows a notification for the one chosen. */
object AlertChecker {
    private const val CHANNEL = "alerts"

    suspend fun run(context: Context, now: Instant = Instant.now()) {
        val store = Store(context)
        val settings = store.alerts()
        if (!settings.priceDrop && !settings.cycleLow) return
        val car = store.car()
        val fuel = Fuel.fromCode(car.fuel)
        val day = AlertRules.sydneyDay(now)
        val seen = store.seenPrices().toMutableMap()
        val alerts = mutableListOf<Alert>()

        if (settings.priceDrop) {
            val stations = store.savedIds().mapNotNull { id -> runCatching { Api.station(id) }.getOrNull() }
            alerts += AlertRules.priceDrops(stations, fuel, car.tankLitres, seen, day)
            stations.forEach { s -> s.price(fuel)?.let { seen["${s.id}|${fuel.code}"] = it.price } }
        }
        val lat = settings.homeLat
        val lng = settings.homeLng
        if (settings.cycleLow && lat != null && lng != null) {
            runCatching {
                val near = Api.nearby(fuel, lat, lng, 5)
                val state = near.firstOrNull()?.state?.lowercase() ?: "nsw"
                AlertRules.cycleLow(fuel, Api.trends(state), near, lat, lng, day)
            }.getOrNull()?.let { alerts += it }
        }
        store.saveSeenPrices(seen)

        val log = store.alertLog().filter { it.day >= AlertRules.sydneyDay(now.minusSeconds(3 * 86_400L)) }
        val chosen = AlertRules.select(alerts, now, settings, log)
        store.saveAlertLog(log)
        if (chosen != null && notify(context, chosen)) {
            store.saveAlertLog(log + AlertLogEntry(chosen.kind, chosen.key, day))
        }
    }

    /** Returns false when notifications are off, so the alert stays eligible for the next check. */
    private fun notify(context: Context, alert: Alert): Boolean {
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Price alerts", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(alert.title)
            .setContentText(alert.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(alert.body))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        return try {
            manager.notify(alert.kind.hashCode(), notification)
            true
        } catch (e: SecurityException) {
            false
        }
    }
}
