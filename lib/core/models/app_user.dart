enum AppRole { owner, employee }

/// Who is actually signed in right now — resolved once per session by
/// CurrentUserRepository from Firebase Auth plus (for employees) their
/// `employees` Firestore document. Profile and Chat both need this to
/// show the right name and decide owner-only vs employee-only UI.
class AppUser {
  final String uid;
  final String username;
  final String displayName;
  final AppRole role;

  /// Whatever Firebase Auth actually has on file as this account's
  /// email right now -- could still be the synthetic
  /// `<username>@4bmobiles.app` placeholder, or a real address once
  /// someone's set/verified one via Profile's Recovery Email flow.
  final String email;

  const AppUser({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.role,
    required this.email,
  });

  bool get isOwner => role == AppRole.owner;

  /// True once [email] is a real address someone can actually read,
  /// not the synthetic placeholder every account starts with -- this
  /// is what Profile's "Recovery Email" row and Forgot Password's
  /// real-world usability both key off.
  bool get hasRecoveryEmail => !email.toLowerCase().endsWith('@4bmobiles.app');
}
