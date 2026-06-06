class CinetPayResult {
  final bool success;
  final String transactionId;
  final String? errorMessage;

  CinetPayResult({
    required this.success,
    required this.transactionId,
    this.errorMessage,
  });
}

class CinetPayService {
  // ⚠️ Clé LIVE — Ne pas committer sans .env
  static const bool modeSimulation = true; // TODO: false une fois le site_id renseigné
  static final String _apiKey = const String.fromEnvironment('CINETPAY_API_KEY', defaultValue: '');
  static const String _siteId = ''; // TODO: demande à CinetPay

  Future<CinetPayResult> initierPaiement({
    required String orderId,
    required double montant,
    required String devise,
    required String telephone,
    required String nomClient,
  }) async {
    final transactionId = 'TXN_${orderId.substring(0, 8)}';

    if (modeSimulation) {
      await Future.delayed(const Duration(seconds: 2));
      return CinetPayResult(
        success: true,
        transactionId: transactionId,
      );
    }

    try {
      // final response = await http.post(
      //   Uri.parse('https://api.cinetpay.com/v1/?method=processPayment'),
      //   body: {
      //     'apikey': _apiKey,
      //     'site_id': _siteId,
      //     'transaction_id': transactionId,
      //     'amount': montant.toStringAsFixed(0),
      //     'currency': devise,
      //     'description': 'Commande #$orderId',
      //     'notify_url': 'https://ton-site.com/webhook',
      //     'customer_name': nomClient,
      //     'customer_phone': telephone,
      //     'channels': 'MOBILE_MONEY',
      //     'language': 'fr',
      //   },
      // );
      // if (response.statusCode == 200) {
      //   final data = jsonDecode(response.body);
      //   if (data['status'] == 'success' || data['code'] == '00') {
      //     return CinetPayResult(success: true, transactionId: transactionId);
      //   }
      // }
      return CinetPayResult(
        success: false,
        transactionId: transactionId,
        errorMessage: 'Erreur API CinetPay',
      );
    } catch (e) {
      return CinetPayResult(
        success: false,
        transactionId: transactionId,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> verifierStatut(String transactionId) async {
    if (modeSimulation) return true;

    // final response = await http.post(
    //   Uri.parse('https://api.cinetpay.com/v1/?method=checkPayStatus'),
    //   body: {
    //     'apikey': _apiKey,
    //     'site_id': _siteId,
    //     'transaction_id': transactionId,
    //   },
    // );
    return false;
  }
}
