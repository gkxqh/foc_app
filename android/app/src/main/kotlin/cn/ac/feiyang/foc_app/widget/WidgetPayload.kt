package cn.ac.feiyang.foc_app.widget

import org.json.JSONArray
import org.json.JSONObject

/** 单条工单在小组件 payload 中的投影（字段与 Dart 侧 WidgetSnapshotService 保持一致） */
data class WidgetTicket(
    val id: String,
    val status: String,
    val device: String,
    val brand: String,
    val model: String,
    val fault: String,
    val campus: String,
    val tech: String,
    val createdAt: String,
)

data class WidgetPayload(
    val loggedIn: Boolean,
    val tokenExpired: Boolean,
    val role: String,
    val uid: String,
    val nickname: String,
    val quota: String,
    val maxConcurrent: Int,
    val tickets: List<WidgetTicket>,
    val countTotal: Int,
    val updatedAt: Long,
) {
    val isTechnician: Boolean get() = role == "technician"

    /** 内容态：登录有效且角色匹配且有工单（此时渲染列表） */
    val showList: Boolean
        get() = loggedIn && !tokenExpired && isTechnician && tickets.isNotEmpty()

    /** 在手工单数：优先用写入端统计的真实总数，兜底列表长度（列表可能被截断） */
    val inHandCount: Int get() = if (countTotal > 0) countTotal else tickets.size

    val firstTicket: WidgetTicket? get() = tickets.firstOrNull()

    companion object {
        fun fromJson(raw: String?): WidgetPayload {
            if (raw.isNullOrBlank()) return empty()
            return try {
                val obj = JSONObject(raw)
                val ticketsJson = obj.optJSONArray("tickets") ?: JSONArray()
                val tickets = (0 until ticketsJson.length()).mapNotNull { i ->
                    val t = ticketsJson.optJSONObject(i) ?: return@mapNotNull null
                    WidgetTicket(
                        id = t.optString("id"),
                        status = t.optString("status"),
                        device = t.optString("device"),
                        brand = t.optString("brand"),
                        model = t.optString("model"),
                        fault = t.optString("fault"),
                        campus = t.optString("campus"),
                        tech = t.optString("tech"),
                        createdAt = t.optString("createdAt"),
                    )
                }
                WidgetPayload(
                    loggedIn = obj.optBoolean("loggedIn", false),
                    tokenExpired = obj.optString("tokenState") == "expired",
                    role = obj.optString("role"),
                    uid = obj.optString("uid"),
                    nickname = obj.optString("nickname"),
                    quota = obj.optString("quota"),
                    maxConcurrent = obj.optInt("maxConcurrent", 1),
                    tickets = tickets,
                    countTotal = obj.optInt("countTotal", tickets.size),
                    updatedAt = obj.optLong("ts"),
                )
            } catch (_: Exception) {
                empty()
            }
        }

        private fun empty() = WidgetPayload(
            loggedIn = false,
            tokenExpired = false,
            role = "",
            uid = "",
            nickname = "",
            quota = "",
            maxConcurrent = 1,
            tickets = emptyList(),
            countTotal = 0,
            updatedAt = 0L,
        )
    }
}
