import 'package:equatable/equatable.dart';

sealed class UnreadSummaryEvent extends Equatable {
  const UnreadSummaryEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the Dashboard opens -- resolves who's signed in and
/// starts watching the right unread source for their role.
class UnreadSummarySubscriptionRequested extends UnreadSummaryEvent {
  const UnreadSummarySubscriptionRequested();
}
