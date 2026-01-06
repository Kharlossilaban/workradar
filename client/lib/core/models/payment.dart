enum PaymentStatus { pending, success, failed, expired, cancelled }

enum SubscriptionPlan { free, vip }

class Payment {
  final String id;
  final String userId;
  final String orderId;
  final SubscriptionPlan plan;
  final int amount;
  final PaymentStatus status;
  final String? snapToken; // Midtrans Snap token
  final String? redirectUrl; // Midtrans redirect URL
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? expiredAt;
  final Map<String, dynamic>? metadata;

  Payment({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.plan,
    required this.amount,
    required this.status,
    this.snapToken,
    this.redirectUrl,
    required this.createdAt,
    this.paidAt,
    this.expiredAt,
    this.metadata,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      orderId: json['order_id'] as String,
      plan: _parsePlan(json['plan'] as String),
      amount: json['amount'] as int,
      status: _parseStatus(json['status'] as String),
      snapToken: json['snap_token'] as String?,
      redirectUrl: json['redirect_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      expiredAt: json['expired_at'] != null
          ? DateTime.parse(json['expired_at'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'order_id': orderId,
      'plan': _planToString(plan),
      'amount': amount,
      'status': _statusToString(status),
      if (snapToken != null) 'snap_token': snapToken,
      if (redirectUrl != null) 'redirect_url': redirectUrl,
      'created_at': createdAt.toIso8601String(),
      if (paidAt != null) 'paid_at': paidAt!.toIso8601String(),
      if (expiredAt != null) 'expired_at': expiredAt!.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  Payment copyWith({
    String? id,
    String? userId,
    String? orderId,
    SubscriptionPlan? plan,
    int? amount,
    PaymentStatus? status,
    String? snapToken,
    String? redirectUrl,
    DateTime? createdAt,
    DateTime? paidAt,
    DateTime? expiredAt,
    Map<String, dynamic>? metadata,
  }) {
    return Payment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      orderId: orderId ?? this.orderId,
      plan: plan ?? this.plan,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      snapToken: snapToken ?? this.snapToken,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      createdAt: createdAt ?? this.createdAt,
      paidAt: paidAt ?? this.paidAt,
      expiredAt: expiredAt ?? this.expiredAt,
      metadata: metadata ?? this.metadata,
    );
  }

  static PaymentStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'success':
        return PaymentStatus.success;
      case 'failed':
        return PaymentStatus.failed;
      case 'expired':
        return PaymentStatus.expired;
      case 'cancelled':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.pending;
    }
  }

  static String _statusToString(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.success:
        return 'success';
      case PaymentStatus.failed:
        return 'failed';
      case PaymentStatus.expired:
        return 'expired';
      case PaymentStatus.cancelled:
        return 'cancelled';
    }
  }

  static SubscriptionPlan _parsePlan(String plan) {
    switch (plan.toLowerCase()) {
      case 'vip':
        return SubscriptionPlan.vip;
      case 'free':
      default:
        return SubscriptionPlan.free;
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

  bool get isPending => status == PaymentStatus.pending;
  bool get isSuccess => status == PaymentStatus.success;
  bool get isFailed => status == PaymentStatus.failed;
  bool get isExpired => status == PaymentStatus.expired;
  bool get isCancelled => status == PaymentStatus.cancelled;
}
