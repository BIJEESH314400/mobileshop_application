import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../features/chat/view/conversation_screen.dart';
import '../constants/shop_constants.dart';
import '../models/app_user.dart';
import '../models/conversation.dart';
import '../repositories/chat_repository.dart';
import '../repositories/current_user_repository.dart';
import '../routes/root_navigator_key.dart';
import 'active_conversation_tracker.dart';
import 'chat_notification_service.dart';

/// Mounted once, above MaterialApp, for the whole app's lifetime (see
/// app.dart). Whenever someone is signed in, watches Firestore live
/// for new incoming chat messages and shows a local notification for
/// them -- see ChatNotificationService's doc comment for exactly what
/// this can and can't do (it's the free, app-must-be-running path,
/// not true background push).
class ChatNotificationWatcher extends StatefulWidget {
  final Widget child;
  const ChatNotificationWatcher({super.key, required this.child});

  @override
  State<ChatNotificationWatcher> createState() => _ChatNotificationWatcherState();
}

class _ChatNotificationWatcherState extends State<ChatNotificationWatcher> {
  final _chatRepository = ChatRepository();
  final _currentUserRepository = CurrentUserRepository();
  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<Conversation>>? _ownerSub;
  StreamSubscription<Conversation?>? _employeeSub;

  // conversationId -> the lastMessageAt we've already notified for (or
  // seen at startup) -- lets us tell "a genuinely new message just
  // arrived" apart from "the stream just reconnected/re-emitted the
  // same thing".
  final Map<String, DateTime?> _lastSeen = {};

  @override
  void initState() {
    super.initState();
    ChatNotificationService.instance.init(onTap: _openConversationFromNotification);
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    _ownerSub?.cancel();
    _ownerSub = null;
    _employeeSub?.cancel();
    _employeeSub = null;
    _lastSeen.clear();

    if (user == null) return;
    _startWatching();
  }

  Future<void> _startWatching() async {
    final AppUser currentUser;
    try {
      currentUser = await _currentUserRepository.loadCurrentUser();
    } catch (_) {
      // Not fully signed in yet (e.g. mid sign-out/sign-in) -- nothing
      // sensible to watch right now.
      return;
    }
    if (!mounted) return;

    if (currentUser.isOwner) {
      var isFirstSnapshot = true;
      _ownerSub = _chatRepository.watchConversations(shopId: currentShopId).listen((conversations) {
        for (final c in conversations) {
          _maybeNotify(
            conversationId: c.employeeUid,
            title: c.employeeName,
            lastMessage: c.lastMessage,
            lastMessageAt: c.lastMessageAt,
            lastSenderRole: c.lastSenderRole,
            expectedSenderRole: 'employee',
            isFirstSnapshot: isFirstSnapshot,
          );
        }
        isFirstSnapshot = false;
      });
    } else {
      var isFirstSnapshot = true;
      _employeeSub = _chatRepository.watchConversation(currentUser.uid).listen((c) {
        if (c != null) {
          _maybeNotify(
            conversationId: c.employeeUid,
            title: 'Owner',
            lastMessage: c.lastMessage,
            lastMessageAt: c.lastMessageAt,
            lastSenderRole: c.lastSenderRole,
            expectedSenderRole: 'owner',
            isFirstSnapshot: isFirstSnapshot,
          );
        }
        isFirstSnapshot = false;
      });
    }
  }

  void _maybeNotify({
    required String conversationId,
    required String title,
    required String lastMessage,
    required DateTime? lastMessageAt,
    required String? lastSenderRole,
    required String expectedSenderRole,
    required bool isFirstSnapshot,
  }) {
    final previous = _lastSeen[conversationId];
    _lastSeen[conversationId] = lastMessageAt;

    // The very first snapshot of each conversation is just catching up
    // on history that's already there (including on a fresh login) --
    // never a new arrival, so never notify for it.
    if (isFirstSnapshot) return;
    if (lastMessageAt == null) return;
    if (previous != null && !lastMessageAt.isAfter(previous)) return;
    // Only the *other* side's messages should ever trigger a
    // notification -- never notify someone about their own message.
    if (lastSenderRole != expectedSenderRole) return;
    // Don't interrupt with a notification for the exact chat someone's
    // already looking at right now.
    if (ActiveConversationTracker.openConversationId == conversationId) return;

    ChatNotificationService.instance.show(title: title, body: lastMessage, conversationId: conversationId);
  }

  Future<void> _openConversationFromNotification(String conversationId) async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;

    try {
      final currentUser = await _currentUserRepository.loadCurrentUser();
      String title;
      if (currentUser.isOwner) {
        // conversationId is the employee's uid here -- look up their
        // name for the header rather than showing a blank/uid title.
        final doc = await FirebaseFirestore.instance.collection('conversations').doc(conversationId).get();
        title = (doc.data()?['employeeName'] as String?) ?? 'Employee';
      } else {
        title = 'Owner';
      }
      navigator.push(MaterialPageRoute(
        builder: (_) => ConversationScreen(conversationId: conversationId, title: title, currentUser: currentUser),
      ));
    } catch (_) {
      // Not signed in, or the lookup failed -- nothing sensible to
      // open; the notification tap is just silently swallowed.
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _ownerSub?.cancel();
    _employeeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
