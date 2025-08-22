class VehicleType {
  final int? id;
  final String name;
  final String? description;
  final DateTime? createdAt;

  VehicleType({this.id, required this.name, this.description, this.createdAt});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory VehicleType.fromMap(Map<String, dynamic> map) {
    return VehicleType(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      description: map['description'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }

  @override
  String toString() {
    return 'VehicleType{id: $id, name: $name}';
  }
}
