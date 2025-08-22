import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/manufacturer.dart';
import '../models/sub_category.dart';
import '../models/vehicle_model.dart';
import '../models/product_compatibility.dart';
import '../models/product_image.dart';
import '../models/product_inventory.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqflite_common/sqlite_api.dart';

class ProductService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Get all products with joined data
  Future<List<Product>> getAllProducts({bool includeInactive = false}) async {
    final db = await _dbHelper.database;

    // Complex query to handle the cascading system properly
    // A product is "effectively active" if:
    // 1. p.is_active = 1 AND sc.is_active = 1 AND mc.is_active = 1
    // A product is "effectively inactive" if:
    // 1. p.is_active = 0 (manually disabled)
    // 2. OR sc.is_active = 0 (sub-category disabled)
    // 3. OR mc.is_active = 0 (main category disabled)

    String whereClause = '';
    if (!includeInactive) {
      whereClause = '''
        WHERE p.is_active = 1
        AND sc.is_active = 1
        AND mc.is_active = 1
      ''';
    }

    final String query =
        '''
      SELECT
        p.*,
        sc.name as sub_category_name,
        sc.is_active as sub_category_active,
        mc.name as main_category_name,
        mc.is_active as main_category_active,
        m.name as manufacturer_name,
        pi.image_path as primary_image_path,
        inv.stock_quantity,
        inv.selling_price,
        CASE
          WHEN p.is_active = 1 AND sc.is_active = 1 AND mc.is_active = 1 THEN 1
          ELSE 0
        END as is_effectively_active
      FROM products p
      LEFT JOIN sub_categories sc ON p.sub_category_id = sc.id
      LEFT JOIN main_categories mc ON sc.main_category_id = mc.id
      LEFT JOIN manufacturers m ON p.manufacturer_id = m.id
      LEFT JOIN product_images pi ON p.id = pi.product_id AND pi.is_primary = 1
      LEFT JOIN product_inventory inv ON p.id = inv.product_id AND inv.is_active = 1
      $whereClause
      ORDER BY p.name ASC
    ''';

    final results = await db.rawQuery(query);
    print('Loaded ${results.length} products from database');

    final products = results.map((map) {
      final product = Product.fromMap(map);
      if (product.primaryImagePath != null) {
        print(
          'Product ${product.name} has primary image: ${product.primaryImagePath}',
        );
      } else {
        print('Product ${product.name} has no primary image');
      }
      return product;
    }).toList();

    return products;
  }

  // Get products by sub-category
  Future<List<Product>> getProductsBySubCategory(
    int subCategoryId, {
    bool includeInactive = false,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = 'WHERE p.sub_category_id = ?';
    List<dynamic> whereArgs = [subCategoryId];

    if (!includeInactive) {
      whereClause += '''
        AND p.is_active = 1
        AND sc.is_active = 1
        AND mc.is_active = 1
      ''';
    }

    final String query =
        '''
      SELECT
        p.*,
        sc.name as sub_category_name,
        sc.is_active as sub_category_active,
        mc.name as main_category_name,
        mc.is_active as main_category_active,
        m.name as manufacturer_name,
        pi.image_path as primary_image_path,
        inv.stock_quantity,
        inv.selling_price,
        CASE
          WHEN p.is_active = 1 AND sc.is_active = 1 AND mc.is_active = 1 THEN 1
          ELSE 0
        END as is_effectively_active
      FROM products p
      LEFT JOIN sub_categories sc ON p.sub_category_id = sc.id
      LEFT JOIN main_categories mc ON sc.main_category_id = mc.id
      LEFT JOIN manufacturers m ON p.manufacturer_id = m.id
      LEFT JOIN product_images pi ON p.id = pi.product_id AND pi.is_primary = 1
      LEFT JOIN product_inventory inv ON p.id = inv.product_id AND inv.is_active = 1
      $whereClause
      ORDER BY p.name ASC
    ''';

    final results = await db.rawQuery(query, whereArgs);
    return results.map((map) => Product.fromMap(map)).toList();
  }

  // Get product by ID with full details
  Future<Product?> getProductById(int id) async {
    final db = await _dbHelper.database;

    final String query = '''
      SELECT
        p.*,
        sc.name as sub_category_name,
        mc.name as main_category_name,
        m.name as manufacturer_name,
        pi.image_path as primary_image_path,
        inv.stock_quantity,
        inv.selling_price,
        CASE
          WHEN p.is_active = 1 AND sc.is_active = 1 AND mc.is_active = 1 THEN 1
          ELSE 0
        END as is_effectively_active
      FROM products p
      LEFT JOIN sub_categories sc ON p.sub_category_id = sc.id
      LEFT JOIN main_categories mc ON sc.main_category_id = mc.id
      LEFT JOIN manufacturers m ON p.manufacturer_id = m.id
      LEFT JOIN product_images pi ON p.id = pi.product_id AND pi.is_primary = 1
      LEFT JOIN product_inventory inv ON p.id = inv.product_id AND inv.is_active = 1
      WHERE p.id = ?
    ''';

    final results = await db.rawQuery(query, [id]);
    if (results.isNotEmpty) {
      return Product.fromMap(results.first);
    }
    return null;
  }

  // Search products by name or part number
  Future<List<Product>> searchProducts(
    String query, {
    bool includeInactive = false,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = '''
      WHERE (p.name LIKE ? OR p.part_number LIKE ? OR m.name LIKE ? OR sc.name LIKE ? OR mc.name LIKE ?)
    ''';

    if (!includeInactive) {
      whereClause += '''
        AND p.is_active = 1
        AND sc.is_active = 1
        AND mc.is_active = 1
      ''';
    }

    final String searchQuery =
        '''
      SELECT
        p.*,
        sc.name as sub_category_name,
        mc.name as main_category_name,
        m.name as manufacturer_name,
        pi.image_path as primary_image_path,
        inv.stock_quantity,
        inv.selling_price,
        CASE
          WHEN p.is_active = 1 AND sc.is_active = 1 AND mc.is_active = 1 THEN 1
          ELSE 0
        END as is_effectively_active
      FROM products p
      LEFT JOIN sub_categories sc ON p.sub_category_id = sc.id
      LEFT JOIN main_categories mc ON sc.main_category_id = mc.id
      LEFT JOIN manufacturers m ON p.manufacturer_id = m.id
      LEFT JOIN product_images pi ON p.id = pi.product_id AND pi.is_primary = 1
      LEFT JOIN product_inventory inv ON p.id = inv.product_id AND inv.is_active = 1
      $whereClause
      ORDER BY p.name ASC
    ''';

    final searchTerm = '%$query%';
    final results = await db.rawQuery(searchQuery, [
      searchTerm,
      searchTerm,
      searchTerm,
      searchTerm,
      searchTerm,
    ]);
    return results.map((map) => Product.fromMap(map)).toList();
  }

  // Validation: Check if product name exists in same sub-category
  Future<bool> isProductNameExistsInSubCategory(
    String name,
    int subCategoryId, {
    int? excludeProductId,
  }) async {
    final db = await _dbHelper.database;

    String query =
        'SELECT COUNT(*) as count FROM products WHERE LOWER(name) = LOWER(?) AND sub_category_id = ?';
    List<dynamic> args = [name.trim(), subCategoryId];

    if (excludeProductId != null) {
      query += ' AND id != ?';
      args.add(excludeProductId);
    }

    final result = await db.rawQuery(query, args);
    final count = result.first['count'] as int;
    return count > 0;
  }

  // Validation: Check if part number exists for same manufacturer
  Future<bool> isPartNumberExistsForManufacturer(
    String partNumber,
    int manufacturerId, {
    int? excludeProductId,
  }) async {
    final db = await _dbHelper.database;

    String query =
        'SELECT COUNT(*) as count FROM products WHERE LOWER(part_number) = LOWER(?) AND manufacturer_id = ?';
    List<dynamic> args = [partNumber.trim(), manufacturerId];

    if (excludeProductId != null) {
      query += ' AND id != ?';
      args.add(excludeProductId);
    }

    final result = await db.rawQuery(query, args);
    final count = result.first['count'] as int;
    return count > 0;
  }

  // Validation: Check if sub-category is active and belongs to active main category
  Future<bool> isSubCategoryValid(int subCategoryId) async {
    final db = await _dbHelper.database;

    final query = '''
      SELECT sc.is_active as sub_active, mc.is_active as main_active
      FROM sub_categories sc
      JOIN main_categories mc ON sc.main_category_id = mc.id
      WHERE sc.id = ?
    ''';

    final result = await db.rawQuery(query, [subCategoryId]);
    if (result.isEmpty) return false;

    final subActive = result.first['sub_active'] == 1;
    final mainActive = result.first['main_active'] == 1;

    return subActive && mainActive;
  }

  // Validation: Check if manufacturer is active and supports parts
  Future<bool> isManufacturerValidForParts(int manufacturerId) async {
    final db = await _dbHelper.database;

    final query = '''
      SELECT is_active, manufacturer_type
      FROM manufacturers
      WHERE id = ? AND is_active = 1 AND manufacturer_type IN ('parts', 'both')
    ''';

    final result = await db.rawQuery(query, [manufacturerId]);
    return result.isNotEmpty;
  }

  // Comprehensive validation for product data
  Future<Map<String, String>> validateProduct(
    Product product, {
    bool isUpdate = false,
  }) async {
    Map<String, String> errors = {};

    // Basic validations
    if (product.name.trim().isEmpty) {
      errors['name'] = 'Product name is required';
    } else if (product.name.trim().length < 3) {
      errors['name'] = 'Product name must be at least 3 characters';
    } else if (product.name.trim().length > 200) {
      errors['name'] = 'Product name must not exceed 200 characters';
    }

    if (product.partNumber != null && product.partNumber!.trim().isNotEmpty) {
      if (product.partNumber!.trim().length > 100) {
        errors['part_number'] = 'Part number must not exceed 100 characters';
      }
    }

    if (product.description != null && product.description!.length > 1000) {
      errors['description'] = 'Description must not exceed 1000 characters';
    }

    if (product.weight != null && product.weight! < 0) {
      errors['weight'] = 'Weight cannot be negative';
    }

    if (product.warrantyMonths < 0) {
      errors['warranty_months'] = 'Warranty months cannot be negative';
    } else if (product.warrantyMonths > 120) {
      errors['warranty_months'] =
          'Warranty months cannot exceed 120 (10 years)';
    }

    // Database validations
    if (product.subCategoryId <= 0) {
      errors['sub_category_id'] = 'Please select a valid sub-category';
    } else {
      final subCategoryValid = await isSubCategoryValid(product.subCategoryId);
      if (!subCategoryValid) {
        errors['sub_category_id'] =
            'Selected sub-category is not active or its main category is inactive';
      }
    }

    if (product.manufacturerId <= 0) {
      errors['manufacturer_id'] = 'Please select a valid manufacturer';
    } else {
      final manufacturerValid = await isManufacturerValidForParts(
        product.manufacturerId,
      );
      if (!manufacturerValid) {
        errors['manufacturer_id'] =
            'Selected manufacturer is not active or does not manufacture parts';
      }
    }

    // Name uniqueness validation
    if (errors['name'] == null && errors['sub_category_id'] == null) {
      final nameExists = await isProductNameExistsInSubCategory(
        product.name,
        product.subCategoryId,
        excludeProductId: isUpdate ? product.id : null,
      );
      if (nameExists) {
        errors['name'] =
            'A product with this name already exists in the selected sub-category';
      }
    }

    // Part number uniqueness validation
    if (product.partNumber != null &&
        product.partNumber!.trim().isNotEmpty &&
        errors['part_number'] == null &&
        errors['manufacturer_id'] == null) {
      final partNumberExists = await isPartNumberExistsForManufacturer(
        product.partNumber!,
        product.manufacturerId,
        excludeProductId: isUpdate ? product.id : null,
      );
      if (partNumberExists) {
        errors['part_number'] =
            'This part number already exists for the selected manufacturer';
      }
    }

    return errors;
  }

  // Create product with validation
  Future<Map<String, dynamic>> createProduct(Product product) async {
    try {
      // Validate product data
      final errors = await validateProduct(product);
      if (errors.isNotEmpty) {
        return {'success': false, 'errors': errors};
      }

      final db = await _dbHelper.database;

      // Insert product
      final productData = product.toMap();
      productData['updated_at'] = DateTime.now().toIso8601String();

      final productId = await db.insert('products', productData);

      return {
        'success': true,
        'id': productId,
        'message': 'Product created successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to create product: ${e.toString()}',
      };
    }
  }

  // Update product with validation
  Future<Map<String, dynamic>> updateProduct(Product product) async {
    try {
      if (product.id == null) {
        return {'success': false, 'error': 'Product ID is required for update'};
      }

      // Validate product data
      final errors = await validateProduct(product, isUpdate: true);
      if (errors.isNotEmpty) {
        return {'success': false, 'errors': errors};
      }

      final db = await _dbHelper.database;

      // Update product
      final productData = product.toMap();
      productData['updated_at'] = DateTime.now().toIso8601String();

      final rowsAffected = await db.update(
        'products',
        productData,
        where: 'id = ?',
        whereArgs: [product.id],
      );

      if (rowsAffected > 0) {
        return {'success': true, 'message': 'Product updated successfully'};
      } else {
        return {
          'success': false,
          'error': 'Product not found or no changes made',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to update product: ${e.toString()}',
      };
    }
  }

  // Soft delete product (set is_active to 0)
  Future<Map<String, dynamic>> deleteProduct(int productId) async {
    try {
      final db = await _dbHelper.database;

      final rowsAffected = await db.update(
        'products',
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (rowsAffected > 0) {
        return {'success': true, 'message': 'Product deleted successfully'};
      } else {
        return {'success': false, 'error': 'Product not found'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to delete product: ${e.toString()}',
      };
    }
  }

  // Toggle product status (active/inactive)
  // Toggle product status (manual enable/disable)
  Future<Map<String, dynamic>> toggleProductStatus(int productId) async {
    try {
      final db = await _dbHelper.database;

      // Get current status - we only need the product's own flags
      final result = await db.query(
        'products',
        columns: ['is_active', 'is_manually_disabled'],
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (result.isEmpty) {
        return {'success': false, 'error': 'Product not found'};
      }

      final current = result.first;
      final currentlyActive = current['is_active'] == 1;

      Map<String, dynamic> updateData = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      String message;

      // Toggle logic exactly like sub-categories:
      // Just flip the isActive flag and update isManuallyDisabled accordingly
      if (currentlyActive) {
        // Currently active, user wants to disable it manually
        updateData['is_active'] = 0;
        updateData['is_manually_disabled'] = 1;
        message = 'Product deactivated successfully';
      } else {
        // Currently inactive, user wants to enable it
        updateData['is_active'] = 1;
        updateData['is_manually_disabled'] = 0;
        message = 'Product activated successfully';
      }

      final rowsAffected = await db.update(
        'products',
        updateData,
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (rowsAffected > 0) {
        return {
          'success': true,
          'message': message,
          'new_status': updateData['is_active'] == 1,
        };
      } else {
        return {'success': false, 'error': 'Failed to update product status'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to toggle product status: ${e.toString()}',
      };
    }
  }

  // Handle cascading when a main category is toggled
  Future<void> handleMainCategoryCascade(
    int mainCategoryId,
    bool isActive, {
    Transaction? txn,
  }) async {
    // NOTE: Unlike the original broken implementation, we DON'T modify product.is_active flags
    // when main categories change. The is_active flag represents the product's individual state.
    // The effective status is computed in queries based on:
    // isEffectivelyActive = product.is_active AND sub_category.is_active AND main_category.is_active
    //
    // This preserves product states when categories are re-enabled, just like sub-categories work.

    // No database operations needed here - the cascade effect is handled by computed queries
    // The UI will automatically show products as inactive when parent categories are inactive
  }

  // Handle cascading when a sub category is toggled
  Future<void> handleSubCategoryCascade(
    int subCategoryId,
    bool isActive, {
    Transaction? txn,
  }) async {
    // NOTE: Unlike the original broken implementation, we DON'T modify product.is_active flags
    // when sub-categories change. The is_active flag represents the product's individual state.
    // The effective status is computed in queries based on:
    // isEffectivelyActive = product.is_active AND sub_category.is_active AND main_category.is_active
    //
    // This preserves product states when categories are re-enabled, just like sub-categories work.

    // No database operations needed here - the cascade effect is handled by computed queries
    // The UI will automatically show products as inactive when parent categories are inactive
  }

  // Get all manufacturers for parts
  Future<List<Manufacturer>> getPartsManufacturers() async {
    final db = await _dbHelper.database;

    final results = await db.query(
      'manufacturers',
      where: "is_active = 1 AND manufacturer_type IN ('parts', 'both')",
      orderBy: 'name ASC',
    );

    return results.map((map) => Manufacturer.fromMap(map)).toList();
  }

  // Get active sub-categories with main category info
  Future<List<SubCategory>> getActiveSubCategories() async {
    final db = await _dbHelper.database;

    final String query = '''
      SELECT sc.*, mc.name as main_category_name
      FROM sub_categories sc
      JOIN main_categories mc ON sc.main_category_id = mc.id
      WHERE sc.is_active = 1 AND mc.is_active = 1
      ORDER BY mc.name ASC, sc.name ASC
    ''';

    final results = await db.rawQuery(query);
    return results.map((map) => SubCategory.fromMap(map)).toList();
  }

  // Get compatible vehicles for a product
  Future<List<ProductCompatibility>> getProductCompatibility(
    int productId,
  ) async {
    final db = await _dbHelper.database;

    final String query = '''
      SELECT
        pc.*,
        vm.name as vehicle_model_name,
        vm.model_year,
        vm.engine_capacity,
        m.name as manufacturer_name,
        vt.name as vehicle_type_name
      FROM product_compatibility pc
      JOIN vehicle_models vm ON pc.vehicle_model_id = vm.id
      JOIN manufacturers m ON vm.manufacturer_id = m.id
      JOIN vehicle_types vt ON vm.vehicle_type_id = vt.id
      WHERE pc.product_id = ? AND vm.is_active = 1
      ORDER BY m.name ASC, vm.model_year DESC, vm.name ASC
    ''';

    final results = await db.rawQuery(query, [productId]);
    return results.map((map) => ProductCompatibility.fromMap(map)).toList();
  }

  // Get all vehicle models
  Future<List<VehicleModel>> getAllVehicleModels({
    bool includeInactive = false,
  }) async {
    final db = await _dbHelper.database;

    final String query =
        '''
      SELECT
        vm.*,
        m.name as manufacturer_name,
        vt.name as vehicle_type_name
      FROM vehicle_models vm
      JOIN manufacturers m ON vm.manufacturer_id = m.id
      JOIN vehicle_types vt ON vm.vehicle_type_id = vt.id
      ${includeInactive ? '' : 'WHERE vm.is_active = 1'}
      ORDER BY m.name ASC, vm.model_year DESC, vm.name ASC
    ''';

    final results = await db.rawQuery(query);
    return results.map((map) => VehicleModel.fromMap(map)).toList();
  }

  // Add product compatibility
  Future<Map<String, dynamic>> addProductCompatibility(
    ProductCompatibility compatibility,
  ) async {
    try {
      final db = await _dbHelper.database;

      // Check if compatibility already exists
      final existing = await db.query(
        'product_compatibility',
        where: 'product_id = ? AND vehicle_model_id = ?',
        whereArgs: [compatibility.productId, compatibility.vehicleModelId],
      );

      if (existing.isNotEmpty) {
        return {
          'success': false,
          'error': 'Compatibility already exists for this vehicle',
        };
      }

      final id = await db.insert(
        'product_compatibility',
        compatibility.toMap(),
      );
      return {
        'success': true,
        'id': id,
        'message': 'Vehicle compatibility added successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to add compatibility: ${e.toString()}',
      };
    }
  }

  // Remove product compatibility
  Future<Map<String, dynamic>> removeProductCompatibility(
    int compatibilityId,
  ) async {
    try {
      final db = await _dbHelper.database;

      final rowsAffected = await db.delete(
        'product_compatibility',
        where: 'id = ?',
        whereArgs: [compatibilityId],
      );

      if (rowsAffected > 0) {
        return {
          'success': true,
          'message': 'Vehicle compatibility removed successfully',
        };
      } else {
        return {'success': false, 'error': 'Compatibility not found'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to remove compatibility: ${e.toString()}',
      };
    }
  }

  // Get product images
  Future<List<ProductImage>> getProductImages(int productId) async {
    final db = await _dbHelper.database;

    final maps = await db.query(
      'product_images',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'sort_order ASC, id ASC',
    );

    final images = maps.map((map) => ProductImage.fromMap(map)).toList();
    print('Found ${images.length} images for product $productId');
    for (final image in images) {
      print('Image: ${image.imagePath}, Primary: ${image.isPrimary}');
    }

    return images;
  }

  // Save product images
  Future<Map<String, dynamic>> saveProductImages(
    int productId,
    List<String> imagePaths,
    int? primaryImageIndex,
  ) async {
    try {
      print('Saving ${imagePaths.length} images for product $productId');
      if (primaryImageIndex != null) {
        print('Primary image index: $primaryImageIndex');
      }

      final db = await _dbHelper.database;

      // Start transaction
      await db.transaction((txn) async {
        // Delete existing images
        await txn.delete(
          'product_images',
          where: 'product_id = ?',
          whereArgs: [productId],
        );

        // Insert new images
        for (int i = 0; i < imagePaths.length; i++) {
          final imagePath = imagePaths[i];
          final isPrimary = primaryImageIndex == i;

          print('Saving image $i: $imagePath (primary: $isPrimary)');

          final productImage = ProductImage(
            productId: productId,
            imagePath: imagePath,
            imageType: isPrimary ? 'main' : 'gallery',
            sortOrder: i,
            isPrimary: isPrimary,
          );

          await txn.insert('product_images', productImage.toMap());
        }
      });

      print('Successfully saved all product images');
      return {'success': true, 'message': 'Product images saved successfully'};
    } catch (e) {
      print('Error saving product images: $e');
      return {
        'success': false,
        'error': 'Failed to save images: ${e.toString()}',
      };
    }
  }

  // Copy image to app directory
  Future<String?> copyImageToAppDirectory(String sourcePath) async {
    try {
      print('Copying image from: $sourcePath');

      final imagesDir = await _dbHelper.getImagesDirectoryPath();
      print('Images directory: $imagesDir');

      final fileName = path.basename(sourcePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName = '${timestamp}_$fileName';
      final destinationPath = path.join(imagesDir, 'products', newFileName);

      print('Destination path: $destinationPath');

      // Create directory if it doesn't exist
      final destinationDir = Directory(path.dirname(destinationPath));
      if (!await destinationDir.exists()) {
        print('Creating directory: ${destinationDir.path}');
        await destinationDir.create(recursive: true);
      }

      // Copy file
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        print('Source file does not exist: $sourcePath');
        return null;
      }

      final destinationFile = await sourceFile.copy(destinationPath);
      print('Image copied successfully to: ${destinationFile.path}');

      return destinationFile.path;
    } catch (e) {
      print('Error copying image: $e');
      return null;
    }
  }

  // Delete product image file
  Future<void> deleteImageFile(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Get product inventory
  Future<ProductInventory?> getProductInventory(int productId) async {
    final db = await _dbHelper.database;

    final maps = await db.query(
      'product_inventory',
      where: 'product_id = ? AND is_active = 1',
      whereArgs: [productId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return ProductInventory.fromMap(maps.first);
    }
    return null;
  }

  // Fix products with images but no primary image set
  Future<Map<String, dynamic>> fixMissingPrimaryImages() async {
    try {
      final db = await _dbHelper.database;

      // Find all product IDs that have images but no primary image
      final result = await db.rawQuery('''
        SELECT DISTINCT product_id
        FROM product_images pi1
        WHERE NOT EXISTS (
          SELECT 1 FROM product_images pi2
          WHERE pi2.product_id = pi1.product_id
          AND pi2.is_primary = 1
        )
      ''');

      if (result.isEmpty) {
        return {'success': true, 'message': 'No products need fixing'};
      }

      int fixedCount = 0;

      // For each product without a primary image, set the first image as primary
      for (final row in result) {
        final productId = row['product_id'] as int;

        // Get the first image for this product (ordered by id)
        final firstImageResult = await db.query(
          'product_images',
          where: 'product_id = ?',
          whereArgs: [productId],
          orderBy: 'id ASC',
          limit: 1,
        );

        if (firstImageResult.isNotEmpty) {
          final imageId = firstImageResult.first['id'] as int;

          // Set this image as primary
          await db.update(
            'product_images',
            {'is_primary': 1},
            where: 'id = ?',
            whereArgs: [imageId],
          );

          fixedCount++;
          print(
            'Set primary image for product $productId (image ID: $imageId)',
          );
        }
      }

      return {
        'success': true,
        'message': 'Fixed $fixedCount products with missing primary images',
        'fixedCount': fixedCount,
      };
    } catch (e) {
      print('Error fixing missing primary images: $e');
      return {
        'success': false,
        'error': 'Failed to fix missing primary images: ${e.toString()}',
      };
    }
  }

  // Save product inventory
  Future<Map<String, dynamic>> saveProductInventory(
    ProductInventory inventory,
  ) async {
    try {
      final db = await _dbHelper.database;

      if (inventory.id == null) {
        // Create new inventory
        final id = await db.insert('product_inventory', inventory.toMap());
        return {
          'success': true,
          'id': id,
          'message': 'Inventory information saved successfully',
        };
      } else {
        // Update existing inventory
        final rowsAffected = await db.update(
          'product_inventory',
          inventory.toMap(),
          where: 'id = ?',
          whereArgs: [inventory.id],
        );

        if (rowsAffected > 0) {
          return {
            'success': true,
            'message': 'Inventory information updated successfully',
          };
        } else {
          return {'success': false, 'error': 'Inventory not found'};
        }
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to save inventory: ${e.toString()}',
      };
    }
  }
}
