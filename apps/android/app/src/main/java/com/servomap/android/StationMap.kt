package com.servomap.android

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AColor
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.drawable.BitmapDrawable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker

/** OpenStreetMap tiles via osmdroid, so no API key is needed. Each station is a price pill in its tier colour. */
@Composable
fun StationMap(
    stations: List<Station>,
    tiers: Map<String, Tier>,
    fuel: Fuel,
    centre: Pair<Double, Double>,
    onSelect: (Station) -> Unit,
) {
    val context = LocalContext.current
    val dark = isSystemInDarkTheme()
    AndroidView(
        modifier = Modifier,
        factory = { ctx ->
            Configuration.getInstance().userAgentValue = ctx.packageName
            MapView(ctx).apply {
                setTileSource(TileSourceFactory.MAPNIK)
                setMultiTouchControls(true)
                controller.setZoom(13.5)
                controller.setCenter(GeoPoint(centre.first, centre.second))
            }
        },
        update = { map ->
            map.controller.animateTo(GeoPoint(centre.first, centre.second))
            map.overlays.clear()
            stations.forEach { s ->
                val price = s.price(fuel) ?: return@forEach
                map.overlays.add(Marker(map).apply {
                    position = GeoPoint(s.lat, s.lng)
                    icon = pill(context, "%.1f".format(price.price), tierColor(tiers[s.id], dark).toArgb())
                    setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                    setOnMarkerClickListener { _, _ -> onSelect(s); true }
                })
            }
            map.invalidate()
        },
        onRelease = { it.onDetach() },
    )
}

private fun pill(context: Context, text: String, colour: Int): BitmapDrawable {
    val d = context.resources.displayMetrics.density
    val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AColor.WHITE; textSize = 12 * d; isFakeBoldText = true
    }
    val w = (textPaint.measureText(text) + 14 * d).toInt()
    val h = (24 * d).toInt()
    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val c = Canvas(bmp)
    c.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), h / 2f, h / 2f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = colour })
    c.drawText(text, 7 * d, h / 2f - (textPaint.ascent() + textPaint.descent()) / 2f, textPaint)
    return BitmapDrawable(context.resources, bmp)
}
