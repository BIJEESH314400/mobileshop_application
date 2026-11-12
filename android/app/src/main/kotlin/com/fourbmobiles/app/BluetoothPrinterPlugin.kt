package com.fourbmobiles.app

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import java.io.IOException
import java.io.OutputStream
import java.util.UUID

/**
 * Generic Bluetooth ESC/POS thermal printer bridge for Flutter.
 *
 * Ported from a client-provided reference Android app's own
 * BluetoothChatService/BlueToothPrinter (classic Bluetooth SPP +
 * ESC/POS) -- that reference project had no real "Visiontek" SDK of
 * its own (the only mention was a commented-out, never-implemented
 * function call); its actual, production-tested printer code is this
 * generic Bluetooth approach, which is exactly what a Visiontek
 * thermal printer (or almost any cheap ESC/POS Bluetooth receipt
 * printer sold in India) speaks. So this one driver covers both.
 *
 * Matches that reference's own hard-won fixes, carried over on purpose:
 * - No battery/status pre-check before printing -- on real hardware
 *   that query just makes some printers print their own self-test
 *   slip instead of replying over Bluetooth, silently breaking the
 *   real print job. This bridge just writes the receipt bytes directly.
 * - Connect -> write -> disconnect immediately per print job, never a
 *   held-open connection -- most cheap thermal printers only accept
 *   one active Bluetooth connection at a time, so closing right after
 *   printing frees the printer for the next print/app immediately.
 * - Runtime BLUETOOTH_CONNECT permission (Android 12+/API 31) is
 *   assumed already granted -- requested from the Dart side via the
 *   `permission_handler` package before this is ever called, the same
 *   pattern this app already uses for microphone access
 *   (VoiceInputService.ensureMicrophonePermission). Keeps this bridge
 *   simple -- no Activity-level permission-result plumbing needed here.
 * - All Bluetooth I/O runs on a background thread, never the Flutter
 *   platform/main thread -- connecting to a slow/out-of-range printer
 *   can block for several seconds, and doing that on the main thread
 *   would freeze the whole app's UI.
 */
class BluetoothPrinterPlugin(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.fourbmobiles.app/printer"

        // Standard Serial Port Profile UUID -- what essentially every
        // classic-Bluetooth ESC/POS thermal printer registers under.
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isBluetoothSupported" -> result.success(BluetoothAdapter.getDefaultAdapter() != null)
            "isBluetoothEnabled" -> result.success(BluetoothAdapter.getDefaultAdapter()?.isEnabled == true)
            "listBondedDevices" -> listBondedDevices(result)
            "openBluetoothSettings" -> openBluetoothSettings(result)
            "printBytes" -> {
                val address = call.argument<String>("address")
                val bytes = call.argument<ByteArray>("bytes")
                if (address.isNullOrEmpty() || bytes == null) {
                    result.error("BAD_ARGS", "address and bytes are required", null)
                    return
                }
                printBytes(address, bytes, result)
            }
            else -> result.notImplemented()
        }
    }

    // Jumps straight to the phone's own system Bluetooth toggle/pairing
    // screen -- added 2026-11-09 so the receipt Print flow can send the
    // owner there directly (Bluetooth off, or no printer paired yet)
    // instead of a dead-end "go turn it on yourself" message with no
    // way to act on it from inside the app.
    private fun openBluetoothSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun listBondedDevices(result: MethodChannel.Result) {
        try {
            val adapter = BluetoothAdapter.getDefaultAdapter()
            if (adapter == null) {
                result.success(emptyList<Map<String, String>>())
                return
            }
            val devices = adapter.bondedDevices?.map { device ->
                mapOf("name" to (device.name ?: "Unknown device"), "address" to device.address)
            } ?: emptyList()
            result.success(devices)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Bluetooth permission not granted", null)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun printBytes(address: String, bytes: ByteArray, result: MethodChannel.Result) {
        Thread {
            var socket: BluetoothSocket? = null
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                    ?: throw IOException("Bluetooth is not available on this device")
                val device = adapter.getRemoteDevice(address)
                // Cancel any in-progress discovery first -- discovery running at the
                // same time significantly slows down (or can fail) an RFCOMM connect.
                adapter.cancelDiscovery()
                socket = connectSocket(device)
                val out: OutputStream = socket.outputStream
                out.write(bytes)
                out.flush()
                mainHandler.post { result.success(true) }
            } catch (e: SecurityException) {
                mainHandler.post { result.error("PERMISSION_DENIED", "Bluetooth permission not granted", null) }
            } catch (e: IOException) {
                mainHandler.post {
                    result.error("CONNECT_FAILED", e.message ?: "Could not connect to the printer", null)
                }
            } catch (e: Exception) {
                mainHandler.post { result.error("ERROR", e.message, null) }
            } finally {
                try {
                    socket?.close()
                } catch (e: Exception) {
                    // Already failed/disconnected -- nothing more to do.
                }
            }
        }.start()
    }

    /**
     * Connects to [device] over classic Bluetooth SPP -- tries the
     * normal SDP-based socket first, and if that connect() fails,
     * falls back to RFCOMM channel 1 directly via reflection.
     *
     * Added 2026-11-09 after a real-device failure: connect() on the
     * SDP-based socket (createRfcommSocketToServiceRecord) threw
     * "read failed, socket might closed or timeout, read ret: -1" --
     * a well-known failure on Android's Bluetooth stack when a cheap
     * thermal printer's firmware doesn't answer the SDP service query
     * properly (very common on ESC/POS printers, Visiontek included --
     * they're not full Bluetooth stacks, just enough firmware to
     * accept a raw RFCOMM connection). Every printer of this kind
     * listens on RFCOMM channel 1 regardless of SDP, so bypassing SDP
     * and connecting to that channel directly is the standard
     * workaround other Android ESC/POS printer libraries use for this
     * exact error.
     */
    private fun connectSocket(device: BluetoothDevice): BluetoothSocket {
        try {
            val socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
            socket.connect()
            return socket
        } catch (sdpFailure: IOException) {
            try {
                val fallback = createChannelSocket(device, 1)
                fallback.connect()
                return fallback
            } catch (channelFailure: Exception) {
                // The SDP-path failure is usually the more informative
                // one to surface, unless the fallback hit something
                // worth reporting on its own.
                throw if (channelFailure is IOException) channelFailure else sdpFailure
            }
        }
    }

    // Hidden-but-stable API every classic-Bluetooth device exposes --
    // BluetoothDevice.createRfcommSocket(int channel), not part of the
    // public SDK because it skips the SDP lookup entirely.
    private fun createChannelSocket(device: BluetoothDevice, channel: Int): BluetoothSocket {
        val method = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
        return method.invoke(device, channel) as BluetoothSocket
    }
}
