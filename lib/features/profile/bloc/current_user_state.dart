import 'package:equatable/equatable.dart';

import '../../../core/models/app_user.dart';

class CurrentUserState extends Equatable {
  final bool isLoading;
  final AppUser? user;
  final String? errorMessage;

  const CurrentUserState({
    this.isLoading = true,
    this.user,
    this.errorMessage,
  });

  CurrentUserState copyWith({
    bool? isLoading,
    AppUser? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CurrentUserState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, user, errorMessage];
}
