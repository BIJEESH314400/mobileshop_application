import 'package:cloud_firestore/cloud_firestore.dart';

/// Backs the small growable lists used by pickers — today `categories`
/// and `brands`. Each is just a Firestore collection of documents
/// shaped like `{ name: "Smartphones" }`; this class doesn't care which
/// collection it's pointed at, so the same code serves both lists
/// instead of writing near-duplicate Category/Brand repositories.
class LookupRepository {
  final FirebaseFirestore _db;

  LookupRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  /// A live, alphabetically-sorted list of names in [collection] — used
  /// to fill a picker and to instantly show a name someone just added,
  /// without needing to close and reopen the picker.
  Stream<List<String>> watchNames(String collection) {
    return _db.collection(collection).orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.data()['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList(),
        );
  }

  /// Adds a new name to [collection], unless one already exists with
  /// the same text (checked case-insensitively client-side, since
  /// Firestore queries are always case-sensitive) — avoids ending up
  /// with both "Apple" and "apple" as separate brands from a typo.
  Future<void> addName(String collection, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final existing = await _db.collection(collection).get();
    final alreadyThere = existing.docs.any(
      (doc) => (doc.data()['name'] as String? ?? '').toLowerCase() == trimmed.toLowerCase(),
    );
    if (alreadyThere) return;

    await _db.collection(collection).add({
      'name': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
