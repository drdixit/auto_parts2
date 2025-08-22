class SubCategory {
  final int? id;
  final String name;
  final int mainCategoryId;
  final String? description;
  final int sortOrder;
  final bool isActive; // Sub-category's own active status
  final bool isManuallyDisabled; // Track user-initiated deactivation
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? mainCategoryName; // For joined queries
  final bool?
  isEffectivelyActive; // Computed: active only if both sub and main are active

  SubCategory({
    this.id,
    required this.name,
    required this.mainCategoryId,
    this.description,
    this.sortOrder = 0,
    this.isActive = true,
    this.isManuallyDisabled = false,
    this.createdAt,
    this.updatedAt,
    this.mainCategoryName,
    this.isEffectivelyActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'main_category_id': mainCategoryId,
      'description': description,
      'sort_order': sortOrder,
      'is_active': isActive ? 1 : 0,
      'is_manually_disabled': isManuallyDisabled ? 1 : 0,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory SubCategory.fromMap(Map<String, dynamic> map) {
    return SubCategory(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      mainCategoryId: map['main_category_id']?.toInt() ?? 0,
      description: map['description'],
      sortOrder: map['sort_order']?.toInt() ?? 0,
      isActive: (map['is_active'] ?? 1) == 1,
      isManuallyDisabled: (map['is_manually_disabled'] ?? 0) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'])
          : null,
      mainCategoryName: map['main_category_name'], // For joined queries
      isEffectivelyActive: map['is_effectively_active'], // Computed field
    );
  }

  SubCategory copyWith({
    int? id,
    String? name,
    int? mainCategoryId,
    String? description,
    int? sortOrder,
    bool? isActive,
    bool? isManuallyDisabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? mainCategoryName,
    bool? isEffectivelyActive,
  }) {
    return SubCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      mainCategoryId: mainCategoryId ?? this.mainCategoryId,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      isManuallyDisabled: isManuallyDisabled ?? this.isManuallyDisabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mainCategoryName: mainCategoryName ?? this.mainCategoryName,
      isEffectivelyActive: isEffectivelyActive ?? this.isEffectivelyActive,
    );
  }

  @override
  String toString() {
    return 'SubCategory{id: $id, name: $name, mainCategoryId: $mainCategoryId, description: $description, sortOrder: $sortOrder, isActive: $isActive, isManuallyDisabled: $isManuallyDisabled, createdAt: $createdAt, updatedAt: $updatedAt, mainCategoryName: $mainCategoryName}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubCategory &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          mainCategoryId == other.mainCategoryId &&
          description == other.description &&
          sortOrder == other.sortOrder &&
          isActive == other.isActive &&
          isManuallyDisabled == other.isManuallyDisabled;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      mainCategoryId.hashCode ^
      description.hashCode ^
      sortOrder.hashCode ^
      isActive.hashCode ^
      isManuallyDisabled.hashCode;
}
