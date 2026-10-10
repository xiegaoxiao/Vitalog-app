package com.vitalog.vitalog

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private fun status(): Map<String, Boolean> = mapOf(
        "notifications" to getSystemService(NotificationManager::class.java).areNotificationsEnabled(),
        "exact" to (Build.VERSION.SDK_INT < 31 || getSystemService(AlarmManager::class.java).canScheduleExactAlarms())
    )
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ReminderScheduler.channels(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vitalog/reminders").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "status" -> result.success(status())
                    "requestNotifications" -> {
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            if (permissionResult != null) result.error("busy", "A permission request is already open", null)
                            else { permissionResult = result; requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 2001) }
                        } else result.success(null)
                    }
                    "exactSettings" -> { if (Build.VERSION.SDK_INT >= 31) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName"))); result.success(null) }
                    "appSettings" -> { startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))); result.success(null) }
                    "sync" -> {
                        val rows = call.arguments as? List<*> ?: error("Invalid schedules")
                        val schedules = JSONArray()
                        for (row in rows) {
                            val map = row as? Map<*, *> ?: error("Invalid reminder")
                            val item = JSONObject()
                            for ((key,value) in map) item.put(key.toString(), value)
                            schedules.put(item)
                        }
                        ReminderScheduler.store(this, schedules); ReminderScheduler.reschedule(this); result.success(null)
                    }
                    "test" -> { ReminderScheduler.scheduleOne(this, JSONObject().put("id", "test").put("title", "元气簿提醒测试").put("body", "你的提醒已经准备好了").put("at", System.currentTimeMillis()+5000).put("alarm", false).put("priority", "important"), 9901); result.success(null) }
                    "timer" -> { val at = call.argument<Number>("at")?.toLong() ?: error("Invalid timer"); ReminderScheduler.scheduleOne(this, JSONObject().put("id", "rest-timer").put("title", "组间休息结束").put("body", "准备好后，开始下一组").put("at", at).put("alarm", false).put("priority", "normal"), 9902); result.success(null) }
                    "cancelTimer" -> { ReminderScheduler.cancel(this, 9902); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("reminders", e.message, null) }
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 2001) { permissionResult?.success(null); permissionResult = null }
    }
    override fun onResume() { super.onResume(); runCatching { ReminderScheduler.reschedule(this) } }
}
