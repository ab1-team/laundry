class Customer {
  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    this.totalOrders = 0,
    this.totalSpent = 0,
  });

  final int id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final int totalOrders;
  final double totalSpent;

  factory Customer.fromJson(Map<String, dynamic> j) {
    // total_spent ships as a string when the model uses Eloquent's
    // `decimal:2` cast; accept either type so old payloads still parse.
    final rawSpent = j['total_spent'];
    final totalSpent = rawSpent is num
        ? rawSpent.toDouble()
        : double.tryParse(rawSpent?.toString() ?? '') ?? 0.0;
    return Customer(
      id: j['id'] as int,
      name: j['name'] as String,
      phone: j['phone'] as String?,
      address: j['address'] as String?,
      notes: j['notes'] as String?,
      totalOrders: (j['total_orders'] as num?)?.toInt() ?? 0,
      totalSpent: totalSpent,
    );
  }
}
