import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

/// Works out who is actually signed in: the shop owner, or a specific
/// employee. Firebase Auth only knows a uid/email — this repository is
/// what turns that into "which real person, and what can they do."
///
/// There's no separate `owners` collection (there's only ever one owner
/// account today, created by hand in the Firebase console) — so the
/// rule is simple: if this uid has an `employees/<uid>` document,
/// they're that employee; otherwise they're the owner.
class CurrentUserRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CurrentUserRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  Future<AppUser> loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('No one is signed in');
    }

    final username = user.email!.split('@').first;

    final employeeDoc = await _db.collection('employees').doc(user.uid).get();
    if (employeeDoc.exists) {
      final name = employeeDoc.data()?['name'] as String? ?? username;
      return AppUser(uid: user.uid, username: username, displayName: name, role: AppRole.employee);
    }

    // Not in `employees` -> the owner. There's no stored "real name" for
    // the owner account yet, so the username is shown, capitalized.
    final displayName = username.isEmpty ? 'Owner' : username[0].toUpperCase() + username.substring(1);
    return AppUser(uid: user.uid, username: username, displayName: displayName, role: AppRole.owner);
  }
}
