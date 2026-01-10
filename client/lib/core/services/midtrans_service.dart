import '../models/payment.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'package:dio/dio.dart';

class MidtransService {
  final ApiClient _apiClient = ApiClient();

  // VIP Pricing
  static const int vipMonthlyPrice = 15000; // Rp 15.000 per month
  static const int vipYearlyPrice = 150000; // Rp 150.000 per year (save 30K)

  /// Create a new payment transaction
  /// Returns Payment object with snap_token for redirect
  Future<Payment> createPayment({
    required String userId,
    required String userEmail,
    required String userName,
    required String planType, // 'monthly' or 'yearly'
  }) async {
    try {
      final amount = planType == 'yearly' ? vipYearlyPrice : vipMonthlyPrice;
      
      final response = await _apiClient.post(
        '/payments/create',
        data: {
          'plan_type': planType,
          'amount': amount,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        
        // Create payment object from response
        return Payment(
          id: data['order_id'] ?? '',
          userId: userId,
          orderId: data['order_id'] ?? '',
          plan: SubscriptionPlan.vip,
          amount: amount,
          status: PaymentStatus.pending,
          snapToken: data['token'],
          redirectUrl: data['redirect_url'],
          createdAt: DateTime.now(),
          metadata: {
            'plan_type': planType,
            'user_email': userEmail,
            'user_name': userName,
          },
        );
      } else {
        throw ApiException(
          message: response.data['error'] ?? 'Failed to create payment',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Check payment status
  Future<Payment> checkPaymentStatus({
    required String orderId,
  }) async {
    try {
      final response = await _apiClient.get('/payments/$orderId');

      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        return Payment.fromJson(data);
      } else {
        throw ApiException(
          message: response.data['error'] ?? 'Failed to check payment status',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get user's payment history
  Future<List<Payment>> getPaymentHistory({
    required String userId,
  }) async {
    try {
      final response = await _apiClient.get('/payments/history');

      if (response.statusCode == 200) {
        final List<dynamic> paymentsJson = response.data['data'] ?? [];
        return paymentsJson.map((json) => Payment.fromJson(json)).toList();
      } else {
        throw ApiException(
          message: response.data['error'] ?? 'Failed to get payment history',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Cancel pending payment
  Future<bool> cancelPayment({required String orderId}) async {
    try {
      final response = await _apiClient.post('/payments/$orderId/cancel');
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // Helper method to get price by plan type
  static int getPriceByPlan(String planType) {
    return planType == 'yearly' ? vipYearlyPrice : vipMonthlyPrice;
  }
}
