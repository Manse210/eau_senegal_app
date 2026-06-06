import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';
import 'models/order.dart';
import 'models/order_status.dart';
import 'order_details_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  int _adminTab = 0; // 0: stats, 1: users, 2: products, 3: orders

  int _totalBoutiquiers = 0;
  int _totalFournisseurs = 0;
  int _totalLivreurs = 0;
  int _totalOrders = 0;
  int _activeDeliveries = 0;
  int _pendingOrders = 0;
  double _totalRevenue = 0;
  List<Order> _orders = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String _selectedUserTab = 'boutiquier';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _supabase.from('boutiquier').select('id'),
        _supabase.from('fournisseur').select('id'),
        _supabase.from('livreur').select('id'),
        _supabase.from('commandes').select().order('created_at', ascending: false),
        _supabase.from('produits').select('*, fournisseur_id'),
      ]);

      _totalBoutiquiers = (results[0] as List).length;
      _totalFournisseurs = (results[1] as List).length;
      _totalLivreurs = (results[2] as List).length;

      final ordersData = results[3] as List;
      final loadedOrders = ordersData
          .map((row) => Order.fromMap(row as Map<String, dynamic>))
          .toList();

      _products = List<Map<String, dynamic>>.from(results[4]);

      int pending = 0;
      int active = 0;
      double revenue = 0;
      for (var order in loadedOrders) {
        if (order.status == OrderStatus.payee ||
            order.status == OrderStatus.livree) {
          revenue += order.totalPrice;
        }
        if (order.status == OrderStatus.enAttente) pending++;
        if (order.status == OrderStatus.enLivraison) active++;
      }

      setState(() {
        _orders = loadedOrders;
        _totalOrders = loadedOrders.length;
        _activeDeliveries = active;
        _pendingOrders = pending;
        _totalRevenue = revenue;
        _isLoading = false;
      });
      _loadUsers();
    } catch (e) {
      debugPrint("Erreur chargement admin: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUsers() async {
    try {
      final data = await _supabase.from(_selectedUserTab).select();
      setState(() => _users = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint("Erreur chargement utilisateurs: $e");
    }
  }

  Future<void> _deleteUser(String table, String id) async {
    try {
      await _supabase.from(table).delete().eq('id', id);
      await _supabase.from('profiles').delete().eq('id', id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Utilisateur supprimé'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      }
    } catch (e) {
      debugPrint("Erreur suppression: $e");
    }
  }

  Future<void> _toggleCertification(String fournisseurId, bool current) async {
    try {
      await _supabase
          .from('fournisseur')
          .update({'certifie': !current})
          .eq('id', fournisseurId);
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(!current ? 'Fournisseur certifié ✓' : 'Certification retirée'),
          backgroundColor: !current ? AppColors.green : AppColors.amber,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      }
    } catch (e) {
      debugPrint("Erreur certification: $e");
    }
  }

  Future<void> _deleteProduct(String id) async {
    try {
      await _supabase.from('produits').delete().eq('id', id);
      _loadData();
      _snackBar('Produit supprimé', AppColors.green);
    } catch (e) {
      debugPrint("Erreur suppression produit: $e");
    }
  }

  void _showEditProductDialog(Map<String, dynamic> p) {
    final nomCtrl = TextEditingController(text: p['nom']);
    final marqueCtrl = TextEditingController(text: p['marque']);
    final prixCtrl = TextEditingController(text: (p['prix'] as num?)?.toString() ?? '');
    final stockCtrl = TextEditingController(text: (p['stock'] as int?)?.toString() ?? '100');
    final descCtrl = TextEditingController(text: p['description']);
    String selectedCouleur = p['couleur_theme']?.toString() ?? '#1565C0';
    Uint8List? imgBytes;
    String? existingImageUrl = (p['image_url'] as String?)?.isNotEmpty == true ? p['image_url'] as String? : null;

    final couleurs = ['#1565C0', '#10B981', '#F59E0B', '#E53935', '#00B4D8', '#7C3AED', '#EC4899', '#6B7280'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Modifier le produit'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom', prefixIcon: Icon(Icons.water_drop_rounded))),
                const SizedBox(height: 10),
                TextField(controller: marqueCtrl, decoration: const InputDecoration(labelText: 'Marque', prefixIcon: Icon(Icons.branding_watermark_rounded))),
                const SizedBox(height: 10),
                TextField(controller: prixCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix (FCFA)', prefixIcon: Icon(Icons.monetization_on_rounded))),
                const SizedBox(height: 10),
                TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock', prefixIcon: Icon(Icons.inventory_rounded))),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined))),
                const SizedBox(height: 16),
                Text('Couleur', style: AppText.caption),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: couleurs.map((c) {
                    final isSel = selectedCouleur == c;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedCouleur = c),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Color(int.parse('FF${c.replaceAll('#', '')}', radix: 16)),
                          borderRadius: BorderRadius.circular(8),
                          border: isSel ? Border.all(color: Colors.white, width: 2.5) : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    try {
                      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200);
                      if (picked == null) return;
                      Uint8List bytes;
                      if (kIsWeb) {
                        bytes = await picked.readAsBytes();
                      } else {
                        final cropped = await ImageCropper().cropImage(
                          sourcePath: picked.path,
                          compressQuality: 90,
                          uiSettings: [AndroidUiSettings(toolbarTitle: 'Cadrer', toolbarColor: const Color(0xFF7C3AED), statusBarColor: const Color(0xFF7C3AED), activeControlsWidgetColor: const Color(0xFF7C3AED))],
                        );
                        if (cropped == null) return;
                        bytes = await cropped.readAsBytes();
                      }
                      setDialogState(() { imgBytes = _compress(bytes); existingImageUrl = null; });
                    } catch (e) {
                      debugPrint('Image pick error: $e');
                    }
                  },
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: imgBytes != null
                        ? Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [AppColors.green.withValues(alpha: 0.2), AppColors.green.withValues(alpha: 0.05)]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 28),
                                  const SizedBox(height: 4),
                                  Text('Nouvelle photo sélectionnée', style: GoogleFonts.poppins(color: AppColors.green, fontSize: 11)),
                                ],
                              ),
                            ),
                          )
                        : existingImageUrl != null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.image_rounded, color: Colors.white38, size: 24),
                                  const SizedBox(height: 4),
                                  Text('Photo existante — cliquer pour changer',
                                      style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded, color: Colors.grey, size: 24),
                                  SizedBox(width: 8),
                                  Text('Ajouter une photo', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final updates = <String, dynamic>{
                    'nom': nomCtrl.text.trim(),
                    'marque': marqueCtrl.text.trim(),
                    'prix': double.tryParse(prixCtrl.text.trim()) ?? 0,
                    'stock': int.tryParse(stockCtrl.text.trim()) ?? 0,
                    'description': descCtrl.text.trim(),
                    'couleur_theme': selectedCouleur,
                  };
                  if (imgBytes != null) {
                    final fileName = 'produits/${DateTime.now().millisecondsSinceEpoch}.jpg';
                    await _supabase.storage.from('produits').uploadBinary(fileName, imgBytes!, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
                    updates['image_url'] = _supabase.storage.from('produits').getPublicUrl(fileName);
                  }
                  await _supabase.from('produits').update(updates).eq('id', p['id'] as String);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                  _snackBar('Produit modifié', AppColors.green);
                } catch (e) {
                  _snackBar('Erreur : $e', AppColors.red);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _snackBar(String msg, Color bg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
    }
  }

  Uint8List _compress(Uint8List bytes) {
    try {
      final original = img.decodeImage(bytes);
      if (original == null) return bytes;
      final size = original.width < original.height ? original.width : original.height;
      final cropped = img.copyCrop(original, x: (original.width - size) ~/ 2, y: (original.height - size) ~/ 2, width: size, height: size);
      final resized = img.copyResize(cropped, width: 600);
      return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
    } catch (_) {
      return bytes;
    }
  }

  Future<void> _deleteOrder(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _supabase
          .from('commandes')
          .update({'status': 'annulee'})
          .eq('id', id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Commande annulée'),
          backgroundColor: AppColors.amber,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      }
    } catch (e) {
      debugPrint("Erreur annulation: $e");
    }
  }

  void _showAddUserDialog() {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedRole = 'boutiquier';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ajouter un utilisateur'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: Icon(Icons.lock_rounded),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rôle',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'boutiquier', child: Text('Boutiquier')),
                  DropdownMenuItem(value: 'fournisseur', child: Text('Fournisseur')),
                  DropdownMenuItem(value: 'livreur', child: Text('Livreur')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedRole = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) return;
                try {
                  await _supabase.rpc('admin_create_user', params: {
                    'p_email': emailCtrl.text.trim(),
                    'p_password': passwordCtrl.text.trim(),
                    'p_role': selectedRole,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Utilisateur créé'),
                      backgroundColor: AppColors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ));
                  }
                } catch (e) {
                  debugPrint("Erreur création: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Erreur : ${e.toString().replaceAll('{', '\n').replaceAll('}', '')}'),
                      backgroundColor: AppColors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ));
                  }
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProductDialog() {
    final nomCtrl = TextEditingController();
    final marqueCtrl = TextEditingController();
    final prixCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '100');
    final descCtrl = TextEditingController();
    String selectedSupplier = '';
    String selectedCouleur = '#1565C0';
    Uint8List? imageBytes;
    List<Map<String, dynamic>> suppliers = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (suppliers.isEmpty) {
            _supabase.from('fournisseur').select('id, email').then((data) {
              setDialogState(() => suppliers = List<Map<String, dynamic>>.from(data));
            });
          }
          final couleurs = ['#1565C0', '#10B981', '#F59E0B', '#E53935', '#00B4D8', '#7C3AED', '#EC4899', '#6B7280'];
          return AlertDialog(
            title: const Text('Ajouter un produit'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom', prefixIcon: Icon(Icons.water_drop_rounded))),
                  const SizedBox(height: 10),
                  TextField(controller: marqueCtrl, decoration: const InputDecoration(labelText: 'Marque', prefixIcon: Icon(Icons.branding_watermark_rounded))),
                  const SizedBox(height: 10),
                  TextField(controller: prixCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix (FCFA)', prefixIcon: Icon(Icons.monetization_on_rounded))),
                  const SizedBox(height: 10),
                  TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock', prefixIcon: Icon(Icons.inventory_rounded))),
                  const SizedBox(height: 10),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined))),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedSupplier.isEmpty ? null : selectedSupplier,
                    decoration: const InputDecoration(labelText: 'Fournisseur', prefixIcon: Icon(Icons.business_rounded)),
                    items: suppliers.map((s) => DropdownMenuItem<String>(value: s['id']?.toString(), child: Text(s['email'] ?? '?'))).toList(),
                    onChanged: (v) { if (v != null) setDialogState(() => selectedSupplier = v); },
                  ),
                  const SizedBox(height: 16),
                  Text('Couleur', style: AppText.caption),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: couleurs.map((c) {
                      final isSel = selectedCouleur == c;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedCouleur = c),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Color(int.parse('FF${c.replaceAll('#', '')}', radix: 16)),
                            borderRadius: BorderRadius.circular(8),
                            border: isSel ? Border.all(color: Colors.black, width: 2.5) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Image picker
                  GestureDetector(
                    onTap: () async {
                      try {
                        final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200);
                        if (picked == null) return;
                        Uint8List bytes;
                        if (kIsWeb) {
                          bytes = await picked.readAsBytes();
                        } else {
                          final cropped = await ImageCropper().cropImage(
                            sourcePath: picked.path,
                            compressQuality: 90,
                            uiSettings: [AndroidUiSettings(toolbarTitle: 'Cadrer', toolbarColor: const Color(0xFF7C3AED), statusBarColor: const Color(0xFF7C3AED), activeControlsWidgetColor: const Color(0xFF7C3AED))],
                          );
                          if (cropped == null) return;
                          bytes = await cropped.readAsBytes();
                        }
                        setDialogState(() => imageBytes = _compress(bytes));
                      } catch (e) {
                        debugPrint('Image pick error: $e');
                      }
                    },
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(imageBytes!, width: double.infinity, fit: BoxFit.contain),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded, color: Colors.grey, size: 24),
                                SizedBox(width: 8),
                                Text('Ajouter une photo', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  if (nomCtrl.text.isEmpty || selectedSupplier.isEmpty) return;
                  try {
                    String? imageUrl;
                    if (imageBytes != null) {
                      final fileName = 'produits/${DateTime.now().millisecondsSinceEpoch}.jpg';
                      await _supabase.storage.from('produits').uploadBinary(fileName, imageBytes!,
                        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
                      );
                      imageUrl = _supabase.storage.from('produits').getPublicUrl(fileName);
                    }
                    await _supabase.from('produits').insert({
                      'nom': nomCtrl.text.trim(),
                      'marque': marqueCtrl.text.trim(),
                      'prix': double.parse(prixCtrl.text.trim()),
                      'stock': int.parse(stockCtrl.text.trim()),
                      'description': descCtrl.text.trim(),
                      'couleur_theme': selectedCouleur,
                      'fournisseur_id': selectedSupplier,
                      if (imageUrl != null) 'image_url': imageUrl,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Produit créé'),
                        backgroundColor: AppColors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ));
                    }
                  } catch (e) {
                    debugPrint("Erreur création produit: $e");
                  }
                },
                child: const Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        accentColor: const Color(0xFF7C3AED),
        child: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : IndexedStack(
                    index: _adminTab,
                    children: [
                      _buildStatsTab(),
                      _buildUsersTab(),
                      _buildProductsTab(),
                      _buildOrdersTab(),
                    ],
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      {'icon': Icons.dashboard_rounded, 'label': 'Vue d\'ensemble'},
      {'icon': Icons.people_rounded, 'label': 'Utilisateurs'},
      {'icon': Icons.inventory_2_rounded, 'label': 'Produits'},
      {'icon': Icons.receipt_long_rounded, 'label': 'Commandes'},
    ];

    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA855F7)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text('Administration', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17)),
                const Spacer(),
                GestureDetector(
                  onTap: _loadData,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: tabs.asMap().entries.map((e) {
              final i = e.key;
              final t = e.value;
              final isSelected = _adminTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _adminTab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF7C3AED).withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(t['icon'] as IconData, color: isSelected ? const Color(0xFF7C3AED) : AppColors.textLight, size: 20),
                        const SizedBox(height: 2),
                        Text(t['label'] as String, style: GoogleFonts.poppins(
                          color: isSelected ? const Color(0xFF7C3AED) : Colors.white54,
                          fontSize: 9, fontWeight: FontWeight.w700,
                        )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════
  //  TAB 0 : VUE D'ENSEMBLE
  // ═══════════════════════════════
  Widget _buildStatsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatCard('Commandes', '$_totalOrders', Icons.receipt_long_rounded, AppColors.primary),
                const SizedBox(width: 12),
                _buildStatCard('Revenu', '${_totalRevenue.toStringAsFixed(0)} FCFA', Icons.trending_up_rounded, AppColors.green),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard('En attente', '$_pendingOrders', Icons.hourglass_empty_rounded, AppColors.amber),
                const SizedBox(width: 12),
                _buildStatCard('En livraison', '$_activeDeliveries', Icons.local_shipping_rounded, AppColors.cyan),
              ],
            ),
            const SizedBox(height: 24),
            Text('UTILISATEURS', style: AppText.label),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildUserStatCard('Boutiquiers', '$_totalBoutiquiers', Icons.store_rounded, AppColors.primary),
                const SizedBox(width: 12),
                _buildUserStatCard('Fournisseurs', '$_totalFournisseurs', Icons.inventory_2_rounded, AppColors.amber),
                const SizedBox(width: 12),
                _buildUserStatCard('Livreurs', '$_totalLivreurs', Icons.delivery_dining_rounded, AppColors.cyan),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.08)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                Text(title, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white)),
            Text(title, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════
  //  TAB 1 : UTILISATEURS
  // ═══════════════════════════════
  Widget _buildUsersTab() {
    final tabs = [
      {'key': 'boutiquier', 'label': 'Boutiquiers', 'count': _totalBoutiquiers},
      {'key': 'fournisseur', 'label': 'Fournisseurs', 'count': _totalFournisseurs},
      {'key': 'livreur', 'label': 'Livreurs', 'count': _totalLivreurs},
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: tabs.map((t) {
                    final isSelected = _selectedUserTab == t['key'];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedUserTab = t['key'] as String);
                          _loadUsers();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF7C3AED).withValues(alpha: 0.1) : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected ? Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3), width: 1.5) : null,
                          ),
                          child: Column(
                            children: [
                              Text('${t['count']}', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16, color: isSelected ? const Color(0xFF7C3AED) : AppColors.textPrimary)),
                              Text(t['label'] as String, style: AppText.caption),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showAddUserDialog,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA855F7)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _users.isEmpty
              ? Center(child: Text('Aucun utilisateur', style: AppText.body))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final u = _users[index];
                    final roleColor = _selectedUserTab == 'fournisseur'
                        ? AppColors.amber
                        : _selectedUserTab == 'livreur'
                            ? AppColors.cyan
                            : AppColors.primary;
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
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: roleColor.withValues(alpha: 0.1),
                            child: Icon(Icons.person_rounded, color: roleColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u['email'] ?? 'Inconnu', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('ID: ${(u['id'] as String).substring(0, 8)}...', style: AppText.caption.copyWith(fontSize: 10)),
                              ],
                            ),
                          ),
                          if (_selectedUserTab == 'fournisseur')
                            Tooltip(
                              message: u['certifie'] == true ? 'Retirer la certification' : 'Certifier ce fournisseur',
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: GestureDetector(
                                onTap: () => _toggleCertification(u['id'] as String, u['certifie'] == true),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: u['certifie'] == true ? AppColors.cyan.withValues(alpha: 0.2) : AppColors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: u['certifie'] == true ? AppColors.cyan.withValues(alpha: 0.5) : AppColors.amber.withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        u['certifie'] == true ? Icons.verified_rounded : Icons.workspace_premium_outlined,
                                        color: u['certifie'] == true ? AppColors.cyan : AppColors.amber,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        u['certifie'] == true ? 'Certifié' : 'Certifier',
                                        style: GoogleFonts.poppins(
                                          color: u['certifie'] == true ? AppColors.cyan : AppColors.amber,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          GestureDetector(
                            onTap: () => _deleteUser(_selectedUserTab, u['id'] as String),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.red.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 18),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════
  //  TAB 2 : PRODUITS
  // ═══════════════════════════════
  Widget _buildProductsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_products.length} produit(s)', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
              GestureDetector(
                onTap: _showAddProductDialog,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA855F7)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _products.isEmpty
              ? Center(child: Text('Aucun produit', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    final couleur = p['couleur_theme']?.toString() ?? '#1565C0';
                    final color = Color(int.parse('FF${couleur.replaceAll('#', '')}', radix: 16));
                        final imageUrl = (p['image_url'] as String?)?.isNotEmpty == true ? p['image_url'] as String? : null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(imageUrl, width: 44, height: 44, fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                        child: Icon(Icons.water_drop_rounded, color: color, size: 22)),
                                  ),
                                )
                              : Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Icon(Icons.water_drop_rounded, color: color, size: 22),
                                ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['nom'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                                Text('${p['marque'] ?? ''} · ${(p['prix'] as num?)?.toStringAsFixed(0) ?? '0'} FCFA · Stock: ${p['stock'] ?? 0}',
                                    style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showEditProductDialog(p),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.cyan.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.edit_rounded, color: AppColors.cyan, size: 18),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _deleteProduct(p['id'] as String),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.red.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 18),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════
  //  TAB 3 : COMMANDES
  // ═══════════════════════════════
  Widget _buildOrdersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_orders.length} commande(s)', style: AppText.subheading),
              Text('${_totalRevenue.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _orders.isEmpty
              ? Center(child: Text('Aucune commande', style: AppText.body))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    final status = order.status;
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order))),
                      child: Container(
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
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: status.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(status.icon, color: status.color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('#${order.shortId.substring(0, 8)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                                  Text('${order.totalPrice.toStringAsFixed(0)} FCFA', style: AppText.caption),
                                ],
                              ),
                            ),
                            if (order.status != OrderStatus.livree && order.status != OrderStatus.payee)
                              GestureDetector(
                                onTap: () => _deleteOrder(order.id),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.cancel_outlined, color: AppColors.amber, size: 16),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: status.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(status.label, style: GoogleFonts.poppins(color: status.color, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
