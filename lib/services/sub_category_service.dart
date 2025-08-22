import '../database/database_helper.dart';
import '../models/sub_category.dart';

class SubCategoryService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<SubCategory>> getAllSubCategories({
    bool includeInactive = false,
  }) async {
    final db = await _dbHelper.database;

    // Complex query to handle the two-flag system properly
    // A sub-category is "effectively active" if:
    // 1. is_active = 1 AND main_category is_active = 1
    // A sub-category is "effectively inactive" if:
    // 1. is_active = 0 (regardless of main category status)
    // 2. OR main_category is_active = 0 (even if sub-category is_active = 1)

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (!includeInactive) {
      // Only show sub-categories that are active AND have active main categories
      whereClause = 'WHERE sc.is_active = 1 AND mc.is_active = 1';
    }

    final maps = await db.rawQuery('''
      SELECT sc.*, mc.name as main_category_name, mc.is_active as main_category_is_active
      FROM sub_categories sc
      LEFT JOIN main_categories mc ON sc.main_category_id = mc.id
      $whereClause
      ORDER BY sc.sort_order, sc.name
    ''', whereArgs);

    return List.generate(maps.length, (i) {
      final map = Map<String, dynamic>.from(maps[i]);
      // Add computed effective status
      final isMainCategoryActive = (map['main_category_is_active'] ?? 1) == 1;
      final isSubCategoryActive = (map['is_active'] ?? 1) == 1;

      // Effective status: sub-category is effectively active only if both are active
      map['is_effectively_active'] =
          isMainCategoryActive && isSubCategoryActive;

      return SubCategory.fromMap(map);
    });
  }

  Future<List<SubCategory>> getSubCategoriesByMainCategory(
    int mainCategoryId, {
    bool includeInactive = false,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = 'WHERE sc.main_category_id = ?';
    List<dynamic> whereArgs = [mainCategoryId];

    if (!includeInactive) {
      // Only show sub-categories that are active AND have active main categories
      whereClause += ' AND sc.is_active = 1 AND mc.is_active = 1';
    }

    final maps = await db.rawQuery('''
      SELECT sc.*, mc.name as main_category_name, mc.is_active as main_category_is_active
      FROM sub_categories sc
      LEFT JOIN main_categories mc ON sc.main_category_id = mc.id
      $whereClause
      ORDER BY sc.sort_order, sc.name
    ''', whereArgs);

    return List.generate(maps.length, (i) {
      final map = Map<String, dynamic>.from(maps[i]);
      // Add computed effective status
      final isMainCategoryActive = (map['main_category_is_active'] ?? 1) == 1;
      final isSubCategoryActive = (map['is_active'] ?? 1) == 1;

      // Effective status: sub-category is effectively active only if both are active
      map['is_effectively_active'] =
          isMainCategoryActive && isSubCategoryActive;

      return SubCategory.fromMap(map);
    });
  }

  Future<SubCategory?> getSubCategoryById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT sc.*, mc.name as main_category_name
      FROM sub_categories sc
      LEFT JOIN main_categories mc ON sc.main_category_id = mc.id
      WHERE sc.id = ?
    ''',
      [id],
    );

    if (maps.isNotEmpty) {
      return SubCategory.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertSubCategory(SubCategory subCategory) async {
    // Input validation
    _validateSubCategoryInput(subCategory);

    // Check for duplicate name within the same main category
    final nameExists = await isSubCategoryNameExists(
      subCategory.name.trim(),
      subCategory.mainCategoryId,
    );
    if (nameExists) {
      throw ArgumentError(
        'A sub-category with the name "${subCategory.name.trim()}" already exists in this main category. Please choose a different name.',
      );
    }

    final data = subCategory.toMap();
    data.remove('id'); // Remove id for insert
    data.remove('main_category_name'); // Remove joined field

    try {
      return await _dbHelper.insertRecord('sub_categories', data);
    } catch (e) {
      // Check if it's a constraint violation error
      if (e.toString().contains('UNIQUE constraint failed')) {
        throw ArgumentError(
          'A sub-category with this name already exists in the selected main category. Please choose a different name.',
        );
      }
      // Re-throw other database errors
      rethrow;
    }
  }

  Future<int> updateSubCategory(SubCategory subCategory) async {
    if (subCategory.id == null) {
      throw ArgumentError('SubCategory ID cannot be null for update');
    }

    // Input validation
    _validateSubCategoryInput(subCategory);

    // Check for duplicate name within the same main category (excluding current record)
    final nameExists = await isSubCategoryNameExists(
      subCategory.name.trim(),
      subCategory.mainCategoryId,
      excludeId: subCategory.id,
    );
    if (nameExists) {
      throw ArgumentError(
        'A sub-category with the name "${subCategory.name.trim()}" already exists in this main category. Please choose a different name.',
      );
    }

    final data = subCategory.toMap();
    data['updated_at'] = DateTime.now().toIso8601String();
    data.remove('id'); // Remove id from data map
    data.remove('main_category_name'); // Remove joined field

    try {
      return await _dbHelper.updateRecord('sub_categories', data, 'id = ?', [
        subCategory.id!,
      ]);
    } catch (e) {
      // Check if it's a constraint violation error
      if (e.toString().contains('UNIQUE constraint failed')) {
        throw ArgumentError(
          'A sub-category with this name already exists in the selected main category. Please choose a different name.',
        );
      }
      // Re-throw other database errors
      rethrow;
    }
  }

  // Private validation method
  void _validateSubCategoryInput(SubCategory subCategory) {
    if (subCategory.name.trim().isEmpty) {
      throw ArgumentError('Sub-category name cannot be empty');
    }
    if (subCategory.name.trim().length > 100) {
      throw ArgumentError('Sub-category name cannot exceed 100 characters');
    }
    if (subCategory.description != null &&
        subCategory.description!.length > 1000) {
      throw ArgumentError(
        'Sub-category description cannot exceed 1000 characters',
      );
    }
    if (subCategory.mainCategoryId <= 0) {
      throw ArgumentError('Valid main category must be selected');
    }
    // Sanitize name - check for dangerous characters
    final dangerousChars = [';', "'", '"', '`', '--', '/*'];
    for (final char in dangerousChars) {
      if (subCategory.name.contains(char)) {
        throw ArgumentError('Sub-category name contains invalid characters');
      }
    }
  }

  // Remove hard delete method - we only use soft delete in this project
  // Future<int> deleteSubCategory(int id) async {
  //   return await _dbHelper.deleteRecord('sub_categories', 'id = ?', [id]);
  // }

  Future<int> softDeleteSubCategory(int id) async {
    return await _dbHelper.softDeleteRecord('sub_categories', id);
  }

  Future<int> toggleSubCategoryStatus(int id, bool isActive) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      try {
        // Update sub-category status regardless of main category status
        // The effective status is handled by UI filtering, not database constraints
        await txn.update(
          'sub_categories',
          {
            'is_active': isActive ? 1 : 0,
            'is_manually_disabled': isActive ? 0 : 1, // Track user intent
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );

        return 1; // Return success
      } catch (e) {
        rethrow;
      }
    });
  }

  Future<List<SubCategory>> searchSubCategories(String searchTerm) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT sc.*, mc.name as main_category_name
      FROM sub_categories sc
      LEFT JOIN main_categories mc ON sc.main_category_id = mc.id
      WHERE (sc.name LIKE ? OR sc.description LIKE ? OR mc.name LIKE ?)
      AND sc.is_active = 1
      ORDER BY sc.sort_order, sc.name
    ''',
      ['%$searchTerm%', '%$searchTerm%', '%$searchTerm%'],
    );

    return List.generate(maps.length, (i) {
      return SubCategory.fromMap(maps[i]);
    });
  }

  Future<bool> isSubCategoryNameExists(
    String name,
    int mainCategoryId, {
    int? excludeId,
  }) async {
    String where = 'LOWER(name) = ? AND main_category_id = ?';
    List<dynamic> whereArgs = [name.toLowerCase(), mainCategoryId];

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final maps = await _dbHelper.getRecords(
      'sub_categories',
      where: where,
      whereArgs: whereArgs,
    );

    return maps.isNotEmpty;
  }

  Future<int> getNextSortOrder(int mainCategoryId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT MAX(sort_order) as max_order FROM sub_categories WHERE main_category_id = ?',
      [mainCategoryId],
    );
    final maxOrder = result.first['max_order'] as int?;
    return (maxOrder ?? 0) + 1;
  }

  Future<int> getSubCategoryCount({
    int? mainCategoryId,
    bool includeInactive = false,
  }) async {
    String where = '';
    List<dynamic> whereArgs = [];

    if (mainCategoryId != null) {
      where = 'main_category_id = ?';
      whereArgs.add(mainCategoryId);
    }

    if (!includeInactive) {
      if (where.isNotEmpty) {
        where += ' AND ';
      }
      where += 'is_active = ?';
      whereArgs.add(1);
    }

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sub_categories${where.isNotEmpty ? ' WHERE $where' : ''}',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return result.first['count'] as int;
  }

  Future<bool> hasProducts(int subCategoryId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE sub_category_id = ? AND is_active = 1',
      [subCategoryId],
    );

    return (result.first['count'] as int) > 0;
  }
}
