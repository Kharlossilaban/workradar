// API Constants (will be used when backend is ready)
class ApiConstants {
  static const String baseUrl = 'http://localhost:8080/api';

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String googleAuth = '/auth/google';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Profile endpoints
  static const String profile = '/profile';

  // Tasks endpoints
  static const String tasks = '/tasks';
  static String taskById(String id) => '/tasks/$id';
  static String completeTask(String id) => '/tasks/$id/complete';
  static String duplicateTask(String id) => '/tasks/$id/duplicate';

  // Categories endpoints
  static const String categories = '/categories';

  // Workload endpoints
  static const String workloadDaily = '/workload/daily';
  static const String workloadWeekly = '/workload/weekly';
  static const String workloadMonthly = '/workload/monthly';

  // Weather endpoint
  static const String weather = '/weather';

  // Subscription endpoint
  static const String subscriptionUpgrade = '/subscription/upgrade';
}

// App constants
class AppConstants {
  // App info
  static const String appName = 'Workradar';
  static const String appVersion = '1.0.0';

  // Subscription prices (in IDR)
  static const int monthlyPrice = 15000;
  static const int yearlyPrice = 100000;

  // Task limits
  static const int vipHealthNotificationThreshold = 15; // tasks per day
  static const int vipHealthHoursThreshold = 12; // hours per day

  // Reminder options (in minutes)
  static const List<int> reminderOptions = [5, 10, 15, 30];

  // Repeat intervals
  static const List<String> repeatTypes = [
    'Jam',
    'Harian',
    'Mingguan',
    'Bulanan',
  ];

  // Default categories
  static const List<String> defaultCategories = [
    'Kerja',
    'Pribadi',
    'Wishlist',
    'Hari Ulang Tahun',
  ];
}
