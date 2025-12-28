import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/profile_provider.dart';
import 'edit_profile_screen.dart';

class ProfileDetailScreen extends StatelessWidget {
  const ProfileDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Curved background
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(40),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Iconsax.arrow_left,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Iconsax.brush_2, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Profile picture
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDarkMode ? AppTheme.darkCard : Colors.white,
                    border: Border.all(
                      color: isDarkMode ? AppTheme.darkCard : Colors.white,
                      width: 4,
                    ),
                    boxShadow: isDarkMode
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                  ),
                  child: Icon(
                    Iconsax.user,
                    size: 50,
                    color: isDarkMode ? Colors.white : AppTheme.primaryColor,
                  ),
                ),

                const SizedBox(height: 60),

                // Info cards
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoCard(
                          context,
                          isDarkMode,
                          icon: Iconsax.user,
                          label: 'Nama Pengguna',
                          value: profileProvider.username,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          context,
                          isDarkMode,
                          icon: Iconsax.sms,
                          label: 'Gmail',
                          value: profileProvider.gmail,
                        ),
                        if (profileProvider.hasWorkHours) ...[
                          const SizedBox(height: 16),
                          _buildInfoCard(
                            context,
                            isDarkMode,
                            icon: Iconsax.clock,
                            label: 'Jadwal Kerja',
                            value: profileProvider.workHoursRange,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    bool isDarkMode, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDarkMode ? null : AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
