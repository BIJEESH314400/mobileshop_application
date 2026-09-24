import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
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
    on<ConversationTypingSubscriptionRequested>(_onTypingSubscriptionRequested);
    on<ConversationTypingChanged>(_onTypingChanged);
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

    await emit.forEach<List<ChatMessage>>(
      _repository.watchMessages(conversationId),
      // Mark read on every update while this screen is open -- not just
      // once when it first opens. A message that arrives *while* this
      // side is already looking at the thread still needs to clear the
      // unread flag; marking read only at open time left a live-arriving
      // message stuck showing unread back on the list (bold + dot) even
      // though the person was staring right at it.
      onData: (messages) {
        unawaited(_repository.markRead(
          conversationId: conversationId,
          asRole: currentUser.isOwner ? 'owner' : 'employee',
        ));
        return state.copyWith(isLoading: false, messages: messages, clearError: true);
      },
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

  // Runs concurrently alongside _onSubscriptionRequested's emit.forEach
  // above -- separate on<EventType> handlers in the same Bloc can each
  // hold their own long-lived stream subscription at once, so this
  // doesn't block or get blocked by the messages stream.
  Future<void> _onTypingSubscriptionRequested(
    ConversationTypingSubscriptionRequested event,
    Emitter<ConversationState> emit,
  ) async {
    await emit.forEach<Conversation?>(
      _repository.watchConversation(conversationId),
      onData: (conversation) {
        // Watch the *other* side's flag -- an owner cares about
        // typingEmployee, an employee cares about typingOwner. Same
        // stream also carries their lastReadAt, used for the blue
        // read-tick on messages I sent -- no need for a third
        // subscription, this doc already has both fields.
        final otherIsTyping = conversation == null
            ? false
            : (currentUser.isOwner ? conversation.typingEmployee : conversation.typingOwner);
        final otherLastReadAt = conversation == null
            ? null
            : (currentUser.isOwner ? conversation.lastReadAtEmployee : conversation.lastReadAtOwner);
        return state.copyWith(otherIsTyping: otherIsTyping, otherLastReadAt: otherLastReadAt);
      },
      // A typing indicator is cosmetic -- if this stream errors, just
      // silently stop showing it rather than surfacing an error banner
      // over an otherwise-working chat.
      onError: (error, stackTrace) => state.copyWith(otherIsTyping: false),
    );
  }

  Future<void> _onTypingChanged(ConversationTypingChanged event, Emitter<ConversationState> emit) async {
    try {
      await _repository.setTyping(
        conversationId: conversationId,
        asRole: currentUser.isOwner ? 'owner' : 'employee',
        typing: event.isTyping,
      );
    } catch (_) {
      // Cosmetic feature -- a failed typing-flag write shouldn't
      // interrupt the conversation or show an error to the user.
    }
  }
}
