import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/customer.dart';
import '../data/customer_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ApiClient.instance);
});

final customersProvider = FutureProvider.autoDispose<List<Customer>>((ref) async {
  final repo = ref.read(customerRepositoryProvider);
  return repo.list();
});
