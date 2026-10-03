package com.jugaad.app

import android.os.Build
import android.os.Bundle
import android.view.Display
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        enableHighRefreshRate()
    }

    /// Queries supported display modes and requests the highest refresh rate (90Hz / 120Hz / 144Hz)
    private fun enableHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                }
                
                val modes = display?.supportedModes
                if (!modes.isNullOrEmpty()) {
                    var maxRate = 60f
                    var bestModeId = 0
                    for (mode in modes) {
                        if (mode.refreshRate > maxRate) {
                            maxRate = mode.refreshRate
                            bestModeId = mode.modeId
                        }
                    }
                    if (bestModeId != 0) {
                        val params = window.attributes
                        params.preferredDisplayModeId = bestModeId
                        window.attributes = params
                    }
                }
            } catch (e: Exception) {
                // Silently fallback if device vendor prohibits display mode override
            }
        }
    }
}
