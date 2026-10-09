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

  /// Writes/overwrites the real email registered for [username] --
  /// used by `CurrentUserRepository`'s self-healing check to keep this
  /// collection in sync once Firebase Auth's own email for an account
  /// actually changes (e.g. after someone verifies a new recovery
  /// email via `verifyBeforeUpdateEmail`). `merge: true` so it never
  /// disturbs any other field a future addition might put on this doc.
  Future<void> setEmailForUsername(String username, String email) async {
    final id = username.trim().toLowerCase();
    final cleanEmail = email.trim();
    if (id.isEmpty || cleanEmail.isEmpty) return;
    await _db.collection('usernames').doc(id).set({'email': cleanEmail}, SetOptions(merge: true));
  }
}
