// MainActivity.kt
package com.haweeinc.advent_song // Updated to match your package name

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.haweeinc.advent_song/share" // Updated channel name to match package

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Ensure flutterEngine is not null and use the non-null assertion
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "share") {
                val title = call.argument<String>("title")
                val lyrics = call.argument<String>("lyrics")
                shareSong("$title\n\n$lyrics")
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun shareSong(content: String) {
        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, content)
        }
        startActivity(Intent.createChooser(shareIntent, "Share Song"))
    }
}
