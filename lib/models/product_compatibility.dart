class ProductCompatibility {
  final int? id;
  final int productId;
  final int vehicleModelId;
  final bool isOem;
  final String? fitNotes;
  final bool compatibilityConfirmed;
  final String? addedBy;
  final DateTime? createdAt;

  // Joined fields
  final String? vehicleModelName;
  final String? manufacturerName;
  final String? vehicleTypeName;
  final int? modelYear;
  final String? engineCapacity;

  ProductCompatibility({
    this.id,
    required this.productId,
    required this.vehicleModelId,
    this.isOem = false,
    this.fitNotes,
    this.compatibilityConfirmed = false,
    this.addedBy,
    this.createdAt,
    this.vehicleModelName,
    this.manufacturerName,
    this.vehicleTypeName,
    this.modelYear,
    this.engineCapacity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'vehicle_model_id': vehicleModelId,
      'is_oem': isOem ? 1 : 0,
      'fit_notes': fitNotes,
      'compatibility_confirmed': compatibilityConfirmed ? 1 : 0,
      'added_by': addedBy,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory ProductCompatibility.fromMap(Map<String, dynamic> map) {
    return ProductCompatibility(
      id: map['id']?.toInt(),
      productId: map['product_id']?.toInt() ?? 0,
      vehicleModelId: map['vehicle_model_id']?.toInt() ?? 0,
      isOem: (map['is_oem'] ?? 0) == 1,
      fitNotes: map['fit_notes'],
      compatibilityConfirmed: (map['compatibility_confirmed'] ?? 0) == 1,
      addedBy: map['added_by'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      vehicleModelName: map['vehicle_model_name'],
      manufacturerName: map['manufacturer_name'],
      vehicleTypeName: map['vehicle_type_name'],
      modelYear: map['model_year']?.toInt(),
      engineCapacity: map['engine_capacity'],
    );
  }

  String get vehicleDisplayName {
    final year = modelYear != null ? '$modelYear ' : '';
    final capacity = engineCapacity != null ? ' ($engineCapacity)' : '';
    return '$manufacturerName $year$vehicleModelName$capacity';
  }

  @override
  String toString() {
    return 'ProductCompatibility{id: $id, productId: $productId, vehicleModelId: $vehicleModelId, isOem: $isOem}';
  }
}
