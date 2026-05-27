import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';

class CartItem {
  final String productId;
  final String name;
  final String brand;
  final double price;
  int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.brand,
    required this.price,
    this.quantity = 1,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary, size: 20),
          ),
        ),
        title: Text('Mon Panier',
            style: AppText.subheading),
      ),
      body: widget.items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.shopping_cart_outlined,
                        size: 44, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 20),
                  Text('Votre panier est vide', style: AppText.subheading),
                  const SizedBox(height: 8),
                  Text('Ajoutez des produits depuis le catalogue',
                      style: AppText.body),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: AppDecorations.card(radius: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: AppDecorations.iconBg(AppColors.primary,
                            radius: 14),
                        child: const Icon(Icons.water_drop_rounded,
                            color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                style: AppText.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 3),
                            Text('${item.brand} · ${item.price.toStringAsFixed(0)} FCFA/u',
                                style: AppText.caption),
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
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(Icons.remove_rounded,
                                  size: 16, color: AppColors.textSecond),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${item.quantity}',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() => item.quantity++);
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(Icons.add_rounded,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: widget.items.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 20,
                      offset: Offset(0, -4))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: AppText.body),
                      Text(
                        '${total.toStringAsFixed(0)} FCFA',
                        style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Nom de la commande (optionnel)',
                      hintStyle: AppText.caption,
                      prefixIcon: const Icon(Icons.label_outline_rounded, size: 18),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => widget.onOrderPlaced(widget.items, orderName: _nameController.text),
                      child: Text(
                          'Commander · ${total.toStringAsFixed(0)} FCFA',
                          style: AppText.button
                              .copyWith(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
