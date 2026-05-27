import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _marqueController = TextEditingController();
  final _prixController = TextEditingController();
  final _stockController = TextEditingController(text: '100');
  final _descriptionController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isSubmitting = false;
  String _selectedCouleur = '#1565C0';

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
  void dispose() {
    _nomController.dispose();
    _marqueController.dispose();
    _prixController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await _supabase.from('produits').insert({
        'nom': _nomController.text.trim(),
        'marque': _marqueController.text.trim(),
        'prix': double.parse(_prixController.text.trim()),
        'stock': int.parse(_stockController.text.trim()),
        'description': _descriptionController.text.trim(),
        'couleur_theme': _selectedCouleur,
        'fournisseur_id': _supabase.auth.currentUser!.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Produit ajouté avec succès !'),
          backgroundColor: AppColors.green,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Erreur ajout produit : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nouveau produit'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: AppDecorations.card(radius: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Informations produit', style: AppText.subheading),
                    const SizedBox(height: 20),
                    _buildField('Nom du produit', _nomController, 'Eau minérale 1.5L'),
                    const SizedBox(height: 16),
                    _buildField('Marque', _marqueController, 'Kirène'),
                    const SizedBox(height: 16),
                    _buildField('Prix (FCFA)', _prixController, '1500',
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    _buildField('Stock initial', _stockController, '100',
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    _buildField('Description', _descriptionController,
                        'Pack de 12 bouteilles de 1.5L',
                        maxLines: 3),
                    const SizedBox(height: 20),
                    Text('Couleur de la marque', style: AppText.caption),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _couleursDisponibles.map((c) {
                        final isSelected = _selectedCouleur == c['hex'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCouleur = c['hex'] as String),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color(int.parse(
                                          'FF${(c['hex'] as String).replaceAll('#', '')}',
                                          radix: 16))
                                      .withOpacity(0.15)
                                  : AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(14),
                              border: isSelected
                                  ? Border.all(
                                      color: Color(int.parse(
                                          'FF${(c['hex'] as String).replaceAll('#', '')}',
                                          radix: 16)),
                                      width: 2)
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(
                                        'FF${(c['hex'] as String).replaceAll('#', '')}',
                                        radix: 16)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(c['label'] as String,
                                    style: AppText.caption),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitProduct,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('AJOUTER LE PRODUIT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      String hint, {TextInputType? keyboardType, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Champ requis' : null,
        ),
      ],
    );
  }
}