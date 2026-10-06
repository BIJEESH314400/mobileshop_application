import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One row in the `customers` Firestore collection — the shop's own
/// customer directory. Deliberately minimal (name + optional phone/
/// email) rather than a full CRM profile; `phone`/`email` default to
/// '' (not recorded) the same way Sale's `soldByName` does, since a
/// walk-in customer added quickly at checkout may only have a name.
/// Address, Business/GST and Notes fields were added later (2026-10-01)
/// for the full Add Customer page's 3 non-Personal-Details sections --
/// all still default to '' (not recorded) so older customer docs read
/// back fine with no migration.
class Customer extends Equatable {
  final String id;
  final String shopId;
  final String name;
  final String phone;
  final String altPhone;
  final String email;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String landmark;
  final String businessName;
  final String gstNumber;
  final String notes;
  final DateTime? createdAt;

  const Customer({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone = '',
    this.altPhone = '',
    this.email = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.landmark = '',
    this.businessName = '',
    this.gstNumber = '',
    this.notes = '',
    this.createdAt,
  });

  factory Customer.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return Customer(
      id: id,
      shopId: map['shopId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      altPhone: map['altPhone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      address: map['address'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
      pincode: map['pincode'] as String? ?? '',
      landmark: map['landmark'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      gstNumber: map['gstNumber'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'name': name,
      'phone': phone,
      'altPhone': altPhone,
      'email': email,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'landmark': landmark,
      'businessName': businessName,
      'gstNumber': gstNumber,
      'notes': notes,
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
  List<Object?> get props => [
        id,
        shopId,
        name,
        phone,
        altPhone,
        email,
        address,
        city,
        state,
        pincode,
        landmark,
        businessName,
        gstNumber,
        notes,
        createdAt,
      ];
}
