package com.aos

import android.content.Context
import com.yausername.aria2c.Aria2c
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

class Job(val id: String, val title: String) {
    @Volatile var status = "running" // running | done | failed | cancelled | paused
    @Volatile var progress = 0f
    @Volatile var eta = -1L
    @Volatile var line = ""
    @Volatile var uri: String? = null
    @Volatile var name: String? = null
    @Volatile var size = 0L
    @Volatile var mime: String? = null
    @Volatile var error: String? = null
    @Volatile var stopRequest: String? = null // "cancel" | "pause"
    @Volatile var lastPush = 0L

    fun toMap(): Map<String, Any?> = mapOf(
        "type" to "progress",
        "id" to id,
        "status" to status,
        "progress" to progress.toDouble(),
        "eta" to eta,
        "line" to line,
        "uri" to uri,
        "name" to name,
        "size" to size,
        "mime" to mime,
        "error" to error,
    )
}

/** One option for yt-dlp: key with optional value. */
data class Opt(val key: String, val value: String?)

object Engine {
    private val pool = Executors.newCachedThreadPool()
    private val jobs = ConcurrentHashMap<String, Job>()
    private val initLock = Any()

    @Volatile private var ready = false
    @Volatile private var aria2Ready = false
    @Volatile private var serviceOn = false

    /** Set by MainActivity; delivers events to Flutter on the UI thread. */
    @Volatile var emit: (Map<String, Any?>) -> Unit = {}

    // ---------------------------------------------------------------- init

    fun init(ctx: Context): Map<String, Any?> {
        synchronized(initLock) {
            if (!ready) {
                YoutubeDL.getInstance().init(ctx)
                FFmpeg.getInstance().init(ctx)
                aria2Ready = try {
                    Aria2c.getInstance().init(ctx)
                    true
                } catch (_: Throwable) {
                    false
                }
                ready = true
            }
        }
        val version = try {
            YoutubeDL.getInstance().version(ctx)
        } catch (_: Throwable) {
            null
        }
        return mapOf("version" to (version ?: "unknown"), "aria2" to aria2Ready)
    }

    // ------------------------------------------------------------- analyze

    /** Runs `yt-dlp -J --flat-playlist` and returns the raw JSON. */
    fun analyze(url: String, noPlaylist: Boolean): String {
        val req = YoutubeDLRequest(url)
        req.addOption("-J")
        req.addOption("--flat-playlist")
        req.addOption("--no-warnings")
        if (noPlaylist) req.addOption("--no-playlist")
        val res = YoutubeDL.getInstance().execute(req)
        return res.out
    }

    // ------------------------------------------------------------ download

    fun start(
        ctx: Context,
        id: String,
        url: String,
        title: String,
        opts: List<Opt>,
        subdir: String,
        useAria: Boolean,
        connections: Int,
    ) {
        val app = ctx.applicationContext
        val job = Job(id, title)
        jobs[id] = job
        push(app, job, force = true)
        pool.execute { run(app, job, url, opts, subdir, useAria, connections) }
    }

    private fun run(
        ctx: Context,
        job: Job,
        url: String,
        opts: List<Opt>,
        subdir: String,
        useAria: Boolean,
        connections: Int,
    ) {
        // Stable per-id folder so a paused/failed download resumes from its .part files.
        val workDir = File(ctx.getExternalFilesDir(null) ?: ctx.filesDir, "work/${job.id}").apply { mkdirs() }
        try {
            val req = YoutubeDLRequest(url)
            req.addOption("-o", workDir.absolutePath + "/%(title).120B [%(id)s].%(ext)s")
            req.addOption("--no-playlist")
            req.addOption("--no-mtime")
            req.addOption("--continue")
            for (o in opts) {
                if (o.value == null) req.addOption(o.key) else req.addOption(o.key, o.value)
            }
            if (useAria && aria2Ready) {
                req.addOption("--downloader", "libaria2c.so")
                req.addOption(
                    "--external-downloader-args",
                    "aria2c:\"-x $connections -s $connections -k 1M --summary-interval=1\""
                )
            }

            YoutubeDL.getInstance().execute(req, job.id) { progress, eta, line ->
                if (progress >= 0f) job.progress = progress
                job.eta = eta
                job.line = line
                push(ctx, job, force = false)
            }

            val src = pickOutput(workDir) ?: throw IllegalStateException("yt-dlp finished but produced no file")
            job.line = "Saving to Downloads…"
            push(ctx, job, force = true)
            val saved = MediaSaver.save(ctx, src, subdir)
            workDir.deleteRecursively()
            job.uri = saved.uri
            job.name = saved.name
            job.size = saved.size
            job.mime = saved.mime
            job.progress = 100f
            job.eta = 0
            job.status = "done"
        } catch (t: Throwable) {
            job.status = when (job.stopRequest) {
                "pause" -> "paused"
                "cancel" -> "cancelled"
                else -> "failed"
            }
            if (job.status == "failed") job.error = cleanError(t)
            if (job.status == "cancelled") workDir.deleteRecursively()
        }
        push(ctx, job, force = true)
        if (job.status == "done") Notifier.finished(ctx, job.id, job.name ?: job.title, true)
        if (job.status == "failed") Notifier.finished(ctx, job.id, job.title, false)
    }

    fun cancel(id: String, pause: Boolean) {
        val job = jobs[id] ?: return
        if (job.status != "running") return
        job.stopRequest = if (pause) "pause" else "cancel"
        try {
            YoutubeDL.getInstance().destroyProcessById(id)
        } catch (_: Throwable) {
        }
    }

    fun forget(id: String) {
        jobs.remove(id)
    }

    fun snapshot(): List<Map<String, Any?>> = jobs.values.map { it.toMap() }

    // ------------------------------------------------------------- updates

    fun updateBinary(ctx: Context, nightly: Boolean): String {
        val channel = if (nightly) YoutubeDL.UpdateChannel.NIGHTLY else YoutubeDL.UpdateChannel.STABLE
        val status = YoutubeDL.getInstance().updateYoutubeDL(ctx.applicationContext, channel)
        return status?.name ?: "UNKNOWN"
    }

    // ------------------------------------------------------------- helpers

    private fun pickOutput(dir: File): File? {
        val skip = setOf("part", "ytdl", "temp", "json", "jpg", "jpeg", "png", "webp", "vtt", "srt", "ass", "lrc")
        return dir.listFiles()
            ?.filter { it.isFile && it.extension.lowercase() !in skip }
            ?.maxByOrNull { it.length() }
    }

    private fun cleanError(t: Throwable): String {
        val msg = t.message ?: t.toString()
        val lines = msg.lines().map { it.trim() }.filter { it.isNotEmpty() }
        return lines.lastOrNull { it.startsWith("ERROR") }?.removePrefix("ERROR:")?.trim()
            ?: lines.lastOrNull()
            ?: "Unknown error"
    }

    private fun push(ctx: Context, job: Job, force: Boolean) {
        val now = System.currentTimeMillis()
        if (!force && now - job.lastPush < 400) return
        job.lastPush = now
        emit(job.toMap())

        val running = jobs.values.filter { it.status == "running" }
        if (running.isNotEmpty()) {
            if (!serviceOn) {
                serviceOn = true
                Notifier.ensureChannels(ctx)
                DownloadService.ensure(ctx)
            }
            Notifier.updateProgress(ctx, running.size, running.map { it.progress }.average().toFloat())
        } else if (serviceOn) {
            serviceOn = false
            DownloadService.stop(ctx)
        }
    }
}
