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
        // Re-enable MainActivity after older icon-plugin builds that disabled it,
        // and repair dual-alias states from the upgrade to icon_orange / icon_1.
        AppIconSwitcher.migrateIfNeeded(this)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        SplashAudioPlayer(this).register(messenger)
        MethodChannel(
            messenger,
            "com.set.principles/app_icon",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setIcon" -> {
                    val icon = call.arguments as? String
                    if (icon == null) {
                        result.error("bad_args", "Expected orange|blue", null)
                        return@setMethodCallHandler
                    }
                    // Queue only — apply when Flutter reports background so One UI
                    // does not kick the user to the home screen mid-session.
                    AppIconSwitcher.setDesired(this, icon)
                    result.success(null)
                }
                "applyPendingIcon" -> {
                    AppIconSwitcher.applyPending(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            messenger,
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

    /** Pins the month calendar. Preview extras use the runtime shell (no `<include>`). */
    private fun requestPinCalendarWidget(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = AppWidgetManager.getInstance(this)
        if (!manager.isRequestPinAppWidgetSupported) return false
        val provider = ComponentName(this, CalendarMonthWidgetProvider::class.java)
        // Do not pass month_preview here: its `<include>`s are fine for picker
        // previewLayout inflation, but Samsung often rejects them as RemoteViews.
        val extras =
            Bundle().apply {
                putParcelable(
                    AppWidgetManager.EXTRA_APPWIDGET_PREVIEW,
                    RemoteViews(packageName, R.layout.calendar_widget_month),
                )
            }
        return try {
            manager.requestPinAppWidget(provider, extras, null)
            true
        } catch (_: Exception) {
            try {
                manager.requestPinAppWidget(provider, null, null)
                true
            } catch (_: Exception) {
                false
            }
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
