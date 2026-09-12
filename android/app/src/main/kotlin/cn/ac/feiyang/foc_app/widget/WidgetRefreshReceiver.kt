package cn.ac.feiyang.foc_app.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 组件上的「刷新」按钮：立即拉一次工单并刷新组件，
 * 顺带保底注册周期轮询（防止 WorkManager 任务被系统清理后不再恢复）。
 */
class WidgetRefreshReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        WidgetPollWorker.ensureScheduled(context)
        val pendingResult = goAsync()
        Thread {
            try {
                WidgetDataSync.sync(context)
            } catch (_: Exception) {
            } finally {
                pendingResult.finish()
            }
        }.start()
    }
}
