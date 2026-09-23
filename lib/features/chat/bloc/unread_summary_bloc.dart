import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/conversation.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/repositories/current_user_repository.dart';
import 'unread_summary_event.dart';
import 'unread_summary_state.dart';

/// Powers the Dashboard's notification bell: a live, per-person
/// breakdown of unread chat messages -- one row per employee for the
/// owner, or a single "Owner" row for an employee -- so tapping the
/// bell shows who has how many unread, not just a single dot meaning
/// "something, somewhere, is unread".
class UnreadSummaryBloc extends Bloc<UnreadSummaryEvent, UnreadSummaryState> {
  final ChatRepository _chatRepository;
  final CurrentUserRepository _currentUserRepository;

  UnreadSummaryBloc({ChatRepository? chatRepository, CurrentUserRepository? currentUserRepository})
      : _chatRepository = chatRepository ?? ChatRepository(),
        _currentUserRepository = currentUserRepository ?? CurrentUserRepository(),
        super(const UnreadSummaryState()) {
    on<UnreadSummarySubscriptionRequested>(_onSubscriptionRequested);
  }

  Future<void> _onSubscriptionRequested(UnreadSummarySubscriptionRequested event, Emitter<UnreadSummaryState> emit) async {
    final AppUser currentUser;
    try {
      currentUser = await _currentUserRepository.loadCurrentUser();
    } catch (_) {
      // Not signed in (shouldn't normally happen on Dashboard) -- just
      // show no unread rather than an error state over the home screen.
      emit(state.copyWith(isLoading: false));
      return;
    }
    emit(state.copyWith(currentUser: currentUser));

    if (currentUser.isOwner) {
      await emit.forEach<List<Conversation>>(
        _chatRepository.watchConversations(shopId: currentShopId),
        onData: (conversations) {
          final entries = conversations.where((c) => c.unreadCountOwner > 0).map((c) {
            return UnreadEntry(conversationId: c.employeeUid, title: c.employeeName, count: c.unreadCountOwner);
          }).toList()
            ..sort((a, b) => b.count.compareTo(a.count));
          return state.copyWith(isLoading: false, entries: entries);
        },
      );
    } else {
      await emit.forEach<Conversation?>(
        _chatRepository.watchConversation(currentUser.uid),
        onData: (c) {
          final entries = (c != null && c.unreadCountEmployee > 0)
              ? [UnreadEntry(conversationId: c.employeeUid, title: 'Owner', count: c.unreadCountEmployee)]
              : const <UnreadEntry>[];
          return state.copyWith(isLoading: false, entries: entries);
        },
      );
    }
  }
}
