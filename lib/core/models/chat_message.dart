import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One message inside `conversations/<employeeUid>/messages`.
class ChatMessage extends Equatable {
  final String id;
  final String senderId;
  final String senderRole; // 'owner' | 'employee'
  final String text;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.text,
    this.createdAt,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return ChatMessage(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      senderRole: map['senderRole'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
    );
  }

  @override
  List<Object?> get props => [id, senderId, senderRole, text, createdAt];
}
