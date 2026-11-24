package com.aos

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val io = Executors.newCachedThreadPool()
    private val ui = Handler(Looper.getMainLooper())
    private var events: EventChannel.EventSink? = null
    private var pendingShare: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingShare = shareText(intent)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "pluck/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                events = sink
                Engine.emit = { m -> ui.post { events?.success(m) } }
            }

            override fun onCancel(arguments: Any?) {
                events = null
                Engine.emit = {}
            }
        })

        MethodChannel(messenger, "pluck/engine").setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> bg(result) { Engine.init(applicationContext) }
                "analyze" -> bg(result) {
                    Engine.analyze(call.argument<String>("url")!!, call.argument<Boolean>("noPlaylist") ?: false)
                }
                "start" -> {
                    Engine.start(
                        applicationContext,
                        id = call.argument<String>("id")!!,
                        url = call.argument<String>("url")!!,
                        title = call.argument<String>("title") ?: "Download",
                        opts = parseOpts(call),
                        subdir = call.argument<String>("subdir") ?: "Pluck",
                        useAria = call.argument<Boolean>("aria") ?: false,
                        connections = call.argument<Int>("connections") ?: 8,
                    )
                    result.success(null)
                }
                "cancel" -> {
                    Engine.cancel(call.argument<String>("id")!!, call.argument<Boolean>("pause") ?: false)
                    result.success(null)
                }
                "forget" -> {
                    Engine.forget(call.argument<String>("id")!!)
                    result.success(null)
                }
                "snapshot" -> result.success(Engine.snapshot())
                "update" -> bg(result) { Engine.updateBinary(applicationContext, call.argument<Boolean>("nightly") ?: false) }
                "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                "initialShare" -> {
                    result.success(pendingShare)
                    pendingShare = null
                }
                "fileExists" -> bg(result) { MediaSaver.exists(applicationContext, call.argument<String>("uri")!!) }
                "deleteFile" -> bg(result) { MediaSaver.delete(applicationContext, call.argument<String>("uri")!!) }
                "openFile" -> openFile(call, result)
                "shareFile" -> shareFile(call, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        shareText(intent)?.let { text ->
            events?.success(mapOf("type" to "share", "text" to text))
        }
    }

    override fun onDestroy() {
        events = null
        Engine.emit = {}
        super.onDestroy()
    }

    // ------------------------------------------------------------- helpers

    private fun shareText(i: Intent?): String? {
        if (i?.action != Intent.ACTION_SEND) return null
        return i.getStringExtra(Intent.EXTRA_TEXT)
    }

    @Suppress("UNCHECKED_CAST")
    private fun parseOpts(call: MethodCall): List<Opt> {
        val raw = call.argument<List<Map<String, Any?>>>("options") ?: return emptyList()
        return raw.map { Opt(it["k"] as String, it["v"] as String?) }
    }

    private fun bg(result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            try {
                val value = block()
                ui.post { result.success(value) }
            } catch (t: Throwable) {
                android.util.Log.e("Pluck", "engine call failed", t)
                val detail = buildString {
                    append(t.javaClass.simpleName)
                    t.message?.takeIf { it.isNotBlank() }?.let { append(": ").append(it) }
                    t.cause?.let { c ->
                        append(" | cause: ").append(c.javaClass.simpleName)
                        c.message?.takeIf { it.isNotBlank() }?.let { append(": ").append(it) }
                    }
                }
                ui.post { result.error("ENGINE", detail, null) }
            }
        }
    }

    private fun openFile(call: MethodCall, result: MethodChannel.Result) {
        val uri = Uri.parse(call.argument<String>("uri")!!)
        val mime = call.argument<String>("mime") ?: "*/*"
        val i = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, mime)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(i)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.error("NO_APP", "No app can open this file", null)
        }
    }

    private fun shareFile(call: MethodCall, result: MethodChannel.Result) {
        val uri = Uri.parse(call.argument<String>("uri")!!)
        val mime = call.argument<String>("mime") ?: "*/*"
        val send = Intent(Intent.ACTION_SEND)
            .setType(mime)
            .putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        startActivity(Intent.createChooser(send, "Share").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        result.success(true)
    }
}
