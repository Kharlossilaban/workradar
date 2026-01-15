import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';

class CitySelectionSheet extends StatelessWidget {
  final String selectedCity;
  final Function(String) onCitySelected;

  const CitySelectionSheet({
    super.key,
    required this.selectedCity,
    required this.onCitySelected,
  });

  static const List<Map<String, dynamic>> cities = [
    {'name': 'Jakarta,ID', 'display': 'Jakarta', 'province': 'DKI Jakarta'},
    {'name': 'Surabaya,ID', 'display': 'Surabaya', 'province': 'Jawa Timur'},
    {'name': 'Bandung,ID', 'display': 'Bandung', 'province': 'Jawa Barat'},
    {'name': 'Batam,ID', 'display': 'Batam', 'province': 'Kepulauan Riau'},
    {'name': 'Medan,ID', 'display': 'Medan', 'province': 'Sumatera Utara'},
    {'name': 'Semarang,ID', 'display': 'Semarang', 'province': 'Jawa Tengah'},
    {'name': 'Makassar,ID', 'display': 'Makassar', 'province': 'Sulawesi Selatan'},
    {'name': 'Palembang,ID', 'display': 'Palembang', 'province': 'Sumatera Selatan'},
    {'name': 'Denpasar,ID', 'display': 'Denpasar', 'province': 'Bali'},
    {'name': 'Yogyakarta,ID', 'display': 'Yogyakarta', 'province': 'DI Yogyakarta'},
    {'name': 'Malang,ID', 'display': 'Malang', 'province': 'Jawa Timur'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
    final textPrimaryColor = isDarkMode ? Colors.white : AppTheme.textPrimary;
    final textSecondaryColor = isDarkMode
        ? Colors.white60
        : AppTheme.textSecondary;
    final handleBarColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.3)
        : Colors.grey.shade300;
    final itemBgColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey.shade100;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: handleBarColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Iconsax.location,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Kota',
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kota-kota populer di Indonesia',
                      style: TextStyle(color: textSecondaryColor, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // City List
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: cities.length,
              itemBuilder: (context, index) {
                final city = cities[index];
                final isSelected = city['name'] == selectedCity;

                return GestureDetector(
                  onTap: () => onCitySelected(city['name']),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.2)
                          : itemBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: AppTheme.primaryColor, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.building_3,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : textSecondaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                city['display'] ?? city['name'],
                                style: TextStyle(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : textPrimaryColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                city['province'],
                                style: TextStyle(
                                  color: textSecondaryColor.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Safe Area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
