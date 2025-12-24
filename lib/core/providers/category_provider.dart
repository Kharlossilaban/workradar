import 'package:flutter/foundation.dart' hide Category;
import '../models/category.dart';
import '../models/task.dart';

class CategoryProvider extends ChangeNotifier {
  final List<Category> _categories = [
    Category(id: 'cat_1', userId: 'user_1', name: 'Kerja', isDefault: true),
    Category(id: 'cat_2', userId: 'user_1', name: 'Pribadi', isDefault: true),
    Category(id: 'cat_3', userId: 'user_1', name: 'Wishlist', isDefault: true),
    Category(
      id: 'cat_4',
      userId: 'user_1',
      name: 'Hari Ulang Tahun',
      isDefault: true,
    ),
  ];

  List<Category> get categories =>
      List.unmodifiable(_categories.where((cat) => !cat.isHidden).toList());

  List<Category> get allCategories => List.unmodifiable(_categories);

  /// Get visible category names for dashboard filter
  List<String> get categoryNames {
    final names = ['Semua'];
    names.addAll(
      _categories.where((cat) => !cat.isHidden).map((cat) => cat.name),
    );
    return names;
  }

  /// Get task count for a specific category
  int getTaskCountForCategory(String categoryName, List<Task> tasks) {
    return tasks.where((task) => task.categoryName == categoryName).length;
  }

  /// Add a new category
  void addCategory(String name) {
    final newCategory = Category(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'user_1',
      name: name,
      isDefault: false,
    );
    _categories.add(newCategory);
    notifyListeners();
  }

  /// Edit category name
  void editCategory(String id, String newName) {
    final index = _categories.indexWhere((cat) => cat.id == id);
    if (index != -1) {
      _categories[index] = _categories[index].copyWith(name: newName);
      notifyListeners();
    }
  }

  /// Hide/Unhide category
  void toggleHideCategory(String id) {
    final index = _categories.indexWhere((cat) => cat.id == id);
    if (index != -1) {
      _categories[index] = _categories[index].copyWith(
        isHidden: !_categories[index].isHidden,
      );
      notifyListeners();
    }
  }

  /// Delete category
  void deleteCategory(String id) {
    _categories.removeWhere((cat) => cat.id == id);
    notifyListeners();
  }

  /// Check if category can be deleted (not default)
  bool canDeleteCategory(String id) {
    final category = _categories.firstWhere(
      (cat) => cat.id == id,
      orElse: () => Category(id: '', userId: '', name: ''),
    );
    return !category.isDefault;
  }
}
