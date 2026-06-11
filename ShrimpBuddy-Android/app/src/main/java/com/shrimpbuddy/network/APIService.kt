package com.shrimpbuddy.network

import com.shrimpbuddy.models.*
import retrofit2.Response
import retrofit2.http.*

interface APIService {

    // ─── Auth ─────────────────────────────────────────────────────────────────
    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): Response<ApiResponse<AuthResponse>>

    @POST("auth/register")
    suspend fun register(@Body request: RegisterRequest): Response<ApiResponse<AuthResponse>>

    @POST("auth/forgot-password")
    suspend fun forgotPassword(@Body body: Map<String, String>): Response<ApiResponse<String>>

    @POST("auth/reset-password")
    suspend fun resetPassword(@Body body: Map<String, String>): Response<ApiResponse<String>>

    // ─── Dashboard ────────────────────────────────────────────────────────────
    @GET("dashboard")
    suspend fun getDashboard(): Response<ApiResponse<DashboardStats>>

    // ─── Sections ─────────────────────────────────────────────────────────────
    @GET("sections")
    suspend fun getSections(): Response<ApiResponse<List<Section>>>

    @POST("sections")
    suspend fun createSection(@Body body: Map<String, String>): Response<ApiResponse<Section>>

    // ─── Ponds ────────────────────────────────────────────────────────────────
    @GET("ponds")
    suspend fun getPonds(@Query("sectionId") sectionId: String? = null): Response<ApiResponse<List<Pond>>>

    @GET("ponds/{id}")
    suspend fun getPond(@Path("id") id: String): Response<ApiResponse<Pond>>

    @POST("ponds")
    suspend fun createPond(@Body request: CreatePondRequest): Response<ApiResponse<Pond>>

    // ─── Feed ─────────────────────────────────────────────────────────────────
    @GET("feed-logs")
    suspend fun getFeedLogs(
        @Query("pondId") pondId: String? = null,
        @Query("date") date: String? = null
    ): Response<ApiResponse<List<FeedLog>>>

    @POST("feed-logs")
    suspend fun logFeed(@Body request: CreateFeedLogRequest): Response<ApiResponse<FeedLog>>

    @GET("feed-inventory")
    suspend fun getFeedInventory(): Response<ApiResponse<List<FeedInventoryItem>>>

    @POST("feed-dispatch")
    suspend fun dispatchFeed(@Body request: FeedDispatchRequest): Response<ApiResponse<String>>

    // ─── Chemicals ────────────────────────────────────────────────────────────
    @GET("chemical-usage")
    suspend fun getChemicalLogs(@Query("pondId") pondId: String? = null): Response<ApiResponse<List<ChemicalLog>>>

    @POST("chemical-usage")
    suspend fun logChemical(@Body request: CreateChemicalLogRequest): Response<ApiResponse<ChemicalLog>>

    @GET("chemical-inventory")
    suspend fun getChemicalInventory(): Response<ApiResponse<List<ChemicalInventoryItem>>>

    // ─── Sampling ─────────────────────────────────────────────────────────────
    @GET("sampling-logs")
    suspend fun getSamplingLogs(@Query("pondId") pondId: String? = null): Response<ApiResponse<List<SamplingLog>>>

    @POST("sampling-logs")
    suspend fun logSampling(@Body request: CreateSamplingRequest): Response<ApiResponse<SamplingLog>>

    // ─── Water Parameters ─────────────────────────────────────────────────────
    @GET("water-parameters/{pondId}")
    suspend fun getWaterParameters(@Path("pondId") pondId: String): Response<ApiResponse<List<WaterParamEntry>>>

    @POST("water-parameters")
    suspend fun logWaterParameters(@Body body: Map<String, Any>): Response<ApiResponse<String>>

    // ─── Finance ──────────────────────────────────────────────────────────────
    @GET("finance")
    suspend fun getFinance(): Response<ApiResponse<List<FinanceTransaction>>>

    @POST("finance")
    suspend fun createTransaction(@Body request: CreateTransactionRequest): Response<ApiResponse<FinanceTransaction>>

    // ─── Harvest ──────────────────────────────────────────────────────────────
    @GET("harvest-forecasts")
    suspend fun getHarvestForecasts(): Response<ApiResponse<List<HarvestForecast>>>

    // ─── Market ───────────────────────────────────────────────────────────────
    @GET("market-prices")
    suspend fun getMarketPrices(): Response<ApiResponse<List<MarketPrice>>>

    // ─── Reports ──────────────────────────────────────────────────────────────
    @GET("reports")
    suspend fun getReports(): Response<ApiResponse<List<FarmReport>>>

    @POST("reports")
    suspend fun generateReport(@Body body: Map<String, String>): Response<ApiResponse<FarmReport>>

    // ─── Staff ────────────────────────────────────────────────────────────────
    @GET("users")
    suspend fun getUsers(): Response<ApiResponse<List<StaffUser>>>

    @GET("audit-logs")
    suspend fun getAuditLogs(): Response<ApiResponse<List<AuditLogEntry>>>

    // ─── Settings ─────────────────────────────────────────────────────────────
    @GET("settings")
    suspend fun getSettings(): Response<ApiResponse<AppSettings>>

    @PUT("settings")
    suspend fun updateSettings(@Body settings: AppSettings): Response<ApiResponse<AppSettings>>
}
