class Service {
  Service({
    required this.id,
    required this.categoryId,
    this.categoryName,
    this.categoryIcon,
    required this.name,
    required this.price,
    required this.unit,
    this.durationHours = 24,
    this.isActive = true,
  });

  final int id;
  final int categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String name;
  final double price;
  final String unit;
  final int durationHours;
  final bool isActive;

  factory Service.fromJson(Map<String, dynamic> j) {
    final cat = j['category'];
    // `price` arrives as a num on most code paths, but Eloquent's
    // `decimal:2` cast used to ship it as a string — accept both so an
    // old backend / cached payload still parses.
    final rawPrice = j['price'];
    final price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0.0;
    return Service(
      id: j['id'] as int,
      categoryId: j['category_id'] as int,
      categoryName: cat is Map ? cat['name'] as String? : null,
      categoryIcon: cat is Map ? cat['icon'] as String? : null,
      name: j['name'] as String,
      price: price,
      unit: j['unit'] as String,
      durationHours: (j['duration_hours'] as num?)?.toInt() ?? 24,
      isActive: j['is_active'] as bool? ?? true,
    );
  }
}
