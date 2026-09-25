import 'package:flutter/material.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/customer.dart';
import '../../../core/repositories/customer_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';

/// Full-page "Add Customer" form (2026-09-25) matching a reference
/// design with 4 collapsible section cards -- Personal Details,
/// Address & Delivery, Business & GST, Internal Notes & Tags. Reached
/// only from the Customers screen's own "Add Customer" button (see
/// AppRoutes.addCustomer); the Sales checkout's quick "+ New" customer
/// shortcut deliberately keeps using the smaller, faster
/// `showAddCustomerSheet` bottom sheet instead -- this bigger form is
/// too slow to open mid-sale.
///
/// Only "Personal Details" is real right now: name, mobile, alt
/// mobile and email all save to the Customer record. The other 3
/// sections show in the same card style, with the same status-badge
/// look as the reference design, but expand to a short "coming soon"
/// note instead of real fields -- there's no address/GST/notes data on
/// the Customer model yet (that's a bigger follow-up: new fields on
/// Customer, new Firestore data, and real screens for each).
class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _altMobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _addressExpanded = false;
  bool _businessExpanded = false;
  bool _notesExpanded = false;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Re-render as the person types so the "COMPLETED" badge and the
    // green check marks next to Name/Mobile update live, not just
    // after tapping Save.
    _nameCtrl.addListener(_onPersonalDetailsChanged);
    _mobileCtrl.addListener(_onPersonalDetailsChanged);
  }

  void _onPersonalDetailsChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl.removeListener(_onPersonalDetailsChanged);
    _mobileCtrl.removeListener(_onPersonalDetailsChanged);
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _altMobileCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  bool get _nameValid => _nameCtrl.text.trim().isNotEmpty;
  bool get _mobileValid => RegExp(r'^\d{10}$').hasMatch(_mobileCtrl.text.trim());
  bool get _personalDetailsComplete => _nameValid && _mobileValid;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter the customer name');
      return;
    }
    if (!_mobileValid) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final mobile = _mobileCtrl.text.trim();
    final altMobile = _altMobileCtrl.text.trim();
    try {
      final customer = Customer(
        id: '', // Firestore assigns the real id -- see addCustomer below.
        shopId: currentShopId,
        name: name,
        phone: '+91$mobile',
        altPhone: altMobile.isEmpty ? '' : '+91$altMobile',
        email: _emailCtrl.text.trim(),
      );
      await CustomerRepository().addCustomer(customer);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Customer saved')));
      Navigator.of(context).pop(true);
    } catch (e, st) {
      AppLogger.error('AddCustomerScreen._save', e, st);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save — check your connection and try again";
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
              decoration: BoxDecoration(color: p.background, border: Border(bottom: BorderSide(color: p.border))),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _saving ? null : () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 20, color: p.textPrimary),
                        const SizedBox(width: 14),
                        Text('Add Customer', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _SectionCard(
                    palette: p,
                    icon: Icons.badge_outlined,
                    iconBg: AppColors.iconTint,
                    iconColor: AppColors.accent,
                    title: 'Personal Details',
                    subtitle: 'Primary name, mobile and alternate contacts',
                    badgeText: _personalDetailsComplete ? 'COMPLETED' : null,
                    badgeBg: AppColors.successBg,
                    badgeColor: AppColors.success,
                    expanded: true,
                    onToggle: null, // the only real section -- always open
                    child: _PersonalDetailsFields(
                      palette: p,
                      nameCtrl: _nameCtrl,
                      mobileCtrl: _mobileCtrl,
                      altMobileCtrl: _altMobileCtrl,
                      emailCtrl: _emailCtrl,
                      nameValid: _nameValid,
                      mobileValid: _mobileValid,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    palette: p,
                    icon: Icons.location_on_outlined,
                    iconBg: AppColors.infoBg,
                    iconColor: AppColors.info,
                    title: 'Address & Delivery',
                    subtitle: 'Shipping location & city suggestions',
                    badgeText: 'READY',
                    badgeBg: AppColors.infoBg,
                    badgeColor: AppColors.info,
                    expanded: _addressExpanded,
                    onToggle: () => setState(() => _addressExpanded = !_addressExpanded),
                    child: const _ComingSoonNote(text: "Address and delivery details aren't collected yet — coming soon."),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    palette: p,
                    icon: Icons.receipt_long_outlined,
                    iconBg: AppColors.successBg,
                    iconColor: AppColors.success,
                    title: 'Business & GST',
                    subtitle: 'Tax registration & business classifications',
                    badgeText: 'B2B VERIFIED',
                    badgeBg: AppColors.purpleBg,
                    badgeColor: AppColors.purple,
                    expanded: _businessExpanded,
                    onToggle: () => setState(() => _businessExpanded = !_businessExpanded),
                    child: const _ComingSoonNote(text: "GST and business details aren't collected yet — coming soon."),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    palette: p,
                    icon: Icons.sell_outlined,
                    iconBg: AppColors.warningBg,
                    iconColor: AppColors.warning,
                    title: 'Internal Notes & Tags',
                    subtitle: 'Special pricing, credit limit and tags',
                    badgeText: 'OPTIONAL',
                    badgeBg: p.border,
                    badgeColor: p.textSecondary,
                    expanded: _notesExpanded,
                    onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
                    child: const _ComingSoonNote(text: "Notes, tags and credit limit aren't collected yet — coming soon."),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.border))),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _saving ? null : () => Navigator.pop(context),
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close_rounded, size: 17, color: p.textSecondary),
                            const SizedBox(width: 6),
                            Text('Cancel', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: p.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_rounded, size: 18, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text('Save Customer', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                ],
                              ),
                      ),
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

/// One collapsible card -- icon square, title + status badge, subtitle,
/// and (when [onToggle] is non-null) a chevron that expands/collapses
/// [child]. `onToggle: null` + `expanded: true` (Personal Details) means
/// "not collapsible, always open" rather than a disabled toggle.
class _SectionCard extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color badgeBg;
  final Color badgeColor;
  final bool expanded;
  final VoidCallback? onToggle;
  final Widget child;

  const _SectionCard({
    required this.palette,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeBg,
    required this.badgeColor,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 19, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.textPrimary),
                              ),
                            ),
                            if (badgeText != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  badgeText!,
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: badgeColor, letterSpacing: 0.3),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(subtitle, style: TextStyle(fontSize: 11.5, color: palette.textSecondary)),
                      ],
                    ),
                  ),
                  if (onToggle != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: palette.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: palette.border),
            Padding(padding: const EdgeInsets.all(14), child: child),
          ],
        ],
      ),
    );
  }
}

/// Placeholder body for the 3 not-yet-built sections.
class _ComingSoonNote extends StatelessWidget {
  final String text;
  const _ComingSoonNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        Icon(Icons.hourglass_empty_rounded, size: 16, color: p.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: p.textSecondary))),
      ],
    );
  }
}

class _PersonalDetailsFields extends StatelessWidget {
  final AppPalette palette;
  final TextEditingController nameCtrl;
  final TextEditingController mobileCtrl;
  final TextEditingController altMobileCtrl;
  final TextEditingController emailCtrl;
  final bool nameValid;
  final bool mobileValid;

  const _PersonalDetailsFields({
    required this.palette,
    required this.nameCtrl,
    required this.mobileCtrl,
    required this.altMobileCtrl,
    required this.emailCtrl,
    required this.nameValid,
    required this.mobileValid,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('CUSTOMER NAME', required: true, palette: palette),
        const SizedBox(height: 6),
        _TextBox(
          palette: palette,
          controller: nameCtrl,
          hint: 'Customer name',
          prefixIcon: Icons.person_outline,
          showCheck: nameCtrl.text.trim().isNotEmpty && nameValid,
        ),
        const SizedBox(height: 14),
        _FieldLabel('MOBILE NUMBER', required: true, palette: palette),
        const SizedBox(height: 6),
        _PhoneBox(palette: palette, controller: mobileCtrl, hint: '98765 43210', showCheck: mobileValid),
        const SizedBox(height: 14),
        _FieldLabel('ALT MOBILE', required: false, palette: palette, trailing: 'Optional'),
        const SizedBox(height: 6),
        _PhoneBox(palette: palette, controller: altMobileCtrl, hint: 'e.g. 98123 45670'),
        const SizedBox(height: 14),
        _FieldLabel('EMAIL ADDRESS', required: false, palette: palette, trailing: 'Optional'),
        const SizedBox(height: 6),
        _TextBox(
          palette: palette,
          controller: emailCtrl,
          hint: 'customer@example.com',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  final String? trailing;
  final AppPalette palette;
  const _FieldLabel(this.text, {required this.required, required this.palette, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: palette.textSecondary, letterSpacing: 0.4),
            children: [
              TextSpan(text: text),
              if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Text(trailing!, style: TextStyle(fontSize: 10.5, color: palette.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

/// Plain text field box -- Customer Name and Email Address (no country
/// code prefix, unlike the mobile fields below).
class _TextBox extends StatelessWidget {
  final AppPalette palette;
  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final bool showCheck;

  const _TextBox({
    required this.palette,
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.showCheck = false,
  });

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
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, size: 17, color: palette.textSecondary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF9C9CA6), fontWeight: FontWeight.w400),
              ),
            ),
          ),
          if (showCheck) const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
        ],
      ),
    );
  }
}

/// Mobile Number / Alt Mobile box -- fixed "+91" prefix chip (this app
/// only supports Indian mobile numbers so far, same assumption the
/// ₹-formatted prices elsewhere already make) followed by a 10-digit
/// field. `Customer.phone`/`altPhone` store the full "+91XXXXXXXXXX"
/// string, so the prefix is baked in at save time, not re-derived later.
class _PhoneBox extends StatelessWidget {
  final AppPalette palette;
  final TextEditingController controller;
  final String hint;
  final bool showCheck;

  const _PhoneBox({required this.palette, required this.controller, required this.hint, this.showCheck = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              border: Border(right: BorderSide(color: palette.border)),
            ),
            alignment: Alignment.center,
            child: Text('+91', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textSecondary)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: hint,
                  hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF9C9CA6), fontWeight: FontWeight.w400),
                ),
              ),
            ),
          ),
          if (showCheck)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
            ),
        ],
      ),
    );
  }
}
