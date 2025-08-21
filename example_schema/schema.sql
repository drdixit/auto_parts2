-- =====================================================================
-- FINAL AUTOMOBILE PARTS INVENTORY DATABASE SCHEMA
-- All Requirements Covered with Logical Error Analysis
-- =====================================================================

-- 1. MANUFACTURERS TABLE (Parts & Vehicle Manufacturers)
CREATE TABLE manufacturers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(100) NOT NULL UNIQUE,
    logo_image_path VARCHAR(255), -- Main logo image
    manufacturer_type VARCHAR(20) CHECK (manufacturer_type IN ('vehicle', 'parts', 'both')) DEFAULT 'parts',
    country VARCHAR(50),
    website VARCHAR(255),
    established_year INTEGER,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. VEHICLE TYPES TABLE
CREATE TABLE vehicle_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 3. VEHICLE MODELS TABLE
CREATE TABLE vehicle_models (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(100) NOT NULL,
    manufacturer_id INTEGER NOT NULL,
    vehicle_type_id INTEGER NOT NULL,
    model_year INTEGER,
    engine_capacity VARCHAR(20),
    fuel_type VARCHAR(20) CHECK (fuel_type IN ('petrol', 'diesel', 'electric', 'hybrid', 'cng')),
    image_path VARCHAR(255), -- Main vehicle image
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (manufacturer_id) REFERENCES manufacturers(id) ON DELETE RESTRICT,
    FOREIGN KEY (vehicle_type_id) REFERENCES vehicle_types(id) ON DELETE RESTRICT,
    UNIQUE(name, manufacturer_id, model_year)
);

-- 4. MAIN CATEGORIES TABLE
CREATE TABLE main_categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    icon_path VARCHAR(255),
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 5. SUB CATEGORIES TABLE
CREATE TABLE sub_categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(100) NOT NULL,
    main_category_id INTEGER NOT NULL,
    description TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (main_category_id) REFERENCES main_categories(id) ON DELETE CASCADE,
    UNIQUE(name, main_category_id)
);

-- 6. PRODUCTS TABLE (Core inventory)
CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(200) NOT NULL, -- Product title
    part_number VARCHAR(100),
    sub_category_id INTEGER NOT NULL,
    manufacturer_id INTEGER NOT NULL, -- Who manufactured this part
    description TEXT, -- Product description
    specifications TEXT, -- JSON format for flexible specs
    weight DECIMAL(8,2),
    dimensions VARCHAR(100),
    material VARCHAR(100),
    warranty_months INTEGER DEFAULT 0,
    is_universal BOOLEAN DEFAULT 0, -- TRUE if fits all vehicles
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sub_category_id) REFERENCES sub_categories(id) ON DELETE RESTRICT,
    FOREIGN KEY (manufacturer_id) REFERENCES manufacturers(id) ON DELETE RESTRICT,
    UNIQUE(part_number, manufacturer_id)
);

-- 7. PRODUCT COMPATIBILITY TABLE (Many-to-Many: Products ↔ Vehicles)
CREATE TABLE product_compatibility (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL,
    vehicle_model_id INTEGER NOT NULL,
    is_oem BOOLEAN DEFAULT 0, -- Original Equipment Manufacturer part
    fit_notes VARCHAR(255), -- "Direct fit", "Minor modification", etc.
    compatibility_confirmed BOOLEAN DEFAULT 0,
    added_by VARCHAR(100),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (vehicle_model_id) REFERENCES vehicle_models(id) ON DELETE CASCADE,
    UNIQUE(product_id, vehicle_model_id)
);

-- 8. PRODUCT IMAGES TABLE (Multiple images per product)
CREATE TABLE product_images (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL,
    image_path VARCHAR(255) NOT NULL,
    image_type VARCHAR(20) DEFAULT 'gallery' CHECK (image_type IN ('main', 'gallery', 'technical', 'installation')),
    alt_text VARCHAR(255),
    sort_order INTEGER DEFAULT 0,
    is_primary BOOLEAN DEFAULT 0, -- Main product image
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- 9. PRODUCT INVENTORY TABLE
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
);

-- 10. OPTIONAL: MANUFACTURER IMAGES TABLE (if multiple images needed)
CREATE TABLE manufacturer_images (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    manufacturer_id INTEGER NOT NULL,
    image_path VARCHAR(255) NOT NULL,
    image_type VARCHAR(20) DEFAULT 'logo' CHECK (image_type IN ('logo', 'factory', 'gallery')),
    is_primary BOOLEAN DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (manufacturer_id) REFERENCES manufacturers(id) ON DELETE CASCADE
);

-- 11. OPTIONAL: VEHICLE MODEL IMAGES TABLE (if multiple images needed)
CREATE TABLE vehicle_model_images (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicle_model_id INTEGER NOT NULL,
    image_path VARCHAR(255) NOT NULL,
    image_type VARCHAR(20) DEFAULT 'main' CHECK (image_type IN ('main', 'side', 'interior', 'engine')),
    is_primary BOOLEAN DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (vehicle_model_id) REFERENCES vehicle_models(id) ON DELETE CASCADE
);

-- =====================================================================
-- PERFORMANCE INDEXES
-- =====================================================================

-- Core search indexes
CREATE INDEX idx_products_manufacturer ON products(manufacturer_id);
CREATE INDEX idx_products_subcategory ON products(sub_category_id);
CREATE INDEX idx_products_active ON products(is_active);
CREATE INDEX idx_products_part_number ON products(part_number);
CREATE INDEX idx_products_name ON products(name);

-- Compatibility search indexes
CREATE INDEX idx_compatibility_product ON product_compatibility(product_id);
CREATE INDEX idx_compatibility_vehicle ON product_compatibility(vehicle_model_id);
CREATE INDEX idx_compatibility_confirmed ON product_compatibility(compatibility_confirmed);

-- Vehicle search indexes
CREATE INDEX idx_vehicle_models_manufacturer ON vehicle_models(manufacturer_id);
CREATE INDEX idx_vehicle_models_type ON vehicle_models(vehicle_type_id);
CREATE INDEX idx_vehicle_models_active ON vehicle_models(is_active);
CREATE INDEX idx_vehicle_models_name ON vehicle_models(name);

-- Category search indexes
CREATE INDEX idx_sub_categories_main ON sub_categories(main_category_id);
CREATE INDEX idx_main_categories_active ON main_categories(is_active);
CREATE INDEX idx_sub_categories_active ON sub_categories(is_active);

-- Inventory indexes
CREATE INDEX idx_inventory_product ON product_inventory(product_id);
CREATE INDEX idx_inventory_stock ON product_inventory(stock_quantity);

-- Image indexes
CREATE INDEX idx_product_images_product ON product_images(product_id);
CREATE INDEX idx_product_images_primary ON product_images(is_primary);

-- =====================================================================
-- SAMPLE DATA FOR TESTING
-- =====================================================================

-- Vehicle Types
INSERT INTO vehicle_types (name, description) VALUES
('Motorcycle', 'Two-wheeler motorcycles and bikes'),
('Scooter', 'Automatic two-wheeler scooters'),
('Car', 'Four-wheeler passenger cars'),
('Truck', 'Heavy commercial vehicles'),
('Auto Rickshaw', 'Three-wheeler passenger vehicles');

-- Vehicle Manufacturers
INSERT INTO manufacturers (name, manufacturer_type, country) VALUES
('Hero MotoCorp', 'vehicle', 'India'),
('Honda', 'both', 'Japan'),
('Bajaj Auto', 'vehicle', 'India'),
('Maruti Suzuki', 'vehicle', 'India'),
('TVS Motor', 'vehicle', 'India'),
('Royal Enfield', 'vehicle', 'India'),
('Yamaha', 'vehicle', 'Japan');

-- Parts Manufacturers
INSERT INTO manufacturers (name, manufacturer_type, country) VALUES
('Bosch', 'parts', 'Germany'),
('Lucas TVS', 'parts', 'India'),
('Exide', 'parts', 'India'),
('Castrol', 'parts', 'United Kingdom'),
('K&N', 'parts', 'United States'),
('NGK', 'parts', 'Japan'),
('DID', 'parts', 'Japan'),
('MRF', 'parts', 'India'),
('Amaron', 'parts', 'India');

-- Main Categories
INSERT INTO main_categories (name, description, sort_order) VALUES
('Engine Parts', 'Engine related components', 1),
('Brake System', 'Braking system parts', 2),
('Transmission', 'Gear and transmission parts', 3),
('Electrical', 'Electrical and electronic parts', 4),
('Body Parts', 'Body and exterior parts', 5),
('Suspension', 'Suspension and steering parts', 6),
('Filters', 'Air, oil and fuel filters', 7),
('Lubricants', 'Oils and lubricants', 8),
('Tyres', 'Tyres and wheels', 9);

-- Sub Categories
INSERT INTO sub_categories (name, main_category_id, sort_order) VALUES
-- Engine Parts
('Spark Plugs', 1, 1),
('Pistons', 1, 2),
('Valves', 1, 3),
('Gaskets', 1, 4),
-- Brake System
('Brake Pads', 2, 1),
('Brake Discs', 2, 2),
('Brake Cables', 2, 3),
('Brake Fluid', 2, 4),
-- Transmission
('Clutch Plates', 3, 1),
('Gear Sets', 3, 2),
('Chain & Sprockets', 3, 3),
-- Electrical
('Batteries', 4, 1),
('Headlights', 4, 2),
('Indicators', 4, 3),
-- Filters
('Air Filters', 7, 1),
('Oil Filters', 7, 2),
('Fuel Filters', 7, 3);

-- Sample Vehicle Models
INSERT INTO vehicle_models (name, manufacturer_id, vehicle_type_id, model_year, engine_capacity, fuel_type) VALUES
-- Hero Models
('Splendor Plus', 1, 1, 2023, '100cc', 'petrol'),
('Passion Pro', 1, 1, 2023, '110cc', 'petrol'),
('Glamour', 1, 1, 2023, '125cc', 'petrol'),
-- Honda Models
('Activa 125', 2, 2, 2023, '125cc', 'petrol'),
('CB Shine', 2, 1, 2023, '125cc', 'petrol'),
('City', 2, 3, 2023, '1500cc', 'petrol'),
-- Bajaj Models
('Pulsar 150', 3, 1, 2023, '150cc', 'petrol'),
('Discover 125', 3, 1, 2023, '125cc', 'petrol'),
-- TVS Models
('Apache RTR 160', 5, 1, 2023, '160cc', 'petrol'),
('Jupiter', 5, 2, 2023, '110cc', 'petrol');
