package com.shrimpbuddy.network

import android.content.Context
import com.shrimpbuddy.config.APIConfig
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit

object TokenManager {
    private const val PREFS_KEY = "sb_prefs"
    private const val TOKEN_KEY = "sb_auth_token"
    private var token: String? = null

    fun getToken(context: Context): String? {
        if (token == null) {
            token = context.getSharedPreferences(PREFS_KEY, Context.MODE_PRIVATE)
                .getString(TOKEN_KEY, null)
        }
        return token
    }

    fun saveToken(context: Context, t: String) {
        token = t
        context.getSharedPreferences(PREFS_KEY, Context.MODE_PRIVATE)
            .edit().putString(TOKEN_KEY, t).apply()
    }

    fun clearToken(context: Context) {
        token = null
        context.getSharedPreferences(PREFS_KEY, Context.MODE_PRIVATE)
            .edit().remove(TOKEN_KEY).apply()
    }
}

object RetrofitClient {
    private var context: Context? = null

    fun init(ctx: Context) { context = ctx.applicationContext }

    private val authInterceptor = Interceptor { chain ->
        val original = chain.request()
        val ctx = context
        val token = if (ctx != null) TokenManager.getToken(ctx) else null
        val request = if (token != null) {
            original.newBuilder()
                .header("Authorization", "Bearer $token")
                .header("Content-Type", "application/json")
                .build()
        } else {
            original.newBuilder()
                .header("Content-Type", "application/json")
                .build()
        }
        chain.proceed(request)
    }

    private val loggingInterceptor = HttpLoggingInterceptor().apply {
        level = HttpLoggingInterceptor.Level.BODY
    }

    private val httpClient = OkHttpClient.Builder()
        .addInterceptor(authInterceptor)
        .addInterceptor(loggingInterceptor)
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    private val retrofit = Retrofit.Builder()
        .baseUrl(APIConfig.BASE_URL)
        .client(httpClient)
        .addConverterFactory(GsonConverterFactory.create())
        .build()

    val api: APIService = retrofit.create(APIService::class.java)
}
