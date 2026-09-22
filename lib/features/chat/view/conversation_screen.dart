import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../bloc/conversation_bloc.dart';
import '../bloc/conversation_event.dart';
import '../bloc/conversation_state.dart';

/// One WhatsApp-style thread — either the owner talking to one specific
/// employee, or an employee talking to the owner. `conversationId` is
/// always the employee's uid (see the Conversation model's doc
/// comment), and `title` is whoever the *other* person is, from this
/// viewer's side.
class ConversationScreen extends StatelessWidget {
  final String conversationId;
  final String title;
  final AppUser currentUser;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    required this.title,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConversationBloc(conversationId: conversationId, currentUser: currentUser)
        ..add(const ConversationSubscriptionRequested()),
      child: _ConversationView(title: title, currentUser: currentUser),
    );
  }
}

class _ConversationView extends StatefulWidget {
  final String title;
  final AppUser currentUser;
  const _ConversationView({required this.title, required this.currentUser});

  @override
  State<_ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<_ConversationView> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send(BuildContext context) {
    final text = _textCtrl.text;
    if (text.trim().isEmpty) return;
    context.read<ConversationBloc>().add(ConversationMessageSent(text));
    _textCtrl.clear();
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
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 20, color: p.textPrimary),
                        const SizedBox(width: 14),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(color: AppColors.iconTint, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: const Icon(Icons.person_rounded, size: 16, color: AppColors.accent),
                        ),
                        const SizedBox(width: 10),
                        Text(widget.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocConsumer<ConversationBloc, ConversationState>(
                listener: (context, state) {
                  if (state.errorMessage != null) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(state.errorMessage!), backgroundColor: AppColors.danger));
                  }
                  // Keep the thread pinned to the newest message as new
                  // ones arrive (list is built oldest-first, reversed).
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollCtrl.hasClients) {
                      _scrollCtrl.jumpTo(0);
                    }
                  });
                },
                builder: (context, state) {
                  if (state.isLoading && state.messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.messages.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages yet.\nSay hello!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: p.textSecondary, height: 1.5),
                      ),
                    );
                  }
                  final reversed = state.messages.reversed.toList();
                  return ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: reversed.length,
                    itemBuilder: (context, index) {
                      final m = reversed[index];
                      final isMine = m.senderId == widget.currentUser.uid;
                      return _MessageBubble(message: m, isMine: isMine, palette: p);
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.border))),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: p.background,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: p.border),
                      ),
                      child: TextField(
                        controller: _textCtrl,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(fontSize: 14, color: p.textPrimary),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                        ),
                        onSubmitted: (_) => _send(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _send(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Icon(Icons.send_rounded, size: 19, color: Colors.white),
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final AppPalette palette;
  const _MessageBubble({required this.message, required this.isMine, required this.palette});

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt == null ? '' : DateFormat('h:mm a').format(message.createdAt!);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppColors.accent : palette.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
          border: isMine ? null : Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(message.text, style: TextStyle(fontSize: 14, height: 1.35, color: isMine ? Colors.white : palette.textPrimary)),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(time, style: TextStyle(fontSize: 10, color: isMine ? Colors.white.withOpacity(0.75) : palette.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}
