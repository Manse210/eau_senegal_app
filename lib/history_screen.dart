import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'models/order.dart';
import 'models/order_status.dart';
import 'order_details_screen.dart';

class HistoryScreen extends StatelessWidget {
  final String? role;
  const HistoryScreen({super.key, this.role});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final isLivreur = role == 'livreur';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isLivreur ? 'Mes Livraisons 🚚' : 'Mes Commandes 📦',
            style: AppText.subheading),
        backgroundColor: AppColors.surface,
        elevation: 0,
        automaticallyImplyLeading: false, // Pas de bouton retour automatique
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Forcer un rafraîchissement via un rebuild si nécessaire
          (context as Element).markNeedsBuild();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: isLivreur
              ? _buildDeliveryHistory(supabase, context)
              : _buildOrderHistory(supabase, context),
        ),
      ),
    );
  }

  Widget _buildOrderHistory(SupabaseClient supabase, BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('commandes')
          .stream(primaryKey: ['id'])
          .eq('boutiquier_id', supabase.auth.currentUser!.id)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(
              child: Text('Erreur : ${snapshot.error}', style: AppText.body),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 3),
            ),
          );
        }
        final List<Order> orders = snapshot.data!
            .map((row) => Order.fromMap(row))
            .toList();

        if (orders.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 80),
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
                  child: const Icon(Icons.shopping_bag_outlined,
                      size: 44, color: AppColors.textLight),
                ),
                const SizedBox(height: 18),
                Text('Aucune commande effectuée', style: AppText.subheading),
                const SizedBox(height: 8),
                Text('Vos commandes apparaîtront ici', style: AppText.body),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: orders.length,
          itemBuilder: (context, index) => GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailsScreen(order: orders[index]),
                ),
              );
            },
            child: _buildOrderCard(orders[index]),
          ),
        );
      },
    );
  }

  Widget _buildDeliveryHistory(SupabaseClient supabase, BuildContext context) {
    final userId = supabase.auth.currentUser!.id;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('commandes')
          .stream(primaryKey: ['id'])
          .eq('livreur_id', userId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(
              child: Text('Erreur : ${snapshot.error}', style: AppText.body),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 3),
            ),
          );
        }
        final List<Order> orders = snapshot.data!
            .map((row) => Order.fromMap(row))
            .toList();

        if (orders.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 80),
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
                  child: const Icon(Icons.local_shipping_outlined,
                      size: 44, color: AppColors.textLight),
                ),
                const SizedBox(height: 18),
                Text('Aucune livraison assignée',
                    style: AppText.subheading),
                const SizedBox(height: 8),
                Text('Vos livraisons apparaîtront ici dès qu\'un fournisseur vous en assigne une.',
                    style: AppText.body),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: orders.length,
          itemBuilder: (context, index) => GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailsScreen(order: orders[index]),
                ),
              );
            },
            child: _buildOrderCard(orders[index]),
          ),
        );
      },
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
        '${createdAt.year}';
    final formattedTime =
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}';

    final shortId = '#${order.shortId.substring(0, 5)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.card(radius: 20),
      child: Row(
        children: [
          // Icône
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
                      : 'Commande $shortId',
                  style: AppText.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if (order.nom != null && order.nom!.isNotEmpty)
                  Text('$shortId · $formattedDate à $formattedTime',
                      style: AppText.caption)
                else
                  Text('$formattedDate à $formattedTime',
                      style: AppText.caption),
                const SizedBox(height: 3),
                Text(
                  '${totalPrice.toStringAsFixed(0)} FCFA',
                  style: AppText.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // Badge statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: AppText.label.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
