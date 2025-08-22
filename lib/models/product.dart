class Product {
  final int? id;
  final String name;
  final String? partNumber;
  final int subCategoryId;
  final int manufacturerId;
  final String? description;
  final String? specifications; // JSON format for flexible specs
  final double? weight;
  final String? dimensions;
  final String? material;
  final int warrantyMonths;
  final bool isUniversal; // TRUE if fits all vehicles
  final bool isActive; // Product's own active status
  final bool isManuallyDisabled; // Track user-initiated deactivation
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined fields for display
  final String? subCategoryName;
  final String? mainCategoryName;
  final String? manufacturerName;
  final String? primaryImagePath;
  final int? stockQuantity;
  final double? sellingPrice;
  final bool? subCategoryActive;
  final bool? mainCategoryActive;
  final bool?
  isEffectivelyActive; // Computed: active only if both product and categories are active

  Product({
    this.id,
    required this.name,
    this.partNumber,
    required this.subCategoryId,
    required this.manufacturerId,
    this.description,
    this.specifications,
    this.weight,
    this.dimensions,
    this.material,
    this.warrantyMonths = 0,
    this.isUniversal = false,
    this.isActive = true,
    this.isManuallyDisabled = false,
    this.createdAt,
    this.updatedAt,
    this.subCategoryName,
    this.mainCategoryName,
    this.manufacturerName,
    this.primaryImagePath,
    this.stockQuantity,
    this.sellingPrice,
    this.subCategoryActive,
    this.mainCategoryActive,
    this.isEffectivelyActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'part_number': partNumber,
      'sub_category_id': subCategoryId,
      'manufacturer_id': manufacturerId,
      'description': description,
      'specifications': specifications,
      'weight': weight,
      'dimensions': dimensions,
      'material': material,
      'warranty_months': warrantyMonths,
      'is_universal': isUniversal ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'is_manually_disabled': isManuallyDisabled ? 1 : 0,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      partNumber: map['part_number'],
      subCategoryId: map['sub_category_id']?.toInt() ?? 0,
      manufacturerId: map['manufacturer_id']?.toInt() ?? 0,
      description: map['description'],
      specifications: map['specifications'],
      weight: map['weight']?.toDouble(),
      dimensions: map['dimensions'],
      material: map['material'],
      warrantyMonths: map['warranty_months']?.toInt() ?? 0,
      isUniversal: (map['is_universal'] ?? 0) == 1,
      isActive: (map['is_active'] ?? 1) == 1,
      isManuallyDisabled: (map['is_manually_disabled'] ?? 0) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
      subCategoryName: map['sub_category_name'],
      mainCategoryName: map['main_category_name'],
      manufacturerName: map['manufacturer_name'],
      primaryImagePath: map['primary_image_path'],
      stockQuantity: map['stock_quantity']?.toInt(),
      sellingPrice: map['selling_price']?.toDouble(),
      subCategoryActive: map['sub_category_active'] != null
          ? (map['sub_category_active'] ?? 1) == 1
          : null,
      mainCategoryActive: map['main_category_active'] != null
          ? (map['main_category_active'] ?? 1) == 1
          : null,
      isEffectivelyActive: map['is_effectively_active'] != null
          ? (map['is_effectively_active'] ?? 0) == 1
          : null,
    );
  }

  Product copyWith({
    int? id,
    String? name,
    String? partNumber,
    int? subCategoryId,
    int? manufacturerId,
    String? description,
    String? specifications,
    double? weight,
    String? dimensions,
    String? material,
    int? warrantyMonths,
    bool? isUniversal,
    bool? isActive,
    bool? isManuallyDisabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? subCategoryName,
    String? mainCategoryName,
    String? manufacturerName,
    String? primaryImagePath,
    int? stockQuantity,
    double? sellingPrice,
    bool? subCategoryActive,
    bool? mainCategoryActive,
    bool? isEffectivelyActive,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      partNumber: partNumber ?? this.partNumber,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      description: description ?? this.description,
      specifications: specifications ?? this.specifications,
      weight: weight ?? this.weight,
      dimensions: dimensions ?? this.dimensions,
      material: material ?? this.material,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      isUniversal: isUniversal ?? this.isUniversal,
      isActive: isActive ?? this.isActive,
      isManuallyDisabled: isManuallyDisabled ?? this.isManuallyDisabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subCategoryName: subCategoryName ?? this.subCategoryName,
      mainCategoryName: mainCategoryName ?? this.mainCategoryName,
      manufacturerName: manufacturerName ?? this.manufacturerName,
      primaryImagePath: primaryImagePath ?? this.primaryImagePath,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      subCategoryActive: subCategoryActive ?? this.subCategoryActive,
      mainCategoryActive: mainCategoryActive ?? this.mainCategoryActive,
      isEffectivelyActive: isEffectivelyActive ?? this.isEffectivelyActive,
    );
  }

  @override
  String toString() {
    return 'Product{id: $id, name: $name, partNumber: $partNumber, subCategoryId: $subCategoryId, manufacturerId: $manufacturerId, isActive: $isActive, isManuallyDisabled: $isManuallyDisabled}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product &&
        other.id == id &&
        other.name == name &&
        other.partNumber == partNumber &&
        other.subCategoryId == subCategoryId &&
        other.manufacturerId == manufacturerId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        partNumber.hashCode ^
        subCategoryId.hashCode ^
        manufacturerId.hashCode;
  }
}
