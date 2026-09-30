package com.servomap.android

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

enum class Fuel(val code: String) {
    U91("U91"), E10("E10"), U95("U95"), U98("U98"), Diesel("Diesel");

    companion object {
        fun fromCode(code: String): Fuel = entries.firstOrNull { it.code == code } ?: U91
    }
}

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
    /** The brand family this station belongs to (BP, Shell, ...); unknown brands are Independent. */
    val family: BrandFamily get() = Brands.resolve(brand)

    fun price(fuel: Fuel): FuelPrice? = prices.firstOrNull { it.fuel == fuel.code }

    /** A price older than a week may be from a station that stopped reporting: shown, but not ranked. */
    fun hasCurrentPrice(fuel: Fuel, now: Instant = Instant.now()): Boolean {
        val p = price(fuel) ?: return false
        val updated = runCatching { Instant.parse(p.updatedAt) }.getOrNull() ?: return false
        return now.epochSecond - updated.epochSecond <= CURRENT_FOR_SECONDS
    }

    /** Whether the [fuel] price was reported within the last [hours] hours; always true when [hours] is null. */
    fun reportedWithin(fuel: Fuel, hours: Int?, now: Instant = Instant.now()): Boolean {
        if (hours == null) return true
        val updated = price(fuel)?.let { runCatching { Instant.parse(it.updatedAt) }.getOrNull() } ?: return false
        return now.epochSecond - updated.epochSecond <= hours * 3600L
    }

    companion object {
        const val CURRENT_FOR_SECONDS = 7L * 86_400
    }
}

@Serializable
data class Envelope<T>(val data: T)

/** What the filter sheet narrows the loaded stations to: brand family ids to hide and how recent a price must be. */
data class Filters(val hiddenBrands: Set<String> = emptySet(), val freshHours: Int? = null) {
    val active: Boolean get() = hiddenBrands.isNotEmpty() || freshHours != null

    fun apply(stations: List<Station>, fuel: Fuel): List<Station> =
        stations.filter { it.family.id !in hiddenBrands && it.reportedWithin(fuel, freshHours) }

    companion object {
        /** The "reported within" choices: label to hours (null means any age). */
        val freshChoices: List<Pair<String, Int?>> = listOf("6 h" to 6, "24 h" to 24, "3 days" to 72, "A week" to null)
    }
}

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
