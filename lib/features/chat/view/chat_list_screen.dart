import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/conversation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../bloc/chat_list_bloc.dart';
import '../bloc/chat_list_event.dart';
import '../bloc/chat_list_state.dart';
import 'conversation_screen.dart';

/// Owner-only: one row per employee, showing the last message and
/// whether there's something new to read. Tapping a row opens that
/// employee's conversation.
class ChatListScreen extends StatelessWidget {
  final AppUser currentUser;
  const ChatListScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChatListBloc()..add(const ChatListSubscriptionRequested()),
      child: _ChatListView(currentUser: currentUser),
    );
  }
}

class _ChatListView extends StatelessWidget {
  final AppUser currentUser;
  const _ChatListView({required this.currentUser});

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
                        Text('Team Chat', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<ChatListBloc, ChatListState>(
                builder: (context, state) {
                  if (state.isLoading && state.conversations.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.errorMessage != null && state.conversations.isEmpty) {
                    return Center(child: Text(state.errorMessage!, style: TextStyle(color: p.textSecondary)));
                  }
                  if (state.conversations.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No employees to chat with yet.\nAdd an employee first from Staff Management.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, color: p.textSecondary, height: 1.5),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    itemCount: state.conversations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final c = state.conversations[index];
                      return _ConversationRow(
                        conversation: c,
                        palette: p,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                              conversationId: c.employeeUid,
                              title: c.employeeName,
                              currentUser: currentUser,
                            ),
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

class _ConversationRow extends StatelessWidget {
  final Conversation conversation;
  final AppPalette palette;
  final VoidCallback onTap;
  const _ConversationRow({required this.conversation, required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadForOwner;
    // ChatListScreen is owner-only, so the "other side" for every row
    // here is that row's employee.
    final isTyping = conversation.typingEmployee;
    final preview = conversation.lastMessage.isEmpty ? 'No messages yet' : conversation.lastMessage;
    final time = conversation.lastMessageAt == null ? '' : DateFormat('h:mm a').format(conversation.lastMessageAt!);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: AppColors.iconTint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.person_rounded, size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conversation.employeeName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    // While the employee is typing, this replaces the
                    // last-message preview entirely -- same as WhatsApp's
                    // conversation list.
                    isTyping ? 'typing...' : preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isTyping ? AppColors.accent : (hasUnread ? palette.textPrimary : palette.textSecondary),
                      fontWeight: isTyping || hasUnread ? FontWeight.w600 : FontWeight.w400,
                      fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time.isNotEmpty) Text(time, style: TextStyle(fontSize: 11, color: palette.textSecondary)),
                if (hasUnread) ...[
                  const SizedBox(height: 6),
                  Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
