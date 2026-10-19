import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);
  @override
  String toString() => message;
}

enum PaymentOutcome { success, failed, cancelled }

class PaymentResult {
  final PaymentOutcome outcome;
  final String? message;
  const PaymentResult(this.outcome, [this.message]);
}

class PaymentStart {
  final bool isFree;
  final String? paymentId;
  final String? gatewayUrl;
  final String? callbackUrl;

  const PaymentStart({
    required this.isFree,
    this.paymentId,
    this.gatewayUrl,
    this.callbackUrl,
  });
}

/// Talks to the "sslcommerz-payment" Supabase Edge Function.
/// The gateway secrets live only on the server, never in the app.
class PaymentService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<PaymentStart> startPayment(String courseId) async {
    final data = await _invoke({'action': 'create', 'courseId': courseId});
    if (data['free'] == true) return const PaymentStart(isFree: true);
    return PaymentStart(
      isFree: false,
      paymentId: data['paymentId'] as String,
      gatewayUrl: data['gatewayUrl'] as String,
      callbackUrl: data['callbackUrl'] as String,
    );
  }

  Future<PaymentResult> confirmPayment(String paymentId) async {
    final data = await _invoke({'action': 'execute', 'paymentId': paymentId});
    if (data['status'] == 'completed') {
      return const PaymentResult(PaymentOutcome.success);
    }
    return PaymentResult(
      PaymentOutcome.failed,
      (data['message'] as String?) ?? 'Payment was not completed.',
    );
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke('sslcommerz-payment', body: body);
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      throw PaymentException('Unexpected response from payment service.');
    } on FunctionException catch (e) {
      final details = e.details;
      final message = (details is Map && details['error'] is String)
          ? details['error'] as String
          : 'Payment service error (${e.status}).';
      throw PaymentException(message);
    }
  }
}