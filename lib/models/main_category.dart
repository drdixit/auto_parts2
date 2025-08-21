class MainCategory {
  final int? id;
  final String name;
  final String? description;
  final String? iconPath;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;

  MainCategory({
    this.id,
    required this.name,
    this.description,
    this.iconPath,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_path': iconPath,
      'sort_order': sortOrder,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory MainCategory.fromMap(Map<String, dynamic> map) {
    return MainCategory(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      description: map['description'],
      iconPath: map['icon_path'],
      sortOrder: map['sort_order']?.toInt() ?? 0,
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
    );
  }

  MainCategory copyWith({
    int? id,
    String? name,
    String? description,
    String? iconPath,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return MainCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconPath: iconPath ?? this.iconPath,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'MainCategory{id: $id, name: $name, description: $description, iconPath: $iconPath, sortOrder: $sortOrder, isActive: $isActive, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MainCategory &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          iconPath == other.iconPath &&
          sortOrder == other.sortOrder &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      description.hashCode ^
      iconPath.hashCode ^
      sortOrder.hashCode ^
      isActive.hashCode;
}
