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

    // Create indexes for better performance
    await _createIndexes(db);
    // Insert sample data (products, categories, etc.)
    await _insertSampleData(db);

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

    // Insert a few customers (shops and trade customers)
    final now = DateTime.now().toIso8601String();
    final aliceId = await db.insert('customers', {
      'name': 'Alpha Auto Stores',
      'address': '12 Market Road',
      'mobile': '9999000001',
      'opening_balance': 0.0,
      'balance': 0.0,
      'created_at': now,
    });
    final bobId = await db.insert('customers', {
      'name': 'Beta Motors',
      'address': '7 Industrial Area',
      'mobile': '9999000002',
      'opening_balance': 0.0,
      // Beta Motors owes 1200.00 -> negative balance to indicate unpaid
      'balance': -1200.00,
      'created_at': now,
    });
    await db.insert('customers', {
      'name': 'Gamma Garage',
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
    // Add larger bulk seed dataset for testing edge cases (idempotent)
    await _insertBulkSeed(db);
  }

  // Insert a larger bulk of seed data to exercise edge-cases and logical flows.
  // This is idempotent: if there are already many customers, skip.
  Future<void> _insertBulkSeed(Database db) async {
    final existing = await db.rawQuery('SELECT COUNT(1) as cnt FROM customers');
    final cnt = (existing.isNotEmpty
        ? (existing.first['cnt'] as int? ?? 0)
        : 0);
    if (cnt > 20) return; // assume already seeded with bulk data

    final imagesDir = await getImagesDirectoryPath();
    final dummyPath = join(imagesDir, 'dummy.jpg');
    final now = DateTime.now().toIso8601String();

    // Create 50 realistic Indian customers. Balances are computed from unpaid bills
    // Mix of shop/trade names and individual customers to mirror real dataset
    final names = <String>[
      'Alpha Auto Stores',
      'Beta Traders',
      'Gamma Garage',
      'Delta Motors',
      'Epsilon Spares',
      'Zeta Two-Wheelers',
      'Eta Service Center',
      'Theta Parts Depot',
      'Iota Repairs',
      'Kappa Auto Care',
      'Lambda Wheels',
      'Mu Garage',
      'Nu Automobile',
      'Xi Motor House',
      'Omicron Auto',
      'Pi Auto Emporium',
      'Rho Car Service',
      'Sigma Bike Shop',
      'Tau Tyres',
      'Upsilon Spares',
      'Phi Motors',
      'Chi Garage',
      'Psi Auto Solutions',
      'Omega Parts',
      'Sunil & Sons Garage',
      'Arun Workshop',
      'Suresh Auto Parts',
      'Sharma Motors',
      'Patel Vehicle Repairs',
      'Kumar Garage',
      'Raju Traders',
      'Nagaraj Spares',
      'Mohan Workshop',
      'Rajesh Wheels',
      'Vikram Auto Center',
      'Ambika Motors',
      'Hari Garage',
      'Rita Service Point',
      'City Auto Store',
      'Township Spares',
      'Neighborhood Garage',
      'Express Auto',
      'Corner Bike Shop',
      'Central Parts',
      'Precision Auto',
      'Prime Motors',
      'Trusty Garage',
      'United Auto Traders',
      'Victory Spares',
    ];

    for (var i = 0; i < 50; i++) {
      final name =
          names[i % names.length] +
          (i >= names.length ? ' ${i - names.length + 1}' : '');
      final mobile = (i % 7 == 0) ? null : '98${70000 + i}';
      final addr = (i % 5 == 0)
          ? 'Plot ${100 + i}, Industrial Area, Near Highway, Pune, Maharashtra'
          : 'Street ${i + 1}, Sector ${((i % 10) + 1)}, City ${((i % 6) + 1)}';

      // Build bills for this customer deterministically so balances are reproducible

      // Patterned bills: some customers have unpaid invoices (owing), some have credits
      if (i % 3 == 0) {
        // one unpaid invoice (will be inserted after customer creation)
      }

      if (i % 11 == 0) {
        // small credit (store owes customer)
        // we'll represent this as positive balance
      }

      // Insert customer with zero balance initially; we'll compute balance after inserting bills
      final cid = await db.insert('customers', {
        'name': name,
        'address': addr,
        'mobile': mobile,
        'opening_balance': 0.0,
        'balance': 0.0,
        'created_at': now,
      });

      // Now re-create the same billed items deterministically so DB and balance match
      if (i % 3 == 0) {
        final prod = ((i * 3) % 20) + 1;
        final tot = 450.0 + (i * 25.0);
        final items = jsonEncode([
          {'product_id': prod, 'qty': 1, 'line_total': tot},
        ]);
        await db.insert('customer_bills', {
          'customer_id': cid,
          'items': items,
          'total': tot,
          'is_paid': 0,
          'is_held': 0,
          'created_at': now,
        });
      }

      if (i % 5 == 0) {
        final prod = ((i * 5) % 20) + 1;
        final tot = 1200.0 + (i * 15.0);
        final items = jsonEncode([
          {'product_id': prod, 'qty': 2, 'line_total': tot},
        ]);
        await db.insert('customer_bills', {
          'customer_id': cid,
          'items': items,
          'total': tot,
          'is_paid': 1,
          'is_held': 0,
          'created_at': now,
        });
      }

      // (Removed positive credit insertion to ensure balances never become positive)

      // Recompute balance from unpaid bills so DB is consistent: balance = -SUM(unpaid totals) + credit
      final unpaidRes = await db.rawQuery(
        'SELECT COALESCE(SUM(total),0) as unpaid FROM customer_bills WHERE customer_id = ? AND is_paid = 0',
        [cid],
      );
      final unpaidNum = (unpaidRes.isNotEmpty
          ? (unpaidRes.first['unpaid'] as num? ?? 0)
          : 0);
      final unpaid = unpaidNum.toDouble();
      double newBalance = -unpaid;
      // no manual positive credits; balance remains negative for unpaid or zero
      await db.update(
        'customers',
        {'balance': newBalance},
        where: 'id = ?',
        whereArgs: [cid],
      );
    }

    // Add some product_images to ensure image paths exist and edge-cases like missing images are covered
    // Only add if product_images is empty
    final piCountRes = await db.rawQuery(
      'SELECT COUNT(1) as cnt FROM product_images',
    );
    final piCount = (piCountRes.isNotEmpty
        ? (piCountRes.first['cnt'] as int? ?? 0)
        : 0);
    if (piCount == 0) {
      // Create image records for first 20 products; some marked primary, some not
      for (var pid = 1; pid <= 20; pid++) {
        final path = dummyPath; // reuse bundled dummy image
        await db.insert('product_images', {
          'product_id': pid,
          'image_path': path,
          'image_type': pid % 3 == 0 ? 'technical' : 'gallery',
          'alt_text': 'Seed image for product $pid',
          'sort_order': pid,
          'is_primary': pid % 5 == 0 ? 1 : 0,
          'created_at': now,
        });
      }
    }

    // Add edge-case inventory rows (zero stock, zero price, very large stock)
    final invCountRes = await db.rawQuery(
      'SELECT COUNT(1) as cnt FROM product_inventory',
    );
    final invCount = (invCountRes.isNotEmpty
        ? (invCountRes.first['cnt'] as int? ?? 0)
        : 0);
    if (invCount < 25) {
      Future<void> safeInsertInventory(Map<String, dynamic> iv) async {
        final pid = iv['product_id'] as int?;
        if (pid == null) return;
        // don't create duplicate inventory rows for same product in seed
        final existing = await db.rawQuery(
          'SELECT COUNT(1) as cnt FROM product_inventory WHERE product_id = ?',
          [pid],
        );
        final exists =
            (existing.isNotEmpty ? (existing.first['cnt'] as int? ?? 0) : 0) >
            0;
        if (exists) return;

        // clamp negative prices to 0 to avoid validators rejecting seeded rows
        iv['cost_price'] =
            (iv['cost_price'] is num && (iv['cost_price'] as num) < 0)
            ? 0.0
            : iv['cost_price'];
        iv['selling_price'] =
            (iv['selling_price'] is num && (iv['selling_price'] as num) < 0)
            ? 0.0
            : iv['selling_price'];
        iv['mrp'] = (iv['mrp'] is num && (iv['mrp'] as num) < 0)
            ? 0.0
            : iv['mrp'];

        iv['created_at'] = now;
        await db.insert('product_inventory', iv);
      }

      // zero stock
      await safeInsertInventory({
        'product_id': 2,
        'supplier_name': 'Edge Supplies',
        'cost_price': 0.0,
        'selling_price': 0.0,
        'mrp': 0.0,
        'stock_quantity': 0,
        'minimum_stock_level': 0,
        'location_rack': 'Z-0',
      });

      // very large stock
      await safeInsertInventory({
        'product_id': 3,
        'supplier_name': 'Bulk Corp',
        'cost_price': 10.0,
        'selling_price': 15.0,
        'mrp': 20.0,
        'stock_quantity': 100000,
        'minimum_stock_level': 10,
        'location_rack': 'BULK-1',
      });

      // previously negative/invalid prices: clamp to 0.0 to avoid validation errors
      await safeInsertInventory({
        'product_id': 4,
        'supplier_name': 'Faulty Supplier',
        'cost_price': -50.0,
        'selling_price': -10.0,
        'mrp': -5.0,
        'stock_quantity': 5,
        'minimum_stock_level': 1,
        'location_rack': 'X-ERR',
      });
    }
  }

  Future<void> _insertSampleProducts(Database db) async {
    // Insert sample products with robust lookups to avoid hard-coded IDs.
    // Define products with names, part numbers, sub-category name and manufacturer name.
    final productDefs = <Map<String, dynamic>>[
      // Spark Plugs
      {
        'name': 'NGK Spark Plug CR8E',
        'part': 'CR8E',
        'sub': 'Spark Plugs',
        'manu': 'NGK',
        'description': 'Standard spark plug for motorcycles',
        'specs':
            '{"electrode_gap": "0.8mm", "thread_size": "M12", "reach": "19mm"}',
        'weight': 0.05,
        'warranty': 12,
        'is_universal': 0,
        'is_active': 1,
      },
      {
        'name': 'Bosch Spark Plug UR4AC',
        'part': 'UR4AC',
        'sub': 'Spark Plugs',
        'manu': 'Bosch',
        'description': 'Copper core spark plug',
        'specs':
            '{"electrode_gap": "0.6mm", "thread_size": "M14", "reach": "12.7mm"}',
        'weight': 0.06,
        'warranty': 6,
        'is_universal': 0,
        'is_active': 1,
      },
      {
        'name': 'NGK Iridium Spark Plug CPR8EAIX-9',
        'part': 'CPR8EAIX-9',
        'sub': 'Spark Plugs',
        'manu': 'NGK',
        'description': 'Premium iridium spark plug for better performance',
        'specs':
            '{"electrode_gap": "0.9mm", "thread_size": "M12", "reach": "19mm", "material": "iridium"}',
        'weight': 0.05,
        'warranty': 24,
        'is_universal': 0,
        'is_active': 1,
      },
      // Brake Pads
      {
        'name': 'Lucas TVS Brake Pad Set Front',
        'part': 'BP-F-125',
        'sub': 'Brake Pads',
        'manu': 'Lucas TVS',
        'description': 'High quality brake pads for front disc brakes',
        'specs':
            '{"material": "ceramic", "temperature_range": "-40°C to 400°C"}',
        'weight': 0.3,
        'warranty': 12,
        'is_universal': 0,
        'is_active': 1,
      },
      {
        'name': 'Bosch Brake Pad Organic',
        'part': 'BP-ORG-150',
        'sub': 'Brake Pads',
        'manu': 'Bosch',
        'description': 'Organic brake pads for smooth braking',
        'specs':
            '{"material": "organic", "temperature_range": "-30°C to 350°C"}',
        'weight': 0.25,
        'warranty': 18,
        'is_universal': 0,
        'is_active': 1,
      },
      // Add remaining definitions similarly (partial set to cover sample inventory/compatibility)
      {
        'name': 'Hero Genuine Clutch Plate Set',
        'part': 'CP-125-H',
        'sub': 'Clutch Plates',
        'manu': 'Hero MotoCorp',
        'description': 'Original clutch plates for Hero motorcycles',
        'specs':
            '{"thickness": "3.2mm", "outer_diameter": "125mm", "inner_diameter": "65mm"}',
        'weight': 0.8,
        'warranty': 12,
        'is_universal': 0,
        'is_active': 1,
      },
      {
        'name': 'Bajaj Original Clutch Friction Plate',
        'part': 'CFP-150-B',
        'sub': 'Clutch Plates',
        'manu': 'Bajaj Auto',
        'description': 'OEM clutch friction plates',
        'specs':
            '{"thickness": "3.5mm", "outer_diameter": "150mm", "inner_diameter": "75mm"}',
        'weight': 1.0,
        'warranty': 12,
        'is_universal': 0,
        'is_active': 1,
      },
      // A few batteries
      {
        'name': 'Exide 12V 9Ah Battery',
        'part': 'EX-12V9AH',
        'sub': 'Batteries',
        'manu': 'Exide',
        'description': 'Maintenance-free motorcycle battery',
        'specs': '{"voltage": "12V", "capacity": "9Ah"}',
        'weight': 2.8,
        'warranty': 18,
        'is_universal': 0,
        'is_active': 1,
      },
      {
        'name': 'Amaron 12V 5Ah Battery',
        'part': 'AM-12V5AH',
        'sub': 'Batteries',
        'manu': 'Amaron',
        'description': 'Long-life VRLA battery for two-wheelers',
        'specs': '{"voltage": "12V", "capacity": "5Ah"}',
        'weight': 1.8,
        'warranty': 24,
        'is_universal': 0,
        'is_active': 1,
      },
    ];

    // Helper to find id by name
    Future<int?> _findId(String table, String name) async {
      final res = await db.rawQuery(
        'SELECT id FROM $table WHERE name = ? LIMIT 1',
        [name],
      );
      if (res.isNotEmpty) return res.first['id'] as int?;
      return null;
    }

    final insertedProductIdsByPart = <String, int>{};

    for (final pd in productDefs) {
      final subName = pd['sub'] as String;
      final manuName = pd['manu'] as String;
      final subId = await _findId('sub_categories', subName);
      final manuId = await _findId('manufacturers', manuName);

      if (subId == null || manuId == null) {
        // Skip insert if lookups fail; avoids referential errors on partial DBs
        print(
          'Skipping product "${pd['name']}" because subId or manuId not found (sub: $subName, manu: $manuName)',
        );
        continue;
      }

      final data = {
        'name': pd['name'],
        'part_number': pd['part'],
        'sub_category_id': subId,
        'manufacturer_id': manuId,
        'description': pd['description'],
        'specifications': pd['specs'],
        'weight': pd['weight'],
        'warranty_months': pd['warranty'],
        'is_universal': pd['is_universal'],
        'is_active': pd['is_active'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        final id = await db.insert('products', data);
        if (pd['part'] != null)
          insertedProductIdsByPart[pd['part'] as String] = id;
      } catch (e) {
        print('Failed to insert product ${pd['name']}: $e');
      }
    }

    // Insert inventory using resolved product IDs (fallback: skip if not found)
    final inventoryDefs = <Map<String, dynamic>>[
      {
        'part': 'CR8E',
        'supplier': 'NGK Spark Plugs India',
        'contact': '+91-80-2234-5678',
        'cost': 180.00,
        'selling': 250.00,
        'mrp': 280.00,
        'stock': 45,
        'min': 10,
        'rack': 'A1-SP',
      },
      {
        'part': 'UR4AC',
        'supplier': 'Bosch Ltd India',
        'contact': '+91-80-2345-6789',
        'cost': 120.00,
        'selling': 180.00,
        'mrp': 200.00,
        'stock': 30,
        'min': 15,
        'rack': 'A1-SP',
      },
      {
        'part': 'CPR8EAIX-9',
        'supplier': 'NGK Spark Plugs India',
        'contact': '+91-80-2234-5678',
        'cost': 450.00,
        'selling': 650.00,
        'mrp': 750.00,
        'stock': 20,
        'min': 5,
        'rack': 'A1-SP',
      },
      // Add couple more inventory rows mapping to parts above
      {
        'part': 'BP-F-125',
        'supplier': 'Lucas TVS',
        'contact': '+91-44-2345-6789',
        'cost': 280.00,
        'selling': 420.00,
        'mrp': 480.00,
        'stock': 25,
        'min': 8,
        'rack': 'B1-BP',
      },
    ];

    for (final inv in inventoryDefs) {
      final part = inv['part'] as String;
      final pid = insertedProductIdsByPart[part];
      if (pid == null) {
        print('Skipping inventory for missing product part $part');
        continue;
      }

      try {
        await db.insert('product_inventory', {
          'product_id': pid,
          'supplier_name': inv['supplier'],
          'supplier_contact': inv['contact'],
          'cost_price': inv['cost'],
          'selling_price': inv['selling'],
          'mrp': inv['mrp'],
          'stock_quantity': inv['stock'],
          'minimum_stock_level': inv['min'],
          'location_rack': inv['rack'],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_active': 1,
        });
      } catch (e) {
        print('Failed to insert inventory for part $part: $e');
      }
    }

    // Insert sample compatibility best-effort: map product part numbers and vehicle model names
    final compatibilityDefs = <Map<String, String>>[
      {'part': 'CR8E', 'vehicle': 'Splendor Plus'},
      {'part': 'CR8E', 'vehicle': 'Passion Pro'},
      {'part': 'CR8E', 'vehicle': 'CB Shine'},
    ];

    for (final c in compatibilityDefs) {
      final pid = insertedProductIdsByPart[c['part']!];
      if (pid == null) continue;
      final vm = await db.rawQuery(
        'SELECT id FROM vehicle_models WHERE name = ? LIMIT 1',
        [c['vehicle']],
      );
      if (vm.isEmpty) continue;
      final vmId = vm.first['id'] as int;
      try {
        await db.insert('product_compatibility', {
          'product_id': pid,
          'vehicle_model_id': vmId,
          'is_primary': 1,
          'notes': 'Seed compatibility',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        print('Failed to insert compatibility for part ${c['part']}: $e');
      }
    }
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
    // Insert realistic product-vehicle compatibility in an idempotent way
    final compatibilityRows = <List<dynamic>>[
      // NGK Spark Plug CR8E compatible with multiple bikes
      [1, 1, 1, 'OEM fitment', 1, 'System'],
      [1, 2, 1, 'OEM fitment', 1, 'System'],
      [1, 5, 0, 'Direct fit', 1, 'System'],

      // Bosch Spark Plug for different models
      [2, 3, 0, 'Aftermarket replacement', 1, 'System'],
      [2, 4, 0, 'Direct fit', 1, 'System'],
      [2, 6, 0, 'Compatible', 1, 'System'],

      // Iridium spark plug for premium bikes
      [3, 7, 0, 'Performance upgrade', 1, 'System'],
      [3, 9, 0, 'Direct fit', 1, 'System'],

      // Brake pads compatibility
      [4, 4, 0, 'Front brake pads', 1, 'System'],
      [4, 5, 0, 'Direct fit', 1, 'System'],
      [4, 7, 0, 'Compatible', 1, 'System'],

      [5, 1, 0, 'Organic brake pads', 1, 'System'],
      [5, 2, 0, 'Direct fit', 1, 'System'],
      [5, 3, 0, 'Compatible', 1, 'System'],

      // Clutch plates
      [6, 1, 1, 'OEM clutch plates', 1, 'System'],
      [6, 2, 1, 'OEM fitment', 1, 'System'],
      [6, 3, 1, 'Original part', 1, 'System'],

      [7, 7, 1, 'OEM Bajaj part', 1, 'System'],
      [7, 8, 1, 'Original fitment', 1, 'System'],

      // Batteries
      [8, 1, 0, '12V 9Ah battery', 1, 'System'],
      [8, 2, 0, 'Direct replacement', 1, 'System'],
      [8, 3, 0, 'Compatible', 1, 'System'],
      [8, 5, 0, 'Suitable', 1, 'System'],
      [8, 7, 0, 'Compatible', 1, 'System'],
      [8, 9, 0, 'Direct fit', 1, 'System'],

      [9, 4, 0, '12V 5Ah scooter battery', 1, 'System'],
      [9, 10, 0, 'Perfect fit', 1, 'System'],

      // Headlights (universal)
      [10, 1, 0, 'H4 halogen bulb', 1, 'System'],
      [10, 2, 0, 'Universal fit', 1, 'System'],
      [10, 3, 0, 'Standard bulb', 1, 'System'],
      [10, 5, 0, 'Compatible', 1, 'System'],
      [10, 7, 0, 'Universal', 1, 'System'],
      [10, 8, 0, 'Direct fit', 1, 'System'],
      [10, 9, 0, 'Standard', 1, 'System'],

      // Air filters
      [12, 1, 0, 'High flow filter', 1, 'System'],
      [12, 2, 0, 'Performance upgrade', 1, 'System'],
      [12, 3, 0, 'Direct fit', 1, 'System'],

      [13, 4, 0, 'Paper air filter', 1, 'System'],
      [13, 5, 0, 'Standard filter', 1, 'System'],
      [13, 10, 0, 'OEM replacement', 1, 'System'],

      // Pistons
      [14, 5, 1, 'OEM Honda piston', 1, 'System'],
      [15, 7, 1, 'OEM Bajaj piston', 1, 'System'],
      [15, 8, 1, 'Original part', 1, 'System'],

      // Chains
      [16, 1, 0, '428 chain', 1, 'System'],
      [16, 2, 0, 'Direct fit', 1, 'System'],
      [16, 7, 0, 'Compatible', 1, 'System'],
      [16, 8, 0, 'Standard chain', 1, 'System'],

      // Oil filters
      [18, 1, 0, 'Spin-on filter', 1, 'System'],
      [18, 2, 0, 'Direct fit', 1, 'System'],
      [18, 3, 0, 'Compatible', 1, 'System'],
      [18, 5, 0, 'Standard filter', 1, 'System'],
    ];

    for (final row in compatibilityRows) {
      try {
        await db.rawInsert(
          'INSERT OR IGNORE INTO product_compatibility (product_id, vehicle_model_id, is_oem, fit_notes, compatibility_confirmed, added_by) VALUES (?, ?, ?, ?, ?, ?)',
          row,
        );
      } catch (e) {
        // ignore individual insert failures - best-effort seed
      }
    }
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
