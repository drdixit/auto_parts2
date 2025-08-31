import 'package:auto_parts2/database/database_helper.dart';
import 'package:auto_parts2/models/main_category.dart';
import 'package:auto_parts2/services/product_service.dart';

class MainCategoryService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ProductService _productService = ProductService();

  Future<List<MainCategory>> getAllCategories({
    bool includeInactive = false,
  }) async {
    String? where;
    List<dynamic>? whereArgs;

    if (!includeInactive) {
      where = 'is_active = ?';
      whereArgs = [1];
    }

    final maps = await _dbHelper.getRecords(
      'main_categories',
      where: where,
      whereArgs: whereArgs,
    );

    return List.generate(maps.length, (i) {
      return MainCategory.fromMap(maps[i]);
    });
  }

  Future<MainCategory?> getCategoryById(int id) async {
    final maps = await _dbHelper.getRecords(
      'main_categories',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return MainCategory.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertCategory(MainCategory category) async {
    // Input validation
    _validateCategoryInput(category);

    final data = category.toMap();
    data.remove('id'); // Remove id for insert
    return await _dbHelper.insertRecord('main_categories', data);
  }

  Future<int> updateCategory(MainCategory category) async {
    if (category.id == null) {
      throw ArgumentError('Category ID cannot be null for update');
    }

    // Input validation
    _validateCategoryInput(category);

    final data = category.toMap();
    data['updated_at'] = DateTime.now().toIso8601String();
    data.remove('id'); // Remove id from data map

    return await _dbHelper.updateRecord('main_categories', data, 'id = ?', [
      category.id!,
    ]);
  }

  // Private validation method
  void _validateCategoryInput(MainCategory category) {
    if (category.name.trim().isEmpty) {
      throw ArgumentError('Category name cannot be empty');
    }
    if (category.name.trim().length > 100) {
      throw ArgumentError('Category name cannot exceed 100 characters');
    }
    if (category.description != null && category.description!.length > 1000) {
      throw ArgumentError('Category description cannot exceed 1000 characters');
    }
    // Sanitize name - check for dangerous characters
    final dangerousChars = [';', "'", '"', '`', '--', '/*'];
    for (final char in dangerousChars) {
      if (category.name.contains(char)) {
        throw ArgumentError('Category name contains invalid characters');
      }
    }
  }

  Future<int> deleteCategory(int id) async {
    return await _dbHelper.deleteRecord('main_categories', 'id = ?', [id]);
  }

  Future<int> softDeleteCategory(int id) async {
    return await _dbHelper.softDeleteRecord('main_categories', id);
  }

  Future<int> toggleCategoryStatus(int id, bool isActive) async {
    final db = await _dbHelper.database;

    // Start a transaction to ensure atomicity
    return await db.transaction((txn) async {
      try {
        // Update the main category status
        await txn.update(
          'main_categories',
          {
            'is_active': isActive ? 1 : 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );

        if (!isActive) {
          // When DEACTIVATING main category:
          // DON'T change sub-category is_active flags - preserve individual states
          // Sub-categories will appear inactive in UI due to filtering logic
          // but maintain their individual is_active state in database

          // Handle product cascading
          await _productService.handleMainCategoryCascade(id, false, txn: txn);
        } else {
          // When REACTIVATING main category:
          // DON'T change sub-category is_active flags - preserve individual states
          // Sub-categories will appear according to their individual is_active state

          // Handle product cascading
          await _productService.handleMainCategoryCascade(id, true, txn: txn);
        }

        return 1; // Return success
      } catch (e) {
        // Transaction will automatically rollback on error
        rethrow;
      }
    });
  }

  Future<List<MainCategory>> searchCategories(String searchTerm) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT * FROM main_categories
      WHERE (name LIKE ? OR description LIKE ?)
      AND is_active = 1
      ORDER BY sort_order, name
    ''',
      ['%$searchTerm%', '%$searchTerm%'],
    );

    return List.generate(maps.length, (i) {
      return MainCategory.fromMap(maps[i]);
    });
  }

  Future<bool> isCategoryNameExists(String name, {int? excludeId}) async {
    String where = 'LOWER(name) = ?';
    List<dynamic> whereArgs = [name.toLowerCase()];

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final maps = await _dbHelper.getRecords(
      'main_categories',
      where: where,
      whereArgs: whereArgs,
    );

    return maps.isNotEmpty;
  }

  Future<int> getNextSortOrder() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT MAX(sort_order) as max_order FROM main_categories',
    );
    final maxOrder = result.first['max_order'] as int?;
    return (maxOrder ?? 0) + 1;
  }

  Future<int> getCategoryCount({bool includeInactive = false}) async {
    String? where;
    List<dynamic>? whereArgs;

    if (!includeInactive) {
      where = 'is_active = ?';
      whereArgs = [1];
    }

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM main_categories${where != null ? ' WHERE $where' : ''}',
      whereArgs,
    );

    return result.first['count'] as int;
  }
}
