package com.aos

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import java.io.File

/** Moves a finished file from the app's private work dir into public Downloads/<subdir>. */
object MediaSaver {

    data class Saved(val uri: String, val name: String, val size: Long, val mime: String)

    fun mimeOf(file: File): String {
        val ext = file.extension.lowercase()
        return when (ext) {
            "mkv" -> "video/x-matroska"
            "opus" -> "audio/ogg"
            "m4a" -> "audio/mp4"
            else -> MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "application/octet-stream"
        }
    }

    fun save(ctx: Context, src: File, subdir: String): Saved {
        val mime = mimeOf(src)
        val size = src.length()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = ctx.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, src.name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/" + subdir)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create file in Downloads")
            try {
                resolver.openOutputStream(uri)!!.use { out -> src.inputStream().use { it.copyTo(out, 256 * 1024) } }
                val done = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
                resolver.update(uri, done, null, null)
            } catch (t: Throwable) {
                resolver.delete(uri, null, null)
                throw t
            }
            Saved(uri.toString(), src.name, size, mime)
        } else {
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), subdir)
            dir.mkdirs()
            var dest = File(dir, src.name)
            var n = 1
            while (dest.exists()) {
                dest = File(dir, "${src.nameWithoutExtension} ($n).${src.extension}")
                n++
            }
            src.copyTo(dest)
            Saved(Uri.fromFile(dest).toString(), dest.name, size, mime)
        }
    }

    fun delete(ctx: Context, uriStr: String): Boolean {
        val uri = Uri.parse(uriStr)
        return try {
            if (uri.scheme == "file") File(uri.path!!).delete()
            else ctx.contentResolver.delete(uri, null, null) > 0
        } catch (_: Throwable) {
            false
        }
    }

    fun exists(ctx: Context, uriStr: String): Boolean {
        return try {
            ctx.contentResolver.openFileDescriptor(Uri.parse(uriStr), "r")?.use { true } ?: false
        } catch (_: Throwable) {
            false
        }
    }
}
