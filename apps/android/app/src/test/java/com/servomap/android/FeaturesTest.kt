package com.servomap.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.YearMonth
import java.time.ZoneOffset

class FeaturesTest {
    private fun snap(date: String, avg: Double) = Snapshot(date, "U91", avg - 5, avg, avg + 5, 100)

    private fun fill(id: String, ms: Long, name: String, litres: Double, cents: Double, area: Double?) =
        FillUp(id, ms, "s-$name", name, "BP", "U91", litres, cents, area)

    @Test fun runsBreakAtMissingDays() {
        val series = listOf(snap("2026-01-01", 200.0), snap("2026-01-02", 201.0), snap("2026-01-05", 199.0))
        assertEquals(listOf(listOf(0, 1), listOf(2)), TrendMath.runs(series))
    }

    @Test fun changeLooksBackTheRequestedDays() {
        val series = (1..8).map { snap("2026-01-%02d".format(it), 200.0 + it) }
        assertEquals(7.0, TrendMath.change(series, 7)!!, 1e-9)
        assertNull(TrendMath.change(series, 30))
    }

    @Test fun verdictNamesTheHighWhenLatestIsMax() {
        val series = listOf(snap("2026-01-01", 200.0), snap("2026-01-02", 210.0))
        assertEquals("At the 2-day high.", TrendMath.verdict(series))
    }

    @Test fun weekdaysStartOnMonday() {
        // 2026-01-05 is a Monday.
        val days = TrendMath.weekdays(listOf(snap("2026-01-05", 200.0), snap("2026-01-06", 190.0)))
        assertEquals("Mon", days[0].first)
        assertEquals(200.0, days[0].second!!, 1e-9)
        assertEquals(190.0, days[1].second!!, 1e-9)
        assertNull(days[2].second)
    }

    @Test fun cityFactsRankCheapestFirst() {
        val cities = listOf(
            CityInsight("a", "Alpha", average = 230.0), CityInsight("b", "Beta", average = 220.0), CityInsight("c", "Gamma"),
        )
        val ranked = CityFacts.ranked(cities)
        assertEquals(listOf("Beta", "Alpha"), ranked.map { it.name })
        assertEquals("Beta is cheapest at 220.0¢ on average. Alpha is 10.0¢ dearer.", CityFacts.cheapestFact(ranked))
    }

    @Test fun savingIsNeverNegative() {
        assertEquals(2.0, fill("1", 0, "A", 40.0, 195.0, 200.0).saved, 1e-9)
        assertEquals(0.0, fill("2", 0, "A", 40.0, 205.0, 200.0).saved, 1e-9)
        assertEquals(0.0, fill("3", 0, "A", 40.0, 195.0, null).saved, 1e-9)
    }

    @Test fun monthSummaryCountsOnlyThatMonth() {
        val jan = Instant.parse("2026-01-10T12:00:00Z").toEpochMilli()
        val feb = Instant.parse("2026-02-10T12:00:00Z").toEpochMilli()
        val log = listOf(fill("1", jan, "A", 40.0, 200.0, 210.0), fill("2", feb, "A", 30.0, 200.0, null))
        val s = LogMath.monthSummary(log, YearMonth.of(2026, 1), ZoneOffset.UTC)
        assertEquals(1, s.count)
        assertEquals(80.0, s.spent, 1e-9)
        assertEquals(4.0, s.saved, 1e-9)
        assertEquals(6, LogMath.recent(log, 6, YearMonth.of(2026, 2), ZoneOffset.UTC).size)
    }

    @Test fun habitsFindFavouriteAndInterval() {
        val day = 86_400_000L
        val log = listOf(fill("1", 0, "A", 40.0, 200.0, 210.0), fill("2", 7 * day, "B", 40.0, 200.0, null), fill("3", 14 * day, "A", 40.0, 200.0, 210.0))
        val h = LogMath.habits(log)!!
        assertEquals("A" to 2, h.favourite)
        assertEquals(7.0, h.daysBetween!!, 1e-9)
        assertEquals(10.0, h.averageUnder!!, 1e-9)
        assertNull(LogMath.habits(emptyList()))
    }

    @Test fun csvQuotesFieldsAndUsesFullStops() {
        val row = fill("1", 0, "Shell, \"Main\"", 40.5, 199.9, null)
        val csv = LogMath.csv(listOf(row), ZoneOffset.UTC)
        val lines = csv.trimEnd().split("\r\n")
        assertEquals(2, lines.size)
        assertTrue(lines[1].contains("\"Shell, \"\"Main\"\"\""))
        assertTrue(lines[1].contains("40.50,199.9,80.96,"))
    }

    @Test fun filtersHideBrandsAndStalePrices() {
        val now = Instant.now()
        fun st(id: String, brand: String, at: Instant) =
            Station(id, id, brand, "", "", "nsw", "", 0.0, 0.0, listOf(FuelPrice("U91", 200.0, at.toString())))
        val list = listOf(st("a", "BP", now), st("b", "Shell", now), st("c", "BP", now.minusSeconds(48 * 3600L)))
        assertEquals(3, Filters().apply(list, Fuel.U91).size)
        assertEquals(listOf("b"), Filters(hiddenBrands = setOf("BP")).apply(list, Fuel.U91).map { it.id })
        assertEquals(listOf("a", "b"), Filters(freshHours = 24).apply(list, Fuel.U91).map { it.id })
        assertTrue(Filters(freshHours = 24).active)
        assertNotNull(Fuel.fromCode("Diesel"))
        assertEquals(Fuel.U91, Fuel.fromCode("nope"))
    }
}
