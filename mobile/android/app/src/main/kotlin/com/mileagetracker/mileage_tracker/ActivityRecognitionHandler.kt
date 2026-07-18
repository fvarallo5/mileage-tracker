package com.mileagetracker.mileage_tracker

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Google Play activity recognition — used as an optional auto-detect gate
 * so GPS watching can sleep until the user is likely in a vehicle.
 */
class ActivityRecognitionHandler(
    private val context: Context,
) : EventChannel.StreamHandler {
    private val methodChannelName = "com.mileagetracker/activity_recognition"
    private val eventChannelName = "com.mileagetracker/activity_recognition_events"
    private val action = "${context.packageName}.ACTIVITY_UPDATES"

    private var eventSink: EventChannel.EventSink? = null
    private var listening = false
    private var lastType = "unknown"
    private var lastConfidence = 0
    private var inVehicle = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent == null || !ActivityRecognitionResult.hasResult(intent)) return
            val result = ActivityRecognitionResult.extractResult(intent) ?: return
            val most = result.mostProbableActivity ?: return
            applyDetected(most)
            emitState()
        }
    }

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getState" -> result.success(currentState())
                    "isAvailable" -> result.success(true)
                    "start" -> {
                        startUpdates()
                        result.success(currentState())
                    }
                    "stop" -> {
                        stopUpdates()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        startUpdates()
        emitState()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        stopUpdates()
    }

    private fun hasPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACTIVITY_RECOGNITION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun startUpdates() {
        if (listening) return
        if (!hasPermission()) {
            emitState()
            return
        }

        val filter = IntentFilter(action)
        ContextCompat.registerReceiver(
            context,
            receiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )

        val intent = Intent(action).setPackage(context.packageName)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
        val pending = PendingIntent.getBroadcast(context, 1001, intent, flags)

        ActivityRecognition.getClient(context)
            .requestActivityUpdates(15_000L, pending)
            .addOnSuccessListener {
                listening = true
            }
            .addOnFailureListener {
                lastType = "unavailable"
                inVehicle = false
                emitState()
            }
    }

    private fun stopUpdates() {
        if (!listening && eventSink == null) {
            // still try unregister
        }
        try {
            context.unregisterReceiver(receiver)
        } catch (_: Exception) {
        }

        if (!hasPermission()) {
            listening = false
            return
        }

        val intent = Intent(action).setPackage(context.packageName)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
        val pending = PendingIntent.getBroadcast(context, 1001, intent, flags)
        try {
            ActivityRecognition.getClient(context).removeActivityUpdates(pending)
        } catch (_: Exception) {
        }
        listening = false
    }

    private fun applyDetected(activity: DetectedActivity) {
        lastConfidence = activity.confidence
        lastType = when (activity.type) {
            DetectedActivity.IN_VEHICLE -> "in_vehicle"
            DetectedActivity.ON_BICYCLE -> "on_bicycle"
            DetectedActivity.ON_FOOT -> "on_foot"
            DetectedActivity.WALKING -> "walking"
            DetectedActivity.RUNNING -> "running"
            DetectedActivity.STILL -> "still"
            DetectedActivity.TILTING -> "tilting"
            DetectedActivity.UNKNOWN -> "unknown"
            else -> "unknown"
        }
        // Vehicle-like for gig work (car / bike). Require modest confidence.
        inVehicle = (activity.type == DetectedActivity.IN_VEHICLE ||
            activity.type == DetectedActivity.ON_BICYCLE) &&
            activity.confidence >= 40
    }

    private fun emitState() {
        eventSink?.success(currentState())
    }

    private fun currentState(): Map<String, Any?> {
        return mapOf(
            "available" to true,
            "inVehicle" to inVehicle,
            "activity" to lastType,
            "confidence" to lastConfidence,
            "permission" to hasPermission(),
        )
    }
}
