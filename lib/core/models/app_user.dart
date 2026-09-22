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

  const AppUser({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.role,
  });

  bool get isOwner => role == AppRole.owner;
}
