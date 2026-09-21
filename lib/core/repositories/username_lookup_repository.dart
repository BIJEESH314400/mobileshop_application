import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps a login username to the real email address Firebase Auth
/// actually has on file for that account. Needed because the app logs
/// people in by username, but Firebase Auth — and password reset
/// emails — only understand real email addresses. Both Login and
/// Forgot Password use this same lookup, so they can never disagree
/// about which email an account uses.
///
/// Each account needs a `usernames/<username>` document, e.g.
/// `usernames/owner` with a field `email` holding the real address
/// that's also set as that account's email in Firebase Authentication.
class UsernameLookupRepository {
  final FirebaseFirestore _db;

  UsernameLookupRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  /// Returns the real email registered for [username], or null if no
  /// `usernames/<username>` document has been set up yet.
  Future<String?> emailForUsername(String username) async {
    final id = username.trim().toLowerCase();
    if (id.isEmpty) return null;

    final doc = await _db.collection('usernames').doc(id).get();
    if (!doc.exists) return null;

    final email = doc.data()?['email'] as String?;
    return (email == null || email.trim().isEmpty) ? null : email.trim();
  }
}
