import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'app_theme.dart';
import 'payment_service.dart';

/// Shows the SSLCommerz checkout page.
///
/// - Android / iOS: the checkout opens inside the app (WebView). When the
///   gateway finishes it redirects to our callback URL, which we spot here.
/// - Web (Chrome): WebView does not exist there, so the checkout opens in a
///   new browser tab and the student comes back and taps "I have paid".
///
/// In both cases the server verifies the payment with SSLCommerz before the
/// course unlocks. Pops with a [PaymentResult].
class PaymentGatewayPage extends StatefulWidget {
  final PaymentStart start;
  const PaymentGatewayPage({super.key, required this.start});

  @override
  State<PaymentGatewayPage> createState() => _PaymentGatewayPageState();
}

class _PaymentGatewayPageState extends State<PaymentGatewayPage> {
  final _paymentService = PaymentService();
  WebViewController? _controller;

  bool _pageLoading = true;
  bool _confirming = false;
  bool _handled = false;
  bool _openedInTab = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _openCheckoutTab();
    } else {
      _setUpWebView();
    }
  }

  // ---------------------------------------------------------------- WEB ----

  Future<void> _openCheckoutTab() async {
    final ok = await launchUrl(
      Uri.parse(widget.start.gatewayUrl!),
      webOnlyWindowName: '_blank',
    );
    if (mounted) setState(() => _openedInTab = ok);
  }

  Future<void> _confirmFromWeb() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      final result = await _paymentService.confirmPayment(widget.start.paymentId!);
      _finish(result);
    } on PaymentException catch (e) {
      if (mounted) setState(() => _confirming = false);
      _showMessage(e.message);
    } catch (_) {
      if (mounted) setState(() => _confirming = false);
      _showMessage('Could not confirm the payment. Please try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildWebBody() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'Complete your payment',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                _openedInTab
                    ? 'The SSLCommerz checkout page opened in a new tab. '
                        'Finish the payment there, then come back to this tab '
                        'and tap the button below.\n\n'
                        '(After paying, the new tab may show a short message. '
                        'You can ignore it and close that tab.)'
                    : 'Your browser blocked the checkout tab. Tap "Open checkout" '
                        'to try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirming ? null : _confirmFromWeb,
                  child: _confirming
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('I have paid'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _confirming ? null : _openCheckoutTab,
                  child: const Text('Open checkout'),
                ),
              ),
              TextButton(
                onPressed: _confirming
                    ? null
                    : () => _finish(const PaymentResult(PaymentOutcome.cancelled)),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------- ANDROID / iOS ----

  void _setUpWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => _checkUrl(url),
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) _checkUrl(url);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _pageLoading = false);
          },
          onNavigationRequest: (request) {
            if (_checkUrl(request.url)) return NavigationDecision.prevent;
            final scheme = Uri.tryParse(request.url)?.scheme ?? '';
            if (scheme != 'http' && scheme != 'https') {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.start.gatewayUrl!));
  }

  /// Returns true if [url] is our callback URL (and handles it).
  /// Checked from several WebView callbacks because Android does not always
  /// report form-POST redirects through onNavigationRequest.
  bool _checkUrl(String url) {
    if (!url.startsWith(widget.start.callbackUrl!)) return false;
    _handleCallback(Uri.parse(url));
    return true;
  }

  Future<void> _handleCallback(Uri uri) async {
    if (_handled) return;
    _handled = true;

    final result = uri.queryParameters['result'];
    if (result == 'cancel') {
      _finish(const PaymentResult(PaymentOutcome.cancelled));
      return;
    }
    if (result != 'success') {
      _finish(const PaymentResult(
          PaymentOutcome.failed, 'Payment failed. Please try again.'));
      return;
    }

    if (mounted) setState(() => _confirming = true);
    try {
      final tranId = uri.queryParameters['tran_id'] ?? widget.start.paymentId!;
      final result = await _paymentService.confirmPayment(tranId);
      _finish(result);
    } on PaymentException catch (e) {
      _finish(PaymentResult(PaymentOutcome.failed, e.message));
    } catch (_) {
      _finish(const PaymentResult(
        PaymentOutcome.failed,
        'Could not confirm your payment. If money was deducted, check My Courses '
        'in a few minutes or contact support.',
      ));
    }
  }

  // ------------------------------------------------------------- COMMON ----

  void _finish(PaymentResult result) {
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_confirming,
      child: Scaffold(
        appBar: AppBar(title: const Text('Secure Payment')),
        body: kIsWeb
            ? _buildWebBody()
            : Stack(
                children: [
                  WebViewWidget(controller: _controller!),
                  if (_pageLoading)
                    const Center(child: CircularProgressIndicator()),
                  if (_confirming)
                    Container(
                      color: AppColors.background,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Confirming your payment...'),
                            SizedBox(height: 4),
                            Text('Please do not close the app.'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}