package com.powerbox.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.BatteryManager
import android.os.Build
import android.widget.RemoteViews
import androidx.core.content.ContextCompat

/**
 * PowerBox 时钟桌面小组件（2x2）。
 *
 * 上时、中分（大字号竖排），下排日期 + 星期 + 电量百分比（如 6日 周五 · 电量93%）。
 *
 * 时间怎么走（重要）：
 * - 时 / 分 / 日期 / 星期 全部使用系统 TextClock 控件。TextClock 在 Launcher 进程里
 *   接收系统 TIME_TICK 广播自行重绘，不需要 PowerBox 进程存活，也不依赖闹钟。
 *   （之前用 AlarmManager 每分钟刷新：Android 14+ 新安装应用的 SCHEDULE_EXACT_ALARM
 *   默认不授予，setExactAndAllowWhileIdle 抛 SecurityException，导致时间一直不动。）
 * - 只有"电量"这一段需要应用侧刷新，由 WidgetRefreshReceiver 定时触发，
 *   组件添加 / 开机 / App 保存校准值时也会更新。电量本身变化很慢，秒级精度无意义。
 *
 * 点击：打开系统时钟应用（点击组件不再刷新数据）。
 */
class ClockWidgetProvider : AppWidgetProvider() {

    companion object {
        /** 常见系统时钟应用包名，按优先级排列（放在最前面的先尝试） */
        private val CLOCK_PACKAGES = listOf(
            "com.android.deskclock",              // 小米 HyperOS / MIUI（本机确认）与 AOSP
            "com.miui.clock",                     // 部分 MIUI 版本
            "com.google.android.deskclock",       // Google 时钟
            "com.coloros.clock",                  // OPPO
            "com.oneplus.deskclock",              // 一加
            "com.huawei.deskclock",               // 华为
            "com.sec.android.app.clockpackage",   // 三星
        )

        /** APP_CLOCK 分类（系统时钟的标准入口，部分机型支持） */
        private const val CATEGORY_APP_CLOCK = "android.intent.category.APP_CLOCK"

        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, ClockWidgetProvider::class.java)
            val ids = appWidgetManager.getAppWidgetIds(component)
            if (ids.isEmpty()) return
            ids.forEach { updateWidget(context, appWidgetManager, it) }
        }

        private fun updateWidget(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_clock)

            // 时 / 分 / 日期 由 TextClock 自己走时，这里不能再用 setTextViewText 覆盖，
            // 否则会打断 TextClock 的格式化显示。只更新电量这一段。
            // 参考图格式：6日 周五 电量95%（日期与电量之间用空格分隔，不用"·"）
            val battery = batteryPercent(context)
            views.setTextViewText(
                R.id.clock_battery,
                "  电量${if (battery >= 0) "$battery%" else "--"}",
            )

            // 点击整个小组件 → 打开系统时钟应用
            views.setOnClickPendingIntent(
                R.id.widget_clock_root,
                PendingIntent.getActivity(
                    context,
                    6001,
                    resolveClockIntent(context),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )

            manager.updateAppWidget(appWidgetId, views)
        }

        /**
         * 打开系统时钟：
         * 1. 先按 APP_CLOCK 分类解析（若系统里有应用声明），并排除 PowerBox 自己；
         * 2. 再按常见包名依次取启动 Intent；
         * 3. 都找不到时打开 PowerBox 本体。
         *
         * 注意：包名必须在 AndroidManifest 的 <queries> 里声明，否则 Android 11+ 的
         * 包可见性会让 getLaunchIntentForPackage 直接返回 null（这正是之前点击没反应的原因）。
         */
        private fun resolveClockIntent(context: Context): Intent {
            val implicit = Intent(Intent.ACTION_MAIN).apply {
                addCategory(CATEGORY_APP_CLOCK)
            }
            val info = try {
                context.packageManager.resolveActivity(
                    implicit,
                    PackageManager.MATCH_DEFAULT_ONLY,
                )
            } catch (_: Exception) {
                null
            }
            if (info != null && info.activityInfo.packageName != context.packageName) {
                return Intent(implicit).apply {
                    component = ComponentName(info.activityInfo.packageName, info.activityInfo.name)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }

            CLOCK_PACKAGES.forEach { pkg ->
                context.packageManager.getLaunchIntentForPackage(pkg)?.let {
                    return it.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
                }
            }

            // 找不到系统时钟：打开 PowerBox 本体（至少给用户一个可见反馈）
            return Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }

        /** 读取电量百分比（0-100），读不到返回 -1 */
        private fun batteryPercent(context: Context): Int {
            return try {
                val manager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                val pct = manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                if (pct in 0..100) pct else fallbackPercent(context)
            } catch (_: Exception) {
                fallbackPercent(context)
            }
        }

        /** 兜底：粘性 ACTION_BATTERY_CHANGED 的 level / scale */
        private fun fallbackPercent(context: Context): Int {
            return try {
                val intent = ContextCompat.registerReceiver(
                    context,
                    null,
                    IntentFilter(Intent.ACTION_BATTERY_CHANGED),
                    ContextCompat.RECEIVER_EXPORTED,
                )
                val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
                if (level >= 0 && scale > 0) level * 100 / scale else -1
            } catch (_: Exception) {
                -1
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        // 小组件添加/更新时，刷新并（重）排定时刷新
        WidgetTickScheduler.refreshSchedule(context)
        updateAll(context)
    }

    override fun onDisabled(context: Context) {
        // 全部时钟小组件移除时：连同电池小组件一起判断是否还要保留定时刷新
        WidgetTickScheduler.refreshSchedule(context)
        super.onDisabled(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                startMonitorService(context)
                WidgetTickScheduler.refreshSchedule(context)
                updateAll(context)
            }
        }
        super.onReceive(context, intent)
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
