import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/task_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/category_provider.dart';
import 'core/services/fcm_service.dart';
import 'features/profile/providers/workload_provider.dart';
import 'features/profile/providers/completed_tasks_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/profile/providers/holiday_provider.dart';
import 'features/profile/providers/leave_provider.dart';
import 'features/messaging/providers/messaging_provider.dart';
import 'features/auth/screens/auth_check_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for Indonesian locale
  await initializeDateFormatting('id_ID', null);

  // Initialize Firebase Cloud Messaging
  await FCMService().initialize();

  runApp(const WorkradarApp());
}

class WorkradarApp extends StatelessWidget {
  const WorkradarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TaskProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => CategoryProvider()),
        ChangeNotifierProvider(create: (context) => WorkloadProvider()),
        ChangeNotifierProvider(create: (context) => CompletedTasksProvider()),
        ChangeNotifierProvider(create: (context) => ProfileProvider()),
        ChangeNotifierProvider(create: (context) => HolidayProvider()),
        ChangeNotifierProvider(create: (context) => LeaveProvider()),
        ChangeNotifierProvider(create: (context) => MessagingProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Workradar',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AuthCheckScreen(),
          );
        },
      ),
    );
  }
}
