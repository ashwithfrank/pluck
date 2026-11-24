package com.aos

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.content.ContextCompat

/** Keeps the process alive (foreground) while the engine has running downloads. */
class DownloadService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Notifier.ensureChannels(this)
        val n = Notifier.progress(this, 0, 0f)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(Notifier.PROGRESS_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(Notifier.PROGRESS_ID, n)
        }
        return START_NOT_STICKY
    }

    companion object {
        fun ensure(ctx: Context) {
            ContextCompat.startForegroundService(ctx, Intent(ctx, DownloadService::class.java))
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, DownloadService::class.java))
        }
    }
}
