package com.bitchat.bitchat

import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.content.Context
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.bitchat.permissions/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBatteryOptimizationDisabled" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            pm.isIgnoringBatteryOptimizations(packageName)
                        } catch (e: Exception) {
                            false
                        }
                    } else {
                        true
                    }
                    result.success(isIgnoring)
                }
                "requestDisableBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent()
                            intent.action = android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                            intent.data = Uri.parse("package:$packageName")
                            // Launch intent; the activity result will be handled by the OS
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to open battery optimization settings: ${e.message}", null)
                        }
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

