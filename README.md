# Auto Parts Inventory Management System

A Flutter desktop application for managing automobile parts inventory with a comprehensive database system.

## Features

### Database Structure
- **SQLite Database**: Complete implementation of the provided schema.sql
- **Database Location**: Stored in `{Documents}/auto_parts2/database/auto_parts.db`
- **Image Storage**: User uploaded images stored in `{Documents}/auto_parts2/database/images/`
- **Automatic Initialization**: Database and sample data created on first run

### Main Categories Management
- ✅ **Add/Edit Categories**: Create and modify main product categories
- ✅ **Sort Order**: Organize categories with custom sorting
- ✅ **Icon Support**: Upload custom icons for categories
- ✅ **Status Management**: Activate/deactivate categories using `is_active` flag
- ✅ **Soft Delete**: Categories are not permanently deleted, just marked as inactive
- ✅ **Search**: Real-time search through category names and descriptions
- ✅ **Validation**: Prevents duplicate category names

### Sub Categories Management
- ✅ **Add/Edit Sub-Categories**: Create and modify sub-categories under main categories
- ✅ **Category Association**: Link sub-categories to main categories
- ✅ **Sort Order**: Custom ordering within each main category
- ✅ **Status Management**: Activate/deactivate sub-categories
- ✅ **Soft Delete**: Sub-categories marked as inactive instead of permanent deletion
- ✅ **Search**: Search across sub-category names, descriptions, and parent categories
- ✅ **Protection**: Prevents deletion of sub-categories with associated products
- ✅ **Filter**: Filter sub-categories by main category

### Database Schema Implementation
The application implements the complete database schema from `example_schema/schema.sql`:

1. **manufacturers** - Vehicle and parts manufacturers
2. **vehicle_types** - Motorcycle, car, truck, etc.
3. **vehicle_models** - Specific vehicle models
4. **main_categories** - Primary product categories
5. **sub_categories** - Secondary product categories
6. **products** - Core inventory items
7. **product_compatibility** - Vehicle-part compatibility
8. **product_images** - Multiple images per product
9. **product_inventory** - Stock and pricing information
10. **manufacturer_images** - Manufacturer logo and images
11. **vehicle_model_images** - Vehicle model images

### Sample Data
The application includes comprehensive sample data:
- Vehicle types (Motorcycle, Scooter, Car, Truck, Auto Rickshaw)
- Vehicle manufacturers (Hero, Honda, Bajaj, Maruti, TVS, Royal Enfield, Yamaha)
- Parts manufacturers (Bosch, Lucas TVS, Exide, Castrol, K&N, NGK, etc.)
- Main categories (Engine Parts, Brake System, Transmission, Electrical, etc.)
- Sub-categories (Spark Plugs, Brake Pads, Clutch Plates, Batteries, etc.)
- Vehicle models with specifications

## Installation & Setup

### Prerequisites
- Flutter SDK (3.9.0 or higher)
- Windows 10/11 for desktop application
- Visual Studio with C++ build tools (for Windows development)

### Installation Steps
1. Clone or download the project
2. Open terminal in project directory
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the application:
   ```bash
   flutter run -d windows
   ```

### Database Location
The SQLite database is automatically created at:
```
{User Documents}/auto_parts2/database/auto_parts.db
```

Images are stored at:
```
{User Documents}/auto_parts2/database/images/
```

## Usage

### Navigation
The application uses a rail navigation with the following sections:
- **Dashboard**: Overview and statistics
- **Main Categories**: Manage primary product categories
- **Sub Categories**: Manage secondary categories
- **Products**: (Coming soon) Product management
- **Inventory**: (Coming soon) Stock and pricing management

### Managing Categories

#### Adding a Main Category
1. Go to "Main Categories" section
2. Click "Add Category" button
3. Fill in the required information:
   - Name (required)
   - Description (optional)
   - Sort Order (auto-generated)
   - Icon (optional - upload image file)
   - Active status
4. Click "Save"

#### Editing Categories
1. Click the edit icon (pencil) in the actions column
2. Modify the information
3. Click "Save"

#### Managing Category Status
- **Activate/Deactivate**: Click the eye icon to toggle status
- **Soft Delete**: Click the delete icon to mark as inactive

#### Adding Sub-Categories
1. Go to "Sub Categories" section
2. Click "Add Sub-Category" button
3. Select the main category
4. Fill in the information
5. Click "Save"

### Search and Filter
- Use the search box to find categories by name or description
- Toggle "Show Inactive" to view deactivated items
- Filter sub-categories by main category using the dropdown

## Technical Details

### Architecture
- **Database Layer**: SQLite with custom helper class
- **Service Layer**: Separate service classes for each entity
- **Model Layer**: Dart models matching database schema
- **UI Layer**: Material Design with responsive layout

### Key Dependencies
- `sqflite`: SQLite database support
- `path_provider`: File system access
- `file_picker`: File selection for images
- `provider`: State management (ready for future use)

### Data Validation
- Unique constraints on category names
- Required field validation
- Foreign key relationships maintained
- Soft delete prevents data loss

## Database Schema Highlights

### Indexing
The application creates optimized indexes for:
- Product searches by manufacturer and category
- Vehicle compatibility lookups
- Category and sub-category searches
- Inventory stock levels

### Relationships
- Proper foreign key constraints
- Cascade delete for related data
- Referential integrity maintained

### Soft Delete Pattern
All major entities use the `is_active` flag for soft delete:
- Preserves data integrity
- Maintains historical records
- Allows data restoration
- Prevents accidental data loss

## Future Enhancements
- Product management with full CRUD operations
- Inventory tracking with stock levels
- Vehicle compatibility management
- Image gallery for products
- Reports and analytics
- Data import/export functionality
- Multi-user support with permissions

## Troubleshooting

### Common Issues
1. **Database not found**: The application creates the database automatically on first run
2. **Image upload fails**: Ensure the application has write permissions to the Documents folder
3. **Build errors**: Run `flutter clean` and `flutter pub get`

### File Picker Warnings
The file picker plugin may show warnings about platform implementations. These are harmless and don't affect functionality.

## Database Backup
The database file can be found at:
```
%USERPROFILE%\Documents\auto_parts2\database\auto_parts.db
```

You can backup this file and the images folder for data preservation.
