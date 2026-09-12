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
            appWidgetManager.updateAppWidget(
                id,
                WidgetViews.tech(context, payload, isWide(appWidgetManager, id)),
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
        val payload = WidgetPayload.fromJson(
            context
                .getSharedPreferences(WidgetDataSync.WIDGET_PREFS, Context.MODE_PRIVATE)
                .getString(WidgetDataSync.KEY_PAYLOAD, null),
        )
        appWidgetManager.updateAppWidget(
            appWidgetId,
            WidgetViews.tech(context, payload, isWide(appWidgetManager, appWidgetId)),
        )
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetPollWorker.ensureScheduled(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
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
