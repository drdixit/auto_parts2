class VehicleModel {
  final int? id;
  final String name;
  final int manufacturerId;
  final int vehicleTypeId;
  final int? modelYear;
  final String? engineCapacity;
  final String? fuelType;
  final String? imagePath;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined fields
  final String? manufacturerName;
  final String? vehicleTypeName;

  VehicleModel({
    this.id,
    required this.name,
    required this.manufacturerId,
    required this.vehicleTypeId,
    this.modelYear,
    this.engineCapacity,
    this.fuelType,
    this.imagePath,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.manufacturerName,
    this.vehicleTypeName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'manufacturer_id': manufacturerId,
      'vehicle_type_id': vehicleTypeId,
      'model_year': modelYear,
      'engine_capacity': engineCapacity,
      'fuel_type': fuelType,
      'image_path': imagePath,
      'is_active': isActive ? 1 : 0,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory VehicleModel.fromMap(Map<String, dynamic> map) {
    return VehicleModel(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      manufacturerId: map['manufacturer_id']?.toInt() ?? 0,
      vehicleTypeId: map['vehicle_type_id']?.toInt() ?? 0,
      modelYear: map['model_year']?.toInt(),
      engineCapacity: map['engine_capacity'],
      fuelType: map['fuel_type'],
      imagePath: map['image_path'],
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
      manufacturerName: map['manufacturer_name'],
      vehicleTypeName: map['vehicle_type_name'],
    );
  }

  String get displayName {
    final year = modelYear != null ? '$modelYear ' : '';
    final capacity = engineCapacity != null ? ' ($engineCapacity)' : '';
    return '$year$name$capacity';
  }

  @override
  String toString() {
    return 'VehicleModel{id: $id, name: $name, manufacturerName: $manufacturerName, modelYear: $modelYear}';
  }
}
