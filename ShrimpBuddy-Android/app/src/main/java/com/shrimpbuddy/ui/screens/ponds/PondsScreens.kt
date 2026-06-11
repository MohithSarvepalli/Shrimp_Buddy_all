package com.shrimpbuddy.ui.screens.ponds

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
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

// ─── Ponds Screen ─────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PondsScreen(onPondClick: (Pond) -> Unit) {
    val scope = rememberCoroutineScope()
    var ponds    by remember { mutableStateOf<List<Pond>>(emptyList()) }
    var sections by remember { mutableStateOf<List<Section>>(emptyList()) }
    var selectedSection by remember { mutableStateOf("All") }
    var isLoading by remember { mutableStateOf(true) }
    var showAddSheet by remember { mutableStateOf(false) }

    val sectionNames = remember(sections) { listOf("All") + sections.map { it.name } }
    val filtered = remember(ponds, selectedSection) {
        if (selectedSection == "All") ponds else ponds.filter { it.sectionName == selectedSection }
    }

    fun load() {
        scope.launch {
            try {
                val p = RetrofitClient.api.getPonds()
                val s = RetrofitClient.api.getSections()
                ponds    = p.body()?.data ?: emptyList()
                sections = s.body()?.data ?: emptyList()
            } catch (_: Exception) {}
            isLoading = false
        }
    }
    LaunchedEffect(Unit) { load() }

    Column(Modifier.fillMaxSize().background(SBBg)) {
        // ── Header ─────────────────────────────────────────────────────────
        Row(
            modifier = Modifier.fillMaxWidth().background(SBSurface)
                .padding(horizontal = 18.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("Ponds", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = SBOnSurface)
            FloatingActionButton(
                onClick = { showAddSheet = true },
                containerColor = SBPrimary,
                contentColor = Color.White,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.size(40.dp).offset(y = 0.dp),
                elevation = FloatingActionButtonDefaults.elevation(0.dp, 0.dp)
            ) { Icon(Icons.Default.Add, "Add Pond", modifier = Modifier.size(18.dp)) }
        }
        Divider(color = SBOutline, thickness = 0.8.dp)

        // ── Section Pill Slider ─────────────────────────────────────────────
        LazyRow(
            modifier = Modifier.fillMaxWidth().background(SBSurface),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            items(sectionNames) { name ->
                val isSelected = name == selectedSection
                Text(
                    text = name,
                    fontSize = 13.sp,
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                    color = if (isSelected) Color.White else SBOnSurfaceVariant,
                    modifier = Modifier
                        .background(
                            if (isSelected) SBPrimary else SBSurfaceElevated,
                            RoundedCornerShape(20.dp)
                        )
                        .then(
                            if (!isSelected)
                                Modifier.border(0.8.dp, SBOutline, RoundedCornerShape(20.dp))
                            else Modifier
                        )
                        .clickable { selectedSection = name }
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                )
            }
        }
        Divider(color = SBOutline, thickness = 0.8.dp)

        // ── List ────────────────────────────────────────────────────────────
        when {
            isLoading -> Box(Modifier.fillMaxSize(), Alignment.Center) {
                CircularProgressIndicator(color = SBPrimary, strokeWidth = 2.5.dp)
            }
            filtered.isEmpty() -> Box(Modifier.fillMaxSize().padding(24.dp), Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("🌊", fontSize = 44.sp)
                    Spacer(Modifier.height(10.dp))
                    Text("No Ponds", fontSize = 17.sp, fontWeight = FontWeight.SemiBold,
                        color = SBOnSurface)
                    Text("Add your first pond to start tracking.",
                        fontSize = 13.sp, color = SBOnSurfaceVariant,
                        textAlign = TextAlign.Center)
                }
            }
            else -> LazyColumn(
                contentPadding = PaddingValues(14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(filtered) { pond ->
                    PondCard(pond = pond, onClick = { onPondClick(pond) })
                }
            }
        }
    }

    if (showAddSheet) {
        AddPondBottomSheet(
            sections = sections,
            onDismiss = { showAddSheet = false; load() }
        )
    }
}

// ─── Pond Card ────────────────────────────────────────────────────────────────

@Composable
fun PondCard(pond: Pond, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(SBSurface, RoundedCornerShape(14.dp))
            .border(0.8.dp, SBOutline, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(14.dp)
    ) {
        // Title row
        Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween, Alignment.Top) {
            Column {
                Text(pond.pondId, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = SBOnSurface)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(pond.sectionName, fontSize = 11.sp,
                        fontWeight = FontWeight.Medium, color = SBPrimaryLight)
                    Text(" · ", fontSize = 11.sp, color = SBOnSurfaceDim)
                    Text(pond.type, fontSize = 11.sp, color = SBOnSurfaceVariant)
                }
            }
            StatusBadge(pond.status)
        }

        Spacer(Modifier.height(12.dp))
        Divider(color = SBOutline, thickness = 0.8.dp)
        Spacer(Modifier.height(12.dp))

        // Metrics row
        Row(Modifier.fillMaxWidth()) {
            PondMetricCell(formatDate(pond.stockedDate), "Stocked",      Modifier.weight(1f))
            VerticalDivider(Modifier.height(36.dp).padding(horizontal = 0.dp))
            PondMetricCell("DOC ${pond.doc}d",           "Day of Culture", Modifier.weight(1f))
            VerticalDivider(Modifier.height(36.dp))
            PondMetricCell("${pond.feedTodayKg.toInt()} kg", "Latest Feed", Modifier.weight(1f))
            VerticalDivider(Modifier.height(36.dp))
            PondMetricCell("${pond.survivalPct.toInt()}%", "Survival",    Modifier.weight(1f))
        }
    }
}

@Composable
fun PondMetricCell(value: String, label: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(value, fontSize = 13.sp, fontWeight = FontWeight.Bold,
            color = SBOnSurface, maxLines = 1)
        Text(label, fontSize = 9.sp, fontWeight = FontWeight.Medium,
            color = SBOnSurfaceVariant, textAlign = TextAlign.Center)
    }
}

@Composable
fun VerticalDivider(modifier: Modifier = Modifier) {
    Box(modifier.width(0.8.dp).background(SBOutline))
}

fun formatDate(iso: String?): String {
    if (iso.isNullOrEmpty()) return "—"
    return try {
        val parts = iso.substring(0, 10).split("-")
        val months = listOf("","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")
        "${parts[2].trimStart('0')} ${months[parts[1].toInt()]}"
    } catch (_: Exception) { iso }
}

// ─── Pond Detail ──────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PondDetailScreen(pond: Pond, onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(pond.pondId, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Text("←", fontSize = 20.sp, color = SBPrimaryLight)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = SBSurface,
                    titleContentColor = SBOnSurface
                )
            )
        },
        containerColor = SBBg
    ) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState())
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            SBCard {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    DetailRow("Section",      pond.sectionName)
                    DetailRow("Type",         pond.type)
                    DetailRow("Status",       pond.status)
                    DetailRow("DOC",          "${pond.doc} days")
                    DetailRow("ABW",          "${pond.abw}g")
                    DetailRow("Survival",     "${pond.survivalPct.toInt()}%")
                    DetailRow("Feed Today",   "${pond.feedTodayKg.toInt()} kg")
                    DetailRow("Stocked",      formatDate(pond.stockedDate))
                }
            }
        }
    }
}

@Composable
fun DetailRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween) {
        Text(label, fontSize = 12.sp, color = SBOnSurfaceVariant)
        Text(value, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = SBOnSurface)
    }
}

// ─── Add Pond Bottom Sheet ────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddPondBottomSheet(sections: List<Section>, onDismiss: () -> Unit) {
    var pondId   by remember { mutableStateOf("") }
    var section  by remember { mutableStateOf(sections.firstOrNull()?.id ?: "") }
    var type     by remember { mutableStateOf("Grow-out") }
    var isLoading by remember { mutableStateOf(false) }
    val scope    = rememberCoroutineScope()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = SBSurface,
        tonalElevation = 0.dp
    ) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text("Add New Pond", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = SBOnSurface)
            SBTextField("Pond ID", pondId, { pondId = it }, "e.g. A1")
            SBTextField("Type", type, { type = it }, "Grow-out / Nursery")
            SBPrimaryButton("Add Pond", isLoading) {
                scope.launch {
                    isLoading = true
                    try { RetrofitClient.api.createPond(mapOf(
                        "pondId" to pondId, "sectionId" to section, "type" to type))
                    } catch (_: Exception) {}
                    isLoading = false; onDismiss()
                }
            }
        }
    }
}
