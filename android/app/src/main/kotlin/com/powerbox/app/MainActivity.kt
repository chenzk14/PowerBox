package com.powerbox.app

import android.content.ComponentName
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.IntentFilter
import android.content.Context
import android.provider.MediaStore
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
                "openFolder" -> {
                    val folderPath = call.argument<String>("path")
                    if (folderPath != null) {
                        result.success(openFolder(folderPath))
                    } else {
                        result.error("INVALID_PATH", "文件夹路径无效", null)
                    }
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

    /**
     * 打开指定文件夹。
     *
     * 为什么不用之前的方式：
     * 1. resource/folder 在本机没有任何应用声明支持，startActivity 只能落到应用选择器；
     * 2. vnd.android.document/directory 只有系统 DocumentsUI 支持，小米文件管理器不支持，
     *    所以选择器里看不到「文件管理」；
     * 3. Android 11+ 的 ExternalStorageProvider 禁止访问 Android/data、Android/obb，
     *    应用私有目录无法直接暴露给文件管理器。
     *
     * 因此应用私有目录会先用 MediaStore 复制到公共 Download/TodoList（无需存储权限），
     * 再用 ExternalStorageProvider 的公共目录 URI + DocumentsUI 打开。
     */
    private fun openFolder(folderPath: String): Boolean {
        val folder = File(folderPath)
        if (!folder.exists()) return false

        val publicRoot = Environment.getExternalStorageDirectory().absolutePath
        val isPrivateDir = folderPath.contains("/Android/data/") ||
            folderPath.contains("/Android/obb/")

        val folderToOpen = if (isPrivateDir) {
            // 应用私有目录：复制到公共 Download/TodoList 后再打开
            copyFolderToPublicDownloads(folder) ?: return false
        } else {
            if (!folderPath.startsWith(publicRoot)) return false
            folderPath
        }

        val relativePath = folderToOpen.removePrefix(publicRoot).trim('/')
        val documentId = if (relativePath.isEmpty()) "primary:" else "primary:$relativePath"
        val uri = Uri.parse(
            "content://com.android.externalstorage.documents/document/" + Uri.encode(documentId)
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "vnd.android.document/directory")
            // FilesActivity 只认 EXTRA_INITIAL_URI 作为初始目录，
            // 只设置 data 会退回默认根目录（实测在 HyperOS 上如此）。
            putExtra("android.provider.extra.INITIAL_URI", uri)
            // 显式指定系统「文件」应用，避免弹出选择器
            component = ComponentName(
                "com.google.android.documentsui",
                "com.android.documentsui.files.FilesActivity"
            )
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        return try {
            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * 把应用私有目录里的文件复制到公共 Download/TodoList。
     * Android 10+ 使用 MediaStore，无需 MANAGE_EXTERNAL_STORAGE 权限。
     * 返回目标目录的绝对路径。
     */
    private fun copyFolderToPublicDownloads(folder: File): String? {
        val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/TodoList"
        val files = folder.listFiles()?.filter { it.isFile } ?: return null
        if (files.isEmpty()) return null

        val publicDir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "TodoList"
        )

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            // Android 10 以下直接写公共目录
            if (!publicDir.exists() && !publicDir.mkdirs()) return null
            files.forEach { source ->
                try {
                    source.copyTo(File(publicDir, source.name), overwrite = true)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
            return publicDir.absolutePath
        }

        val resolver = contentResolver
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        files.forEach { source ->
            try {
                // 先删除同名旧文件，避免出现 todo_data (1).json
                resolver.query(
                    collection,
                    arrayOf(MediaStore.MediaColumns._ID),
                    "${MediaStore.MediaColumns.RELATIVE_PATH}=? AND " +
                        "${MediaStore.MediaColumns.DISPLAY_NAME}=?",
                    arrayOf("$relativePath/", source.name),
                    null
                )?.use { cursor ->
                    while (cursor.moveToNext()) {
                        val oldUri = ContentUris.withAppendedId(collection, cursor.getLong(0))
                        resolver.delete(oldUri, null, null)
                    }
                }

                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, source.name)
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val uri = resolver.insert(collection, values) ?: return@forEach
                try {
                    resolver.openOutputStream(uri)?.use { out ->
                        source.inputStream().use { it.copyTo(out) }
                    }
                    values.clear()
                    values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    resolver.update(uri, values, null, null)
                } catch (e: Exception) {
                    e.printStackTrace()
                    resolver.delete(uri, null, null)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        return publicDir.absolutePath
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
