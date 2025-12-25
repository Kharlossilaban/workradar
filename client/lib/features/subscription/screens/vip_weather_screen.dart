import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/city_selection_sheet.dart';

class VipWeatherScreen extends StatefulWidget {
  const VipWeatherScreen({super.key});

  @override
  State<VipWeatherScreen> createState() => _VipWeatherScreenState();
}

class _VipWeatherScreenState extends State<VipWeatherScreen> {
  String _selectedCity = 'Jakarta';
  final String _username = 'John Doe';

  // Mock weather data
  final Map<String, dynamic> _weatherData = {
    'temperature': 28,
    'condition': 'Cerah Berawan',
    'humidity': 75,
    'windSpeed': 12,
    'pressure': 1013,
  };

  String _getCurrentTime() {
    final now = DateTime.now();
    final days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  IconData _getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'cerah':
        return Iconsax.sun_1;
      case 'cerah berawan':
        return Iconsax.cloud_sunny;
      case 'berawan':
        return Iconsax.cloud;
      case 'hujan':
        return Iconsax.cloud_drizzle;
      case 'hujan lebat':
        return Iconsax.cloud_lightning;
      default:
        return Iconsax.cloud_sunny;
    }
  }

  void _showCitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CitySelectionSheet(
        selectedCity: _selectedCity,
        onCitySelected: (city) {
          setState(() => _selectedCity = city);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode
        ? const Color(0xFF1A1A2E)
        : AppTheme.backgroundColor;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimary;
    final textSecondaryColor = isDarkMode
        ? Colors.white70
        : AppTheme.textSecondary;
    final iconBgColor = isDarkMode
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade200;
    final panelBgColor = isDarkMode
        ? Colors.white.withOpacity(0.1)
        : AppTheme.primaryColor.withOpacity(0.1);
    final panelBorderColor = isDarkMode
        ? Colors.white.withOpacity(0.1)
        : AppTheme.primaryColor.withOpacity(0.2);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(
              isDarkMode,
              textColor,
              textSecondaryColor,
              iconBgColor,
            ),

            // Main Content
            Expanded(
              child: _buildMainContent(
                isDarkMode,
                textColor,
                textSecondaryColor,
              ),
            ),

            // Bottom Panel
            _buildBottomPanel(
              isDarkMode,
              textColor,
              textSecondaryColor,
              panelBgColor,
              panelBorderColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    bool isDarkMode,
    Color textColor,
    Color textSecondaryColor,
    Color iconBgColor,
  ) {
    final iconColor = isDarkMode ? Colors.white : AppTheme.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Menu Icon for City Selection
          GestureDetector(
            onTap: _showCitySelector,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Iconsax.menu, color: iconColor, size: 22),
            ),
          ),

          // Center: Location & Time
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.location, color: textSecondaryColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _selectedCity,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getCurrentTime(),
                  style: TextStyle(
                    color: textSecondaryColor.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Placeholder for balance
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    bool isDarkMode,
    Color textColor,
    Color textSecondaryColor,
  ) {
    final iconColor = isDarkMode ? Colors.white : AppTheme.primaryColor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // City Name above illustration
        Text(
          _selectedCity,
          style: TextStyle(
            color: textSecondaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),

        const SizedBox(height: 20),

        // Large Weather Illustration
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(0.3),
                AppTheme.secondaryColor.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getWeatherIcon(_weatherData['condition']),
            size: 100,
            color: iconColor,
          ),
        ),

        const SizedBox(height: 30),

        // Temperature
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_weatherData['temperature']}',
              style: TextStyle(
                color: textColor,
                fontSize: 96,
                fontWeight: FontWeight.w200,
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                '°C',
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Weather Condition
        Text(
          _weatherData['condition'],
          style: TextStyle(
            color: textSecondaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),

        const SizedBox(height: 24),

        // Personal Greeting
        Text(
          '${_getGreeting()}, $_username! 👋',
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(
    bool isDarkMode,
    Color textColor,
    Color textSecondaryColor,
    Color panelBgColor,
    Color panelBorderColor,
  ) {
    final dividerColor = isDarkMode
        ? Colors.white.withOpacity(0.2)
        : AppTheme.primaryColor.withOpacity(0.2);

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: panelBgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: panelBorderColor, width: 1),
      ),
      child: Row(
        children: [
          // Humidity
          Expanded(
            child: _buildWeatherInfoColumn(
              icon: Iconsax.drop,
              label: 'Kelembaban',
              value: '${_weatherData['humidity']}%',
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
            ),
          ),

          // Divider
          Container(width: 1, height: 50, color: dividerColor),

          // Wind Speed
          Expanded(
            child: _buildWeatherInfoColumn(
              icon: Iconsax.wind,
              label: 'Angin',
              value: '${_weatherData['windSpeed']} km/h',
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
            ),
          ),

          // Divider
          Container(width: 1, height: 50, color: dividerColor),

          // Pressure
          Expanded(
            child: _buildWeatherInfoColumn(
              icon: Iconsax.chart,
              label: 'Tekanan',
              value: '${_weatherData['pressure']} hPa',
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherInfoColumn({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.secondaryColor, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: textSecondaryColor.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
