package com.mileagetracker.mileage_tracker

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.mileagetracker/voice_commands"
    private var methodChannel: MethodChannel? = null
    private var pendingAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureVoiceAction(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureVoiceAction(intent)
        deliverPendingAction()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingAction" -> {
                        result.success(pendingAction)
                        pendingAction = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        deliverPendingAction()
    }

    private fun captureVoiceAction(intent: Intent?) {
        val action = when {
            intent?.action == ACTION_START_TRIP -> "start_trip"
            intent?.action == ACTION_STOP_TRIP -> "stop_trip"
            intent?.data?.host == "start-trip" -> "start_trip"
            intent?.data?.host == "stop-trip" -> "stop_trip"
            else -> null
        }
        if (action != null) {
            pendingAction = action
        }
    }

    private fun deliverPendingAction() {
        val action = pendingAction ?: return
        val channel = methodChannel ?: return
        channel.invokeMethod("onVoiceCommand", action)
        pendingAction = null
    }

    companion object {
        private const val ACTION_START_TRIP = "com.mileagetracker.START_TRIP"
        private const val ACTION_STOP_TRIP = "com.mileagetracker.STOP_TRIP"
    }
}