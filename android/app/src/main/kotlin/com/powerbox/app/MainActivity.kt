package com.powerbox.app

import android.content.Intent
import android.content.IntentFilter
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.BatteryManager
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.powerbox.app/installer"
    private val SHORTCUT_CHANNEL = "com.powerbox.app/shortcut"
    private val BATTERY_CHANNEL = "com.powerbox.app/battery"
    private val ACTION_EXPRESS = "com.powerbox.app.SHORTCUT_EXPRESS"

    private var shortcutChannel: MethodChannel? = null

    // 冷启动时 Flutter 还没就绪，先缓存快捷方式动作，等 Dart 侧主动拉取
    private var pendingShortcut: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShortcutIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShortcutIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val success = installApk(filePath)
                        result.success(success)
                    } else {
                        result.error("INVALID_PATH", "文件路径无效", null)
                    }
                }
                "requestManageStoragePermission" -> {
                    requestManageStoragePermission()
                    result.success(true)
                }
                "isManageStoragePermissionGranted" -> {
                    result.success(isManageStoragePermissionGranted())
                }
                else -> result.notImplemented()
            }
        }

        // 电池信息 / 桌面小组件通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBatteryInfo" -> result.success(readBatteryInfo())
                    "refreshWidget" -> {
                        BatteryWidgetProvider.updateAll(applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // 桌面快捷方式通道
        shortcutChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHORTCUT_CHANNEL)
        shortcutChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShortcut" -> {
                    // 读取后清空，避免重复跳转
                    result.success(pendingShortcut)
                    pendingShortcut = null
                }
                else -> result.notImplemented()
            }
        }
    }

    /** 处理来自桌面快捷方式的 Intent */
    private fun handleShortcutIntent(intent: Intent?) {
        if (intent?.action == ACTION_EXPRESS) {
            pendingShortcut = "express"
            // 热启动时 Dart 侧已就绪，直接推送；冷启动时由 pendingShortcut 兜底
            shortcutChannel?.invokeMethod("onShortcut", "express")
        }
    }

    /** 通过 BatteryManager 读取实时电池数据（电池信息页对照展示用） */
    private fun readBatteryInfo(): Map<String, Any?> {
        val manager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager

        val statusIntent = try {
            ContextCompat.registerReceiver(
                this,
                null,
                IntentFilter(Intent.ACTION_BATTERY_CHANGED),
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
        } catch (e: Exception) {
            null
        }

        val status = statusIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
        val temperatureTenths = statusIntent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1) ?: -1
        val voltageMv = statusIntent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1) ?: -1

        val chargeCounterMicroAh = try {
            manager.getLongProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
        } catch (e: Exception) {
            -1L
        }
        val currentMicroA = try {
            manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
        } catch (e: Exception) {
            null
        }

        val currentMa = if (isCharging && currentMicroA != null) {
            val absMicroA = kotlin.math.abs(currentMicroA.toLong())
            if (absMicroA in 1..20_000_000) absMicroA / 1000.0 else null
        } else {
            null
        }

        return mapOf(
            "chargeCounterMah" to if (chargeCounterMicroAh >= 0) chargeCounterMicroAh / 1000.0 else null,
            "temperatureC" to if (temperatureTenths >= 0) temperatureTenths / 10.0 else null,
            "voltageMv" to if (voltageMv > 0) voltageMv else null,
            "currentMa" to currentMa,
            "isCharging" to isCharging,
        )
    }

    private fun isManageStoragePermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            true
        }
    }

    private fun requestManageStoragePermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!Environment.isExternalStorageManager()) {
                try {
                    val intent = Intent(android.provider.Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    intent.data = Uri.parse("package:$packageName")
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                } catch (e: Exception) {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                    } catch (e2: Exception) {
                        // 最终回退：跳转到应用详情设置页
                        val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:$packageName")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                    }
                }
            } else {
                // 已有权限，跳转到应用详情页让用户手动管理
                val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            }
        }
    }

    private fun installApk(filePath: String): Boolean {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                return false
            }

            val intent = Intent(Intent.ACTION_VIEW)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // Android 7.0+ 使用 FileProvider
                val uri = FileProvider.getUriForFile(
                    this,
                    "${packageName}.fileprovider",
                    file
                )
                intent.setDataAndType(uri, "application/vnd.android.package-archive")
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } else {
                intent.setDataAndType(Uri.fromFile(file), "application/vnd.android.package-archive")
            }

            startActivity(intent)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
}
