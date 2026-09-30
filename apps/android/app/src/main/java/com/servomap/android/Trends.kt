package com.servomap.android

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.DayOfWeek
import java.time.LocalDate

/** One state's price for one fuel on one day. */
@Serializable
data class Snapshot(
    val date: String,
    val fuel: String,
    val min: Double,
    val avg: Double,
    val max: Double,
    @SerialName("station_count") val stationCount: Int = 0,
)

@Serializable
data class Trend(val state: String = "", val series: List<Snapshot>)

@Serializable
data class StateMeta(@SerialName("station_count") val stationCount: Int = 0)

@Serializable
data class CityInsight(
    val id: String,
    val name: String,
    val state: String = "",
    @SerialName("radius_km") val radiusKm: Double = 0.0,
    @SerialName("station_count") val stationCount: Int = 0,
    val count: Int = 0,
    val average: Double? = null,
    val min: Double? = null,
    val max: Double? = null,
    val median: Double? = null,
    @SerialName("reported_within_24h_share") val reportedWithin24hShare: Double? = null,
)

@Serializable
data class CityInsights(val fuel: String = "", val cities: List<CityInsight>)

/** Reads over the daily state series, mirroring the iOS app's TrendMath. */
object TrendMath {
    fun day(date: String): LocalDate? = runCatching { LocalDate.parse(date) }.getOrNull()

    /** Indices of consecutive days grouped into runs; a missing day starts a new run so charts never bridge a gap. */
    fun runs(series: List<Snapshot>): List<List<Int>> {
        val out = mutableListOf<MutableList<Int>>()
        var prev: LocalDate? = null
        series.forEachIndexed { i, s ->
            val d = day(s.date)
            if (prev != null && d != null && d.toEpochDay() - prev!!.toEpochDay() <= 1) out.last().add(i)
            else out.add(mutableListOf(i))
            prev = d
        }
        return out
    }

    fun verdict(series: List<Snapshot>): String? {
        val latest = series.lastOrNull() ?: return null
        val lo = series.minOf { it.avg }
        val hi = series.maxOf { it.avg }
        if (hi <= lo) return null
        val first = day(series.first().date)
        val last = day(latest.date)
        val days = if (first != null && last != null) "${last.toEpochDay() - first.toEpochDay() + 1}-day" else "recent"
        val position = (latest.avg - lo) / (hi - lo)
        return when {
            latest.avg == hi -> "At the $days high."
            position >= 0.66 -> "Near the $days high."
            position <= 0.33 -> "Near the $days low."
            else -> "Mid-range for the last $days period."
        }
    }

    /** Change in the average against the snapshot [days] earlier, or null when that day is missing. */
    fun change(series: List<Snapshot>, days: Int): Double? {
        val latest = series.lastOrNull() ?: return null
        val target = (day(latest.date) ?: return null).toEpochDay() - days
        val earlier = series.lastOrNull { (day(it.date)?.toEpochDay() ?: Long.MAX_VALUE) <= target } ?: return null
        val gap = target - (day(earlier.date)?.toEpochDay() ?: return null)
        return if (gap <= 1) latest.avg - earlier.avg else null
    }

    /** The last [days] days of the series (all of it when null). */
    fun window(series: List<Snapshot>, days: Int?): List<Snapshot> {
        val latest = series.lastOrNull() ?: return series
        if (days == null) return series
        val start = (day(latest.date) ?: return series).toEpochDay() - days
        return series.filter { (day(it.date)?.toEpochDay() ?: 0L) > start }
    }

    /** Average price per weekday, Monday first. */
    fun weekdays(series: List<Snapshot>): List<Pair<String, Double?>> {
        val names = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
        val sums = DoubleArray(7)
        val counts = IntArray(7)
        series.forEach { s ->
            val d = day(s.date) ?: return@forEach
            val i = (d.dayOfWeek.value - DayOfWeek.MONDAY.value)
            sums[i] += s.avg
            counts[i]++
        }
        return names.indices.map { names[it] to if (counts[it] == 0) null else sums[it] / counts[it] }
    }
}

object CityFacts {
    fun ranked(cities: List<CityInsight>): List<CityInsight> =
        cities.filter { it.average != null }.sortedWith(compareBy({ it.average }, { it.name }))

    /** "Bunbury is cheapest at 232.2¢ on average. Launceston is 14.4¢ dearer." */
    fun cheapestFact(ranked: List<CityInsight>): String? {
        val low = ranked.firstOrNull() ?: return null
        val lowAvg = low.average ?: return null
        val head = "${low.name} is cheapest at ${"%.1f".format(lowAvg)}¢ on average."
        val high = ranked.lastOrNull()
        val highAvg = high?.average
        if (ranked.size < 2 || high == null || highAvg == null || highAvg - lowAvg < 0.05) return head
        return "$head ${high.name} is ${"%.1f".format(highAvg - lowAvg)}¢ dearer."
    }
}
