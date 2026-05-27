import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    super.key,
    required this.child,
    this.borderColor,
    this.padding = const EdgeInsets.all(28),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: Colors.white.withOpacity(0.07),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.25),
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
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final Color iconColor;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
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
            style: AppText.body.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppText.body.copyWith(color: AppColors.textPrimary.withOpacity(0.5)),
              prefixIcon: Icon(icon, color: iconColor.withOpacity(0.8), size: 20),
              suffixIcon: suffix != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: suffix,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            ),
          ),
        ),
      ),
    );
  }
}
