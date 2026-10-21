import 'package:cloud_firestore/cloud_firestore.dart';

/// Extra, self-editable profile fields -- just a display-name override
/// and a phone number today -- kept in their own `userProfiles/{uid}`
/// collection rather than inside `employees/{uid}` or anywhere owner-
/// specific. That split matters because of firestore.rules: an
/// employee's `employees/{uid}` doc stays locked to owner-only writes
/// (it carries login-critical fields like username/disabled), and
/// there's no doc for the owner at all today -- `userProfiles` is a
/// single shape either role can read/write for just their OWN uid,
/// limited to these two fields, regardless of role.
///
/// `CurrentUserRepository.loadCurrentUser()` is what actually reads
/// this collection and folds `name`/`phone` into the resolved `AppUser`
/// -- this repository only ever writes it, from Edit Profile.
class ProfileRepository {
  final FirebaseFirestore _db;

  ProfileRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _profiles => _db.collection('userProfiles');

  Future<void> saveProfile({required String uid, required String name, required String phone}) {
    return _profiles.doc(uid).set({
      'name': name.trim(),
      'phone': phone.trim(),
    }, SetOptions(merge: true));
  }
}
