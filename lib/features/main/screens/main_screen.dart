import 'package:flutter/material.dart';
import '../../../core/widgets/bottom_nav.dart';
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

  // VIP status flag - should be synced with actual user status
  // Set to true for VIP access during UI/UX testing
  final bool _isVip = true;

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
