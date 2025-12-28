import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/providers/task_provider.dart';
import '../widgets/edit_category_dialog.dart';

class ManageCategoryScreen extends StatelessWidget {
  const ManageCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final categories = categoryProvider.allCategories;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kategori'),
        leading: IconButton(
          icon: Icon(
            Iconsax.arrow_left,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: categories.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final taskCount = categoryProvider
                          .getTaskCountForCategory(
                            category.name,
                            taskProvider.tasks,
                          );

                      return _buildCategoryItem(
                        context,
                        category,
                        taskCount,
                        isDarkMode,
                        categoryProvider,
                      );
                    },
                  ),
          ),
          // Add New Category Button
          _buildAddNewButton(context, isDarkMode, categoryProvider),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.category,
            size: 80,
            color: AppTheme.primaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada kategori',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Buat kategori baru untuk mengorganisir tugas Anda',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context,
    dynamic category,
    int taskCount,
    bool isDarkMode,
    CategoryProvider categoryProvider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getCategoryColor(category.name).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getCategoryIcon(category.name),
            color: _getCategoryColor(category.name),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                category.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: category.isHidden
                      ? (isDarkMode
                            ? AppTheme.darkTextLight
                            : AppTheme.textLight)
                      : Theme.of(context).colorScheme.onSurface,
                  decoration: category.isHidden
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
            if (category.isHidden)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Tersembunyi',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Task count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$taskCount tugas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Options menu
            PopupMenuButton<String>(
              icon: Icon(
                Iconsax.more,
                color: isDarkMode
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppTheme.borderRadiusMedium,
                ),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showEditDialog(context, category, categoryProvider);
                    break;
                  case 'hide':
                    categoryProvider.toggleHideCategory(category.id);
                    _showSnackBar(
                      context,
                      category.isHidden
                          ? '${category.name} ditampilkan kembali'
                          : '${category.name} disembunyikan',
                    );
                    break;
                  case 'delete':
                    _showDeleteConfirmation(
                      context,
                      category,
                      categoryProvider,
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.edit,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 12),
                      const Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'hide',
                  child: Row(
                    children: [
                      Icon(
                        category.isHidden ? Iconsax.eye : Iconsax.eye_slash,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 12),
                      Text(category.isHidden ? 'Tampilkan' : 'Sembunyikan'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Iconsax.trash, size: 18, color: AppTheme.errorColor),
                      const SizedBox(width: 12),
                      Text(
                        'Hapus',
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewButton(
    BuildContext context,
    bool isDarkMode,
    CategoryProvider categoryProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: InkWell(
          onTap: () => _showCreateDialog(context, categoryProvider),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.add, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Buat Baru',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    dynamic category,
    CategoryProvider categoryProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => EditCategoryDialog(
        initialName: category.name,
        onSave: (newName) {
          categoryProvider.editCategory(category.id, newName);
          _showSnackBar(context, 'Kategori berhasil diubah');
        },
      ),
    );
  }

  void _showCreateDialog(
    BuildContext context,
    CategoryProvider categoryProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => EditCategoryDialog(
        onSave: (name) {
          categoryProvider.addCategory(name);
          _showSnackBar(context, 'Kategori baru berhasil dibuat');
        },
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    dynamic category,
    CategoryProvider categoryProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text(
          'Apakah Anda yakin ingin menghapus kategori "${category.name}"? '
          'Tugas dalam kategori ini tidak akan terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              categoryProvider.deleteCategory(category.id);
              Navigator.pop(context);
              _showSnackBar(context, 'Kategori berhasil dihapus');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Color _getCategoryColor(String name) {
    switch (name.toLowerCase()) {
      case 'kerja':
        return AppTheme.categoryWork;
      case 'pribadi':
        return AppTheme.categoryPersonal;
      case 'wishlist':
        return AppTheme.categoryWishlist;
      case 'hari ulang tahun':
        return AppTheme.categoryBirthday;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getCategoryIcon(String name) {
    switch (name.toLowerCase()) {
      case 'kerja':
        return Iconsax.briefcase;
      case 'pribadi':
        return Iconsax.user;
      case 'wishlist':
        return Iconsax.heart;
      case 'hari ulang tahun':
        return Iconsax.cake;
      default:
        return Iconsax.folder;
    }
  }
}
