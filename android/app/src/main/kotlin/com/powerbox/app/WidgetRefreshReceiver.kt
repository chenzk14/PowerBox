package com.powerbox.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 每分钟触发一次，刷新时钟/电池小组件，随后自我续期。
 */
class WidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        ClockWidgetProvider.updateAll(context)
        BatteryWidgetProvider.updateAll(context)
        // 自我续期：再排下一分钟
        WidgetTickScheduler.schedule(context)
    }
}
