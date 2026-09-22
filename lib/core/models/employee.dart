import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One row in the `employees` Firestore collection — a real login
/// account for someone who works at the shop (not the owner). Created
/// only from the owner's "Add Employee" screen; the employee then signs
/// in on the same Login screen as the owner, using this username.
class Employee extends Equatable {
  final String id; // Firebase Auth uid — also used as the doc id
  final String name;
  final String username;
  final String shopId;
  final DateTime? createdAt;

  const Employee({
    required this.id,
    required this.name,
    required this.username,
    required this.shopId,
    this.createdAt,
  });

  factory Employee.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return Employee(
      id: id,
      name: map['name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'username': username,
      'shopId': shopId,
      'role': 'employee',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props => [id, name, username, shopId, createdAt];
}
