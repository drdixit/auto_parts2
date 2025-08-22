class ProductImage {
  final int? id;
  final int productId;
  final String imagePath;
  final String imageType; // 'main', 'gallery', 'technical', 'installation'
  final String? altText;
  final int sortOrder;
  final bool isPrimary;
  final DateTime? createdAt;

  ProductImage({
    this.id,
    required this.productId,
    required this.imagePath,
    this.imageType = 'gallery',
    this.altText,
    this.sortOrder = 0,
    this.isPrimary = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'image_path': imagePath,
      'image_type': imageType,
      'alt_text': altText,
      'sort_order': sortOrder,
      'is_primary': isPrimary ? 1 : 0,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory ProductImage.fromMap(Map<String, dynamic> map) {
    return ProductImage(
      id: map['id']?.toInt(),
      productId: map['product_id']?.toInt() ?? 0,
      imagePath: map['image_path'] ?? '',
      imageType: map['image_type'] ?? 'gallery',
      altText: map['alt_text'],
      sortOrder: map['sort_order']?.toInt() ?? 0,
      isPrimary: (map['is_primary'] ?? 0) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }

  ProductImage copyWith({
    int? id,
    int? productId,
    String? imagePath,
    String? imageType,
    String? altText,
    int? sortOrder,
    bool? isPrimary,
    DateTime? createdAt,
  }) {
    return ProductImage(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      imagePath: imagePath ?? this.imagePath,
      imageType: imageType ?? this.imageType,
      altText: altText ?? this.altText,
      sortOrder: sortOrder ?? this.sortOrder,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ProductImage{id: $id, productId: $productId, imagePath: $imagePath, imageType: $imageType, isPrimary: $isPrimary}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductImage &&
        other.id == id &&
        other.productId == productId &&
        other.imagePath == imagePath;
  }

  @override
  int get hashCode {
    return id.hashCode ^ productId.hashCode ^ imagePath.hashCode;
  }
}
