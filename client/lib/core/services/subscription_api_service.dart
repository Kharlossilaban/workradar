import 'package:dio/dio.dart';
import 'package:workradar/core/network/api_client.dart';
import 'package:workradar/core/network/api_exception.dart';

/// Subscription API Service
class SubscriptionApiService {
  final ApiClient _apiClient = ApiClient();

  /// Upgrade to VIP
  Future<SubscriptionResponse> upgradeToVip({
    required String planType, // 'monthly' or 'yearly'
    required String paymentMethod,
    required String transactionId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/subscription/upgrade',
        data: {
          'plan_type': planType,
          'payment_method': paymentMethod,
          'transaction_id': transactionId,
        },
      );

      if (response.statusCode == 201) {
        return SubscriptionResponse.fromJson(response.data);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to upgrade',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get VIP status
  Future<VipStatus> getVipStatus() async {
    try {
      final response = await _apiClient.get('/subscription/status');

      if (response.statusCode == 200) {
        return VipStatus.fromJson(response.data);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to get status',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get subscription history
  Future<List<SubscriptionModel>> getHistory() async {
    try {
      final response = await _apiClient.get('/subscription/history');

      if (response.statusCode == 200) {
        final List<dynamic> subscriptionsJson =
            response.data['subscriptions'] ?? [];
        return subscriptionsJson
            .map((json) => SubscriptionModel.fromJson(json))
            .toList();
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to get history',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// Subscription Response
class SubscriptionResponse {
  final String message;
  final SubscriptionModel subscription;

  SubscriptionResponse({required this.message, required this.subscription});

  factory SubscriptionResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionResponse(
      message: json['message'] ?? '',
      subscription: SubscriptionModel.fromJson(json['subscription']),
    );
  }
}

/// VIP Status
class VipStatus {
  final bool isVip;
  final DateTime? vipExpiresAt;
  final int daysRemaining;
  final SubscriptionModel? activeSubscription;

  VipStatus({
    required this.isVip,
    this.vipExpiresAt,
    required this.daysRemaining,
    this.activeSubscription,
  });

  factory VipStatus.fromJson(Map<String, dynamic> json) {
    return VipStatus(
      isVip: json['is_vip'] ?? false,
      vipExpiresAt: json['vip_expires_at'] != null
          ? DateTime.parse(json['vip_expires_at'])
          : null,
      daysRemaining: json['days_remaining'] ?? 0,
      activeSubscription: json['active_subscription'] != null
          ? SubscriptionModel.fromJson(json['active_subscription'])
          : null,
    );
  }
}

/// Subscription Model
class SubscriptionModel {
  final String id;
  final String userId;
  final String planType;
  final int price;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String? paymentMethod;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubscriptionModel({
    required this.id,
    required this.userId,
    required this.planType,
    required this.price,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    this.paymentMethod,
    this.transactionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      planType: json['plan_type'] ?? 'monthly',
      price: json['price'] ?? 0,
      startDate: DateTime.parse(
        json['start_date'] ?? DateTime.now().toIso8601String(),
      ),
      endDate: DateTime.parse(
        json['end_date'] ?? DateTime.now().toIso8601String(),
      ),
      isActive: json['is_active'] ?? false,
      paymentMethod: json['payment_method'],
      transactionId: json['transaction_id'],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  String get formattedPrice {
    return 'Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }
}
