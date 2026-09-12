package cn.ac.feiyang.foc_app.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 用户「我的报修」小组件：展示最新进行中工单与四步进度，
 * 待用户确认时整卡强调 + 直达确认；布局切换逻辑同 TechWidgetProvider。
 */
class UserWidgetProvider : HomeWidgetProvider() {

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
                WidgetViews.user(context, payload, isWide(appWidgetManager, id)),
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
            WidgetViews.user(context, payload, isWide(appWidgetManager, appWidgetId)),
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
        const val WIDE_THRESHOLD_DP = 220
    }
}
