import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

// ═══════════════════════════════════════════════════
//  FOND DÉGRADÉ ANIMÉ avec bulles + accents radiaux
// ═══════════════════════════════════════════════════
class AppBackground extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final bool showBubbles;

  const AppBackground({
    super.key,
    required this.child,
    this.accentColor,
    this.showBubbles = true,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final accent = accentColor ?? AppColors.primary;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B1A2E),
            Color(0xFF0D2137),
            Color(0xFF0F243B),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Radial accent circles
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  accent.withValues(alpha: 0.10),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          Positioned(
            bottom: -100,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.primaryLight.withValues(alpha: 0.06),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // Bubbles
          if (showBubbles) ..._bubbles(size, accent),

          // Content
          child,
        ],
      ),
    );
  }

  List<Widget> _bubbles(Size size, Color accent) {
    final specs = [
      (0.08, 0.18, 60.0),
      (0.78, 0.28, 45.0),
      (0.50, 0.75, 55.0),
      (0.15, 0.80, 35.0),
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
              accent.withValues(alpha: 0.06),
              accent.withValues(alpha: 0.02),
            ]),
            border: Border.all(
              color: accent.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ═══════════════════════════════════════════════════
//  CARTE VITRÉE (glassmorphism — style page login)
// ═══════════════════════════════════════════════════
class AppGlassCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool hasShadow;

  const AppGlassCard({
    super.key,
    required this.child,
    this.borderColor,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 22,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.10),
              width: 0.8,
            ),
            boxShadow: hasShadow
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  EN-TÊTE GRADIENT style login (sans SliverAppBar)
// ═══════════════════════════════════════════════════
class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool bottomRounded;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.showBackButton = false,
    this.onBack,
    this.actions,
    this.bottomRounded = true,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primary;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 22,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.6)],
        ),
        borderRadius: bottomRounded
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              )
            : null,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (showBackButton)
                  GestureDetector(
                    onTap: onBack ?? () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  ICÔNE GRADIENT dans un conteneur circulaire
// ═══════════════════════════════════════════════════
class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const AppIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

// ═══════════════════════════════════════════════════
//  BADGE STATUT avec gradient
// ═══════════════════════════════════════════════════
class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: child);
    }
    return child;
  }
}

// ═══════════════════════════════════════════════════
//  BOUTON PRINCIPAL
// ═══════════════════════════════════════════════════
class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : icon != null
                ? Icon(icon, color: Colors.white)
                : const SizedBox.shrink(),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  INDICATEUR DE CHARGEMENT
// ═══════════════════════════════════════════════════
class AppLoader extends StatelessWidget {
  final Color? color;

  const AppLoader({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: color ?? AppColors.primary,
        strokeWidth: 3,
      ),
    );
  }
}
