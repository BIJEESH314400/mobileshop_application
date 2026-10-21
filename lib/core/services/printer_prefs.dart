import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which paired Bluetooth printer *this phone* should use
/// when printing a receipt -- a deliberately per-device setting
/// (SharedPreferences, same as Dark Mode / idle-lock timestamps),
/// not a Firestore shop-wide setting. Bluetooth pairing only ever
/// connects one specific phone to one specific printer, so a setting
/// synced across every staff phone would be misleading -- each
/// counter phone has to pick its own nearby paired printer.
///
/// Only PrinterSettingsScreen (owner-only, see OwnerOnlyGate) ever
/// writes this; the Sales History receipt print button only reads it.
class PrinterPrefs {
  PrinterPrefs._();

  static const _keyAddress = 'selected_printer_address';
  static const _keyName = 'selected_printer_name';

  static Future<void> setSelectedPrinter({required String address, required String name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAddress, address);
    await prefs.setString(_keyName, name);
  }

  static Future<String?> getSelectedPrinterAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyAddress);
    return (value == null || value.isEmpty) ? null : value;
  }

  static Future<String?> getSelectedPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAddress);
    await prefs.remove(_keyName);
  }
}
