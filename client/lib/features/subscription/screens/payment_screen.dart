import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/midtrans_service.dart';
import '../../../core/models/payment.dart';
import '../../messaging/providers/messaging_provider.dart';
import 'package:provider/provider.dart';
import 'payment_webview_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String userName;
  final String selectedPlan; // 'monthly' or 'yearly'

  const PaymentScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.selectedPlan = 'monthly',
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final MidtransService _midtransService = MidtransService();
  bool _isLoading = false;
  Payment? _currentPayment;
  late String _selectedPlan;

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.selectedPlan;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? AppTheme.darkBackground : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('VIP Subscription'),
        centerTitle: true,
        backgroundColor: isDarkMode ? AppTheme.darkCard : Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // VIP Benefits Card
              _buildVipBenefitsCard(isDarkMode),

              const SizedBox(height: 24),

              // Pricing Card
              _buildPricingCard(isDarkMode),

              const SizedBox(height: 24),

              // Payment Button
              _buildPaymentButton(isDarkMode),

              const SizedBox(height: 16),

              // Current Payment Status (if any)
              if (_currentPayment != null) ...[
                _buildPaymentStatus(isDarkMode),
                const SizedBox(height: 16),
              ],

              // Terms and Info
              _buildTermsInfo(isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVipBenefitsCard(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.vipGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.vipGold.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Iconsax.crown_15, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Upgrade ke VIP',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nikmati Semua Fitur Premium',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ..._buildBenefitsList(),
        ],
      ),
    );
  }

  List<Widget> _buildBenefitsList() {
    final benefits = [
      {'icon': Iconsax.chart_1, 'text': 'Grafik Workload Weekly & Monthly'},
      {'icon': Iconsax.cloud_sunny, 'text': 'Prakiraan Cuaca Real-time'},
      {'icon': Iconsax.task_square, 'text': 'Statistik Lengkap Task'},
      {'icon': Iconsax.trend_up, 'text': 'Analisis Produktivitas'},
      {'icon': Iconsax.notification_bing, 'text': 'Notifikasi Premium'},
      {'icon': Iconsax.message_text, 'text': 'Chat AI Bot'},
    ];

    return benefits.map((benefit) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                benefit['icon'] as IconData,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                benefit['text'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildPricingCard(bool isDarkMode) {
    final cardColor = isDarkMode ? AppTheme.darkCard : Colors.white;
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    return Column(
      children: [
        // Plan Selector
        Row(
          children: [
            Expanded(
              child: _buildPlanOption(
                'monthly',
                'Bulanan',
                'Rp 15.000',
                '/bulan',
                false,
                isDarkMode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPlanOption(
                'yearly',
                'Tahunan',
                'Rp 150.000',
                '/tahun',
                true,
                isDarkMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Selected Plan Details
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.vipGold.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: isDarkMode ? null : AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedPlan == 'yearly' ? 'VIP Tahunan' : 'VIP Bulanan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.vipGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _selectedPlan == 'yearly' ? 'HEMAT 17%' : 'POPULER',
                      style: const TextStyle(
                        color: AppTheme.vipGold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rp',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _selectedPlan == 'yearly' ? '150.000' : '15.000',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _selectedPlan == 'yearly' ? '/ tahun' : '/ bulan',
                      style: TextStyle(fontSize: 14, color: textSecondaryColor),
                    ),
                  ),
                ],
              ),
              if (_selectedPlan == 'yearly') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '💰 Hemat Rp 30.000 dibanding bulanan!',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Pembayaran dapat dilakukan via Transfer Bank, E-Wallet, atau Kartu Kredit',
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondaryColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanOption(
    String planId,
    String title,
    String price,
    String period,
    bool showBadge,
    bool isDarkMode,
  ) {
    final isSelected = _selectedPlan == planId;
    final cardColor = isDarkMode ? AppTheme.darkCard : Colors.white;
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = planId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.vipGold.withValues(alpha: 0.1)
              : cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.vipGold : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (showBadge)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'TERBAIK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.vipGold : textPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.vipGold : textPrimaryColor,
              ),
            ),
            Text(period, style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppTheme.vipGold : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentButton(bool isDarkMode) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handlePayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.vipGold,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.wallet_3, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Lanjutkan Pembayaran',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPaymentStatus(bool isDarkMode) {
    final cardColor = isDarkMode ? AppTheme.darkCard : Colors.white;
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (_currentPayment!.status) {
      case PaymentStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Iconsax.clock;
        statusText = 'Menunggu Pembayaran';
        break;
      case PaymentStatus.success:
        statusColor = Colors.green;
        statusIcon = Iconsax.tick_circle;
        statusText = 'Pembayaran Berhasil';
        break;
      case PaymentStatus.failed:
        statusColor = Colors.red;
        statusIcon = Iconsax.close_circle;
        statusText = 'Pembayaran Gagal';
        break;
      case PaymentStatus.expired:
        statusColor = Colors.grey;
        statusIcon = Iconsax.timer;
        statusText = 'Pembayaran Kadaluarsa';
        break;
      case PaymentStatus.cancelled:
        statusColor = Colors.grey;
        statusIcon = Iconsax.close_square;
        statusText = 'Pembayaran Dibatalkan';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Order ID: ${_currentPayment!.orderId}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (_currentPayment!.isPending)
            TextButton(
              onPressed: () {
                // Since we're now using WebView, we don't need manual status check
                // The WebView handles status automatically
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Status akan diperbarui otomatis setelah pembayaran selesai.',
                    ),
                  ),
                );
              },
              child: const Text('Refresh'),
            ),
        ],
      ),
    );
  }

  Widget _buildTermsInfo(bool isDarkMode) {
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Dengan melanjutkan, Anda menyetujui Syarat & Ketentuan serta Kebijakan Privasi kami.',
          style: TextStyle(
            fontSize: 12,
            color: textSecondaryColor,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '🔒 Pembayaran aman & terenkripsi via Midtrans',
          style: TextStyle(
            fontSize: 12,
            color: textSecondaryColor,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _handlePayment() async {
    setState(() => _isLoading = true);

    try {
      final payment = await _midtransService.createPayment(
        userId: widget.userId,
        userEmail: widget.userEmail,
        userName: widget.userName,
        planType: _selectedPlan,
      );

      setState(() {
        _currentPayment = payment;
        _isLoading = false;
      });

      // Open WebView Payment Screen instead of external browser
      if (payment.redirectUrl != null && mounted) {
        final result = await Navigator.push<PaymentStatus>(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebViewScreen(
              redirectUrl: payment.redirectUrl!,
              orderId: payment.orderId,
              onPaymentCompleted: (status, message) {
                Navigator.pop(context, status);
              },
            ),
          ),
        );

        // Handle payment result
        if (result != null && mounted) {
          await _handlePaymentResult(result, payment);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat pembayaran: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePaymentResult(
    PaymentStatus result,
    Payment payment,
  ) async {
    switch (result) {
      case PaymentStatus.success:
        // Send success messages
        if (mounted) {
          context.read<MessagingProvider>().sendPaymentSuccessMessage(
            widget.userId,
            payment.amount,
          );
          context.read<MessagingProvider>().sendVipWelcomeMessage(
            widget.userId,
          );
        }

        // Show success dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Text('Pembayaran Berhasil!'),
                ],
              ),
              content: const Text(
                'Selamat! Status VIP Anda sekarang aktif. '
                'Nikmati semua fitur premium!',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Return to previous screen
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        break;

      case PaymentStatus.failed:
        if (mounted) {
          context.read<MessagingProvider>().sendPaymentFailedMessage(
            widget.userId,
            'Pembayaran ditolak oleh sistem',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pembayaran gagal. Silakan coba lagi.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;

      case PaymentStatus.cancelled:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pembayaran dibatalkan.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        break;

      case PaymentStatus.expired:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pembayaran kadaluarsa. Silakan coba lagi.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;

      case PaymentStatus.pending:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Pembayaran sedang diproses. Mohon tunggu beberapa saat.',
              ),
              backgroundColor: Colors.blue,
            ),
          );
        }
        break;
    }
  }
}
