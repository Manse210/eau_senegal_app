import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum OrderStatus {
  enAttente('en_attente', 'En attente', AppColors.amber, Icons.hourglass_empty_rounded),
  payee('payee', 'Payée', AppColors.green, Icons.payments_rounded),
  confirmee('confirmee', 'Confirmée', AppColors.primary, Icons.check_circle_outline),
  enLivraison('en_livraison', 'En livraison', AppColors.cyan, Icons.local_shipping_rounded),
  livree('livree', 'Livrée', AppColors.green, Icons.done_all_rounded);

  final String code;
  final String label;
  final Color color;
  final IconData icon;

  const OrderStatus(this.code, this.label, this.color, this.icon);

  static OrderStatus fromCode(String code) {
    return OrderStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => OrderStatus.enAttente,
    );
  }
}
