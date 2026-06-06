import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';

class CartItem {
  final String productId;
  final String name;
  final String brand;
  final double price;
  int quantity;
  final String? imageUrl;
  final Color? couleurTheme;
  final IconData icon;

  CartItem({
    required this.productId,
    required this.name,
    required this.brand,
    required this.price,
    this.quantity = 1,
    this.imageUrl,
    this.couleurTheme,
    this.icon = Icons.water_drop_rounded,
  });
}

class CartScreen extends StatefulWidget {
  final List<CartItem> items;
  final Function(List<CartItem>, {String? orderName}) onOrderPlaced;

  const CartScreen(
      {super.key, required this.items, required this.onOrderPlaced});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _nameController = TextEditingController();
  double get total =>
      widget.items.fold(0, (sum, item) => sum + (item.price * item.quantity));

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Column(
          children: [
            AppHeader(
              title: 'Mon Panier',
              icon: Icons.shopping_cart_rounded,
              showBackButton: true,
            ),
            Expanded(
              child: widget.items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 90, height: 90,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Icon(Icons.shopping_cart_outlined,
                                size: 44, color: Colors.white38),
                          ),
                          const SizedBox(height: 20),
                          Text('Votre panier est vide',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('Ajoutez des produits depuis le catalogue',
                              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: widget.items.length,
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        final color = item.couleurTheme ?? AppColors.primary;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              item.imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.network(
                                          item.imageUrl!,
                                          width: 50, height: 50,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              AppIconBadge(icon: item.icon, color: color, size: 50)),
                                    )
                                  : AppIconBadge(icon: item.icon, color: color, size: 50),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name,
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white, fontSize: 14)),
                                    const SizedBox(height: 3),
                                    Text('${item.brand} · ${item.price.toStringAsFixed(0)} FCFA/u',
                                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (item.quantity > 1) item.quantity--;
                                      });
                                    },
                                    child: Container(
                                      width: 32, height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: const Icon(Icons.remove_rounded,
                                          size: 16, color: Colors.white54),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('${item.quantity}',
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16, color: Colors.white)),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => item.quantity++),
                                    child: Container(
                                      width: 32, height: 32,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (widget.items.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D2137),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14)),
                        Text('${total.toStringAsFixed(0)} FCFA',
                            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Nom de la commande (optionnel)',
                        hintStyle: GoogleFonts.poppins(color: Colors.white24, fontSize: 12),
                        prefixIcon: const Icon(Icons.label_outline_rounded, size: 18, color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Commander · ${total.toStringAsFixed(0)} FCFA',
                      icon: Icons.shopping_cart_rounded,
                      onPressed: () => widget.onOrderPlaced(widget.items, orderName: _nameController.text),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
