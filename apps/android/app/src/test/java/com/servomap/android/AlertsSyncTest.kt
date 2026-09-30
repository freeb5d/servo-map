package com.servomap.android

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class AlertsSyncTest {
    private fun station(id: String, price: Double, lat: Double = -33.0, lng: Double = 151.0) =
        Station(id, "Station $id", "BP", "1 St", "Town", "nsw", "2000", lat, lng,
            listOf(FuelPrice("U91", price, Instant.now().toString())))

    private fun snaps(latest: Double, days: Int = 30) = (1..days).map {
        Snapshot("2026-01-%02d".format(it), "U91", 190.0, if (it == days) latest else 200.0 + (it % 5) * 4, 230.0, 100)
    }

    @Test fun dropOfThreeCentsOrMoreAlertsAndFirstSightingDoesNot() {
        val s = station("a", 195.0)
        val drops = AlertRules.priceDrops(listOf(s), Fuel.U91, 50, mapOf("a|U91" to 199.0), "2026-01-01")
        assertEquals(1, drops.size)
        assertEquals("Station a dropped 4.0¢", drops[0].title)
        assertTrue(drops[0].body.contains("$2.00 less"))
        assertTrue(AlertRules.priceDrops(listOf(s), Fuel.U91, 50, mapOf("a|U91" to 197.0), "d").isEmpty())
        assertTrue(AlertRules.priceDrops(listOf(s), Fuel.U91, 50, emptyMap(), "d").isEmpty())
    }

    @Test fun cycleLowNeedsTwoWeeksAndABottomQuartile() {
        val near = listOf(station("a", 190.0), station("far", 150.0, lat = -35.0))
        val low = AlertRules.cycleLow(Fuel.U91, snaps(latest = 192.0), near, -33.0, 151.0, "d")
        assertNotNull(low)
        assertTrue(low!!.body.contains("Station a"))
        assertNull(AlertRules.cycleLow(Fuel.U91, snaps(latest = 225.0), near, -33.0, 151.0, "d"))
        assertNull(AlertRules.cycleLow(Fuel.U91, snaps(latest = 192.0, days = 10), near, -33.0, 151.0, "d"))
    }

    @Test fun quietHoursMayRunPastMidnight() {
        assertTrue(AlertRules.isQuiet(23, 22, 7))
        assertTrue(AlertRules.isQuiet(3, 22, 7))
        assertFalse(AlertRules.isQuiet(12, 22, 7))
        assertTrue(AlertRules.isQuiet(8, 6, 9))
        assertFalse(AlertRules.isQuiet(9, 6, 9))
    }

    @Test fun selectSendsOneAPerDayOutsideQuietHoursAndPrefersDrops() {
        val drop = Alert("price_drop", "k1", "t", "b")
        val low = Alert("cycle_low", "k2", "t", "b")
        val noon = Instant.parse("2026-01-10T01:00:00Z") // 12:00 in Sydney (UTC+11)
        val night = Instant.parse("2026-01-10T13:00:00Z") // midnight in Sydney
        val settings = AlertSettings(priceDrop = true, cycleLow = true)
        assertEquals(drop, AlertRules.select(listOf(low, drop), noon, settings, emptyList()))
        assertNull(AlertRules.select(listOf(drop), night, settings, emptyList()))
        val today = AlertRules.sydneyDay(noon)
        assertNull(AlertRules.select(listOf(drop), noon, settings, listOf(AlertLogEntry("cycle_low", "x", today))))
        assertNull(AlertRules.select(listOf(drop), noon, settings, listOf(AlertLogEntry("price_drop", "k1", "2026-01-08"))))
        assertEquals(low, AlertRules.select(listOf(drop, low), noon, settings, listOf(AlertLogEntry("price_drop", "k1", "2026-01-08"))))
    }

    @Test fun fillUpsSurviveTheRoundTripThroughTheWireFormat() {
        val f = FillUp("id-1", 1_767_225_600_000, "s1", "Shell", "Shell", "U91", 40.5, 199.9, 210.0)
        val back = f.toDto().toFillUp()!!
        assertEquals(f.copy(epochMs = 1_767_225_600_000), back)
        assertNull(FillUpDto("x", "not a date", "s", "n", "b", "U91", 1.0, 1.0).toFillUp())
    }

    @Test fun carMapsTheDefaultNameBothWays() {
        assertTrue(Car().isDefault)
        assertEquals("My car", Car().toDto().name)
        assertTrue(CarDto(name = "My car", fuel = "U91", tankLitres = 50).toCar().isDefault)
        val dto = Car("Mazda", "E10", 51, "mazda-cx5", "suv", 56).toDto()
        assertEquals("mazda-cx5", dto.vehicleId)
        assertEquals(56, dto.catalogueTankLitres)
    }

    @Test fun serverAlertsKeepALocalHomeWhenTheAccountHasNone() {
        val local = AlertSettings(homeLat = -33.87, homeLng = 151.21)
        val merged = AlertsDto(priceDrop = true, quietStart = 21).applyTo(local)
        assertTrue(merged.priceDrop)
        assertEquals(21, merged.quietStart)
        assertEquals(-33.87, merged.homeLat!!, 0.0)
        assertEquals(HomeDto(-33.87, 151.21), merged.toDto().home)
    }

    @Test fun meResponseDecodesWithMissingOptionalParts() {
        val body = """{"account":{"id":"u","provider":"google","createdAt":"2026-01-01T00:00:00Z"},"savedStationIds":["a"],
            "fillUps":[],"alerts":{"priceDrop":true,"cycleLow":false,"quietStart":22,"quietEnd":7,"future":1}}"""
        val me = Json { ignoreUnknownKeys = true }.decodeFromString(MeDto.serializer(), body)
        assertEquals(listOf("a"), me.savedStationIds)
        assertNull(me.car)
        assertTrue(me.alerts.priceDrop)
    }

    @Test fun brandsResolveByNameAndFragment() {
        assertEquals("bp", Brands.resolve("BP").id)
        assertEquals("shell", Brands.resolve("Shell Coles Express").id)
        assertEquals("shell", Brands.resolve("Reddy Express").id)
        assertEquals("independent", Brands.resolve("Joe's Servo").id)
        assertEquals("7-eleven", Brands.resolve("7-Eleven").id)
    }

    @Test fun agoReadsAsAHumanAge() {
        val now = Instant.parse("2026-01-10T12:00:00Z")
        assertEquals("30 min ago", ago("2026-01-10T11:30:00Z", now))
        assertEquals("5 h ago", ago("2026-01-10T07:00:00Z", now))
        assertEquals("3 days ago", ago("2026-01-07T12:00:00Z", now))
        assertEquals("", ago("garbage", now))
    }
}
