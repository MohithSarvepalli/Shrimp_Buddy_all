package com.shrimpbuddy

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.shrimpbuddy.network.RetrofitClient
import com.shrimpbuddy.ui.navigation.ShrimpBuddyApp
import com.shrimpbuddy.ui.theme.ShrimpBuddyTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // Initialize Retrofit with app context for token management
        RetrofitClient.init(this)
        setContent {
            ShrimpBuddyTheme {
                ShrimpBuddyApp()
            }
        }
    }
}
