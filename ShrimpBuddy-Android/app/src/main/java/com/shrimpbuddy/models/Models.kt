package com.shrimpbuddy.models

import com.google.gson.annotations.SerializedName

// ─── Generic wrappers ─────────────────────────────────────────────────────────

data class ApiResponse<T>(
    val success: Boolean,
    val data: T?,
    val message: String?,
    val error: String?
)

// ─── Auth ─────────────────────────────────────────────────────────────────────

data class LoginRequest(val email: String, val password: String)

data class RegisterRequest(
    val farmName: String,
    val name: String,
    val email: String,
    val password: String
)

data class AuthResponse(val token: String, val user: AppUser)

data class AppUser(
    val id: String,
    val name: String,
    val email: String,
    val role: String,
    val farmName: String,
    val initials: String
)

// ─── Dashboard ────────────────────────────────────────────────────────────────

data class DashboardStats(
    val activePonds: Int = 0,
    val stablePonds: Int = 0,
    val attentionPonds: Int = 0,
    val criticalPonds: Int = 0,
    val feedLoggedToday: Double = 0.0,
    val feedDailyTarget: Double = 0.0,
    val avgSurvival: Double = 0.0,
    val survivalChange: Double = 0.0,
    val fcr: Double = 0.0,
    val alerts: List<FarmAlert> = emptyList(),
    val sectionHealth: List<SectionHealth> = emptyList(),
    val timeline: List<TimelineEvent> = emptyList(),
    val feedTrend: List<FeedTrendPoint> = emptyList(),
    val sectionFeedLogs: List<SectionFeedLog> = emptyList()
)

data class FarmAlert(val id: String, val message: String, val severity: String)
data class SectionHealth(val id: String, val name: String, val status: String)
data class TimelineEvent(val id: String, val time: String, val event: String, val detail: String, val status: String)

data class FeedTrendPoint(
    val label: String,  // e.g. "Mon"
    val value: Double   // kg
)

data class SectionFeedLog(
    val id: String,
    val sectionName: String,
    val feedKg: Double,
    val time: String,
    val status: String
)

// ─── Sections ─────────────────────────────────────────────────────────────────

data class Section(
    val id: String,
    val name: String,
    val code: String,
    val pondCount: Int,
    val biomassKg: Double,
    val stockedDate: String
)

// ─── Ponds ────────────────────────────────────────────────────────────────────

data class Pond(
    val id: String,
    val pondId: String,
    val sectionId: String,
    val sectionName: String,
    val type: String,
    val doc: Int,
    val abw: Double,
    val feedTodayKg: Double,
    val survivalPct: Double,
    val status: String,
    val stockedDate: String,
    val seedCount: Int
)

data class CreatePondRequest(
    val sectionId: String,
    val pondId: String,
    val stockedDate: String,
    val seedCount: Int,
    val type: String
)

// ─── Feed ─────────────────────────────────────────────────────────────────────

data class FeedLog(
    val id: String,
    val pondId: String,
    val feedName: String,
    val totalKg: Double,
    val date: String,
    val time: String,
    val status: String,
    val loggedBy: String? = null,
    val sectionId: String? = null,
    val sectionName: String? = null
)

data class CreateFeedLogRequest(
    val pondId: String,
    val feedName: String,
    val totalKg: Double,
    val time: String
)

data class FeedInventoryItem(
    val id: String,
    val name: String,
    val stockKg: Double,
    val category: String,
    val pricePerKg: Double,
    val sectionId: String? = null
)

data class FeedDispatch(
    val id: String,
    val toSectionId: String,
    val toSectionName: String? = null,
    val feedVariety: String,
    val quantityKg: Double,
    val date: String,
    val dispatchedBy: String? = null
)

data class FeedDispatchRequest(
    val toSectionId: String,
    val feedVariety: String,
    val quantityKg: Double
)

// ─── Chemicals ────────────────────────────────────────────────────────────────

data class ChemicalLog(
    val id: String,
    val pondId: String,
    val name: String,
    val quantity: Double,
    val unit: String,
    val purpose: String,
    val date: String,
    val loggedBy: String?
)

data class CreateChemicalLogRequest(
    val pondId: String,
    val name: String,
    val quantity: Double,
    val unit: String,
    val purpose: String
)

data class ChemicalInventoryItem(
    val id: String,
    val name: String,
    val stock: Double,
    val unit: String,
    val ratePerUnit: Double,
    val sectionId: String? = null
)

// ─── Sampling ─────────────────────────────────────────────────────────────────

data class SamplingLog(
    val id: String,
    val pondId: String,
    val date: String,
    val abw: Double,
    val survivalPct: Double,
    val sampleCount: Int,
    val loggedBy: String? = null,
    val sectionId: String? = null,
    val sectionName: String? = null
)

data class CreateSamplingRequest(
    val pondId: String,
    val abw: Double,
    val survivalPct: Double,
    val sampleCount: Int
)

// ─── Water Parameters ─────────────────────────────────────────────────────────

data class WaterParamEntry(
    val id: String,
    val name: String,
    val value: Double,
    val unit: String,
    val range: String,
    val status: String
)

// ─── Finance ──────────────────────────────────────────────────────────────────

data class FinanceTransaction(
    val id: String,
    val date: String,
    val title: String,
    val type: String,
    val amount: Double,
    val category: String,
    val note: String?
)

data class CreateTransactionRequest(
    val title: String,
    val type: String,
    val amount: Double,
    val category: String,
    val note: String?
)

// ─── Harvest ──────────────────────────────────────────────────────────────────

data class HarvestForecast(
    val id: String,
    val pondId: String,
    val currentAbw: Double,
    val targetAbw: Double,
    val daysLeft: Int,
    val estimatedBiomassKg: Double,
    val status: String
)

// ─── Market ───────────────────────────────────────────────────────────────────

data class MarketPrice(
    val id: String,
    val size: String,
    val pricePerKg: Double,
    val trend: String,
    val updatedAt: String
)

// ─── Reports ──────────────────────────────────────────────────────────────────

data class FarmReport(
    val id: String,
    val title: String,
    val type: String,
    val generatedAt: String,
    val downloadUrl: String?
)

// ─── Staff ────────────────────────────────────────────────────────────────────

data class StaffUser(
    val id: String,
    val name: String,
    val email: String,
    val role: String,
    val status: String,
    val initials: String
)

data class AuditLogEntry(
    val id: String,
    val time: String,
    val user: String,
    val event: String,
    val detail: String,
    val risk: String
)

// ─── Settings ─────────────────────────────────────────────────────────────────

data class AppSettings(
    val farmName: String,
    val farmLocation: String,
    val notificationsEnabled: Boolean,
    val alertThresholdAmmonia: Double,
    val alertThresholdDO: Double,
    val feedReminderEnabled: Boolean,
    val defaultFeedRounds: Int,
    val currencySymbol: String,
    val language: String
)
