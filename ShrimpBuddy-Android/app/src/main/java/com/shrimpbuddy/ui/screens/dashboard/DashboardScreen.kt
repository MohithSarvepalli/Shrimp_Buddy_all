package com.shrimpbuddy.ui.screens.dashboard

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.shrimpbuddy.models.DashboardStats
import com.shrimpbuddy.network.RetrofitClient
import com.shrimpbuddy.ui.theme.*
import kotlinx.coroutines.launch

// ─── Dashboard ────────────────────────────────────────────────────────────────

@Composable
fun DashboardScreen() {
    val scope = rememberCoroutineScope()
    var stats    by remember { mutableStateOf<DashboardStats?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var error    by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        scope.launch {
            try {
                val res = RetrofitClient.api.getDashboard()
                stats = res.body()?.data
            } catch (e: Exception) { error = e.message }
            isLoading = false
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(SBBg)
    ) {
        // ── Dark Header ──────────────────────────────────────────────────────
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(SBSurface)
                .padding(horizontal = 18.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text("BLUE OCEAN AQUAFARM",
                    fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
                    color = SBOnSurfaceVariant, letterSpacing = 1.2.sp)
                Text("Dashboard",
                    fontSize = 22.sp, fontWeight = FontWeight.Bold, color = SBOnSurface)
            }
            IconButton(onClick = {}) {
                Box(
                    modifier = Modifier.size(40.dp)
                        .background(SBSurfaceElevated, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.Notifications, "Alerts",
                        tint = SBPrimaryLight, modifier = Modifier.size(20.dp))
                }
            }
        }
        Divider(color = SBOutline, thickness = 0.8.dp)

        when {
            isLoading -> Box(Modifier.fillMaxSize(), Alignment.Center) {
                CircularProgressIndicator(color = SBPrimary, strokeWidth = 2.5.dp)
            }
            error != null -> Box(Modifier.fillMaxSize().padding(24.dp), Alignment.Center) {
                Text("⚠️ $error", color = SBError, fontSize = 14.sp)
            }
            stats != null -> DashboardContent(stats!!)
        }
    }
}

@Composable
fun DashboardContent(stats: DashboardStats) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // ── Alert Banners ────────────────────────────────────────────────────
        stats.alerts.forEach { alert ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(statusBgColor(alert.severity), RoundedCornerShape(12.dp))
                    .border(0.8.dp, statusColor(alert.severity).copy(0.25f), RoundedCornerShape(12.dp))
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(if (alert.severity == "critical") "🚨" else "⚠️", fontSize = 14.sp)
                Spacer(Modifier.width(10.dp))
                Text(alert.message, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                    color = statusColor(alert.severity), modifier = Modifier.weight(1f))
                Text(
                    alert.severity.uppercase(),
                    fontSize = 9.sp, fontWeight = FontWeight.Bold,
                    color = statusColor(alert.severity),
                    modifier = Modifier
                        .background(statusBgColor(alert.severity), RoundedCornerShape(20.dp))
                        .padding(horizontal = 7.dp, vertical = 3.dp)
                )
            }
        }

        // ── 4 Stat Cards ─────────────────────────────────────────────────────
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            MetricCard("${stats.stablePonds}",    "Stable",     SBSuccess,      Modifier.weight(1f))
            MetricCard("${stats.attentionPonds ?: 0}", "Attention", SBWarning,  Modifier.weight(1f))
            MetricCard("${stats.criticalPonds}",  "Critical",   SBError,        Modifier.weight(1f))
            LatestFeedCard(stats.feedLoggedToday, Modifier.weight(1f))
        }

        // ── Feed Trend Chart ─────────────────────────────────────────────────
        SBCard {
            Column {
                Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween, Alignment.CenterVertically) {
                    Text("DAILY FEED TREND", fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
                        color = SBOnSurfaceVariant, letterSpacing = 0.5.sp)
                    Text("Last 7 days", fontSize = 10.sp, color = SBOnSurfaceDim)
                }
                Spacer(Modifier.height(14.dp))
                if (stats.feedTrend.isNotEmpty()) {
                    FeedLineChart(
                        data = stats.feedTrend.map { it.value.toFloat() },
                        labels = stats.feedTrend.map { it.label },
                        modifier = Modifier.fillMaxWidth().height(160.dp)
                    )
                } else {
                    Box(Modifier.fillMaxWidth().height(100.dp), Alignment.Center) {
                        Text("No feed data yet", fontSize = 12.sp, color = SBOnSurfaceVariant)
                    }
                }
            }
        }

        // ── Section Feed Logs ─────────────────────────────────────────────────
        SBCard {
            Column {
                Text("LATEST FEED — BY SECTION",
                    fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
                    color = SBOnSurfaceVariant, letterSpacing = 0.5.sp,
                    modifier = Modifier.padding(bottom = 12.dp))

                if (stats.sectionFeedLogs.isEmpty()) {
                    Text("No feed logged today", fontSize = 12.sp, color = SBOnSurfaceVariant,
                        modifier = Modifier.fillMaxWidth().padding(8.dp),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                } else {
                    stats.sectionFeedLogs.forEachIndexed { idx, log ->
                        Row(
                            Modifier.fillMaxWidth().padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier.size(36.dp)
                                    .background(SBPrimaryDim, CircleShape),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(log.sectionName.take(1),
                                    fontSize = 13.sp, fontWeight = FontWeight.Bold,
                                    color = SBPrimaryLight)
                            }
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) {
                                Text(log.sectionName, fontSize = 13.sp,
                                    fontWeight = FontWeight.SemiBold, color = SBOnSurface)
                                Text(log.time, fontSize = 11.sp, color = SBOnSurfaceVariant)
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text("${log.feedKg} kg", fontSize = 14.sp,
                                    fontWeight = FontWeight.Bold, color = SBPrimaryLight)
                                StatusBadge(log.status)
                            }
                        }
                        if (idx < stats.sectionFeedLogs.lastIndex) {
                            Divider(color = SBOutline, thickness = 0.8.dp)
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(8.dp))
    }
}

// ─── Shared Card Shell ────────────────────────────────────────────────────────

@Composable
fun SBCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(SBSurface, RoundedCornerShape(14.dp))
            .border(0.8.dp, SBOutline, RoundedCornerShape(14.dp))
            .padding(14.dp),
        content = content
    )
}

// ─── Metric Card ─────────────────────────────────────────────────────────────

@Composable
fun MetricCard(value: String, label: String, color: Color, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .background(SBSurface, RoundedCornerShape(12.dp))
            .border(0.8.dp, SBOutline, RoundedCornerShape(12.dp))
            .padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(value, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = color)
        Text(label, fontSize = 10.sp, fontWeight = FontWeight.Medium,
            color = SBOnSurfaceVariant, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
    }
}

@Composable
fun LatestFeedCard(kg: Double, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .background(SBSurface, RoundedCornerShape(12.dp))
            .border(0.8.dp, SBOutline, RoundedCornerShape(12.dp))
            .padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("${kg.toInt()}", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = SBPrimary)
        Text("kg", fontSize = 10.sp, color = SBPrimaryLight)
        Text("Today's Feed", fontSize = 10.sp, fontWeight = FontWeight.Medium,
            color = SBOnSurfaceVariant,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center)
    }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

@Composable
fun StatusBadge(status: String) {
    Text(
        status.replaceFirstChar { it.uppercase() },
        fontSize = 9.sp, fontWeight = FontWeight.Bold,
        color = statusColor(status),
        modifier = Modifier
            .background(statusBgColor(status), RoundedCornerShape(20.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp)
    )
}

// ─── Feed Line Chart (Canvas) ─────────────────────────────────────────────────

@Composable
fun FeedLineChart(
    data: List<Float>,
    labels: List<String>,
    modifier: Modifier = Modifier
) {
    if (data.size < 2) return
    val primaryColor = SBPrimary
    val accentColor  = SBPrimaryLight
    val gridColor    = SBOutline
    val labelColor   = SBOnSurfaceVariant

    Canvas(modifier = modifier.padding(bottom = 20.dp)) {
        val w    = size.width
        val h    = size.height
        val padL = 36f; val padR = 16f; val padT = 8f; val padB = 8f
        val plotW = w - padL - padR
        val plotH = h - padT - padB

        val minV = data.min(); val maxV = data.max()
        val range = if (maxV - minV == 0f) 1f else maxV - minV

        fun xOf(i: Int) = padL + i * plotW / (data.size - 1)
        fun yOf(v: Float) = padT + plotH - (v - minV) / range * plotH

        // Grid lines (3 horizontal)
        repeat(3) { i ->
            val y = padT + i * plotH / 2
            drawLine(gridColor, Offset(padL, y), Offset(w - padR, y),
                strokeWidth = 0.8f, pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(4f, 6f)))
        }

        // Area fill
        val path = Path().apply {
            moveTo(xOf(0), yOf(data[0]))
            data.forEachIndexed { i, v -> if (i > 0) lineTo(xOf(i), yOf(v)) }
            lineTo(xOf(data.lastIndex), padT + plotH)
            lineTo(padL, padT + plotH)
            close()
        }
        drawPath(path, Brush.verticalGradient(
            colors = listOf(primaryColor.copy(alpha = 0.28f), Color.Transparent),
            startY = padT, endY = padT + plotH
        ))

        // Line
        val linePath = Path().apply {
            moveTo(xOf(0), yOf(data[0]))
            data.forEachIndexed { i, v -> if (i > 0) lineTo(xOf(i), yOf(v)) }
        }
        drawPath(linePath, primaryColor, style = Stroke(2.5f, cap = StrokeCap.Round))

        // Dots
        data.forEachIndexed { i, v ->
            drawCircle(accentColor, 5f, Offset(xOf(i), yOf(v)))
        }
    }
}
