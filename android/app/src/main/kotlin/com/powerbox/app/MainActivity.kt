package com.powerbox.app

import android.app.ActivityManager
import android.content.Intent
import android.content.IntentFilter
import android.content.Context
import android.provider.Settings
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
    private val TASK_CHANNEL = "com.powerbox.app/task"
    private val KEEPALIVE_CHANNEL = "com.powerbox.app/keepalive"
    private val ACTION_EXPRESS = "com.powerbox.app.SHORTCUT_EXPRESS"

    /** 与 BatteryMonitorService 共用的原生偏好 */
    private val PREFS_NAME = "powerbox_prefs"
    private val KEY_HIDE_FROM_RECENTS = "hide_from_recents"
    private val KEY_FLOATING_KEEP_ALIVE = "floating_keep_alive"

    private var shortcutChannel: MethodChannel? = null

    // 是否已把「隐藏最近任务卡片」应用到当前任务，避免 onPostResume 反复执行
    private var hideFromRecentsApplied = false

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
        // 热启动时任务可能被重建，重新套用一次隐藏设置
        hideFromRecentsApplied = applyHideFromRecents()
    }

    override fun onPostResume() {
        super.onPostResume()
        // 首次启动时 appTasks 可能还没就绪，这里再试一次；
        // 只有真正拿到任务并处理后才置位，避免任务列表为空时错过
        if (!hideFromRecentsApplied) {
            hideFromRecentsApplied = applyHideFromRecents()
        }
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
                        startMonitorService(applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // 最近任务卡片隐藏通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TASK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isHideFromRecents" -> {
                        val value = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                            .getBoolean(KEY_HIDE_FROM_RECENTS, false)
                        result.success(value)
                    }
                    "setHideFromRecents" -> {
                        val value = call.argument<Boolean>("value") ?: false
                        getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit()
                            .putBoolean(KEY_HIDE_FROM_RECENTS, value)
                            .apply()
                        // 立即对当前任务生效；返回是否真的拿到了任务
                        hideFromRecentsApplied = applyHideFromRecents()
                        result.success(hideFromRecentsApplied)
                    }
                    else -> result.notImplemented()
                }
            }

        // 透明悬浮窗保活通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KEEPALIVE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isFloatingKeepAlive" -> {
                        val value = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                            .getBoolean(KEY_FLOATING_KEEP_ALIVE, false)
                        result.success(value)
                    }
                    "isOverlayPermissionGranted" -> result.success(canDrawOverlays())
                    "requestOverlayPermission" -> {
                        requestOverlayPermission()
                        result.success(true)
                    }
                    "setFloatingKeepAlive" -> {
                        val value = call.argument<Boolean>("value") ?: false
                        if (value && !canDrawOverlays()) {
                            // 没有悬浮窗权限时不要假装开启，交给 Dart 侧提示用户授权
                            result.success(false)
                        } else {
                            getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit()
                                .putBoolean(KEY_FLOATING_KEEP_ALIVE, value)
                                .apply()
                            updateOverlaySetting()
                            result.success(true)
                        }
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

    /**
     * 把「隐藏最近任务卡片」设置应用到当前 App 的所有任务。
     *
     * 说明：
     * - setExcludeFromRecents 只影响「最近任务」列表是否显示，任务本身仍在运行；
     * - 应用无法替用户「锁定后台」，锁定需要在最近任务里手动下拉卡片；
     * - 返回 true 表示至少拿到了一个任务并尝试应用。
     */
    private fun applyHideFromRecents(): Boolean {
        val enabled = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .getBoolean(KEY_HIDE_FROM_RECENTS, false)
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val tasks = manager.appTasks
        tasks.forEach { task ->
            try {
                task.setExcludeFromRecents(enabled)
            } catch (_: Exception) {
                // 个别 ROM 可能不支持，跳过该任务，不影响其余任务
            }
        }
        return tasks.isNotEmpty()
    }

    /** 通知电池监控服务重新读取「透明悬浮窗保活」开关 */
    private fun updateOverlaySetting() {
        val intent = Intent(this, BatteryMonitorService::class.java).apply {
            action = BatteryMonitorService.ACTION_UPDATE_OVERLAY
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    /** 是否已授予「显示悬浮窗」特殊权限；Android 6.0 以下没有该权限 */
    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    /** 跳转系统的「显示悬浮窗」授权页 */
    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (_: Exception) {
            try {
                startActivity(
                    Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            } catch (_: Exception) {
                // 系统没有该设置页时忽略
            }
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
                return false;
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

    /** 启动电池监控前台服务（Android 8+ 需要 startForegroundService） */
    private fun startMonitorService(context: Context) {
        val intent = Intent(context, BatteryMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }
}
