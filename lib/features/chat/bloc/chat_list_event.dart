import 'package:equatable/equatable.dart';

sealed class ChatListEvent extends Equatable {
  const ChatListEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the owner's Team Chat screen opens — starts a live
/// subscription to every employee's conversation preview.
class ChatListSubscriptionRequested extends ChatListEvent {
  const ChatListSubscriptionRequested();
}
