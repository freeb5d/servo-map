package com.servomap.android

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** A family of raw upstream brand names shown as one brand (mirrors packages/shared brands.ts). */
data class BrandFamily(
    val id: String,
    val name: String,
    /** Short monogram printed on the tile for a brand without a logo file. */
    val seal: String,
    val background: Color,
    val foreground: Color,
    /** Lower-case raw names that belong to this family, matched exactly. */
    val names: List<String> = emptyList(),
    /** Lower-case fragments; a raw name containing one belongs here. */
    val contains: List<String> = emptyList(),
)

object Brands {
    val independent = BrandFamily("independent", "Independent", "IND", Color(0xFF5A5750), Color.White, listOf("independent"))

    val all: List<BrandFamily> = listOf(
        BrandFamily("ampol", "Ampol", "AMP", Color(0xFF0B2D72), Color.White, contains = listOf("ampol")),
        BrandFamily("bp", "BP", "BP", Color(0xFF007A33), Color.White, names = listOf("bp")),
        BrandFamily("shell", "Shell", "SHL", Color(0xFFFFD200), Color(0xFFA30D14), names = listOf("reddy express", "coles express"), contains = listOf("shell")),
        BrandFamily("7-eleven", "7-Eleven", "7E", Color(0xFF006B4F), Color.White, names = listOf("7-eleven", "7 eleven")),
        BrandFamily("caltex", "Caltex", "CTX", Color(0xFFC8102E), Color.White, contains = listOf("caltex")),
        BrandFamily("mobil", "Mobil", "MOB", Color(0xFF1E4494), Color.White, contains = listOf("mobil")),
        BrandFamily("metro", "Metro", "MET", Color(0xFF003DA5), Color.White, contains = listOf("metro")),
        BrandFamily("united", "United", "UTD", Color(0xFFB5122D), Color.White, names = listOf("united")),
        BrandFamily("speedway", "Speedway", "SPD", Color(0xFF1F1F1F), Color.White, names = listOf("speedway")),
        BrandFamily("liberty", "Liberty", "LIB", Color(0xFF00539B), Color.White, names = listOf("liberty")),
        BrandFamily("puma", "Puma", "PUM", Color(0xFFB71C24), Color.White, names = listOf("puma")),
        BrandFamily("astron", "Astron", "AST", Color(0xFFF37021), Color(0xFF1F1F1F), names = listOf("astron")),
        BrandFamily("u-go", "U-Go", "UGO", Color(0xFF7AC143), Color(0xFF1F1F1F), names = listOf("u-go", "ugo")),
        BrandFamily("costco", "Costco", "CST", Color(0xFF005DAA), Color.White, names = listOf("costco")),
        independent,
    )

    /** Resolves a raw upstream brand name to its family; unknown names fall back to Independent. */
    fun resolve(raw: String): BrandFamily {
        val key = raw.trim().lowercase()
        all.firstOrNull { key in it.names }?.let { return it }
        all.firstOrNull { f -> f.contains.any { key.contains(it) } }?.let { return it }
        return independent
    }
}

/** The brand's logo on a white tile, or its monogram tile when there is no logo file. */
@Composable
fun BrandMark(raw: String, size: Dp = 40.dp, modifier: Modifier = Modifier) {
    val family = remember(raw) { Brands.resolve(raw) }
    val context = LocalContext.current
    val logo = remember(family.id) {
        context.resources.getIdentifier("brand_" + family.id.replace('-', '_'), "drawable", context.packageName)
    }
    val shape = RoundedCornerShape(size / 4)
    if (logo != 0) {
        Box(modifier.size(size).clip(shape).background(Color.White).border(BorderStroke(1.dp, MaterialTheme.colorScheme.outline), shape).padding(size / 10)) {
            Image(painterResource(logo), contentDescription = family.name, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
        }
    } else {
        Box(modifier.size(size).clip(shape).background(family.background), contentAlignment = Alignment.Center) {
            Text(family.seal, color = family.foreground, fontSize = (size.value * 0.28f).sp, fontWeight = FontWeight.Bold)
        }
    }
}
