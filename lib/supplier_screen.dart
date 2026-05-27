import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
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
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  int _totalOrders = 0;
  int _activeDeliveries = 0;
  int _pendingOrders = 0;
  List<Order> _orders = [];
  List<Map<String, dynamic>> _livreurs = [];
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadDashboardData();
    _loadLivreurs();
  }

  Future<void> _loadLivreurs() async {
    try {
      final response = await _supabase.from('livreur').select();
      setState(() {
        _livreurs = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("Erreur chargement livreurs : $e");
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('commandes')
          .select()
          .order('created_at', ascending: false);

      final List<Order> loadedOrders = (response as List)
          .map((row) => Order.fromMap(row as Map<String, dynamic>))
          .toList();

      int pending = 0;
      int active = 0;
      for (var order in loadedOrders) {
        if (order.status == OrderStatus.enAttente) pending++;
        if (order.status == OrderStatus.enLivraison) active++;
      }

      setState(() {
        _orders = loadedOrders;
        _totalOrders = loadedOrders.length;
        _activeDeliveries = active;
        _pendingOrders = pending;
        _isLoading = false;
      });
      _fadeController.forward(from: 0);
    } catch (e) {
      debugPrint("Erreur Dashboard : $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String orderId, OrderStatus newStatus, {String? livreurId}) async {
    try {
      final updates = {'status': newStatus.code};
      if (livreurId != null) {
        updates['livreur_id'] = livreurId;
      }

      await _supabase
          .from('commandes')
          .update(updates)
          .eq('id', orderId);
      
      // Si on passe en livraison, on crée/met à jour aussi le tracking
      if (newStatus == OrderStatus.enLivraison && livreurId != null) {
        try {
          // On essaie d'insérer une ligne de tracking initiale
          await _supabase.from('tracking_livreurs').upsert({
            'livreur_id': livreurId,
            'commande_id_uuid': orderId, // Utilisons un nouveau nom de colonne pour éviter le conflit type
            'position': 'POINT(-17.4624 14.6912)', // Position par défaut (Dakar)
          });
        } catch (trackError) {
          debugPrint("Note: Erreur tracking init (colonne peut-être manquante) : $trackError");
        }
      }

      _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Statut mis à jour : ${newStatus.label}'),
        ));
      }
    } catch (e) {
      debugPrint("Erreur mise à jour statut : $e");
    }
  }

  void _showLivreurSelection(String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assigner un livreur', style: AppText.subheading),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: _livreurs.isEmpty
            ? Text('Aucun livreur disponible', style: AppText.body)
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _livreurs.length,
                  itemBuilder: (context, index) {
                    final l = _livreurs[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.cyan,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(l['email'] ?? 'Livreur', style: AppText.body),
                      onTap: () {
                        Navigator.pop(context);
                        _updateOrderStatus(orderId, OrderStatus.enLivraison,
                            livreurId: l['id']);
                      },
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? Center(
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
          : FadeTransition(
              opacity: _fadeAnim,
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

  // ─── HEADER ───
  SliverAppBar _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 330,
      pinned: true,
      backgroundColor: AppColors.surface,
      elevation: 0,
      automaticallyImplyLeading: false, // Pas de bouton retour sur l'écran racine
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
          ),
          child: Stack(
            children: [
              // Dégradé décoratif
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                top: -40,
                right: -40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    shape: BoxShape.circle,
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
                              color: AppColors.red.withOpacity(0.08),
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
                    Text('Gestion des\nStocks 💧', style: AppText.heading),
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
            Icons.shopping_basket_rounded, AppColors.primary,
            AppColors.primary.withOpacity(0.08)),
        const SizedBox(width: 14),
        _buildStatCard('En livraison', '$_activeDeliveries',
            Icons.local_shipping_rounded, AppColors.cyan,
            AppColors.cyan.withOpacity(0.08)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppDecorations.card(radius: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
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
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(26),
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
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildOrderCard(_orders[index]),
          );
        },
        childCount: _orders.length,
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
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

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(order: order),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppDecorations.card(radius: 20),
        child: Row(
          children: [
            // Icône statut
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
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
                    Text('#$shortId · $formattedDate', style: AppText.caption)
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.green.withOpacity(0.1),
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

            // Badge statut
            PopupMenuButton<OrderStatus>(
              onSelected: (s) {
                if (s == OrderStatus.enLivraison) {
                  _showLivreurSelection(order.id);
                } else {
                  _updateOrderStatus(order.id, s);
                }
              },
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              itemBuilder: (context) => [
                _popupItem(OrderStatus.confirmee, OrderStatus.confirmee.label, OrderStatus.confirmee.icon),
                _popupItem(OrderStatus.enLivraison, OrderStatus.enLivraison.label,
                    OrderStatus.enLivraison.icon),
                _popupItem(OrderStatus.livree, OrderStatus.livree.label, OrderStatus.livree.icon),
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
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
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<OrderStatus> _popupItem(
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
}
