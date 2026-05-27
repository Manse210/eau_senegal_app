import 'product.dart';

class OrderItem {
  final String id;
  final String commandeId;
  final String produitId;
  final int quantity;
  final double priceAtOrder;
  final Product? product; // Can be null if not joined

  OrderItem({
    required this.id,
    required this.commandeId,
    required this.produitId,
    required this.quantity,
    required this.priceAtOrder,
    this.product,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id']?.toString() ?? '',
      commandeId: map['commande_id']?.toString() ?? '',
      produitId: map['produit_id']?.toString() ?? '',
      quantity: map['quantity'] as int? ?? 0,
      priceAtOrder: (map['price_at_order'] as num? ?? 0).toDouble(),
      product: map['produits'] != null 
          ? Product.fromMap(map['produits'] as Map<String, dynamic>) 
          : null,
    );
  }

  double get total => quantity * priceAtOrder;
}
