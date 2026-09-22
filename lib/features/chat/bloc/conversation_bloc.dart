import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/repositories/chat_repository.dart';
import 'conversation_event.dart';
import 'conversation_state.dart';

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  final ChatRepository _repository;
  final String conversationId;
  final AppUser currentUser;

  ConversationBloc({
    required this.conversationId,
    required this.currentUser,
    ChatRepository? repository,
  })  : _repository = repository ?? ChatRepository(),
        super(const ConversationState()) {
    on<ConversationSubscriptionRequested>(_onSubscriptionRequested);
    on<ConversationMessageSent>(_onMessageSent);
  }

  Future<void> _onSubscriptionRequested(ConversationSubscriptionRequested event, Emitter<ConversationState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    // An employee opening their own thread is the one path that can
    // reach a conversation the owner's list doesn't know about yet
    // (see ensureConversationExists' doc comment) — self-heal it here.
    if (!currentUser.isOwner) {
      unawaited(_repository.ensureConversationExists(
        employeeUid: currentUser.uid,
        employeeName: currentUser.displayName,
        employeeUsername: currentUser.username,
        shopId: currentShopId,
      ));
    }

    // Mark read as soon as the screen opens — this side has now seen
    // whatever's here, regardless of whether more messages arrive later.
    unawaited(_repository.markRead(
      conversationId: conversationId,
      asRole: currentUser.isOwner ? 'owner' : 'employee',
    ));

    await emit.forEach<List<ChatMessage>>(
      _repository.watchMessages(conversationId),
      onData: (messages) => state.copyWith(isLoading: false, messages: messages, clearError: true),
      onError: (error, stackTrace) => state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load messages. Please check your connection and try again.',
      ),
    );
  }

  Future<void> _onMessageSent(ConversationMessageSent event, Emitter<ConversationState> emit) async {
    if (event.text.trim().isEmpty) return;
    try {
      await _repository.sendMessage(
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderRole: currentUser.isOwner ? 'owner' : 'employee',
        text: event.text,
      );
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Message could not be sent. Please check your connection.'));
    }
  }
}
