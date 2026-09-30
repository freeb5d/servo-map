package com.servomap.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/** Read-only client for the public ServoMap API, the same endpoints the web and iOS apps use. */
object Api {
    private val json = Json { ignoreUnknownKeys = true }
    private const val STATION_LIMIT = 500

    suspend fun nearby(fuel: Fuel, lat: Double, lng: Double, radiusKm: Int): List<Station> =
        fetch(url("stations", "fuel" to fuel.code, "lat" to "$lat", "lng" to "$lng",
            "radius" to "$radiusKm", "limit" to "$STATION_LIMIT", "sort" to "price_asc"))

    suspend fun search(text: String, fuel: Fuel): List<Station> =
        fetch(url("stations", "q" to text, "fuel" to fuel.code, "limit" to "100", "sort" to "price_asc"))

    private fun url(path: String, vararg params: Pair<String, String>): String =
        BuildConfig.API_BASE + "/" + path + "?" +
            params.joinToString("&") { (k, v) -> k + "=" + URLEncoder.encode(v, "UTF-8") }

    private suspend fun fetch(url: String): List<Station> = withContext(Dispatchers.IO) {
        val conn = URL(url).openConnection() as HttpURLConnection
        try {
            conn.connectTimeout = 10_000
            conn.readTimeout = 15_000
            check(conn.responseCode == 200) { "Server returned ${conn.responseCode}" }
            parse(conn.inputStream.bufferedReader().use { it.readText() })
        } finally {
            conn.disconnect()
        }
    }

    fun parse(body: String): List<Station> =
        json.decodeFromString(Envelope.serializer(ListSerializer(Station.serializer())), body).data
}
