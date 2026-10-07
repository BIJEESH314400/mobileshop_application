import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// A repair/service job's progress, same 4 stages the Service screen's
/// filter pills have always shown (previously only ever applied to
/// static demo data -- see service_job_repository.dart for the real
/// Firestore-backed version).
enum ServiceJobStatus { pending, inProgress, ready, completed }

extension ServiceJobStatusX on ServiceJobStatus {
  String get label {
    switch (this) {
      case ServiceJobStatus.pending:
        return 'Pending';
      case ServiceJobStatus.inProgress:
        return 'In Progress';
      case ServiceJobStatus.ready:
        return 'Ready';
      case ServiceJobStatus.completed:
        return 'Completed';
    }
  }

  /// Stored in Firestore as the enum's plain name ('pending',
  /// 'inProgress', ...) -- same "store the .name" convention
  /// PaymentMethod/AppRole already use elsewhere in this app.
  String get storeValue => name;

  static ServiceJobStatus fromStoreValue(String? value) {
    return ServiceJobStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ServiceJobStatus.pending,
    );
  }
}

/// One row in the `serviceJobs` Firestore collection -- a repair/service
/// job, optionally linked to a real Customer (same `customerId`/`Name`/
/// `Phone` snapshot-at-link-time shape `Sale` already uses for its own
/// customer link, so an edited customer's details don't retroactively
/// change what an already-created job shows).
class ServiceJob extends Equatable {
  final String id;
  final String shopId;
  final String title;
  final String deviceModel;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final double price;
  final String notes;
  final ServiceJobStatus status;
  final DateTime? createdAt;

  /// When `status` was last changed -- also stamped on creation (so a
  /// brand-new job's "Dropped off"/status-age label has something to
  /// compute from immediately). Never touched by a plain info edit
  /// (title/device/customer/price/notes) -- only
  /// ServiceJobRepository.updateStatus() moves this forward.
  final DateTime? statusChangedAt;

  const ServiceJob({
    required this.id,
    required this.shopId,
    required this.title,
    this.deviceModel = '',
    this.customerId = '',
    this.customerName = '',
    this.customerPhone = '',
    this.price = 0,
    this.notes = '',
    this.status = ServiceJobStatus.pending,
    this.createdAt,
    this.statusChangedAt,
  });

  factory ServiceJob.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    final rawStatusChangedAt = map['statusChangedAt'];
    return ServiceJob(
      id: id,
      shopId: map['shopId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      deviceModel: map['deviceModel'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      customerPhone: map['customerPhone'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String? ?? '',
      status: ServiceJobStatusX.fromStoreValue(map['status'] as String?),
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
      statusChangedAt: rawStatusChangedAt is Timestamp ? rawStatusChangedAt.toDate() : null,
    );
  }

  /// Used by `addJob` as-is (fresh server timestamps for both date
  /// fields). `updateJob`/`updateStatus` in the repository each strip
  /// out whichever of these they don't own -- see their own doc
  /// comments for why.
  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'title': title,
      'deviceModel': deviceModel,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'price': price,
      'notes': notes,
      'status': status.storeValue,
      'createdAt': FieldValue.serverTimestamp(),
      'statusChangedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        shopId,
        title,
        deviceModel,
        customerId,
        customerName,
        customerPhone,
        price,
        notes,
        status,
        createdAt,
        statusChangedAt,
      ];
}
