package com.shrimpbuddy.config

object APIConfig {
    // ─── Set this to your web backend base URL ────────────────────────────────
    // 10.0.2.2 is the Android emulator's alias for host machine localhost
    // If running on a physical device, use your computer's local IP (e.g. http://192.168.x.x:8085/api/v1/)
    const val BASE_URL = "http://10.0.2.2:8085/api/v1/"
    // ──────────────────────────────────────────────────────────────────────────

    object Endpoints {
        // Auth
        const val LOGIN           = "auth/login"
        const val REGISTER        = "auth/register"
        const val FORGOT_PASSWORD = "auth/forgot-password"
        const val RESET_PASSWORD  = "auth/reset-password"
        // Dashboard
        const val DASHBOARD       = "dashboard"
        // Sections
        const val SECTIONS        = "sections"
        // Ponds
        const val PONDS           = "ponds"
        fun pondDetail(id: String) = "ponds/$id"
        // Feed
        const val FEED_LOGS       = "feed-logs"
        const val FEED_INVENTORY  = "feed-inventory"
        const val FEED_DISPATCH   = "feed-dispatch"
        // Chemicals
        const val CHEMICAL_USAGE  = "chemical-usage"
        const val CHEMICAL_INV    = "chemical-inventory"
        // Sampling
        const val SAMPLING        = "sampling-logs"
        // Water
        const val WATER_PARAMS    = "water-parameters"
        fun waterParams(pondId: String) = "water-parameters/$pondId"
        // Finance
        const val FINANCE         = "finance"
        // Harvest
        const val HARVEST         = "harvest-forecasts"
        // Market
        const val MARKET          = "market-prices"
        // Reports
        const val REPORTS         = "reports"
        // Staff
        const val USERS           = "users"
        const val AUDIT           = "audit-logs"
        // Settings
        const val SETTINGS        = "settings"
    }
}
