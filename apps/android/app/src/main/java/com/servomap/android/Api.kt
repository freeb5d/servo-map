package com.servomap.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/** Read-only client for the public ServoMap API, the same endpoints the web and iOS apps use. */
object Api {
    private val json = Json { ignoreUnknownKeys = true }
    private const val STATION_LIMIT = 500

    suspend fun nearby(fuel: Fuel, lat: Double, lng: Double, radiusKm: Int): List<Station> =
        stations(url("stations", "fuel" to fuel.code, "lat" to "$lat", "lng" to "$lng",
            "radius" to "$radiusKm", "limit" to "$STATION_LIMIT", "sort" to "price_asc"))

    suspend fun search(text: String, fuel: Fuel): List<Station> =
        stations(url("stations", "q" to text, "fuel" to fuel.code, "limit" to "100", "sort" to "price_asc"))

    suspend fun station(id: String): Station =
        get(url("stations/" + URLEncoder.encode(id, "UTF-8")), ::parseOne)

    /** States with at least one reporting station, e.g. ["nsw", "wa"]. */
    suspend fun liveStates(): List<String> =
        data(url("metadata"), MapSerializer(String.serializer(), StateMeta.serializer()))
            .filter { it.value.stationCount > 0 }.keys.sorted()

    /** Daily history for every fuel in a state, oldest first. */
    suspend fun trends(state: String): List<Snapshot> =
        data(url("trends", "state" to state), Trend.serializer()).series.sortedBy { it.date }

    suspend fun cityInsights(fuel: Fuel): List<CityInsight> =
        data(url("insights/cities", "fuel" to fuel.code), CityInsights.serializer()).cities

    private fun url(path: String, vararg params: Pair<String, String>): String =
        BuildConfig.API_BASE + "/" + path +
            if (params.isEmpty()) "" else "?" + params.joinToString("&") { (k, v) -> k + "=" + URLEncoder.encode(v, "UTF-8") }

    private suspend fun stations(url: String): List<Station> = get(url, ::parse)

    private suspend fun <T> data(url: String, serializer: KSerializer<T>): T =
        get(url) { json.decodeFromString(Envelope.serializer(serializer), it).data }

    private suspend fun <T> get(url: String, decode: (String) -> T): T = withContext(Dispatchers.IO) {
        val conn = URL(url).openConnection() as HttpURLConnection
        try {
            conn.connectTimeout = 10_000
            conn.readTimeout = 15_000
            check(conn.responseCode == 200) { "Server returned ${conn.responseCode}" }
            decode(conn.inputStream.bufferedReader().use { it.readText() })
        } finally {
            conn.disconnect()
        }
    }

    fun parse(body: String): List<Station> =
        json.decodeFromString(Envelope.serializer(ListSerializer(Station.serializer())), body).data
}

fun parseOne(body: String): Station =
    Json { ignoreUnknownKeys = true }.decodeFromString(Envelope.serializer(Station.serializer()), body).data
