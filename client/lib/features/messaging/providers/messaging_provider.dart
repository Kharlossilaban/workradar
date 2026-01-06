import 'package:flutter/foundation.dart';
import '../../../core/models/bot_message.dart';

class MessagingProvider with ChangeNotifier {
  // Local message storage
  final List<BotMessage> _messages = [];

  /// Get all messages
  List<BotMessage> get messages => List.unmodifiable(_messages);

  /// Get unread message count
  int get unreadCount => _messages.where((m) => !m.isRead).length;

  /// Get messages by type
  List<BotMessage> getMessagesByType(MessageType type) {
    return _messages.where((m) => m.type == type).toList();
  }

  /// Add a new message
  void addMessage(BotMessage message) {
    _messages.insert(0, message); // Insert at beginning (newest first)
    notifyListeners();
  }

  /// Mark message as read
  void markAsRead(String messageId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  /// Mark all messages as read
  void markAllAsRead() {
    for (int i = 0; i < _messages.length; i++) {
      if (!_messages[i].isRead) {
        _messages[i] = _messages[i].copyWith(isRead: true);
      }
    }
    notifyListeners();
  }

  /// Delete a message
  void deleteMessage(String messageId) {
    _messages.removeWhere((m) => m.id == messageId);
    notifyListeners();
  }

  /// Clear all messages
  void clearAll() {
    _messages.clear();
    notifyListeners();
  }

  /// Generate welcome message for new VIP user
  void sendVipWelcomeMessage(String userId) {
    final message = BotMessage(
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      type: MessageType.welcome,
      title: 'Selamat Datang, Member VIP! 🎉',
      content:
          'Terima kasih telah bergabung sebagai member VIP Workradar! '
          'Anda sekarang dapat menikmati semua fitur premium termasuk:\n\n'
          '✨ Grafik workload Weekly & Monthly\n'
          '🌤️ Prakiraan cuaca real-time\n'
          '📊 Statistik lengkap tugas Anda\n'
          '🎯 Fitur-fitur eksklusif lainnya\n\n'
          'Selamat bekerja lebih produktif!',
      createdAt: DateTime.now(),
    );
    addMessage(message);
  }

  /// Generate payment success message
  void sendPaymentSuccessMessage(String userId, int amount) {
    final message = BotMessage(
      id: 'payment_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      type: MessageType.payment,
      title: 'Pembayaran Berhasil! ✅',
      content:
          'Pembayaran VIP subscription sebesar Rp ${_formatCurrency(amount)} '
          'telah berhasil diproses.\n\n'
          'Status VIP Anda sekarang aktif. Nikmati semua fitur premium!\n\n'
          'Terima kasih atas kepercayaan Anda.',
      createdAt: DateTime.now(),
      metadata: {'amount': amount},
    );
    addMessage(message);
  }

  /// Generate payment failed message
  void sendPaymentFailedMessage(String userId, String reason) {
    final message = BotMessage(
      id: 'payment_failed_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      type: MessageType.alert,
      title: 'Pembayaran Gagal ⚠️',
      content:
          'Maaf, pembayaran Anda tidak dapat diproses.\n\n'
          'Alasan: $reason\n\n'
          'Silakan coba lagi atau hubungi customer support jika masalah berlanjut.',
      createdAt: DateTime.now(),
    );
    addMessage(message);
  }

  /// Generate productivity tip message
  void sendProductivityTip(String userId, String tip) {
    final message = BotMessage(
      id: 'tip_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      type: MessageType.tip,
      title: 'Tips Produktivitas 💡',
      content: tip,
      createdAt: DateTime.now(),
    );
    addMessage(message);
  }

  /// Generate system update message
  void sendSystemUpdate(String userId, String title, String content) {
    final message = BotMessage(
      id: 'update_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      type: MessageType.update,
      title: title,
      content: content,
      createdAt: DateTime.now(),
    );
    addMessage(message);
  }

  /// Generate workload alert message
  void sendWorkloadAlert(String userId, String alertMessage) {
    final message = BotMessage(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      type: MessageType.alert,
      title: 'Peringatan Beban Kerja ⚡',
      content: alertMessage,
      createdAt: DateTime.now(),
    );
    addMessage(message);
  }

  // Helper method to format currency
  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  /// Load sample messages for demo
  void loadSampleMessages(String userId) {
    // Add some sample automated messages
    sendProductivityTip(
      userId,
      'Cobalah teknik Pomodoro: Kerja fokus 25 menit, istirahat 5 menit. '
      'Setelah 4 siklus, ambil istirahat panjang 15-30 menit. '
      'Metode ini terbukti meningkatkan produktivitas!',
    );

    final updateMessage = BotMessage(
      id: 'welcome_init',
      userId: userId,
      type: MessageType.update,
      title: 'Selamat Datang di Workradar! 👋',
      content:
          'Terima kasih telah menggunakan Workradar untuk mengelola tugas dan workload Anda. '
          'Bot Assistant ini akan membantu Anda dengan:\n\n'
          '📬 Notifikasi pembayaran\n'
          '💡 Tips produktivitas\n'
          '⚠️ Peringatan workload\n'
          '📢 Update fitur terbaru\n\n'
          'Atur jadwal kerja Anda di halaman Profile untuk mulai menggunakan semua fitur!',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: false,
    );
    addMessage(updateMessage);
  }
}
