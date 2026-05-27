import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart_screen.dart';
import 'payment_screen.dart';
import 'theme/app_theme.dart';
import 'theme/glass_theme.dart';
import 'models/product.dart';

class CatalogScreen extends StatefulWidget {
  final Function(List<CartItem>)? onOrderPlaced;
  const CatalogScreen({super.key, this.onOrderPlaced});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with SingleTickerProviderStateMixin {
  final List<CartItem> _cart = [];
  List<Product> _products = [];
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final response = await Supabase.instance.client
          .from('produits')
          .select()
          .order('marque', ascending: true);
      
      final parsedProducts = response.map<Product>((row) => Product.fromMap(row)).toList();

      setState(() {
        _products = parsedProducts;
        _isLoadingProducts = false;
      });
    } catch (e) {
      debugPrint("Erreur chargement produits : $e");
      // Repli robuste en cas d'erreur
      setState(() {
        _products = [
          Product(
            id: 'c1bc0bf3-94d7-4ef3-af1e-457e368f2957',
            nom: 'Pack 1.5 L',
            marque: 'Kirène',
            prix: 2500,
            couleurTheme: AppColors.primary,
            icon: Icons.water_drop_rounded,
            description: 'Eau minérale naturelle, riche en minéraux',
          ),
          Product(
            id: 'd695ccf5-1a2d-48f1-acc1-34c786d1f3c6',
            nom: 'Pack 0.5 L',
            marque: 'Casamancaise',
            prix: 1800,
            couleurTheme: AppColors.cyan,
            icon: Icons.water_drop_outlined,
            description: 'Eau purifiée, idéale pour les déplacements',
          ),
          Product(
            id: '7cb3bc1f-2e3e-49f8-ac6d-e91307c83be6',
            nom: 'Pack 10 L',
            marque: 'Baobab',
            prix: 3000,
            couleurTheme: AppColors.amber,
            icon: Icons.local_drink_rounded,
            description: 'Grand format pour la famille, économique',
          ),
        ];
        _isLoadingProducts = false;
      });
    }
  }

  void _addToCart(Product product) {
    setState(() {
      final index = _cart.indexWhere((item) => item.productId == product.id);
      if (index != -1) {
        _cart[index].quantity++;
      } else {
        _cart.add(CartItem(
          productId: product.id,
          name: product.nom,
          brand: product.marque,
          price: product.prix,
        ));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.green, size: 18),
          const SizedBox(width: 10),
          Text('${product.nom} ajouté au panier',
              style: GoogleFonts.poppins(color: Colors.white)),
        ],
      ),
    ));
  }

  void _removeFromCart(Product product) {
    setState(() {
      final index = _cart.indexWhere((item) => item.productId == product.id);
      if (index != -1) {
        if (_cart[index].quantity > 1) {
          _cart[index].quantity--;
        } else {
          _cart.removeAt(index);
        }
      }
    });
  }

  Future<void> _placeOrder(List<CartItem> items, {String? orderName}) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur : Vous devez être connecté pour commander.'),
          backgroundColor: AppColors.red,
        ));
      }
      return;
    }

    final userRole = user.userMetadata?['role'] ?? 'boutiquier';
    if (userRole != 'boutiquier') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Seul un Boutiquier peut commander (votre compte est enregistré comme : ${userRole.toUpperCase()}).'),
          backgroundColor: AppColors.red,
          duration: const Duration(seconds: 5),
        ));
      }
      return;
    }

    final total =
        items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    try {
      // Auto-réparation
      try {
        final profileCheck = await supabase
            .from('boutiquier')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();
        if (profileCheck == null) {
          await supabase.from('boutiquier').insert({
            'id': user.id,
            'email': user.email,
            'role': 'boutiquier',
          });
        }
      } catch (dbError) {
        debugPrint("Erreur synchronisation boutiquier : $dbError");
      }

      final order = await supabase.from('commandes').insert({
        'boutiquier_id': user.id,
        'nom': (orderName == null || orderName.trim().isEmpty) ? null : orderName.trim(),
        'status': 'en_attente',
        'total_price': total,
      }).select().single();
      for (var item in items) {
        // Insertion de l'article dans la commande
        await supabase.from('commande_items').insert({
          'commande_id': order['id'],
          'produit_id': item.productId,
          'quantity': item.quantity,
          'price_at_order': item.price,
        });

        // Décrémentation du stock (Gestion Simplifiée)
        try {
          final currentProduct = _products.firstWhere((p) => p.id == item.productId);
          final newStock = (currentProduct.stock - item.quantity).clamp(0, 999);
          
          await supabase.from('produits').update({
            'stock': newStock,
          }).eq('id', item.productId);
        } catch (stockError) {
          debugPrint("Erreur mise à jour stock pour ${item.productId} : $stockError");
        }
      }

      if (mounted) {
        setState(() {
          _cart.clear();
        });
        _loadProducts();

        Navigator.pop(context);

        final paiement = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              orderId: order['id'] as String,
              montant: total,
            ),
          ),
        );

        if (mounted && paiement == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Commande validée et payée ! 🎉'),
            backgroundColor: AppColors.green,
          ));
        }
      }
    } catch (e) {
      debugPrint("Erreur commande : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de la commande : $e'),
          backgroundColor: AppColors.red,
        ));
      }
    }
  }

  int get _cartTotal => _cart.fold(0, (sum, item) => sum + item.quantity);

  double get _cartValue =>
      _cart.fold(0.0, (sum, item) => sum + item.price * item.quantity);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          if (_cartTotal > 0) _buildCartBanner(),
          _isLoadingProducts
              ? const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildProductCard(_products[index]),
                      childCount: _products.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  SliverAppBar _buildHeader() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppColors.surface,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CartScreen(items: _cart, onOrderPlaced: _placeOrder),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shopping_cart_rounded,
                      color: AppColors.primary, size: 22),
                ),
                if (_cartTotal > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '$_cartTotal',
                          style: AppText.body.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppColors.surface,
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('CATALOGUE', style: AppText.label),
              const SizedBox(height: 8),
              Text('Eau Minérale\nau Sénégal 💧', style: AppText.heading),
              const SizedBox(height: 14),
              Row(
                children: [
                  _chip('${_products.length}', 'produits',
                      AppColors.primary),
                  const SizedBox(width: 10),
                  if (_cartTotal > 0)
                    _chip('$_cartTotal', 'dans le panier', AppColors.cyan),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: AppDecorations.chip(color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
                color: color, fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppText.caption.copyWith(color: color)),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildCartBanner() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.cyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_cartTotal article${_cartTotal > 1 ? 's' : ''} dans le panier',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${_cartValue.toStringAsFixed(0)} FCFA',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CartScreen(items: _cart, onOrderPlaced: _placeOrder),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Voir',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final inCart = _cart.firstWhereOrNull((i) => i.productId == product.id);
    final qty = inCart?.quantity ?? 0;

    return GlassCard(
      borderColor: qty > 0 ? product.couleurTheme.withValues(alpha: 0.4) : null,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: product.couleurTheme.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(product.icon,
                color: product.couleurTheme, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.marque.toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: product.couleurTheme,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.nom,
                  style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(product.description, style: AppText.caption),
                const SizedBox(height: 8),
                Text(
                  '${product.prix.toStringAsFixed(0)} FCFA',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
            Column(
              children: [
                if (qty > 0) ...[
                  GestureDetector(
                    onTap: () => _addToCart(product),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: product.couleurTheme,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$qty',
                    style: GoogleFonts.poppins(
                      color: product.couleurTheme,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _removeFromCart(product),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.remove_rounded,
                          color: product.couleurTheme, size: 20),
                    ),
                  ),
                ] else
                  GestureDetector(
                    onTap: () => _addToCart(product),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: product.couleurTheme,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: product.couleurTheme.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ),
              ],
            ),
          ],
        ),
    );
  }
}

extension _ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
