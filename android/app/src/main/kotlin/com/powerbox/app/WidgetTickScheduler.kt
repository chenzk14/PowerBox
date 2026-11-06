package com.powerbox.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock

/**
 * 小组件定时刷新调度器（只负责"电量"这类需要应用侧读取的数据）。
 *
 * 重要：
 * - 时钟的时/分/日期由 TextClock 在 Launcher 进程里自己走时，与本调度器无关。
 * - Android 14（API 34）起，新安装应用的 SCHEDULE_EXACT_ALARM 默认不授予，
 *   setExactAndAllowWhileIdle 会抛 SecurityException。所以这里先判断
 *   canScheduleExactAlarms()：允许则用精确闹钟，否则降级为
 *   setAndAllowWhileIdle（非精确，doze 下系统约每 9 分钟唤醒一次，亮屏时约 1 分钟），
 *   对"电量百分比"这种慢变量完全够用。
 *
 * 由 WidgetRefreshReceiver 执行刷新并自我续期；
 * 在小组件被移除、开机时统一管理（取消或重排）。
 */
object WidgetTickScheduler {
    const val ACTION_TICK = "com.powerbox.app.ACTION_WIDGET_TICK"

    /** 每 60 秒请求一次（非精确闹钟时由系统按 doze 策略合并） */
    private const val INTERVAL_MS = 60_000L

    fun schedule(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = tickPendingIntent(context)
        val triggerAt = SystemClock.elapsedRealtime() + INTERVAL_MS
        try {
            if (canUseExactAlarm(alarmManager)) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    pending,
                )
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    pending,
                )
            }
        } catch (_: SecurityException) {
            // 极端情况：权限在两次检查之间被撤销，退回非精确闹钟
            try {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    pending,
                )
            } catch (_: SecurityException) {
                // 系统完全禁止闹钟：放弃本轮，等下一次组件更新再排
            }
        }
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(tickPendingIntent(context))
    }

    /** 两个小组件都被移除时取消定时刷新；否则（重）排一次 */
    fun refreshSchedule(context: Context) {
        if (hasAnyWidget(context)) {
            schedule(context)
        } else {
            cancel(context)
        }
    }

    /** Android 12+ 才有精确闹钟开关；更低版本直接允许 */
    private fun canUseExactAlarm(alarmManager: AlarmManager): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    private fun tickPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, WidgetRefreshReceiver::class.java).apply {
            action = ACTION_TICK
        }
        return PendingIntent.getBroadcast(
            context,
            5001,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun hasAnyWidget(context: Context): Boolean {
        val manager = android.appwidget.AppWidgetManager.getInstance(context)
        val clockIds = manager.getAppWidgetIds(
            android.content.ComponentName(context, ClockWidgetProvider::class.java),
        )
        val batteryIds = manager.getAppWidgetIds(
            android.content.ComponentName(context, BatteryWidgetProvider::class.java),
        )
        return clockIds.isNotEmpty() || batteryIds.isNotEmpty()
    }
}
