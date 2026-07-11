import '../../../core/network/asset_url.dart';

/// Master Icon asset — file yang diupload admin ke `/master/icons`,
/// disimpan di Storage::disk('public') di backend. Dipakai oleh
/// kategori & layanan via FK icon_id. Field [iconUrl] sudah absolut
/// (origin + /storage/path) supaya Image.network langsung render
/// tanpa concatenation di view.
class IconAsset {
  IconAsset({
    required this.id,
    required this.name,
    this.iconPath,
    this.iconUrl,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String? iconPath;
  // Resolved absolut oleh resolveAssetUrl() di factory — lihat asset_url.dart
  // untuk penjelasan pattern concatenation-nya.
  final String? iconUrl;
  final bool isActive;

  factory IconAsset.fromJson(Map<String, dynamic> j) => IconAsset(
        id: j['id'] as int,
        name: j['name'] as String,
        iconPath: j['icon_path'] as String?,
        iconUrl: resolveAssetUrl(j['icon_url'] as String?),
        isActive: j['is_active'] as bool? ?? true,
      );
}