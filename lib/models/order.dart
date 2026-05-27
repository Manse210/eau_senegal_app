import 'order_status.dart';
import 'order_item.dart';

class Order {
  final String id;
  final String? nom;
  final String boutiquierId;
  final String? livreurId;
  final OrderStatus status;
  final double totalPrice;
  final DateTime createdAt;
  final String? paymentMethod;
  final List<OrderItem> items;

  Order({
    required this.id,
    this.nom,
    required this.boutiquierId,
    this.livreurId,
    required this.status,
    required this.totalPrice,
    required this.createdAt,
    this.paymentMethod,
    this.items = const [],
  });

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id']?.toString() ?? '',
      nom: map['nom']?.toString(),
      boutiquierId: map['boutiquier_id']?.toString() ?? '',
      livreurId: map['livreur_id']?.toString(),
      status: OrderStatus.fromCode(map['status'] as String? ?? 'en_attente'),
      totalPrice: (map['total_price'] as num? ?? 0).toDouble(),
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String).toLocal() 
          : DateTime.now(),
      paymentMethod: map['payment_method']?.toString(),
      items: map['commande_items'] != null
          ? (map['commande_items'] as List)
              .map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  String get shortId => id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
}
