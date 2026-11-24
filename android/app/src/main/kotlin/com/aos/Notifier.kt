package com.aos

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

object Notifier {
    const val CH_PROGRESS = "pluck_progress"
    const val CH_DONE = "pluck_done"
    const val PROGRESS_ID = 4001

    fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(CH_PROGRESS, "Active downloads", NotificationManager.IMPORTANCE_LOW)
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_DONE, "Finished downloads", NotificationManager.IMPORTANCE_DEFAULT)
        )
    }

    private fun openApp(ctx: Context): PendingIntent {
        val i = Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(ctx, 0, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    fun progress(ctx: Context, active: Int, avgPercent: Float): Notification {
        val text = if (active <= 0) "Starting…" else if (active == 1) "Downloading 1 item" else "Downloading $active items"
        val b = NotificationCompat.Builder(ctx, CH_PROGRESS)
            .setSmallIcon(R.drawable.ic_stat_pluck)
            .setContentTitle("Pluck")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openApp(ctx))
        if (avgPercent > 0f) b.setProgress(100, avgPercent.toInt().coerceIn(0, 100), false)
        else b.setProgress(0, 0, true)
        return b.build()
    }

    fun updateProgress(ctx: Context, active: Int, avgPercent: Float) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        try {
            nm.notify(PROGRESS_ID, progress(ctx, active, avgPercent))
        } catch (_: SecurityException) {
            // notification permission denied; downloads still run
        }
    }

    fun finished(ctx: Context, id: String, title: String, ok: Boolean) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val n = NotificationCompat.Builder(ctx, CH_DONE)
            .setSmallIcon(R.drawable.ic_stat_pluck)
            .setContentTitle(if (ok) "Download complete" else "Download failed")
            .setContentText(title)
            .setAutoCancel(true)
            .setContentIntent(openApp(ctx))
            .build()
        try {
            nm.notify(id.hashCode(), n)
        } catch (_: SecurityException) {
        }
    }
}
