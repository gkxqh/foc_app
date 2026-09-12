package cn.ac.feiyang.foc_app.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * 周期轮询 Worker（30 分钟 + 网络可用）：App 未打开时也让小组件保持较新。
 * 纯原生 HTTP 实现，不拉起 Flutter 引擎；国内 ROM 上系统可能推迟执行，属预期内。
 */
class WidgetPollWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    override fun doWork(): Result {
        WidgetDataSync.sync(applicationContext)
        return Result.success()
    }

    companion object {
        private const val UNIQUE_WORK = "foc_widget_poll"

        /** 幂等注册：组件被添加时调用，重复调用保留已有周期任务 */
        fun ensureScheduled(context: Context) {
            val request =
                PeriodicWorkRequest.Builder(WidgetPollWorker::class.java, 30, TimeUnit.MINUTES)
                    .setConstraints(
                        Constraints.Builder()
                            .setRequiredNetworkType(androidx.work.NetworkType.CONNECTED)
                            .build(),
                    )
                    .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                UNIQUE_WORK,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }

        /** 全部组件被移除后停止轮询，避免无谓耗电 */
        fun cancelIfNoWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val anyPinned =
                listOf(TechWidgetProvider::class.java, UserWidgetProvider::class.java)
                    .any { manager.getAppWidgetIds(ComponentName(context, it)).isNotEmpty() }
            if (!anyPinned) {
                runCatching { WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_WORK) }
            }
        }
    }
}
