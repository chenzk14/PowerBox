package com.powerbox.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import androidx.core.content.ContextCompat
import java.util.Locale

/**
 * PowerBox 电池桌面小组件。
 *
 * 布局：两排五列（设计容量 / 实时容量 / 最大容量 / 实时容量比 / 最大容量比，
 *       电池温度 / 电池电压 / 充电电压 / 充电电流 / 充电功率）。
 *
 * 数据来源：
 * - 实时数据：BatteryManager + 粘性 ACTION_BATTERY_CHANGED 广播（系统公开 API，无需 root）。
 * - 设计容量 / 最大容量：HyperOS 隐藏了健康度百分比，系统不向第三方应用开放
 *   charge_full / charge_full_design，因此由用户在 App「电池信息」页手动校准，
 *   存储在 FlutterSharedPreferences（key 带 flutter. 前缀）。
 *
 * 刷新：
 * - AlarmManager 每分钟触发（WidgetRefreshReceiver）
 * - AppWidgetProviderInfo.updatePeriodMillis（系统最短 30 分钟）
 * - 点击整个小组件
 * - App 保存校准值后调用 refreshWidget
 */
class BatteryWidgetProvider : AppWidgetProvider() {

    companion object {
        /** App「电池信息」页保存校准值后触发的刷新动作 */
        const val ACTION_REFRESH = "com.powerbox.app.ACTION_BATTERY_WIDGET_REFRESH"

        private const val PREFS_FILE = "FlutterSharedPreferences"
        private const val KEY_DESIGN_CAPACITY = "flutter.battery_design_capacity"
        private const val KEY_MAX_CAPACITY = "flutter.battery_max_capacity"

        /** 小米 14 标称设计容量（mAh），用户未校准时的默认值 */
        private const val DEFAULT_CAPACITY_MAH = 4610

        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val component = android.content.ComponentName(context, BatteryWidgetProvider::class.java)
            val ids = appWidgetManager.getAppWidgetIds(component)
            if (ids.isEmpty()) return
            ids.forEach { updateWidget(context, appWidgetManager, it) }
        }

        private fun updateWidget(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
            val info = readBatteryInfo(context)

            val views = android.widget.RemoteViews(context.packageName, R.layout.widget_battery)
            views.setTextViewText(R.id.battery_design_value, info.designCapacityMah.toString())
            views.setTextViewText(R.id.battery_realtime_value, info.chargeCounterMah?.toString() ?: "--")
            views.setTextViewText(R.id.battery_max_value, info.maxCapacityMah.toString())
            views.setTextViewText(R.id.battery_realtime_ratio, info.realtimeRatio?.let { formatPercent(it) } ?: "--")
            views.setTextViewText(R.id.battery_max_ratio, formatPercent(info.maxRatio))
            views.setTextViewText(R.id.battery_temp, info.temperatureC?.let { formatOneDecimal(it) } ?: "--")
            views.setTextViewText(R.id.battery_voltage, info.voltageMv?.let { formatTwoDecimals(it / 1000.0) } ?: "--")
            views.setTextViewText(R.id.battery_charge_voltage, info.chargeVoltageMv?.let { formatTwoDecimals(it / 1000.0) } ?: "--")
            views.setTextViewText(R.id.battery_current, info.currentMa?.let { formatTwoDecimals(it / 1000.0) } ?: "--")
            views.setTextViewText(R.id.battery_power, info.powerW?.let { formatPower(it) } ?: "--")

            // 点击整个小组件 → 立即刷新
            val refreshIntent = Intent(context, BatteryWidgetProvider::class.java).apply {
                action = ACTION_REFRESH
            }
            views.setOnClickPendingIntent(
                R.id.widget_battery_root,
                PendingIntent.getBroadcast(
                    context,
                    2,
                    refreshIntent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )

            manager.updateAppWidget(appWidgetId, views)
        }

        // ---------- 数据读取 ----------

        private data class BatteryInfo(
            val designCapacityMah: Int,
            val maxCapacityMah: Int,
            val chargeCounterMah: Long?,
            val realtimeRatio: Double?,
            val maxRatio: Double,
            val temperatureC: Double?,
            val voltageMv: Int?,
            val chargeVoltageMv: Int?,
            val currentMa: Double?,
            val powerW: Double?,
        )

        private fun readBatteryInfo(context: Context): BatteryInfo {
            // 校准值（mAh）
            val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            val design = parseCapacity(prefs.getString(KEY_DESIGN_CAPACITY, null)) ?: DEFAULT_CAPACITY_MAH
            val max = parseCapacity(prefs.getString(KEY_MAX_CAPACITY, null)) ?: design

            // 粘性广播读当前电池状态
            val statusIntent = batteryStatusIntent(context)
            val status = statusIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL
            val temperatureTenths = statusIntent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1) ?: -1
            val voltageMv = statusIntent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1) ?: -1
            val chargeCounterMicroAh = chargeCounterMicroAh(context)

            val temperatureC = if (temperatureTenths >= 0) temperatureTenths / 10.0 else null
            val realtimeMah = if (chargeCounterMicroAh >= 0) chargeCounterMicroAh / 1000L else null
            val realtimeRatio = if (realtimeMah != null && max > 0) realtimeMah * 100.0 / max else null
            val maxRatio = if (design > 0) max * 100.0 / design else 100.0

            // 瞬时电流（μA），小米上充电时可能为负值，统一取绝对值；无效值或异常值丢弃
            val currentMicroA = currentMicroA(context)
            val currentMa = if (isCharging && currentMicroA != null && currentMicroA > 0 && currentMicroA <= 20_000_000) {
                currentMicroA / 1000.0
            } else {
                null
            }
            val powerW = if (currentMa != null && voltageMv > 0) {
                voltageMv / 1000.0 * (currentMa / 1000.0)
            } else {
                null
            }
            val chargeVoltage = if (isCharging && voltageMv > 0) voltageMv else null

            return BatteryInfo(
                designCapacityMah = design,
                maxCapacityMah = max,
                chargeCounterMah = realtimeMah,
                realtimeRatio = realtimeRatio,
                maxRatio = maxRatio,
                temperatureC = temperatureC,
                voltageMv = if (voltageMv > 0) voltageMv else null,
                chargeVoltageMv = chargeVoltage,
                currentMa = currentMa,
                powerW = powerW,
            )
        }

        /** 读取粘性 ACTION_BATTERY_CHANGED，拿不到返回 null */
        private fun batteryStatusIntent(context: Context): Intent? {
            return try {
                ContextCompat.registerReceiver(
                    context,
                    null,
                    IntentFilter(Intent.ACTION_BATTERY_CHANGED),
                    ContextCompat.RECEIVER_EXPORTED,
                )
            } catch (_: Exception) {
                null
            }
        }

        private fun chargeCounterMicroAh(context: Context): Long {
            return try {
                val manager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                manager.getLongProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
            } catch (_: Exception) {
                -1L
            }
        }

        private fun currentMicroA(context: Context): Long? {
            return try {
                val manager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                val value = manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
                if (value == Int.MIN_VALUE) null else kotlin.math.abs(value.toLong())
            } catch (_: Exception) {
                null
            }
        }

        private fun parseCapacity(raw: String?): Int? {
            val value = raw?.toIntOrNull() ?: return null
            return if (value in 500..10000) value else null
        }

        // ---------- 格式化 ----------

        private fun formatPercent(value: Double): String {
            return String.format(Locale.US, "%.1f", value)
        }

        private fun formatOneDecimal(value: Double): String {
            return String.format(Locale.US, "%.1f", value)
        }

        private fun formatTwoDecimals(value: Double): String {
            return String.format(Locale.US, "%.2f", value)
        }

        private fun formatPower(value: Double): String {
            return if (value >= 10) {
                String.format(Locale.US, "%.1f", value)
            } else {
                String.format(Locale.US, "%.2f", value)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        // 小组件添加/更新时，刷新并（重）排分钟级定时
        WidgetTickScheduler.refreshSchedule(context)
        updateAll(context)
    }

    override fun onDisabled(context: Context) {
        // 最后一个电池小组件移除时，连同/时钟一起判断是否还要保留定时刷新
        // （保留刷新与否看两个小组件是否都被移除）
        WidgetTickScheduler.refreshSchedule(context)
        super.onDisabled(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_REFRESH,
            Intent.ACTION_BOOT_COMPLETED -> {
                WidgetTickScheduler.refreshSchedule(context)
                updateAll(context)
            }
        }
        super.onReceive(context, intent)
    }
}
