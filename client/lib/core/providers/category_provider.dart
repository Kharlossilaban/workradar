import 'package:flutter/foundation.dart' hide Category;
import '../models/category.dart';
import '../models/task.dart';
import '../services/category_api_service.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryApiService _categoryApiService = CategoryApiService();

  List<Category> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  /// Load categories from server
  Future<void> loadCategories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final categoryModels = await _categoryApiService.getCategories();
      _categories = categoryModels
          .map(
            (model) => Category(
              id: model.id,
              userId: model.userId,
              name: model.name,
              isDefault: model.isDefault,
            ),
          )
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memuat kategori: $e';
      notifyListeners();
    }
  }

  /// Refresh categories from server
  Future<void> refreshCategories() async {
    await loadCategories();
  }

  /// Get task count for a specific category
  int getTaskCountForCategory(String categoryName, List<Task> tasks) {
    return tasks.where((task) => task.categoryName == categoryName).length;
  }

  /// Add a new category (to server and local)
  Future<void> addCategory(String name) async {
    try {
      final newCategoryModel = await _categoryApiService.createCategory(
        name: name,
        color: _getRandomColor(),
      );

      _categories.add(
        Category(
          id: newCategoryModel.id,
          userId: newCategoryModel.userId,
          name: newCategoryModel.name,
          isDefault: false,
        ),
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Gagal menambah kategori: $e';
      notifyListeners();
      rethrow;
    }
  }

  String _getRandomColor() {
    final colors = [
      '#6C5CE7',
      '#00B894',
      '#0984E3',
      '#FD79A8',
      '#FDCB6E',
      '#E17055',
      '#74B9FF',
      '#A29BFE',
    ];
    colors.shuffle();
    return colors.first;
  }

  /// Edit category name
  Future<void> editCategory(String id, String newName) async {
    try {
      await _categoryApiService.updateCategory(categoryId: id, name: newName);

      final index = _categories.indexWhere((cat) => cat.id == id);
      if (index != -1) {
        _categories[index] = _categories[index].copyWith(name: newName);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Gagal mengedit kategori: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Hide/Unhide category (local only for now)
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
  Future<void> deleteCategory(String id) async {
    try {
      await _categoryApiService.deleteCategory(id);
      _categories.removeWhere((cat) => cat.id == id);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Gagal menghapus kategori: $e';
      notifyListeners();
      rethrow;
    }
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
