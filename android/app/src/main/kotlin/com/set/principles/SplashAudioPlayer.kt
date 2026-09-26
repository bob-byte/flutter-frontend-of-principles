package com.set.principles

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// Plays the splash WAV with [MediaPlayer] from a cache file.
///
/// Avoids audioplayers' BytesSource / MediaDataSource path, which can hang
/// waiting for prepared on some Android 11 OEMs.
class SplashAudioPlayer(private val context: Context) {
    private var player: MediaPlayer? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val bytes = call.arguments as? ByteArray
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("bad_args", "Expected WAV bytes", null)
                        return@setMethodCallHandler
                    }
                    try {
                        play(bytes)
                        result.success(null)
                    } catch (e: Exception) {
                        stop()
                        result.error("play_failed", e.message, null)
                    }
                }
                "stop" -> {
                    stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun play(bytes: ByteArray) {
        stop()
        val file = File(context.cacheDir, TEMP_NAME)
        file.writeBytes(bytes)

        val mp = MediaPlayer()
        mp.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build(),
        )
        mp.setDataSource(file.absolutePath)
        mp.setOnCompletionListener { stop() }
        mp.setOnErrorListener { _, _, _ ->
            stop()
            true
        }
        mp.setOnPreparedListener { prepared ->
            try {
                prepared.start()
            } catch (_: Exception) {
                stop()
            }
        }
        player = mp
        mp.prepareAsync()
    }

    private fun stop() {
        val current = player
        player = null
        if (current == null) return
        try {
            current.setOnPreparedListener(null)
            current.setOnCompletionListener(null)
            current.setOnErrorListener(null)
            if (current.isPlaying) {
                current.stop()
            }
        } catch (_: Exception) {
        }
        try {
            current.release()
        } catch (_: Exception) {
        }
    }

    companion object {
        private const val CHANNEL = "com.set.principles/splash_audio"
        private const val TEMP_NAME = "principles_epic_start.wav"
    }
}
