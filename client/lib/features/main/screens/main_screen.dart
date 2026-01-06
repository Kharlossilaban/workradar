import 'package:flutter/material.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../../core/storage/secure_storage.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../calendar/screens/calendar_screen.dart';
import '../../subscription/screens/subscription_screen.dart';
import '../../subscription/screens/vip_weather_screen.dart';
import '../../profile/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isVip = false; // Will be loaded from storage

  @override
  void initState() {
    super.initState();
    _loadVipStatus();
  }

  void _loadVipStatus() async {
    final userType = await SecureStorage.getUserType();
    setState(() {
      _isVip = userType == 'vip';
    });
  }

  List<Widget> get _screens => [
    const DashboardScreen(),
    const CalendarScreen(),
    // Show VipWeatherScreen for VIP users, SubscriptionScreen for regular users
    _isVip ? const VipWeatherScreen() : const SubscriptionScreen(),
    const ProfileScreen(),
  ];

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
