import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One row in the `conversations` Firestore collection — exactly one
/// per employee (the doc id IS the employee's uid, since chat is
/// strictly owner<->that-one-employee, never employee<->employee).
/// Created automatically the moment an employee account is created
/// (see EmployeeRepository.addEmployee), so it always exists by the
/// time either side opens the chat, even before a first message.
class Conversation extends Equatable {
  final String employeeUid; // == doc id
  final String employeeName;
  final String employeeUsername;
  final String shopId;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderRole; // 'owner' | 'employee' | null (no messages yet)
  final bool unreadForOwner;
  final bool unreadForEmployee;

  const Conversation({
    required this.employeeUid,
    required this.employeeName,
    required this.employeeUsername,
    required this.shopId,
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastSenderRole,
    this.unreadForOwner = false,
    this.unreadForEmployee = false,
  });

  factory Conversation.fromMap(String id, Map<String, dynamic> map) {
    final rawLastMessageAt = map['lastMessageAt'];
    return Conversation(
      employeeUid: id,
      employeeName: map['employeeName'] as String? ?? '',
      employeeUsername: map['employeeUsername'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageAt: rawLastMessageAt is Timestamp ? rawLastMessageAt.toDate() : null,
      lastSenderRole: map['lastSenderRole'] as String?,
      unreadForOwner: map['unreadForOwner'] as bool? ?? false,
      unreadForEmployee: map['unreadForEmployee'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        employeeUid,
        employeeName,
        employeeUsername,
        shopId,
        lastMessage,
        lastMessageAt,
        lastSenderRole,
        unreadForOwner,
        unreadForEmployee,
      ];
}
