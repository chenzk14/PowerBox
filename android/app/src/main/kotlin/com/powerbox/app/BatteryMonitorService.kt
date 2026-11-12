package com.powerbox.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * 电池监控前台服务。
 *
 * 职责：
 * 1. 常驻前台（状态栏显示一条低打扰通知），保证进程不被 HyperOS Greezer 杀掉，
 *    从而能可靠接收系统 ACTION_BATTERY_CHANGED 广播。
 * 2. 每次电池状态变化（充电/放电、电量、温度、电压、电流变化）立即刷新桌面电池小组件。
 * 3. 开机后由 BatteryWidgetProvider / ClockWidgetProvider 的 BOOT_COMPLETED 启动本服务。
 * 4. 可选：按住一个 1x1 的全透明悬浮窗，进一步降低进程被系统回收的优先级。
 *
 * 前台服务类型用 specialUse 而不是 dataSync：
 * Android 15/16 对 dataSync 有「24 小时内累计最多 6 小时」的硬限制，超时后系统
 * 会要求服务停止，当天无法再次启动；specialUse 没有该时长限制。
 *
 * 与闹钟方案对比：HyperOS 对后台闹钟策略严格（Android 14+ 新安装应用的
 * SCHEDULE_EXACT_ALARM 默认不授予），前台服务是目前可靠的实时刷新手段。
 *
 * 通知：低打扰渠道 powerbox_battery_monitor，文案「PowerBox 电池监控运行中」/
 * 「桌面电池小组件实时刷新中」。
 */
class BatteryMonitorService : Service() {

    companion object {
        /** 重新读取悬浮窗开关并立即应用（开关变化时由 Activity 发来） */
        const val ACTION_UPDATE_OVERLAY = "com.powerbox.app.ACTION_UPDATE_OVERLAY"

        /** 与 MainActivity 共用同一份原生偏好 */
        private const val PREFS_NAME = "powerbox_prefs"
        private const val KEY_FLOATING_KEEP_ALIVE = "floating_keep_alive"
    }

    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "powerbox_battery_monitor"
    private val CHANNEL_NAME = "电池监控"
    private val CHANNEL_DESC = "桌面电池小组件实时刷新，低打扰，无声音无震动"

    private lateinit var batteryReceiver: BroadcastReceiver

    /** 1x1 透明悬浮窗；null 表示当前没有挂载 */
    private var overlayView: View? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
        batteryReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent?) {
                if (intent?.action == Intent.ACTION_BATTERY_CHANGED) {
                    // 电池状态变化：立即刷新电池小组件和时钟小组件的电量
                    BatteryWidgetProvider.updateAll(context)
                    ClockWidgetProvider.updateAll(context)
                }
            }
        }
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        // ACTION_BATTERY_CHANGED 是粘性广播，需用 registerReceiver 接收；应用进程存活期间有效
        ContextCompat.registerReceiver(
            this,
            batteryReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        // 每次 start 都按最新偏好应用一次；开关变化通过 ACTION_UPDATE_OVERLAY 触发
        applyOverlay()
        return START_STICKY
    }

    override fun onDestroy() {
        removeOverlay()
        try {
            unregisterReceiver(batteryReceiver)
        } catch (_: Exception) {
            // 忽略
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * 按偏好和权限决定是否挂载 1x1 透明悬浮窗。
     *
     * 说明：
     * - 悬浮窗只能降低进程被回收的优先级，进程已被杀后它无法复活；
     * - 1x1、alpha=0.01、不可触摸/不可聚焦，尽量做到用户无感；
     * - alpha 不用 0：完全透明的窗口在部分 ROM 上会被当作不可见，反而失去意义。
     */
    private fun applyOverlay() {
        val enabled = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .getBoolean(KEY_FLOATING_KEEP_ALIVE, false)
        if (enabled && canDrawOverlays()) {
            addOverlay()
        } else {
            removeOverlay()
        }
    }

    private fun addOverlay() {
        if (overlayView != null) return
        if (!canDrawOverlays()) return

        val manager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            1,
            1,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
            alpha = 0.01f
        }

        val view = View(this).apply {
            setBackgroundColor(Color.TRANSPARENT)
        }
        try {
            manager.addView(view, params)
            overlayView = view
        } catch (_: Exception) {
            // 权限被撤销或 ROM 拒绝：静默失败，下次 start 再试
            overlayView = null
        }
    }

    private fun removeOverlay() {
        val view = overlayView ?: return
        try {
            val manager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            manager.removeView(view)
        } catch (_: Exception) {
            // 窗口可能已被系统移除，忽略
        }
        overlayView = null
    }

    /** Android 6.0 以下没有悬浮窗特殊权限，直接视为可用 */
    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = CHANNEL_DESC
                // 低打扰：无声音、无震动、无呼吸灯、不弹出锁屏
                setSound(null, null)
                setVibrationPattern(null)
                enableLights(false)
                lockscreenVisibility = Notification.VISIBILITY_SECRET
            }
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val clickIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            },
            PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_battery_monitor)
            .setContentTitle("PowerBox 电池监控运行中")
            .setContentText("桌面电池小组件实时刷新中")
            .setContentIntent(clickIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOnlyAlertOnce(true)
            .build()
    }
}
