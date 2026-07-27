package com.hanestl.flule34

import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "inspectFile" -> {
                    val rawUri = call.argument<String>("uri")
                    if (rawUri.isNullOrBlank()) {
                        result.error("INVALID_URI", "文件 URI 不能为空", null)
                    } else {
                        result.success(inspectFile(Uri.parse(rawUri)))
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, LOG_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val retentionDays = call.argument<Int>("retentionDays") ?: 3
                    NativeDebugLog.configure(this, enabled, retentionDays)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun inspectFile(uri: Uri): Map<String, Any?> {
        if (uri.scheme == "file") {
            val file = uri.path?.let(::File)
            if (file == null) {
                return mapOf(
                    "exists" to false,
                    "readable" to false,
                    "name" to null,
                    "size" to null,
                )
            }
            val exists = file.exists() && file.isFile
            return mapOf(
                "exists" to exists,
                "readable" to (exists && file.canRead()),
                "name" to file.name,
                "size" to if (exists) file.length() else null,
            )
        }

        if (uri.scheme != "content") {
            return mapOf(
                "exists" to false,
                "readable" to false,
                "name" to null,
                "size" to null,
            )
        }

        return try {
            var name: String? = null
            var size: Long? = null
            var queryFoundFile = false
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    queryFoundFile = true
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (nameIndex >= 0 && !cursor.isNull(nameIndex)) {
                        name = cursor.getString(nameIndex)
                    }
                    if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                        size = cursor.getLong(sizeIndex)
                    }
                }
            }
            val readable = runCatching {
                contentResolver.openFileDescriptor(uri, "r")?.use { descriptor ->
                    if (size == null && descriptor.statSize >= 0L) {
                        size = descriptor.statSize
                    }
                    true
                } ?: false
            }.getOrDefault(false)
            mapOf(
                "exists" to (queryFoundFile || readable),
                "readable" to readable,
                "name" to name,
                "size" to size,
            )
        } catch (_: RuntimeException) {
            mapOf(
                "exists" to false,
                "readable" to false,
                "name" to null,
                "size" to null,
            )
        }
    }

    private companion object {
        const val STORAGE_CHANNEL = "com.hanestl.flule34/storage_access"
        const val LOG_CHANNEL = "com.hanestl.flule34/app_log"
    }
}
