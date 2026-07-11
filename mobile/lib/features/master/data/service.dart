import '../../../core/network/asset_url.dart';

class Service {
  Service({
    required this.id,
    required this.categoryId,
    this.categoryName,
    this.categoryIconId,
    this.categoryIconUrl,
    this.iconId,
    this.iconName,
    this.iconUrl,
    required this.name,
    required this.price,
    required this.unit,
    this.durationHours = 24,
    this.isActive = true,
  });

  final int id;
  final int categoryId;
  final String? categoryName;
  // Kategori.icon_id (FK), dan icon milik kategori kalau di-resolve.
  final int? categoryIconId;
  final String? categoryIconUrl;
  // Icon milik service sendiri — override kategori kalau ada. Frontend
  // prioritaskan [iconUrl], fallback ke [categoryIconUrl].
  final int? iconId;
  final String? iconName;
  final String? iconUrl;
  final String name;
  final double price;
  final String unit;
  final int durationHours;
  final bool isActive;

  /// Resolve icon URL dengan prioritas: service.icon → category.icon →
  /// null. Null di view = fallback ke Icons.* default.
  String? get effectiveIconUrl => iconUrl ?? categoryIconUrl;

  factory Service.fromJson(Map<String, dynamic> j) {
    final cat = j['category'];
    Map? catObj;
    if (cat is Map) catObj = cat;
    final icon = j['icon'];
    Map? iconObj;
    if (icon is Map) iconObj = icon;

    final rawPrice = j['price'];
    final price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0.0;
    return Service(
      id: j['id'] as int,
      categoryId: j['category_id'] as int,
      categoryName: catObj?['name'] as String?,
      categoryIconId: (catObj?['icon_id'] as num?)?.toInt(),
      categoryIconUrl: resolveAssetUrl(
        // ServiceCategoryResource expose `icon` (object IconResource) kalau
        // di-eager-load. Frontend baca url-nya dari sini.
        catObj?['icon'] is Map
            ? ((catObj!['icon'] as Map)['icon_url'] as String?)
            : null,
      ),
      iconId: (j['icon_id'] as num?)?.toInt(),
      iconName: iconObj?['name'] as String?,
      iconUrl: resolveAssetUrl(iconObj?['icon_url'] as String?),
      name: j['name'] as String,
      price: price,
      unit: j['unit'] as String,
      durationHours: (j['duration_hours'] as num?)?.toInt() ?? 24,
      isActive: j['is_active'] as bool? ?? true,
    );
  }
}