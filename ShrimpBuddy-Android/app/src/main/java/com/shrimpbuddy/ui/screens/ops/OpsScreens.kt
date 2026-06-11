package com.shrimpbuddy.ui.screens.ops

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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.shrimpbuddy.models.*
import com.shrimpbuddy.network.RetrofitClient
import com.shrimpbuddy.ui.screens.auth.SBPrimaryButton
import com.shrimpbuddy.ui.screens.auth.SBTextField
import com.shrimpbuddy.ui.screens.dashboard.SBCard
import com.shrimpbuddy.ui.screens.dashboard.StatusBadge
import com.shrimpbuddy.ui.theme.*
import kotlinx.coroutines.launch

// ─── Shared Ops App Bar ───────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OpsAppBar(title: String, onBack: () -> Unit, action: (@Composable () -> Unit)? = null) {
    Row(
        modifier = Modifier.fillMaxWidth().background(SBSurface)
            .padding(horizontal = 6.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onBack) {
            Text("←", fontSize = 20.sp, color = SBPrimaryLight)
        }
        Text(title, fontSize = 18.sp, fontWeight = FontWeight.Bold,
            color = SBOnSurface, modifier = Modifier.weight(1f))
        action?.invoke()
    }
    Divider(color = SBOutline, thickness = 0.8.dp)
}

// ─── Feed Log Screen ──────────────────────────────────────────────────────────

@Composable
fun FeedLogScreen(onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var logs     by remember { mutableStateOf<List<FeedLog>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var showLogSheet by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        scope.launch {
            logs = RetrofitClient.api.getFeedLogs().body()?.data ?: emptyList()
            isLoading = false
        }
    }

    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("Feed Log", onBack) {
            Box(
                modifier = Modifier
                    .background(SBPrimary, RoundedCornerShape(10.dp))
                    .clickable { showLogSheet = true }
                    .padding(horizontal = 12.dp, vertical = 7.dp)
            ) {
                Text("+ Log Feed", fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                    color = Color.White)
            }
            Spacer(Modifier.width(10.dp))
        }

        if (isLoading) {
            Box(Modifier.fillMaxSize(), Alignment.Center) {
                CircularProgressIndicator(color = SBPrimary, strokeWidth = 2.5.dp)
            }
        } else if (logs.isEmpty()) {
            EmptyOpsState("🌾", "No Feed Logs", "Tap + to record your first feed entry.")
        } else {
            LazyColumn(contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(logs) { log ->
                    SBCard {
                        Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween, Alignment.CenterVertically) {
                            Column {
                                Text("Pond ${log.pondId} · ${log.feedName}",
                                    fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = SBOnSurface)
                                Text("${log.time} · ${log.sectionName ?: ""}",
                                    fontSize = 11.sp, color = SBOnSurfaceVariant)
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text("${log.totalKg} kg", fontSize = 14.sp, fontWeight = FontWeight.Bold,
                                    color = if (log.status == "Fed") SBSuccess else SBWarning)
                                StatusBadge(log.status)
                            }
                        }
                    }
                }
            }
        }
    }
}

// ─── Feed Inventory Screen (Inventory | Dispatches tabs) ─────────────────────

@Composable
fun FeedInventoryScreen(onBack: () -> Unit) {
    var tabIndex by remember { mutableStateOf(0) }
    val tabs = listOf("Inventory", "Dispatches")

    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("Feed Inventory", onBack)

        // Tab bar
        Row(Modifier.fillMaxWidth().background(SBSurface)) {
            tabs.forEachIndexed { i, label ->
                Column(
                    modifier = Modifier.weight(1f).clickable { tabIndex = i }.padding(vertical = 10.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        label, fontSize = 14.sp,
                        fontWeight = if (tabIndex == i) FontWeight.Bold else FontWeight.Medium,
                        color = if (tabIndex == i) SBPrimary else SBOnSurfaceVariant
                    )
                    Spacer(Modifier.height(4.dp))
                    Box(
                        Modifier.fillMaxWidth(0.6f).height(2.5.dp)
                            .background(if (tabIndex == i) SBPrimary else Color.Transparent,
                                RoundedCornerShape(2.dp))
                    )
                }
            }
        }
        Divider(color = SBOutline, thickness = 0.8.dp)

        when (tabIndex) {
            0    -> FeedInventoryContent()
            else -> FeedDispatchContent()
        }
    }
}

@Composable
fun FeedInventoryContent() {
    val scope = rememberCoroutineScope()
    var sections by remember { mutableStateOf<List<Section>>(emptyList()) }
    var items    by remember { mutableStateOf<List<FeedInventoryItem>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        scope.launch {
            sections = RetrofitClient.api.getSections().body()?.data ?: emptyList()
            items    = RetrofitClient.api.getFeedInventory().body()?.data ?: emptyList()
            isLoading = false
        }
    }

    if (isLoading) {
        Box(Modifier.fillMaxSize(), Alignment.Center) {
            CircularProgressIndicator(color = SBPrimary, strokeWidth = 2.5.dp)
        }
        return
    }

    LazyColumn(contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        // Section-wise groups
        items(sections) { sec ->
            val secItems = items.filter { it.sectionId == sec.id }
            if (secItems.isNotEmpty()) {
                SBCard {
                    Text(sec.name, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = SBOnSurface)
                    Text("${secItems.sumOf { it.stockKg }.toInt()} kg total",
                        fontSize = 11.sp, color = SBPrimaryLight,
                        modifier = Modifier.padding(top = 2.dp, bottom = 10.dp))
                    Divider(color = SBOutline, thickness = 0.8.dp)
                    secItems.forEach { item ->
                        Row(
                            Modifier.fillMaxWidth().padding(vertical = 8.dp),
                            Arrangement.SpaceBetween, Alignment.CenterVertically
                        ) {
                            Column {
                                Text(item.name, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = SBOnSurface)
                                Text(item.category, fontSize = 11.sp, color = SBOnSurfaceVariant)
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text("${item.stockKg.toInt()} kg", fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (item.stockKg < 50) SBWarning else SBSuccess)
                                Text("₹${item.pricePerKg.toInt()}/kg", fontSize = 11.sp,
                                    color = SBOnSurfaceVariant)
                            }
                        }
                        Divider(color = SBOutline, thickness = 0.5.dp)
                    }
                }
            }
        }
        // Central stock
        item {
            val central = items.filter { it.sectionId.isNullOrEmpty() }
            if (central.isNotEmpty()) {
                SBCard {
                    Text("Central Stock", fontSize = 14.sp, fontWeight = FontWeight.Bold,
                        color = SBPrimaryLight, modifier = Modifier.padding(bottom = 10.dp))
                    Divider(color = SBOutline, thickness = 0.8.dp)
                    central.forEach { item ->
                        Row(
                            Modifier.fillMaxWidth().padding(vertical = 8.dp),
                            Arrangement.SpaceBetween, Alignment.CenterVertically
                        ) {
                            Text(item.name, fontSize = 13.sp, color = SBOnSurface)
                            Text("${item.stockKg.toInt()} kg", fontSize = 13.sp,
                                fontWeight = FontWeight.Bold, color = SBSuccess)
                        }
                        Divider(color = SBOutline, thickness = 0.5.dp)
                    }
                }
            }
        }
    }
}

@Composable
fun FeedDispatchContent() {
    val scope = rememberCoroutineScope()
    var dispatches by remember { mutableStateOf<List<FeedDispatch>>(emptyList()) }
    var isLoading  by remember { mutableStateOf(true) }
    var showSheet  by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        scope.launch {
            dispatches = RetrofitClient.api.getFeedDispatches().body()?.data ?: emptyList()
            isLoading  = false
        }
    }

    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().background(SBSurface)
                .padding(horizontal = 14.dp, vertical = 10.dp),
            Arrangement.SpaceBetween, Alignment.CenterVertically
        ) {
            Text("Dispatch History", fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                color = SBOnSurfaceVariant)
            Box(
                Modifier.background(SBPrimary, RoundedCornerShape(10.dp))
                    .clickable { showSheet = true }
                    .padding(horizontal = 12.dp, vertical = 7.dp)
            ) {
                Text("+ New Dispatch", fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                    color = Color.White)
            }
        }
        Divider(color = SBOutline, thickness = 0.8.dp)

        if (isLoading) {
            Box(Modifier.fillMaxSize(), Alignment.Center) {
                CircularProgressIndicator(color = SBPrimary, strokeWidth = 2.5.dp)
            }
        } else if (dispatches.isEmpty()) {
            EmptyOpsState("📦", "No Dispatches", "Record a feed dispatch to sections.")
        } else {
            LazyColumn(contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(dispatches) { d ->
                    SBCard {
                        Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween, Alignment.CenterVertically) {
                            Column {
                                Text("To: ${d.toSectionName}", fontSize = 13.sp,
                                    fontWeight = FontWeight.SemiBold, color = SBOnSurface)
                                Text("${d.feedVariety} · ${d.date}", fontSize = 11.sp,
                                    color = SBOnSurfaceVariant)
                            }
                            Text("${d.quantityKg.toInt()} kg", fontSize = 14.sp,
                                fontWeight = FontWeight.Bold, color = SBPrimaryLight)
                        }
                    }
                }
            }
        }
    }

    if (showSheet) {
        FeedDispatchSheet(onDismiss = { showSheet = false; /* reload */ })
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FeedDispatchSheet(onDismiss: () -> Unit) {
    val scope = rememberCoroutineScope()
    var section   by remember { mutableStateOf("") }
    var variety   by remember { mutableStateOf("") }
    var qty       by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = SBSurface, tonalElevation = 0.dp) {
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text("New Feed Dispatch", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = SBOnSurface)
            SBTextField("To Section",    section, { section = it }, "Section A")
            SBTextField("Feed Variety",  variety, { variety = it }, "Grower Max 2.4mm")
            SBTextField("Quantity (kg)", qty,     { qty     = it }, "100")
            SBPrimaryButton("Confirm Dispatch", isLoading) {
                scope.launch {
                    isLoading = true
                    try { RetrofitClient.api.dispatchFeed(
                        mapOf("toSectionId" to section, "feedVariety" to variety,
                              "quantityKg" to qty.toDoubleOrNull())
                    )} catch (_: Exception) {}
                    isLoading = false; onDismiss()
                }
            }
        }
    }
}

// ─── Chemical Menu Screen (tabs) ──────────────────────────────────────────────

@Composable
fun ChemicalMenuScreen(onBack: () -> Unit) {
    var tabIndex by remember { mutableStateOf(0) }
    val tabs = listOf("Usage Log", "Inventory", "Dispatch")

    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("Chemicals", onBack)

        Row(Modifier.fillMaxWidth().background(SBSurface)) {
            tabs.forEachIndexed { i, label ->
                Column(
                    Modifier.weight(1f).clickable { tabIndex = i }.padding(vertical = 10.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(label, fontSize = 13.sp,
                        fontWeight = if (tabIndex == i) FontWeight.Bold else FontWeight.Medium,
                        color = if (tabIndex == i) SBPrimary else SBOnSurfaceVariant)
                    Spacer(Modifier.height(4.dp))
                    Box(Modifier.fillMaxWidth(0.7f).height(2.5.dp)
                        .background(if (tabIndex == i) SBPrimary else Color.Transparent,
                            RoundedCornerShape(2.dp)))
                }
            }
        }
        Divider(color = SBOutline, thickness = 0.8.dp)

        when (tabIndex) {
            0    -> ChemicalUsageContent()
            1    -> ChemicalInventoryContent()
            else -> ChemicalDispatchContent()
        }
    }
}

@Composable
fun ChemicalUsageContent() {
    val scope = rememberCoroutineScope()
    var logs     by remember { mutableStateOf<List<ChemicalLog>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var showSheet by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        scope.launch {
            logs = RetrofitClient.api.getChemicalLogs().body()?.data ?: emptyList()
            isLoading = false
        }
    }

    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().background(SBSurface)
                .padding(horizontal = 14.dp, vertical = 10.dp),
            Arrangement.End
        ) {
            Box(
                Modifier.background(SBPrimary, RoundedCornerShape(10.dp))
                    .clickable { showSheet = true }
                    .padding(horizontal = 12.dp, vertical = 7.dp)
            ) { Text("+ Log Chemical", fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                color = Color.White) }
        }
        Divider(color = SBOutline, thickness = 0.8.dp)

        if (isLoading) Box(Modifier.fillMaxSize(), Alignment.Center) {
            CircularProgressIndicator(color = SBPrimary, strokeWidth = 2.5.dp)
        } else LazyColumn(
            contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(logs) { log ->
                SBCard {
                    Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween, Alignment.Top) {
                        Column {
                            Text(log.name, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = SBOnSurface)
                            Text("Pond ${log.pondId} · ${log.purpose}", fontSize = 11.sp, color = SBOnSurfaceVariant)
                            Text(log.date, fontSize = 10.sp, color = SBOnSurfaceDim)
                        }
                        Text("${log.quantity} ${log.unit}", fontSize = 13.sp,
                            fontWeight = FontWeight.Bold, color = SBPrimaryLight)
                    }
                }
            }
        }
    }
}

@Composable
fun ChemicalInventoryContent() {
    val scope = rememberCoroutineScope()
    var sections by remember { mutableStateOf<List<Section>>(emptyList()) }
    var items    by remember { mutableStateOf<List<ChemicalInventoryItem>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        scope.launch {
            sections = RetrofitClient.api.getSections().body()?.data ?: emptyList()
            items    = RetrofitClient.api.getChemicalInventory().body()?.data ?: emptyList()
            isLoading = false
        }
    }

    if (isLoading) Box(Modifier.fillMaxSize(), Alignment.Center) {
        CircularProgressIndicator(color = SBPrimary, strokeWidth = 2.5.dp)
        return
    }

    LazyColumn(contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            val central = items.filter { it.sectionId.isNullOrEmpty() }
            if (central.isNotEmpty()) SBCard {
                Text("Central Stock", fontSize = 14.sp, fontWeight = FontWeight.Bold,
                    color = SBPrimaryLight, modifier = Modifier.padding(bottom = 10.dp))
                Divider(color = SBOutline)
                central.forEach { ChemInventoryRow(it) }
            }
        }
        items(sections) { sec ->
            val secItems = items.filter { it.sectionId == sec.id }
            if (secItems.isNotEmpty()) SBCard {
                Text(sec.name, fontSize = 14.sp, fontWeight = FontWeight.Bold,
                    color = SBOnSurface, modifier = Modifier.padding(bottom = 10.dp))
                Divider(color = SBOutline)
                secItems.forEach { ChemInventoryRow(it) }
            }
        }
    }
}

@Composable
fun ColumnScope.ChemInventoryRow(item: ChemicalInventoryItem) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 8.dp),
        Arrangement.SpaceBetween, Alignment.CenterVertically
    ) {
        Text(item.name, fontSize = 13.sp, color = SBOnSurface)
        Column(horizontalAlignment = Alignment.End) {
            Text("${item.stock.toInt()} ${item.unit}", fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = if (item.stock < 5) SBWarning else SBSuccess)
            Text("₹${item.ratePerUnit.toInt()}/${item.unit}", fontSize = 11.sp, color = SBOnSurfaceVariant)
        }
    }
    Divider(color = SBOutline, thickness = 0.5.dp)
}

@Composable
fun ChemicalDispatchContent() {
    EmptyOpsState("📦", "No Chemical Dispatches", "Chemical dispatch records will appear here.")
}

// ─── Sampling Menu Screen ─────────────────────────────────────────────────────

@Composable
fun SamplingMenuScreen(onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var sections   by remember { mutableStateOf<List<Section>>(emptyList()) }
    var recentLogs by remember { mutableStateOf<List<SamplingLog>>(emptyList()) }
    var isLoading  by remember { mutableStateOf(true) }
    var selectedSection by remember { mutableStateOf<Section?>(null) }
    var showBulk   by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        scope.launch {
            sections   = RetrofitClient.api.getSections().body()?.data ?: emptyList()
            recentLogs = RetrofitClient.api.getSamplingLogs().body()?.data ?: emptyList()
            isLoading  = false
        }
    }

    if (selectedSection != null) {
        SectionSamplingScreen(
            section    = selectedSection!!,
            allLogs    = recentLogs,
            onBack     = { selectedSection = null }
        )
        return
    }

    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("Sampling", onBack) {
            Box(
                Modifier.background(SBPrimaryDim, RoundedCornerShape(10.dp))
                    .clickable { showBulk = true }
                    .padding(horizontal = 12.dp, vertical = 7.dp)
            ) {
                Text("Bulk Entry", fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                    color = SBPrimaryLight)
            }
            Spacer(Modifier.width(10.dp))
        }

        if (isLoading) Box(Modifier.fillMaxSize(), Alignment.Center) {
            CircularProgressIndicator(color = SBPrimary, strokeWidth = 2.5.dp)
        } else LazyColumn(
            contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(sections) { sec ->
                val latest = recentLogs.firstOrNull { it.sectionId == sec.id }
                SamplingCard(sec, latest, onClick = { selectedSection = sec })
            }
        }
    }
}

@Composable
fun SamplingCard(section: Section, latestLog: SamplingLog?, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(SBSurface, RoundedCornerShape(14.dp))
            .border(0.8.dp, SBOutline, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(section.name, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = SBOnSurface)
            if (latestLog != null) {
                Text("ABW: ${latestLog.abw}g · Survival: ${latestLog.survivalPct.toInt()}%",
                    fontSize = 12.sp, color = SBOnSurfaceVariant)
                Text("Last sampled: ${latestLog.date}", fontSize = 11.sp, color = SBOnSurfaceDim)
            } else {
                Text("No samples yet", fontSize = 12.sp, color = SBOnSurfaceDim)
            }
        }
        Icon(androidx.compose.material.icons.Icons.Default.ChevronRight,
            "Go", tint = SBOnSurfaceDim, modifier = Modifier.size(18.dp))
    }
}

@Composable
fun SectionSamplingScreen(section: Section, allLogs: List<SamplingLog>, onBack: () -> Unit) {
    var showLog by remember { mutableStateOf(false) }
    val logs = allLogs.filter { it.sectionId == section.id }

    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("${section.name} — Sampling", onBack) {
            Box(
                Modifier.background(SBPrimary, RoundedCornerShape(10.dp))
                    .clickable { showLog = true }
                    .padding(horizontal = 12.dp, vertical = 7.dp)
            ) {
                Text("+ Sample", fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                    color = Color.White)
            }
            Spacer(Modifier.width(10.dp))
        }

        if (logs.isEmpty()) {
            EmptyOpsState("🔬", "No Samples", "Tap + to record the first sample for this section.")
        } else {
            LazyColumn(contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(logs) { log ->
                    SBCard {
                        Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween, Alignment.CenterVertically) {
                            Column {
                                Text("Pond ${log.pondId} · ${log.date}", fontSize = 13.sp,
                                    fontWeight = FontWeight.SemiBold, color = SBOnSurface)
                                Text("Sample count: ${log.sampleCount}", fontSize = 11.sp,
                                    color = SBOnSurfaceVariant)
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text("${log.abw}g", fontSize = 14.sp,
                                    fontWeight = FontWeight.Bold, color = SBPrimaryLight)
                                Text("${log.survivalPct.toInt()}% survival",
                                    fontSize = 11.sp, color = SBSuccess)
                            }
                        }
                    }
                }
            }
        }
    }
}

// ─── Water Quality ────────────────────────────────────────────────────────────

@Composable
fun WaterQualityScreen(onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var pondId   by remember { mutableStateOf("A1") }
    var params   by remember { mutableStateOf<List<WaterParamEntry>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }

    fun load() {
        scope.launch {
            isLoading = true
            params    = RetrofitClient.api.getWaterParameters(pondId).body()?.data ?: emptyList()
            isLoading = false
        }
    }
    LaunchedEffect(Unit) { load() }

    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("Water Quality", onBack)

        Row(
            Modifier.fillMaxWidth().background(SBSurface)
                .padding(12.dp),
            Arrangement.spacedBy(10.dp), Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = pondId, onValueChange = { pondId = it },
                label = { Text("Pond ID", color = SBOnSurfaceVariant) },
                singleLine = true,
                shape = RoundedCornerShape(8.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor   = SBPrimary,
                    unfocusedBorderColor = SBOutline,
                    focusedContainerColor   = SBSurfaceElevated,
                    unfocusedContainerColor = SBSurfaceElevated,
                    focusedTextColor    = SBOnSurface,
                    unfocusedTextColor  = SBOnSurface
                ),
                modifier = Modifier.width(130.dp).height(52.dp)
            )
            Box(
                Modifier.background(SBPrimary, RoundedCornerShape(10.dp))
                    .clickable { load() }.padding(horizontal = 16.dp, vertical = 12.dp)
            ) { Text("Load", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Color.White) }
        }
        Divider(color = SBOutline)

        if (isLoading) Box(Modifier.fillMaxSize(), Alignment.Center) {
            CircularProgressIndicator(color = SBPrimary, strokeWidth = 2.5.dp)
        } else LazyColumn(contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(params) { p ->
                SBCard {
                    Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween, Alignment.CenterVertically) {
                        Column {
                            Text(p.name, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = SBOnSurface)
                            Text("Range: ${p.range}", fontSize = 11.sp, color = SBOnSurfaceVariant)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text("${p.value} ${p.unit}", fontSize = 13.sp,
                                fontWeight = FontWeight.Bold, color = SBOnSurface)
                            StatusBadge(p.status)
                        }
                    }
                }
            }
        }
    }
}

// ─── Bulk Entry Screen ────────────────────────────────────────────────────────

@Composable
fun BulkEntryScreen(onBack: () -> Unit) {
    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("Bulk Entry", onBack)
        LazyColumn(contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item { BulkCard("🌾", "Bulk Feed Log",      "Log feed for multiple ponds at once") }
            item { BulkCard("🔬", "Bulk Sampling",      "Enter all sample points for a section") }
            item { BulkCard("🧪", "Bulk Chemical Log",  "Record chemical application across ponds") }
            item { BulkCard("📦", "Bulk Feed Dispatch", "Send feed to multiple sections at once") }
        }
    }
}

@Composable
fun BulkCard(emoji: String, title: String, subtitle: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(SBSurface, RoundedCornerShape(14.dp))
            .border(0.8.dp, SBOutline, RoundedCornerShape(14.dp))
            .clickable { }
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            Modifier.size(50.dp).background(SBPrimaryDim, RoundedCornerShape(12.dp)),
            Alignment.Center
        ) { Text(emoji, fontSize = 24.sp) }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(title,    fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = SBOnSurface)
            Text(subtitle, fontSize = 12.sp, color = SBOnSurfaceVariant)
        }
        Icon(androidx.compose.material.icons.Icons.Default.ChevronRight,
            "Go", tint = SBOnSurfaceDim, modifier = Modifier.size(18.dp))
    }
}

// ─── Empty State Helper ────────────────────────────────────────────────────────

@Composable
fun EmptyOpsState(emoji: String, title: String, message: String) {
    Box(Modifier.fillMaxSize().padding(24.dp), Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(emoji, fontSize = 44.sp)
            Spacer(Modifier.height(10.dp))
            Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = SBOnSurface)
            Spacer(Modifier.height(4.dp))
            Text(message, fontSize = 13.sp, color = SBOnSurfaceVariant,
                textAlign = TextAlign.Center)
        }
    }
}
