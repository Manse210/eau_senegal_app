import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';
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

class _PaymentScreenState extends State<PaymentScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final _service = CinetPayService();

  String? _selectedMethod;
  bool _isProcessing = false;
  String? _transactionId;

  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;
  late AnimationController _successCtrl;
  late Animation<double> _successScale;

  final _methods = [
    {'id': 'wave', 'label': 'Wave', 'asset': 'assets/images/wave.png', 'color': const Color(0xFF00A2FF)},
    {'id': 'orange', 'label': 'Orange Money', 'asset': 'assets/images/Orange-Money.png', 'color': const Color(0xFFFF7900)},
    {'id': 'free', 'label': 'Free Money', 'asset': 'assets/images/free-money.png', 'color': const Color(0xFFE2001A)},
  ];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = CurvedAnimation(
        parent: _successCtrl, curve: Curves.elasticOut);
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _successCtrl.dispose();
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
          _successCtrl.forward();
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
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        accentColor: AppColors.primaryLight,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
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
          body: _transactionId != null
              ? _buildSuccess()
              : FadeTransition(
                  opacity: _entryFade,
                  child: SlideTransition(
                    position: _entrySlide,
                    child: _buildPaymentForm(),
                  ),
                ),
        ),
      ),
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
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 12),
                Text('Montant à payer', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
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
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),

          const SizedBox(height: 28),
          Text('MOYEN DE PAIEMENT', style: AppText.label),
          const SizedBox(height: 12),

          ..._methods.map((m) => GestureDetector(
            onTap: () =>
                setState(() => _selectedMethod = m['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _selectedMethod == m['id']
                    ? (m['color'] as Color).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _selectedMethod == m['id']
                      ? m['color'] as Color
                      : Colors.white.withValues(alpha: 0.06),
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
                          ? (m['color'] as Color).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
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
              fillColor: Colors.white.withValues(alpha: 0.05),
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
              color: AppColors.amber.withValues(alpha: 0.1),
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
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _effectuerPaiement,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.payment_rounded, color: Colors.white),
              label: Text(
                _isProcessing
                    ? 'PAIEMENT EN COURS...'
                    : 'PAYER ${widget.montant.toStringAsFixed(0)} FCFA',
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

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _successScale,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.green, Color(0xFF00E676)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 60),
              ),
            ),
            const SizedBox(height: 28),
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
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.shopping_bag_rounded,
                    color: Colors.white),
                label: const Text('RETOUR AU CATALOGUE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
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
}
