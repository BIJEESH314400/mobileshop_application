import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/tax_invoice_settings.dart';
import '../../../core/repositories/tax_invoice_settings_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/owner_only_gate.dart';
import '../../../core/widgets/voice_note_field.dart';

/// Owner-only: the shop's GSTIN + the GST rate actually used at Sales
/// checkout, plus an optional invoice prefix/footer note -- same
/// shape as `ShopDetailsScreen`/`PaymentSettingsScreen`, but the tax
/// rate here is live, not display-only: saving it is what
/// `SalesBloc._onSubscriptionRequested` reads to replace the 18% that
/// used to be hardcoded in `SalesState.taxRate`. GSTIN/prefix/note are
/// still display-only for now (not yet printed on receipts/reports).
/// Reached from Profile -> Tax & Invoice Settings, which only shows
/// for an owner session, with this screen's `OwnerOnlyGate` wrapper as
/// the real access control either way.
class TaxInvoiceSettingsScreen extends StatelessWidget {
  const TaxInvoiceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OwnerOnlyGate(child: _TaxInvoiceSettingsView());
  }
}

class _TaxInvoiceSettingsView extends StatefulWidget {
  const _TaxInvoiceSettingsView();

  @override
  State<_TaxInvoiceSettingsView> createState() => _TaxInvoiceSettingsViewState();
}

class _TaxInvoiceSettingsViewState extends State<_TaxInvoiceSettingsView> {
  final _gstinCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();
  final _noteCtrl = LanguageTaggedTextController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  // 2-digit state code + 10-char PAN + 1 entity code + 'Z' + 1 checksum
  // char -- the standard 15-character Indian GSTIN shape. Soft check
  // only, same spirit as PaymentSettingsScreen's UPI/IFSC patterns --
  // a shop can still save something that doesn't match.
  static final _gstinPattern = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');

  @override
  void initState() {
    super.initState();
    _load();
    for (final c in [_gstinCtrl, _taxRateCtrl, _prefixCtrl, _noteCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  Future<void> _load() async {
    try {
      final settings = await TaxInvoiceSettingsRepository().getTaxInvoiceSettings(currentShopId);
      if (!mounted) return;
      _gstinCtrl.text = settings.gstin;
      _taxRateCtrl.text = _formatRate(settings.taxRatePercent);
      _prefixCtrl.text = settings.invoicePrefix;
      _noteCtrl.text = settings.invoiceNote;
    } catch (e, st) {
      AppLogger.error('TaxInvoiceSettingsScreen._load', e, st);
      // Fails open to a blank form -- see ShopDetailsScreen's own note.
      // The tax rate field still falls back to the usual 18% default
      // (TaxInvoiceSettings()'s own default) rather than showing blank,
      // so Save here can't accidentally wipe checkout's tax rate just
      // because this one load hiccuped.
      _taxRateCtrl.text = _formatRate(const TaxInvoiceSettings().taxRatePercent);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatRate(double rate) {
    return rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toString();
  }

  @override
  void dispose() {
    _gstinCtrl.dispose();
    _taxRateCtrl.dispose();
    _prefixCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rate = double.tryParse(_taxRateCtrl.text.trim());
    if (rate == null || rate < 0 || rate > 100) {
      setState(() => _error = 'Enter a valid GST rate between 0 and 100');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await TaxInvoiceSettingsRepository().saveTaxInvoiceSettings(
        currentShopId,
        TaxInvoiceSettings(
          gstin: _gstinCtrl.text.trim().toUpperCase(),
          taxRatePercent: rate,
          invoicePrefix: _prefixCtrl.text.trim(),
          invoiceNote: _noteCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Tax & invoice settings saved')));
      Navigator.of(context).pop(true);
    } catch (e, st) {
      AppLogger.error('TaxInvoiceSettingsScreen._save', e, st);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save -- check your connection and try again";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final gstin = _gstinCtrl.text.trim().toUpperCase();
    final gstinLooksOff = gstin.isNotEmpty && !_gstinPattern.hasMatch(gstin);

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              decoration: BoxDecoration(
                color: p.background,
                border: Border(bottom: BorderSide(color: p.border)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 20, color: p.textPrimary),
                        const SizedBox(width: 14),
                        Text('Tax & Invoice Settings', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      children: [
                        Text(
                          'The GST rate below is what Sales checkout actually uses on the next sale. GSTIN, invoice prefix and footer note are saved for showing on receipts/invoices later.',
                          style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                        ),
                        const SizedBox(height: 18),
                        _Label('GSTIN', p, required: false, trailing: 'Optional'),
                        const SizedBox(height: 7),
                        _Box(
                          p,
                          child: TextField(
                            controller: _gstinCtrl,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 15,
                            style: TextStyle(fontSize: 14, color: p.textPrimary),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              counterText: '',
                              hintText: 'e.g. 32AAAAA0000A1Z5',
                              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                            ),
                          ),
                        ),
                        if (gstinLooksOff) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Doesn\'t look like a valid 15-character GSTIN -- you can still save it.',
                            style: TextStyle(fontSize: 11, color: AppColors.warningText),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Text('GST RATE', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.textSecondary)),
                        const SizedBox(height: 10),
                        _Label('Tax Rate (%)', p, required: true),
                        const SizedBox(height: 7),
                        _Box(
                          p,
                          child: TextField(
                            controller: _taxRateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}\.?\d{0,2}'))],
                            style: TextStyle(fontSize: 14, color: p.textPrimary),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'e.g. 18',
                              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Applies to every sale rung up after you save -- past sales/receipts keep whatever rate they were made at.',
                          style: TextStyle(fontSize: 11, color: p.textSecondary),
                        ),
                        const SizedBox(height: 18),
                        Text('INVOICE', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.textSecondary)),
                        const SizedBox(height: 10),
                        _Label('Invoice Prefix', p, required: false, trailing: 'Optional'),
                        const SizedBox(height: 7),
                        _Box(
                          p,
                          child: TextField(
                            controller: _prefixCtrl,
                            textCapitalization: TextCapitalization.characters,
                            style: TextStyle(fontSize: 14, color: p.textPrimary),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'e.g. INV',
                              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Label('Invoice Footer Note', p, required: false, trailing: 'Optional'),
                        const SizedBox(height: 7),
                        VoiceNoteFieldBody(
                          controller: _noteCtrl,
                          maxLines: 3,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          textStyle: TextStyle(fontSize: 14, color: p.textPrimary),
                          hintText: 'e.g. Goods once sold will not be taken back.',
                          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(_error!, style: const TextStyle(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: p.card,
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: GestureDetector(
                onTap: (_saving || _loading) ? null : _save,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final AppPalette palette;
  final bool required;
  final String? trailing;
  const _Label(this.text, this.palette, {this.required = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.textPrimary),
            children: [
              TextSpan(text: text),
              if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: TextStyle(fontSize: 11, color: palette.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  final AppPalette palette;
  final Widget child;
  const _Box(this.palette, {required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}
