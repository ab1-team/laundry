import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/master_repository.dart';
import '../data/service.dart';
import '../data/service_category.dart';

final masterRepositoryProvider = Provider<MasterRepository>((ref) {
  return MasterRepository(ApiClient.instance);
});

final categoriesProvider = FutureProvider.autoDispose<List<ServiceCategory>>((ref) async {
  final repo = ref.read(masterRepositoryProvider);
  return repo.listCategories();
});

final servicesProvider = FutureProvider.autoDispose<List<Service>>((ref) async {
  final repo = ref.read(masterRepositoryProvider);
  return repo.listServices();
});
