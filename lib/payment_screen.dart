import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'services/cinetpay_service.dart';

class PaymentScreen extends StatefulWidget {
  final String orderId;
  final double montant;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.montant,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _phoneController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final _service = CinetPayService();

  String? _selectedMethod;
  bool _isProcessing = false;
  String? _transactionId;

  final _methods = [
    {'id': 'wave', 'label': 'Wave', 'asset': 'assets/images/wave.png', 'color': const Color(0xFF00A2FF)},
    {'id': 'orange', 'label': 'Orange Money', 'asset': 'assets/images/Orange-Money.png', 'color': const Color(0xFFFF7900)},
    {'id': 'free', 'label': 'Free Money', 'asset': 'assets/images/free-money.png', 'color': const Color(0xFFE2001A)},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _effectuerPaiement() async {
    if (_selectedMethod == null) {
      _showError('Sélectionnez un moyen de paiement');
      return;
    }
    if (_phoneController.text.trim().length < 8) {
      _showError('Entrez un numéro de téléphone valide');
      return;
    }

    setState(() => _isProcessing = true);

    final user = _supabase.auth.currentUser;
    final nomClient = user?.email ?? 'Client';

    final result = await _service.initierPaiement(
      orderId: widget.orderId,
      montant: widget.montant,
      devise: 'XOF',
      telephone: _phoneController.text.trim(),
      nomClient: nomClient,
    );

    if (result.success) {
      try {
        // Marquer la commande comme payée
        await _supabase
            .from('commandes')
            .update({
              'status': 'payee',
              'payment_method': _selectedMethod,
            })
            .eq('id', widget.orderId);

        if (mounted) {
          setState(() {
            _transactionId = result.transactionId;
            _isProcessing = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError('Erreur mise à jour commande: $e');
        }
      }
    } else {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError(result.errorMessage ?? 'Paiement échoué');
      }
    }
  }

  String _labelForMethod(String? id) {
    for (final m in _methods) {
      if (m['id'] == id) return m['label'] as String;
    }
    return id ?? 'Paiement';
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary, size: 20),
          ),
        ),
        title: Text('Paiement', style: AppText.subheading),
      ),
      body: _transactionId != null ? _buildSuccess() : _buildPaymentForm(),
    );
  }

  Widget _buildPaymentForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: AppDecorations.card(radius: 24),
            child: Column(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    size: 40, color: AppColors.primary),
                const SizedBox(height: 12),
                Text('Montant à payer', style: AppText.caption),
                const SizedBox(height: 4),
                Text(
                  '${widget.montant.toStringAsFixed(0)} FCFA',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text('#${widget.orderId.substring(0, 8)}',
                    style: AppText.caption),
              ],
            ),
          ),

          const SizedBox(height: 28),
          Text('MOYEN DE PAIEMENT', style: AppText.label),
          const SizedBox(height: 12),

          ..._methods.map((m) => GestureDetector(
            onTap: () => setState(() => _selectedMethod = m['id'] as String),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _selectedMethod == m['id']
                    ? (m['color'] as Color).withOpacity(0.1)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _selectedMethod == m['id']
                      ? m['color'] as Color
                      : AppColors.divider,
                  width: _selectedMethod == m['id'] ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _selectedMethod == m['id']
                          ? (m['color'] as Color).withOpacity(0.15)
                          : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        m['asset'] as String,
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.payment_rounded,
                          color: m['color'] as Color,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      m['label'] as String,
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (_selectedMethod == m['id'])
                    Icon(Icons.check_circle_rounded,
                        color: m['color'] as Color, size: 24),
                ],
              ),
            ),
          )),

          const SizedBox(height: 20),
          Text('NUMÉRO DE TÉLÉPHONE', style: AppText.label),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.poppins(fontSize: 15),
            decoration: InputDecoration(
              hintText: '77 123 45 67',
              hintStyle: AppText.caption,
              prefixIcon: const Icon(Icons.phone_rounded, size: 20),
              prefixText: '+221 ',
              prefixStyle: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    CinetPayService.modeSimulation
                        ? 'Mode simulation : aucun débit réel'
                        : 'Vous recevrez une demande de paiement sur votre téléphone',
                    style: AppText.caption.copyWith(color: AppColors.amber),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _effectuerPaiement,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('PAYER ${widget.montant.toStringAsFixed(0)} FCFA',
                      style: AppText.button.copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.green, size: 56),
            ),
            const SizedBox(height: 24),
            Text('Paiement réussi !', style: AppText.subheading),
            const SizedBox(height: 8),
            Text(
              'Transaction #$_transactionId',
              style: AppText.caption,
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.montant.toStringAsFixed(0)} FCFA · ${_labelForMethod(_selectedMethod)}',
              style: AppText.body,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('RETOUR AU CATALOGUE',
                    style: AppText.button.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
