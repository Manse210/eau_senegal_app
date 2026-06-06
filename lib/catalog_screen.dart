import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart_screen.dart';
import 'payment_screen.dart';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';
import 'models/product.dart';

class CatalogScreen extends StatefulWidget {
  final Function(List<CartItem>)? onOrderPlaced;
  const CatalogScreen({super.key, this.onOrderPlaced});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with TickerProviderStateMixin {
  final List<CartItem> _cart = [];
  List<Product> _products = [];
  bool _isLoadingProducts = true;
  Set<String> _certifiedSuppliers = {};

  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _loadProducts();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final supabase = Supabase.instance.client;

      // Charger les fournisseurs certifiés
      final certifies = await supabase
          .from('fournisseur')
          .select('id')
          .eq('certifie', true);
      _certifiedSuppliers = (certifies as List)
          .map((f) => f['id'] as String)
          .toSet();

      // Charger les produits
      final response = await supabase
          .from('produits')
          .select()
          .order('marque', ascending: true);
      setState(() {
        _products = response.map<Product>((row) => Product.fromMap(row)).toList();
        _isLoadingProducts = false;
      });
      _entryCtrl.forward(from: 0);
    } catch (e) {
      debugPrint("Erreur chargement produits : $e");
      setState(() {
        _products = [
          Product(id: 'c1bc0bf3-94d7-4ef3-af1e-457e368f2957', nom: 'Pack 1.5 L', marque: 'Kirène', prix: 2500, couleurTheme: AppColors.primary, icon: Icons.water_drop_rounded, description: 'Eau minérale naturelle'),
          Product(id: 'd695ccf5-1a2d-48f1-acc1-34c786d1f3c6', nom: 'Pack 0.5 L', marque: 'Casamancaise', prix: 1800, couleurTheme: AppColors.cyan, icon: Icons.water_drop_outlined, description: 'Eau purifiée'),
          Product(id: '7cb3bc1f-2e3e-49f8-ac6d-e91307c83be6', nom: 'Pack 10 L', marque: 'Baobab', prix: 3000, couleurTheme: AppColors.amber, icon: Icons.local_drink_rounded, description: 'Grand format'),
        ];
        _isLoadingProducts = false;
      });
    }
  }

  bool _isFournisseurCertifie(Product product) {
    return product.fournisseurId != null && _certifiedSuppliers.contains(product.fournisseurId);
  }

  void _addToCart(Product product) {
    setState(() {
      final index = _cart.indexWhere((item) => item.productId == product.id);
      if (index != -1) { _cart[index].quantity++; }
      else { _cart.add(CartItem(productId: product.id, name: product.nom, brand: product.marque, price: product.prix, imageUrl: product.imageUrl, couleurTheme: product.couleurTheme, icon: product.icon)); }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18), const SizedBox(width: 10), Text(product.nom, style: GoogleFonts.poppins(color: Colors.white))]),
      backgroundColor: AppColors.textPrimary, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  void _removeFromCart(Product product) {
    setState(() {
      final index = _cart.indexWhere((item) => item.productId == product.id);
      if (index != -1) { if (_cart[index].quantity > 1) { _cart[index].quantity--; } else { _cart.removeAt(index); } }
    });
  }

  Future<void> _placeOrder(List<CartItem> items, {String? orderName}) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      _snack('Vous devez être connecté', AppColors.red); return;
    }
    final userRole = user.userMetadata?['role'] ?? 'boutiquier';
    if (userRole != 'boutiquier') {
      _snack('Seul un Boutiquier peut commander', AppColors.red); return;
    }
    final total = items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    try {
      try {
        final pc = await supabase.from('boutiquier').select('id').eq('id', user.id).maybeSingle();
        if (pc == null) { await supabase.from('boutiquier').insert({'id': user.id, 'role': 'boutiquier'}); }
      } catch (_) {}
      final order = await supabase.from('commandes').insert({
        'boutiquier_id': user.id, 'nom': (orderName == null || orderName.trim().isEmpty) ? null : orderName.trim(),
        'status': 'en_attente', 'total_price': total,
      }).select().single();
      for (var item in items) {
        await supabase.from('commande_items').insert({'commande_id': order['id'], 'produit_id': item.productId, 'quantity': item.quantity, 'price_at_order': item.price});
        try {
          final cp = _products.firstWhere((p) => p.id == item.productId);
          await supabase.from('produits').update({'stock': (cp.stock - item.quantity).clamp(0, 999)}).eq('id', item.productId);
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _cart.clear());
        _loadProducts();
        Navigator.pop(context);
        final paid = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PaymentScreen(orderId: order['id'] as String, montant: total)));
        if (mounted && paid == true) { _snack('Commande validée et payée !', AppColors.green); }
      }
    } catch (e) {
      if (mounted) _snack('Erreur : $e', AppColors.red);
    }
  }

  void _snack(String msg, Color bg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ));

  int get _cartTotal => _cart.fold(0, (sum, item) => sum + item.quantity);
  double get _cartValue => _cart.fold(0.0, (sum, item) => sum + item.price * item.quantity);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        accentColor: AppColors.primaryLight,
        child: FadeTransition(
          opacity: _entryFade,
          child: SlideTransition(
            position: _entrySlide,
            child: CustomScrollView(
              slivers: [
                _buildHeader(),
                if (_cartTotal > 0) _buildCartBanner(),
                _isLoadingProducts
                    ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)))
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        sliver: SliverList(delegate: SliverChildBuilderDelegate(
                          (_, i) => _AnimatedProductCard(index: i, product: _products[i], cart: _cart, isCertifie: _isFournisseurCertifie(_products[i]), onAdd: _addToCart, onRemove: _removeFromCart),
                          childCount: _products.length,
                        )),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildHeader() {
    return SliverAppBar(
      expandedHeight: 180, pinned: true,
      backgroundColor: Colors.black26, elevation: 0, automaticallyImplyLeading: false,
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen(items: _cart, onOrderPlaced: _placeOrder))),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 22)),
                if (_cartTotal > 0)
                  Positioned(top: -4, right: -4,
                    child: Container(width: 20, height: 20, decoration: BoxDecoration(color: AppColors.red, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0B1A2E), width: 2)),
                      child: Center(child: Text('$_cartTotal', style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))))),
              ],
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('CATALOGUE', style: AppText.label.copyWith(color: Colors.white54)),
              const SizedBox(height: 8),
              Text('Eau Minérale\nau Sénégal', style: AppText.heading.copyWith(color: Colors.white)),
              const SizedBox(height: 14),
              Row(children: [
                _chip('${_products.length}', 'produits', AppColors.primary),
                const SizedBox(width: 10),
                if (_cartTotal > 0) _chip('$_cartTotal', 'dans le panier', AppColors.cyan),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
      ]),
    );
  }

  SliverToBoxAdapter _buildCartBanner() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cyan]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, 6))],
          ),
          child: Row(children: [
            const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_cartTotal article${_cartTotal > 1 ? 's' : ''}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              Text('${_cartValue.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
            ])),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen(items: _cart, onOrderPlaced: _placeOrder))),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: Text('Voir', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AnimatedProductCard extends StatefulWidget {
  final int index;
  final Product product;
  final List<CartItem> cart;
  final bool isCertifie;
  final void Function(Product) onAdd;
  final void Function(Product) onRemove;
  const _AnimatedProductCard({required this.index, required this.product, required this.cart, required this.isCertifie, required this.onAdd, required this.onRemove});
  @override
  State<_AnimatedProductCard> createState() => _AnimatedProductCardState();
}

class _AnimatedProductCardState extends State<_AnimatedProductCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 60 * widget.index), _ctrl.forward);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final inCart = widget.cart.firstWhereOrNull((i) => i.productId == product.id);
    final qty = inCart?.quantity ?? 0;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AppGlassCard(
            borderColor: qty > 0 ? product.couleurTheme.withValues(alpha: 0.3) : null,
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Stack(
                children: [
                  product.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                            child: Image.network(product.imageUrl!, width: 60, height: 60, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => AppIconBadge(icon: product.icon, color: product.couleurTheme, size: 60)),
                        )
                      : AppIconBadge(icon: product.icon, color: product.couleurTheme, size: 60),
                  if (widget.isCertifie)
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.cyan,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0B1A2E), width: 1.5),
                        ),
                        child: const Icon(Icons.verified_rounded, color: Colors.white, size: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  children: [
                    Text(product.marque.toUpperCase(), style: GoogleFonts.poppins(color: product.couleurTheme, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2)),
                    if (widget.isCertifie) ...[
                      const SizedBox(width: 6),
                      Text('OFFICIEL', style: GoogleFonts.poppins(color: AppColors.cyan, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(product.nom, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(product.description, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                Text('${product.prix.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              ])),
              Column(children: [
                if (qty > 0) ...[
                  GestureDetector(
                    onTap: () => widget.onAdd(product),
                    child: Container(width: 36, height: 36, decoration: BoxDecoration(color: product.couleurTheme, borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 20)),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(duration: const Duration(milliseconds: 150),
                    child: Text('$qty', key: ValueKey(qty), style: GoogleFonts.poppins(color: product.couleurTheme, fontWeight: FontWeight.w800, fontSize: 16))),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => widget.onRemove(product),
                    child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(11)),
                      child: Icon(Icons.remove_rounded, color: product.couleurTheme, size: 20)),
                  ),
                ] else
                  GestureDetector(
                    onTap: () => widget.onAdd(product),
                    child: Container(width: 44, height: 44, decoration: BoxDecoration(color: product.couleurTheme, borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: product.couleurTheme.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))]),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 24)),
                  ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

extension _ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) { if (test(e)) return e; }
    return null;
  }
}
