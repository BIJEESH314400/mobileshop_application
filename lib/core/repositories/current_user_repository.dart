import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../utils/app_logger.dart';
import 'username_lookup_repository.dart';

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
  final UsernameLookupRepository _usernames;

  CurrentUserRepository({FirebaseAuth? auth, FirebaseFirestore? firestore, UsernameLookupRepository? usernames})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _usernames = usernames ?? UsernameLookupRepository(firestore: firestore);

  Future<AppUser> loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('No one is signed in');
    }

    // Refresh from Firebase's servers before reading `email` — this is
    // the one chance to notice someone verified a new Recovery Email
    // (via Profile's `verifyBeforeUpdateEmail` flow) since this device
    // last saw it. Best-effort: a failed reload just means we fall
    // back to whatever's already cached locally, same as before this
    // field existed. Deliberately re-reads `_auth.currentUser?.email`
    // afterward rather than reassigning `user` itself -- keeps `user`
    // a plain non-nullable local the whole way through, no extra null
    // checks needed on `user.uid` below.
    try {
      await user.reload();
    } catch (e, st) {
      AppLogger.error('CurrentUserRepository.loadCurrentUser (reload)', e, st);
    }
    final email = _auth.currentUser?.email ?? user.email ?? '';

    final employeeDoc = await _db.collection('employees').doc(user.uid).get();
    final AppUser result;
    if (employeeDoc.exists) {
      // Read the real stored username field instead of deriving it
      // from the email's local part — deriving from email broke the
      // moment an employee's real Firebase Auth email stopped looking
      // like `<username>@4bmobiles.app` (exactly what Recovery Email
      // now lets happen). The stored field is the actual login
      // username regardless of what the account's email currently is.
      final data = employeeDoc.data();
      final username = data?['username'] as String? ?? email.split('@').first;
      final name = data?['name'] as String? ?? username;
      result = AppUser(uid: user.uid, username: username, displayName: name, role: AppRole.employee, email: email);
    } else {
      // Not in `employees` -> the owner. Only one owner account exists
      // today and it always logs in as `owner` — hardcoded rather than
      // derived from the email for the same reason as above: once the
      // owner's email is a real personal address, its local part has
      // no relation to their actual login username anymore.
      result = AppUser(uid: user.uid, username: 'owner', displayName: 'Owner', role: AppRole.owner, email: email);
    }

    // Self-heal `usernames/<username>` if Firebase Auth's real email
    // has drifted away from whatever this doc currently says — the
    // only way the app finds out a verifyBeforeUpdateEmail link got
    // clicked, since Firebase gives no callback for that. Keeps Login
    // and Forgot Password (both of which resolve a username through
    // this same collection) pointed at the account's real, current
    // email. Best-effort and silent: a failed write here just means
    // the next successful load tries again.
    if (email.isNotEmpty) {
      try {
        final stored = await _usernames.emailForUsername(result.username);
        if (stored != email) {
          await _usernames.setEmailForUsername(result.username, email);
        }
      } catch (e, st) {
        AppLogger.error('CurrentUserRepository.loadCurrentUser (usernames sync)', e, st);
      }
    }

    return result;
  }
}
