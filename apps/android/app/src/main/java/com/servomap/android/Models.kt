package com.servomap.android

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

enum class Fuel(val code: String) { U91("U91"), E10("E10"), U95("U95"), U98("U98"), Diesel("Diesel") }

@Serializable
data class FuelPrice(
    val fuel: String,
    /** Cents per litre. */
    val price: Double,
    @SerialName("updated_at") val updatedAt: String,
)

@Serializable
data class Station(
    val id: String,
    val name: String,
    val brand: String,
    val address: String,
    val suburb: String,
    val state: String,
    val postcode: String,
    val lat: Double,
    val lng: Double,
    val prices: List<FuelPrice>,
    val distance: Double? = null,
) {
    fun price(fuel: Fuel): FuelPrice? = prices.firstOrNull { it.fuel == fuel.code }

    /** A price older than a week may be from a station that stopped reporting: shown, but not ranked. */
    fun hasCurrentPrice(fuel: Fuel, now: Instant = Instant.now()): Boolean {
        val p = price(fuel) ?: return false
        val updated = runCatching { Instant.parse(p.updatedAt) }.getOrNull() ?: return false
        return now.epochSecond - updated.epochSecond <= CURRENT_FOR_SECONDS
    }

    companion object {
        const val CURRENT_FOR_SECONDS = 7L * 86_400
    }
}

@Serializable
data class Envelope<T>(val data: T)

enum class Tier { Cheap, Mid, Expensive }

/** Splits ranked prices into thirds: cheapest third green, middle ochre, dearest red. */
fun tiers(stations: List<Station>, fuel: Fuel): Map<String, Tier> {
    val ranked = stations.filter { it.hasCurrentPrice(fuel) }.sortedBy { it.price(fuel)!!.price }
    return ranked.mapIndexed { i, s ->
        s.id to when {
            i * 3 < ranked.size -> Tier.Cheap
            i * 3 < ranked.size * 2 -> Tier.Mid
            else -> Tier.Expensive
        }
    }.toMap()
}
