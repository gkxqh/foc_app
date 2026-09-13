package cn.ac.feiyang.foc_app.widget

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import cn.ac.feiyang.foc_app.MainActivity
import cn.ac.feiyang.foc_app.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 小组件 RemoteViews 组装。状态口径：
 * - 未登录 / token 过期 → 引导态
 * - 角色不匹配 → 引导更换组件
 * - 正常但无工单 → 空态
 * - 正常 → 内容态（4x2 为可滑动工单列表，2x2 紧凑数字）
 */
internal object WidgetViews {
    private const val LINK_SCAN = "focapp://widget/scan"
    private const val LINK_HOME = "focapp://widget/home"
    private const val LINK_REPORT = "focapp://widget/report"

    private fun linkTicket(id: String) = "focapp://widget/ticket?id=${Uri.encode(id)}"

    // ---------- 技术员版 ----------

    fun tech(
        context: Context,
        payload: WidgetPayload,
        wide: Boolean,
        appWidgetId: Int = -1,
        page: Int = 0,
        totalPages: Int = 1,
    ): RemoteViews {
        val views = RemoteViews(
            context.packageName,
            if (wide) R.layout.widget_tech_4x2 else R.layout.widget_tech_2x2,
        )
        return if (wide) {
            techWide(context, payload, views, appWidgetId, page, totalPages)
        } else {
            techSmall(context, payload, views)
        }
    }

    private fun techWide(
        context: Context,
        payload: WidgetPayload,
        views: RemoteViews,
        appWidgetId: Int,
        page: Int,
        totalPages: Int,
    ): RemoteViews {
        val openApp = launchHome(context)
        views.setOnClickPendingIntent(R.id.tech_root, openApp)

        val off = !payload.loggedIn || payload.tokenExpired
        // 角色校验：非技术员账号（用户/管理员）不展示工单内容，引导更换组件
        val wrongRole = !off && !payload.isTechnician
        views.setViewVisibility(
            R.id.tech_block_off,
            if (off || wrongRole) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(R.id.tech_footer, if (off || wrongRole) View.GONE else View.VISIBLE)
        if (off || wrongRole) {
            views.setTextViewText(
                R.id.tech_off_text,
                when {
                    payload.tokenExpired -> context.getString(R.string.widget_expired)
                    !payload.loggedIn -> context.getString(R.string.widget_logged_out)
                    else -> context.getString(R.string.widget_tech_wrong_role)
                },
            )
            views.setOnClickPendingIntent(R.id.tech_off_action, openApp)
            views.setViewVisibility(R.id.tech_rows, View.GONE)
            views.setViewVisibility(R.id.tech_block_empty, View.GONE)
            views.setViewVisibility(R.id.tech_page_prev, View.GONE)
            views.setViewVisibility(R.id.tech_page_label, View.GONE)
            views.setViewVisibility(R.id.tech_page_next, View.GONE)
            return views
        }

        if (payload.tickets.isEmpty()) {
            views.setViewVisibility(R.id.tech_block_empty, View.VISIBLE)
            views.setViewVisibility(R.id.tech_rows, View.GONE)
            views.setViewVisibility(R.id.tech_page_prev, View.GONE)
            views.setViewVisibility(R.id.tech_page_label, View.GONE)
            views.setViewVisibility(R.id.tech_page_next, View.GONE)
        } else {
            views.setViewVisibility(R.id.tech_block_empty, View.GONE)
            views.setViewVisibility(R.id.tech_rows, View.VISIBLE)
            bindTechRow(
                context,
                views,
                1,
                payload.tickets.getOrNull(page * WidgetPageReceiver.ROWS_PER_PAGE),
            )
            bindTechRow(
                context,
                views,
                2,
                payload.tickets.getOrNull(page * WidgetPageReceiver.ROWS_PER_PAGE + 1),
            )
            // 翻页器：单页时整体隐藏，多页时显示 页码 与可用的方向
            views.setViewVisibility(
                R.id.tech_page_prev,
                if (totalPages > 1 && page > 0) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.tech_page_next,
                if (totalPages > 1 && page < totalPages - 1) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.tech_page_label,
                if (totalPages > 1) View.VISIBLE else View.GONE,
            )
            views.setTextViewText(
                R.id.tech_page_label,
                context.getString(
                    R.string.widget_page_fmt,
                    page + 1,
                    totalPages,
                ),
            )
            views.setOnClickPendingIntent(
                R.id.tech_page_prev,
                pagePendingIntent(context, appWidgetId, forward = false),
            )
            views.setOnClickPendingIntent(
                R.id.tech_page_next,
                pagePendingIntent(context, appWidgetId, forward = true),
            )
        }
        views.setOnClickPendingIntent(R.id.tech_btn_scan, launchScan(context))
        views.setOnClickPendingIntent(R.id.tech_btn_refresh, refreshPendingIntent(context))
        views.setTextViewText(R.id.tech_updated, updatedLabel(context, payload.updatedAt))
        return views
    }

    private fun techSmall(context: Context, payload: WidgetPayload, views: RemoteViews): RemoteViews {
        val off = !payload.loggedIn || payload.tokenExpired
        when {
            off -> {
                // 引导态保留「点按打开应用」提示
                views.setTextViewText(R.id.tech2_hand, if (payload.tokenExpired) "登录过期" else "未登录")
                views.setTextViewText(R.id.tech2_free, context.getString(R.string.widget_tap_open))
            }
            !payload.isTechnician -> {
                views.setTextViewText(R.id.tech2_hand, context.getString(R.string.widget_tech_unavailable_short))
                views.setTextViewText(R.id.tech2_free, context.getString(R.string.widget_tech_wrong_role_short))
            }
            else -> {
                views.setTextViewText(
                    R.id.tech2_hand,
                    context.getString(R.string.widget_hand_fmt, payload.inHandCount),
                )
                views.setViewVisibility(R.id.tech2_free, View.GONE)
            }
        }
        views.setOnClickPendingIntent(R.id.tech2_scan, launchScan(context))
        views.setOnClickPendingIntent(R.id.tech2_root, launchHome(context))
        return views
    }


    private fun bindTechRow(
        context: Context,
        views: RemoteViews,
        row: Int,
        ticket: WidgetTicket?,
    ) {
        val (root, title, status) = if (row == 1) {
            Triple(R.id.tech_row1, R.id.tech_row1_title, R.id.tech_row1_status)
        } else {
            Triple(R.id.tech_row2, R.id.tech_row2_title, R.id.tech_row2_status)
        }
        if (ticket == null) {
            views.setViewVisibility(root, View.GONE)
            return
        }
        views.setViewVisibility(root, View.VISIBLE)
        views.setTextViewText(title, rowTitle(ticket, withCampus = true))
        views.setTextViewText(status, statusLabel(ticket.status))
        views.setTextColor(status, statusColor(context, ticket.status))
        views.setOnClickPendingIntent(
            root,
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse(linkTicket(ticket.id)),
            ),
        )
    }

    // ---------- 用户版 ----------

    fun user(context: Context, payload: WidgetPayload, wide: Boolean): RemoteViews {
        val views = RemoteViews(
            context.packageName,
            if (wide) R.layout.widget_user_4x2 else R.layout.widget_user_2x2,
        )
        return if (wide) userWide(context, payload, views) else userSmall(context, payload, views)
    }

    private fun userWide(context: Context, payload: WidgetPayload, views: RemoteViews): RemoteViews {
        val openApp = launchHome(context)
        views.setOnClickPendingIntent(R.id.user_root, openApp)

        val off = !payload.loggedIn || payload.tokenExpired
        // 角色校验：技术员账号引导使用接单工作台组件
        val wrongRole = !off && payload.isTechnician
        views.setViewVisibility(
            R.id.user_block_off,
            if (off || wrongRole) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(R.id.user_block_empty, View.GONE)
        views.setViewVisibility(R.id.user_block_main, View.GONE)
        views.setViewVisibility(R.id.user_footer, if (off || wrongRole) View.GONE else View.VISIBLE)
        if (off || wrongRole) {
            views.setTextViewText(
                R.id.user_off_text,
                when {
                    payload.tokenExpired -> context.getString(R.string.widget_expired)
                    !payload.loggedIn -> context.getString(R.string.widget_logged_out)
                    else -> context.getString(R.string.widget_user_wrong_role)
                },
            )
            views.setOnClickPendingIntent(R.id.user_off_action, openApp)
            return views
        }

        val ticket = payload.firstTicket
        if (ticket == null) {
            views.setViewVisibility(R.id.user_block_empty, View.VISIBLE)
            views.setOnClickPendingIntent(R.id.user_btn_report_empty, launchReport(context))
            return views
        }

        views.setViewVisibility(R.id.user_block_main, View.VISIBLE)
        views.setTextViewText(R.id.user_device, rowTitle(ticket, withCampus = false))
        views.setTextViewText(R.id.user_status, statusLabel(ticket.status))
        views.setTextColor(R.id.user_status, statusColor(context, ticket.status))
        views.setOnClickPendingIntent(
            R.id.user_block_main,
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse(linkTicket(ticket.id)),
            ),
        )

        // 双向确认闭环：需要用户亲自确认时给出直达按钮
        val needSelfConfirm = ticket.status.trim().equals("userconfirming", ignoreCase = true)
        views.setViewVisibility(
            R.id.user_confirm_btn,
            if (needSelfConfirm) View.VISIBLE else View.GONE,
        )
        if (needSelfConfirm) {
            views.setOnClickPendingIntent(
                R.id.user_confirm_btn,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(linkTicket(ticket.id)),
                ),
            )
        }
        bindSteps(context, views, ticket.status)

        views.setOnClickPendingIntent(R.id.user_btn_report, launchReport(context))
        views.setOnClickPendingIntent(R.id.user_btn_refresh, refreshPendingIntent(context))
        views.setTextViewText(R.id.user_updated, updatedLabel(context, payload.updatedAt))
        return views
    }

    private fun userSmall(context: Context, payload: WidgetPayload, views: RemoteViews): RemoteViews {
        val openApp = launchHome(context)
        when {
            !payload.loggedIn -> {
                views.setTextViewText(R.id.user2_status, "未登录")
                views.setTextColor(R.id.user2_status, color(context, R.color.widget_text_secondary))
                views.setTextViewText(R.id.user2_device, context.getString(R.string.widget_tap_open))
                views.setTextViewText(R.id.user2_hint, "")
                views.setOnClickPendingIntent(R.id.user2_root, openApp)
            }
            payload.tokenExpired -> {
                views.setTextViewText(R.id.user2_status, "登录过期")
                views.setTextColor(R.id.user2_status, color(context, R.color.widget_status_closed))
                views.setTextViewText(R.id.user2_device, context.getString(R.string.widget_tap_open))
                views.setTextViewText(R.id.user2_hint, "")
                views.setOnClickPendingIntent(R.id.user2_root, openApp)
            }
            // 角色校验优先于空态：技术员账号一律引导更换组件
            payload.isTechnician -> {
                views.setTextViewText(R.id.user2_status, context.getString(R.string.widget_user_unavailable_short))
                views.setTextColor(R.id.user2_status, color(context, R.color.widget_text_secondary))
                views.setTextViewText(R.id.user2_device, context.getString(R.string.widget_user_wrong_role_short))
                views.setTextViewText(R.id.user2_hint, "")
                views.setOnClickPendingIntent(R.id.user2_root, openApp)
            }
            payload.firstTicket == null -> {
                views.setTextViewText(R.id.user2_status, "暂无工单")
                views.setTextColor(R.id.user2_status, color(context, R.color.widget_text_secondary))
                views.setTextViewText(R.id.user2_device, context.getString(R.string.widget_tap_report))
                views.setTextViewText(R.id.user2_hint, "")
                views.setOnClickPendingIntent(R.id.user2_root, launchReport(context))
            }
            else -> {
                val ticket = payload.firstTicket!!
                views.setTextViewText(R.id.user2_status, statusLabel(ticket.status))
                views.setTextColor(R.id.user2_status, statusColor(context, ticket.status))
                views.setTextViewText(R.id.user2_device, rowTitle(ticket, withCampus = false))
                views.setTextViewText(R.id.user2_hint, context.getString(R.string.widget_tap_detail))
                views.setOnClickPendingIntent(
                    R.id.user2_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse(linkTicket(ticket.id)),
                    ),
                )
            }
        }
        return views
    }

    // ---------- 公共片段 ----------

    /**
     * 四步进度条：报修 · 接单 · 确认 · 完成（与 App 工单详情页步骤条一致）。
     * 已过步骤强调色，当前步骤用状态色。
     */
    private fun bindSteps(context: Context, views: RemoteViews, status: String) {
        val stepIds = intArrayOf(
            R.id.user_step1, R.id.user_step2, R.id.user_step3, R.id.user_step4,
        )
        val sepIds = intArrayOf(
            R.id.user_sep1, R.id.user_sep2, R.id.user_sep3,
        )
        val current = currentStep(status)
        val accent = color(context, R.color.widget_accent)
        val tertiary = color(context, R.color.widget_text_tertiary)
        val currentColor = statusColor(context, status)
        stepIds.forEachIndexed { index, id ->
            val step = index + 1
            views.setTextColor(
                id,
                when {
                    step < current -> accent
                    step == current -> currentColor
                    else -> tertiary
                },
            )
        }
        sepIds.forEach { views.setTextColor(it, tertiary) }
    }

    /** 取消/关闭为异常终态，与 App 一致落在最后一步；未知状态回落第一步 */
    private fun currentStep(status: String): Int = when (status.trim().lowercase()) {
        "pending" -> 1
        "repairing" -> 2
        "userconfirming", "techconfirming" -> 3
        "done", "closed", "canceled", "cancelled" -> 4
        else -> 1
    }

    internal fun rowTitle(ticket: WidgetTicket, withCampus: Boolean): String {
        val head = listOf(ticket.brand.trim(), ticket.model.trim())
            .filter { it.isNotEmpty() }
            .joinToString(" ")
            .ifEmpty { ticket.device.trim() }
        val campusPrefix =
            if (withCampus && ticket.campus.isNotBlank()) "[${ticket.campus}] " else ""
        return if (ticket.fault.isBlank()) {
            "$campusPrefix$head"
        } else {
            "$campusPrefix$head • ${ticket.fault}"
        }
    }

    /**
     * 状态文案与 App 内 AppTheme.getStatusText 语义一致；
     * 小组件空间受限用「待…」短形，不再按角色反转（App 侧为「等待…」全称）。
     */
    internal fun statusLabel(status: String): String =
        when (status.trim().lowercase()) {
            "pending" -> "待分配"
            "repairing" -> "维修中"
            "userconfirming" -> "待用户确认"
            "techconfirming" -> "待技术员确认"
            "done" -> "已完成"
            "closed" -> "已关闭"
            "canceled", "cancelled" -> "已取消"
            else -> status
        }

    /** 状态色与 App 内 AppTheme.getStatusColor 同源 */
    internal fun statusColor(context: Context, status: String): Int =
        color(
            context,
            when (status.trim().lowercase()) {
                "pending" -> R.color.widget_status_pending
                "repairing" -> R.color.widget_status_repairing
                "userconfirming", "techconfirming" -> R.color.widget_status_confirming
                "done" -> R.color.widget_status_done
                "closed" -> R.color.widget_status_closed
                else -> R.color.widget_status_canceled
            },
        )
    private fun updatedLabel(context: Context, ts: Long): String =
        if (ts <= 0L) {
            ""
        } else {
            val time = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(ts))
            context.getString(R.string.widget_updated_fmt, time)
        }

    private fun launchHome(context: Context): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(LINK_HOME))

    /** 立即报修：直达报修须知页（与首页「我要报修」一致），未登录由路由层引导登录 */
    private fun launchReport(context: Context): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(LINK_REPORT))

    private fun launchScan(context: Context): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(LINK_SCAN))

    private fun pagePendingIntent(context: Context, appWidgetId: Int, forward: Boolean): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            if (forward) appWidgetId * 2 + 1 else appWidgetId * 2,
            Intent(context, WidgetPageReceiver::class.java)
                .putExtra(WidgetPageReceiver.EXTRA_WIDGET_ID, appWidgetId)
                .putExtra(WidgetPageReceiver.EXTRA_FORWARD, forward),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun refreshPendingIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, WidgetRefreshReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun color(context: Context, resId: Int): Int = context.getColor(resId)
}
