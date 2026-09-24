import 'package:equatable/equatable.dart';

import '../../../core/models/chat_message.dart';

class ConversationState extends Equatable {
  final bool isLoading;
  final List<ChatMessage> messages;
  final String? errorMessage;
  final bool otherIsTyping;
  // The other side's last-read timestamp -- a message I sent is shown
  // as "read" (blue double-tick) once its createdAt is at or before
  // this. Null until they've opened the thread at least once.
  final DateTime? otherLastReadAt;

  const ConversationState({
    this.isLoading = true,
    this.messages = const [],
    this.errorMessage,
    this.otherIsTyping = false,
    this.otherLastReadAt,
  });

  ConversationState copyWith({
    bool? isLoading,
    List<ChatMessage>? messages,
    String? errorMessage,
    bool clearError = false,
    bool? otherIsTyping,
    DateTime? otherLastReadAt,
  }) {
    return ConversationState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      otherIsTyping: otherIsTyping ?? this.otherIsTyping,
      otherLastReadAt: otherLastReadAt ?? this.otherLastReadAt,
    );
  }

  @override
  List<Object?> get props => [isLoading, messages, errorMessage, otherIsTyping, otherLastReadAt];
}
