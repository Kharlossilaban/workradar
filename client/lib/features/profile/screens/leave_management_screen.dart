import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/leave.dart';
import '../providers/leave_provider.dart';

class LeaveManagementScreen extends StatefulWidget {
  final String userId;

  const LeaveManagementScreen({super.key, required this.userId});

  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? AppTheme.darkBackground : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Manajemen Cuti'),
        centerTitle: true,
        backgroundColor: isDarkMode ? AppTheme.darkCard : Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Mendatang'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUpcomingLeaves(isDarkMode),
          _buildPastLeaves(isDarkMode),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLeaveDialog(context),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Iconsax.add, color: Colors.white),
        tooltip: 'Tambah Cuti',
      ),
    );
  }

  Widget _buildUpcomingLeaves(bool isDarkMode) {
    return Consumer<LeaveProvider>(
      builder: (context, provider, child) {
        final upcomingLeaves = provider.getUpcomingLeaves();

        if (upcomingLeaves.isEmpty) {
          return _buildEmptyState(
            isDarkMode,
            'Belum Ada Cuti Mendatang',
            'Tambahkan cuti untuk merencanakan hari libur Anda',
            Iconsax.calendar_tick,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: upcomingLeaves.length,
          itemBuilder: (context, index) {
            final leave = upcomingLeaves[index];
            return _LeaveCard(
              leave: leave,
              isDarkMode: isDarkMode,
              isUpcoming: true,
              onDelete: () => _confirmDeleteLeave(leave, provider),
            );
          },
        );
      },
    );
  }

  Widget _buildPastLeaves(bool isDarkMode) {
    return Consumer<LeaveProvider>(
      builder: (context, provider, child) {
        final pastLeaves = provider.getPastLeaves();

        if (pastLeaves.isEmpty) {
          return _buildEmptyState(
            isDarkMode,
            'Belum Ada Riwayat Cuti',
            'Cuti yang sudah lewat akan muncul di sini',
            Iconsax.archive_tick,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pastLeaves.length,
          itemBuilder: (context, index) {
            final leave = pastLeaves[index];
            return _LeaveCard(
              leave: leave,
              isDarkMode: isDarkMode,
              isUpcoming: false,
              onDelete: () => _confirmDeleteLeave(leave, provider),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(
    bool isDarkMode,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: textSecondaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: textSecondaryColor.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showAddLeaveDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    DateTime selectedDate = DateTime.now();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDarkMode ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Iconsax.calendar_add,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Tambah Cuti'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date selector
              const Text(
                'Tanggal Cuti',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.calendar, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat(
                          'EEEE, dd MMMM yyyy',
                          'id_ID',
                        ).format(selectedDate),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Reason input
              const Text(
                'Alasan Cuti',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'Contoh: Liburan keluarga',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Iconsax.note_text),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Harap isi alasan cuti')),
                  );
                  return;
                }

                // Show confirmation dialog
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('Konfirmasi'),
                    content: Text(
                      'Yakin ingin menambahkan cuti pada ${DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(selectedDate)}?\n\n'
                      'Alasan: ${reasonController.text.trim()}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx); // Close confirmation

                          final leave = Leave(
                            id: 'leave_${DateTime.now().millisecondsSinceEpoch}',
                            userId: widget.userId,
                            date: selectedDate,
                            reason: reasonController.text.trim(),
                            createdAt: DateTime.now(),
                          );

                          context.read<LeaveProvider>().addLeave(leave);
                          Navigator.pop(context); // Close add dialog

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cuti ditambahkan: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                        ),
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteLeave(Leave leave, LeaveProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Cuti?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus cuti pada ${DateFormat('dd MMMM yyyy', 'id_ID').format(leave.date)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteLeave(leave.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Cuti dihapus')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final Leave leave;
  final bool isDarkMode;
  final bool isUpcoming;
  final VoidCallback onDelete;

  const _LeaveCard({
    required this.leave,
    required this.isDarkMode,
    required this.isUpcoming,
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

    final daysUntil = leave.date.difference(DateTime.now()).inDays;
    final statusColor = isUpcoming ? Colors.orange : Colors.grey;
    final statusText = isUpcoming
        ? daysUntil == 0
              ? 'Hari ini'
              : daysUntil == 1
              ? 'Besok'
              : '$daysUntil hari lagi'
        : 'Sudah lewat';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isUpcoming
            ? Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 2,
              )
            : null,
        boxShadow: isDarkMode ? null : AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Date indicator
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('dd').format(leave.date),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  Text(
                    DateFormat('MMM', 'id_ID').format(leave.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Leave info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE', 'id_ID').format(leave.date),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    leave.reason,
                    style: TextStyle(fontSize: 13, color: textSecondaryColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Delete button
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Iconsax.trash, color: Colors.red, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
