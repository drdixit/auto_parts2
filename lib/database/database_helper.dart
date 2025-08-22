import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  static Future<void> initializeDatabase() async {
    // Initialize sqflite for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Initialize FFI
      sqfliteFfiInit();
      // Set the database factory to use FFI
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Get the application documents directory
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasesDirectory = Directory(
      join(documentsDirectory.path, 'auto_parts2', 'database'),
    );

    // Create database directory if it doesn't exist
    if (!await databasesDirectory.exists()) {
      await databasesDirectory.create(recursive: true);
    }

    final path = join(databasesDirectory.path, 'auto_parts.db');

    return await openDatabase(
      path,
      version: 3, // Incremented for new schema changes
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) {
        // Enable foreign keys
        db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add updated_at column to main_categories table with NULL default
      await db.execute('''
        ALTER TABLE main_categories ADD COLUMN updated_at DATETIME
      ''');

      // Add updated_at column to sub_categories table with NULL default
      await db.execute('''
        ALTER TABLE sub_categories ADD COLUMN updated_at DATETIME
      ''');

      // Update existing records with current timestamp
      final currentTime = DateTime.now().toIso8601String();
      await db.execute(
        '''
        UPDATE main_categories SET updated_at = ? WHERE updated_at IS NULL
      ''',
        [currentTime],
      );

      await db.execute(
        '''
        UPDATE sub_categories SET updated_at = ? WHERE updated_at IS NULL
      ''',
        [currentTime],
      );
    }

    if (oldVersion < 3) {
      // Add is_manually_disabled flag to track user-initiated deactivation
      // This helps distinguish between cascade deactivation and manual deactivation
      await db.execute('''
        ALTER TABLE sub_categories ADD COLUMN is_manually_disabled BOOLEAN DEFAULT 0
      ''');

      // Initialize existing records - if currently inactive, consider it manually disabled
      await db.execute('''
        UPDATE sub_categories SET is_manually_disabled = 1 WHERE is_active = 0
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create all tables based on the schema.sql

    // 1. MANUFACTURERS TABLE
    await db.execute('''
      CREATE TABLE manufacturers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(100) NOT NULL UNIQUE,
        logo_image_path VARCHAR(255),
        manufacturer_type VARCHAR(20) CHECK (manufacturer_type IN ('vehicle', 'parts', 'both')) DEFAULT 'parts',
        country VARCHAR(50),
        website VARCHAR(255),
        established_year INTEGER,
        is_active BOOLEAN DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 2. VEHICLE TYPES TABLE
    await db.execute('''
      CREATE TABLE vehicle_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(50) NOT NULL UNIQUE,
        description TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 3. VEHICLE MODELS TABLE
    await db.execute('''
      CREATE TABLE vehicle_models (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(100) NOT NULL,
        manufacturer_id INTEGER NOT NULL,
        vehicle_type_id INTEGER NOT NULL,
        model_year INTEGER,
        engine_capacity VARCHAR(20),
        fuel_type VARCHAR(20) CHECK (fuel_type IN ('petrol', 'diesel', 'electric', 'hybrid', 'cng')),
        image_path VARCHAR(255),
        is_active BOOLEAN DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (manufacturer_id) REFERENCES manufacturers(id) ON DELETE RESTRICT,
        FOREIGN KEY (vehicle_type_id) REFERENCES vehicle_types(id) ON DELETE RESTRICT,
        UNIQUE(name, manufacturer_id, model_year)
      )
    ''');

    // 4. MAIN CATEGORIES TABLE
    await db.execute('''
      CREATE TABLE main_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(100) NOT NULL UNIQUE,
        description TEXT,
        icon_path VARCHAR(255),
        sort_order INTEGER DEFAULT 0,
        is_active BOOLEAN DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 5. SUB CATEGORIES TABLE
    await db.execute('''
      CREATE TABLE sub_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(100) NOT NULL,
        main_category_id INTEGER NOT NULL,
        description TEXT,
        sort_order INTEGER DEFAULT 0,
        is_active BOOLEAN DEFAULT 1,
        is_manually_disabled BOOLEAN DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (main_category_id) REFERENCES main_categories(id) ON DELETE CASCADE,
        UNIQUE(name, main_category_id)
      )
    ''');

    // 6. PRODUCTS TABLE
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(200) NOT NULL,
        part_number VARCHAR(100),
        sub_category_id INTEGER NOT NULL,
        manufacturer_id INTEGER NOT NULL,
        description TEXT,
        specifications TEXT,
        weight DECIMAL(8,2),
        dimensions VARCHAR(100),
        material VARCHAR(100),
        warranty_months INTEGER DEFAULT 0,
        is_universal BOOLEAN DEFAULT 0,
        is_active BOOLEAN DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sub_category_id) REFERENCES sub_categories(id) ON DELETE RESTRICT,
        FOREIGN KEY (manufacturer_id) REFERENCES manufacturers(id) ON DELETE RESTRICT,
        UNIQUE(part_number, manufacturer_id)
      )
    ''');

    // 7. PRODUCT COMPATIBILITY TABLE
    await db.execute('''
      CREATE TABLE product_compatibility (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        vehicle_model_id INTEGER NOT NULL,
        is_oem BOOLEAN DEFAULT 0,
        fit_notes VARCHAR(255),
        compatibility_confirmed BOOLEAN DEFAULT 0,
        added_by VARCHAR(100),
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (vehicle_model_id) REFERENCES vehicle_models(id) ON DELETE CASCADE,
        UNIQUE(product_id, vehicle_model_id)
      )
    ''');

    // 8. PRODUCT IMAGES TABLE
    await db.execute('''
      CREATE TABLE product_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        image_path VARCHAR(255) NOT NULL,
        image_type VARCHAR(20) DEFAULT 'gallery' CHECK (image_type IN ('main', 'gallery', 'technical', 'installation')),
        alt_text VARCHAR(255),
        sort_order INTEGER DEFAULT 0,
        is_primary BOOLEAN DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    // 9. PRODUCT INVENTORY TABLE
    await db.execute('''
      CREATE TABLE product_inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        supplier_name VARCHAR(100),
        supplier_contact TEXT,
        supplier_email VARCHAR(100),
        cost_price DECIMAL(10,2) DEFAULT 0.00,
        selling_price DECIMAL(10,2) DEFAULT 0.00,
        mrp DECIMAL(10,2) DEFAULT 0.00,
        stock_quantity INTEGER DEFAULT 0,
        minimum_stock_level INTEGER DEFAULT 5,
        maximum_stock_level INTEGER DEFAULT 100,
        location_rack VARCHAR(50),
        last_restocked_date DATE,
        last_sold_date DATE,
        is_active BOOLEAN DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    // 10. MANUFACTURER IMAGES TABLE
    await db.execute('''
      CREATE TABLE manufacturer_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manufacturer_id INTEGER NOT NULL,
        image_path VARCHAR(255) NOT NULL,
        image_type VARCHAR(20) DEFAULT 'logo' CHECK (image_type IN ('logo', 'factory', 'gallery')),
        is_primary BOOLEAN DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (manufacturer_id) REFERENCES manufacturers(id) ON DELETE CASCADE
      )
    ''');

    // 11. VEHICLE MODEL IMAGES TABLE
    await db.execute('''
      CREATE TABLE vehicle_model_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_model_id INTEGER NOT NULL,
        image_path VARCHAR(255) NOT NULL,
        image_type VARCHAR(20) DEFAULT 'main' CHECK (image_type IN ('main', 'side', 'interior', 'engine')),
        is_primary BOOLEAN DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (vehicle_model_id) REFERENCES vehicle_models(id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await _createIndexes(db);

    // Insert sample data
    await _insertSampleData(db);
  }

  Future<void> _createIndexes(Database db) async {
    // Core search indexes
    await db.execute(
      'CREATE INDEX idx_products_manufacturer ON products(manufacturer_id)',
    );
    await db.execute(
      'CREATE INDEX idx_products_subcategory ON products(sub_category_id)',
    );
    await db.execute('CREATE INDEX idx_products_active ON products(is_active)');
    await db.execute(
      'CREATE INDEX idx_products_part_number ON products(part_number)',
    );
    await db.execute('CREATE INDEX idx_products_name ON products(name)');

    // Compatibility search indexes
    await db.execute(
      'CREATE INDEX idx_compatibility_product ON product_compatibility(product_id)',
    );
    await db.execute(
      'CREATE INDEX idx_compatibility_vehicle ON product_compatibility(vehicle_model_id)',
    );
    await db.execute(
      'CREATE INDEX idx_compatibility_confirmed ON product_compatibility(compatibility_confirmed)',
    );

    // Vehicle search indexes
    await db.execute(
      'CREATE INDEX idx_vehicle_models_manufacturer ON vehicle_models(manufacturer_id)',
    );
    await db.execute(
      'CREATE INDEX idx_vehicle_models_type ON vehicle_models(vehicle_type_id)',
    );
    await db.execute(
      'CREATE INDEX idx_vehicle_models_active ON vehicle_models(is_active)',
    );
    await db.execute(
      'CREATE INDEX idx_vehicle_models_name ON vehicle_models(name)',
    );

    // Category search indexes
    await db.execute(
      'CREATE INDEX idx_sub_categories_main ON sub_categories(main_category_id)',
    );
    await db.execute(
      'CREATE INDEX idx_main_categories_active ON main_categories(is_active)',
    );
    await db.execute(
      'CREATE INDEX idx_sub_categories_active ON sub_categories(is_active)',
    );

    // Inventory indexes
    await db.execute(
      'CREATE INDEX idx_inventory_product ON product_inventory(product_id)',
    );
    await db.execute(
      'CREATE INDEX idx_inventory_stock ON product_inventory(stock_quantity)',
    );

    // Image indexes
    await db.execute(
      'CREATE INDEX idx_product_images_product ON product_images(product_id)',
    );
    await db.execute(
      'CREATE INDEX idx_product_images_primary ON product_images(is_primary)',
    );
  }

  Future<void> _insertSampleData(Database db) async {
    // Vehicle Types
    await db.execute('''
      INSERT INTO vehicle_types (name, description) VALUES
      ('Motorcycle', 'Two-wheeler motorcycles and bikes'),
      ('Scooter', 'Automatic two-wheeler scooters'),
      ('Car', 'Four-wheeler passenger cars'),
      ('Truck', 'Heavy commercial vehicles'),
      ('Auto Rickshaw', 'Three-wheeler passenger vehicles')
    ''');

    // Vehicle Manufacturers
    await db.execute('''
      INSERT INTO manufacturers (name, manufacturer_type, country) VALUES
      ('Hero MotoCorp', 'vehicle', 'India'),
      ('Honda', 'both', 'Japan'),
      ('Bajaj Auto', 'vehicle', 'India'),
      ('Maruti Suzuki', 'vehicle', 'India'),
      ('TVS Motor', 'vehicle', 'India'),
      ('Royal Enfield', 'vehicle', 'India'),
      ('Yamaha', 'vehicle', 'Japan')
    ''');

    // Parts Manufacturers
    await db.execute('''
      INSERT INTO manufacturers (name, manufacturer_type, country) VALUES
      ('Bosch', 'parts', 'Germany'),
      ('Lucas TVS', 'parts', 'India'),
      ('Exide', 'parts', 'India'),
      ('Castrol', 'parts', 'United Kingdom'),
      ('K&N', 'parts', 'United States'),
      ('NGK', 'parts', 'Japan'),
      ('DID', 'parts', 'Japan'),
      ('MRF', 'parts', 'India'),
      ('Amaron', 'parts', 'India')
    ''');

    // Main Categories
    await db.execute('''
      INSERT INTO main_categories (name, description, sort_order) VALUES
      ('Engine Parts', 'Engine related components', 1),
      ('Brake System', 'Braking system parts', 2),
      ('Transmission', 'Gear and transmission parts', 3),
      ('Electrical', 'Electrical and electronic parts', 4),
      ('Body Parts', 'Body and exterior parts', 5),
      ('Suspension', 'Suspension and steering parts', 6),
      ('Filters', 'Air, oil and fuel filters', 7),
      ('Lubricants', 'Oils and lubricants', 8),
      ('Tyres', 'Tyres and wheels', 9)
    ''');

    // Sub Categories
    await db.execute('''
      INSERT INTO sub_categories (name, main_category_id, sort_order) VALUES
      ('Spark Plugs', 1, 1),
      ('Pistons', 1, 2),
      ('Valves', 1, 3),
      ('Gaskets', 1, 4),
      ('Brake Pads', 2, 1),
      ('Brake Discs', 2, 2),
      ('Brake Cables', 2, 3),
      ('Brake Fluid', 2, 4),
      ('Clutch Plates', 3, 1),
      ('Gear Sets', 3, 2),
      ('Chain & Sprockets', 3, 3),
      ('Batteries', 4, 1),
      ('Headlights', 4, 2),
      ('Indicators', 4, 3),
      ('Air Filters', 7, 1),
      ('Oil Filters', 7, 2),
      ('Fuel Filters', 7, 3)
    ''');

    // Sample Vehicle Models
    await db.execute('''
      INSERT INTO vehicle_models (name, manufacturer_id, vehicle_type_id, model_year, engine_capacity, fuel_type) VALUES
      ('Splendor Plus', 1, 1, 2023, '100cc', 'petrol'),
      ('Passion Pro', 1, 1, 2023, '110cc', 'petrol'),
      ('Glamour', 1, 1, 2023, '125cc', 'petrol'),
      ('Activa 125', 2, 2, 2023, '125cc', 'petrol'),
      ('CB Shine', 2, 1, 2023, '125cc', 'petrol'),
      ('City', 2, 3, 2023, '1500cc', 'petrol'),
      ('Pulsar 150', 3, 1, 2023, '150cc', 'petrol'),
      ('Discover 125', 3, 1, 2023, '125cc', 'petrol'),
      ('Apache RTR 160', 5, 1, 2023, '160cc', 'petrol'),
      ('Jupiter', 5, 2, 2023, '110cc', 'petrol')
    ''');
  }

  // Helper methods for CRUD operations
  Future<int> insertRecord(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> getRecords(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs);
  }

  Future<int> updateRecord(
    String table,
    Map<String, dynamic> data,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> deleteRecord(
    String table,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  // Soft delete - set is_active to 0
  Future<int> softDeleteRecord(String table, int id) async {
    final db = await database;
    return await db.update(
      table,
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get database path for copying database file
  Future<String> getDatabasePath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasesDirectory = Directory(
      join(documentsDirectory.path, 'auto_parts2', 'database'),
    );
    return join(databasesDirectory.path, 'auto_parts.db');
  }

  // Get images directory path
  Future<String> getImagesDirectoryPath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final imagesDirectory = Directory(
      join(documentsDirectory.path, 'auto_parts2', 'database', 'images'),
    );

    // Create images directory if it doesn't exist
    if (!await imagesDirectory.exists()) {
      await imagesDirectory.create(recursive: true);
    }

    return imagesDirectory.path;
  }
}
