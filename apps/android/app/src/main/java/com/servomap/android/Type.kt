package com.servomap.android

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/** Shippori Mincho, the design system's display face for titles and prices (same files as the iPhone app). */
val Display = FontFamily(
    Font(R.font.shippori_mincho_medium, FontWeight.Normal),
    Font(R.font.shippori_mincho_medium, FontWeight.Medium),
    Font(R.font.shippori_mincho_semibold, FontWeight.SemiBold),
    Font(R.font.shippori_mincho_semibold, FontWeight.Bold),
)

val ServoTypography = Typography(
    headlineLarge = TextStyle(fontFamily = Display, fontWeight = FontWeight.Medium, fontSize = 34.sp, lineHeight = 44.sp, letterSpacing = 0.3.sp),
    headlineMedium = TextStyle(fontFamily = Display, fontWeight = FontWeight.SemiBold, fontSize = 28.sp, lineHeight = 36.sp),
    headlineSmall = TextStyle(fontFamily = Display, fontWeight = FontWeight.SemiBold, fontSize = 22.sp, lineHeight = 30.sp),
    titleLarge = TextStyle(fontFamily = Display, fontWeight = FontWeight.SemiBold, fontSize = 22.sp, lineHeight = 30.sp),
    titleMedium = TextStyle(fontFamily = Display, fontWeight = FontWeight.SemiBold, fontSize = 18.sp, lineHeight = 24.sp),
)
