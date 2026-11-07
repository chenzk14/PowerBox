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
import android.os.Build
import android.os.IBinder
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
 *
 * 与闹钟方案对比：HyperOS 对后台闹钟策略严格（Android 14+ 新安装应用的
 * SCHEDULE_EXACT_ALARM 默认不授予），前台服务是目前可靠的实时刷新手段。
 *
 * 通知：低打扰渠道 powerbox_battery_monitor，文案「PowerBox 电池监控运行中」/
 * 「桌面电池小组件实时刷新中」。
 */
class BatteryMonitorService : Service() {

    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "powerbox_battery_monitor"
    private val CHANNEL_NAME = "电池监控"
    private val CHANNEL_DESC = "桌面电池小组件实时刷新，低打扰，无声音无震动"

    private lateinit var batteryReceiver: BroadcastReceiver

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
        batteryReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent?) {
                if (intent?.action == Intent.ACTION_BATTERY_CHANGED) {
                    // 电池状态变化：立即刷新电池小组件
                    BatteryWidgetProvider.updateAll(context)
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
        return START_STICKY
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(batteryReceiver)
        } catch (_: Exception) {
            // 忽略
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

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
