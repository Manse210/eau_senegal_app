import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';
import 'models/order.dart';
import 'models/order_item.dart';
import 'models/order_status.dart';
import 'services/facture_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _otpController = TextEditingController();
  List<OrderItem> _items = [];
  bool _isLoading = true;
  String? _userRole;

  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _loadInitialData();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _userRole = user.userMetadata?['role'];
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
      _entryCtrl.forward(from: 0);
    } catch (e) {
      debugPrint("Erreur chargement articles : $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelivery() async {
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Livraison validée avec succès !'),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ));
          if (_userRole == 'boutiquier' && widget.order.livreurId != null) {
            _showRatingDialog(widget.order.livreurId!);
          } else {
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        debugPrint("Erreur validation livraison : $e");
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Code OTP incorrect. Veuillez réessayer.'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      }
    }
  }

  Future<void> _showRatingDialog(String livreurId) async {
    int note = 5;
    final commentCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_rounded, color: AppColors.amber, size: 30),
            ),
            const SizedBox(height: 12),
            Text('Évaluer le livreur', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Notez la qualité de la livraison', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setDialogState(() => note = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        star <= note ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: AppColors.amber,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Commentaire (optionnel)',
                  hintStyle: GoogleFonts.poppins(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Passer'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Noter $note/5', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final userId = _supabase.auth.currentUser!.id;
        await _supabase.from('evaluations_livreurs').insert({
          'livreur_id': livreurId,
          'commande_id': widget.order.id,
          'note': note,
          'commentaire': commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
          'evaluateur_id': userId,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Merci ! Note de $note/5 enregistrée'),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ));
        }
      } catch (e) {
        debugPrint("Erreur enregistrement évaluation: $e");
      }
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = order.status;
    final isLivreur = _userRole == 'livreur';
    final isBoutiquier = _userRole == 'boutiquier';
    final isAdmin = _userRole == 'admin';
    final size = MediaQuery.of(context).size;

    final numericId = order.id.replaceAll(RegExp(r'[^0-9]'), '');
    final displayOtp = numericId.length >= 4
        ? numericId.substring(numericId.length - 4)
        : '1234';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        accentColor: status.color,
        child: FadeTransition(
            opacity: _entryFade,
            child: SlideTransition(
              position: _entrySlide,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 3))
                  : CustomScrollView(
                      slivers: [
                        _buildStatusHeader(order, status),
                        if (status.code == 'en_livraison')
                          _buildOtpSection(
                              order, isBoutiquier, isLivreur, displayOtp),
                        if (isAdmin) _buildAdminStatusSection(order),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: Text('ARTICLES', style: AppText.label.copyWith(color: Colors.white54)),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildItemCard(_items[index]),
                              childCount: _items.length,
                            ),
                          ),
                        ),
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildTotalSection(order),
                        ),
                      ],
                    ),
            ),
          ),
      ),
    );
  }

  Widget _buildStatusHeader(Order order, OrderStatus status) {
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          bottom: 24,
        ),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // AppBar-like row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.textPrimary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Commande #${order.shortId.substring(0, 5)}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [
                  status.color.withValues(alpha: 0.15),
                  status.color.withValues(alpha: 0.05),
                ]),
                shape: BoxShape.circle,
                border: Border.all(
                  color: status.color.withValues(alpha: 0.15),
                  width: 1.5,
                ),
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
    );
  }

  Widget _buildOtpSection(
      Order order, bool isBoutiquier, bool isLivreur, String displayOtp) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.06),
                AppColors.primary.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.1)),
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
                    hintStyle: AppText.caption,
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
                  child: ElevatedButton.icon(
                    onPressed: _confirmDelivery,
                    icon: const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 20),
                    label: const Text('CONFIRMER LA LIVRAISON'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── ADMIN : CHANGER LE STATUT ───
  Widget _buildAdminStatusSection(Order order) {
    final statuses = [
      OrderStatus.confirmee,
      OrderStatus.enLivraison,
      OrderStatus.livree,
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded,
                      color: Color(0xFF7C3AED), size: 18),
                  const SizedBox(width: 8),
                  Text('ADMIN — Changer le statut', style: AppText.label),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: statuses.map((s) {
                  final isCurrent = order.status == s;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: isCurrent
                            ? null
                            : () => _updateOrderStatus(order.id, s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? s.color.withValues(alpha: 0.15)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent
                                  ? s.color.withValues(alpha: 0.4)
                                  : AppColors.divider,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(s.icon,
                                  color: isCurrent
                                      ? s.color
                                      : AppColors.textLight,
                                  size: 20),
                              const SizedBox(height: 4),
                              Text(
                                s.label,
                                style: GoogleFonts.poppins(
                                  color: isCurrent
                                      ? s.color
                                      : AppColors.textLight,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateOrderStatus(
      String orderId, OrderStatus newStatus) async {
    try {
      await _supabase
          .from('commandes')
          .update({'status': newStatus.code})
          .eq('id', orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Statut mis à jour : ${newStatus.label}'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Erreur mise à jour statut: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      }
    }
  }

  Widget _buildItemCard(OrderItem item) {
    final product = item.product;
    final color = product?.couleurTheme ?? AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          product?.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(product!.imageUrl!, width: 54, height: 54, fit: BoxFit.contain),
                )
              : Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withValues(alpha: 0.12),
                width: 1,
              ),
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
                const SizedBox(height: 2),
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

  Widget _buildTotalSection(Order order) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total à payer', style: AppText.subheading),
                    if (order.paymentMethod != null)
                      Text(
                        order.paymentMethod!.toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: AppColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Génération de la facture…'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ));
                  final service = FactureService();
                  await service.genererEtPartager(widget.order);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Erreur : $e'),
                      backgroundColor: AppColors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      duration: const Duration(seconds: 5),
                    ));
                  }
                }
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
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
    );
  }
}
