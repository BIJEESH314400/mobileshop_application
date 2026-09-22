import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/conversation.dart';
import '../../../core/repositories/chat_repository.dart';
import 'chat_list_event.dart';
import 'chat_list_state.dart';

class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  final ChatRepository _repository;

  ChatListBloc({ChatRepository? repository})
      : _repository = repository ?? ChatRepository(),
        super(const ChatListState()) {
    on<ChatListSubscriptionRequested>(_onSubscriptionRequested);
  }

  Future<void> _onSubscriptionRequested(ChatListSubscriptionRequested event, Emitter<ChatListState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    await emit.forEach<List<Conversation>>(
      _repository.watchConversations(shopId: currentShopId),
      onData: (conversations) => state.copyWith(isLoading: false, conversations: conversations, clearError: true),
      onError: (error, stackTrace) => state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load chats. Please check your connection and try again.',
      ),
    );
  }
}
