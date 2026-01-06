import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/storage/secure_storage.dart';
import '../../profile/providers/profile_provider.dart';
import 'payment_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _selectedPlan = 'monthly';
  final bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Iconsax.arrow_left,
                  color: AppTheme.textPrimary,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Upgrade ke VIP'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // VIP Crown Icon
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppTheme.vipGradient,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.vipGold.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Iconsax.crown_15,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Center(
              child: Text(
                'Buka Semua Fitur VIP',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Center(
              child: Text(
                'Tingkatkan produktivitas Anda dengan fitur premium',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),

            const SizedBox(height: 32),

            // VIP Features
            _buildFeaturesList(),

            const SizedBox(height: 32),

            // Plan Selection
            Text('Pilih Paket', style: Theme.of(context).textTheme.titleLarge),

            const SizedBox(height: 16),

            // Monthly Plan
            _buildPlanCard(
              planId: 'monthly',
              title: 'Bulanan',
              price: 'Rp ${AppConstants.monthlyPrice ~/ 1000}K',
              period: '/bulan',
              isPopular: false,
            ),

            const SizedBox(height: 12),

            // Yearly Plan
            _buildPlanCard(
              planId: 'yearly',
              title: 'Tahunan',
              price: 'Rp ${AppConstants.yearlyPrice ~/ 1000}K',
              period: '/tahun',
              isPopular: true,
              savings:
                  'Hemat Rp ${(AppConstants.monthlyPrice * 12 - AppConstants.yearlyPrice) ~/ 1000}K',
            ),

            const SizedBox(height: 32),

            // Subscribe Button
            CustomButton(
              text: 'Upgrade Sekarang',
              onPressed: _handleSubscribe,
              isLoading: _isLoading,
              backgroundColor: AppTheme.vipGold,
              icon: Iconsax.crown_15,
            ),

            const SizedBox(height: 16),

            // Terms
            Center(
              child: Text(
                'Pembayaran akan diproses melalui payment gateway.\nAnda dapat membatalkan kapan saja.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      {
        'icon': Iconsax.repeat,
        'title': 'Atur Ulangi Tugas',
        'desc': 'Konfigurasi pengulangan tugas sesuai keinginan',
      },
      {
        'icon': Iconsax.chart_1,
        'title': 'Grafik Mingguan & Bulanan',
        'desc': 'Pantau beban kerja dalam jangka panjang',
      },
      {
        'icon': Iconsax.health,
        'title': 'Rekomendasi Kesehatan',
        'desc': 'Notifikasi kesehatan saat beban kerja tinggi',
      },
      {
        'icon': Iconsax.cloud_drizzle,
        'title': 'Integrasi Cuaca',
        'desc': 'Peringatan cuaca yang mempengaruhi aktivitas',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.star_15, color: AppTheme.vipGold, size: 20),
              const SizedBox(width: 8),
              Text(
                'Fitur VIP',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.vipGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      feature['icon'] as IconData,
                      color: AppTheme.vipGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          feature['desc'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String planId,
    required String title,
    required String price,
    required String period,
    required bool isPopular,
    String? savings,
  }) {
    final isSelected = _selectedPlan == planId;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedPlan = planId);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.vipGold : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.vipGold.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.vipGold : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.vipGold,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Plan info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'TERBAIK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (savings != null)
                    Text(
                      savings,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppTheme.vipGold : AppTheme.textPrimary,
                  ),
                ),
                Text(
                  period,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubscribe() async {
    // Get real user data from SecureStorage and ProfileProvider
    final userId = await SecureStorage.getUserId();
    final userEmail = await SecureStorage.getUserEmail();
    final profileProvider = context.read<ProfileProvider>();
    final userName = profileProvider.username;

    // Validate user data before proceeding
    if (userId == null || userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesi login tidak valid. Silakan login ulang.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Navigate to payment screen with real user data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          userId: userId,
          userEmail: userEmail ?? 'user@workradar.app',
          userName: userName,
          selectedPlan: _selectedPlan,
        ),
      ),
    );
  }
}
