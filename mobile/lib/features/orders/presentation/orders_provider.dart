import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/order_model.dart';
import '../data/order_repository.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ApiClient.instance);
});

final activeOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final repo = ref.read(orderRepositoryProvider);
  return repo.list(group: 'active');
});

final historyOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final repo = ref.read(orderRepositoryProvider);
  return repo.list(group: 'history');
});

final orderDetailProvider = FutureProvider.autoDispose.family<OrderModel, int>((ref, id) async {
  final repo = ref.read(orderRepositoryProvider);
  return repo.show(id);
});
