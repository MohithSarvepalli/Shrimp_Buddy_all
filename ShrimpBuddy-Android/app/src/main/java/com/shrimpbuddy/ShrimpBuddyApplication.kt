package com.shrimpbuddy

import android.app.Application
import com.shrimpbuddy.network.RetrofitClient

class ShrimpBuddyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        RetrofitClient.init(this)
    }
}
