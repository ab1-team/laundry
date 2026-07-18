import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/master/presentation/master_screen.dart';
import '../../features/orders/presentation/create_order_screen.dart';
import '../../features/orders/presentation/dashboard_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_list_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/change_password_screen.dart';
import '../../features/settings/presentation/edit_profile_screen.dart';
import '../../features/settings/presentation/edit_tenant_contact_screen.dart';
import '../../features/settings/presentation/edit_tenant_info_screen.dart';
import '../../features/settings/presentation/help_screen.dart';
import '../../features/settings/presentation/preference_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/whatsapp_screen.dart';
import '../theme/app_theme_ext.dart';
import '../widgets/bottom_nav_bar.dart';
import '../../features/admin/presentation/admin_create_tenant_screen.dart';
import '../../features/admin/presentation/admin_tenant_detail_screen.dart';
import '../../features/admin/presentation/admin_tenants_list_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.child});
  final Widget? child;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // The shell's tab state is *derived* from the current route, not a
  // local counter. That way "Lihat Semua" → /orders, or any deep link
  // back to a tab, lights up the matching bottom-nav item without
  // needing a separate setState path. The local [int] is only used to
  // highlight the active icon for a tap that's *about* to navigate
  // (GoRouter's redirect returns immediately, so the matched-location
  // read on the next frame would still be the old one — we keep the
  // optimistic index until the route actually changes).
  int _index = 0;
  // Order: Home | Order | Laporan (center) | Customer | Layanan
  static const _items = [
    BottomNavItem(label: 'Home',     icon: Icons.home_outlined,             activeIcon: Icons.home),
    BottomNavItem(label: 'Order',    icon: Icons.list_alt_outlined,         activeIcon: Icons.list_alt),
    BottomNavItem(label: 'Laporan',  icon: Icons.bar_chart_outlined,        activeIcon: Icons.bar_chart),
    BottomNavItem(label: 'Customer', icon: Icons.person_outline,            activeIcon: Icons.person),
    BottomNavItem(label: 'Layanan',  icon: Icons.miscellaneous_services_outlined, activeIcon: Icons.miscellaneous_services),
  ];
  static const _centerIndex = 2; // Laporan

  /// Reverse-lookup the tab index from the current GoRouter location.
  /// Falls back to the local [_index] when the location doesn't map to
  /// a tab (e.g. while a deep-link to /orders/create is on top of the
  /// shell — we keep the previously selected tab highlighted).
  int _resolveIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    switch (loc) {
      case '/home':      return 0;
      case '/orders':    return 1;
      case '/reports':   return 2;
      case '/customers': return 3;
      case '/master':    return 4;
    }
    return _index;
  }

  @override
  Widget build(BuildContext context) {
    // System bar overlay follows the active theme so the status bar icons
    // stay readable in both light and dark mode. AppBarTheme in
    // AppTheme.{light,dark} already configures this for AppBar children,
    // but HomeShell wraps a Scaffold (no AppBar) so we set it here.
    final brightness = Theme.of(context).brightness;
    final systemOverlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarColor: context.colors.surface,
      systemNavigationBarIconBrightness: brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: context.colors.surface,
      systemNavigationBarContrastEnforced: false,
    );
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemOverlay,
        child: widget.child!,
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _resolveIndex(context),
        onTap: (i) {
          setState(() => _index = i);
          switch (i) {
            case 0: context.go('/home');     break;
            case 1: context.go('/orders');   break;
            case 2: context.go('/reports');  break;
            case 3: context.go('/customers');break;
            case 4: context.go('/master');   break;
          }
        },
        items: _items,
        centerIndex: _centerIndex,
      ),
    );
  }
}

/// Bottom-sheet style modal route (32px top radius per DESIGN.md).
class SheetRoute<T> extends PageRouteBuilder<T> {
  SheetRoute({required WidgetBuilder builder}) : super(
    opaque: false,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    barrierDismissible: true,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, anim, _) => builder(ctx),
    transitionsBuilder: (_, anim, __, child) {
      return SlideTransition(
        position: anim.drive(Tween(begin: const Offset(0, 1), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic))),
        child: child,
      );
    },
  );
}

class AppRouter {
  AppRouter._();

  /// Root Navigator GlobalKey — dipakai oleh widget di luar Router scope
  /// (mis. UpdateGate yang di-mount via `builder` callback MaterialApp)
  /// untuk akses Navigator. Tanpa akses ini, Navigator.of(context) dari
  /// UpdateGate gagal karena Navigator di-abstract ke Router API dan
  /// tidak ada di ancestor context.
  ///
  /// Ekspos sebagai public static agar mudah di-inject dari mana saja
  /// tanpa lewat Provider. Identitas-nya satu dengan key yang di-pass
  /// ke GoRouter(navigatorKey:) supaya currentState/context konsisten.
  static final rootKey = GlobalKey<NavigatorState>();
  static final _shellKey = GlobalKey<NavigatorState>();

  /// Adapter: bridge StateNotifier (authProvider) ke Listenable agar
  /// GoRouter otomatis re-evaluate `redirect` setiap kali user login
  /// atau logout — tanpa adapter, redirect hanya jalan pada navigasi
  /// manual, sehingga logout diam-diam tidak me-redirect ke /login.
  static GoRouter build(WidgetRef ref) {
    final auth = ref.read(authProvider.notifier);
    final refresh = _AuthRouterRefresh(auth);
    return GoRouter(
      navigatorKey: rootKey,
      initialLocation: '/login',
      refreshListenable: refresh,
      redirect: (ctx, state) {
        final auth = ref.read(authProvider);
        final loggedIn = auth.isAuthenticated;
        final loggingIn = state.matchedLocation == '/login';
        final isAdmin = auth.user?.isSuperAdmin ?? false;
        final loc = state.matchedLocation;

        if (!loggedIn && !loggingIn) return '/login';

        if (loggedIn && loggingIn) {
          // Super admin → masuk ke panel admin. Selain itu → home biasa.
          return isAdmin ? '/admin/tenants' : '/home';
        }

        // Logged-in user mencoba akses route yang bukan untuk role-nya.
        // Super admin TIDAK boleh masuk shell route (Dashboard/Orders/...)
        // — semua hal operasional tenant hanya untuk owner/operator.
        // User biasa dilarang masuk /admin/*.
        if (loggedIn) {
          final goingToAdmin = loc.startsWith('/admin');
          final inOwnerShell = {
            '/home','/orders','/reports','/customers','/master',
          }.contains(loc);
          if (isAdmin && (inOwnerShell || loc == '/settings' || loc.startsWith('/orders/') || loc.startsWith('/settings/'))) {
            return '/admin/tenants';
          }
          if (!isAdmin && goingToAdmin) {
            return '/home';
          }
        }

        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        ShellRoute(
          navigatorKey: _shellKey,
          builder: (ctx, state, child) => HomeShell(child: child),
          routes: [
            GoRoute(path: '/home',     builder: (_, __) => const DashboardScreen()),
            GoRoute(path: '/orders',   builder: (_, __) => const OrdersListScreen()),
            GoRoute(path: '/reports',  builder: (_, __) => const ReportsScreen()),
            GoRoute(path: '/customers',builder: (_, __) => const CustomersScreen()),
            GoRoute(path: '/master',   builder: (_, __) => const MasterScreen()),
          ],
        ),
        GoRoute(path: '/orders/create', parentNavigatorKey: rootKey, builder: (_, __) => const CreateOrderScreen()),
        GoRoute(
          path: '/orders/:id',
          parentNavigatorKey: rootKey,
          builder: (_, st) => OrderDetailScreen(
            orderId: int.parse(st.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/settings',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/settings/tenant/info',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const EditTenantInfoScreen(),
        ),
        GoRoute(
          path: '/settings/tenant/contact',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const EditTenantContactScreen(),
        ),
        GoRoute(
          path: '/settings/password',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const ChangePasswordScreen(),
        ),
        GoRoute(
          path: '/settings/profile',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const EditProfileScreen(),
        ),
        GoRoute(
          path: '/settings/preferences',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const PreferenceScreen(),
        ),
        GoRoute(
          path: '/settings/help',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const HelpScreen(),
        ),
        GoRoute(
          path: '/settings/whatsapp',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const WhatsAppScreen(),
        ),

        // =====================
        // Super Admin
        // =====================
        GoRoute(
          path: '/admin/tenants',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const AdminTenantsListScreen(),
        ),
        GoRoute(
          path: '/admin/tenants/new',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const AdminCreateTenantScreen(),
        ),
        GoRoute(
          path: '/admin/tenants/:id',
          parentNavigatorKey: rootKey,
          builder: (_, st) => AdminTenantDetailScreen(
            tenantId: int.parse(st.pathParameters['id']!),
          ),
        ),
      ],
    );
  }
}

/// Bridge `StateNotifier<AuthState>` ke `Listenable` agar GoRouter dapat
/// subscribe ke perubahan auth (login/logout/updateUser). Setiap kali
/// state berubah, adapter notify listener → GoRouter re-evaluate
/// `redirect` sehingga user ter-otomatis pindah ke route yang sesuai
/// untuk role-nya (mis. logout → /login, super_admin login → /admin/tenants).
class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(StateNotifier<dynamic> notifier) {
    _sub = notifier.stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
