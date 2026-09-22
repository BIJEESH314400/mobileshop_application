import 'package:equatable/equatable.dart';

sealed class AddEmployeeEvent extends Equatable {
  const AddEmployeeEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when "Create Login" is tapped, carrying the form fields as
/// plain strings — parsing/validation happens in the Bloc, not the View.
class AddEmployeeSubmitted extends AddEmployeeEvent {
  final String name;
  final String username;
  final String password;

  const AddEmployeeSubmitted({required this.name, required this.username, required this.password});

  @override
  List<Object?> get props => [name, username, password];
}
