/// One Bluetooth device already paired with this phone, as returned
/// by BluetoothPrinterService.listBondedDevices() -- not necessarily
/// a printer (the native side has no way to tell), so the Printer
/// Settings screen shows every bonded device and lets the owner pick
/// which one is actually their receipt printer.
class BluetoothPrinterDevice {
  final String name;
  final String address;

  const BluetoothPrinterDevice({required this.name, required this.address});
}
