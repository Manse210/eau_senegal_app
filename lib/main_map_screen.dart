import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'catalog_screen.dart';
import 'history_screen.dart';
import 'admin_screen.dart';
import 'theme/app_theme.dart';
import 'models/order_status.dart';

class MainMapScreen extends StatefulWidget {
  const MainMapScreen({super.key});


  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends State<MainMapScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  LatLng _positionLivreur = const LatLng(14.6912, -17.4624);
  LatLng _positionBoutiquier = const LatLng(14.7167, -17.4677); // Position mockée pour le prototype
  bool _isDeliveryActive = false;
  bool _chargement = true;
  String? _userRole;
  int _currentTab = 0;
  Timer? _timerSimulation;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _orderStatusSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _trackingSubscription;
  Timer? _timerNotifications;
  Map<String, String> _previousStatuses = {};
  List<Map<String, dynamic>> _realNotifications = [];
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
@override
void initState() {
  super.initState();
  final user = _supabase.auth.currentUser;
  _userRole = user?.userMetadata?['role'] ?? 'boutiquier';
  debugPrint("MapScreen initialisé pour le rôle : $_userRole");

  _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);
  _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
    CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
  );

  // Initialisation différée pour éviter de bloquer le thread principal au lancement
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initialiserSession();
  });
}

  Future<void> _initialiserSession() async {
    try {
      final user = _supabase.auth.currentUser;
      String role = 'boutiquier';
      if (user != null) {
        role = user.userMetadata?['role'] ?? 'boutiquier';
        try {
          final profile = await _supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
          if (profile != null) {
            role = profile['role'] ?? role;
          } else {
            await _supabase.from('profiles').insert({'id': user.id, 'email': user.email, 'role': role});
          }
        } catch (e) {
          debugPrint("Note: profiles table sync: $e");
        }

        if (mounted) {
          setState(() {
            _userRole = role;
            _chargement = false;
          });
        }
      } else {
        if (mounted) setState(() => _chargement = false);
      }
      
      _ecouterTrackingLivreur();
      if (role == 'boutiquier' || role == 'livreur') {
        _ecouterChangementsStatut();
      }
    } catch (e) {
      debugPrint("Erreur critique initialisation: $e");
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _ecouterChangementsStatut() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final userId = user.id;
    final role = _userRole ?? 'boutiquier';

    debugPrint("🔔 Initialisation notifications pour le rôle: $role (ID: $userId)");
    
    final filterColumn = role == 'livreur' ? 'livreur_id' : 'boutiquier_id';

    // 0. Charger l'état actuel pour peupler _previousStatuses (sans générer de notifications)
    try {
      final snapshot = await _supabase
          .from('commandes')
          .select()
          .eq(filterColumn, userId);
      for (final row in List<Map<String, dynamic>>.from(snapshot)) {
        final id = row['id'] as String;
        _previousStatuses[id] = row['status'] as String? ?? 'en_attente';
      }
      debugPrint("📦 Chargement initial: ${snapshot.length} commandes suivies");
    } catch (e) {
      debugPrint("⚠️ Erreur chargement initial commandes: $e");
    }

    // 1. Vérification secondaire (diagnostic)
    _supabase.from('commandes').select('id, status').eq(filterColumn, userId).then((data) {
      debugPrint("📦 Commandes trouvées pour ce $role: ${data.length}");
    });

    // 2. Stream Realtime (notifications instantanées)
    _orderStatusSubscription?.cancel();
    Stream<List<Map<String, dynamic>>> query = _supabase
        .from('commandes')
        .stream(primaryKey: ['id'])
        .eq(filterColumn, userId);

    _orderStatusSubscription = query.listen((data) {
      if (!mounted) return;
      _traiterDonneesNotifications(data);
    }, onError: (e) {
      debugPrint("❌ Erreur Stream Notifications: $e");
    });

    // 3. Polling périodique de secours (toutes les 10s)
    _timerNotifications?.cancel();
    _timerNotifications = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final data = await _supabase
            .from('commandes')
            .select()
            .eq(filterColumn, userId)
            .order('updated_at', ascending: false);
        
        if (mounted) _traiterDonneesNotifications(List<Map<String, dynamic>>.from(data));
      } catch (e) {
        debugPrint("⚠️ Polling notifications: $e");
      }
    });
  }

  void _traiterDonneesNotifications(List<Map<String, dynamic>> data) {
    for (final row in data) {
      final id = row['id'] as String;
      final newStatus = row['status'] as String? ?? '';
      final oldStatus = _previousStatuses[id];

      if (oldStatus != null && oldStatus != newStatus) {
        final statusObj = OrderStatus.fromCode(newStatus);
        final String orderName = row['nom'] ?? 'Commande #${id.substring(0, 5)}';
        final msg = '$orderName : ${statusObj.label}';

        debugPrint("🎁 Notification: $msg");

        setState(() {
          _realNotifications.insert(0, {
            'title': 'Mise à jour livraison',
            'body': msg,
            'time': '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            'icon': statusObj.icon,
            'color': statusObj.color,
          });
          if (_realNotifications.length > 20) _realNotifications.removeLast();
        });

        _showSnack(msg, color: statusObj.color);
      }

      _previousStatuses[id] = newStatus;
    }
  }

  Future<void> _ecouterTrackingLivreur() async {
    await Future.delayed(const Duration(milliseconds: 800));
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // 1. Trouver le livreur assigné à la commande active du boutiquier
    String? livreurIdASuivre;
    if (_userRole == 'boutiquier') {
      try {
        final activeOrder = await _supabase
            .from('commandes')
            .select('livreur_id, status')
            .eq('boutiquier_id', userId)
            .eq('status', 'en_livraison')
            .maybeSingle();
        
        if (activeOrder != null && activeOrder['livreur_id'] != null) {
          livreurIdASuivre = activeOrder['livreur_id'];
          if (mounted) setState(() => _isDeliveryActive = true);
        } else {
          // Si aucune commande n'est "en_livraison", on masque le trajet
          if (mounted) setState(() => _isDeliveryActive = false);
        }
      } catch (e) {
        debugPrint("Erreur recherche livreur assigné : $e");
      }
    } else if (_userRole == 'livreur') {
       // Pour le livreur, on vérifie s'il a au moins une commande active à livrer
       try {
         final response = await _supabase
            .from('commandes')
            .select('id')
            .eq('livreur_id', userId)
            .eq('status', 'en_livraison');
         
         final activeOrders = response as List;
         if (mounted) setState(() => _isDeliveryActive = activeOrders.isNotEmpty);
       } catch (_) {
         if (mounted) setState(() => _isDeliveryActive = false);
       }
    }

    // 2. Écouter le tracking de ce livreur
    _trackingSubscription?.cancel();
    if (livreurIdASuivre != null) {
      _trackingSubscription = _supabase
          .from('tracking_livreurs')
          .stream(primaryKey: ['id'])
          .eq('livreur_id', livreurIdASuivre)
          .handleError((e) => debugPrint("Erreur stream tracking: $e"))
          .listen((data) {
        try {
          if (data.isNotEmpty && mounted) {
            final row = data.first;
            final dynamic positionRaw = row['position'];
            if (positionRaw is String) {
              final cleanCoords = positionRaw.replaceAll('POINT(', '').replaceAll(')', '').trim().split(RegExp(r'\s+'));
              if (cleanCoords.length >= 2) {
                final lon = double.tryParse(cleanCoords[0]);
                final lat = double.tryParse(cleanCoords[1]);
                if (lat != null && lon != null) {
                  setState(() {
                    _positionLivreur = LatLng(lat, lon);
                  });
                  _mapController.move(_positionLivreur, _mapController.camera.zoom);
                }
              }
            }
          }
        } catch (parseError) {
          debugPrint("Erreur parse position: $parseError");
        }
      });
    }
  }

  Future<void> _demarrerGpsReel() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('Veuillez activer la localisation.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnack('Permission refusée.');
        return;
      }
    }

    _timerSimulation?.cancel();
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((position) async {
      try {
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) return;

        // On met à jour toutes les lignes de tracking pour ce livreur
        // Idéalement, on a une ligne par livreur ou par commande active
        await _supabase.from('tracking_livreurs').upsert({
          'livreur_id': userId,
          'position': 'POINT(${position.longitude} ${position.latitude})',
          'derniere_mise_a_jour': DateTime.now().toIso8601String(),
        }, onConflict: 'livreur_id'); 
        
      } catch (e) {
        debugPrint("Erreur GPS Update : $e");
        // Fallback si la contrainte unique sur livreur_id n'existe pas
        try {
           await _supabase.from('tracking_livreurs').insert({
            'livreur_id': _supabase.auth.currentUser?.id,
            'position': 'POINT(${position.longitude} ${position.latitude})',
          });
        } catch (_) {}
      }
    });
    _showSnack('GPS Actif !', color: AppColors.green);
  }

  @override
  void dispose() {
    _timerSimulation?.cancel();
    _positionStreamSubscription?.cancel();
    _orderStatusSubscription?.cancel();
    _trackingSubscription?.cancel();
    _timerNotifications?.cancel();
    _mapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _showNotifications() async {
    // Forcer une vérification live avant d'afficher le panneau
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final role = _userRole ?? 'boutiquier';
        final filterColumn = role == 'livreur' ? 'livreur_id' : 'boutiquier_id';
        final data = await _supabase
            .from('commandes')
            .select()
            .eq(filterColumn, user.id)
            .order('updated_at', ascending: false);
        if (mounted) _traiterDonneesNotifications(List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint("⚠️ Vérification live notifications: $e");
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0D2137),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Notifications', style: AppText.subheading.copyWith(color: Colors.white)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_realNotifications.length}', style: AppText.caption.copyWith(color: Colors.white54)),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_realNotifications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          color: AppColors.textLight.withValues(alpha: 0.5),
                          size: 48),
                      const SizedBox(height: 12),
                      Text('Aucune notification pour le moment',
                          style: AppText.body
                              .copyWith(color: AppColors.textLight)),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _realNotifications.length,
                  itemBuilder: (context2, index) {
                    final n = _realNotifications[index];
                    return _notificationItem(
                      (n['icon'] is IconData)
                          ? n['icon'] as IconData
                          : Icons.notifications_active_rounded,
                      (n['title'] ?? 'Notification').toString(),
                      (n['body'] ?? '').toString(),
                      (n['time'] ?? '').toString(),
                      color: (n['color'] is Color) ? n['color'] as Color : null,
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            if (_realNotifications.isNotEmpty)
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _realNotifications.clear();
                    });
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Tout effacer'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _notificationItem(IconData icon, String title, String subtitle, String time, {Color? color}) {
    final themeColor = color ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
             decoration: AppDecorations.iconBg(themeColor.withValues(alpha: 0.15)),
            child: Icon(icon, color: themeColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                Text(subtitle, style: AppText.caption.copyWith(color: Colors.white54), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(time, style: AppText.caption.copyWith(fontSize: 10, color: Colors.white38)),
        ],
      ),
    );
  }

  // --- UI RENDERERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1A2E),
      body: _buildScreen(),
      floatingActionButton:
          (_currentTab == 0 && _userRole == 'livreur') ? _buildFab() : null,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildScreen() {
    if (_chargement) return _buildLoader();
    
    if (_userRole == 'boutiquier') {
      switch (_currentTab) {
        case 0: return _buildMapBody();
        case 1: return CatalogScreen(onOrderPlaced: (_) {});
        case 2: return const HistoryScreen(role: 'boutiquier');
        case 3: return _buildProfileScreen();
      }
    } else if (_userRole == 'admin') {
      switch (_currentTab) {
        case 0: return _buildMapBody();
        case 1: return const AdminScreen();
        case 2: return _buildProfileScreen();
      }
    } else {
      switch (_currentTab) {
        case 0: return _buildMapBody();
        case 1: return HistoryScreen(role: _userRole);
        case 2: return _buildProfileScreen();
      }
    }
    return _buildMapBody();
  }

  Widget _buildMapBody() {
    return Column(
      children: [
        _buildMapHeader(_userRole == 'livreur'),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _positionLivreur,
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.sen_eau',
                  ),
                  if (_isDeliveryActive)
                    PolylineLayer<Object>(
                      polylines: [
                        Polyline(
                          points: [_positionLivreur, _positionBoutiquier],
                          color: AppColors.primary.withValues(alpha: 0.4),
                          strokeWidth: 4,
                          pattern: const StrokePattern.dotted(),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      // Marqueur Boutique
                      if (_isDeliveryActive)
                        Marker(
                          point: _positionBoutiquier,
                          width: 60,
                          height: 60,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: AppColors.green.withValues(alpha: 0.3), blurRadius: 10)
                              ],
                            ),
                            child: const Icon(Icons.store_rounded, color: AppColors.green, size: 30),
                          ),
                        ),
                      // Marqueur Livreur
                      Marker(
                        point: _positionLivreur,
                        width: 80,
                        height: 80,
                        child: ScaleTransition(
                          scale: _pulseAnim,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 40,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _buildInfoCard(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        backgroundColor: const Color(0xFF0D2137),
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: Colors.white38,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        items: _userRole == 'boutiquier' 
        ? [
          const BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Carte'),
          const BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), activeIcon: Icon(Icons.shopping_bag), label: 'Boutique'),
          const BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'Historique'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
        ]
        : _userRole == 'admin'
        ? [
          const BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Carte'),
          const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), activeIcon: Icon(Icons.dashboard), label: 'Admin'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
        ]
        : [
          const BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Carte'),
          const BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'Historique'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _demarrerGpsReel,
      icon: const Icon(Icons.gps_fixed),
      label: const Text("Activer GPS"),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildProfileScreen() {
    final user = _supabase.auth.currentUser;
    final roleColor = _userRole == 'fournisseur'
        ? AppColors.amber
        : _userRole == 'livreur'
            ? AppColors.cyan
            : AppColors.primary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar avec bordure gradient
            Container(
              width: 110,
              height: 110,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [roleColor, roleColor.withValues(alpha: 0.3)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: roleColor.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                child: Icon(Icons.person_rounded,
                    size: 50, color: roleColor),
              ),
            ),

            const SizedBox(height: 20),
            Text(user?.email ?? "Utilisateur", style: AppText.subheading.copyWith(color: Colors.white)),
            const SizedBox(height: 10),

            // Rôle badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    roleColor.withValues(alpha: 0.12),
                    roleColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: roleColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _userRole == 'fournisseur'
                        ? Icons.inventory_2_rounded
                        : _userRole == 'livreur'
                            ? Icons.delivery_dining_rounded
                            : Icons.store_rounded,
                    size: 16,
                    color: roleColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _userRole?.toUpperCase() ?? "INCONNU",
                    style: GoogleFonts.poppins(
                      color: roleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Carte d'info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.info_outline_rounded,
                            color: AppColors.primaryLight, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('Informations', style: AppText.subheading.copyWith(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _profileInfoRow(Icons.email_rounded, 'Email',
                      user?.email ?? "—"),
                  const SizedBox(height: 10),
                  _profileInfoRow(Icons.badge_rounded, 'Statut',
                      _userRole ?? "Inconnu"),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Déconnexion
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _supabase.auth.signOut();
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                label: Text(
                  "SE DÉCONNECTER",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.caption.copyWith(color: Colors.white54)),
            Text(value,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                )),
          ],
        ),
      ],
    );
  }

  Widget _buildMapHeader(bool isLivreur) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("sen-eau 💧", style: AppText.heading.copyWith(fontSize: 22, color: Colors.white)),
              Text(isLivreur ? "Mode Livreur - En route" : "Suivi de votre livraison", style: AppText.caption.copyWith(color: Colors.white54)),
            ],
          ),
          GestureDetector(
            onTap: _showNotifications,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: AppDecorations.iconBg(AppColors.primary),
                  child: const Icon(Icons.notifications_none, color: AppColors.primary),
                ),
                if (_realNotifications.isNotEmpty)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${_realNotifications.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: AppDecorations.iconBg(AppColors.green),
            child: const Icon(Icons.local_shipping, color: AppColors.green),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Livreur en approche", style: AppText.subheading.copyWith(fontSize: 16, color: Colors.white)),
                Text("Arrivée estimée : 12 min", style: AppText.caption.copyWith(color: Colors.white54)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white38),
        ],
      ),
    );
  }

  void _showSnack(String msg, {Color? color}) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color ?? AppColors.textPrimary));
  }
}
