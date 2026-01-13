import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/midtrans_service.dart';
import '../../../core/models/payment.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String redirectUrl;
  final String orderId;
  final Function(PaymentStatus status, String? message) onPaymentCompleted;

  const PaymentWebViewScreen({
    super.key,
    required this.redirectUrl,
    required this.orderId,
    required this.onPaymentCompleted,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  final MidtransService _midtransService = MidtransService();
  bool _isLoading = true;
  bool _hasCompletedPayment = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (String url) {
          setState(() {
            _isLoading = true;
          });
          _handleUrlNavigation(url);
        },
        onPageFinished: (String url) {
          setState(() {
            _isLoading = false;
          });
          _handleUrlNavigation(url);
        },
        onWebResourceError: (WebResourceError error) {
          if (!_hasCompletedPayment) {
            widget.onPaymentCompleted(
              PaymentStatus.failed,
              'Network error: ${error.description}',
            );
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.redirectUrl));
  }

  void _handleUrlNavigation(String url) {
    if (_hasCompletedPayment) return;

    // Check for success URLs
    if (url.contains('success') || 
        url.contains('settlement') || 
        url.contains('transaction_status=settlement')) {
      _checkPaymentStatus(expectSuccess: true);
    }
    
    // Check for failure URLs
    else if (url.contains('error') || 
             url.contains('failure') || 
             url.contains('cancel') ||
             url.contains('transaction_status=cancel') ||
             url.contains('transaction_status=deny') ||
             url.contains('transaction_status=expire')) {
      _checkPaymentStatus(expectSuccess: false);
    }
    
    // Check for pending URLs
    else if (url.contains('pending') || 
             url.contains('transaction_status=pending')) {
      _checkPaymentStatus(expectSuccess: null); // null = pending
    }
  }

  Future<void> _checkPaymentStatus({bool? expectSuccess}) async {
    if (_hasCompletedPayment) return;

    try {
      final payment = await _midtransService.checkPaymentStatus(
        orderId: widget.orderId,
      );

      _hasCompletedPayment = true;
      
      switch (payment.status) {
        case PaymentStatus.success:
          widget.onPaymentCompleted(PaymentStatus.success, 'Payment successful!');
          break;
        case PaymentStatus.failed:
          widget.onPaymentCompleted(PaymentStatus.failed, 'Payment failed');
          break;
        case PaymentStatus.cancelled:
          widget.onPaymentCompleted(PaymentStatus.cancelled, 'Payment cancelled');
          break;
        case PaymentStatus.expired:
          widget.onPaymentCompleted(PaymentStatus.expired, 'Payment expired');
          break;
        case PaymentStatus.pending:
          widget.onPaymentCompleted(PaymentStatus.pending, 'Payment is being processed');
          break;
      }
    } catch (e) {
      if (!_hasCompletedPayment) {
        _hasCompletedPayment = true;
        widget.onPaymentCompleted(
          PaymentStatus.failed,
          'Failed to verify payment status: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : Colors.white,
      appBar: AppBar(
        title: const Text('Complete Payment'),
        centerTitle: true,
        backgroundColor: isDarkMode ? AppTheme.darkCard : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _showCancelConfirmation();
          },
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: isDarkMode 
                  ? AppTheme.darkBackground.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading payment gateway...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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

  void _showCancelConfirmation() {
    if (_hasCompletedPayment) {
      Navigator.of(context).pop();
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Payment?'),
          content: const Text(
            'Are you sure you want to cancel the payment process? '
            'You can try again later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _hasCompletedPayment = true;
                widget.onPaymentCompleted(PaymentStatus.cancelled, 'Payment cancelled by user');
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Cancel Payment'),
            ),
          ],
        );
      },
    );
  }
}