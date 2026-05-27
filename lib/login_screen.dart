import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';

// ─────────────────────────────────────────────
//  ROLE MODEL
// ─────────────────────────────────────────────
class _RoleOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color gradientEnd;

  const _RoleOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.gradientEnd,
  });
}

const _roles = [
  _RoleOption(
    value: 'boutiquier',
    label: 'Boutiquier',
    icon: Icons.storefront_rounded,
    color: Color(0xFF0EA5E9),
    gradientEnd: Color(0xFF0369A1),
  ),
  _RoleOption(
    value: 'livreur',
    label: 'Livreur',
    icon: Icons.local_shipping_rounded,
    color: Color(0xFF06B6D4),
    gradientEnd: Color(0xFF0E7490),
  ),
  _RoleOption(
    value: 'fournisseur',
    label: 'Fournisseur',
    icon: Icons.factory_rounded,
    color: Color(0xFFF59E0B),
    gradientEnd: Color(0xFFB45309),
  ),
];

// ─────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  int _selectedRoleIndex = 0;

  // Animations
  late AnimationController _bgCtrl;
  late Animation<double> _bgAnim;

  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  late AnimationController _rippleCtrl;

  _RoleOption get _role => _roles[_selectedRoleIndex];

  @override
  void initState() {
    super.initState();

    // Slow background bubble drift
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);

    // Entry animation
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();

    // Role color transition ripple
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  void _selectRole(int index) {
    if (_selectedRoleIndex == index) return;
    setState(() => _selectedRoleIndex = index);
    _rippleCtrl.forward(from: 0);
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      if (res.user != null && mounted) {
        final metadataRole = res.user!.userMetadata?['role'] as String?;
        if (metadataRole != null && metadataRole != _role.value) {
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            _showError(
              'Ce compte est un compte "${_roleLabel(metadataRole)}", '
              'pas "${_role.label}".\nSélectionnez le bon rôle.',
            );
          }
          return;
        }
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _roleLabel(String value) {
    for (final r in _roles) {
      if (r.value == value) return r.label;
    }
    return value;
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        data: {'role': _role.value},
      );
      if (mounted && res.user != null) {
        await _insertProfile(res.user!.id);
        _showSuccess('Inscription réussie ! Vérifiez vos emails.');
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _insertProfile(String uid) async {
    final data = {
      'id': uid,
      'role': _role.value,
    };
    try {
      await Supabase.instance.client.from(_role.value).insert(data);
    } catch (e) {
      debugPrint('role table insert: $e');
    }
    try {
      await Supabase.instance.client.from('profiles').insert(data);
    } catch (e) {
      debugPrint('profiles insert: $e');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0B1A2E),
              const Color(0xFF0D2137),
              _role.color.withOpacity(0.25),
            ],
          ),
        ),
        child: Stack(
          children: [
            // ── BACKGROUND WATER BUBBLES ──
            ..._buildBubbles(size),

            // ── DIAGONAL ACCENT LINE ──
            Positioned(
              top: -60,
              right: -60,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _role.color.withOpacity(0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _role.gradientEnd.withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── SCROLL CONTENT ──
            FadeTransition(
              opacity: _entryFade,
              child: SlideTransition(
                position: _entrySlide,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image pleine largeur (sans SafeArea ni padding)
                      _buildCoverImage(),
                      // Reste du contenu avec padding horizontal
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 28),
                            _buildGlassCard(),
                            const SizedBox(height: 24),
                            _buildForgotPassword(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  ANIMATED WATER BUBBLES
  // ─────────────────────────────────────────────
  List<Widget> _buildBubbles(Size size) {
    final specs = [
      (0.08, 0.12, 80.0, 0.0),
      (0.72, 0.22, 55.0, 0.3),
      (0.45, 0.65, 100.0, 0.6),
      (0.15, 0.75, 45.0, 0.1),
      (0.88, 0.55, 70.0, 0.8),
    ];
    return specs.map((s) {
      return AnimatedBuilder(
        animation: _bgAnim,
        builder: (_, __) {
          final dy = math.sin((_bgAnim.value + s.$4) * math.pi) * 18;
          return Positioned(
            left: size.width * s.$1,
            top: size.height * s.$2 + dy,
            child: Container(
              width: s.$3,
              height: s.$3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _role.color.withOpacity(0.10),
                    _role.color.withOpacity(0.03),
                  ],
                ),
                border: Border.all(
                  color: _role.color.withOpacity(0.12),
                  width: 1,
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  // ─────────────────────────────────────────────
  //  COVER IMAGE PLEINE LARGEUR
  // ─────────────────────────────────────────────
  Widget _buildCoverImage() {
    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── IMAGE LOCALE ──
          Image.asset(
            'assets/images/im_eau.webp',
            fit: BoxFit.cover,
          ),

          // ── DÉGRADÉ SUPERPOSÉ (haut → transparent → bas opaque) ──
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 1.0],
                colors: [
                  const Color(0xFF0B1A2E).withOpacity(0.55),
                  Colors.transparent,
                  const Color(0xFF0B1A2E),
                ],
              ),
            ),
          ),

          // ── TEINTE COULEUR DU RÔLE ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  _role.color.withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // ── TITRE POSITIONNÉ EN BAS ──
          Positioned(
            left: 24,
            right: 24,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Eau Sénégal',
                  style: GoogleFonts.outfit(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Plateforme de distribution d'eau",
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.70),
                    letterSpacing: 0.2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── BADGE RÔLE ACTIF (haut droite) ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            right: 18,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _role.color.withOpacity(0.22),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _role.color.withOpacity(0.55),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _role.color.withOpacity(0.25),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_role.icon, color: _role.color, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _role.label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _role.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  GLASS CARD
  // ─────────────────────────────────────────────
  Widget _buildGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: Colors.white.withOpacity(0.07),
            border: Border.all(
              color: _role.color.withOpacity(0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Heading
              Text(
                'Connexion',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bienvenue sur votre espace !',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.50),
                ),
              ),
              const SizedBox(height: 28),

              // EMAIL FIELD
              _buildGlassField(
                controller: _emailCtrl,
                hint: 'Adresse email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),

              // PASSWORD FIELD
              _buildGlassField(
                controller: _passwordCtrl,
                hint: 'Mot de passe',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textPrimary.withOpacity(0.6),
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ROLE LABEL
              Text(
                'Je suis un :',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.55),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),

              // ROLE SELECTOR ROW
              Row(
                children: List.generate(
                  _roles.length,
                      (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                      child: _buildRoleChip(i),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // BUTTONS
              if (_isLoading)
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    child: CircularProgressIndicator(color: _role.color),
                  ),
                )
              else ...[
                _buildPrimaryButton(),
                const SizedBox(height: 12),
                _buildSecondaryButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  GLASS TEXT FIELD
  // ─────────────────────────────────────────────
  Widget _buildGlassField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(
                color: AppColors.textPrimary.withOpacity(0.5),
                fontSize: 15,
              ),
              prefixIcon: Icon(icon,
                  color: _role.color.withOpacity(0.8), size: 20),
              suffixIcon: suffix != null
                  ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: suffix,
              )
                  : null,
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  ROLE CHIP
  // ─────────────────────────────────────────────
  Widget _buildRoleChip(int index) {
    final role = _roles[index];
    final isSelected = _selectedRoleIndex == index;

    return GestureDetector(
      onTap: () => _selectRole(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? role.color.withOpacity(0.20)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? role.color : Colors.white.withOpacity(0.10),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: role.color.withOpacity(0.30),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? role.color.withOpacity(0.25)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(role.icon,
                  color: isSelected ? role.color : Colors.white.withOpacity(0.4),
                  size: 20),
            ),
            const SizedBox(height: 7),
            Text(
              role.label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight:
                isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? role.color : Colors.white.withOpacity(0.45),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  PRIMARY BUTTON
  // ─────────────────────────────────────────────
  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_role.color, _role.gradientEnd],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _role.color.withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _signIn,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withOpacity(0.15),
            child: Center(
              child: Text(
                'SE CONNECTER',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  SECONDARY BUTTON
  // ─────────────────────────────────────────────
  Widget _buildSecondaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _role.color.withOpacity(0.40),
                width: 1.2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _signUp,
                borderRadius: BorderRadius.circular(16),
                splashColor: _role.color.withOpacity(0.10),
                child: Center(
                  child: Text(
                    'CRÉER UN COMPTE',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _role.color,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  FORGOT PASSWORD
  // ─────────────────────────────────────────────
  Widget _buildForgotPassword() {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        overlayColor: _role.color.withOpacity(0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        'Mot de passe oublié ?',
        style: GoogleFonts.outfit(
          fontSize: 14,
          color: _role.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  WATER DROP ILLUSTRATED LOGO PAINTER
//
//  Dessine une goutte d'eau stylisée avec :
//  • un fond dégradé vertical (colorTop → colorBottom)
//  • un reflet blanc ovale en haut à gauche
//  • une vague intérieure à la base (2 couches)
//  • un éclat de lumière subtil
//  Le tout sans aucun asset externe.
// ─────────────────────────────────────────────
class _WaterDropLogoPainter extends CustomPainter {
  final Color colorTop;
  final Color colorBottom;

  const _WaterDropLogoPainter({
    required this.colorTop,
    required this.colorBottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── 1. FORME GOUTTE ──
    // Une goutte orientée vers le haut : base ronde, pointe haute
    final dropPath = _buildDropPath(w, h);

    // Dégradé principal
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [colorTop, colorBottom],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(dropPath, Paint()..shader = gradient);

    // Contour léger
    canvas.drawPath(
      dropPath,
      Paint()
        ..color = Colors.white.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── 2. VAGUE INTÉRIEURE (couche sombre) ──
    canvas.save();
    canvas.clipPath(dropPath);

    final waveBase = h * 0.62;
    final wave1 = Path();
    wave1.moveTo(0, waveBase);
    wave1.cubicTo(
      w * 0.22, waveBase - h * 0.10,
      w * 0.55, waveBase + h * 0.10,
      w, waveBase,
    );
    wave1.lineTo(w, h);
    wave1.lineTo(0, h);
    wave1.close();
    canvas.drawPath(
      wave1,
      Paint()..color = colorBottom.withOpacity(0.55),
    );

    // Couche claire par-dessus
    final wave2 = Path();
    final waveBase2 = h * 0.68;
    wave2.moveTo(0, waveBase2);
    wave2.cubicTo(
      w * 0.30, waveBase2 - h * 0.08,
      w * 0.65, waveBase2 + h * 0.09,
      w, waveBase2,
    );
    wave2.lineTo(w, h);
    wave2.lineTo(0, h);
    wave2.close();
    canvas.drawPath(
      wave2,
      Paint()..color = Colors.white.withOpacity(0.12),
    );

    canvas.restore();

    // ── 3. REFLET PRINCIPAL (ovale blanc haut-gauche) ──
    canvas.save();
    canvas.clipPath(dropPath);
    final reflectPaint = Paint()
      ..color = Colors.white.withOpacity(0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.36, h * 0.28),
        width: w * 0.28,
        height: h * 0.14,
      ),
      reflectPaint,
    );
    canvas.restore();

    // ── 4. ÉCLAT DE LUMIÈRE (petit point brillant) ──
    canvas.save();
    canvas.clipPath(dropPath);
    canvas.drawCircle(
      Offset(w * 0.38, h * 0.22),
      w * 0.055,
      Paint()..color = Colors.white.withOpacity(0.70),
    );
    canvas.restore();
  }

  // Construit le path de la goutte :
  // pointe en haut, ventre arrondi vers le bas.
  Path _buildDropPath(double w, double h) {
    final cx = w / 2;
    final path = Path();

    // Point haut (pointe de la goutte)
    path.moveTo(cx, h * 0.04);

    // Courbe droite : pointe → flanc droit → bas
    path.cubicTo(
      cx + w * 0.55, h * 0.35,   // cp1
      w * 0.96,      h * 0.68,   // cp2
      cx,            h * 0.97,   // bas
    );

    // Courbe gauche : bas → flanc gauche → pointe
    path.cubicTo(
      w * 0.04,      h * 0.68,   // cp1
      cx - w * 0.55, h * 0.35,   // cp2
      cx,            h * 0.04,   // retour pointe
    );

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_WaterDropLogoPainter old) =>
      old.colorTop != colorTop || old.colorBottom != colorBottom;
}
