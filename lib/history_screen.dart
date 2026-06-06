import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';
import 'models/order.dart';
import 'models/order_status.dart';
import 'order_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  final String? role;
  const HistoryScreen({super.key, this.role});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final isLivreur = widget.role == 'livreur';
    final accent =
        isLivreur ? AppColors.cyan : AppColors.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        accentColor: accent,
        child: FadeTransition(
          opacity: _entryFade,
          child: SlideTransition(
            position: _entrySlide,
            child: Column(
              children: [
                AppHeader(
                  icon: isLivreur
                      ? Icons.local_shipping_rounded
                      : Icons.receipt_long_rounded,
                  title: isLivreur ? 'Mes Livraisons' : 'Mes Commandes',
                  subtitle: isLivreur
                      ? 'Suivez toutes vos livraisons assignées'
                      : 'Consultez l\'historique de vos commandes',
                  accentColor: accent,
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        Future.delayed(const Duration(milliseconds: 300)),
                    color: accent,
                    child: isLivreur
                        ? _buildDeliveryHistory(supabase)
                        : _buildOrderHistory(supabase),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHistory(SupabaseClient supabase) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('commandes')
          .stream(primaryKey: ['id'])
          .eq('boutiquier_id', supabase.auth.currentUser!.id)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.red.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text('Erreur de chargement',
                  style: GoogleFonts.poppins(color: Colors.white)),
              const SizedBox(height: 4),
              Text('${snapshot.error}',
                  style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
            ]),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 3),
          );
        }
        final orders = snapshot.data!
            .map((row) => Order.fromMap(row))
            .toList();

        if (orders.isEmpty) {
          return _empty(
              Icons.shopping_bag_outlined, 'Aucune commande', 'Vos commandes apparaîtront ici');
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: orders.length,
          itemBuilder: (_, i) => _buildOrderCard(orders[i], i),
        );
      },
    );
  }

  Widget _buildDeliveryHistory(SupabaseClient supabase) {
    final userId = supabase.auth.currentUser!.id;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('commandes')
          .stream(primaryKey: ['id'])
          .eq('livreur_id', userId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.red.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text('Erreur de chargement',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ]),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 3),
          );
        }
        final orders = snapshot.data!
            .map((row) => Order.fromMap(row))
            .toList();

        if (orders.isEmpty) {
          return _empty(
              Icons.local_shipping_outlined, 'Aucune livraison',
              'Vos livraisons apparaîtront ici dès qu\'un fournisseur vous en assigne une.');
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: orders.length,
          itemBuilder: (_, i) => _buildOrderCard(orders[i], i),
        );
      },
    );
  }

  Widget _empty(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(icon, size: 48, color: Colors.white38),
        ),
        const SizedBox(height: 20),
        Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(subtitle,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _buildOrderCard(Order order, int index) {
    final status = order.status;
    final formattedDate =
        '${order.createdAt.day.toString().padLeft(2, '0')}/'
        '${order.createdAt.month.toString().padLeft(2, '0')}/'
        '${order.createdAt.year}';
    final formattedTime =
        '${order.createdAt.hour.toString().padLeft(2, '0')}:'
        '${order.createdAt.minute.toString().padLeft(2, '0')}';
    final shortId = '#${order.shortId.substring(0, 5)}';

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(children: [
          AppIconBadge(icon: status.icon, color: status.color, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.nom != null && order.nom!.isNotEmpty ? order.nom! : 'Commande $shortId',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(order.nom != null && order.nom!.isNotEmpty
                      ? '$shortId · $formattedDate à $formattedTime'
                      : '$formattedDate à $formattedTime',
                  style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 4),
              Text('${order.totalPrice.toStringAsFixed(0)} FCFA',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ]),
          ),
          AppStatusBadge(label: status.label, color: status.color),
          if (status == OrderStatus.livree) ...[
            const SizedBox(width: 6),
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.star_rounded, color: AppColors.amber, size: 16),
            ),
          ],
        ]),
      ),
    );
  }
}
