import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One row in the `customers` Firestore collection — the shop's own
/// customer directory. Deliberately minimal (name + optional phone/
/// email) rather than a full CRM profile; `phone`/`email` default to
/// '' (not recorded) the same way Sale's `soldByName` does, since a
/// walk-in customer added quickly at checkout may only have a name.
class Customer extends Equatable {
  final String id;
  final String shopId;
  final String name;
  final String phone;
  final String email;
  final DateTime? createdAt;

  const Customer({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone = '',
    this.email = '',
    this.createdAt,
  });

  factory Customer.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return Customer(
      id: id,
      shopId: map['shopId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'name': name,
      'phone': phone,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Same initials logic as ProfileScreen's `_initials` — one or two
  /// uppercase letters for the avatar circle.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  List<Object?> get props => [id, shopId, name, phone, email, createdAt];
}
