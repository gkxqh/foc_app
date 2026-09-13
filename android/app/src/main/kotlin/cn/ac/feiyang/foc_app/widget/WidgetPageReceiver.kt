package cn.ac.feiyang.foc_app.widget

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * 工作台 4x2 的工单翻页：按 widgetId 记忆页码（HomeWidgetPreferences 内），
 * clamp 到当前数据范围后重渲染。每页两行，与布局的行数一致。
 */
class WidgetPageReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
        val forward = intent.getBooleanExtra(EXTRA_FORWARD, true)

        val manager = AppWidgetManager.getInstance(context) ?: return
        // 翻页时现读 payload（可能比上次 onUpdate 新），并按数据量 clamp 页码
        val payload = WidgetDataSync.readPayload(context)
        val totalPages =
            if (payload.tickets.isEmpty()) 1
            else (payload.tickets.size + ROWS_PER_PAGE - 1) / ROWS_PER_PAGE
        val current =
            context
                .getSharedPreferences(WidgetDataSync.WIDGET_PREFS, Context.MODE_PRIVATE)
                .getInt(pageKey(id), 0)
        val next = (if (forward) current + 1 else current - 1).coerceIn(0, totalPages - 1)

        context
            .getSharedPreferences(WidgetDataSync.WIDGET_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putInt(pageKey(id), next)
            .apply()

        val wide = manager
            .getAppWidgetOptions(id)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250) >= WIDE_THRESHOLD_DP
        manager.updateAppWidget(
            id,
            WidgetViews.tech(context, payload, wide, page = next, totalPages = totalPages),
        )
    }

    companion object {
        const val EXTRA_WIDGET_ID = "widget_id"
        const val EXTRA_FORWARD = "forward"
        const val ROWS_PER_PAGE = 2
        const val WIDE_THRESHOLD_DP = 220

        fun pageKey(appWidgetId: Int) = "tech_page_$appWidgetId"

        /** 工单数变化后清理越界的页码记忆（onUpdate 渲染前调用） */
        fun clampedPage(context: Context, appWidgetId: Int, totalPages: Int): Int {
            val prefs =
                context.getSharedPreferences(WidgetDataSync.WIDGET_PREFS, Context.MODE_PRIVATE)
            val saved = prefs.getInt(pageKey(appWidgetId), 0)
            val page = saved.coerceIn(0, totalPages - 1)
            if (page != saved) {
                prefs.edit().putInt(pageKey(appWidgetId), page).apply()
            }
            return page
        }
    }
}
