package com.hanestl.flule34

import android.app.Application
import android.content.Context
import android.os.Process
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.system.exitProcess

class Flule34Application : Application() {
    override fun onCreate() {
        super.onCreate()
        NativeDebugLog.install(this)
    }
}

object NativeDebugLog {
    private const val PREFS_NAME = "flule34_debug_logging"
    private const val ENABLED_KEY = "enabled"
    private const val RETENTION_DAYS_KEY = "retention_days"
    private const val LOG_DIRECTORY = "flule34_logs"
    private const val MAX_FILE_BYTES = 2L * 1024L * 1024L
    private const val MAX_RETENTION_DAYS = 7

    @Volatile
    private var enabled = false

    @Volatile
    private var retentionDays = 3

    private var previousHandler: Thread.UncaughtExceptionHandler? = null

    fun install(context: Context) {
        val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        enabled = preferences.getBoolean(ENABLED_KEY, false)
        retentionDays = preferences.getInt(RETENTION_DAYS_KEY, 3).coerceIn(1, MAX_RETENTION_DAYS)
        cleanup(context)

        val current = Thread.getDefaultUncaughtExceptionHandler()
        if (current is Flule34ExceptionHandler) {
            return
        }
        previousHandler = current
        Thread.setDefaultUncaughtExceptionHandler(
            Flule34ExceptionHandler(context.applicationContext),
        )
    }

    fun configure(context: Context, isEnabled: Boolean, days: Int) {
        enabled = isEnabled
        retentionDays = days.coerceIn(1, MAX_RETENTION_DAYS)
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(ENABLED_KEY, enabled)
            .putInt(RETENTION_DAYS_KEY, retentionDays)
            .apply()
        cleanup(context)
    }

    private fun writeCrash(context: Context, thread: Thread, throwable: Throwable) {
        if (!enabled) {
            return
        }
        try {
            val directory = File(context.filesDir, LOG_DIRECTORY)
            if (!directory.exists() && !directory.mkdirs()) {
                return
            }
            val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ", Locale.US).format(Date())
            val file = File(directory, "native-$date.log")
            if (file.exists() && file.length() >= MAX_FILE_BYTES) {
                return
            }
            val stack = redact(Log.getStackTraceString(throwable))
            file.appendText("$timestamp ERROR native 未捕获异常 thread=${thread.name}\n$stack\n")
        } catch (_: Exception) {
            // 崩溃处理器不能因为日志写入失败而阻止系统原有处理流程。
        }
    }

    private fun cleanup(context: Context) {
        try {
            val directory = File(context.filesDir, LOG_DIRECTORY)
            if (!directory.exists()) {
                return
            }
            val cutoff = System.currentTimeMillis() - retentionDays * 24L * 60L * 60L * 1000L
            directory.listFiles()?.forEach { file ->
                if (file.isFile && file.lastModified() < cutoff) {
                    file.delete()
                }
            }
        } catch (_: Exception) {
            // 清理失败不应影响 App 启动。
        }
    }

    private fun redact(value: String): String {
        return value
            .replace(Regex("(?i)([?&](?:v-acctoken|acctoken|token|access_token|auth|signature|password|passwd|email)=)[^&#\\s\"']+"), "\$1<redacted>")
            .replace(Regex("(?i)(PHPSESSID=)[^;\\s]+"), "\$1<redacted>")
            .replace(Regex("(?i)(Authorization\\s*[:=]\\s*(?:Bearer\\s+)?)[^\\s,;]+"), "\$1<redacted>")
            .replace(Regex("(?i)(Cookie\\s*[:=]\\s*)[^\\r\\n]+"), "\$1<redacted>")
            .replace(Regex("(?i)((?:\"?(?:password|passwd|email)\"?\\s*[:=]\\s*)[\"']?)[^\"',;\\s&}\\]]+"), "\$1<redacted>")
            .take(24_000)
    }

    private class Flule34ExceptionHandler(
        private val context: Context,
    ) : Thread.UncaughtExceptionHandler {
        override fun uncaughtException(thread: Thread, throwable: Throwable) {
            writeCrash(context, thread, throwable)
            val handler = previousHandler
            if (handler != null) {
                handler.uncaughtException(thread, throwable)
            } else {
                Process.killProcess(Process.myPid())
                exitProcess(10)
            }
        }
    }
}
