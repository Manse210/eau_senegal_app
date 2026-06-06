import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'theme/app_theme.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;

  const AddProductScreen({super.key, this.product});

  bool get isEditing => product != null;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _marqueController = TextEditingController();
  final _prixController = TextEditingController();
  final _stockController = TextEditingController(text: '100');
  final _descriptionController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isSubmitting = false;
  String _selectedCouleur = '#1565C0';
  Uint8List? _imageBytes;

  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;
  late AnimationController _colorCtrl;

  final List<Map<String, dynamic>> _couleursDisponibles = [
    {'label': 'Bleu (Kirène)', 'hex': '#1565C0'},
    {'label': 'Vert (Casamancaise)', 'hex': '#10B981'},
    {'label': 'Ambre (Baobab)', 'hex': '#F59E0B'},
    {'label': 'Rouge', 'hex': '#E53935'},
    {'label': 'Cyan', 'hex': '#00B4D8'},
    {'label': 'Violet', 'hex': '#7C3AED'},
    {'label': 'Rose', 'hex': '#EC4899'},
    {'label': 'Gris', 'hex': '#6B7280'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      final p = widget.product!;
      _nomController.text = p['nom'] as String? ?? '';
      _marqueController.text = p['marque'] as String? ?? '';
      _prixController.text = (p['prix'] as num?)?.toStringAsFixed(0) ?? '';
      _stockController.text = (p['stock'] as num?)?.toString() ?? '100';
      _descriptionController.text = p['description'] as String? ?? '';
      _selectedCouleur = p['couleur_theme'] as String? ?? '#1565C0';
    }
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _colorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _entryCtrl.forward();

    _prixController.addListener(_onFieldChanged);
    _stockController.addListener(_onFieldChanged);
    _nomController.addListener(_onFieldChanged);
    _marqueController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    _colorCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _colorCtrl.dispose();
    _nomController.dispose();
    _marqueController.dispose();
    _prixController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
      if (picked == null) return;
      Uint8List bytes;
      if (kIsWeb) {
        bytes = await picked.readAsBytes();
      } else {
                        final cropped = await ImageCropper().cropImage(
                          sourcePath: picked.path,
                          compressQuality: 90,
                          uiSettings: [AndroidUiSettings(toolbarTitle: 'Cadrer', toolbarColor: AppColors.primary, statusBarColor: AppColors.primary, activeControlsWidgetColor: AppColors.primary)],
                        );
        if (cropped == null) return;
        bytes = await cropped.readAsBytes();
      }
      setState(() => _imageBytes = _compress(bytes));
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      }
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

  Color _hexToColor(String hex) {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      String? imageUrl;
      if (_imageBytes != null) {
        final fileName = 'produits/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage.from('produits').uploadBinary(fileName, _imageBytes!,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
        imageUrl = _supabase.storage.from('produits').getPublicUrl(fileName);
      }

      final data = {
        'nom': _nomController.text.trim(),
        'marque': _marqueController.text.trim(),
        'prix': double.parse(_prixController.text.trim()),
        'stock': int.parse(_stockController.text.trim()),
        'description': _descriptionController.text.trim(),
        'couleur_theme': _selectedCouleur,
        if (imageUrl != null) 'image_url': imageUrl,
      };

      if (widget.isEditing) {
        await _supabase.from('produits').update(data).eq('id', widget.product!['id'] as String);
      } else {
        data['fournisseur_id'] = _supabase.auth.currentUser!.id;
        await _supabase.from('produits').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isEditing ? 'Produit modifié avec succès !' : 'Produit ajouté avec succès !'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Erreur ${widget.isEditing ? 'modification' : 'ajout'} produit : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final accentColor = _hexToColor(_selectedCouleur);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── DECORATIVE BUBBLES ──
          ..._buildBubbles(size, accentColor),

          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  accentColor.withValues(alpha: 0.10),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.cyan.withValues(alpha: 0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── MAIN CONTENT ──
          FadeTransition(
            opacity: _entryFade,
            child: SlideTransition(
              position: _entrySlide,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      child: Form(
                        key: _formKey,
                        child: _buildFormCard(accentColor),
                      ),
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                widget.isEditing ? 'Modifier le produit' : 'Nouveau produit',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBubbles(Size size, Color accent) {
    final specs = [
      (0.08, 0.25, 45.0),
      (0.78, 0.35, 55.0),
      (0.50, 0.75, 40.0),
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
              accent.withValues(alpha: 0.07),
              accent.withValues(alpha: 0.02),
            ]),
            border: Border.all(
              color: accent.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildFormCard(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text('Informations produit', style: AppText.subheading),
            ],
          ),
          const SizedBox(height: 24),
          _buildField(
            label: 'Nom du produit',
            controller: _nomController,
            hint: 'Eau minérale 1.5L',
            icon: Icons.water_drop_rounded,
          ),
          const SizedBox(height: 18),
          _buildField(
            label: 'Marque',
            controller: _marqueController,
            hint: 'Kirène',
            icon: Icons.branding_watermark_rounded,
          ),
          const SizedBox(height: 18),
          _buildField(
            label: 'Prix (FCFA)',
            controller: _prixController,
            hint: '1500',
            icon: Icons.monetization_on_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),
          _buildField(
            label: 'Stock initial',
            controller: _stockController,
            hint: '100',
            icon: Icons.inventory_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),
          _buildField(
            label: 'Description',
            controller: _descriptionController,
            hint: 'Pack de 12 bouteilles de 1.5L',
            icon: Icons.description_outlined,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          // Image picker
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.image_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text('Photo du produit', style: AppText.subheading),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withValues(alpha: 0.2), width: 1.5),
              ),
              child: _imageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(_imageBytes!, fit: BoxFit.contain, width: double.infinity),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded, color: accent, size: 32),
                        const SizedBox(height: 4),
                        Text('Ajouter une photo', style: AppText.caption.copyWith(color: accent)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.palette_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text('Couleur de la marque', style: AppText.subheading),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _couleursDisponibles.map((c) {
              final isSelected = _selectedCouleur == c['hex'];
              final color = _hexToColor(c['hex'] as String);
              return GestureDetector(
                onTap: () => setState(() => _selectedCouleur = c['hex'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.12)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: isSelected
                        ? Border.all(color: color, width: 2)
                        : Border.all(
                            color: AppColors.divider, width: 0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(c['label'] as String, style: AppText.caption),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitProduct,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_rounded, size: 22),
              label: Text(
                _isSubmitting
                    ? 'EN COURS...'
                    : widget.isEditing
                        ? 'MODIFIER LE PRODUIT'
                        : 'AJOUTER LE PRODUIT',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            prefixIconConstraints: const BoxConstraints(
                minWidth: 48, minHeight: 36),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Champ requis' : null,
        ),
      ],
    );
  }
}
