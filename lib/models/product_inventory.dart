class ProductInventory {
  final int? id;
  final int productId;
  final String? supplierName;
  final String? supplierContact;
  final String? supplierEmail;
  final double costPrice;
  final double sellingPrice;
  final double mrp;
  final int stockQuantity;
  final int minimumStockLevel;
  final int maximumStockLevel;
  final String? locationRack;
  final DateTime? lastRestockedDate;
  final DateTime? lastSoldDate;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductInventory({
    this.id,
    required this.productId,
    this.supplierName,
    this.supplierContact,
    this.supplierEmail,
    this.costPrice = 0.0,
    this.sellingPrice = 0.0,
    this.mrp = 0.0,
    this.stockQuantity = 0,
    this.minimumStockLevel = 5,
    this.maximumStockLevel = 100,
    this.locationRack,
    this.lastRestockedDate,
    this.lastSoldDate,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'supplier_name': supplierName,
      'supplier_contact': supplierContact,
      'supplier_email': supplierEmail,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'mrp': mrp,
      'stock_quantity': stockQuantity,
      'minimum_stock_level': minimumStockLevel,
      'maximum_stock_level': maximumStockLevel,
      'location_rack': locationRack,
      'last_restocked_date': lastRestockedDate?.toIso8601String().split('T')[0],
      'last_sold_date': lastSoldDate?.toIso8601String().split('T')[0],
      'is_active': isActive ? 1 : 0,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory ProductInventory.fromMap(Map<String, dynamic> map) {
    return ProductInventory(
      id: map['id']?.toInt(),
      productId: map['product_id']?.toInt() ?? 0,
      supplierName: map['supplier_name'],
      supplierContact: map['supplier_contact'],
      supplierEmail: map['supplier_email'],
      costPrice: map['cost_price']?.toDouble() ?? 0.0,
      sellingPrice: map['selling_price']?.toDouble() ?? 0.0,
      mrp: map['mrp']?.toDouble() ?? 0.0,
      stockQuantity: map['stock_quantity']?.toInt() ?? 0,
      minimumStockLevel: map['minimum_stock_level']?.toInt() ?? 5,
      maximumStockLevel: map['maximum_stock_level']?.toInt() ?? 100,
      locationRack: map['location_rack'],
      lastRestockedDate: map['last_restocked_date'] != null
          ? DateTime.parse(map['last_restocked_date'])
          : null,
      lastSoldDate: map['last_sold_date'] != null
          ? DateTime.parse(map['last_sold_date'])
          : null,
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }

  ProductInventory copyWith({
    int? id,
    int? productId,
    String? supplierName,
    String? supplierContact,
    String? supplierEmail,
    double? costPrice,
    double? sellingPrice,
    double? mrp,
    int? stockQuantity,
    int? minimumStockLevel,
    int? maximumStockLevel,
    String? locationRack,
    DateTime? lastRestockedDate,
    DateTime? lastSoldDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductInventory(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      supplierName: supplierName ?? this.supplierName,
      supplierContact: supplierContact ?? this.supplierContact,
      supplierEmail: supplierEmail ?? this.supplierEmail,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      mrp: mrp ?? this.mrp,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minimumStockLevel: minimumStockLevel ?? this.minimumStockLevel,
      maximumStockLevel: maximumStockLevel ?? this.maximumStockLevel,
      locationRack: locationRack ?? this.locationRack,
      lastRestockedDate: lastRestockedDate ?? this.lastRestockedDate,
      lastSoldDate: lastSoldDate ?? this.lastSoldDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isLowStock => stockQuantity <= minimumStockLevel;
  bool get isOutOfStock => stockQuantity <= 0;
  bool get isOverStock => stockQuantity >= maximumStockLevel;

  @override
  String toString() {
    return 'ProductInventory{id: $id, productId: $productId, stockQuantity: $stockQuantity, sellingPrice: $sellingPrice}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductInventory &&
        other.id == id &&
        other.productId == productId;
  }

  @override
  int get hashCode {
    return id.hashCode ^ productId.hashCode;
  }
}
