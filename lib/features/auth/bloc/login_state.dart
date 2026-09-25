import 'package:equatable/equatable.dart';

/// Unchanged from the Cubit version — State shape doesn't depend on
/// whether a Cubit or a Bloc produces it. This is still just "what the
/// UI needs to render right now."
class LoginState extends Equatable {
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;

  /// True right after a successful username/password check when the
  /// account's login response says it has more than one branch — the
  /// View reacts to this by showing the branch-picker popup instead of
  /// finishing the sign-in immediately. Stays false (no popup) for a
  /// single-branch account.
  final bool needsBranchSelection;

  /// The branches to offer in that popup, straight from the login
  /// response. Empty until `needsBranchSelection` is true.
  final List<String> availableBranches;

  /// True once sign-in has actually succeeded AND this account has a
  /// Quick PIN set -- the View reacts to this by routing through
  /// PinUnlockScreen instead of straight to Dashboard, same as Splash
  /// does for an already-signed-in cold start. Needed because a fresh
  /// username+password login here (e.g. right after reinstalling the
  /// app, which wipes the locally-persisted Firebase session) never
  /// goes through Splash at all, so without this check a Quick PIN
  /// that was set earlier would silently never be asked for again.
  final bool needsPin;

  /// True once sign-in has succeeded and this account has NO Quick PIN
  /// saved yet -- Quick PIN is now a REQUIRED part of signing in, not
  /// an optional extra, so the View reacts to this by routing through
  /// SetPinScreen (mandatory mode) instead of straight to Dashboard.
  /// Mutually exclusive with [needsPin]: every successful login has
  /// exactly one of the two true (an account either already has a PIN
  /// to verify, or needs one set for the first time).
  final bool needsSetPin;

  const LoginState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
    this.needsBranchSelection = false,
    this.availableBranches = const [],
    this.needsPin = false,
    this.needsSetPin = false,
  });

  LoginState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
    bool clearError = false,
    bool? needsBranchSelection,
    List<String>? availableBranches,
    bool? needsPin,
    bool? needsSetPin,
  }) {
    return LoginState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      needsBranchSelection: needsBranchSelection ?? this.needsBranchSelection,
      availableBranches: availableBranches ?? this.availableBranches,
      needsPin: needsPin ?? this.needsPin,
      needsSetPin: needsSetPin ?? this.needsSetPin,
    );
  }

  @override
  List<Object?> get props => [
        isSubmitting,
        isSuccess,
        errorMessage,
        needsBranchSelection,
        availableBranches,
        needsPin,
        needsSetPin,
      ];
}
