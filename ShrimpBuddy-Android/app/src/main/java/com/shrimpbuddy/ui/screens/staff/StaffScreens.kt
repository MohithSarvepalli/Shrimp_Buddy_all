package com.shrimpbuddy.ui.screens.staff

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.shrimpbuddy.models.*
import com.shrimpbuddy.network.RetrofitClient
import com.shrimpbuddy.ui.screens.dashboard.SBCard
import com.shrimpbuddy.ui.screens.dashboard.StatusBadge
import com.shrimpbuddy.ui.screens.ops.EmptyOpsState
import com.shrimpbuddy.ui.screens.ops.OpsAppBar
import com.shrimpbuddy.ui.theme.*
import kotlinx.coroutines.launch

// ─── Staff Directory ──────────────────────────────────────────────────────────

@Composable
fun StaffScreen(onBack: () -> Unit = {}) {
    val scope = rememberCoroutineScope()
    var users    by remember { mutableStateOf<List<StaffUser>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    LaunchedEffect(Unit) { scope.launch {
        users = RetrofitClient.api.getUsers().body()?.data ?: emptyList()
        isLoading = false
    }}
    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("User Management", onBack)
        if (isLoading) Box(Modifier.fillMaxSize(), Alignment.Center) {
            CircularProgressIndicator(color = SBPrimary, strokeWidth = 2.5.dp)
        } else if (users.isEmpty()) {
            EmptyOpsState("👥", "No Team Members", "Add team members to manage access.")
        } else LazyColumn(
            contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(users) { user ->
                SBCard {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            Modifier.size(40.dp)
                                .background(SBPrimaryDim, CircleShape),
                            Alignment.Center
                        ) {
                            Text(user.name.take(1).uppercase(), fontSize = 15.sp,
                                fontWeight = FontWeight.Bold, color = SBPrimaryLight)
                        }
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(user.name, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                                color = SBOnSurface)
                            Text(user.email, fontSize = 11.sp, color = SBOnSurfaceVariant)
                        }
                        Text(user.role.replaceFirstChar { it.uppercase() },
                            fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
                            color = SBPrimaryLight,
                            modifier = Modifier
                                .background(SBPrimaryDim, RoundedCornerShape(20.dp))
                                .padding(horizontal = 8.dp, vertical = 3.dp))
                    }
                }
            }
        }
    }
}

// ─── Audit Log ────────────────────────────────────────────────────────────────

@Composable
fun AuditLogScreen(onBack: () -> Unit = {}) {
    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("Audit & Compliance", onBack)
        EmptyOpsState("🛡️", "All Good", "Your compliance and audit records will appear here.")
    }
}

// ─── Price List Screen ─────────────────────────────────────────────────────────

@Composable
fun PriceListScreen(onBack: () -> Unit = {}) {
    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("Price List & Rates", onBack)
        EmptyOpsState("🏷️", "No Prices Set", "Set feed, seed and chemical rates for your farm.")
    }
}

// ─── Settings Screen ──────────────────────────────────────────────────────────

@Composable
fun SettingsScreen(onLogout: () -> Unit, onBack: () -> Unit = {}) {
    Column(Modifier.fillMaxSize().background(SBBg)) {
        OpsAppBar("Settings", onBack)
        Box(Modifier.fillMaxSize().padding(24.dp), Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("⚙️", fontSize = 44.sp)
                Spacer(Modifier.height(10.dp))
                Text("App Settings", fontSize = 17.sp, fontWeight = FontWeight.SemiBold,
                    color = SBOnSurface)
                Spacer(Modifier.height(24.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(SBErrorBg, RoundedCornerShape(14.dp))
                        .border(0.8.dp, SBError.copy(0.3f), RoundedCornerShape(14.dp))
                        .clickable { onLogout() }
                        .padding(16.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text("Sign Out", fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                        color = SBError)
                }
            }
        }
    }
}
