import 'package:equatable/equatable.dart';

import '../../../core/models/app_user.dart';

/// One row of the unread breakdown -- one employee's unread count for
/// the owner's view, or the single "Owner" row for an employee's view.
class UnreadEntry extends Equatable {
  final String conversationId;
  final String title;
  final int count;

  const UnreadEntry({required this.conversationId, required this.title, required this.count});

  @override
  List<Object?> get props => [conversationId, title, count];
}

class UnreadSummaryState extends Equatable {
  final bool isLoading;
  final AppUser? currentUser;
  final List<UnreadEntry> entries;

  const UnreadSummaryState({this.isLoading = true, this.currentUser, this.entries = const []});

  /// Drives the notification bell's red dot -- real data now, not the
  /// old hardcoded "always show a dot" placeholder.
  bool get hasUnread => entries.isNotEmpty;

  UnreadSummaryState copyWith({bool? isLoading, AppUser? currentUser, List<UnreadEntry>? entries}) {
    return UnreadSummaryState(
      isLoading: isLoading ?? this.isLoading,
      currentUser: currentUser ?? this.currentUser,
      entries: entries ?? this.entries,
    );
  }

  @override
  List<Object?> get props => [isLoading, currentUser, entries];
}
