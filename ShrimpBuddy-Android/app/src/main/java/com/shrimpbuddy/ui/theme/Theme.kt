package com.shrimpbuddy.ui.theme

import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// ─── Shrimp Buddy Dark Design Tokens ──────────────────────────────────────────
// Palette derived from web UI (#001142 / #0060ab) adapted for dark mobile

// Backgrounds
val SBBg               = Color(0xFF060E1C)   // page background
val SBSurface          = Color(0xFF0C1A2F)   // card surface
val SBSurfaceElevated  = Color(0xFF112238)   // raised cards
val SBSurfaceHigh      = Color(0xFF162E48)   // highlighted rows
val SBOutline          = Color(0xFF1E3355)   // borders
val SBOutlineVariant   = Color(0xFF284470)   // softer borders

// Brand Blues
val SBPrimary          = Color(0xFF4487E0)   // main interactive
val SBPrimaryLight     = Color(0xFF7AB0FF)   // secondary / highlight
val SBPrimaryDim       = Color(0xFF1A3560)   // tinted bg areas

// Text
val SBOnSurface        = Color(0xFFDCE9FF)   // primary text
val SBOnSurfaceVariant = Color(0xFF6A8CB5)   // muted text
val SBOnSurfaceDim     = Color(0xFF3D5A82)   // very muted

// Semantic
val SBSuccess          = Color(0xFF35C96E)
val SBWarning          = Color(0xFFF0A020)
val SBError            = Color(0xFFF04545)
val SBInfo             = Color(0xFF7AB0FF)

val SBSuccessBg        = Color(0xFF0A2D1A)
val SBWarningBg        = Color(0xFF2A1E06)
val SBErrorBg          = Color(0xFF2A0A0A)
val SBInfoBg           = Color(0xFF0A1E38)

// Legacy aliases
val SBSecondary        = SBPrimary
val SBSurfaceLow       = SBSurface
val SBSurfaceContainer = SBSurfaceElevated
val SBPrimaryContainer = SBPrimaryDim
val SBOnPrimaryContainer = SBPrimaryLight

private val SBColorScheme = darkColorScheme(
    primary              = SBPrimary,
    onPrimary            = Color.White,
    primaryContainer     = SBPrimaryDim,
    onPrimaryContainer   = SBPrimaryLight,
    secondary            = SBPrimaryLight,
    onSecondary          = Color.White,
    background           = SBBg,
    onBackground         = SBOnSurface,
    surface              = SBSurface,
    onSurface            = SBOnSurface,
    surfaceVariant       = SBSurfaceElevated,
    onSurfaceVariant     = SBOnSurfaceVariant,
    outline              = SBOutline,
    error                = SBError,
    onError              = Color.White
)

@Composable
fun ShrimpBuddyTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = SBColorScheme,
        typography  = Typography(),
        content     = content
    )
}

// ─── Status Color Helpers ──────────────────────────────────────────────────────

fun statusColor(status: String): Color = when (status.uppercase()) {
    "STABLE"    -> SBSuccess
    "ATTENTION" -> SBWarning
    "CRITICAL"  -> SBError
    "HIGH"      -> SBError
    "MEDIUM"    -> SBWarning
    "LOW"       -> SBSuccess
    "READY"     -> SBSuccess
    "SOON"      -> SBWarning
    "GROWING"   -> SBInfo
    else        -> SBOnSurfaceVariant
}

fun statusBgColor(status: String): Color = when (status.uppercase()) {
    "STABLE"    -> SBSuccessBg
    "ATTENTION" -> SBWarningBg
    "CRITICAL"  -> SBErrorBg
    "HIGH"      -> SBErrorBg
    "MEDIUM"    -> SBWarningBg
    "LOW"       -> SBSuccessBg
    else        -> SBSurfaceElevated
}
