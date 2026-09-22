import 'package:equatable/equatable.dart';

import '../../../core/models/chat_message.dart';

class ConversationState extends Equatable {
  final bool isLoading;
  final List<ChatMessage> messages;
  final String? errorMessage;

  const ConversationState({
    this.isLoading = true,
    this.messages = const [],
    this.errorMessage,
  });

  ConversationState copyWith({
    bool? isLoading,
    List<ChatMessage>? messages,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ConversationState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, messages, errorMessage];
}
