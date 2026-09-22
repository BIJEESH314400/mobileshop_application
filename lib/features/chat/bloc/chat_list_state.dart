import 'package:equatable/equatable.dart';

import '../../../core/models/conversation.dart';

class ChatListState extends Equatable {
  final bool isLoading;
  final List<Conversation> conversations;
  final String? errorMessage;

  const ChatListState({
    this.isLoading = true,
    this.conversations = const [],
    this.errorMessage,
  });

  ChatListState copyWith({
    bool? isLoading,
    List<Conversation>? conversations,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatListState(
      isLoading: isLoading ?? this.isLoading,
      conversations: conversations ?? this.conversations,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, conversations, errorMessage];
}
