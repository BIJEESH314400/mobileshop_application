import 'package:flutter_bloc/flutter_bloc.dart';

import 'splash_event.dart';
import 'splash_state.dart';

/// Same job as the old SplashCubit, now expressed as Bloc:
/// an Event comes in -> `on<Event>` handler runs -> `emit()`s a new State.
class SplashBloc extends Bloc<SplashEvent, AuthStatus> {
  SplashBloc() : super(AuthStatus.checking) {
    on<SplashStarted>(_onStarted);
  }

  Future<void> _onStarted(SplashStarted event, Emitter<AuthStatus> emit) async {
    // TODO: replace with a real stored-token / session check.
    await Future.delayed(const Duration(seconds: 2));
    emit(AuthStatus.unauthenticated);
  }
}
