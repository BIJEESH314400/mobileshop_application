import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/services/active_conversation_tracker.dart';
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
bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "Last seen ..." text from the other side's lastReadAt -- today shows
/// just the time, yesterday is called out explicitly, anything older
/// gets a short date. Same relative-date shape as the Dashboard's
/// today/yesterday stat comparison, reused here for a familiar feel.
String _lastSeenText(DateTime lastSeen) {
  final now = DateTime.now();
  final time = DateFormat('h:mm a').format(lastSeen);
  if (_isSameDay(lastSeen, now)) {
    return 'Last seen today at $time';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(lastSeen, yesterday)) {
    return 'Last seen yesterday at $time';
  }
  return 'Last seen ${DateFormat('MMM d').format(lastSeen)} at $time';
}

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
        ..add(const ConversationSubscriptionRequested())
        ..add(const ConversationTypingSubscriptionRequested()),
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
  Timer? _typingIdleTimer;
  bool _lastSentTyping = false;
  late final String _conversationId;

  @override
  void initState() {
    super.initState();
    _conversationId = context.read<ConversationBloc>().conversationId;
    // This chat is now the one on screen -- ChatNotificationWatcher
    // checks this before popping a notification, so a message that
    // arrives while it's already open here doesn't also buzz as one.
    ActiveConversationTracker.openConversationId = _conversationId;
  }

  @override
  void dispose() {
    // Only clear it if it's still pointing at *this* screen -- guards
    // against a stale clear if somehow a second conversation screen
    // was opened before this one finished disposing.
    if (ActiveConversationTracker.openConversationId == _conversationId) {
      ActiveConversationTracker.openConversationId = null;
    }
    _typingIdleTimer?.cancel();
    // Best-effort: let the other side know this side left mid-typing.
    if (_lastSentTyping) {
      context.read<ConversationBloc>().add(const ConversationTypingChanged(false));
    }
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Called on every keystroke. Debounced so it doesn't write to
  // Firestore on every character -- only when typing *starts*, and
  // again after ~3s of no further keystrokes to say it *stopped*.
  void _onTextChanged(String text) {
    _typingIdleTimer?.cancel();
    if (text.trim().isEmpty) {
      _setTyping(false);
      return;
    }
    _setTyping(true);
    _typingIdleTimer = Timer(const Duration(seconds: 3), () => _setTyping(false));
  }

  void _setTyping(bool typing) {
    if (_lastSentTyping == typing) return;
    _lastSentTyping = typing;
    context.read<ConversationBloc>().add(ConversationTypingChanged(typing));
  }

  void _send(BuildContext context) {
    final text = _textCtrl.text;
    if (text.trim().isEmpty) return;
    _typingIdleTimer?.cancel();
    _setTyping(false);
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
                        BlocBuilder<ConversationBloc, ConversationState>(
                          buildWhen: (previous, current) =>
                              previous.otherIsTyping != current.otherIsTyping ||
                              previous.otherLastReadAt != current.otherLastReadAt,
                          builder: (context, state) {
                            // Typing beats last-seen when both are true --
                            // same priority WhatsApp uses. Otherwise, show
                            // "Last seen ..." from the same lastReadAt used
                            // for the blue tick (the last time they had this
                            // chat open) -- nothing at all until they've
                            // opened it for the first time.
                            final subtitle = state.otherIsTyping
                                ? 'Typing...'
                                : (state.otherLastReadAt == null ? null : _lastSeenText(state.otherLastReadAt!));
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.textPrimary)),
                                if (subtitle != null)
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: state.otherIsTyping ? AppColors.accent : p.textSecondary,
                                      fontWeight: state.otherIsTyping ? FontWeight.w600 : FontWeight.w400,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
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
                  if (state.messages.isEmpty && !state.otherIsTyping) {
                    return Center(
                      child: Text(
                        'No messages yet.\nSay hello!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: p.textSecondary, height: 1.5),
                      ),
                    );
                  }
                  final reversed = state.messages.reversed.toList();
                  // The animated typing bubble is inserted as the newest
                  // item (index 0 in this reversed, bottom-anchored list)
                  // whenever the other side is typing -- same idea as
                  // WhatsApp's "..." bubble at the foot of the thread.
                  final showTypingBubble = state.otherIsTyping;
                  final itemCount = reversed.length + (showTypingBubble ? 1 : 0);
                  return ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (showTypingBubble && index == 0) {
                        return _TypingBubble(palette: p);
                      }
                      final m = reversed[showTypingBubble ? index - 1 : index];
                      final isMine = m.senderId == widget.currentUser.uid;
                      return _MessageBubble(
                        message: m,
                        isMine: isMine,
                        palette: p,
                        otherLastReadAt: state.otherLastReadAt,
                      );
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
                        onChanged: _onTextChanged,
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

/// The animated "..." bubble shown in place of a message while the
/// other person is typing -- same left-aligned bordered-card shape as
/// an incoming _MessageBubble, but with 3 pulsing dots instead of text.
class _TypingBubble extends StatefulWidget {
  final AppPalette palette;
  const _TypingBubble({required this.palette});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: widget.palette.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(14),
          ),
          border: Border.all(color: widget.palette.border),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                // Each dot's phase is offset from the next so they pulse
                // in a left-to-right wave rather than all together.
                final t = (_controller.value - (i * 0.2)) % 1.0;
                final bounce = t < 0.5 ? t * 2 : (1 - t) * 2;
                return Container(
                  margin: EdgeInsets.only(right: i == 2 ? 0 : 4),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withOpacity(0.3 + bounce * 0.7),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final AppPalette palette;
  // Only meaningful when isMine -- the other side's last-read
  // timestamp, used to decide the blue "read" double-tick below.
  final DateTime? otherLastReadAt;
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.palette,
    this.otherLastReadAt,
  });

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt == null ? '' : DateFormat('h:mm a').format(message.createdAt!);

    // A message I sent counts as "read" once the other side's
    // lastReadAt is at or after this message's own createdAt --
    // i.e. they've opened the thread at a point in time that
    // included this message.
    final createdAt = message.createdAt;
    final isRead = isMine &&
        createdAt != null &&
        otherLastReadAt != null &&
        !createdAt.isAfter(otherLastReadAt!);

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
            if (time.isNotEmpty || isMine) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (time.isNotEmpty)
                    Text(time, style: TextStyle(fontSize: 10, color: isMine ? Colors.white.withOpacity(0.75) : palette.textSecondary)),
                  // Only ever shown on my own outgoing messages --
                  // same as WhatsApp, an incoming bubble never gets a
                  // tick. Single tick = sent; double blue tick = read.
                  if (isMine) ...[
                    const SizedBox(width: 3),
                    Icon(
                      isRead ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 13,
                      color: isRead ? const Color(0xFF34B7F1) : Colors.white.withOpacity(0.75),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
