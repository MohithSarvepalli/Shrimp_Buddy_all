package com.shrimpbuddy.ui.navigation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.shrimpbuddy.models.Pond
import com.shrimpbuddy.ui.screens.auth.*
import com.shrimpbuddy.ui.screens.dashboard.DashboardScreen
import com.shrimpbuddy.ui.screens.finance.*
import com.shrimpbuddy.ui.screens.ops.*
import com.shrimpbuddy.ui.screens.ponds.*
import com.shrimpbuddy.ui.screens.staff.*
import com.shrimpbuddy.ui.theme.*

data class BottomNavItem(val label: String, val icon: ImageVector, val route: String)

val bottomNavItems = listOf(
    BottomNavItem("Home",    Icons.Default.Home,           "dashboard"),
    BottomNavItem("Ponds",   Icons.Default.Water,          "ponds"),
    BottomNavItem("Ops",     Icons.Default.GridView,       "ops"),
    BottomNavItem("Finance", Icons.Default.BarChart,       "finance"),
    BottomNavItem("More",    Icons.Default.MoreHoriz,      "more")
)

// ─── App Shell ────────────────────────────────────────────────────────────────

@Composable
fun ShrimpBuddyApp() {
    var isLoggedIn  by remember { mutableStateOf(false) }
    var authScreen  by remember { mutableStateOf("login") }
    var currentTab  by remember { mutableStateOf("dashboard") }
    var selectedPond by remember { mutableStateOf<Pond?>(null) }
    var opsScreen   by remember { mutableStateOf("menu") }
    var financeScreen by remember { mutableStateOf("menu") }
    var moreScreen  by remember { mutableStateOf("menu") }

    if (!isLoggedIn) {
        when (authScreen) {
            "login"    -> LoginScreen(
                onLoginSuccess       = { isLoggedIn = true },
                onNavigateToRegister = { authScreen = "register" },
                onNavigateToForgot   = { authScreen = "forgot" }
            )
            "register" -> RegisterScreen(
                onSuccess = { isLoggedIn = true },
                onBack    = { authScreen = "login" }
            )
            "forgot"   -> ForgotPasswordScreen(
                onBack = { authScreen = "login" },
                onSent = { authScreen = "login" }
            )
        }
        return
    }

    if (selectedPond != null) {
        PondDetailScreen(pond = selectedPond!!, onBack = { selectedPond = null })
        return
    }

    Scaffold(
        containerColor = SBBg,
        bottomBar = {
            NavigationBar(
                containerColor = SBSurface,
                tonalElevation = 0.dp,
                modifier = Modifier.border(0.8.dp, SBOutline,
                    RoundedCornerShape(topStart = 0.dp, topEnd = 0.dp))
            ) {
                bottomNavItems.forEach { item ->
                    NavigationBarItem(
                        selected   = currentTab == item.route,
                        onClick    = {
                            currentTab    = item.route
                            opsScreen     = "menu"
                            financeScreen = "menu"
                            moreScreen    = "menu"
                        },
                        icon  = { Icon(item.icon, item.label, Modifier.size(22.dp)) },
                        label = { Text(item.label, fontSize = 10.sp) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor   = SBPrimary,
                            selectedTextColor   = SBPrimary,
                            unselectedIconColor = SBOnSurfaceVariant,
                            unselectedTextColor = SBOnSurfaceVariant,
                            indicatorColor      = SBPrimaryDim
                        )
                    )
                }
            }
        }
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (currentTab) {
                "dashboard" -> DashboardScreen()
                "ponds"     -> PondsScreen(onPondClick = { selectedPond = it })
                "ops"       -> OpsRouter(currentScreen = opsScreen,
                                         onNavigate    = { opsScreen = it },
                                         onBack        = { opsScreen = "menu" })
                "finance"   -> FinanceRouter(currentScreen = financeScreen,
                                              onNavigate    = { financeScreen = it },
                                              onBack        = { financeScreen = "menu" })
                "more"      -> MoreRouter(currentScreen = moreScreen,
                                          onNavigate    = { moreScreen = it },
                                          onBack        = { moreScreen = "menu" },
                                          onLogout      = { isLoggedIn = false })
            }
        }
    }
}

// ─── Ops Router ───────────────────────────────────────────────────────────────

@Composable
fun OpsRouter(currentScreen: String, onNavigate: (String) -> Unit, onBack: () -> Unit) {
    when (currentScreen) {
        "feed-log"    -> FeedLogScreen(onBack = onBack)
        "feed-inv"    -> FeedInventoryScreen(onBack = onBack)
        "chem"        -> ChemicalMenuScreen(onBack = onBack)
        "sampling"    -> SamplingMenuScreen(onBack = onBack)
        "water"       -> WaterQualityScreen(onBack = onBack)
        "bulk"        -> BulkEntryScreen(onBack = onBack)
        else          -> OpsMenuScreen(onNavigate = onNavigate)
    }
}

// ─── Ops Menu (Icon Grid) ─────────────────────────────────────────────────────

data class OpsGridItem(
    val emoji: String, val title: String, val subtitle: String,
    val gradientStart: Color, val gradientEnd: Color, val route: String
)

val opsGridItems = listOf(
    OpsGridItem("🌾", "Feed Log",        "Record daily feeding",
        Color(0xFF1A3A6A), Color(0xFF0D2248), "feed-log"),
    OpsGridItem("📦", "Feed Inventory",  "Stock & dispatches",
        Color(0xFF1A4A3A), Color(0xFF0D2A22), "feed-inv"),
    OpsGridItem("🧪", "Chemicals",       "Usage & inventory",
        Color(0xFF3A2A4A), Color(0xFF211530), "chem"),
    OpsGridItem("🔬", "Sampling",        "ABW & survival data",
        Color(0xFF2A3A1A), Color(0xFF172212), "sampling"),
    OpsGridItem("💧", "Water Quality",   "Parameters log",
        Color(0xFF0A2A3A), Color(0xFF051820), "water"),
    OpsGridItem("📋", "Bulk Entry",      "Log multiple at once",
        Color(0xFF3A2A1A), Color(0xFF221808), "bulk"),
)

@Composable
fun OpsMenuScreen(onNavigate: (String) -> Unit) {
    Column(
        Modifier.fillMaxSize().background(SBBg)
    ) {
        Column(
            Modifier.fillMaxWidth().background(SBSurface)
                .padding(horizontal = 18.dp, vertical = 14.dp)
        ) {
            Text("Operations", fontSize = 26.sp, fontWeight = FontWeight.Bold, color = SBOnSurface)
            Text("Manage feed, chemicals and sampling",
                fontSize = 13.sp, color = SBOnSurfaceVariant)
        }
        Divider(color = SBOutline, thickness = 0.8.dp)

        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            contentPadding = PaddingValues(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxSize()
        ) {
            items(opsGridItems) { item ->
                OpsGridCard(item = item, onClick = { onNavigate(item.route) })
            }
        }
    }
}

@Composable
fun OpsGridCard(item: OpsGridItem, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1.1f)
            .background(
                Brush.linearGradient(listOf(item.gradientStart, item.gradientEnd)),
                RoundedCornerShape(16.dp)
            )
            .border(1.dp, Color.White.copy(0.07f), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(16.dp)
    ) {
        Column(Modifier.fillMaxSize()) {
            Text(item.emoji, fontSize = 30.sp)
            Spacer(Modifier.weight(1f))
            Text(item.title, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Color.White)
            Text(item.subtitle, fontSize = 11.sp, color = Color.White.copy(0.65f))
        }
    }
}

// ─── Finance Router ───────────────────────────────────────────────────────────

@Composable
fun FinanceRouter(currentScreen: String, onNavigate: (String) -> Unit, onBack: () -> Unit) {
    when (currentScreen) {
        "overview"  -> FinanceScreen(onBack = onBack)
        "harvest"   -> HarvestScreen(onBack = onBack)
        "reports"   -> ReportsScreen(onBack = onBack)
        else        -> FinanceMenuScreen(onNavigate = onNavigate)
    }
}

@Composable
fun FinanceMenuScreen(onNavigate: (String) -> Unit) {
    Column(Modifier.fillMaxSize().background(SBBg)) {
        Column(
            Modifier.fillMaxWidth().background(SBSurface)
                .padding(horizontal = 18.dp, vertical = 14.dp)
        ) {
            Text("Finance", fontSize = 26.sp, fontWeight = FontWeight.Bold, color = SBOnSurface)
            Text("Expenses and cost analysis", fontSize = 13.sp, color = SBOnSurfaceVariant)
        }
        Divider(color = SBOutline, thickness = 0.8.dp)

        LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item { FinanceNavCard("💰", "Expense Overview",   "Total, feed & chemical costs") { onNavigate("overview") } }
            item { FinanceNavCard("📈", "Harvest Forecast",   "Projected yields per pond")    { onNavigate("harvest")  } }
            item { FinanceNavCard("📄", "Farm Reports",       "Download detailed reports")    { onNavigate("reports")  } }
        }
    }
}

@Composable
fun FinanceNavCard(emoji: String, title: String, subtitle: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(SBSurface, RoundedCornerShape(14.dp))
            .border(0.8.dp, SBOutline, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            Modifier.size(50.dp).background(SBPrimaryDim, RoundedCornerShape(12.dp)),
            Alignment.Center
        ) { Text(emoji, fontSize = 24.sp) }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(title,    fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = SBOnSurface)
            Text(subtitle, fontSize = 12.sp, color = SBOnSurfaceVariant)
        }
        Icon(Icons.Default.ChevronRight, "Go", tint = SBOnSurfaceDim, modifier = Modifier.size(18.dp))
    }
}

// ─── More Router ──────────────────────────────────────────────────────────────

@Composable
fun MoreRouter(
    currentScreen: String,
    onNavigate: (String) -> Unit,
    onBack: () -> Unit,
    onLogout: () -> Unit
) {
    when (currentScreen) {
        "market"     -> MarketPriceScreen(onBack = onBack)
        "prices"     -> PriceListScreen(onBack = onBack)
        "users"      -> StaffScreen(onBack = onBack)
        "audit"      -> AuditLogScreen(onBack = onBack)
        "settings"   -> SettingsScreen(onLogout = onLogout, onBack = onBack)
        else         -> MoreMenuScreen(onNavigate = onNavigate, onLogout = onLogout)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MoreMenuScreen(onNavigate: (String) -> Unit, onLogout: () -> Unit) {
    Column(Modifier.fillMaxSize().background(SBBg)) {
        Column(
            Modifier.fillMaxWidth().background(SBSurface)
                .padding(horizontal = 18.dp, vertical = 14.dp)
        ) {
            Text("More", fontSize = 26.sp, fontWeight = FontWeight.Bold, color = SBOnSurface)
            Text("Tools, settings and account", fontSize = 13.sp, color = SBOnSurfaceVariant)
        }
        Divider(color = SBOutline, thickness = 0.8.dp)

        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                MoreGroup("Market & Pricing") {
                    MoreRow("📊", "Market Prices")       { onNavigate("market")   }
                    MoreRow("🏷️", "Price List & Rates")  { onNavigate("prices")   }
                }
            }
            item {
                MoreGroup("Team & Compliance") {
                    MoreRow("👥", "User Management")     { onNavigate("users")    }
                    MoreRow("🛡️", "Audit & Compliance")  { onNavigate("audit")    }
                }
            }
            item {
                MoreGroup("App") {
                    MoreRow("⚙️", "Settings")            { onNavigate("settings") }
                }
            }
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(SBSurface, RoundedCornerShape(14.dp))
                        .border(0.8.dp, SBOutline, RoundedCornerShape(14.dp))
                        .clickable(onClick = onLogout)
                        .padding(16.dp)
                ) {
                    Text("Sign Out", fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                        color = SBError)
                }
            }
        }
    }
}

@Composable
fun MoreGroup(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column {
        Text(
            title.uppercase(), fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
            color = SBOnSurfaceDim, letterSpacing = 0.8.sp,
            modifier = Modifier.padding(start = 4.dp, bottom = 6.dp)
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(SBSurface, RoundedCornerShape(14.dp))
                .border(0.8.dp, SBOutline, RoundedCornerShape(14.dp)),
            content = content
        )
    }
}

@Composable
fun MoreRow(emoji: String, label: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(emoji, fontSize = 18.sp, modifier = Modifier.width(28.dp))
        Spacer(Modifier.width(12.dp))
        Text(label, fontSize = 14.sp, fontWeight = FontWeight.Medium,
            color = SBOnSurface, modifier = Modifier.weight(1f))
        Icon(Icons.Default.ChevronRight, "Go",
            tint = SBOnSurfaceDim, modifier = Modifier.size(16.dp))
    }
    Divider(
        color = SBOutline, thickness = 0.8.dp,
        modifier = Modifier.padding(start = 56.dp)
    )
}
