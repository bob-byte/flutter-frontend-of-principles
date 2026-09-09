package com.set.principles

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.RemoteViews
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.app.NotificationManagerCompat
import androidx.core.os.LocaleListCompat
import com.set.principles.calendar.CalendarMonthWidgetProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Українська як мова додатку — щоб IME пропонував укр. розкладку.
        AppCompatDelegate.setApplicationLocales(
            LocaleListCompat.forLanguageTags("uk-UA,en-US")
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.set.principles/app_settings",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" ->
                    result.success(openNotificationSettings())
                "clearDeliveredNotifications" -> {
                    // Status bar only — does not cancel AlarmManager schedules.
                    NotificationManagerCompat.from(this).cancelAll()
                    result.success(null)
                }
                "requestPinCalendarWidget" ->
                    result.success(requestPinCalendarWidget())
                else -> result.notImplemented()
            }
        }
    }

    /** Pins the month calendar with a filled static preview (not the empty runtime shell). */
    private fun requestPinCalendarWidget(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = AppWidgetManager.getInstance(this)
        if (!manager.isRequestPinAppWidgetSupported) return false
        val provider = ComponentName(this, CalendarMonthWidgetProvider::class.java)
        val extras =
            Bundle().apply {
                putParcelable(
                    AppWidgetManager.EXTRA_APPWIDGET_PREVIEW,
                    RemoteViews(packageName, R.layout.calendar_widget_month_preview),
                )
            }
        return try {
            manager.requestPinAppWidget(provider, extras, null)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openNotificationSettings(): Boolean {
        val notificationIntent = Intent().apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            } else {
                action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                data = Uri.fromParts("package", packageName, null)
            }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            startActivity(notificationIntent)
            true
        } catch (_: Exception) {
            val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(details)
            true
        }
    }
}
