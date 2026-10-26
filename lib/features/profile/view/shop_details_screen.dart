import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/shop_details.dart';
import '../../../core/repositories/shop_details_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/owner_only_gate.dart';
import 'pick_shop_location_screen.dart';

/// Owner-only: the shop's own business info (name/address/phone), not
/// any one signed-in person's — see `ShopDetails`'s own doc comment
/// for why this is a separate collection from Edit Profile's
/// `userProfiles`. Reached from Profile → Shop Details, which only
/// shows for an owner session in the menu, with this screen's
/// `OwnerOnlyGate` wrapper as the real access control either way.
class ShopDetailsScreen extends StatelessWidget {
  const ShopDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OwnerOnlyGate(child: _ShopDetailsView());
  }
}

class _ShopDetailsView extends StatefulWidget {
  const _ShopDetailsView();

  @override
  State<_ShopDetailsView> createState() => _ShopDetailsViewState();
}

class _ShopDetailsViewState extends State<_ShopDetailsView> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final details = await ShopDetailsRepository().getShopDetails(currentShopId);
      if (!mounted) return;
      _nameCtrl.text = details.name;
      _addressCtrl.text = details.address;
      _phoneCtrl.text = details.phone;
      _lat = details.latitude;
      _lng = details.longitude;
    } catch (e, st) {
      AppLogger.error('ShopDetailsScreen._load', e, st);
      // Fails open to a blank form rather than stranding the owner on
      // a spinner — worst case they re-type details that were already
      // there, not a security concern like OwnerOnlyGate's own check.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickOnMap() async {
    final initial = (_lat != null && _lng != null) ? LatLng(_lat!, _lng!) : null;
    final result = await Navigator.of(context).push<PickedShopLocation>(
      MaterialPageRoute(builder: (_) => PickShopLocationScreen(initialLatLng: initial)),
    );
    if (result == null || !mounted) return;
    setState(() {
      _lat = result.latitude;
      _lng = result.longitude;
      if (result.address.isNotEmpty) _addressCtrl.text = result.address;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Shop name is required');
      return;
    }
    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty && !RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 10-digit phone number, or leave it blank');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ShopDetailsRepository().saveShopDetails(
        currentShopId,
        ShopDetails(
          name: name,
          address: _addressCtrl.text.trim(),
          phone: phone,
          latitude: _lat,
          longitude: _lng,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Shop details saved')));
      Navigator.of(context).pop(true);
    } catch (e, st) {
      AppLogger.error('ShopDetailsScreen._save', e, st);
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
                        Text('Shop Details', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
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
                          'This is your shop\'s own business info, not your personal profile — shown on receipts and reports.',
                          style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                        ),
                        const SizedBox(height: 18),
                        _Label('Shop Name', p, required: true),
                        const SizedBox(height: 7),
                        _Box(
                          p,
                          child: TextField(
                            controller: _nameCtrl,
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
                        _Label('Address', p, required: false, trailing: 'Optional'),
                        const SizedBox(height: 7),
                        GestureDetector(
                          onTap: _pickOnMap,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_pin, size: 15, color: AppColors.accent),
                              const SizedBox(width: 4),
                              Text(
                                (_lat != null && _lng != null) ? 'Exact location pinned -- tap to change' : 'Pick on Map',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: p.border),
                          ),
                          child: TextField(
                            controller: _addressCtrl,
                            maxLines: 3,
                            minLines: 2,
                            style: TextStyle(fontSize: 14, color: p.textPrimary),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'Shop address, city, state, pincode',
                              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Label('Phone Number', p, required: false, trailing: 'Optional'),
                        const SizedBox(height: 7),
                        _Box(
                          p,
                          child: TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            style: TextStyle(fontSize: 14, color: p.textPrimary),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              counterText: '',
                              hintText: 'e.g. 9876543210',
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
