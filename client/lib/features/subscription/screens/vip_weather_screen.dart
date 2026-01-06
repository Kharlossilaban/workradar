import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/city_selection_sheet.dart';

enum WeatherCategory { rainyCold, hot }

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

  WeatherCategory _getWeatherCategory() {
    final condition = _weatherData['condition'].toString().toLowerCase();
    final temp = _weatherData['temperature'] as int;

    if (condition.contains('hujan') ||
        condition.contains('berawan') ||
        temp < 25) {
      return WeatherCategory.rainyCold;
    }
    return WeatherCategory.hot;
  }

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

  List<Map<String, dynamic>> _generateHourlyForecast() {
    final now = DateTime.now();
    final List<Map<String, dynamic>> forecast = [];

    for (int i = 0; i < 12; i++) {
      final hourTime = now.add(Duration(hours: i));
      final isNow = i == 0;

      // Simulating some weather variations for different hours
      String condition = 'Cerah Berawan';
      int percentage = 10;
      int temp = 28;

      if (i > 2 && i < 6) {
        condition = 'Hujan';
        percentage = 80;
        temp = 25;
      } else if (i >= 6) {
        condition = 'Berawan';
        percentage = 30;
        temp = 26;
      }

      String timeLabel;
      if (isNow) {
        timeLabel = 'Now';
      } else {
        final hour = hourTime.hour;
        final period = hour < 12 ? 'AM' : 'PM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        timeLabel = '$displayHour $period';
      }

      forecast.add({
        'time': timeLabel,
        'condition': condition,
        'percentage': percentage,
        'temp': temp,
        'isNow': isNow,
      });
    }
    return forecast;
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
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.shade200;
    final panelBgColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : AppTheme.primaryColor.withValues(alpha: 0.1);
    final panelBorderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : AppTheme.primaryColor.withValues(alpha: 0.2);

    final hourlyForecast = _generateHourlyForecast();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // --- ABOVE FOLD ---

              // 1. Header with City Selector Button (Top-Left)
              _buildHeader(isDarkMode, iconBgColor),

              // 2. Main Content (Greeting, City, Date, Weather Icon, Temp)
              _buildMainContent(isDarkMode, textColor, textSecondaryColor),

              // 3. Weather Stats (Humidity, Wind, Pressure)
              _buildBottomPanel(
                isDarkMode,
                textColor,
                textSecondaryColor,
                panelBgColor,
                panelBorderColor,
              ),

              const SizedBox(height: 40),

              // --- BELOW FOLD ---

              // 4. Recommendation Card
              _buildRecommendationCard(isDarkMode, textColor),

              const SizedBox(height: 24),

              // 5. Health Tips Section
              _buildHealthTips(isDarkMode, textColor, textSecondaryColor),

              const SizedBox(height: 24),

              // 6. Hourly Forecast Section
              _buildHourlyForecast(
                isDarkMode,
                textColor,
                textSecondaryColor,
                hourlyForecast,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode, Color iconBgColor) {
    final iconColor = isDarkMode ? Colors.white : AppTheme.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Menu Icon for City Selection (Top-Left)
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
          const Spacer(),
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
        // Personal Greeting (Above weather icon)
        Text(
          '${_getGreeting()}, $_username! 👋',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.9),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 16),

        // City Name
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.location, color: textSecondaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              _selectedCity,
              style: TextStyle(
                color: textColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Date
        Text(
          _getCurrentTime(),
          style: TextStyle(
            color: textSecondaryColor.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 32),

        // Large Weather Illustration
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.3),
                AppTheme.secondaryColor.withValues(alpha: 0.2),
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

        const SizedBox(height: 20),

        // Temperature
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_weatherData['temperature']}',
              style: TextStyle(
                color: textColor,
                fontSize: 80,
                fontWeight: FontWeight.w200,
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '°C',
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // Weather Condition
        Text(
          _weatherData['condition'],
          style: TextStyle(
            color: textSecondaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),

        const SizedBox(height: 20),
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
        ? Colors.white.withValues(alpha: 0.2)
        : AppTheme.primaryColor.withValues(alpha: 0.2);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
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
          Container(width: 1, height: 44, color: dividerColor),

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
          Container(width: 1, height: 44, color: dividerColor),

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
        Icon(icon, color: AppTheme.secondaryColor, size: 26),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: textSecondaryColor.withValues(alpha: 0.8),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(bool isDarkMode, Color textColor) {
    final category = _getWeatherCategory();
    final String recommendationText = category == WeatherCategory.rainyCold
        ? 'Siapkan payung dan jas hujan sebelum bepergian ya!'
        : 'Jangan lupa sunscreen dan bawa kipas biar tetap adem!';

    final List<String> icons = category == WeatherCategory.rainyCold
        ? ['Payung.svg', 'Jaket_Hujan.svg', 'Jaket.svg']
        : ['Sunscreen.svg', 'Kipas Portabel.svg', 'Payung.svg'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: isDarkMode ? null : AppTheme.cardShadow,
        border: isDarkMode
            ? Border.all(color: Colors.white.withValues(alpha: 0.1))
            : null,
      ),
      child: Column(
        children: [
          Text(
            recommendationText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: icons
                .map(
                  (icon) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SvgPicture.asset(
                      'assets/icons/$icon',
                      width: 48,
                      height: 48,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTips(
    bool isDarkMode,
    Color textColor,
    Color textSecondaryColor,
  ) {
    final category = _getWeatherCategory();
    final List<Map<String, String>> tips = category == WeatherCategory.rainyCold
        ? [
            {
              'icon': 'Vitamin.svg',
              'text': 'Konsumsi makanan bergizi kaya vitamin (C, D, zinc)',
            },
            {
              'icon': 'Pakaian.svg',
              'text': 'Gunakan pakaian hangat dan kering',
            },
            {
              'icon': 'Olahraga.svg',
              'text':
                  'Jangan malas untuk melakukan berbagai kegiatan fisik atau olahraga',
            },
          ]
        : [
            {'icon': 'Botol_Minum.svg', 'text': 'Perbanyaklah minum air putih'},
            {
              'icon': 'Buah_Buahan.svg',
              'text': 'Perbanyak mengonsumsi buah-buahan saat cuaca panas',
            },
            {
              'icon': 'Krim_Pelembap.svg',
              'text': 'Jangan lupa untuk menggunakan krim pelembap',
            },
            {
              'icon': 'Topi.svg',
              'text': 'Gunakan pelindung tubuh seperti payung dan topi',
            },
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Tips Menjaga Kesehatan',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: tips
                    .map(
                      (tip) => SizedBox(
                        width: cardWidth,
                        child: _buildOvalTip(
                          iconPath: tip['icon']!,
                          text: tip['text']!,
                          isDarkMode: isDarkMode,
                          textColor: textColor,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOvalTip({
    required String iconPath,
    required String text,
    required bool isDarkMode,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(
          28,
        ), // Adjusted for better wrap layout
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.primaryColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          SvgPicture.asset('assets/icons/$iconPath', width: 32, height: 32),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyForecast(
    bool isDarkMode,
    Color textColor,
    Color textSecondaryColor,
    List<Map<String, dynamic>> hourlyForecast,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Perkiraan Cuaca Per Jam',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: hourlyForecast.length,
            itemBuilder: (context, index) {
              final forecast = hourlyForecast[index];
              return _buildHourlyCapsule(forecast, isDarkMode, textColor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyCapsule(
    Map<String, dynamic> forecast,
    bool isDarkMode,
    Color textColor,
  ) {
    final isNow = forecast['isNow'] as bool;

    return Container(
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        gradient: isNow ? AppTheme.primaryGradient : null,
        color: isNow
            ? null
            : (isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white),
        borderRadius: BorderRadius.circular(35),
        boxShadow: isNow
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        border: !isNow && isDarkMode
            ? Border.all(color: Colors.white.withValues(alpha: 0.1))
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            forecast['time'],
            style: TextStyle(
              color: isNow ? Colors.white : textColor.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 12),
          Icon(
            _getWeatherIcon(forecast['condition']),
            color: isNow ? Colors.white : AppTheme.secondaryColor,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            '${forecast['percentage']}%',
            style: TextStyle(
              color: isNow
                  ? Colors.white.withValues(alpha: 0.8)
                  : AppTheme.secondaryColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${forecast['temp']}°',
            style: TextStyle(
              color: isNow ? Colors.white : textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
