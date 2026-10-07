import 'package:flutter/material.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/customer.dart';
import '../../../core/repositories/customer_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';

/// Full-page "Add Customer" form -- a 4-step wizard (Personal -> Location
/// -> Business -> Review), redesigned 2026-10-01 from the original
/// single-scroll-page-of-collapsible-cards version (2026-09-25) after
/// the user shared a reference design built around a step indicator and
/// a final read-only review step. Scoped via AskUserQuestion before
/// rebuilding (all recommended options picked): full 4-step wizard (not
/// just a visual refresh of the old single page); keep exactly the 12
/// fields this app already has (no GPS/map picker, PAN, Trade Name,
/// Credit Limit, Payment Terms, Composition Scheme or Assigned Staff --
/// all present in the reference but not part of this app's data model);
/// add a Review step before Save.
///
/// Reached only from the Customers screen's own "Add Customer" button
/// (see AppRoutes.addCustomer); the Sales checkout's quick "+ New"
/// customer shortcut deliberately keeps using the smaller, faster
/// `showAddCustomerSheet` bottom sheet instead -- this bigger form is
/// too slow to open mid-sale.
///
/// Personal Details (name, mobile) is the only step with hard-required
/// fields -- Location, Business/GST and Notes are entirely optional, so
/// a quick walk-in customer can still be saved with just a name and
/// number. Pincode and GST are format-checked (6 digits / 15-char
/// GSTIN) with an inline warning when filled-but-wrong, but neither
/// blocks moving to the next step -- this is a shop directory, not a
/// tax filing.
///
/// **Required-field message fix (2026-10-01):** previously a missing
/// Name/Mobile only ever showed as a single generic line at the very
/// bottom of the whole page, after tapping Save -- easy to miss, and
/// far from the field it was actually about. Now `_personalAttempted`
/// flips true the first time "Continue to Location" is tapped with
/// Name/Mobile still invalid, and from then on a plain red "required"
/// line appears directly under whichever field is still wrong, updating
/// live as the person types -- same idea as the Pincode/GST format
/// warnings already had, just extended to the two required fields.
class AddCustomerScreen extends StatefulWidget {
  /// When non-null, the form opens pre-filled with this customer's data
  /// and Save updates their existing document instead of creating a new
  /// one -- same "reuse the same form for add vs. edit" pattern Add
  /// Product already uses (`AddProductScreen(product: ...)`), added
  /// 2026-10-06.
  final Customer? customer;

  const AddCustomerScreen({super.key, this.customer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _altMobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();

  final _businessNameCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();

  final _notesCtrl = TextEditingController();

  static const _stepTitles = ['Personal', 'Location', 'Business', 'Review'];

  int _step = 0;
  int _maxStepReached = 0;
  bool _personalAttempted = false;

  bool _saving = false;
  bool _deleting = false;
  String? _error;

  static final _gstinPattern = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

  List<TextEditingController> get _allControllers => [
        _nameCtrl,
        _mobileCtrl,
        _altMobileCtrl,
        _emailCtrl,
        _addressCtrl,
        _cityCtrl,
        _stateCtrl,
        _pincodeCtrl,
        _landmarkCtrl,
        _businessNameCtrl,
        _gstCtrl,
        _notesCtrl,
      ];

  @override
  void initState() {
    super.initState();
    final existing = widget.customer;
    if (existing != null) {
      _nameCtrl.text = existing.name;
      _mobileCtrl.text = _stripCountryCode(existing.phone);
      _altMobileCtrl.text = _stripCountryCode(existing.altPhone);
      _emailCtrl.text = existing.email;
      _addressCtrl.text = existing.address;
      _cityCtrl.text = existing.city;
      _stateCtrl.text = existing.state;
      _pincodeCtrl.text = existing.pincode;
      _landmarkCtrl.text = existing.landmark;
      _businessNameCtrl.text = existing.businessName;
      _gstCtrl.text = existing.gstNumber;
      _notesCtrl.text = existing.notes;
      // An existing customer's data is presumably already valid, so
      // there's no reason to make the person step through Personal ->
      // Location -> Business in order just to fix one field -- every
      // step circle is tappable right away.
      _maxStepReached = 3;
    }
    // Re-render as the person types so the status badges, green check
    // marks, and inline required/format warnings all update live, not
    // just after tapping Continue/Save.
    for (final c in _allControllers) {
      c.addListener(_onFormChanged);
    }
  }

  static String _stripCountryCode(String phone) => phone.startsWith('+91') ? phone.substring(3) : phone;

  void _onFormChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in _allControllers) {
      c.removeListener(_onFormChanged);
      c.dispose();
    }
    super.dispose();
  }

  bool get _nameValid => _nameCtrl.text.trim().isNotEmpty;
  bool get _mobileValid => RegExp(r'^\d{10}$').hasMatch(_mobileCtrl.text.trim());
  bool get _personalDetailsComplete => _nameValid && _mobileValid;

  bool get _pincodeValid => _pincodeCtrl.text.trim().isEmpty || RegExp(r'^\d{6}$').hasMatch(_pincodeCtrl.text.trim());
  bool get _addressAdded =>
      _addressCtrl.text.trim().isNotEmpty && _cityCtrl.text.trim().isNotEmpty && RegExp(r'^\d{6}$').hasMatch(_pincodeCtrl.text.trim());

  bool get _gstValid => _gstCtrl.text.trim().isEmpty || _gstinPattern.hasMatch(_gstCtrl.text.trim().toUpperCase());
  bool get _gstVerified => _gstinPattern.hasMatch(_gstCtrl.text.trim().toUpperCase());

  void _goToStep(int step) {
    if (step < 0 || step > 3 || step > _maxStepReached) return;
    setState(() => _step = step);
  }

  void _continueFromPersonal() {
    if (!_personalDetailsComplete) {
      setState(() => _personalAttempted = true);
      return;
    }
    setState(() {
      _step = 1;
      if (_maxStepReached < 1) _maxStepReached = 1;
    });
  }

  void _continueFromLocation() {
    setState(() {
      _step = 2;
      if (_maxStepReached < 2) _maxStepReached = 2;
    });
  }

  void _continueFromBusiness() {
    setState(() {
      _step = 3;
      if (_maxStepReached < 3) _maxStepReached = 3;
    });
  }

  void _previousStep() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step -= 1);
    }
  }

  Future<void> _save() async {
    // Defensive re-check -- the wizard shouldn't let anyone reach Review
    // with an invalid Personal step, but don't trust that blindly.
    if (!_personalDetailsComplete) {
      setState(() {
        _step = 0;
        _personalAttempted = true;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final mobile = _mobileCtrl.text.trim();
    final altMobile = _altMobileCtrl.text.trim();
    final isEditing = widget.customer != null;
    try {
      final customer = Customer(
        id: widget.customer?.id ?? '', // Firestore assigns the id for a new customer -- see addCustomer below.
        shopId: currentShopId,
        name: _nameCtrl.text.trim(),
        phone: '+91$mobile',
        altPhone: altMobile.isEmpty ? '' : '+91$altMobile',
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        pincode: _pincodeCtrl.text.trim(),
        landmark: _landmarkCtrl.text.trim(),
        businessName: _businessNameCtrl.text.trim(),
        gstNumber: _gstCtrl.text.trim().toUpperCase(),
        notes: _notesCtrl.text.trim(),
      );
      if (isEditing) {
        await CustomerRepository().updateCustomer(customer.id, customer);
      } else {
        await CustomerRepository().addCustomer(customer);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(isEditing ? 'Customer updated' : 'Customer saved')));
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

  Future<void> _confirmDelete() async {
    final customer = widget.customer;
    if (customer == null) return;
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete this customer permanently?',
      message: "This can't be undone. Their past orders stay on record, just no longer linked to a saved customer.",
      confirmLabel: 'Yes, Delete Customer',
      cancelLabel: 'Keep Customer',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await CustomerRepository().deleteCustomer(customer.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Customer deleted')));
      Navigator.of(context).pop(true);
    } catch (e, st) {
      AppLogger.error('AddCustomerScreen._confirmDelete', e, st);
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = "Couldn't delete — check your connection and try again";
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
            _Header(
              palette: p,
              stepIndex: _step,
              stepTitles: _stepTitles,
              saving: _saving || _deleting,
              onBack: _previousStep,
              isEditing: widget.customer != null,
              onDelete: widget.customer != null ? _confirmDelete : null,
            ),
            _StepIndicator(
              palette: p,
              stepTitles: _stepTitles,
              currentStep: _step,
              maxStepReached: _maxStepReached,
              onTap: _goToStep,
            ),
            Expanded(child: _buildStepBody(p)),
            _BottomBar(
              palette: p,
              step: _step,
              saving: _saving || _deleting,
              isEditing: widget.customer != null,
              onPrevious: _previousStep,
              onContinuePersonal: _continueFromPersonal,
              onContinueLocation: _continueFromLocation,
              onContinueBusiness: _continueFromBusiness,
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBody(AppPalette p) {
    switch (_step) {
      case 0:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _SectionHeading(
              palette: p,
              icon: Icons.badge_outlined,
              iconBg: AppColors.iconTint,
              iconColor: AppColors.accent,
              title: 'Personal & Contact Details',
              subtitle: 'Primary name, mobile and alternate contacts',
              badgeText: _personalDetailsComplete ? 'COMPLETED' : null,
              badgeBg: AppColors.successBg,
              badgeColor: AppColors.success,
            ),
            const SizedBox(height: 14),
            _PersonalDetailsFields(
              palette: p,
              nameCtrl: _nameCtrl,
              mobileCtrl: _mobileCtrl,
              altMobileCtrl: _altMobileCtrl,
              emailCtrl: _emailCtrl,
              nameValid: _nameValid,
              mobileValid: _mobileValid,
              nameError: _personalAttempted && !_nameValid ? 'Customer name is required' : null,
              mobileError: _personalAttempted && !_mobileValid ? 'Enter a valid 10-digit mobile number' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ],
        );
      case 1:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _SectionHeading(
              palette: p,
              icon: Icons.location_on_outlined,
              iconBg: AppColors.infoBg,
              iconColor: AppColors.info,
              title: 'Address & Delivery',
              subtitle: 'Shipping location & city suggestions',
              badgeText: _addressAdded ? 'ADDED' : null,
              badgeBg: AppColors.infoBg,
              badgeColor: AppColors.info,
            ),
            const SizedBox(height: 14),
            _AddressFields(
              palette: p,
              addressCtrl: _addressCtrl,
              cityCtrl: _cityCtrl,
              stateCtrl: _stateCtrl,
              pincodeCtrl: _pincodeCtrl,
              landmarkCtrl: _landmarkCtrl,
              pincodeValid: _pincodeValid,
            ),
          ],
        );
      case 2:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _SectionHeading(
              palette: p,
              icon: Icons.receipt_long_outlined,
              iconBg: AppColors.successBg,
              iconColor: AppColors.success,
              title: 'Business & GST',
              subtitle: 'Tax registration & business classification',
              badgeText: _gstVerified ? 'B2B VERIFIED' : null,
              badgeBg: AppColors.purpleBg,
              badgeColor: AppColors.purple,
            ),
            const SizedBox(height: 14),
            _BusinessFields(
              palette: p,
              businessNameCtrl: _businessNameCtrl,
              gstCtrl: _gstCtrl,
              gstValid: _gstValid,
              gstVerified: _gstVerified,
            ),
            const SizedBox(height: 22),
            _SectionHeading(
              palette: p,
              icon: Icons.sell_outlined,
              iconBg: AppColors.warningBg,
              iconColor: AppColors.warning,
              title: 'Internal Notes',
              subtitle: 'Special pricing, credit terms, anything worth remembering',
              badgeText: 'OPTIONAL',
              badgeBg: p.border,
              badgeColor: p.textSecondary,
            ),
            const SizedBox(height: 14),
            _NotesFields(palette: p, notesCtrl: _notesCtrl),
          ],
        );
      case 3:
      default:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _ReviewSection(
              palette: p,
              icon: Icons.badge_outlined,
              iconBg: AppColors.iconTint,
              iconColor: AppColors.accent,
              title: 'Personal Details',
              badgeText: _personalDetailsComplete ? 'COMPLETED' : null,
              badgeBg: AppColors.successBg,
              badgeColor: AppColors.success,
              onEdit: () => _goToStep(0),
              rows: [
                _ReviewRow('Name', _nameCtrl.text.trim()),
                _ReviewRow('Mobile', _mobileCtrl.text.trim().isEmpty ? '' : '+91 ${_mobileCtrl.text.trim()}'),
                _ReviewRow('Alt Mobile', _altMobileCtrl.text.trim().isEmpty ? '' : '+91 ${_altMobileCtrl.text.trim()}'),
                _ReviewRow('Email', _emailCtrl.text.trim()),
              ],
            ),
            const SizedBox(height: 12),
            _ReviewSection(
              palette: p,
              icon: Icons.location_on_outlined,
              iconBg: AppColors.infoBg,
              iconColor: AppColors.info,
              title: 'Address & Delivery',
              badgeText: _addressAdded ? 'ADDED' : null,
              badgeBg: AppColors.infoBg,
              badgeColor: AppColors.info,
              onEdit: () => _goToStep(1),
              rows: [
                _ReviewRow('Address', _addressCtrl.text.trim()),
                _ReviewRow('City', _cityCtrl.text.trim()),
                _ReviewRow('State', _stateCtrl.text.trim()),
                _ReviewRow('Pincode', _pincodeCtrl.text.trim()),
                _ReviewRow('Landmark', _landmarkCtrl.text.trim()),
              ],
            ),
            const SizedBox(height: 12),
            _ReviewSection(
              palette: p,
              icon: Icons.receipt_long_outlined,
              iconBg: AppColors.successBg,
              iconColor: AppColors.success,
              title: 'Business & Notes',
              badgeText: _gstVerified ? 'B2B VERIFIED' : null,
              badgeBg: AppColors.purpleBg,
              badgeColor: AppColors.purple,
              onEdit: () => _goToStep(2),
              rows: [
                _ReviewRow('Business Name', _businessNameCtrl.text.trim()),
                _ReviewRow('GST Number', _gstCtrl.text.trim().toUpperCase()),
                _ReviewRow('Notes', _notesCtrl.text.trim()),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ],
        );
    }
  }
}

/// Header: back arrow (goes to the previous step, or pops the whole
/// screen from step 0) + "Add Customer" title + a small accent caps
/// line underneath ("STEP 2 OF 4: LOCATION") naming the current step.
class _Header extends StatelessWidget {
  final AppPalette palette;
  final int stepIndex;
  final List<String> stepTitles;
  final bool saving;
  final VoidCallback onBack;
  final bool isEditing;
  final VoidCallback? onDelete;

  const _Header({
    required this.palette,
    required this.stepIndex,
    required this.stepTitles,
    required this.saving,
    required this.onBack,
    required this.isEditing,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(color: palette.background, border: Border(bottom: BorderSide(color: palette.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: saving ? null : onBack,
            child: Icon(Icons.arrow_back_rounded, size: 20, color: palette.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit Customer' : 'Add Customer',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: palette.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'STEP ${stepIndex + 1} OF ${stepTitles.length}: ${stepTitles[stepIndex].toUpperCase()}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.accent, letterSpacing: 0.4),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: saving ? null : onDelete,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.danger),
              ),
            ),
        ],
      ),
    );
  }
}

/// The 4-circle progress row -- a done step shows a filled check, the
/// current step shows a filled number, an upcoming step shows an
/// outlined number. Tapping a circle jumps back to that step, but only
/// if it's already been reached (`maxStepReached`) -- no skipping ahead
/// past unfinished steps this way.
class _StepIndicator extends StatelessWidget {
  final AppPalette palette;
  final List<String> stepTitles;
  final int currentStep;
  final int maxStepReached;
  final ValueChanged<int> onTap;

  const _StepIndicator({
    required this.palette,
    required this.stepTitles,
    required this.currentStep,
    required this.maxStepReached,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      color: palette.background,
      child: Row(
        children: [
          for (var i = 0; i < stepTitles.length; i++) ...[
            _StepCircle(
              palette: palette,
              index: i,
              label: stepTitles[i],
              done: i < currentStep,
              current: i == currentStep,
              reachable: i <= maxStepReached,
              onTap: () => onTap(i),
            ),
            if (i != stepTitles.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  color: i < currentStep ? AppColors.accent : palette.border,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final AppPalette palette;
  final int index;
  final String label;
  final bool done;
  final bool current;
  final bool reachable;
  final VoidCallback onTap;

  const _StepCircle({
    required this.palette,
    required this.index,
    required this.label,
    required this.done,
    required this.current,
    required this.reachable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = done || current;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: reachable ? onTap : null,
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppColors.accent : palette.card,
              border: Border.all(color: filled ? AppColors.accent : palette.border, width: 1.5),
            ),
            alignment: Alignment.center,
            child: done
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: current ? Colors.white : palette.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: current ? FontWeight.w800 : FontWeight.w600,
              color: current ? palette.textPrimary : palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Non-collapsible heading row for a step's section -- icon square,
/// title + optional status badge, subtitle. Replaces the old
/// `_SectionCard`'s header now that each step is its own full page
/// rather than a stack of collapsible cards.
class _SectionHeading extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color badgeBg;
  final Color badgeColor;

  const _SectionHeading({
    required this.palette,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeBg,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
                    child: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
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
      ],
    );
  }
}

/// Bottom button row -- varies per step: Cancel + Continue (step 0),
/// Previous + Continue (steps 1-2), Back + Save & Create Customer
/// (step 3, Review).
class _BottomBar extends StatelessWidget {
  final AppPalette palette;
  final int step;
  final bool saving;
  final bool isEditing;
  final VoidCallback onPrevious;
  final VoidCallback onContinuePersonal;
  final VoidCallback onContinueLocation;
  final VoidCallback onContinueBusiness;
  final VoidCallback onSave;

  const _BottomBar({
    required this.palette,
    required this.step,
    required this.saving,
    required this.isEditing,
    required this.onPrevious,
    required this.onContinuePersonal,
    required this.onContinueLocation,
    required this.onContinueBusiness,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    late final String leftLabel;
    late final IconData leftIcon;
    late final String rightLabel;
    late final IconData rightIcon;
    late final VoidCallback? rightOnTap;

    switch (step) {
      case 0:
        leftLabel = 'Cancel';
        leftIcon = Icons.close_rounded;
        rightLabel = 'Continue to Location';
        rightIcon = Icons.arrow_forward_rounded;
        rightOnTap = saving ? null : onContinuePersonal;
        break;
      case 1:
        leftLabel = 'Previous';
        leftIcon = Icons.arrow_back_rounded;
        rightLabel = 'Continue to Business';
        rightIcon = Icons.arrow_forward_rounded;
        rightOnTap = saving ? null : onContinueLocation;
        break;
      case 2:
        leftLabel = 'Previous';
        leftIcon = Icons.arrow_back_rounded;
        rightLabel = 'Continue to Review';
        rightIcon = Icons.arrow_forward_rounded;
        rightOnTap = saving ? null : onContinueBusiness;
        break;
      case 3:
      default:
        leftLabel = 'Back to Business';
        leftIcon = Icons.arrow_back_rounded;
        rightLabel = isEditing ? 'Save Changes' : 'Save & Create Customer';
        rightIcon = Icons.check_rounded;
        rightOnTap = saving ? null : onSave;
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      decoration: BoxDecoration(color: palette.card, border: Border(top: BorderSide(color: palette.border))),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: saving ? null : onPrevious,
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: palette.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: palette.border)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(leftIcon, size: 17, color: palette.textSecondary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        leftLabel,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: rightOnTap,
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              rightLabel,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(rightIcon, size: 17, color: Colors.white),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
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
  final String? nameError;
  final String? mobileError;

  const _PersonalDetailsFields({
    required this.palette,
    required this.nameCtrl,
    required this.mobileCtrl,
    required this.altMobileCtrl,
    required this.emailCtrl,
    required this.nameValid,
    required this.mobileValid,
    this.nameError,
    this.mobileError,
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
        if (nameError != null) ...[
          const SizedBox(height: 5),
          Text(nameError!, style: const TextStyle(fontSize: 11.5, color: AppColors.danger, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 14),
        _FieldLabel('MOBILE NUMBER', required: true, palette: palette),
        const SizedBox(height: 6),
        _PhoneBox(palette: palette, controller: mobileCtrl, hint: '98765 43210', showCheck: mobileValid),
        if (mobileError != null) ...[
          const SizedBox(height: 5),
          Text(mobileError!, style: const TextStyle(fontSize: 11.5, color: AppColors.danger, fontWeight: FontWeight.w600)),
        ],
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

/// Address, City, State, Pincode and Landmark -- all optional, so a
/// quick walk-in customer doesn't need a full address on file. Pincode
/// gets an inline "looks wrong" warning when filled with something
/// other than 6 digits, but it doesn't block moving on.
class _AddressFields extends StatelessWidget {
  final AppPalette palette;
  final TextEditingController addressCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController pincodeCtrl;
  final TextEditingController landmarkCtrl;
  final bool pincodeValid;

  const _AddressFields({
    required this.palette,
    required this.addressCtrl,
    required this.cityCtrl,
    required this.stateCtrl,
    required this.pincodeCtrl,
    required this.landmarkCtrl,
    required this.pincodeValid,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('ADDRESS', required: false, palette: palette, trailing: 'Optional'),
        const SizedBox(height: 6),
        _MultilineTextBox(palette: palette, controller: addressCtrl, hint: 'House/shop no., street, area'),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('CITY', required: false, palette: palette),
                  const SizedBox(height: 6),
                  _TextBox(palette: palette, controller: cityCtrl, hint: 'City'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('STATE', required: false, palette: palette),
                  const SizedBox(height: 6),
                  _TextBox(palette: palette, controller: stateCtrl, hint: 'State'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _FieldLabel('PINCODE', required: false, palette: palette, trailing: 'Optional'),
        const SizedBox(height: 6),
        _TextBox(
          palette: palette,
          controller: pincodeCtrl,
          hint: '6-digit pincode',
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        if (!pincodeValid) ...[
          const SizedBox(height: 5),
          const Text(
            'Enter a valid 6-digit pincode',
            style: TextStyle(fontSize: 11.5, color: AppColors.danger, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 14),
        _FieldLabel('LANDMARK', required: false, palette: palette, trailing: 'Optional'),
        const SizedBox(height: 6),
        _TextBox(palette: palette, controller: landmarkCtrl, hint: 'Nearby landmark'),
      ],
    );
  }
}

/// Business/Firm Name and GSTIN -- both optional. The GSTIN gets a
/// green check and the "B2B VERIFIED" badge only once it matches the
/// real 15-character GSTIN format; an inline warning shows if
/// something's typed that doesn't match, but (like Pincode above) it
/// never blocks moving on.
class _BusinessFields extends StatelessWidget {
  final AppPalette palette;
  final TextEditingController businessNameCtrl;
  final TextEditingController gstCtrl;
  final bool gstValid;
  final bool gstVerified;

  const _BusinessFields({
    required this.palette,
    required this.businessNameCtrl,
    required this.gstCtrl,
    required this.gstValid,
    required this.gstVerified,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('BUSINESS / FIRM NAME', required: false, palette: palette, trailing: 'Optional'),
        const SizedBox(height: 6),
        _TextBox(
          palette: palette,
          controller: businessNameCtrl,
          hint: 'Business name',
          prefixIcon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 14),
        _FieldLabel('GST NUMBER (GSTIN)', required: false, palette: palette, trailing: 'Optional'),
        const SizedBox(height: 6),
        _TextBox(
          palette: palette,
          controller: gstCtrl,
          hint: '22AAAAA0000A1Z5',
          maxLength: 15,
          textCapitalization: TextCapitalization.characters,
          showCheck: gstVerified,
        ),
        if (!gstValid) ...[
          const SizedBox(height: 5),
          const Text(
            'Enter a valid 15-character GSTIN',
            style: TextStyle(fontSize: 11.5, color: AppColors.danger, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

/// Free-text notes only -- no fixed tag list. Staff can jot down
/// anything ("prefers WhatsApp updates", "pays on credit, settle
/// monthly") without needing a pre-defined tag to match it to.
class _NotesFields extends StatelessWidget {
  final AppPalette palette;
  final TextEditingController notesCtrl;

  const _NotesFields({required this.palette, required this.notesCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('NOTES', required: false, palette: palette, trailing: 'Optional'),
        const SizedBox(height: 6),
        _MultilineTextBox(
          palette: palette,
          controller: notesCtrl,
          hint: 'e.g. prefers WhatsApp updates, pays on credit, settle monthly...',
          minLines: 3,
          maxLines: 5,
        ),
      ],
    );
  }
}

/// Step 4 -- one read-only card per section, each row showing what was
/// entered (or "Not provided" in muted italics for a blank optional
/// field). An "Edit" link on the card jumps straight back to that step.
class _ReviewSection extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? badgeText;
  final Color badgeBg;
  final Color badgeColor;
  final VoidCallback onEdit;
  final List<_ReviewRow> rows;

  const _ReviewSection({
    required this.palette,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.badgeText,
    required this.badgeBg,
    required this.badgeColor,
    required this.onEdit,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
              ),
              if (badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    badgeText!,
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: badgeColor, letterSpacing: 0.3),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEdit,
                child: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: palette.border),
          const SizedBox(height: 10),
          for (final row in rows) row.build(palette),
        ],
      ),
    );
  }
}

class _ReviewRow {
  final String label;
  final String value;
  const _ReviewRow(this.label, this.value);

  Widget build(AppPalette palette) {
    final filled = value.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.textSecondary)),
          ),
          Expanded(
            child: Text(
              filled ? value : 'Not provided',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
                fontStyle: filled ? FontStyle.normal : FontStyle.italic,
                color: filled ? palette.textPrimary : palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
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

/// Plain single-line text field box -- Customer Name, Email, City,
/// State, Pincode, Business Name and GST Number all use this (no
/// country-code prefix, unlike the mobile fields below).
class _TextBox extends StatelessWidget {
  final AppPalette palette;
  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final bool showCheck;

  const _TextBox({
    required this.palette,
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
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
              textCapitalization: textCapitalization,
              maxLength: maxLength,
              buildCounter: maxLength != null
                  ? (context, {required currentLength, required isFocused, maxLength}) => null
                  : null,
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

/// Multi-line text box -- Address and Notes. Grows with content
/// between [minLines] and [maxLines] instead of the fixed 48px height
/// the single-line fields use.
class _MultilineTextBox extends StatelessWidget {
  final AppPalette palette;
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;

  const _MultilineTextBox({
    required this.palette,
    required this.controller,
    required this.hint,
    this.minLines = 2,
    this.maxLines = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF9C9CA6), fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}
