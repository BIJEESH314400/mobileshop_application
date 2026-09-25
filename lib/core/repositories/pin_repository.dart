import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

/// Stores a salted-hash "Quick PIN" per account in its own `pins/{uid}`
/// collection -- deliberately separate from `employees` (which has no
/// document at all for the owner account, see CurrentUserRepository) so
/// both roles use one uniform path.
///
/// The PIN is NEVER a replacement for the real Firebase Auth login --
/// it only re-gates access to a session that's ALREADY signed in (see
/// PinLockGate / PinUnlockScreen), so a salted SHA-256 hash is enough
/// here; nothing sensitive is protected by the PIN on its own, only by
/// Firebase Auth + the Firestore rules that were already built.
class PinRepository {
  final FirebaseFirestore _db;
  PinRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _pins => _db.collection('pins');

  Future<bool> hasPin(String uid) async {
    final doc = await _pins.doc(uid).get();
    return doc.exists;
  }

  Future<void> setPin(String uid, String pin) async {
    final salt = _randomSalt();
    await _pins.doc(uid).set({
      'hash': _hash(pin, salt),
      'salt': salt,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> verifyPin(String uid, String pin) async {
    final doc = await _pins.doc(uid).get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    final salt = data['salt'] as String? ?? '';
    final storedHash = data['hash'] as String? ?? '';
    if (salt.isEmpty || storedHash.isEmpty) return false;
    return _hash(pin, salt) == storedHash;
  }

  Future<void> clearPin(String uid) => _pins.doc(uid).delete();

  String _randomSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hash(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();
}
