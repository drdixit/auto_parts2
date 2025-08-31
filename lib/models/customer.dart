class Customer {
  int? id;
  String name;
  String? address;
  String? mobile;
  double openingBalance;
  double balance;
  String? createdAt;

  Customer({
    this.id,
    required this.name,
    this.address,
    this.mobile,
    this.openingBalance = 0.0,
    this.balance = 0.0,
    this.createdAt,
  });

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
    id: m['id'] as int?,
    name: m['name'] as String,
    address: m['address'] as String?,
    mobile: m['mobile'] as String?,
    openingBalance: (m['opening_balance'] ?? 0).toDouble(),
    balance: (m['balance'] ?? 0).toDouble(),
    createdAt: m['created_at'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'address': address,
    'mobile': mobile,
    'opening_balance': openingBalance,
    'balance': balance,
    'created_at': createdAt,
  };
}
