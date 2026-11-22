package com.thepercentage.tpc_invoice

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val alertChannel = "workspace_alerts"
    private val silentChannel = "workspace_silent"
    private val notificationAction = "com.thepercentage.tpc_invoice.WORKSPACE_NOTIFICATION"
    private var bridge: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannels(listOf(
                NotificationChannel(alertChannel, "Workspace alerts", NotificationManager.IMPORTANCE_HIGH),
                NotificationChannel(silentChannel, "Silent workspace alerts", NotificationManager.IMPORTANCE_LOW)
            ))
        }
        bridge = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tpc/workspace_notifications")
        bridge?.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    showNotification(call.arguments as? Map<*, *> ?: emptyMap<String, String>())
                    result.success(null)
                }
                "initial" -> result.success(takeLink(intent))
                else -> result.notImplemented()
            }
        }
    }

    private fun showNotification(data: Map<*, *>) {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val id = data["notificationId"] as? String ?: return
        val company = data["companyId"] as? String ?: return
        val open = Intent(this, MainActivity::class.java).apply {
            action = notificationAction
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("notificationId", id)
            putExtra("companyId", company)
            putExtra("taskId", data["taskId"] as? String)
        }
        val pending = PendingIntent.getActivity(
            this, id.hashCode(), open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val silent = data["sound"] == "none"
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, if (silent) silentChannel else alertChannel)
        } else {
            Notification.Builder(this).apply {
                if (!silent) {
                    setDefaults(Notification.DEFAULT_ALL)
                    setPriority(Notification.PRIORITY_HIGH)
                }
            }
        }
        getSystemService(NotificationManager::class.java).notify(
            id, 0, builder.setSmallIcon(applicationInfo.icon)
                .setContentTitle(data["title"] as? String ?: "Workspace notification")
                .setContentText(data["body"] as? String ?: "Open your workspace for details.")
                .setContentIntent(pending).setAutoCancel(true).build()
        )
    }

    private fun takeLink(open: Intent?): Map<String, String?>? {
        if (open == null || open.action != notificationAction) return null
        open.action = Intent.ACTION_MAIN
        return listOf("notificationId", "companyId", "taskId").associateWith { open.getStringExtra(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        takeLink(intent)?.let { bridge?.invokeMethod("opened", it) }
    }
}
