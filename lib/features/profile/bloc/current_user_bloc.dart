import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/repositories/current_user_repository.dart';
import 'current_user_event.dart';
import 'current_user_state.dart';

class CurrentUserBloc extends Bloc<CurrentUserEvent, CurrentUserState> {
  final CurrentUserRepository _repository;

  CurrentUserBloc({CurrentUserRepository? repository})
      : _repository = repository ?? CurrentUserRepository(),
        super(const CurrentUserState()) {
    on<CurrentUserRequested>(_onRequested);
  }

  Future<void> _onRequested(CurrentUserRequested event, Emitter<CurrentUserState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repository.loadCurrentUser();
      emit(state.copyWith(isLoading: false, user: user, clearError: true));
    } catch (_) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Could not load your account'));
    }
  }
}
