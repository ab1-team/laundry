import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'admin_tenants_repository.dart';

final adminTenantsRepositoryProvider = Provider<AdminTenantsRepository>((ref) {
  return AdminTenantsRepository(ApiClient.instance);
});

/// State untuk list tenants: search + status filter + page.
class AdminTenantListFilter {
  const AdminTenantListFilter({this.search = '', this.status});
  final String search;
  final String? status;

  AdminTenantListFilter copyWith({String? search, String? status, bool clearStatus = false}) {
    return AdminTenantListFilter(
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
    );
  }
}

final adminTenantFilterProvider =
    StateProvider<AdminTenantListFilter>((_) => const AdminTenantListFilter());

/// Trigger untuk refresh list — increment manual setelah create/activate/suspend.
final adminTenantsRefreshProvider = StateProvider<int>((_) => 0);
