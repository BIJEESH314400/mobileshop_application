import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/payment_settings.dart';
import '../../../core/repositories/payment_settings_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/owner_only_gate.dart';

/// Owner-only: the shop's UPI id + bank account details -- display
/// info only, for showing on receipts/invoices later (see
/// `PaymentSettings`'s own doc comment). Doesn't change what Sales
/// checkout itself offers (still UPI/Card/Cash either way). Reached
/// from Profile -> Payment Settings, which only shows for an owner
/// session, with this screen's `OwnerOnlyGate` wrapper as the real
/// access control either way -- same shape as `ShopDetailsScreen`.
class PaymentSettingsScreen extends StatelessWidget {
  const PaymentSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OwnerOnlyGate(child: _PaymentSettingsView());
  }
}

class _PaymentSettingsView extends StatefulWidget {
  const _PaymentSettingsView();

  @override
  State<_PaymentSettingsView> createState() => _PaymentSettingsViewState();
}

class _PaymentSettingsViewState extends State<_PaymentSettingsView> {
  final _upiCtrl = TextEditingController();
  final _acctNameCtrl = TextEditingController();
  final _acctNumberCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  static final _upiPattern = RegExp(r'^[\w.\-]{2,}@[A-Za-z]{2,}$');
  static final _ifscPattern = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

  @override
  void initState() {
    super.initState();
    _load();
    for (final c in [_upiCtrl, _acctNameCtrl, _acctNumberCtrl, _ifscCtrl, _bankNameCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  Future<void> _load() async {
    try {
      final settings = await PaymentSettingsRepository().getPaymentSettings(currentShopId);
      if (!mounted) return;
      _upiCtrl.text = settings.upiId;
      _acctNameCtrl.text = settings.bankAccountName;
      _acctNumberCtrl.text = settings.bankAccountNumber;
      _ifscCtrl.text = settings.bankIfsc;
      _bankNameCtrl.text = settings.bankName;
    } catch (e, st) {
      AppLogger.error('PaymentSettingsScreen._load', e, st);
      // Fails open to a blank form -- see ShopDetailsScreen's own note.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _upiCtrl.dispose();
    _acctNameCtrl.dispose();
    _acctNumberCtrl.dispose();
    _ifscCtrl.dispose();
    _bankNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PaymentSettingsRepository().savePaymentSettings(
        currentShopId,
        PaymentSettings(
          upiId: _upiCtrl.text.trim(),
          bankAccountName: _acctNameCtrl.text.trim(),
          bankAccountNumber: _acctNumberCtrl.text.trim(),
          bankIfsc: _ifscCtrl.text.trim().toUpperCase(),
          bankName: _bankNameCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Payment settings saved')));
      Navigator.of(context).pop(true);
    } catch (e, st) {
      AppLogger.error('PaymentSettingsScreen._save', e, st);
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
    final upi = _upiCtrl.text.trim();
    final ifsc = _ifscCtrl.text.trim();
    final upiLooksOff = upi.isNotEmpty && !_upiPattern.hasMatch(upi);
    final ifscLooksOff = ifsc.isNotEmpty && !_ifscPattern.hasMatch(ifsc.toUpperCase());

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
                        Text('Payment Settings', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
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
                          'Saved here for showing on receipts/invoices later -- doesn\'t change what Sales checkout offers today.',
                          style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                        ),
                        const SizedBox(height: 18),
                        _Label('UPI ID', p, required: false, trailing: 'Optional'),
                        const SizedBox(height: 7),
                        _Box(
                          p,
                          child: TextField(
                            controller: _upiCtrl,
                            style: TextStyle(fontSize: 14, color: p.textPrimary),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'e.g. 4bmobiles@okaxis',
                              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                            ),
                          ),
                        ),
                        if (upiLooksOff) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Doesn\'t look like a valid UPI ID (e.g. name@bank) -- you can still save it.',
                            style: TextStyle(fontSize: 11, color: AppColors.warningText),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Text('BANK ACCOUNT', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.textSecondary)),
                        const SizedBox(height: 10),
                        _Label('Account Holder Name', p, required: false, trailing: 'Optional'),
                        const SizedBox(height: 7),
                        _Box(
                          p,
                          child: TextField(
                            controller: _acctNameCtrl,
                            style: TextStyle(fontSize: 14, color: p.textPrimary),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'e.g. 4B Mobiles',
                              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Label('Account Number', p, required: false, trailing: 'Optional'),
                        const SizedBox(height: 7),
                        _Box(
                          p,
                          child: TextField(
                            controller: _acctNumberCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: TextStyle(fontSize: 14, color: p.textPrimary),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'e.g. 123456789012',
                              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Label('IFSC Code', p, required: false, trailing: 'Optional'),
                        const SizedBox(height: 7),
                        _Box(
                          p,
                          child: TextField(
                            controller: _ifscCtrl,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 11,
                            style: TextStyle(fontSize: 14, color: p.textPrimary),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              counterText: '',
                              hintText: 'e.g. SBIN0001234',
                              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                            ),
                          ),
                        ),
                        if (ifscLooksOff) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Doesn\'t look like a valid 11-character IFSC code -- you can still save it.',
                            style: TextStyle(fontSize: 11, color: AppColors.warningText),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _Label('Bank Name', p, required: false, trailing: 'Optional'),
                        const SizedBox(height: 7),
                        _Box(
                          p,
                          child: TextField(
                            controller: _bankNameCtrl,
                            style: TextStyle(fontSize: 14, color: p.textPrimary),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'e.g. State Bank of India',
                              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                            ),
                          ),
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
