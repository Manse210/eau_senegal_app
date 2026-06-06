import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Product {
  final String id;
  final String nom;
  final String marque;
  final double prix;
  final int stock;
  final String description;
  final String? imageUrl;
  final String? fournisseurId;
  final Color couleurTheme;
  final IconData icon;

  Product({
    required this.id,
    required this.nom,
    required this.marque,
    required this.prix,
    this.stock = 100,
    this.description = '',
    this.imageUrl,
    this.fournisseurId,
    required this.couleurTheme,
    this.icon = Icons.water_drop_rounded,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    final hexColor = map['couleur_theme'] as String?;
    final nom = map['nom'] as String;
    
    return Product(
      id: map['id'] as String,
      nom: nom,
      marque: map['marque'] as String,
      prix: (map['prix'] as num).toDouble(),
      stock: map['stock'] as int? ?? 100,
      description: map['description'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      fournisseurId: map['fournisseur_id'] as String?,
      couleurTheme: _parseHexColor(hexColor),
      icon: _getIconForProduct(nom),
    );
  }

  static Color _parseHexColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return AppColors.primary;
    final cleanHex = hexString.replaceAll('#', '');
    if (cleanHex.length == 6) {
      return Color(int.parse('FF$cleanHex', radix: 16));
    } else if (cleanHex.length == 8) {
      return Color(int.parse(cleanHex, radix: 16));
    }
    return AppColors.primary;
  }

  static IconData _getIconForProduct(String name) {
    final lowercaseName = name.toLowerCase();
    if (lowercaseName.contains('0.5') || lowercaseName.contains('500ml')) {
      return Icons.water_drop_outlined;
    } else if (lowercaseName.contains('10l') || lowercaseName.contains('10 l')) {
      return Icons.local_drink_rounded;
    } else {
      return Icons.water_drop_rounded;
    }
  }
}
