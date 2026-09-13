package cn.ac.feiyang.foc_app.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 技术员工作台小组件。同一 Provider 承载 4x2 / 2x2 两种布局：
 * 通过当前宽度选择，添加时默认 4x2（targetCellWidth），可手动缩放至 2x2。
 */
class TechWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload =
            WidgetPayload.fromJson(widgetData.getString(WidgetDataSync.KEY_PAYLOAD, null))
        for (id in appWidgetIds) {
            val (page, totalPages) = pagedPosition(context, id, payload)
            appWidgetManager.updateAppWidget(
                id,
                WidgetViews.tech(
                    context,
                    payload,
                    isWide(appWidgetManager, id),
                    appWidgetId = id,
                    page = page,
                    totalPages = totalPages,
                ),
            )
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val payload = WidgetDataSync.readPayload(context)
        val (page, totalPages) = pagedPosition(context, appWidgetId, payload)
        appWidgetManager.updateAppWidget(
            appWidgetId,
            WidgetViews.tech(
                context,
                payload,
                isWide(appWidgetManager, appWidgetId),
                appWidgetId = appWidgetId,
                page = page,
                totalPages = totalPages,
            ),
        )
    }

    /** 工单数变化后 clamp 已记忆的页码，返回（页码, 总页数） */
    private fun pagedPosition(
        context: Context,
        appWidgetId: Int,
        payload: WidgetPayload,
    ): Pair<Int, Int> {
        val totalPages =
            if (payload.tickets.isEmpty()) 1
            else (payload.tickets.size + WidgetPageReceiver.ROWS_PER_PAGE - 1) /
                WidgetPageReceiver.ROWS_PER_PAGE
        return WidgetPageReceiver.clampedPage(context, appWidgetId, totalPages) to totalPages
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetPollWorker.ensureScheduled(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val prefs =
            context.getSharedPreferences(WidgetDataSync.WIDGET_PREFS, Context.MODE_PRIVATE)
        appWidgetIds.forEach { prefs.edit().remove(WidgetPageReceiver.pageKey(it)).apply() }
        WidgetPollWorker.cancelIfNoWidgets(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetPollWorker.cancelIfNoWidgets(context)
    }

    private fun isWide(manager: AppWidgetManager, appWidgetId: Int): Boolean {
        val widthDp = manager
            .getAppWidgetOptions(appWidgetId)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
        return widthDp >= WIDE_THRESHOLD_DP
    }

    private companion object {
        /** 低于该宽度（约 3 格）切 2x2 紧凑布局 */
        const val WIDE_THRESHOLD_DP = 220
    }
}
