import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/icon.dart';
import '../data/icon_repository.dart';
import '../data/master_repository.dart';
import '../data/service.dart';
import '../data/service_category.dart';

final masterRepositoryProvider = Provider<MasterRepository>((ref) {
  return MasterRepository(ApiClient.instance);
});

final iconRepositoryProvider = Provider<IconRepository>((ref) {
  return IconRepository(ApiClient.instance);
});

final categoriesProvider = FutureProvider.autoDispose<List<ServiceCategory>>((ref) async {
  final repo = ref.read(masterRepositoryProvider);
  return repo.listCategories();
});

final servicesProvider = FutureProvider.autoDispose<List<Service>>((ref) async {
  final repo = ref.read(masterRepositoryProvider);
  return repo.listServices();
});

/// List icon master. Backend kasih daftar icon yang sudah di-upload admin
/// untuk dipilih sebagai icon kategori/layanan. autoDispose: dibuang
/// saat tidak ada yang watch, refresh otomatis tiap masuk halaman Master.
final iconsProvider = FutureProvider.autoDispose<List<IconAsset>>((ref) async {
  final repo = ref.read(iconRepositoryProvider);
  return repo.listIcons();
});