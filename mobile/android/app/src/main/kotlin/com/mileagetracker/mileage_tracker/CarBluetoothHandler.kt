package com.mileagetracker.mileage_tracker

import android.Manifest
import android.bluetooth.BluetoothA2dp
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Detects vehicle-like Bluetooth audio connections (car stereo / HFP / A2DP).
 * Used as an optional gate so auto-detect GPS can sleep until the car connects.
 */
class CarBluetoothHandler(
    private val context: Context,
) : EventChannel.StreamHandler {
    private val methodChannelName = "com.mileagetracker/car_bluetooth"
    private val eventChannelName = "com.mileagetracker/car_bluetooth_events"

    private var eventSink: EventChannel.EventSink? = null
    private var a2dp: BluetoothA2dp? = null
    private var headset: BluetoothHeadset? = null
    private var receiverRegistered = false

    private val profileListener = object : BluetoothProfile.ServiceListener {
        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
            when (profile) {
                BluetoothProfile.A2DP -> a2dp = proxy as? BluetoothA2dp
                BluetoothProfile.HEADSET -> headset = proxy as? BluetoothHeadset
            }
            emitState()
        }

        override fun onServiceDisconnected(profile: Int) {
            when (profile) {
                BluetoothProfile.A2DP -> a2dp = null
                BluetoothProfile.HEADSET -> headset = null
            }
            emitState()
        }
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            emitState()
        }
    }

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getState" -> result.success(currentState())
                    "isAvailable" -> result.success(adapter() != null)
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        bindProfiles()
        registerReceiver()
        emitState()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        unregisterReceiver()
        unbindProfiles()
    }

    private fun adapter(): BluetoothAdapter? {
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter
    }

    private fun hasConnectPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.BLUETOOTH_CONNECT,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun bindProfiles() {
        val adapter = adapter() ?: return
        if (!hasConnectPermission()) return
        try {
            adapter.getProfileProxy(context, profileListener, BluetoothProfile.A2DP)
            adapter.getProfileProxy(context, profileListener, BluetoothProfile.HEADSET)
        } catch (_: SecurityException) {
            // Permission revoked mid-session.
        }
    }

    private fun unbindProfiles() {
        val adapter = adapter() ?: return
        try {
            a2dp?.let { adapter.closeProfileProxy(BluetoothProfile.A2DP, it) }
            headset?.let { adapter.closeProfileProxy(BluetoothProfile.HEADSET, it) }
        } catch (_: Exception) {
        }
        a2dp = null
        headset = null
    }

    private fun registerReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction(BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED)
            addAction(BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED)
            addAction(BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED)
        }
        ContextCompat.registerReceiver(
            context,
            receiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        receiverRegistered = true
    }

    private fun unregisterReceiver() {
        if (!receiverRegistered) return
        try {
            context.unregisterReceiver(receiver)
        } catch (_: Exception) {
        }
        receiverRegistered = false
    }

    private fun emitState() {
        eventSink?.success(currentState())
    }

    private fun currentState(): Map<String, Any?> {
        if (adapter() == null) {
            return mapOf(
                "available" to false,
                "connected" to false,
                "deviceName" to null,
                "permission" to true,
            )
        }
        if (!hasConnectPermission()) {
            return mapOf(
                "available" to true,
                "connected" to false,
                "deviceName" to null,
                "permission" to false,
            )
        }

        val devices = linkedMapOf<String, BluetoothDevice>()
        try {
            a2dp?.connectedDevices?.forEach { devices[it.address] = it }
            headset?.connectedDevices?.forEach { devices[it.address] = it }
        } catch (_: SecurityException) {
            return mapOf(
                "available" to true,
                "connected" to false,
                "deviceName" to null,
                "permission" to false,
            )
        }

        val vehicle = devices.values.firstOrNull { isVehicleLike(it) }
        return mapOf(
            "available" to true,
            "connected" to (vehicle != null),
            "deviceName" to vehicle?.name,
            "permission" to true,
        )
    }

    private fun isVehicleLike(device: BluetoothDevice): Boolean {
        val btClass = try {
            device.bluetoothClass
        } catch (_: SecurityException) {
            null
        } ?: return true // Connected audio profile without class — treat as vehicle-capable.

        return when (btClass.deviceClass) {
            BluetoothClass.Device.AUDIO_VIDEO_CAR_AUDIO,
            BluetoothClass.Device.AUDIO_VIDEO_HANDSFREE,
            BluetoothClass.Device.AUDIO_VIDEO_HIFI_AUDIO,
            BluetoothClass.Device.AUDIO_VIDEO_LOUDSPEAKER,
            -> true
            BluetoothClass.Device.AUDIO_VIDEO_WEARABLE_HEADSET,
            BluetoothClass.Device.AUDIO_VIDEO_HEADPHONES,
            BluetoothClass.Device.AUDIO_VIDEO_PORTABLE_AUDIO,
            -> false
            else -> btClass.majorDeviceClass == BluetoothClass.Device.Major.AUDIO_VIDEO
        }
    }
}
