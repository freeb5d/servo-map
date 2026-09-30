package com.servomap.android

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant

// Wire types for /api/v1/auth and /api/v1/me. They mirror packages/shared/src/account.ts, which owns the contract.

@Serializable
data class AccountDto(
    val id: String,
    val provider: String,
    val email: String? = null,
    val name: String? = null,
    val picture: String? = null,
    val createdAt: String = "",
)

@Serializable
data class SessionDto(val token: String, val account: AccountDto)

@Serializable
data class FillUpDto(
    val id: String,
    val date: String,
    val stationId: String,
    val stationName: String,
    val brand: String,
    val fuel: String,
    val litres: Double,
    val centsPerLitre: Double,
    val areaAverage: Double? = null,
)

@Serializable
data class CarDto(
    val vehicleId: String? = null,
    val name: String,
    val body: String = "hatch",
    val fuel: String,
    val tankLitres: Int,
    val catalogueTankLitres: Int? = null,
)

@Serializable
data class HomeDto(val lat: Double, val lng: Double)

@Serializable
data class AlertsDto(
    val priceDrop: Boolean = false,
    val cycleLow: Boolean = false,
    val quietStart: Int = 22,
    val quietEnd: Int = 7,
    val home: HomeDto? = null,
)

@Serializable
data class MeDto(
    val account: AccountDto,
    val savedStationIds: List<String> = emptyList(),
    val fillUps: List<FillUpDto> = emptyList(),
    val car: CarDto? = null,
    val alerts: AlertsDto = AlertsDto(),
)

@Serializable
private data class SignInBody(val identityToken: String, val name: String? = null)

@Serializable
private data class SavedBody(val stationIds: List<String>)

@Serializable
private data class FillUpsBody(val fillUps: List<FillUpDto>)

// Mapping between the on-device records and the synced ones.

fun FillUp.toDto() = FillUpDto(
    id = id, date = Instant.ofEpochSecond(epochMs / 1000).toString(), stationId = stationId, stationName = stationName,
    brand = brand, fuel = fuel, litres = litres, centsPerLitre = centsPerLitre, areaAverage = areaAverage,
)

fun FillUpDto.toFillUp(): FillUp? {
    val at = runCatching { Instant.parse(date) }.getOrNull() ?: return null
    return FillUp(id, at.toEpochMilli(), stationId, stationName, brand, fuel, litres, centsPerLitre, areaAverage)
}

const val DEFAULT_CAR_NAME = "My car"

fun Car.toDto() = CarDto(vehicleId, name.ifBlank { DEFAULT_CAR_NAME }, body, fuel, tankLitres, catalogueTankLitres)

fun CarDto.toCar() = Car(if (name == DEFAULT_CAR_NAME) "" else name, fuel, tankLitres, vehicleId, body, catalogueTankLitres)

/** A car the user has not set up: no catalogue id and no name of their own. */
val Car.isDefault: Boolean get() = vehicleId == null && name.isBlank()

fun AlertSettings.toDto() = AlertsDto(
    priceDrop, cycleLow, quietStart, quietEnd,
    if (homeLat != null && homeLng != null) HomeDto(homeLat, homeLng) else null,
)

/** Takes the server's switches and hours; a home set on this phone is kept when the account has none. */
fun AlertsDto.applyTo(local: AlertSettings) = AlertSettings(
    priceDrop, cycleLow, quietStart, quietEnd, home?.lat ?: local.homeLat, home?.lng ?: local.homeLng,
)

/** A failed account call. [code] is the HTTP status, 401 for an expired session, or 0 when offline. */
class ApiFailure(val code: Int) : Exception("HTTP $code")

/** Signed-in calls to /api/v1/auth and /api/v1/me. */
@OptIn(ExperimentalSerializationApi::class)
object AccountApi {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true; explicitNulls = false }

    suspend fun signIn(provider: String, identityToken: String, name: String?): SessionDto =
        call("POST", "auth/$provider", null, json.encodeToString(SignInBody.serializer(), SignInBody(identityToken, name)), SessionDto.serializer())!!

    suspend fun me(token: String): MeDto = call("GET", "me", token, null, MeDto.serializer())!!
    suspend fun deleteAccount(token: String) { call("DELETE", "me", token, null, null) }

    suspend fun putSaved(token: String, ids: List<String>) {
        call("PUT", "me/saved", token, json.encodeToString(SavedBody.serializer(), SavedBody(ids)), null)
    }

    suspend fun putFillUps(token: String, fills: List<FillUpDto>) {
        if (fills.isEmpty()) return
        call("PUT", "me/fillups", token, json.encodeToString(FillUpsBody.serializer(), FillUpsBody(fills)), null)
    }

    suspend fun deleteFillUp(token: String, id: String) { call("DELETE", "me/fillups/$id", token, null, null) }
    suspend fun putCar(token: String, car: CarDto) { call("PUT", "me/car", token, json.encodeToString(CarDto.serializer(), car), null) }
    suspend fun putAlerts(token: String, alerts: AlertsDto) {
        call("PUT", "me/alerts", token, json.encodeToString(AlertsDto.serializer(), alerts), null)
    }

    private suspend fun <T> call(method: String, path: String, token: String?, body: String?, reply: KSerializer<T>?): T? =
        withContext(Dispatchers.IO) {
            val conn = URL(BuildConfig.API_BASE + "/" + path).openConnection() as HttpURLConnection
            try {
                conn.requestMethod = method
                conn.connectTimeout = 10_000
                conn.readTimeout = 20_000
                token?.let { conn.setRequestProperty("Authorization", "Bearer $it") }
                if (body != null) {
                    conn.doOutput = true
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.outputStream.use { it.write(body.toByteArray()) }
                }
                val status = try { conn.responseCode } catch (e: java.io.IOException) { throw ApiFailure(0) }
                if (status == 401) throw ApiFailure(401)
                if (status !in 200..299) throw ApiFailure(status)
                if (reply == null) null
                else json.decodeFromString(Envelope.serializer(reply), conn.inputStream.bufferedReader().use { it.readText() }).data
            } finally {
                conn.disconnect()
            }
        }
}

/** The session token, kept in encrypted preferences (plain ones only if the keystore is unavailable). */
class TokenStore(context: Context) {
    private val prefs: SharedPreferences = try {
        val key = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
        EncryptedSharedPreferences.create(
            context, "session", key,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    } catch (e: Exception) {
        context.getSharedPreferences("session_fallback", Context.MODE_PRIVATE)
    }

    fun read(): String? = prefs.getString("token", null)
    fun save(token: String) = prefs.edit().putString("token", token).apply()
    fun clear() = prefs.edit().remove("token").apply()
}

/** Google sign-in through Credential Manager, returning the ID token the worker verifies. */
object GoogleSignIn {
    class Cancelled : Exception()

    /** Whether this build has a Google web client id; without one the sign-in button is hidden. */
    val configured: Boolean get() = BuildConfig.GOOGLE_CLIENT_ID.isNotBlank()

    suspend fun idToken(activity: Activity): Pair<String, String?> {
        val option = GetSignInWithGoogleOption.Builder(BuildConfig.GOOGLE_CLIENT_ID).build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        try {
            val credential = CredentialManager.create(activity).getCredential(activity, request).credential
            if (credential is CustomCredential && credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                val google = GoogleIdTokenCredential.createFrom(credential.data)
                return google.idToken to google.displayName
            }
            throw IllegalStateException("Unexpected credential")
        } catch (e: GetCredentialCancellationException) {
            throw Cancelled()
        }
    }
}

tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
