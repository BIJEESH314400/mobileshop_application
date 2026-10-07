import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/service_job.dart';

/// The only place in the app that talks to the `serviceJobs` Firestore
/// collection directly -- same one-repository-per-collection
/// convention as every other repository.
class ServiceJobRepository {
  final FirebaseFirestore _db;

  ServiceJobRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _jobs => _db.collection('serviceJobs');

  /// Live feed of every repair job for this shop, newest first.
  /// Client-sorted, same reasoning as every other watchX() in this app
  /// -- avoids needing a composite index alongside the shopId filter.
  Stream<List<ServiceJob>> watchJobs({required String shopId}) {
    return _jobs.where('shopId', isEqualTo: shopId).snapshots().map((snapshot) {
      final jobs = snapshot.docs.map((doc) => ServiceJob.fromMap(doc.id, doc.data())).toList();
      jobs.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime); // newest first
      });
      return jobs;
    });
  }

  /// Creates a new job and returns its Firestore-assigned id. Status
  /// always starts at Pending -- toMap()'s default -- regardless of
  /// what's on `job.status`, since a job is never created pre-advanced.
  Future<String> addJob(ServiceJob job) async {
    final doc = await _jobs.add(job.toMap());
    return doc.id;
  }

  /// Updates a job's own descriptive info (title, device, linked
  /// customer, price, notes) -- deliberately never touches `status` or
  /// `statusChangedAt` (stripped from the write map before it goes out)
  /// so fixing a typo in the device model can never silently move a job
  /// back to Pending or reset its status-age label. Also strips
  /// `createdAt` for the same reason ProductRepository.updateProduct
  /// does -- toMap() always stamps a fresh server timestamp, which
  /// would be correct for a new job but wrong here.
  Future<void> updateJob(String id, ServiceJob job) {
    final map = job.toMap()
      ..remove('createdAt')
      ..remove('status')
      ..remove('statusChangedAt');
    return _jobs.doc(id).update(map);
  }

  /// Moves a job to a new status (Pending -> In Progress -> Ready ->
  /// Completed, picked from the job's own detail sheet) and stamps
  /// `statusChangedAt` so the "Started .../Ready since .../Picked up
  /// ..." label on the job card has a real date to compute from. The
  /// only method in this repository allowed to touch either field.
  Future<void> updateStatus(String id, ServiceJobStatus status) {
    return _jobs.doc(id).update({
      'status': status.storeValue,
      'statusChangedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently removes a job. There's no undo -- the caller is
  /// responsible for confirming with the person first.
  Future<void> deleteJob(String id) {
    return _jobs.doc(id).delete();
  }

  /// Marks a job Picked Up (Completed) and writes the confirmed final
  /// price in the same write -- added 2026-10-06. Deliberately separate
  /// from both `updateJob` and `updateStatus`: the price set when a job
  /// is created/edited is really just an estimate, and the real amount
  /// often isn't settled until the customer is actually standing there
  /// picking the device up, which is exactly when this fires. Stamps a
  /// fresh `statusChangedAt` the same way `updateStatus` does.
  Future<void> completeJob(String id, {required double finalPrice}) {
    return _jobs.doc(id).update({
      'status': ServiceJobStatus.completed.storeValue,
      'statusChangedAt': FieldValue.serverTimestamp(),
      'price': finalPrice,
    });
  }
}
