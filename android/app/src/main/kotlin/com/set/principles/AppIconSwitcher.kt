package com.set.principles

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log

/**
 * Swaps the home-screen icon between orange (default) and blue via activity-aliases.
 *
 * MainActivity itself stays enabled and has no LAUNCHER filter — only the aliases
 * do. That avoids the "Activity class does not exist" / broken flutter-run state
 * that happens when plugins disable MainActivity.
 *
 * Samsung One UI often never delivers [android.app.Service.onTaskRemoved], so the
 * flutter_dynamic_icon_plus defer-until-kill path is unreliable here. Callers
 * should [setDesired] then [applyPending] when the app is backgrounded.
 */
object AppIconSwitcher {
    private const val TAG = "AppIconSwitcher"
    private const val PREFS = "principles_app_icon"
    private const val KEY_DESIRED = "desired_icon"

    const val ICON_ORANGE = "orange"
    const val ICON_BLUE = "blue"

    private const val ALIAS_ORANGE = "com.set.principles.icon_orange"
    private const val ALIAS_BLUE = "com.set.principles.icon_1"

    fun setDesired(context: Context, icon: String) {
        val normalized = normalize(icon)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_DESIRED, normalized)
            .commit()
    }

    fun desired(context: Context): String {
        return normalize(
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_DESIRED, ICON_ORANGE),
        )
    }

    /** Ensures MainActivity is enabled and exactly one launcher alias matches [desired]. */
    fun applyPending(context: Context) {
        ensureMainActivityEnabled(context)
        val wantBlue = desired(context) == ICON_BLUE
        val orangeEnabled = isEnabled(context, ALIAS_ORANGE)
        val blueEnabled = isEnabled(context, ALIAS_BLUE)

        if (wantBlue && blueEnabled && !orangeEnabled) return
        if (!wantBlue && orangeEnabled && !blueEnabled) return

        val enable = if (wantBlue) ALIAS_BLUE else ALIAS_ORANGE
        val disable = if (wantBlue) ALIAS_ORANGE else ALIAS_BLUE
        Log.d(TAG, "Applying launcher icon: $enable")
        setEnabled(context, enable, true)
        setEnabled(context, disable, false)
    }

    /**
     * Repair state after upgrades from the old MainActivity-as-launcher layout
     * (MainActivity may still be disabled; both or neither aliases enabled).
     * Does not flip a single valid alias during launch — that waits until Flutter
     * backgrounds the app so One UI does not kill the starting activity.
     */
    fun migrateIfNeeded(context: Context) {
        ensureMainActivityEnabled(context)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val orangeEnabled = isEnabled(context, ALIAS_ORANGE)
        val blueEnabled = isEnabled(context, ALIAS_BLUE)
        if (!prefs.contains(KEY_DESIRED)) {
            if (blueEnabled && !orangeEnabled) {
                setDesired(context, ICON_BLUE)
            } else {
                setDesired(context, ICON_ORANGE)
            }
        }
        // Both enabled (upgrade glitch) or neither (broken) — repair now.
        if (orangeEnabled == blueEnabled) {
            applyPending(context)
        }
    }

    private fun ensureMainActivityEnabled(context: Context) {
        setEnabled(context, MainActivity::class.java.name, true)
    }

    private fun normalize(icon: String?): String =
        if (icon == ICON_BLUE) ICON_BLUE else ICON_ORANGE

    private fun isEnabled(context: Context, className: String): Boolean {
        val pm = context.packageManager
        val component = ComponentName(context, className)
        return when (pm.getComponentEnabledSetting(component)) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> {
                try {
                    pm.getActivityInfo(component, PackageManager.GET_META_DATA).enabled
                } catch (_: Exception) {
                    false
                }
            }
            else -> false
        }
    }

    private fun setEnabled(context: Context, className: String, enabled: Boolean) {
        val pm = context.packageManager
        val component = ComponentName(context, className)
        val state =
            if (enabled) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
        try {
            pm.setComponentEnabledSetting(
                component,
                state,
                PackageManager.DONT_KILL_APP,
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to set $className enabled=$enabled", e)
        }
    }
}
