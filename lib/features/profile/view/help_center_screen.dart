import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/repositories/shop_details_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';
import '../../chat/view/conversation_screen.dart';

/// Profile -> Help Center. This app has no real support team/ticketing
/// system behind it -- it's a private single-shop tool -- so "help"
/// here means two things: a static FAQ covering the app's own
/// features (written against what's actually built, not generic
/// copy), and a quick way to reach a real person (the shop owner, via
/// the same tap-to-call pattern Customers/Service Jobs already use
/// for the shop's own number from Shop Details, and/or the existing
/// Chat with Owner thread for an employee).
class HelpCenterScreen extends StatelessWidget {
  final AppUser? currentUser;
  const HelpCenterScreen({super.key, this.currentUser});

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
                        Text('Help Center', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
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
                  Text('FREQUENTLY ASKED QUESTIONS', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.textSecondary)),
                  const SizedBox(height: 10),
                  for (final faq in _faqs(isOwner: currentUser?.isOwner ?? true)) _FaqCard(palette: p, question: faq.$1, answer: faq.$2),
                  const SizedBox(height: 24),
                  Text('CONTACT', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.textSecondary)),
                  const SizedBox(height: 10),
                  _ContactSection(palette: p, currentUser: currentUser),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        Text('4B Mobiles', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.textSecondary)),
                        const SizedBox(height: 2),
                        // Kept in sync by hand with pubspec.yaml's `version:` --
                        // low-stakes/cosmetic if it ever drifts, same as every
                        // other static piece of shop/app copy elsewhere in
                        // this app (e.g. receipt headers).
                        Text('App version 0.1.0', style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
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

/// (question, answer) pairs. Written against what's actually built in
/// this app today, not generic placeholder copy -- each answer names
/// the real screen/button a person would actually tap. A couple of
/// answers are owner-only (Add Employee, Forgot Password today only
/// works for the owner account) -- [isOwner] swaps those two entries
/// for an employee-facing version instead of hiding them outright, so
/// an employee still knows who to ask.
List<(String, String)> _faqs({required bool isOwner}) {
  return [
    (
      'How do I make a sale?',
      'Go to the Sales tab, tap "Add Product" to add items to the cart, scan or type each item\'s barcode to confirm it, optionally pick a customer, enter a discount if there is one, choose UPI/Card/Cash, then tap "Complete Sale."',
    ),
    (
      'I forgot my Quick PIN -- what do I do?',
      'On the PIN screen, keep entering until you see "Forgot PIN? Log in with password instead," tap it, then sign in again with your username and password. You\'ll be asked to set a brand new PIN right after.',
    ),
    (
      'Why did the app suddenly ask for my PIN again?',
      'For security on a shared shop counter, the app automatically locks after 5 minutes with no activity and shows the PIN screen. Just enter your PIN to continue -- nothing you were doing is lost.',
    ),
    (
      'How do I add a new product?',
      'From the Products tab, tap the + button in the corner, or from the Home screen\'s Quick Actions, tap "Add Product." Fill in the name, category, brand, price and stock, then save.',
    ),
    (
      'A customer wants something that\'s out of stock -- what do I do?',
      'Tap the bookmark icon on the Home screen header to open "Waiting Customers," then "+ Add Request" to log what they want and their name/phone. You\'ll see it on that list until it\'s marked fulfilled once the item is back in stock.',
    ),
    (
      'How do I track a repair/service job?',
      'Go to the Service tab, tap + to log a new job (device, what needs fixing, price, and optionally the customer), then open the job and move it forward one step at a time -- Start Repair, Mark Ready, then Mark Picked Up.',
    ),
    (
      'How do I remove a product, customer or job I added by mistake?',
      'Open it from its list and look for the trash/delete icon -- on Products, swipe the row left or right instead. You\'ll always see a confirmation before anything is actually deleted.',
    ),
    isOwner
        ? (
            'How do I add a new employee?',
            'Profile -> Staff Management -> Add Employee. This creates their own login (username + password) -- they don\'t need to know yours.',
          )
        : (
            'How do I get a new employee login set up?',
            'Only the shop owner can create staff logins, from Profile -> Staff Management. Ask the owner to add you there.',
          ),
    isOwner
        ? (
            'I forgot my own login password -- what do I do?',
            'On the Login screen, tap "Forgot password?" and follow the reset email sent to your recovery email address (set one from Profile -> Recovery Email if you haven\'t already).',
          )
        : (
            'I forgot my login password -- what do I do?',
            'Password reset isn\'t self-service for staff accounts yet -- ask the shop owner to help you sign back in.',
          ),
  ];
}

class _FaqCard extends StatefulWidget {
  final AppPalette palette;
  final String question;
  final String answer;
  const _FaqCard({required this.palette, required this.question, required this.answer});

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: p.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.answer,
                  style: TextStyle(fontSize: 13, color: p.textSecondary, height: 1.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactSection extends StatefulWidget {
  final AppPalette palette;
  final AppUser? currentUser;
  const _ContactSection({required this.palette, required this.currentUser});

  @override
  State<_ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends State<_ContactSection> {
  String? _shopPhone;
  bool _loadingPhone = true;

  @override
  void initState() {
    super.initState();
    _loadShopPhone();
  }

  Future<void> _loadShopPhone() async {
    try {
      final details = await ShopDetailsRepository().getShopDetails(currentShopId);
      if (!mounted) return;
      setState(() {
        _shopPhone = details.phone.trim().isEmpty ? null : details.phone.trim();
        _loadingPhone = false;
      });
    } catch (e, st) {
      AppLogger.error('HelpCenterScreen._loadShopPhone', e, st);
      // Fails open to "no number on file" -- same as every other
      // best-effort read in this app -- the Chat with Owner button
      // below still works either way for an employee.
      if (!mounted) return;
      setState(() => _loadingPhone = false);
    }
  }

  Future<void> _callShop(BuildContext context) async {
    final phone = _shopPhone;
    if (phone == null) return;
    try {
      await launchUrl(Uri(scheme: 'tel', path: phone));
    } catch (e, st) {
      AppLogger.error('HelpCenterScreen._callShop', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't open the dialer")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final user = widget.currentUser;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Didn't find what you needed above?",
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.textPrimary),
          ),
          const SizedBox(height: 12),
          if (!_loadingPhone && _shopPhone != null)
            _ContactButton(
              palette: p,
              icon: Icons.call_rounded,
              label: 'Call Shop ($_shopPhone)',
              onTap: () => _callShop(context),
            ),
          if (!_loadingPhone && _shopPhone != null && user != null && !user.isOwner) const SizedBox(height: 10),
          if (user != null && !user.isOwner)
            _ContactButton(
              palette: p,
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
          if (_loadingPhone)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (!_loadingPhone && _shopPhone == null && (user == null || user.isOwner))
            Text(
              'No shop phone number on file yet -- add one from Profile -> Shop Details so this button can show here.',
              style: TextStyle(fontSize: 12, color: p.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ContactButton({required this.palette, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.accent))),
            Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
