package com.shrimpbuddy.ui.screens.finance

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.shrimpbuddy.models.*
import com.shrimpbuddy.network.RetrofitClient
import com.shrimpbuddy.ui.navigation.FinanceNavCard
import com.shrimpbuddy.ui.screens.dashboard.SBCard
import com.shrimpbuddy.ui.screens.dashboard.StatusBadge
import com.shrimpbuddy.ui.screens.ops.OpsAppBar
import com.shrimpbuddy.ui.theme.*
import kotlinx.coroutines.launch

// ─── Finance Overview ─────────────────────────────────────────────────────────

@Composable
fun FinanceScreen(onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var transactions by remember { mutableStateOf<List<FinanceTransaction>>(emptyList()) }
    var isLoading    by remember { mutableStateOf(true) }
    var showAdd      by remember { mutableStateOf(false) }

    val expenses   = transactions.filter { it.type == "Expense" }
    val totalExp   = expenses.sumOf { it.amount }
    val feedCost   = expenses.filter { it.category == "Feed" }.sumOf { it.amount }
    val chemCost   = expenses.filter { it.category == "Chemical" }.sumOf { it.amount }
    val otherCost  = totalExp - feedCost - chemCost

    // Category breakdown
    val breakdown = expenses.groupBy { it.category }.map { (cat, list) ->
        val color = when (cat) {
            "Feed"     -> SBPrimary
            "Chemical" -> SBWarning
            "Labour"   -> SBSuccess
            "Harvest"  -> Color(0xFF9B59B6)
            else       -> SBOnSurfaceVariant
        }
        Triple(cat, list.sumOf { it.amount }, color)
    }.sortedByDescending { it.second }

    LaunchedEffect(Unit) {
        scope.launch {
            transactions = RetrofitClient.api.getFinance().body()?.data ?: emptyList()
            isLoading = false
        }
    }

    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("Finance", onBack) {
            Box(
                Modifier.background(SBPrimary, RoundedCornerShape(10.dp))
                    .clickable { showAdd = true }
                    .padding(horizontal = 12.dp, vertical = 7.dp)
            ) {
                Text("+ Entry", fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                    color = Color.White)
            }
            Spacer(Modifier.width(10.dp))
        }

        if (isLoading) {
            Box(Modifier.fillMaxSize(), Alignment.Center) {
                CircularProgressIndicator(color = SBPrimary, strokeWidth = 2.5.dp)
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(14.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                // Total expense hero
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(SBSurfaceElevated, RoundedCornerShape(14.dp))
                            .border(0.8.dp, SBOutline, RoundedCornerShape(14.dp))
                            .padding(16.dp)
                    ) {
                        Text("TOTAL EXPENSES", fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
                            color = SBOnSurfaceVariant, letterSpacing = 0.6.sp)
                        Text("₹${totalExp.toInt()}", fontSize = 34.sp, fontWeight = FontWeight.Bold,
                            color = SBOnSurface)
                        Text("All time · ${expenses.size} entries",
                            fontSize = 12.sp, color = SBOnSurfaceVariant)
                    }
                }

                // 3 cost cards
                item {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        CostCard("Feed Cost",     feedCost,  SBPrimary,           Modifier.weight(1f))
                        CostCard("Chemical Cost", chemCost,  SBWarning,           Modifier.weight(1f))
                        CostCard("Other",         otherCost, SBOnSurfaceVariant,  Modifier.weight(1f))
                    }
                }

                // Expense breakdown bar chart
                if (breakdown.isNotEmpty()) {
                    item {
                        SBCard {
                            Text("EXPENSE BREAKDOWN", fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
                                color = SBOnSurfaceVariant, letterSpacing = 0.5.sp,
                                modifier = Modifier.padding(bottom = 12.dp))

                            ExpenseBarChart(
                                breakdown = breakdown,
                                modifier  = Modifier.fillMaxWidth().height(180.dp)
                            )

                            // Legend
                            Spacer(Modifier.height(10.dp))
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                breakdown.take(4).forEach { (cat, _, color) ->
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Box(Modifier.size(7.dp).background(color, RoundedCornerShape(3.dp)))
                                        Spacer(Modifier.width(4.dp))
                                        Text(cat, fontSize = 10.sp, color = SBOnSurfaceVariant)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showAdd) {
        AddTransactionSheet(onDismiss = { showAdd = false })
    }
}

@Composable
fun CostCard(label: String, value: Double, color: Color, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .background(SBSurface, RoundedCornerShape(12.dp))
            .border(0.8.dp, SBOutline, RoundedCornerShape(12.dp))
            .padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("₹${(value / 1000).toInt()}k", fontSize = 16.sp, fontWeight = FontWeight.Bold,
            color = color)
        Text(label, fontSize = 10.sp, fontWeight = FontWeight.Medium,
            color = SBOnSurfaceVariant,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center)
    }
}

@Composable
fun ExpenseBarChart(
    breakdown: List<Triple<String, Double, Color>>,
    modifier: Modifier = Modifier
) {
    val maxVal = breakdown.maxOfOrNull { it.second } ?: 1.0

    Canvas(modifier = modifier.padding(bottom = 20.dp)) {
        val w = size.width; val h = size.height
        val barW = (w / (breakdown.size * 2 + 1))
        val gap  = barW

        breakdown.forEachIndexed { i, (_, value, color) ->
            val barH  = (value / maxVal * h).toFloat()
            val left  = gap + i * (barW + gap)
            val top   = h - barH

            // Bar
            drawRoundRect(
                color     = color,
                topLeft   = Offset(left, top),
                size      = Size(barW, barH),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(6f, 6f)
            )
        }
    }
}

// ─── Add Transaction Sheet ────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddTransactionSheet(onDismiss: () -> Unit) {
    val scope = rememberCoroutineScope()
    var title    by remember { mutableStateOf("") }
    var type     by remember { mutableStateOf("Expense") }
    var amount   by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("Feed") }
    var note     by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }

    val types      = listOf("Income", "Expense")
    val categories = listOf("Feed", "Chemical", "Harvest", "Labour", "Utility", "Other")

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = SBSurface, tonalElevation = 0.dp
    ) {
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text("Add Entry", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = SBOnSurface)

            com.shrimpbuddy.ui.screens.auth.SBTextField("Title", title, { title = it },
                "e.g. Feed Purchase")
            com.shrimpbuddy.ui.screens.auth.SBTextField("Amount (₹)", amount, { amount = it }, "88000")

            // Type selector
            Column {
                Text("TYPE", fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
                    color = SBOnSurfaceVariant, modifier = Modifier.padding(bottom = 5.dp))
                Row(Modifier.fillMaxWidth(), Arrangement.spacedBy(8.dp)) {
                    types.forEach { t ->
                        Box(
                            modifier = Modifier.weight(1f)
                                .background(
                                    if (type == t) SBPrimary else SBSurfaceElevated,
                                    RoundedCornerShape(8.dp)
                                )
                                .border(0.8.dp, if (type == t) SBPrimary else SBOutline, RoundedCornerShape(8.dp))
                                .clickable { type = t }
                                .padding(vertical = 10.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(t, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                                color = if (type == t) Color.White else SBOnSurfaceVariant)
                        }
                    }
                }
            }

            com.shrimpbuddy.ui.screens.auth.SBPrimaryButton("Save Entry", isLoading) {
                scope.launch {
                    isLoading = true
                    try {
                        RetrofitClient.api.createTransaction(
                            mapOf("title" to title, "type" to type,
                                  "amount" to amount.toDoubleOrNull(), "category" to category,
                                  "note" to note.ifEmpty { null })
                        )
                    } catch (_: Exception) {}
                    isLoading = false; onDismiss()
                }
            }
        }
    }
}

// ─── Harvest Screen ───────────────────────────────────────────────────────────

@Composable
fun HarvestScreen(onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var forecasts by remember { mutableStateOf<List<HarvestForecast>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    LaunchedEffect(Unit) { scope.launch {
        forecasts = RetrofitClient.api.getHarvestForecasts().body()?.data ?: emptyList()
        isLoading = false
    }}
    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("Harvest Forecast", onBack)
        if (isLoading) Box(Modifier.fillMaxSize(), Alignment.Center) {
            CircularProgressIndicator(color = SBPrimary, strokeWidth = 2.5.dp)
        } else LazyColumn(
            contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(forecasts) { f ->
                SBCard {
                    Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween, Alignment.Top) {
                        Text("Pond ${f.pondId}", fontSize = 15.sp, fontWeight = FontWeight.Bold,
                            color = SBOnSurface)
                        StatusBadge(f.status)
                    }
                    Spacer(Modifier.height(8.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Column {
                            Text("Current ABW", fontSize = 10.sp, color = SBOnSurfaceVariant)
                            Text("${f.currentAbw}g", fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                                color = SBOnSurface)
                        }
                        Column {
                            Text("Target ABW", fontSize = 10.sp, color = SBOnSurfaceVariant)
                            Text("${f.targetAbw}g", fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                                color = SBOnSurface)
                        }
                        Spacer(Modifier.weight(1f))
                        Column(horizontalAlignment = Alignment.End) {
                            Text("Days Left", fontSize = 10.sp, color = SBOnSurfaceVariant)
                            Text(if (f.daysLeft == 0) "READY" else "${f.daysLeft}d",
                                fontSize = 14.sp, fontWeight = FontWeight.Bold,
                                color = if (f.daysLeft == 0) SBSuccess else SBPrimaryLight)
                        }
                    }
                    Spacer(Modifier.height(10.dp))
                    // Progress bar
                    val progress = minOf(1.0, f.currentAbw / f.targetAbw).toFloat()
                    Box(Modifier.fillMaxWidth().height(6.dp).background(SBSurfaceHigh, RoundedCornerShape(3.dp))) {
                        Box(Modifier.fillMaxWidth(progress).fillMaxHeight()
                            .background(SBPrimary, RoundedCornerShape(3.dp)))
                    }
                }
            }
        }
    }
}

// ─── Reports Screen ───────────────────────────────────────────────────────────

@Composable
fun ReportsScreen(onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var reports  by remember { mutableStateOf<List<FarmReport>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    LaunchedEffect(Unit) { scope.launch {
        reports = RetrofitClient.api.getReports().body()?.data ?: emptyList()
        isLoading = false
    }}
    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("Farm Reports", onBack)
        if (isLoading) Box(Modifier.fillMaxSize(), Alignment.Center) {
            CircularProgressIndicator(color = SBPrimary, strokeWidth = 2.5.dp)
        } else if (reports.isEmpty()) {
            com.shrimpbuddy.ui.screens.ops.EmptyOpsState("📄", "No Reports",
                "Generate your first farm report.")
        } else LazyColumn(contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(reports) { report ->
                SBCard {
                    Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween, Alignment.CenterVertically) {
                        Column {
                            Text(report.title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                                color = SBOnSurface)
                            Text("${report.type.replaceFirstChar { it.uppercase() }} · ${report.generatedAt}",
                                fontSize = 11.sp, color = SBOnSurfaceVariant)
                        }
                        if (report.downloadUrl != null)
                            Text("↓", fontSize = 20.sp, color = SBPrimary)
                    }
                }
            }
        }
    }
}

// ─── Market Price Screen ──────────────────────────────────────────────────────

@Composable
fun MarketPriceScreen(onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var prices   by remember { mutableStateOf<List<MarketPrice>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    LaunchedEffect(Unit) { scope.launch {
        prices = RetrofitClient.api.getMarketPrices().body()?.data ?: emptyList()
        isLoading = false
    }}
    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("Market Prices", onBack)
        if (isLoading) Box(Modifier.fillMaxSize(), Alignment.Center) {
            CircularProgressIndicator(color = SBPrimary, strokeWidth = 2.5.dp)
        } else LazyColumn(contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(prices) { price ->
                SBCard {
                    Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween, Alignment.CenterVertically) {
                        Column {
                            Text(price.size, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = SBOnSurface)
                            Text("Updated: ${price.updatedAt}", fontSize = 11.sp, color = SBOnSurfaceVariant)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text("₹${price.pricePerKg.toInt()}/kg", fontSize = 15.sp,
                                fontWeight = FontWeight.Bold, color = SBOnSurface)
                            Text(
                                when (price.trend) { "up" -> "↑ Rising"; "down" -> "↓ Falling"; else -> "→ Stable" },
                                fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
                                color = when (price.trend) { "up" -> SBSuccess; "down" -> SBError; else -> SBOnSurfaceVariant }
                            )
                        }
                    }
                }
            }
        }
    }
}
