package cn.ac.feiyang.foc_app.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * 小组件数据同步：读取 App 侧写入的登录态（Flutter SharedPreferences），
 * 直接请求工单接口并重建 payload，写入 home_widget 的存储后刷新两组件。
 *
 * 与 Dart 侧 WidgetSnapshotService 写入同一份 schema（key: foc_widget_payload，
 * 文件: HomeWidgetPreferences）；工单字段映射与 ticket_model.dart / TicketModel.fromJson 对齐。
 */
object WidgetDataSync {
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_TOKEN = "flutter.access_token"
    private const val KEY_USER = "flutter.cached_user_info"

    const val WIDGET_PREFS = "HomeWidgetPreferences"
    const val KEY_PAYLOAD = "foc_widget_payload"

    private const val API_ROOT = "https://focapi.feiyang.ac.cn"
    private const val TICKET_PATH = "/v1/status/getTicket"
    private const val TIMEOUT_MS = 10_000
    private const val MAX_TICKETS = 4

    private val FINISHED_STATUSES = setOf("done", "closed", "canceled", "cancelled")

    /** 拉取工单并刷新组件。返回是否得到有效数据；任何异常都不外抛。 */
    fun sync(context: Context): Boolean = try {
        val flutterPrefs =
            context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val token = flutterPrefs.getString(KEY_TOKEN, null)
        val userRaw = flutterPrefs.getString(KEY_USER, null)
        if (token.isNullOrBlank() || userRaw.isNullOrBlank()) {
            writePayload(context, loggedOutPayload())
            false
        } else {
            val user = JSONObject(userRaw)
            val uid = user.optString("uid").ifEmpty { user.optString("id") }
            val role = user.optString("role", "user")
            if (uid.isEmpty()) {
                writePayload(context, loggedOutPayload())
                false
            } else {
                fetchTicketsAndWrite(context, token, user, role, uid)
            }
        }
    } catch (_: Exception) {
        false
    }

    private fun fetchTicketsAndWrite(
        context: Context,
        token: String,
        user: JSONObject,
        role: String,
        uid: String,
    ): Boolean {
        // 与 Dart 侧 TicketService.getTickets 相同：角色决定查询参数
        val query = if (role == "technician") "tid=$uid" else "uid=$uid"
        val conn =
            (URL("$API_ROOT$TICKET_PATH?$query").openConnection() as HttpURLConnection).apply {
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Accept", "application/json")
                connectTimeout = TIMEOUT_MS
                readTimeout = TIMEOUT_MS
            }
        try {
            when (conn.responseCode) {
                // token 失效：不动 token（登出由 App 侧统一处理），组件展示引导态
                401 -> {
                    writeExpired(context, user, role, uid)
                    return true
                }
                200 -> Unit
                else -> return false
            }
            val body = conn.inputStream.bufferedReader().use { it.readText() }
            val data = JSONObject(body).optJSONArray("data") ?: return false

            val technician = role == "technician"
            val active = (0 until data.length())
                .mapNotNull { data.optJSONObject(it) }
                .filter {
                    it.optString("repair_status").trim().lowercase() !in FINISHED_STATUSES
                }
                .sortedBy { priority(it.optString("repair_status"), technician) }
            val shown = active.take(MAX_TICKETS).map { mapTicket(it) }

            val payload = basePayload(user, role, uid)
                .put(
                    "tickets",
                    JSONArray().apply { shown.forEach { put(it) } },
                )
                .put("countTotal", active.size)
                .put(
                    "countTechConfirm",
                    active.count {
                        it.optString("repair_status").equals("TechConfirming", true)
                    },
                )
                .put(
                    "countUserConfirm",
                    active.count {
                        it.optString("repair_status").equals("UserConfirming", true)
                    },
                )
            writePayload(context, payload)
            return true
        } finally {
            conn.disconnect()
        }
    }

    /** 服务端工单 JSON → payload 投影，键名与 Dart 侧 _ticketToJson 完全一致 */
    private fun mapTicket(t: JSONObject): JSONObject =
        JSONObject()
            .put("id", t.optString("id"))
            .put("status", t.optString("repair_status"))
            .put("device", t.optString("device_type"))
            .put("brand", t.optString("computer_brand"))
            .put("model", t.optString("model"))
            .put("fault", t.optString("fault_type"))
            .put("campus", t.optString("campus"))
            .put("tech", t.optString("assigned_technician_nickname"))
            .put("createdAt", t.optString("create_time"))

    private fun basePayload(user: JSONObject, role: String, uid: String): JSONObject =
        JSONObject()
            .put("v", 1)
            .put("ts", System.currentTimeMillis())
            .put("loggedIn", true)
            .put("tokenState", "ok")
            .put("role", role)
            .put("uid", uid)
            .put("nickname", user.optString("nickname"))
            .put("quota", user.optString("available"))
            .put("maxConcurrent", user.optInt("max_concurrent", 1))

    private fun writeExpired(
        context: Context,
        user: JSONObject,
        role: String,
        uid: String,
    ) {
        val payload = basePayload(user, role, uid)
            .put("tokenState", "expired")
            .put("tickets", JSONArray())
            .put("countTotal", 0)
            .put("countTechConfirm", 0)
            .put("countUserConfirm", 0)
        writePayload(context, payload)
    }

    private fun loggedOutPayload(): JSONObject =
        JSONObject()
            .put("v", 1)
            .put("ts", System.currentTimeMillis())
            .put("loggedIn", false)
            .put("tokenState", "ok")
            .put("role", "")
            .put("uid", "")
            .put("nickname", "")
            .put("quota", "")
            .put("maxConcurrent", 1)
            .put("tickets", JSONArray())
            .put("countTotal", 0)
            .put("countTechConfirm", 0)
            .put("countUserConfirm", 0)

    private fun writePayload(context: Context, payload: JSONObject) {
        context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PAYLOAD, payload.toString())
            .apply()
        requestUpdateAll(context)
    }

    private fun requestUpdateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context) ?: return
        for (cls in listOf(TechWidgetProvider::class.java, UserWidgetProvider::class.java)) {
            val ids = manager.getAppWidgetIds(ComponentName(context, cls))
            if (ids.isEmpty()) continue
            val intent =
                Intent(context, cls)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            context.sendBroadcast(intent)
        }
    }

    /** 与 Dart 侧 priority() 同源：可操作状态最优先 */
    private fun priority(status: String, technician: Boolean): Int =
        when (status.trim().lowercase()) {
            "techconfirming" -> if (technician) 0 else 2
            "repairing" -> 1
            "userconfirming" -> if (technician) 2 else 0
            "pending" -> 3
            else -> 4
        }
}
