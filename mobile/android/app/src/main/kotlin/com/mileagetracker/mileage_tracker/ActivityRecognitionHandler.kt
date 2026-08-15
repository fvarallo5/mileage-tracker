package com.mileagetracker.mileage_tracker

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Stub: Play Console treats ACTIVITY_RECOGNITION as a Health Apps permission.
 * TrekTrack is not a health app, so we do not request or use activity recognition
 * on Android. Vehicle auto-detect relies on GPS speed / other gates instead.
 *
 * iOS still uses Core Motion via the same Flutter channel when available.
 */
class ActivityRecognitionHandler(
    @Suppress("UNUSED_PARAMETER") context: android.content.Context,
) : EventChannel.StreamHandler {
    private val methodChannelName = "com.mileagetracker/activity_recognition"
    private val eventChannelName = "com.mileagetracker/activity_recognition_events"

    private var eventSink: EventChannel.EventSink? = null

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getState" -> result.success(unavailableState())
                    "isAvailable" -> result.success(false)
                    "start", "stop" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        eventSink?.success(unavailableState())
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun unavailableState(): Map<String, Any?> = mapOf(
        "available" to false,
        "inVehicle" to false,
        "activity" to "unavailable",
        "confidence" to 0,
        "permission" to false,
    )
}
