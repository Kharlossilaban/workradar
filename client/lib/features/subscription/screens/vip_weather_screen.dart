import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/weather_api_service.dart';
import '../widgets/city_selection_sheet.dart';

class VipWeatherScreen extends StatefulWidget {
  const VipWeatherScreen({super.key});

  @override
  State<VipWeatherScreen> createState() => _VipWeatherScreenState();
}

class _VipWeatherScreenState extends State<VipWeatherScreen> {
  String _selectedCity = 'Jakarta,ID'; // Use city with country code for better accuracy
  final String _username = 'John Doe';
  final WeatherApiService _weatherService = WeatherApiService();

  // Real weather data from API
  CurrentWeather? _currentWeather;
  WeatherForecast? _forecast;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _weatherService.getWeatherData(_selectedCity);
      setState(() {
        _currentWeather = data.current;
        _forecast = data.forecast;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
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

  String _getDisplayCityName() {
    // Remove country code for display (e.g., "Jakarta,ID" -> "Jakarta")
    return _selectedCity.split(',').first;
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
          // Reload weather data for new city
          _loadWeatherData();
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
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.shade200;
    final panelBgColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : AppTheme.primaryColor.withValues(alpha: 0.1);
    final panelBorderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : AppTheme.primaryColor.withValues(alpha: 0.2);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState(isDarkMode)
            : _errorMessage != null
                ? _buildErrorState(isDarkMode, textColor)
                : RefreshIndicator(
                    onRefresh: _loadWeatherData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDarkMode ? Colors.white : AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat data cuaca...',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode, Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.cloud_cross,
              size: 64,
              color: isDarkMode ? Colors.white54 : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat data cuaca',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.white54 : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadWeatherData,
              icon: const Icon(Iconsax.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
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
              _getDisplayCityName(),
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
            _getWeatherIcon(_currentWeather?.conditionIndonesian ?? 'Cerah'),
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
              '${_currentWeather?.temperature.round() ?? 28}',
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
          _currentWeather?.conditionIndonesian ?? 'Cerah Berawan',
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
              value: '${_currentWeather?.humidity ?? 0}%',
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
              value: '${_currentWeather?.windSpeed.toStringAsFixed(1) ?? 0} km/h',
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
              value: '${_currentWeather?.pressure ?? 0} hPa',
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
    final recommendation = _getWeatherRecommendation();

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
          // Weather-based emoji
          Text(
            recommendation['emoji'] as String,
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 12),
          Text(
            recommendation['title'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recommendation['subtitle'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          // Items to prepare
          Text(
            'Barang yang perlu disiapkan:',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: (recommendation['items'] as List<Map<String, String>>)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/${item['icon']}',
                          width: 44,
                          height: 44,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['name']!,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  /// Get weather-specific recommendations based on current weather
  Map<String, dynamic> _getWeatherRecommendation() {
    if (_currentWeather == null) {
      return _getDefaultRecommendation();
    }

    final temp = _currentWeather!.temperature;
    final condition = _currentWeather!.conditionIndonesian.toLowerCase();
    final humidity = _currentWeather!.humidity;

    // Very Hot (> 33°C)
    if (temp > 33) {
      return {
        'emoji': '🥵',
        'title': 'Cuaca sangat panas! Hindari aktivitas luar ruangan yang berat.',
        'subtitle': 'Suhu mencapai ${temp.round()}°C. Pastikan tubuh tetap terhidrasi dan sejuk.',
        'items': [
          {'icon': 'Botol_Minum.svg', 'name': 'Air Minum'},
          {'icon': 'Sunscreen.svg', 'name': 'Sunscreen'},
          {'icon': 'Topi.svg', 'name': 'Topi'},
          {'icon': 'Kipas Portabel.svg', 'name': 'Kipas'},
        ],
      };
    }

    // Hot (28-33°C)
    if (temp >= 28) {
      return {
        'emoji': '☀️',
        'title': 'Cuaca panas! Jangan lupa sunscreen dan bawa minum ya!',
        'subtitle': 'Suhu ${temp.round()}°C. Lindungi kulit dari paparan sinar UV.',
        'items': [
          {'icon': 'Botol_Minum.svg', 'name': 'Air Minum'},
          {'icon': 'Sunscreen.svg', 'name': 'Sunscreen'},
          {'icon': 'Kipas Portabel.svg', 'name': 'Kipas'},
        ],
      };
    }

    // Rainy
    if (condition.contains('hujan')) {
      if (condition.contains('petir') || condition.contains('lebat')) {
        return {
          'emoji': '⛈️',
          'title': 'Hujan lebat disertai petir! Sebaiknya tetap di dalam ruangan.',
          'subtitle': 'Hindari area terbuka dan tempat tinggi. Suhu ${temp.round()}°C.',
          'items': [
            {'icon': 'Payung.svg', 'name': 'Payung'},
            {'icon': 'Jaket_Hujan.svg', 'name': 'Jas Hujan'},
            {'icon': 'Jaket.svg', 'name': 'Jaket'},
          ],
        };
      }
      return {
        'emoji': '🌧️',
        'title': 'Siapkan payung dan jas hujan sebelum bepergian ya!',
        'subtitle': 'Cuaca hujan dengan suhu ${temp.round()}°C. Tetap hangat dan kering.',
        'items': [
          {'icon': 'Payung.svg', 'name': 'Payung'},
          {'icon': 'Jaket_Hujan.svg', 'name': 'Jas Hujan'},
          {'icon': 'Jaket.svg', 'name': 'Jaket'},
        ],
      };
    }

    // Cloudy
    if (condition.contains('berawan')) {
      if (temp < 25) {
        return {
          'emoji': '🌥️',
          'title': 'Cuaca berawan dan sejuk. Cocok untuk aktivitas outdoor!',
          'subtitle': 'Suhu ${temp.round()}°C. Siapkan jaket tipis untuk jaga-jaga.',
          'items': [
            {'icon': 'Jaket.svg', 'name': 'Jaket'},
            {'icon': 'Payung.svg', 'name': 'Payung'},
            {'icon': 'Botol_Minum.svg', 'name': 'Air Minum'},
          ],
        };
      }
      return {
        'emoji': '⛅',
        'title': 'Cuaca berawan. Tetap bawa payung untuk jaga-jaga!',
        'subtitle': 'Suhu ${temp.round()}°C dengan kelembaban $humidity%.',
        'items': [
          {'icon': 'Payung.svg', 'name': 'Payung'},
          {'icon': 'Botol_Minum.svg', 'name': 'Air Minum'},
          {'icon': 'Sunscreen.svg', 'name': 'Sunscreen'},
        ],
      };
    }

    // Cold (< 22°C)
    if (temp < 22) {
      return {
        'emoji': '🥶',
        'title': 'Cuaca dingin! Gunakan pakaian hangat.',
        'subtitle': 'Suhu ${temp.round()}°C. Jaga tubuh tetap hangat.',
        'items': [
          {'icon': 'Jaket.svg', 'name': 'Jaket'},
          {'icon': 'Vitamin.svg', 'name': 'Vitamin'},
          {'icon': 'Botol_Minum.svg', 'name': 'Air Hangat'},
        ],
      };
    }

    // Foggy/Misty
    if (condition.contains('kabut') || condition.contains('berkabut')) {
      return {
        'emoji': '🌫️',
        'title': 'Cuaca berkabut. Hati-hati saat berkendara!',
        'subtitle': 'Jarak pandang terbatas. Suhu ${temp.round()}°C.',
        'items': [
          {'icon': 'Jaket.svg', 'name': 'Jaket'},
          {'icon': 'Payung.svg', 'name': 'Payung'},
        ],
      };
    }

    // High Humidity (> 80%)
    if (humidity > 80) {
      return {
        'emoji': '💧',
        'title': 'Kelembaban tinggi! Gunakan pakaian yang menyerap keringat.',
        'subtitle': 'Kelembaban $humidity% dengan suhu ${temp.round()}°C.',
        'items': [
          {'icon': 'Botol_Minum.svg', 'name': 'Air Minum'},
          {'icon': 'Kipas Portabel.svg', 'name': 'Kipas'},
          {'icon': 'Payung.svg', 'name': 'Payung'},
        ],
      };
    }

    // Clear/Nice weather (22-28°C)
    return {
      'emoji': '😊',
      'title': 'Cuaca cerah dan nyaman! Sempurna untuk beraktivitas.',
      'subtitle': 'Suhu ${temp.round()}°C. Nikmati harimu!',
      'items': [
        {'icon': 'Botol_Minum.svg', 'name': 'Air Minum'},
        {'icon': 'Sunscreen.svg', 'name': 'Sunscreen'},
        {'icon': 'Topi.svg', 'name': 'Topi'},
      ],
    };
  }

  Map<String, dynamic> _getDefaultRecommendation() {
    return {
      'emoji': '🌤️',
      'title': 'Siapkan dirimu untuk cuaca hari ini!',
      'subtitle': 'Memuat data cuaca...',
      'items': [
        {'icon': 'Botol_Minum.svg', 'name': 'Air Minum'},
        {'icon': 'Payung.svg', 'name': 'Payung'},
      ],
    };
  }

  /// Get weather-specific health tips based on current weather
  List<Map<String, String>> _getHealthTips() {
    if (_currentWeather == null) {
      return _getDefaultHealthTips();
    }

    final temp = _currentWeather!.temperature;
    final condition = _currentWeather!.conditionIndonesian.toLowerCase();
    final humidity = _currentWeather!.humidity;

    // Very Hot (> 33°C)
    if (temp > 33) {
      return [
        {
          'icon': 'Botol_Minum.svg',
          'text': 'Minum air putih minimal 3 liter per hari untuk mencegah dehidrasi',
        },
        {
          'icon': 'Buah_Buahan.svg',
          'text': 'Konsumsi buah-buahan berair seperti semangka, melon, jeruk',
        },
        {
          'icon': 'Olahraga.svg',
          'text': 'Hindari aktivitas fisik berat di luar ruangan saat siang hari',
        },
        {
          'icon': 'Krim_Pelembap.svg',
          'text': 'Gunakan sunscreen SPF 30+ sebelum keluar ruangan',
        },
      ];
    }

    // Hot (28-33°C)
    if (temp >= 28) {
      return [
        {
          'icon': 'Botol_Minum.svg',
          'text': 'Perbanyak minum air putih agar tubuh tetap terhidrasi',
        },
        {
          'icon': 'Buah_Buahan.svg',
          'text': 'Konsumsi buah-buahan segar untuk tambahan cairan dan vitamin',
        },
        {
          'icon': 'Krim_Pelembap.svg',
          'text': 'Gunakan pelembap dan sunscreen untuk melindungi kulit',
        },
        {
          'icon': 'Topi.svg',
          'text': 'Gunakan topi atau payung saat beraktivitas di luar ruangan',
        },
      ];
    }

    // Rainy
    if (condition.contains('hujan')) {
      if (condition.contains('petir') || condition.contains('lebat')) {
        return [
          {
            'icon': 'Vitamin.svg',
            'text': 'Konsumsi vitamin C untuk menjaga daya tahan tubuh',
          },
          {
            'icon': 'Pakaian.svg',
            'text': 'Segera ganti pakaian jika basah untuk mencegah masuk angin',
          },
          {
            'icon': 'Botol_Minum.svg',
            'text': 'Minum minuman hangat seperti jahe atau teh untuk menghangatkan tubuh',
          },
          {
            'icon': 'Olahraga.svg',
            'text': 'Tetap aktif dengan olahraga ringan di dalam ruangan',
          },
        ];
      }
      return [
        {
          'icon': 'Vitamin.svg',
          'text': 'Konsumsi makanan bergizi kaya vitamin (C, D, zinc)',
        },
        {
          'icon': 'Pakaian.svg',
          'text': 'Gunakan pakaian hangat dan pastikan selalu kering',
        },
        {
          'icon': 'Botol_Minum.svg',
          'text': 'Minum air hangat untuk menjaga suhu tubuh',
        },
        {
          'icon': 'Olahraga.svg',
          'text': 'Tetap lakukan olahraga ringan untuk menjaga imunitas',
        },
      ];
    }

    // Cloudy
    if (condition.contains('berawan')) {
      return [
        {
          'icon': 'Botol_Minum.svg',
          'text': 'Tetap jaga asupan air meskipun cuaca tidak terlalu panas',
        },
        {
          'icon': 'Olahraga.svg',
          'text': 'Cuaca ideal untuk olahraga outdoor seperti jogging atau bersepeda',
        },
        {
          'icon': 'Krim_Pelembap.svg',
          'text': 'Tetap gunakan sunscreen, sinar UV tetap bisa menembus awan',
        },
        {
          'icon': 'Vitamin.svg',
          'text': 'Konsumsi vitamin D karena sinar matahari terbatas',
        },
      ];
    }

    // Cold (< 22°C)
    if (temp < 22) {
      return [
        {
          'icon': 'Vitamin.svg',
          'text': 'Perbanyak konsumsi vitamin C dan makanan bergizi',
        },
        {
          'icon': 'Pakaian.svg',
          'text': 'Gunakan pakaian berlapis untuk menjaga kehangatan',
        },
        {
          'icon': 'Botol_Minum.svg',
          'text': 'Minum minuman hangat seperti teh, jahe, atau sup',
        },
        {
          'icon': 'Olahraga.svg',
          'text': 'Lakukan pemanasan sebelum aktivitas untuk memperlancar sirkulasi',
        },
      ];
    }

    // Foggy/Misty
    if (condition.contains('kabut') || condition.contains('berkabut')) {
      return [
        {
          'icon': 'Vitamin.svg',
          'text': 'Jaga daya tahan tubuh dengan vitamin dan istirahat cukup',
        },
        {
          'icon': 'Pakaian.svg',
          'text': 'Gunakan pakaian yang nyaman dan tidak terlalu tebal',
        },
        {
          'icon': 'Olahraga.svg',
          'text': 'Hati-hati saat olahraga outdoor karena jarak pandang terbatas',
        },
      ];
    }

    // High Humidity (> 80%)
    if (humidity > 80) {
      return [
        {
          'icon': 'Botol_Minum.svg',
          'text': 'Minum banyak air karena tubuh lebih mudah berkeringat',
        },
        {
          'icon': 'Pakaian.svg',
          'text': 'Gunakan pakaian berbahan katun yang menyerap keringat',
        },
        {
          'icon': 'Krim_Pelembap.svg',
          'text': 'Gunakan powder untuk mencegah kulit lembap dan iritasi',
        },
        {
          'icon': 'Olahraga.svg',
          'text': 'Pilih waktu olahraga di pagi atau sore hari yang lebih sejuk',
        },
      ];
    }

    // Clear/Nice weather (22-28°C)
    return [
      {
        'icon': 'Botol_Minum.svg',
        'text': 'Tetap jaga hidrasi dengan minum air putih secara teratur',
      },
      {
        'icon': 'Olahraga.svg',
        'text': 'Cuaca ideal untuk aktivitas outdoor, manfaatkan untuk olahraga!',
      },
      {
        'icon': 'Buah_Buahan.svg',
        'text': 'Konsumsi buah dan sayur untuk menjaga kesehatan',
      },
      {
        'icon': 'Krim_Pelembap.svg',
        'text': 'Jangan lupa gunakan sunscreen saat beraktivitas di luar',
      },
    ];
  }

  List<Map<String, String>> _getDefaultHealthTips() {
    return [
      {
        'icon': 'Botol_Minum.svg',
        'text': 'Jaga asupan cairan dengan minum air putih yang cukup',
      },
      {
        'icon': 'Vitamin.svg',
        'text': 'Konsumsi makanan bergizi untuk menjaga daya tahan tubuh',
      },
      {
        'icon': 'Olahraga.svg',
        'text': 'Tetap aktif dengan olahraga rutin setiap hari',
      },
    ];
  }

  Widget _buildHealthTips(
    bool isDarkMode,
    Color textColor,
    Color textSecondaryColor,
  ) {
    final tips = _getHealthTips();

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
  ) {
    final hourlyData = _forecast?.hourly ?? [];
    
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
        if (hourlyData.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Data perkiraan cuaca tidak tersedia',
              style: TextStyle(color: textSecondaryColor),
            ),
          )
        else
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: hourlyData.length,
              itemBuilder: (context, index) {
                final forecast = hourlyData[index];
                return _buildHourlyCapsule(forecast, isDarkMode, textColor, index == 0);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildHourlyCapsule(
    HourlyForecast forecast,
    bool isDarkMode,
    Color textColor,
    bool isNow,
  ) {
    // Format time
    String timeLabel;
    if (isNow) {
      timeLabel = 'Now';
    } else {
      final hour = forecast.dateTime.hour;
      final period = hour < 12 ? 'AM' : 'PM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      timeLabel = '$displayHour $period';
    }

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
            timeLabel,
            style: TextStyle(
              color: isNow ? Colors.white : textColor.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 12),
          Icon(
            _getWeatherIcon(forecast.conditionIndonesian),
            color: isNow ? Colors.white : AppTheme.secondaryColor,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            '${forecast.humidity}%',
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
            '${forecast.temperature.round()}°',
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
