import 'package:flutter/material.dart';

import '../../../core/models/app_user.dart';
import '../../../core/repositories/profile_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';

/// Lets whoever's signed in (owner or employee) edit their own display
/// name and phone number -- opened from Profile's account card and its
/// "Edit Profile" row. Saves into `userProfiles/{uid}` via
/// ProfileRepository; the caller (ProfileScreen) is the one that
/// re-requests CurrentUserBloc after this pops, so the new name shows
/// immediately without this screen needing to know about that bloc.
///
/// Deliberately a plain StatefulWidget with a direct repository call,
/// not a full Bloc -- same lightweight shape as
/// set_recovery_email_sheet.dart, since this is just two fields and
/// one save, not something with its own multi-step flow.
class EditProfileScreen extends StatefulWidget {
  final AppUser user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.displayName);
    _phoneCtrl = TextEditingController(text: widget.user.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
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
      await ProfileRepository().saveProfile(uid: widget.user.uid, name: name, phone: phone);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, st) {
      AppLogger.error('EditProfileScreen._save', e, st);
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
                        Text('Edit Profile', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  _Label('Full Name', p, required: true),
                  const SizedBox(height: 7),
                  _Box(
                    p,
                    child: TextField(
                      controller: _nameCtrl,
                      style: TextStyle(fontSize: 14, color: p.textPrimary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'e.g. Ravi Kumar',
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
                  const SizedBox(height: 14),
                  _Label('Email', p, required: false),
                  const SizedBox(height: 7),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: p.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.border),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.user.email,
                      style: TextStyle(fontSize: 14, color: p.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Change this from Profile → Recovery Email instead.',
                    style: TextStyle(fontSize: 11.5, color: p.textSecondary),
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
                onTap: _saving ? null : _save,
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
