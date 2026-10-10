package com.vitalog.vitalog

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

object ReminderScheduler {
    private const val PREFS = "vitalog_reminders"
    private const val REFRESH = 9903
    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    fun channels(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(NotificationChannel("important", "重要事项", NotificationManager.IMPORTANCE_HIGH))
            manager.createNotificationChannel(NotificationChannel("normal", "日常提醒", NotificationManager.IMPORTANCE_HIGH))
            val alarm = NotificationChannel("alarm", "闹钟响铃", NotificationManager.IMPORTANCE_HIGH)
            alarm.setSound(null, null); manager.createNotificationChannel(alarm)
        }
    }
    fun store(context: Context, schedules: JSONArray) { check(prefs(context).edit().putString("schedules", schedules.toString()).commit()) { "Unable to save reminder schedule" } }
    fun reschedule(context: Context) {
        channels(context)
        val all = JSONArray(prefs(context).getString("schedules", "[]"))
        val future = (0 until all.length()).map { all.getJSONObject(it) }.filter { it.optLong("at") > System.currentTimeMillis() }.sortedBy { it.optLong("at") }
        require(future.size<=400 || future[400].getLong("at")>System.currentTimeMillis()+13*60*60*1000L) { "Too many reminders in the next 13 hours; reduce duplicate schedules" }
        val old = JSONArray(prefs(context).getString("requests", "[]"))
        for (i in 0 until old.length()) cancel(context, old.getInt(i))
        cancel(context, REFRESH)
        val codes = mutableSetOf<Int>(); val active = JSONArray()
        // Use a rolling queue to avoid the system's per-app alarm limit.
        for (row in future.take(400)) {
            var code = 10000 + (row.getString("id").hashCode() and 0x1FFFFFFF)
            while (!codes.add(code)) code++
            scheduleOne(context, row, code); active.put(code)
        }
        prefs(context).edit().putString("requests", active.toString()).apply()
        if (future.isNotEmpty()) {
            val pending = PendingIntent.getBroadcast(context, REFRESH, Intent(context, RescheduleReceiver::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val at = System.currentTimeMillis()+12*60*60*1000
            context.getSystemService(AlarmManager::class.java).setWindow(AlarmManager.RTC_WAKEUP, at, 60*60*1000L, pending)
        }
    }
    fun cancel(context: Context, code: Int) {
        val target = if (code == REFRESH) RescheduleReceiver::class.java else ReminderReceiver::class.java
        val pending = PendingIntent.getBroadcast(context, code, Intent(context,target), PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
        if (pending != null) { context.getSystemService(AlarmManager::class.java).cancel(pending); pending.cancel() }
    }
    fun scheduleOne(context: Context, row: JSONObject, code: Int) {
        val intent = Intent(context, ReminderReceiver::class.java).putExtra("payload", row.toString()).putExtra("code", code)
        val pending = PendingIntent.getBroadcast(context, code, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val manager = context.getSystemService(AlarmManager::class.java); val at = row.getLong("at")
        if (Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()) {
            if (row.optBoolean("alarm")) {
                val open = PendingIntent.getActivity(context, code, Intent(context,MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                manager.setAlarmClock(AlarmManager.AlarmClockInfo(at,open),pending)
            } else manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,pending)
        } else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,pending)
    }
    fun notification(context: Context,row: JSONObject,code: Int,alarm: Boolean = false): Notification {
        channels(context)
        val channel = if (alarm) "alarm" else if (row.optString("priority")=="important") "important" else "normal"
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context,channel) else Notification.Builder(context)
        val open = PendingIntent.getActivity(context,code,Intent(context,MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        builder.setSmallIcon(R.drawable.ic_stat_vitalog).setContentTitle(row.optString("title")).setContentText(row.optString("body")).setContentIntent(open).setAutoCancel(!alarm).setCategory(if(alarm)Notification.CATEGORY_ALARM else Notification.CATEGORY_REMINDER).setVisibility(Notification.VISIBILITY_PRIVATE)
        if(alarm) {
            val stop = PendingIntent.getService(context,code,Intent(context,AlarmService::class.java).setAction("dismiss").putExtra("code",code),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            builder.setOngoing(true).addAction(Notification.Action.Builder(R.drawable.ic_stat_vitalog,"关闭闹钟",stop).build())
        }
        if(Build.VERSION.SDK_INT < 26 && !alarm) builder.setDefaults(Notification.DEFAULT_ALL).setPriority(if(channel=="important")Notification.PRIORITY_HIGH else Notification.PRIORITY_DEFAULT)
        return builder.build()
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context,intent: Intent) {
        val row = runCatching { JSONObject(intent.getStringExtra("payload") ?: return) }.getOrNull() ?: return
        val code = intent.getIntExtra("code",9901); val manager = context.getSystemService(NotificationManager::class.java)
        // Do not start persistent sound without accessible notification controls.
        if(!manager.areNotificationsEnabled()) return
        if(row.optBoolean("alarm")) {
            val service = Intent(context,AlarmService::class.java).putExtra("payload",row.toString()).putExtra("code",code)
            try { if(Build.VERSION.SDK_INT>=26) context.startForegroundService(service) else context.startService(service) }
            catch(_:Exception) { manager.notify(code,ReminderScheduler.notification(context,row,code)) }
        } else manager.notify(code,ReminderScheduler.notification(context,row,code))
    }
}
class RescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context,intent: Intent) { runCatching { ReminderScheduler.reschedule(context) } }
}
