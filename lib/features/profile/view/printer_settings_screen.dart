import 'package:flutter/material.dart';

import '../../../core/models/bluetooth_printer_device.dart';
import '../../../core/services/bluetooth_printer_service.dart';
import '../../../core/services/printer_prefs.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/escpos_builder.dart';
import '../../../core/widgets/owner_only_gate.dart';

/// Owner-only: picks which already-paired Bluetooth thermal printer
/// *this phone* uses when printing a Sales receipt (see PrinterPrefs's
/// own doc comment for why this is a per-device setting, not a
/// Firestore shop-wide one). Reached from Profile -> Printer Settings.
///
/// Deliberately lists already-*paired* devices only (via the phone's
/// own Bluetooth settings) rather than scanning/discovering nearby
/// ones -- simpler, needs no extra BLUETOOTH_SCAN permission, and
/// matches how this kind of "pick a printer" screen almost always
/// works elsewhere: pair the printer like a pair of headphones first,
/// then just pick it here.
class PrinterSettingsScreen extends StatelessWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OwnerOnlyGate(child: _PrinterSettingsView());
  }
}

class _PrinterSettingsView extends StatefulWidget {
  const _PrinterSettingsView();

  @override
  State<_PrinterSettingsView> createState() => _PrinterSettingsViewState();
}

class _PrinterSettingsViewState extends State<_PrinterSettingsView> {
  bool _loading = true;
  bool _testing = false;
  String? _error;
  List<BluetoothPrinterDevice> _devices = const [];
  String? _selectedAddress;
  String? _selectedName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supported = await BluetoothPrinterService.instance.isBluetoothSupported();
      if (!supported) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'This phone has no Bluetooth hardware';
        });
        return;
      }
      final granted = await BluetoothPrinterService.instance.ensurePermission();
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Bluetooth permission is needed to see paired printers';
        });
        return;
      }
      final enabled = await BluetoothPrinterService.instance.isBluetoothEnabled();
      final devices =
          enabled ? await BluetoothPrinterService.instance.listBondedDevices() : <BluetoothPrinterDevice>[];
      final savedAddress = await PrinterPrefs.getSelectedPrinterAddress();
      final savedName = await PrinterPrefs.getSelectedPrinterName();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _devices = devices;
        _selectedAddress = savedAddress;
        _selectedName = savedName;
        _error = enabled ? null : 'Turn on Bluetooth, then tap Refresh';
      });
    } catch (e, st) {
      AppLogger.error('PrinterSettingsScreen._load', e, st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load paired devices -- try again";
      });
    }
  }

  Future<void> _select(BluetoothPrinterDevice device) async {
    await PrinterPrefs.setSelectedPrinter(address: device.address, name: device.name);
    if (!mounted) return;
    setState(() {
      _selectedAddress = device.address;
      _selectedName = device.name;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${device.name} set as the receipt printer')));
  }

  Future<void> _testPrint() async {
    final address = _selectedAddress;
    if (address == null) return;
    setState(() => _testing = true);
    final bytes = (EscPosBuilder()
          ..text('4B Mobiles', bold: true, doubleWidth: true, center: true)
          ..line()
          ..text('Test print', center: true)
          ..line()
          ..line()
          ..line('If you can read this, the printer is')
          ..line('connected and ready to print receipts.')
          ..feed(3))
        .build();
    final outcome = await BluetoothPrinterService.instance.printBytes(address: address, bytes: bytes);
    if (!mounted) return;
    setState(() => _testing = false);
    final message = switch (outcome) {
      PrintOutcome.success => 'Test print sent',
      PrintOutcome.permissionDenied => 'Bluetooth permission is needed to print',
      PrintOutcome.connectFailed => "Couldn't connect -- check the printer is on and in range",
      _ => "Couldn't print -- try again",
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              decoration: BoxDecoration(color: p.background, border: Border(bottom: BorderSide(color: p.border))),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 20, color: p.textPrimary),
                        const SizedBox(width: 10),
                        Text(
                          'Printer Settings',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _loading ? null : _load,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: p.border),
                      ),
                      child: Icon(Icons.refresh_rounded, size: 19, color: p.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          "Pair your Bluetooth thermal receipt printer (Visiontek or any ESC/POS printer) from this phone's own Bluetooth settings first -- then pick it below.",
                          style: TextStyle(fontSize: 13, color: p.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warningText),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: AppColors.warningText)),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          'SELECTED PRINTER',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.textSecondary, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.border)),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.print_outlined, color: AppColors.accent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedName ?? 'No printer selected',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary),
                                ),
                              ),
                              if (_selectedAddress != null)
                                GestureDetector(
                                  onTap: _testing ? null : _testPrint,
                                  child: _testing
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                      : Text(
                                          'Test Print',
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                                        ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'PAIRED DEVICES',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.textSecondary, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        if (_devices.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.border)),
                            child: Text('No paired Bluetooth devices found', style: TextStyle(fontSize: 13, color: p.textSecondary)),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.border)),
                            child: Column(
                              children: [
                                for (var i = 0; i < _devices.length; i++)
                                  _DeviceRow(
                                    device: _devices[i],
                                    selected: _devices[i].address == _selectedAddress,
                                    showBottomBorder: i != _devices.length - 1,
                                    onTap: () => _select(_devices[i]),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final BluetoothPrinterDevice device;
  final bool selected;
  final bool showBottomBorder;
  final VoidCallback onTap;

  const _DeviceRow({
    required this.device,
    required this.selected,
    required this.showBottomBorder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: showBottomBorder ? Border(bottom: BorderSide(color: p.divider)) : null,
        ),
        child: Row(
          children: [
            Icon(Icons.bluetooth_rounded, size: 18, color: selected ? AppColors.accent : p.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary)),
                  Text(device.address, style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, size: 20, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
