import 'package:equatable/equatable.dart';

/// The shop's own business info (not any one person's) — name,
/// address, phone — stored once per shop under `shopDetails/{shopId}`.
/// Deliberately separate from `AppUser`/`userProfiles` (which is
/// per-signed-in-person) and from the hardcoded "4B Mobiles" branding
/// text sprinkled through the app's own UI/splash/PDF headers today —
/// this is the shop's real business details, editable by the owner
/// from Profile → Shop Details.
///
/// Every field defaults to `''` so a shop that hasn't filled this in
/// yet just reads back blank rather than crashing or guessing.
class ShopDetails extends Equatable {
  final String name;
  final String address;
  final String phone;

  // Exact pinned location from "Pick on Map", added 2026-10-19 --
  // null means the address above was only ever typed, never pinned
  // on the map (every shop before this feature, and still an
  // option today since the map picker is optional, not required).
  final double? latitude;
  final double? longitude;

  const ShopDetails({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.latitude,
    this.longitude,
  });

  bool get hasPinnedLocation => latitude != null && longitude != null;

  factory ShopDetails.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ShopDetails();
    return ShopDetails(
      name: map['name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  List<Object?> get props => [name, address, phone, latitude, longitude];
}
