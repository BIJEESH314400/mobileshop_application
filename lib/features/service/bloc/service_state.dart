import 'package:equatable/equatable.dart';

import '../../../core/models/service_job.dart';

class ServiceState extends Equatable {
  final bool isLoading;
  final List<ServiceJob> jobs;
  final String? errorMessage;

  const ServiceState({
    this.isLoading = true,
    this.jobs = const [],
    this.errorMessage,
  });

  ServiceState copyWith({
    bool? isLoading,
    List<ServiceJob>? jobs,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ServiceState(
      isLoading: isLoading ?? this.isLoading,
      jobs: jobs ?? this.jobs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, jobs, errorMessage];
}
