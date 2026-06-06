import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';
import 'models/order.dart';
import 'models/order_status.dart';
import 'order_details_screen.dart';
import 'add_product_screen.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  int _totalOrders = 0;
  int _activeDeliveries = 0;
  int _pendingOrders = 0;
  int _paidOrders = 0;
  List<Order> _orders = [];
  List<Map<String, dynamic>> _livreurs = [];
  List<Map<String, dynamic>> _myProducts = [];
  bool _isCertifie = false;

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
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _loadDashboardData();
    _loadLivreurs();
  }

  Future<void> _loadLivreurs() async {
    try {
      final response = await _supabase
          .from('livreur')
          .select('*, evaluations_livreurs!left(note)')
          .order('note_moyenne', ascending: false);
      setState(() {
        _livreurs = (response as List).map((l) {
          final evals = l['evaluations_livreurs'] as List? ?? [];
          l['nb_evaluations'] = evals.length;
          return l as Map<String, dynamic>;
        }).toList();
      });
    } catch (e) {
      debugPrint("Erreur chargement livreurs : $e");
      // Fallback sans jointure
      try {
        final response = await _supabase.from('livreur').select();
        setState(() {
          _livreurs = List<Map<String, dynamic>>.from(response);
        });
      } catch (e2) {
        debugPrint("Erreur chargement livreurs (fallback) : $e2");
      }
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      // 0. Vérifier certification
      final monProfil = await _supabase
          .from('fournisseur')
          .select('certifie')
          .eq('id', userId)
          .maybeSingle();
      setState(() => _isCertifie = monProfil?['certifie'] == true);

      // 1. Récupérer les IDs des produits de ce fournisseur
      final mesProduits = await _supabase
          .from('produits')
          .select('id')
          .eq('fournisseur_id', userId);

      final mesProduitsIds =
          (mesProduits as List).map((p) => p['id'] as String).toList();

      List<Order> loadedOrders = [];

      if (mesProduitsIds.isNotEmpty) {
        // 2. Récupérer les commande_items liés à ces produits
        final items = await _supabase
            .from('commande_items')
            .select('commande_id')
            .inFilter('produit_id', mesProduitsIds);

        final commandeIds = (items as List)
            .map((i) => i['commande_id'] as String)
            .toSet()
            .toList();

        if (commandeIds.isNotEmpty) {
          // 3. Charger les commandes correspondantes
          final response = await _supabase
              .from('commandes')
              .select()
              .inFilter('id', commandeIds)
              .order('created_at', ascending: false);

          loadedOrders = (response as List)
              .map((row) => Order.fromMap(row as Map<String, dynamic>))
              .toList();
        }
      }

      int pending = 0;
      int active = 0;
      int paid = 0;
      for (var order in loadedOrders) {
        if (order.status == OrderStatus.enAttente) pending++;
        if (order.status == OrderStatus.enLivraison) active++;
        if (order.status == OrderStatus.payee) paid++;
      }

      // 4. Charger les produits du fournisseur
      final mesProduitsData = await _supabase
          .from('produits')
          .select('id, nom, marque, prix, stock, description, couleur_theme')
          .eq('fournisseur_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _orders = loadedOrders;
        _totalOrders = loadedOrders.length;
        _activeDeliveries = active;
        _pendingOrders = pending;
        _paidOrders = paid;
        _myProducts = List<Map<String, dynamic>>.from(mesProduitsData);
        _isLoading = false;
      });
      _entryCtrl.forward(from: 0);
    } catch (e) {
      debugPrint("Erreur Dashboard : $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String orderId, OrderStatus newStatus,
      {String? livreurId}) async {
    try {
      final updates = {'status': newStatus.code};
      if (livreurId != null) {
        updates['livreur_id'] = livreurId;
      }

      await _supabase
          .from('commandes')
          .update(updates)
          .eq('id', orderId);

      if (newStatus == OrderStatus.enLivraison && livreurId != null) {
        try {
          await _supabase.from('tracking_livreurs').upsert({
            'livreur_id': livreurId,
            'commande_id_uuid': orderId,
            'position': 'POINT(-17.4624 14.6912)',
          });
        } catch (trackError) {
          debugPrint("Note: Erreur tracking init : $trackError");
        }
      }

      _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Statut mis à jour : ${newStatus.label}'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      }
    } catch (e) {
      debugPrint("Erreur mise à jour statut : $e");
    }
  }

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _supabase.from('produits').delete().eq('id', productId);
      _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Produit supprimé'),
          backgroundColor: AppColors.green, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      }
    } catch (e) {
      debugPrint("Erreur suppression produit : $e");
    }
  }

  void _showLivreurSelection(String orderId) {
    // Trier par note moyenne décroissante
    final sorted = List<Map<String, dynamic>>.from(_livreurs)
      ..sort((a, b) {
        final noteA = (a['note_moyenne'] as num?)?.toDouble() ?? 0;
        final noteB = (b['note_moyenne'] as num?)?.toDouble() ?? 0;
        return noteB.compareTo(noteA);
      });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assigner un livreur', style: AppText.subheading),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: sorted.isEmpty
            ? Text('Aucun livreur disponible', style: AppText.body)
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final l = sorted[index];
                    final note = (l['note_moyenne'] as num?)?.toDouble() ?? 0;
                    final nbEval = l['nb_evaluations'] as int? ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: index == 0 && note > 0
                            ? AppColors.amber.withValues(alpha: 0.05)
                            : Colors.transparent,
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Icon(Icons.person, color: AppColors.primary),
                        ),
                        title: Text(l['email'] ?? 'Livreur', style: AppText.body),
                        subtitle: note > 0
                            ? Row(
                                children: [
                                  ...List.generate(5, (i) => Icon(
                                    i < note.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: AppColors.amber, size: 14,
                                  )),
                                  const SizedBox(width: 4),
                                  Text('${note.toStringAsFixed(1)}', style: GoogleFonts.poppins(color: AppColors.amber, fontSize: 11, fontWeight: FontWeight.w700)),
                                  if (nbEval > 0)
                                    Text(' ($nbEval)', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
                                ],
                              )
                            : Text('Aucune évaluation', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                        trailing: index == 0 && note > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('Meilleur', style: GoogleFonts.poppins(color: AppColors.amber, fontSize: 9, fontWeight: FontWeight.w700)),
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _updateOrderStatus(orderId, OrderStatus.enLivraison,
                              livreurId: l['id']);
                        },
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: AppText.caption),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        accentColor: AppColors.amber,
        child: Stack(
        children: [
          // ── DECORATIVE BUBBLES ──
          ..._buildBubbles(size),

          Positioned(
            bottom: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.cyan.withValues(alpha: 0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          if (_isLoading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 3),
                  const SizedBox(height: 20),
                  Text('Chargement…', style: AppText.body),
                ],
              ),
            )
          else
            FadeTransition(
              opacity: _entryFade,
              child: SlideTransition(
                position: _entrySlide,
                child: CustomScrollView(
                  slivers: [
                    _buildSliverHeader(),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Vue d\'ensemble', style: AppText.label),
                            const SizedBox(height: 14),
                            _buildStatsGrid(),
                            const SizedBox(height: 32),
                            if (_myProducts.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Mes produits', style: AppText.label),
                                  Text('${_myProducts.length} produit(s)', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ...(_myProducts.map((p) => _buildProductCard(p))),
                              const SizedBox(height: 32),
                            ],
                            Text('Commandes récentes', style: AppText.label),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),
                    _buildOrdersList(),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          );
          if (result == true) {
            _loadDashboardData();
          }
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          'Nouveau produit',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 4,
      ),
    );
  }

  List<Widget> _buildBubbles(Size size) {
    final specs = [
      (0.88, 0.08, 50.0),
      (0.10, 0.40, 60.0),
      (0.80, 0.80, 45.0),
    ];
    return specs.map((s) {
      return Positioned(
        left: size.width * s.$1,
        top: size.height * s.$2,
        child: Container(
          width: s.$3,
          height: s.$3,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              AppColors.primaryLight.withValues(alpha: 0.07),
              AppColors.primaryLight.withValues(alpha: 0.02),
            ]),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
        ),
      );
    }).toList();
  }

  // ─── HEADER ───
  SliverAppBar _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 330,
      pinned: true,
      backgroundColor: Colors.black26,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
          ),
          child: Stack(
            children: [
              // Grand cercle décoratif radial
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.primaryLight.withValues(alpha: 0.12),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 60,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.cyan.withValues(alpha: 0.08),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),

              // Contenu
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, MediaQuery.of(context).padding.top + 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.cyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.water_drop_rounded,
                              color: Colors.white, size: 24),
                        ),
                        const Spacer(),
                        if (_isCertifie)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_rounded, color: AppColors.cyan, size: 14),
                                const SizedBox(width: 4),
                                Text('Certifié', style: GoogleFonts.poppins(color: AppColors.cyan, fontSize: 10, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        GestureDetector(
                          onTap: _loadDashboardData,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.refresh_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _supabase.auth.signOut(),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.logout_rounded,
                                color: AppColors.red, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('TABLEAU DE BORD', style: AppText.label),
                    const SizedBox(height: 8),
                    Text('Gestion des\nStocks', style: AppText.heading),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _heroStat('$_totalOrders', 'Total', AppColors.primary),
                        _divider(),
                        _heroStat(
                            '$_pendingOrders', 'En attente', AppColors.amber),
                        _divider(),
                        _heroStat('$_activeDeliveries', 'En livraison',
                            AppColors.cyan),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroStat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
                color: color, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 14),
    );
  }

  // ─── GRILLE DE STATS ───
  Widget _buildStatsGrid() {
    return Row(
      children: [
        _buildStatCard('Commandes', '$_totalOrders',
            Icons.shopping_basket_rounded, AppColors.primary),
        const SizedBox(width: 14),
        _buildStatCard('En livraison', '$_activeDeliveries',
            Icons.local_shipping_rounded, AppColors.cyan),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
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
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.0),
            ),
            const SizedBox(height: 4),
            Text(title, style: AppText.caption),
          ],
        ),
      ),
    );
  }

  // ─── CARTE PRODUIT ───
  Widget _buildProductCard(Map<String, dynamic> p) {
    final hex = p['couleur_theme'] as String? ?? '#1565C0';
    final color = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.water_drop_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['nom'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${p['marque']} · ${p['prix']} FCFA · Stock: ${p['stock']}', style: GoogleFonts.poppins(color: Colors.black45, fontSize: 10)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.cyan, size: 18),
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => AddProductScreen(product: p)),
              );
              if (result == true) _loadDashboardData();
            },
            padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 18),
            onPressed: () => _deleteProduct(p['id'] as String),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  // ─── LISTE COMMANDES ───
  SliverList _buildOrdersList() {
    if (_orders.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.surfaceAlt,
                        AppColors.surfaceAlt.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.inbox_outlined,
                      size: 40, color: AppColors.textLight),
                ),
                const SizedBox(height: 18),
                Text('Aucune commande pour le moment', style: AppText.body),
              ],
            ),
          ),
        ]),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return _AnimatedOrderCard(
            index: index,
            order: _orders[index],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailsScreen(order: _orders[index]),
              ),
            ),
            onStatusChange: (orderId, newStatus) {
              if (newStatus == OrderStatus.enLivraison) {
                _showLivreurSelection(orderId);
              } else {
                _updateOrderStatus(orderId, newStatus);
              }
            },
          );
        },
        childCount: _orders.length,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ANIMATED ORDER CARD
// ─────────────────────────────────────────────
class _AnimatedOrderCard extends StatefulWidget {
  final int index;
  final Order order;
  final VoidCallback onTap;
  final void Function(String orderId, OrderStatus newStatus) onStatusChange;

  const _AnimatedOrderCard({
    required this.index,
    required this.order,
    required this.onTap,
    required this.onStatusChange,
  });

  @override
  State<_AnimatedOrderCard> createState() => _AnimatedOrderCardState();
}

class _AnimatedOrderCardState extends State<_AnimatedOrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 60 * widget.index), _ctrl.forward);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = order.status;
    final statusText = status.label;
    final statusColor = status.color;
    final statusIcon = status.icon;

    final totalPrice = order.totalPrice;
    final createdAt = order.createdAt;
    final formattedDate =
        '${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}/'
        '${createdAt.year}  '
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}';

    final shortId = order.shortId;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icône statut avec gradient
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          statusColor.withValues(alpha: 0.15),
                          statusColor.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 26),
                  ),
                  const SizedBox(width: 14),

                  // Détails
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.nom != null && order.nom!.isNotEmpty
                              ? order.nom!
                              : 'CMD #$shortId',
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        if (order.nom != null && order.nom!.isNotEmpty)
                          Text('#$shortId · $formattedDate',
                              style: AppText.caption)
                        else
                          Text(formattedDate, style: AppText.caption),
                        const SizedBox(height: 3),
                        Text(
                          '${totalPrice.toStringAsFixed(0)} FCFA',
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (order.paymentMethod != null)
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${order.paymentMethod!.toUpperCase()} ✓',
                              style: GoogleFonts.poppins(
                                color: AppColors.green,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Menu statut
                  _StatusMenu(
                    status: status,
                    statusText: statusText,
                    statusColor: statusColor,
                    onChanged: (s) => widget.onStatusChange(order.id, s),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  STATUS MENU
// ─────────────────────────────────────────────
class _StatusMenu extends StatelessWidget {
  final OrderStatus status;
  final String statusText;
  final Color statusColor;
  final void Function(OrderStatus) onChanged;

  const _StatusMenu({
    required this.status,
    required this.statusText,
    required this.statusColor,
    required this.onChanged,
  });

  PopupMenuItem<OrderStatus> _item(
      OrderStatus value, String label, IconData icon) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: AppText.body.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<OrderStatus>(
      onSelected: onChanged,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        _item(OrderStatus.confirmee, OrderStatus.confirmee.label,
            OrderStatus.confirmee.icon),
        _item(OrderStatus.enLivraison, OrderStatus.enLivraison.label,
            OrderStatus.enLivraison.icon),
        _item(OrderStatus.livree, OrderStatus.livree.label,
            OrderStatus.livree.icon),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              statusColor.withValues(alpha: 0.12),
              statusColor.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              statusText,
              style: GoogleFonts.poppins(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: statusColor, size: 14),
          ],
        ),
      ),
    );
  }
}
