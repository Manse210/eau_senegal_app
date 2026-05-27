import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'models/order.dart';
import 'models/order_item.dart';
import 'services/facture_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final _supabase = Supabase.instance.client;
  final _otpController = TextEditingController();
  List<OrderItem> _items = [];
  bool _isLoading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final role = user.userMetadata?['role'];
      debugPrint("Rôle détecté dans OrderDetails: $role");
      setState(() {
        _userRole = role;
      });
    }
    await _loadOrderItems();
  }

  Future<void> _loadOrderItems() async {
    try {
      final response = await _supabase
          .from('commande_items')
          .select('*, produits(*)')
          .eq('commande_id', widget.order.id);

      setState(() {
        _items = (response as List)
            .map((row) => OrderItem.fromMap(row as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur chargement articles : $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelivery() async {
    // Dans ce prototype, l'OTP est constitué des 4 derniers chiffres de l'ID de commande
    final correctOtp = widget.order.id.replaceAll(RegExp(r'[^0-9]'), '');
    final last4 = correctOtp.length >= 4 
        ? correctOtp.substring(correctOtp.length - 4) 
        : '1234';

    if (_otpController.text == last4) {
      try {
        await _supabase
            .from('commandes')
            .update({'status': 'livree'})
            .eq('id', widget.order.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Livraison validée avec succès ! 🎉'),
            backgroundColor: AppColors.green,
          ));
          Navigator.pop(context, true);
        }
      } catch (e) {
        debugPrint("Erreur validation livraison : $e");
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Code OTP incorrect. Veuillez réessayer.'),
          backgroundColor: AppColors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = order.status;
    final isLivreur = _userRole == 'livreur';
    final isBoutiquier = _userRole == 'boutiquier';
    
    // Calcul de l'OTP pour l'affichage
    final numericId = order.id.replaceAll(RegExp(r'[^0-9]'), '');
    final displayOtp = numericId.length >= 4 
        ? numericId.substring(numericId.length - 4) 
        : '1234';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Commande #${order.shortId.substring(0, 5)}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 3))
          : CustomScrollView(
              slivers: [
                // ── RÉSUMÉ STATUT ──
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: status.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(status.icon,
                              color: status.color, size: 40),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          status.label.toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: status.color,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Passée le ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} à ${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── SECTION OTP (Boutiquier ou Livreur) ──
                if (status.code == 'en_livraison')
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                            if (isBoutiquier) ...[
                              Text('CODE DE VALIDATION', style: AppText.label),
                              const SizedBox(height: 10),
                              Text(
                                displayOtp,
                                style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  letterSpacing: 8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Donnez ce code au livreur pour valider la réception.',
                                style: AppText.caption,
                                textAlign: TextAlign.center,
                              ),
                            ] else if (isLivreur) ...[
                              Text('VALIDER LA LIVRAISON', style: AppText.label),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 4,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'CODE OTP',
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _confirmDelivery,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.green,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Text('CONFIRMER LA LIVRAISON'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── LISTE DES ARTICLES ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text('ARTICLES', style: AppText.label),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildItemCard(_items[index]),
                      childCount: _items.length,
                    ),
                  ),
                ),

                // ── TOTAL + FACTURE ──
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: AppDecorations.card(radius: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total à payer',
                                  style: AppText.subheading),
                              Text(
                                '${order.totalPrice.toStringAsFixed(0)} FCFA',
                                style: GoogleFonts.poppins(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Génération de la facture…'),
                                    backgroundColor: AppColors.primary,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                                final service = FactureService();
                                await service.genererEtPartager(widget.order);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erreur : $e'),
                                      backgroundColor: AppColors.red,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.picture_as_pdf_rounded,
                                size: 20),
                            label: const Text('Télécharger la facture'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildItemCard(OrderItem item) {
    final product = item.product;
    final color = product?.couleurTheme ?? AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(radius: 18),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(product?.icon ?? Icons.water_drop_rounded,
                color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product?.nom ?? 'Produit inconnu',
                  style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
                Text(
                  '${item.quantity} x ${item.priceAtOrder.toStringAsFixed(0)} FCFA',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Text(
            '${item.total.toStringAsFixed(0)} FCFA',
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
