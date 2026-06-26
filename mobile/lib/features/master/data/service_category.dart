class ServiceCategory {
  ServiceCategory({
    required this.id,
    required this.name,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
    this.servicesCount = 0,
  });

  final int id;
  final String name;
  final String? icon;
  final int sortOrder;
  final bool isActive;
  final int servicesCount;

  factory ServiceCategory.fromJson(Map<String, dynamic> j) => ServiceCategory(
        id: j['id'] as int,
        name: j['name'] as String,
        icon: j['icon'] as String?,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        isActive: j['is_active'] as bool? ?? true,
        servicesCount: (j['services_count'] as num?)?.toInt() ?? 0,
      );
}
