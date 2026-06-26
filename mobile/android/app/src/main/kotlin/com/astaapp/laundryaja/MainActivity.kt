package com.astaapp.laundryaja

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Force NormalTheme as early as possible — this runs after the OS
        // inflates LaunchTheme, so we immediately switch to our app theme
        // to kill the splash flash.
        setTheme(R.style.NormalTheme)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.navigationBarColor = Color.parseColor("#F5F7FA")
            window.statusBarColor = Color.TRANSPARENT
        }
        // Android 10+ (API 29): kill the auto scrim/divider that creates the
        // dark border above the gesture bar when nav bar color ≈ window background.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
        super.onCreate(savedInstanceState)
    }
}