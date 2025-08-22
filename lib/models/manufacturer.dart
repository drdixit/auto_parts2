class Manufacturer {
  final int? id;
  final String name;
  final String? logoImagePath;
  final String manufacturerType; // 'vehicle', 'parts', 'both'
  final String? country;
  final String? website;
  final int? establishedYear;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Manufacturer({
    this.id,
    required this.name,
    this.logoImagePath,
    this.manufacturerType = 'parts',
    this.country,
    this.website,
    this.establishedYear,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'logo_image_path': logoImagePath,
      'manufacturer_type': manufacturerType,
      'country': country,
      'website': website,
      'established_year': establishedYear,
      'is_active': isActive ? 1 : 0,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Manufacturer.fromMap(Map<String, dynamic> map) {
    return Manufacturer(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      logoImagePath: map['logo_image_path'],
      manufacturerType: map['manufacturer_type'] ?? 'parts',
      country: map['country'],
      website: map['website'],
      establishedYear: map['established_year']?.toInt(),
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }

  Manufacturer copyWith({
    int? id,
    String? name,
    String? logoImagePath,
    String? manufacturerType,
    String? country,
    String? website,
    int? establishedYear,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Manufacturer(
      id: id ?? this.id,
      name: name ?? this.name,
      logoImagePath: logoImagePath ?? this.logoImagePath,
      manufacturerType: manufacturerType ?? this.manufacturerType,
      country: country ?? this.country,
      website: website ?? this.website,
      establishedYear: establishedYear ?? this.establishedYear,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Manufacturer{id: $id, name: $name, type: $manufacturerType, country: $country, isActive: $isActive}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Manufacturer &&
        other.id == id &&
        other.name == name &&
        other.manufacturerType == manufacturerType;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ manufacturerType.hashCode;
  }
}
