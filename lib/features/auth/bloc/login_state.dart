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

  const LoginState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
    this.needsBranchSelection = false,
    this.availableBranches = const [],
  });

  LoginState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
    bool clearError = false,
    bool? needsBranchSelection,
    List<String>? availableBranches,
  }) {
    return LoginState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      needsBranchSelection: needsBranchSelection ?? this.needsBranchSelection,
      availableBranches: availableBranches ?? this.availableBranches,
    );
  }

  @override
  List<Object?> get props =>
      [isSubmitting, isSuccess, errorMessage, needsBranchSelection, availableBranches];
}
