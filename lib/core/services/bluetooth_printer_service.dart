import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/bluetooth_printer_device.dart';
import '../utils/app_logger.dart';

/// Outcome of a print attempt -- deliberately more specific than a
/// plain bool so the caller can show "turn on Bluetooth permission"
/// vs "couldn't reach the printer" vs a generic failure, rather than
/// one catch-all error message for every kind of failure.
enum PrintOutcome { success, permissionDenied, connectFailed, noPrinterSelected, error }

/// Thin wrapper around the native Bluetooth ESC/POS printer bridge
/// (BluetoothPrinterPlugin.kt, registered in MainActivity.kt) -- the
/// only place in this app that talks to that platform channel.
///
/// Deliberately a fresh connect-print-disconnect per call, never a
/// held-open connection -- see BluetoothPrinterPlugin's own doc
/// comment for why (most cheap thermal printers only accept one
/// active connection at a time).
class BluetoothPrinterService {
  BluetoothPrinterService._();
  static final BluetoothPrinterService instance = BluetoothPrinterService._();

  static const MethodChannel _channel = MethodChannel('com.fourbmobiles.app/printer');

  Future<bool> isBluetoothSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isBluetoothSupported') ?? false;
    } catch (e, st) {
      AppLogger.error('BluetoothPrinterService.isBluetoothSupported', e, st);
      return false;
    }
  }

  Future<bool> isBluetoothEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isBluetoothEnabled') ?? false;
    } catch (e, st) {
      AppLogger.error('BluetoothPrinterService.isBluetoothEnabled', e, st);
      return false;
    }
  }

  /// Requests the runtime Bluetooth permission (Android 12+ only --
  /// a no-op success on older Android, same shape as
  /// VoiceInputService.ensureMicrophonePermission). Must succeed
  /// before listing paired devices or printing will work on a modern
  /// phone.
  Future<bool> ensurePermission() async {
    try {
      final status = await Permission.bluetoothConnect.request();
      return status.isGranted;
    } catch (e, st) {
      AppLogger.error('BluetoothPrinterService.ensurePermission', e, st);
      return false;
    }
  }

  /// Every Bluetooth device already paired with this phone (via the
  /// phone's own system Bluetooth settings) -- not filtered down to
  /// "looks like a printer" in any way, since there's no reliable way
  /// to tell from here. The Printer Settings screen shows the whole
  /// list and lets the owner pick which one actually is their printer.
  Future<List<BluetoothPrinterDevice>> listBondedDevices() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('listBondedDevices') ?? const [];
      return raw
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map(
            (map) => BluetoothPrinterDevice(
              name: map['name'] as String? ?? 'Unknown device',
              address: map['address'] as String? ?? '',
            ),
          )
          .where((device) => device.address.isNotEmpty)
          .toList();
    } catch (e, st) {
      AppLogger.error('BluetoothPrinterService.listBondedDevices', e, st);
      return const [];
    }
  }

  /// Connects to [address], writes [bytes], disconnects. May take a
  /// few seconds if the printer is off/out of range before it
  /// reports failure -- that's the OS's own Bluetooth connect timeout,
  /// not a bug here.
  Future<PrintOutcome> printBytes({required String address, required Uint8List bytes}) async {
    try {
      final ok = await _channel.invokeMethod<bool>('printBytes', {
        'address': address,
        'bytes': bytes,
      });
      return ok == true ? PrintOutcome.success : PrintOutcome.error;
    } on PlatformException catch (e, st) {
      AppLogger.error('BluetoothPrinterService.printBytes', e, st);
      switch (e.code) {
        case 'PERMISSION_DENIED':
          return PrintOutcome.permissionDenied;
        case 'CONNECT_FAILED':
          return PrintOutcome.connectFailed;
        default:
          return PrintOutcome.error;
      }
    } catch (e, st) {
      AppLogger.error('BluetoothPrinterService.printBytes', e, st);
      return PrintOutcome.error;
    }
  }
}
