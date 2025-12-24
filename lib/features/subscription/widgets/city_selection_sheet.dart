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
    {'name': 'Jakarta', 'province': 'DKI Jakarta'},
    {'name': 'Surabaya', 'province': 'Jawa Timur'},
    {'name': 'Bandung', 'province': 'Jawa Barat'},
    {'name': 'Medan', 'province': 'Sumatera Utara'},
    {'name': 'Semarang', 'province': 'Jawa Tengah'},
    {'name': 'Makassar', 'province': 'Sulawesi Selatan'},
    {'name': 'Palembang', 'province': 'Sumatera Selatan'},
    {'name': 'Denpasar', 'province': 'Bali'},
    {'name': 'Yogyakarta', 'province': 'DI Yogyakarta'},
    {'name': 'Malang', 'province': 'Jawa Timur'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              color: Colors.white.withOpacity(0.3),
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
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Iconsax.location,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Kota',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kota-kota populer di Indonesia',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
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
                          ? AppTheme.primaryColor.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
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
                              : Colors.white60,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                city['name'],
                                style: TextStyle(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                city['province'],
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
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
