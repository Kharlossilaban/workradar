import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/payment.dart';
import '../config/environment.dart';

class MidtransService {
  // Use centralized environment config instead of hardcoded URL
  static String get _baseUrl => AppConfig.baseUrl;

  // VIP Pricing (as per requirements)
  static const int vipMonthlyPrice = 15000; // Rp 15.000 per month
  static const int vipAnnualPrice = 100000; // Rp 100.000 per year

  /// Create a new payment transaction
  /// Returns Payment object with snap_token for redirect
  Future<Payment> createPayment({
    required String userId,
    required String userEmail,
    required String userName,
    required SubscriptionPlan plan,
    String? token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/payments/create'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'user_email': userEmail,
          'user_name': userName,
          'plan': _planToString(plan),
          'amount': _getPlanAmount(plan),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Payment.fromJson(data['payment']);
      } else {
        throw Exception('Failed to create payment: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating payment: $e');
    }
  }

  /// Check payment status
  Future<Payment> checkPaymentStatus({
    required String orderId,
    String? token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/payments/$orderId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Payment.fromJson(data['payment']);
      } else {
        throw Exception('Failed to check payment status: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error checking payment status: $e');
    }
  }

  /// Get user's payment history
  Future<List<Payment>> getPaymentHistory({
    required String userId,
    String? token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/payments/history?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> paymentsJson = data['payments'];
        return paymentsJson.map((json) => Payment.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get payment history: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting payment history: $e');
    }
  }

  /// Cancel pending payment
  Future<bool> cancelPayment({required String orderId, String? token}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/payments/$orderId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error cancelling payment: $e');
    }
  }

  // Helper methods
  static int _getPlanAmount(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.vip:
        return vipMonthlyPrice;
      case SubscriptionPlan.free:
        return 0;
    }
  }

  static String _planToString(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.vip:
        return 'vip';
      case SubscriptionPlan.free:
        return 'free';
    }
  }
}
