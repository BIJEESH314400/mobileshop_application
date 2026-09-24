import 'package:equatable/equatable.dart';

sealed class AddProductEvent extends Equatable {
  const AddProductEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when "Save Product" is tapped, carrying every field straight
/// off the form as plain strings — parsing/validation happens in the
/// Bloc, not the View.
class AddProductSubmitted extends AddProductEvent {
  final String name;
  final String category;
  final String brand;
  final String price;
  final String stockQty;
  final String sku;
  final String condition;
  final String description;

  /// Null when adding a brand-new product. When editing an existing one,
  /// this carries its Firestore document id so the Bloc updates that
  /// document in place instead of creating a new one.
  final String? productId;

  const AddProductSubmitted({
    required this.name,
    required this.category,
    required this.brand,
    required this.price,
    required this.stockQty,
    required this.sku,
    required this.condition,
    required this.description,
    this.productId,
  });

  @override
  List<Object?> get props =>
      [name, category, brand, price, stockQty, sku, condition, description, productId];
}
