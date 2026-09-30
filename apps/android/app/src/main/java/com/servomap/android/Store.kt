package com.servomap.android

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.time.Instant
import java.time.YearMonth
import java.time.ZoneId

@Serializable
data class Settings(
    /** "system", "light" or "dark". */
    val theme: String = "system",
    val fuel: String = Fuel.U91.code,
    /** Radius nearby prices are fetched and compared within, in km. */
    val compareKm: Int = 20,
    /** "ask", "google", "waze" or "other". */
    val nav: String = "ask",
) {
    companion object {
        val compareChoices = listOf(2, 5, 10, 20, 50)
    }
}

@Serializable
data class Car(val name: String = "", val fuel: String = Fuel.U91.code, val tankLitres: Int = 50)

/** One fill-up the user recorded. Prices are cents per litre; the area average is captured at the time. */
@Serializable
data class FillUp(
    val id: String,
    val epochMs: Long,
    val stationId: String,
    val stationName: String,
    val brand: String,
    val fuel: String,
    val litres: Double,
    val centsPerLitre: Double,
    /** Local average when logged; null if unknown, in which case no saving is claimed. */
    val areaAverage: Double? = null,
) {
    val cost: Double get() = litres * centsPerLitre / 100

    /** Dollars saved against the area average; never negative, a dearer fill counts as zero saved. */
    val saved: Double get() = areaAverage?.let { maxOf(0.0, (it - centsPerLitre) * litres / 100) } ?: 0.0
}

/** Everything the app keeps on the device, as JSON in SharedPreferences. */
class Store(context: Context) {
    private val sp = context.getSharedPreferences("servomap", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }

    fun settings(): Settings = read("settings", Settings.serializer()) ?: Settings()
    fun saveSettings(v: Settings) = write("settings", Settings.serializer(), v)

    fun car(): Car = read("car", Car.serializer()) ?: Car()
    fun saveCar(v: Car) = write("car", Car.serializer(), v)

    fun fillUps(): List<FillUp> = read("fillups", ListSerializer(FillUp.serializer())) ?: emptyList()
    fun saveFillUps(v: List<FillUp>) = write("fillups", ListSerializer(FillUp.serializer()), v)

    fun savedIds(): Set<String> = sp.getStringSet("saved_ids", emptySet()).orEmpty().toSet()
    fun saveSavedIds(v: Set<String>) = sp.edit().putStringSet("saved_ids", v).apply()

    private fun <T> read(key: String, s: kotlinx.serialization.KSerializer<T>): T? =
        sp.getString(key, null)?.let { runCatching { json.decodeFromString(s, it) }.getOrNull() }

    private fun <T> write(key: String, s: kotlinx.serialization.KSerializer<T>, v: T) =
        sp.edit().putString(key, json.encodeToString(s, v)).apply()
}

/** Totals for one calendar month of fill-ups. */
data class MonthSummary(val count: Int = 0, val litres: Double = 0.0, val spent: Double = 0.0, val saved: Double = 0.0)

object LogMath {
    private fun month(epochMs: Long, zone: ZoneId) = YearMonth.from(Instant.ofEpochMilli(epochMs).atZone(zone))

    fun monthSummary(log: List<FillUp>, month: YearMonth, zone: ZoneId = ZoneId.systemDefault()): MonthSummary =
        log.filter { month(it.epochMs, zone) == month }.fold(MonthSummary()) { s, f ->
            MonthSummary(s.count + 1, s.litres + f.litres, s.spent + f.cost, s.saved + f.saved)
        }

    /** The [count] calendar months ending with [now]'s, oldest first; empty months included. */
    fun recent(log: List<FillUp>, count: Int, now: YearMonth, zone: ZoneId = ZoneId.systemDefault()): List<Pair<YearMonth, MonthSummary>> =
        (count - 1 downTo 0).map { back -> now.minusMonths(back.toLong()).let { it to monthSummary(log, it, zone) } }

    data class Habits(
        val averageLitres: Double,
        /** Litre-weighted average price paid, cents per litre. */
        val averagePrice: Double,
        /** Mean of (local average - price paid) over fills with a known average; positive means paid under. */
        val averageUnder: Double?,
        /** Mean days between consecutive fills; null with fewer than two. */
        val daysBetween: Double?,
        val favourite: Pair<String, Int>?,
    )

    fun habits(log: List<FillUp>): Habits? {
        if (log.isEmpty()) return null
        val litres = log.sumOf { it.litres }
        val paid = log.sumOf { it.litres * it.centsPerLitre }
        val unders = log.mapNotNull { f -> f.areaAverage?.let { it - f.centsPerLitre } }
        val times = log.map { it.epochMs }.sorted()
        val gaps = times.zipWithNext { a, b -> (b - a) / 86_400_000.0 }
        val newestFirst = log.sortedByDescending { it.epochMs }.map { it.stationName }
        val counts = newestFirst.groupingBy { it }.eachCount()
        val top = counts.values.max()
        val favourite = newestFirst.first { counts[it] == top }
        return Habits(
            averageLitres = litres / log.size,
            averagePrice = if (litres > 0) paid / litres else 0.0,
            averageUnder = if (unders.isEmpty()) null else unders.average(),
            daysBetween = if (gaps.isEmpty()) null else gaps.average(),
            favourite = favourite to top,
        )
    }

    /** RFC 4180 CSV, oldest first, for a spreadsheet; numbers use a full stop whatever the locale. */
    fun csv(entries: List<FillUp>, zone: ZoneId = ZoneId.systemDefault()): String {
        val header = listOf("date", "station", "station_id", "brand", "fuel", "litres", "cents_per_litre", "cost_dollars", "area_average_cents")
        val rows = entries.sortedBy { it.epochMs }.map { f ->
            listOf(Instant.ofEpochMilli(f.epochMs).atZone(zone).toOffsetDateTime().toString(), f.stationName, f.stationId, f.brand, f.fuel,
                num(f.litres, 2), num(f.centsPerLitre, 1), num(f.cost, 2), f.areaAverage?.let { num(it, 1) } ?: "")
        }
        return (listOf(header) + rows).joinToString("\r\n") { r -> r.joinToString(",") { field(it) } } + "\r\n"
    }

    fun field(v: String): String =
        if (v.any { it == ',' || it == '"' || it == '\n' || it == '\r' }) "\"" + v.replace("\"", "\"\"") + "\"" else v

    private fun num(v: Double, decimals: Int) = String.format(java.util.Locale.US, "%.${decimals}f", v)
}
