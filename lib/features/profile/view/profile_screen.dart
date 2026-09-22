import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/app_user.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../chat/view/chat_list_screen.dart';
import '../../chat/view/conversation_screen.dart';
import '../../theme/bloc/theme_bloc.dart';
import '../../theme/bloc/theme_event.dart';
import '../../theme/bloc/theme_state.dart';
import '../bloc/current_user_bloc.dart';
import '../bloc/current_user_event.dart';
import '../bloc/current_user_state.dart';

/// Profile — matches the CellPoint design canvas (account card, three
/// grouped settings sections, Log Out).
///
/// As of 2026-09-22, this screen shows the **real signed-in person**
/// (owner or a specific employee), not fixed placeholder text — see
/// `CurrentUserBloc`/`CurrentUserRepository`. That's also what decides
/// which menu rows show: only the owner sees Staff Management and the
/// full Team Chat list; an employee sees a single "Chat with Owner"
/// row instead.
///
/// Dark Mode is real: the switch below reads/dispatches to the
/// app-wide `ThemeBloc` (see app.dart), so toggling it here flips
/// `MaterialApp.themeMode` for the whole app. This screen uses the
/// shared `AppPalette` (core/theme/app_palette.dart) for its colors —
/// that's the same helper every other screen now uses too, so the
/// whole app repaints together instead of just this one screen.
///
/// Notifications stays a local, purely-visual toggle — no real
/// notifications system exists yet. Menu rows with no real destination
/// yet reuse the same "coming soon" SnackBar pattern as the login
/// screen's Forgot password/Create account.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CurrentUserBloc()..add(const CurrentUserRequested()),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  bool _notifOn = true;

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature — coming soon')));
  }

  Future<void> _logOut() async {
    // Actually end the Firebase session (previously this just navigated
    // to Login without signing out — harmless day-to-day since signing
    // in again overwrites the session, but not correct logout hygiene).
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final darkOn = context.watch<ThemeBloc>().state.isDark;
    final userState = context.watch<CurrentUserBloc>().state;
    final AppUser? user = userState.user;

    final displayName = user?.displayName ?? '...';
    final roleLabel = user == null ? '' : (user.isOwner ? 'Shop Owner · 4B Mobiles' : 'Staff · 4B Mobiles');

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary)),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _comingSoon('Settings'),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: p.border),
                      ),
                      child: Icon(Icons.settings_outlined, size: 18, color: p.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _comingSoon('Edit Profile'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text(
                                _initials(displayName),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(displayName, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.textPrimary)),
                                  const SizedBox(height: 3),
                                  Text(
                                    roleLabel,
                                    style: TextStyle(fontSize: 12.5, color: p.textSecondary, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, size: 20, color: p.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _MenuSection(
                      palette: p,
                      title: 'ACCOUNT',
                      rows: [
                        _MenuRowData(icon: Icons.person_outline, label: 'Edit Profile', onTap: () => _comingSoon('Edit Profile')),
                        _MenuRowData(icon: Icons.storefront_outlined, label: 'Shop Details', onTap: () => _comingSoon('Shop Details')),
                        // Only the owner manages staff — an employee
                        // account has no reason to see this row.
                        if (user == null || user.isOwner)
                          _MenuRowData(
                            icon: Icons.groups_outlined,
                            label: 'Staff Management',
                            onTap: () => Navigator.of(context).pushNamed(AppRoutes.staffManagement),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _MenuSection(
                      palette: p,
                      title: 'BUSINESS',
                      rows: [
                        _MenuRowData(
                          icon: Icons.bar_chart_rounded,
                          label: 'Reports & Analytics',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.reports),
                        ),
                        _MenuRowData(icon: Icons.credit_card_outlined, label: 'Payment Settings', onTap: () => _comingSoon('Payment Settings')),
                        _MenuRowData(icon: Icons.receipt_long_outlined, label: 'Tax & Invoice Settings', onTap: () => _comingSoon('Tax & Invoice Settings')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Chat — owner sees every employee's conversation,
                    // an employee sees just their own thread with the
                    // owner (skips the list entirely, since there's
                    // only ever one person on the other end for them).
                    _MenuSection(
                      palette: p,
                      title: 'TEAM',
                      rows: [
                        if (user != null && user.isOwner)
                          _MenuRowData(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Team Chat',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ChatListScreen(currentUser: user)),
                            ),
                          ),
                        if (user != null && !user.isOwner)
                          _MenuRowData(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Chat with Owner',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ConversationScreen(
                                  conversationId: user.uid,
                                  title: '4B Mobiles Owner',
                                  currentUser: user,
                                ),
                              ),
                            ),
                          ),
                        if (user == null)
                          _MenuRowData(icon: Icons.chat_bubble_outline_rounded, label: 'Chat', onTap: () => _comingSoon('Chat')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'APP',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.border),
                          ),
                          child: Column(
                            children: [
                              _ToggleRow(
                                palette: p,
                                icon: Icons.notifications_outlined,
                                label: 'Notifications',
                                value: _notifOn,
                                onChanged: (v) => setState(() => _notifOn = v),
                                showBottomBorder: true,
                              ),
                              _ToggleRow(
                                palette: p,
                                icon: p.isDark ? Icons.dark_mode_rounded : Icons.dark_mode_outlined,
                                label: 'Dark Mode',
                                value: darkOn,
                                // Dispatches to the app-wide ThemeBloc instead of
                                // local setState — this is what makes the switch
                                // actually change the app's theme, not just its
                                // own look.
                                onChanged: (_) => context.read<ThemeBloc>().add(const ThemeToggled()),
                                showBottomBorder: true,
                              ),
                              _MenuRow(
                                palette: p,
                                data: _MenuRowData(icon: Icons.help_outline_rounded, label: 'Help Center', onTap: () => _comingSoon('Help Center')),
                                showBottomBorder: false,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _logOut,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.dangerBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
                            SizedBox(width: 12),
                            Text('Log Out', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.profile),
    );
  }
}

class _MenuRowData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuRowData({required this.icon, required this.label, required this.onTap});
}

class _MenuSection extends StatelessWidget {
  final AppPalette palette;
  final String title;
  final List<_MenuRowData> rows;

  const _MenuSection({required this.palette, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: palette.textSecondary)),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                _MenuRow(palette: palette, data: rows[i], showBottomBorder: i != rows.length - 1),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final AppPalette palette;
  final _MenuRowData data;
  final bool showBottomBorder;

  const _MenuRow({required this.palette, required this.data, required this.showBottomBorder});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: data.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: showBottomBorder ? Border(bottom: BorderSide(color: palette.divider)) : null,
        ),
        child: Row(
          children: [
            Icon(data.icon, size: 18, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(child: Text(data.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: palette.textPrimary))),
            Icon(Icons.chevron_right_rounded, size: 15, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showBottomBorder;

  const _ToggleRow({
    required this.palette,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.showBottomBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: showBottomBorder ? Border(bottom: BorderSide(color: palette.divider)) : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: palette.textPrimary))),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 22,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? AppColors.accent : const Color(0xFFD8D8E0),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
