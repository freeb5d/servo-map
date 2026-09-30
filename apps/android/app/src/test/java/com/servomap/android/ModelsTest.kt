package com.servomap.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class ModelsTest {
    private fun station(id: String, price: Double, updated: String = Instant.now().toString()) =
        Station(id, id, "BP", "1 St", "Town", "nsw", "2000", -33.0, 151.0,
            listOf(FuelPrice("U91", price, updated)))

    @Test fun parsesEnvelopeAndIgnoresUnknownKeys() {
        val body = """{"status":"success","meta":{"total":1},"data":[{"id":"a","name":"N","brand":"BP","address":"x",
            "suburb":"s","state":"nsw","postcode":"2000","lat":-33.0,"lng":151.0,"extra":1,
            "prices":[{"fuel":"U91","price":199.9,"updated_at":"2026-01-01T00:00:00Z"}],"distance":1.5}]}"""
        val s = Api.parse(body).single()
        assertEquals(199.9, s.price(Fuel.U91)!!.price, 0.0)
        assertEquals(1.5, s.distance!!, 0.0)
    }

    @Test fun tiersSplitIntoThirdsAndSkipStale() {
        val list = listOf(station("a", 190.0), station("b", 200.0), station("c", 210.0),
            station("stale", 100.0, "2020-01-01T00:00:00Z"))
        val t = tiers(list, Fuel.U91)
        assertEquals(Tier.Cheap, t["a"]); assertEquals(Tier.Mid, t["b"]); assertEquals(Tier.Expensive, t["c"])
        assertTrue("stale" !in t)
    }
}
