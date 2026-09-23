import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/app_user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../chat/bloc/unread_summary_bloc.dart';
import '../../chat/bloc/unread_summary_state.dart';
import '../../chat/view/conversation_screen.dart';

/// Dedicated full-screen "Notifications" page opened from the
/// Dashboard bell -- replaces the earlier bottom-sheet version
/// (2026-09-23). Reuses the already-built UnreadSummaryBloc for its
/// live data; this screen only adds presentation.
///
/// The bell's onTap pushes this with the SAME UnreadSummaryBloc
/// instance (see dashboard_screen.dart), so it keeps updating live
/// while this screen is open, same as every other pushed screen in
/// this app that shares a Dashboard-owned bloc.
class NotificationsScreen extends StatelessWidget {
  final AppUser? currentUser;
  const NotificationsScreen({super.key, required this.currentUser});

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
                        const SizedBox(width: 14),
                        Text('Notifications', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<UnreadSummaryBloc, UnreadSummaryState>(
                builder: (context, state) {
                  if (state.entries.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(color: AppColors.iconTint, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: const Icon(Icons.notifications_none_rounded, size: 30, color: AppColors.accent),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No notifications',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: p.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "You're all caught up.",
                              style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    itemCount: state.entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = state.entries[index];
                      return GestureDetector(
                        onTap: () {
                          if (currentUser == null) return;
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                              conversationId: entry.conversationId,
                              title: entry.title,
                              currentUser: currentUser!,
                            ),
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(color: AppColors.iconTint, shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: const Icon(Icons.mark_chat_unread_rounded, size: 20, color: AppColors.accent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text.rich(
                                      TextSpan(
                                        style: TextStyle(fontSize: 13.5, height: 1.35, color: p.textPrimary),
                                        children: [
                                          const TextSpan(text: 'You have a message from '),
                                          TextSpan(text: entry.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap to open the chat',
                                      style: TextStyle(fontSize: 11.5, color: p.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(999)),
                                child: Text(
                                  '${entry.count}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
