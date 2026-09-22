import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';

/// The only place that talks to the `conversations` collection and its
/// `messages` subcollection — same "one repository per collection"
/// pattern as everywhere else in the app.
class ChatRepository {
  final FirebaseFirestore _db;

  ChatRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conversations => _db.collection('conversations');

  /// Owner's Chats list: one row per employee, newest-activity first.
  Stream<List<Conversation>> watchConversations({required String shopId}) {
    return _conversations.where('shopId', isEqualTo: shopId).snapshots().map((snapshot) {
      final conversations = snapshot.docs.map((doc) => Conversation.fromMap(doc.id, doc.data())).toList();
      conversations.sort((a, b) {
        final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return conversations;
    });
  }

  /// Live messages for one conversation, oldest first (natural chat
  /// reading order — the View reverses this for a bottom-anchored list).
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ChatMessage.fromMap(doc.id, doc.data())).toList());
  }

  /// Sends one message and updates the conversation's preview fields
  /// (last message text/time/sender, and an unread flag for whichever
  /// side didn't send it) in the same batch, so the Chats list always
  /// reflects the latest message the instant it's sent.
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderRole,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final conversationRef = _conversations.doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc();

    final batch = _db.batch();
    batch.set(messageRef, {
      'senderId': senderId,
      'senderRole': senderRole,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // set(merge: true) instead of update() — self-heals a missing
    // conversation doc (e.g. an employee created before this chat
    // feature existed) instead of throwing NOT_FOUND.
    batch.set(conversationRef, {
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderRole': senderRole,
      // The sender obviously doesn't need an unread badge for their own
      // message — only flip the *other* side's flag on.
      if (senderRole == 'owner') 'unreadForEmployee': true,
      if (senderRole == 'employee') 'unreadForOwner': true,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Makes sure this employee's conversation doc exists with its
  /// identifying fields set (employeeName/employeeUsername/shopId) —
  /// a safety net for any employee whose account was created before
  /// this chat feature existed (new employees already get this from
  /// EmployeeRepository.addEmployee, so this is a no-op for them:
  /// merge doesn't touch fields that already match). Without this, an
  /// old employee's conversation would never appear in the owner's
  /// Team Chat list, since that list is filtered by `shopId` and a
  /// missing document has no `shopId` to match.
  Future<void> ensureConversationExists({
    required String employeeUid,
    required String employeeName,
    required String employeeUsername,
    required String shopId,
  }) {
    return _conversations.doc(employeeUid).set({
      'employeeName': employeeName,
      'employeeUsername': employeeUsername,
      'shopId': shopId,
    }, SetOptions(merge: true));
  }

  /// Called when a conversation screen opens, so its own unread flag
  /// clears for whichever side just looked at it.
  Future<void> markRead({required String conversationId, required String asRole}) {
    return _conversations.doc(conversationId).set({
      if (asRole == 'owner') 'unreadForOwner': false,
      if (asRole == 'employee') 'unreadForEmployee': false,
    }, SetOptions(merge: true));
  }
}
