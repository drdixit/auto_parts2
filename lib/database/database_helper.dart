import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

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
      version:
          8, // Incremented to add customers, customer_bills and is_held for holds
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

    if (oldVersion < 4) {
      // Add sample products and inventory data
      await _insertSampleProducts(db);
    }

    if (oldVersion < 5) {
      // Add sample compatibility data
      await _insertSampleCompatibility(db);
    }

    if (oldVersion < 6) {
      // Add is_manually_disabled flag to products to track user-initiated deactivation
      // This helps distinguish between cascade deactivation and manual deactivation
      await db.execute('''
        ALTER TABLE products ADD COLUMN is_manually_disabled BOOLEAN DEFAULT 0
      ''');

      // Initialize existing records - if currently inactive, consider it manually disabled
      await db.execute('''
        UPDATE products SET is_manually_disabled = 1 WHERE is_active = 0
      ''');
    }

    if (oldVersion < 7) {
      // Add customers table
      await db.execute('''
        CREATE TABLE customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name VARCHAR(200) NOT NULL,
          address TEXT,
          mobile VARCHAR(30),
          opening_balance DECIMAL(12,2) DEFAULT 0.00,
          balance DECIMAL(12,2) DEFAULT 0.00,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Add customer bills table (stores held bills and invoices)
      await db.execute('''
        CREATE TABLE customer_bills (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          items TEXT,
          total DECIMAL(12,2) DEFAULT 0.00,
          is_paid BOOLEAN DEFAULT 0,
          is_held BOOLEAN DEFAULT 0,
          FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 8) {
      // Add is_held column to customer_bills so holds can be persisted separately from finalized invoices
      await db.execute('''
        ALTER TABLE customer_bills ADD COLUMN is_held BOOLEAN DEFAULT 0
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
        is_manually_disabled BOOLEAN DEFAULT 0,
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

    // Ensure customers and customer_bills tables exist on fresh create
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(200) NOT NULL,
        address TEXT,
        mobile VARCHAR(30),
        opening_balance DECIMAL(12,2) DEFAULT 0.00,
        balance DECIMAL(12,2) DEFAULT 0.00,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        items TEXT,
        total DECIMAL(12,2) DEFAULT 0.00,
        is_paid BOOLEAN DEFAULT 0,
        is_held BOOLEAN DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
      )
    ''');

    // Seed customers and sample bills (safe, idempotent)
    await _insertSampleCustomersAndBills(db);

    // Try to copy a bundled dummy image into the DB images directory so code that expects an image path can find it.
    try {
      final imagesDir = await getImagesDirectoryPath();
      final dest = File(join(imagesDir, 'dummy.jpg'));
      if (!await dest.exists()) {
        // rootBundle may not be available in some contexts; guard with try/catch
        try {
          final bytes = await rootBundle.load('assets/images/dummy.jpg');
          await dest.writeAsBytes(bytes.buffer.asUint8List());
        } catch (e) {
          // ignore - asset may not be available in this context
        }
      }
    } catch (e) {
      // ignore filesystem errors during DB create - non-critical
    }
  }

  // Insert sample customers and corresponding sample bills.
  Future<void> _insertSampleCustomersAndBills(Database db) async {
    // Check if customers already exist
    final existing = await db.rawQuery('SELECT COUNT(1) as cnt FROM customers');
    final cnt = (existing.isNotEmpty
        ? (existing.first['cnt'] as int? ?? 0)
        : 0);
    if (cnt > 0) return; // already seeded

    // Insert a few customers
    final now = DateTime.now().toIso8601String();
    final aliceId = await db.insert('customers', {
      'name': 'Alice Auto',
      'address': '12 Market Road',
      'mobile': '9999000001',
      'opening_balance': 0.0,
      'balance': 0.0,
      'created_at': now,
    });
    final bobId = await db.insert('customers', {
      'name': 'Bob Motors',
      'address': '7 Industrial Area',
      'mobile': '9999000002',
      'opening_balance': 0.0,
      // Bob owes 1200.00 -> negative balance to indicate unpaid
      'balance': -1200.00,
      'created_at': now,
    });
    await db.insert('customers', {
      'name': 'Charlie Garage',
      'address': '45 Service Lane',
      'mobile': '9999000003',
      'opening_balance': 0.0,
      'balance': 0.0,
      'created_at': now,
    });

    // Insert a paid bill for Alice
    final itemsAlice = [
      {'product_id': 1, 'qty': 1, 'line_total': 250.0},
    ];
    await db.insert('customer_bills', {
      'customer_id': aliceId,
      'items': jsonEncode(itemsAlice),
      'total': 250.0,
      'is_paid': 1,
      'is_held': 0,
      'created_at': now,
    });

    // Insert an unpaid bill (held->unpaid) for Bob
    final itemsBob = [
      {'product_id': 4, 'qty': 2, 'line_total': 600.0},
    ];
    await db.insert('customer_bills', {
      'customer_id': bobId,
      'items': jsonEncode(itemsBob),
      'total': 1200.0,
      'is_paid': 0,
      'is_held': 0,
      'created_at': now,
    });
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

    // Sample Products - Add comprehensive product data
    await _insertSampleProducts(db);
  }

  Future<void> _insertSampleProducts(Database db) async {
    // Insert sample products with realistic data

    // Engine Parts - Spark Plugs (Sub Category ID: 1)
    await db.execute('''
      INSERT INTO products (name, part_number, sub_category_id, manufacturer_id, description, specifications, weight, warranty_months, is_universal, is_active) VALUES
      ('NGK Spark Plug CR8E', 'CR8E', 1, 13, 'Standard spark plug for motorcycles', '{"electrode_gap": "0.8mm", "thread_size": "M12", "reach": "19mm"}', 0.05, 12, 0, 1),
      ('Bosch Spark Plug UR4AC', 'UR4AC', 1, 8, 'Copper core spark plug', '{"electrode_gap": "0.6mm", "thread_size": "M14", "reach": "12.7mm"}', 0.06, 6, 0, 1),
      ('NGK Iridium Spark Plug CPR8EAIX-9', 'CPR8EAIX-9', 1, 13, 'Premium iridium spark plug for better performance', '{"electrode_gap": "0.9mm", "thread_size": "M12", "reach": "19mm", "material": "iridium"}', 0.05, 24, 0, 1)
    ''');

    // Brake System - Brake Pads (Sub Category ID: 5)
    await db.execute('''
      INSERT INTO products (name, part_number, sub_category_id, manufacturer_id, description, specifications, weight, warranty_months, is_universal, is_active) VALUES
      ('Lucas TVS Brake Pad Set Front', 'BP-F-125', 5, 9, 'High quality brake pads for front disc brakes', '{"material": "ceramic", "temperature_range": "-40°C to 400°C"}', 0.3, 12, 0, 1),
      ('Bosch Brake Pad Organic', 'BP-ORG-150', 5, 8, 'Organic brake pads for smooth braking', '{"material": "organic", "temperature_range": "-30°C to 350°C"}', 0.25, 18, 0, 1)
    ''');

    // Transmission - Clutch Plates (Sub Category ID: 9)
    await db.execute('''
      INSERT INTO products (name, part_number, sub_category_id, manufacturer_id, description, specifications, weight, warranty_months, is_universal, is_active) VALUES
      ('Hero Genuine Clutch Plate Set', 'CP-125-H', 9, 1, 'Original clutch plates for Hero motorcycles', '{"thickness": "3.2mm", "outer_diameter": "125mm", "inner_diameter": "65mm"}', 0.8, 12, 0, 1),
      ('Bajaj Original Clutch Friction Plate', 'CFP-150-B', 9, 3, 'OEM clutch friction plates', '{"thickness": "3.5mm", "outer_diameter": "150mm", "inner_diameter": "75mm"}', 1.0, 12, 0, 1)
    ''');

    // Electrical - Batteries (Sub Category ID: 12)
    await db.execute('''
      INSERT INTO products (name, part_number, sub_category_id, manufacturer_id, description, specifications, weight, warranty_months, is_universal, is_active) VALUES
      ('Exide 12V 9Ah Battery', 'EX-12V9AH', 12, 10, 'Maintenance-free motorcycle battery', '{"voltage": "12V", "capacity": "9Ah", "terminals": "L+R-", "dimensions": "150x87x105mm"}', 2.8, 18, 0, 1),
      ('Amaron 12V 5Ah Battery', 'AM-12V5AH', 12, 16, 'Long-life VRLA battery for two-wheelers', '{"voltage": "12V", "capacity": "5Ah", "terminals": "L+R-", "dimensions": "120x70x92mm"}', 1.8, 24, 0, 1)
    ''');

    // Electrical - Headlights (Sub Category ID: 13)
    await db.execute('''
      INSERT INTO products (name, part_number, sub_category_id, manufacturer_id, description, specifications, weight, warranty_months, is_universal, is_active) VALUES
      ('Bosch H4 Halogen Headlight Bulb', 'H4-55W', 13, 8, 'Standard halogen headlight bulb', '{"wattage": "55W/60W", "voltage": "12V", "base": "P43t", "luminous_flux": "1650lm"}', 0.08, 6, 1, 1),
      ('Lucas LED Headlight Assembly', 'LED-HL-120', 13, 9, 'LED headlight with DRL', '{"power": "20W", "voltage": "12V", "color_temperature": "6000K", "luminous_flux": "2400lm"}', 0.4, 12, 0, 1)
    ''');

    // Filters - Air Filters (Sub Category ID: 15)
    await db.execute('''
      INSERT INTO products (name, part_number, sub_category_id, manufacturer_id, description, specifications, weight, warranty_months, is_universal, is_active) VALUES
      ('K&N High Flow Air Filter', 'KN-125-1', 15, 12, 'High-performance washable air filter', '{"material": "cotton_gauze", "filtration_efficiency": "99%", "airflow_increase": "50%"}', 0.2, 12, 0, 1),
      ('Bosch Paper Air Filter', 'AF-P-125', 15, 8, 'Standard paper air filter element', '{"material": "pleated_paper", "filtration_efficiency": "95%"}', 0.15, 6, 0, 1)
    ''');

    // Pistons (Sub Category ID: 2)
    await db.execute('''
      INSERT INTO products (name, part_number, sub_category_id, manufacturer_id, description, specifications, weight, warranty_months, is_universal, is_active) VALUES
      ('Honda Genuine Piston Kit 125cc', 'PK-125-H', 2, 2, 'Complete piston kit with rings and pin', '{"bore_size": "52.4mm", "compression_ratio": "9.3:1", "material": "aluminum_alloy"}', 0.5, 12, 0, 1),
      ('Bajaj OEM Piston Assembly 150cc', 'PA-150-B', 2, 3, 'Original piston assembly for 150cc engines', '{"bore_size": "57mm", "compression_ratio": "9.5:1", "material": "aluminum_alloy"}', 0.6, 12, 0, 1)
    ''');

    // Chain & Sprockets (Sub Category ID: 11)
    await db.execute('''
      INSERT INTO products (name, part_number, sub_category_id, manufacturer_id, description, specifications, weight, warranty_months, is_universal, is_active) VALUES
      ('DID Gold Chain 428HG', '428HG-120L', 11, 14, 'Heavy duty gold chain 120 links', '{"pitch": "428", "links": "120", "tensile_strength": "1400kg", "material": "alloy_steel"}', 1.2, 18, 0, 1),
      ('TVS Chain Kit Complete 125cc', 'CK-125-TVS', 11, 5, 'Complete chain and sprocket kit', '{"chain_size": "428", "front_sprocket": "14T", "rear_sprocket": "42T"}', 1.8, 12, 0, 1)
    ''');

    // Oil Filters (Sub Category ID: 16)
    await db.execute('''
      INSERT INTO products (name, part_number, sub_category_id, manufacturer_id, description, specifications, weight, warranty_months, is_universal, is_active) VALUES
      ('Bosch Oil Filter F002H23627', 'F002H23627', 16, 8, 'Spin-on oil filter for motorcycles', '{"thread": "M20x1.5", "bypass_valve": "yes", "filtration": "20_micron"}', 0.3, 6, 0, 1),
      ('TVS King Oil Filter', 'OF-TVS-125', 16, 5, 'High-quality oil filter element', '{"thread": "M20x1.5", "bypass_valve": "yes", "filtration": "25_micron"}', 0.25, 12, 0, 1)
    ''');

    // Now insert corresponding inventory records
    await _insertSampleInventory(db);
  }

  Future<void> _insertSampleInventory(Database db) async {
    // Insert inventory for the products (using product IDs 1-15)
    await db.execute('''
      INSERT INTO product_inventory (product_id, supplier_name, supplier_contact, cost_price, selling_price, mrp, stock_quantity, minimum_stock_level, location_rack) VALUES
      (1, 'NGK Spark Plugs India', '+91-80-2234-5678', 180.00, 250.00, 280.00, 45, 10, 'A1-SP'),
      (2, 'Bosch Ltd India', '+91-80-2345-6789', 120.00, 180.00, 200.00, 30, 15, 'A1-SP'),
      (3, 'NGK Spark Plugs India', '+91-80-2234-5678', 450.00, 650.00, 750.00, 20, 5, 'A1-SP'),
      (4, 'Lucas TVS', '+91-44-2345-6789', 280.00, 420.00, 480.00, 25, 8, 'B1-BP'),
      (5, 'Bosch Ltd India', '+91-80-2345-6789', 320.00, 480.00, 550.00, 18, 10, 'B1-BP'),
      (6, 'Hero MotoCorp Parts', '+91-124-234-5678', 850.00, 1200.00, 1350.00, 12, 5, 'C1-CP'),
      (7, 'Bajaj Auto Parts', '+91-20-2345-6789', 950.00, 1350.00, 1500.00, 15, 5, 'C1-CP'),
      (8, 'Exide Industries', '+91-33-2234-5678', 1800.00, 2400.00, 2700.00, 8, 3, 'D1-BAT'),
      (9, 'Amaron Batteries', '+91-44-2345-6789', 1200.00, 1650.00, 1850.00, 10, 5, 'D1-BAT'),
      (10, 'Bosch Ltd India', '+91-80-2345-6789', 85.00, 120.00, 140.00, 50, 20, 'D2-HL'),
      (11, 'Lucas TVS', '+91-44-2345-6789', 2200.00, 3200.00, 3600.00, 6, 2, 'D2-HL'),
      (12, 'K&N Engineering', '+91-22-2345-6789', 2800.00, 4200.00, 4800.00, 8, 3, 'E1-AF'),
      (13, 'Bosch Ltd India', '+91-80-2345-6789', 180.00, 280.00, 320.00, 35, 15, 'E1-AF'),
      (14, 'Honda Motorcycle Parts', '+91-124-345-6789', 2400.00, 3500.00, 3900.00, 5, 2, 'A2-PIS'),
      (15, 'Bajaj Auto Parts', '+91-20-2345-6789', 2800.00, 4000.00, 4500.00, 4, 2, 'A2-PIS'),
      (16, 'DID Chains India', '+91-22-3456-7890', 1800.00, 2700.00, 3000.00, 12, 5, 'C2-CHN'),
      (17, 'TVS Motor Parts', '+91-44-3456-7890', 2200.00, 3200.00, 3600.00, 8, 3, 'C2-CHN'),
      (18, 'Bosch Ltd India', '+91-80-2345-6789', 220.00, 350.00, 400.00, 25, 10, 'E2-OF'),
      (19, 'TVS King Filters', '+91-44-4567-8901', 180.00, 280.00, 320.00, 30, 12, 'E2-OF')
    ''');

    // Insert product compatibility data
    await _insertSampleCompatibility(db);
  }

  Future<void> _insertSampleCompatibility(Database db) async {
    // Insert realistic product-vehicle compatibility
    await db.execute('''
      INSERT INTO product_compatibility (product_id, vehicle_model_id, is_oem, fit_notes, compatibility_confirmed, added_by) VALUES
      -- NGK Spark Plug CR8E compatible with multiple bikes
      (1, 1, 1, 'OEM fitment', 1, 'System'),
      (1, 2, 1, 'OEM fitment', 1, 'System'),
      (1, 5, 0, 'Direct fit', 1, 'System'),

      -- Bosch Spark Plug for different models
      (2, 3, 0, 'Aftermarket replacement', 1, 'System'),
      (2, 4, 0, 'Direct fit', 1, 'System'),
      (2, 6, 0, 'Compatible', 1, 'System'),

      -- Iridium spark plug for premium bikes
      (3, 7, 0, 'Performance upgrade', 1, 'System'),
      (3, 9, 0, 'Direct fit', 1, 'System'),

      -- Brake pads compatibility
      (4, 4, 0, 'Front brake pads', 1, 'System'),
      (4, 5, 0, 'Direct fit', 1, 'System'),
      (4, 7, 0, 'Compatible', 1, 'System'),

      (5, 1, 0, 'Organic brake pads', 1, 'System'),
      (5, 2, 0, 'Direct fit', 1, 'System'),
      (5, 3, 0, 'Compatible', 1, 'System'),

      -- Clutch plates
      (6, 1, 1, 'OEM clutch plates', 1, 'System'),
      (6, 2, 1, 'OEM fitment', 1, 'System'),
      (6, 3, 1, 'Original part', 1, 'System'),

      (7, 7, 1, 'OEM Bajaj part', 1, 'System'),
      (7, 8, 1, 'Original fitment', 1, 'System'),

      -- Batteries
      (8, 1, 0, '12V 9Ah battery', 1, 'System'),
      (8, 2, 0, 'Direct replacement', 1, 'System'),
      (8, 3, 0, 'Compatible', 1, 'System'),
      (8, 5, 0, 'Suitable', 1, 'System'),
      (8, 7, 0, 'Compatible', 1, 'System'),
      (8, 9, 0, 'Direct fit', 1, 'System'),

      (9, 4, 0, '12V 5Ah scooter battery', 1, 'System'),
      (9, 10, 0, 'Perfect fit', 1, 'System'),

      -- Headlights (universal)
      (10, 1, 0, 'H4 halogen bulb', 1, 'System'),
      (10, 2, 0, 'Universal fit', 1, 'System'),
      (10, 3, 0, 'Standard bulb', 1, 'System'),
      (10, 5, 0, 'Compatible', 1, 'System'),
      (10, 7, 0, 'Universal', 1, 'System'),
      (10, 8, 0, 'Direct fit', 1, 'System'),
      (10, 9, 0, 'Standard', 1, 'System'),

      -- Air filters
      (12, 1, 0, 'High flow filter', 1, 'System'),
      (12, 2, 0, 'Performance upgrade', 1, 'System'),
      (12, 3, 0, 'Direct fit', 1, 'System'),

      (13, 4, 0, 'Paper air filter', 1, 'System'),
      (13, 5, 0, 'Standard filter', 1, 'System'),
      (13, 10, 0, 'OEM replacement', 1, 'System'),

      -- Pistons
      (14, 5, 1, 'OEM Honda piston', 1, 'System'),
      (15, 7, 1, 'OEM Bajaj piston', 1, 'System'),
      (15, 8, 1, 'Original part', 1, 'System'),

      -- Chains
      (16, 1, 0, '428 chain', 1, 'System'),
      (16, 2, 0, 'Direct fit', 1, 'System'),
      (16, 7, 0, 'Compatible', 1, 'System'),
      (16, 8, 0, 'Standard chain', 1, 'System'),

      -- Oil filters
      (18, 1, 0, 'Spin-on filter', 1, 'System'),
      (18, 2, 0, 'Direct fit', 1, 'System'),
      (18, 3, 0, 'Compatible', 1, 'System'),
      (18, 5, 0, 'Standard filter', 1, 'System')
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
