package com.vitalog.vitalog

import android.app.Service
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import org.json.JSONObject

class AlarmService : Service() {
    private var player: MediaPlayer? = null
    private var currentCode = 0
    private val handler = Handler(Looper.getMainLooper())
    private val stop = Runnable { stopSelf() }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?,flags: Int,startId: Int): Int {
        if(intent?.action=="dismiss") { stopSelf(); return START_NOT_STICKY }
        val row = runCatching { JSONObject(intent?.getStringExtra("payload") ?: return START_NOT_STICKY) }.getOrNull() ?: return START_NOT_STICKY
        val code = intent?.getIntExtra("code",9901) ?: 9901
        if(currentCode!=0 && currentCode!=code) getSystemService(NotificationManager::class.java).cancel(currentCode)
        currentCode=code
        val notification=ReminderScheduler.notification(this,row,code,alarm=true)
        if(Build.VERSION.SDK_INT>=29) startForeground(code,notification,ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK) else startForeground(code,notification)
        player?.release()
        player=runCatching {
            MediaPlayer().apply {
                setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                setDataSource(this@AlarmService,RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM) ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
                isLooping=true; prepare(); start()
            }
        }.getOrNull()
        handler.removeCallbacks(stop); handler.postDelayed(stop,10*60*1000L)
        return START_NOT_STICKY
    }
    override fun onDestroy() {
        handler.removeCallbacks(stop); player?.release(); player=null
        stopForeground(STOP_FOREGROUND_REMOVE); super.onDestroy()
    }
}
