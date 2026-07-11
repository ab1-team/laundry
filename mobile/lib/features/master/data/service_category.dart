import '../../../core/network/asset_url.dart';

class ServiceCategory {
  ServiceCategory({
    required this.id,
    required this.name,
    this.iconId,
    this.iconName,
    this.iconUrl,
    this.iconPath,
    this.sortOrder = 0,
    this.isActive = true,
    this.servicesCount = 0,
  });

  final int id;
  final String name;
  // Backward-compat: `icon` lama adalah string identifier (weight/shirt),
  // sekarang nullable Int FK ke tabel icons. Field baru expose iconUrl
  // langsung dari relasi agar view bisa Image.network tanpa join manual.
  final int? iconId;
  final String? iconName;
  final String? iconUrl;
  final String? iconPath;
  final int sortOrder;
  final bool isActive;
  final int servicesCount;

  factory ServiceCategory.fromJson(Map<String, dynamic> j) {
    // Backend can return `icon` either as a full object (when eager-loaded)
    // or as null. Tahan kedua bentuk supaya FE tidak crash kalau backend
    // belum eager-load relasi.
    final rawIcon = j['icon'];
    Map? iconObj;
    if (rawIcon is Map) iconObj = rawIcon;
    return ServiceCategory(
      id: j['id'] as int,
      name: j['name'] as String,
      iconId: (j['icon_id'] as num?)?.toInt(),
      iconName: iconObj?['name'] as String?,
      iconPath: iconObj?['icon_path'] as String?,
      iconUrl: resolveAssetUrl(iconObj?['icon_url'] as String?),
      sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      isActive: j['is_active'] as bool? ?? true,
      servicesCount: (j['services_count'] as num?)?.toInt() ?? 0,
    );
  }
}
