package com.servomap.android

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/** 素 design tokens (packages/design-tokens): paper and sumi ink, with price tiers the only chroma. */
object Ink {
    val paper = Color(0xFFFDFDFB); val paperDark = Color(0xFF21211F)
    val wash = Color(0xFFEFEEE9); val washDark = Color(0xFF2A2927)
    val ink = Color(0xFF2A2927); val inkDark = Color(0xFFE6E3DB)
    val ink2 = Color(0xFF5A5750); val ink2Dark = Color(0xFFABA69B)
    val line = Color(0xFFD9D6CE); val lineDark = Color(0xFF3A3935)
    val cheap = Color(0xFF3D6848); val cheapDark = Color(0xFF93B597)
    val mid = Color(0xFF85601C); val midDark = Color(0xFFD2B271)
    val expensive = Color(0xFF9A3B2B); val expensiveDark = Color(0xFFDE9A8A)
}

fun tierColor(tier: Tier?, dark: Boolean): Color = when (tier) {
    Tier.Cheap -> if (dark) Ink.cheapDark else Ink.cheap
    Tier.Mid -> if (dark) Ink.midDark else Ink.mid
    Tier.Expensive -> if (dark) Ink.expensiveDark else Ink.expensive
    null -> if (dark) Ink.ink2Dark else Ink.ink2
}

@Composable
fun ServoTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val scheme = if (dark) darkColorScheme(
        primary = Ink.inkDark, onPrimary = Ink.paperDark, background = Ink.paperDark, surface = Ink.paperDark,
        onBackground = Ink.inkDark, onSurface = Ink.inkDark, surfaceVariant = Ink.washDark,
        onSurfaceVariant = Ink.ink2Dark, outline = Ink.lineDark,
    ) else lightColorScheme(
        primary = Ink.ink, onPrimary = Ink.paper, background = Ink.paper, surface = Ink.paper,
        onBackground = Ink.ink, onSurface = Ink.ink, surfaceVariant = Ink.wash,
        onSurfaceVariant = Ink.ink2, outline = Ink.line,
    )
    MaterialTheme(colorScheme = scheme, content = content)
}
