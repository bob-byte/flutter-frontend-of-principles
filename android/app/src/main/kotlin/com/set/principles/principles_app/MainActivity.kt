package com.set.principles

import android.os.Bundle
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Українська як мова додатку — щоб IME пропонував укр. розкладку.
        AppCompatDelegate.setApplicationLocales(
            LocaleListCompat.forLanguageTags("uk-UA,en-US")
        )
        super.onCreate(savedInstanceState)
    }
}
