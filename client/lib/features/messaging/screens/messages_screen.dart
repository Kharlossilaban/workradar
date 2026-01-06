import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/bot_message.dart';
import '../providers/messaging_provider.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? AppTheme.darkBackground : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Pesan dari Bot Assistant'),
        centerTitle: true,
        backgroundColor: isDarkMode ? AppTheme.darkCard : Colors.white,
        elevation: 0,
        actions: [
          Consumer<MessagingProvider>(
            builder: (context, provider, child) {
              if (provider.unreadCount > 0) {
                return TextButton(
                  onPressed: () => provider.markAllAsRead(),
                  child: const Text('Tandai Semua Dibaca'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Iconsax.more),
            onSelected: (value) {
              if (value == 'clear_all') {
                _showClearConfirmation(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Iconsax.trash, size: 18),
                    SizedBox(width: 8),
                    Text('Hapus Semua'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<MessagingProvider>(
        builder: (context, provider, child) {
          final messages = provider.messages;

          if (messages.isEmpty) {
            return _buildEmptyState(isDarkMode);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return _MessageCard(
                message: message,
                isDarkMode: isDarkMode,
                onTap: () => _showMessageDetail(context, message, provider),
                onDelete: () => _confirmDelete(context, message, provider),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.message,
            size: 80,
            color: textSecondaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Pesan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pesan dari Bot Assistant akan muncul di sini',
            style: TextStyle(
              fontSize: 14,
              color: textSecondaryColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageDetail(
    BuildContext context,
    BotMessage message,
    MessagingProvider provider,
  ) {
    // Mark as read when opened
    if (!message.isRead) {
      provider.markAsRead(message.id);
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getMessageColor(
                      message.type,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getMessageIcon(message.type),
                    color: _getMessageColor(message.type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat(
                          'dd MMM yyyy, HH:mm',
                          'id_ID',
                        ).format(message.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Content
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: textPrimaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Delete button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDelete(context, message, provider);
                },
                icon: const Icon(Iconsax.trash, size: 18),
                label: const Text('Hapus Pesan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    BotMessage message,
    MessagingProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pesan?'),
        content: const Text('Pesan yang dihapus tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteMessage(message.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Pesan dihapus')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua Pesan?'),
        content: const Text(
          'Semua pesan dari Bot Assistant akan dihapus. '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<MessagingProvider>().clearAll();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Semua pesan dihapus')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }

  IconData _getMessageIcon(MessageType type) {
    switch (type) {
      case MessageType.payment:
        return Iconsax.wallet;
      case MessageType.welcome:
        return Iconsax.emoji_happy;
      case MessageType.tip:
        return Iconsax.lamp_on;
      case MessageType.alert:
        return Iconsax.warning_2;
      case MessageType.update:
        return Iconsax.info_circle;
    }
  }

  Color _getMessageColor(MessageType type) {
    switch (type) {
      case MessageType.payment:
        return const Color(0xFF4CAF50); // Green
      case MessageType.welcome:
        return const Color(0xFFFF9800); // Orange
      case MessageType.tip:
        return const Color(0xFF2196F3); // Blue
      case MessageType.alert:
        return const Color(0xFFF44336); // Red
      case MessageType.update:
        return const Color(0xFF9C27B0); // Purple
    }
  }
}

class _MessageCard extends StatelessWidget {
  final BotMessage message;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MessageCard({
    required this.message,
    required this.isDarkMode,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDarkMode ? AppTheme.darkCard : Colors.white;
    final textPrimaryColor = isDarkMode
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: message.isRead
            ? null
            : Border.all(
                color: _getMessageColor().withValues(alpha: 0.3),
                width: 2,
              ),
        boxShadow: isDarkMode ? null : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getMessageColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getMessageIcon(),
                    color: _getMessageColor(),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: message.isRead
                                    ? FontWeight.w600
                                    : FontWeight.bold,
                                color: textPrimaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!message.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getMessageColor(),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message.content,
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondaryColor,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(message.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getMessageIcon() {
    switch (message.type) {
      case MessageType.payment:
        return Iconsax.wallet;
      case MessageType.welcome:
        return Iconsax.emoji_happy;
      case MessageType.tip:
        return Iconsax.lamp_on;
      case MessageType.alert:
        return Iconsax.warning_2;
      case MessageType.update:
        return Iconsax.info_circle;
    }
  }

  Color _getMessageColor() {
    switch (message.type) {
      case MessageType.payment:
        return const Color(0xFF4CAF50);
      case MessageType.welcome:
        return const Color(0xFFFF9800);
      case MessageType.tip:
        return const Color(0xFF2196F3);
      case MessageType.alert:
        return const Color(0xFFF44336);
      case MessageType.update:
        return const Color(0xFF9C27B0);
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Baru saja';
        }
        return '${difference.inMinutes} menit yang lalu';
      }
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else {
      return DateFormat('dd MMM yyyy', 'id_ID').format(dateTime);
    }
  }
}
