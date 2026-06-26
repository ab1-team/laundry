import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_provider.dart';
import '../network/asset_url.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_ext.dart';

/// Header used by all bottom-tab screens (Dashboard, Orders, Customers,
/// Reports). Reads the tenant name from [authProvider] automatically; callers
/// that need a different title (e.g. 'Laporan Bisnis') can pass [title] to
/// override.
class AppTabHeader extends ConsumerWidget {
  const AppTabHeader({
    super.key,
    this.title,
    this.trailingIcon = Icons.settings_outlined,
    this.onTrailingTap,
  });

  /// Explicit title override. When `null` the widget reads `tenantName` from
  /// [authProvider].
  final String? title;
  final IconData trailingIcon;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.paddingOf(context).top;
    final user = ref.watch(authProvider).user;
    final resolvedTitle =
        title ?? user?.tenantName ?? '';
    final logoUrl = resolveAssetUrl(user?.tenantLogoUrl);

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 12),
        child: Row(
          children: [
            _TenantLogo(url: logoUrl, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                resolvedTitle,
                style: AppTextStyles.titleLg.copyWith(color: context.colors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(trailingIcon, color: context.colors.onSurface),
              onPressed: onTrailingTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tenant logo (40×40 default). When [url] is null/empty, shows the brand
/// laundry-service icon. When the network image fails to load, also
/// falls back to the icon.
class _TenantLogo extends StatelessWidget {
  const _TenantLogo({required this.url, this.size = 40});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasUrl
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, __, ___) => Icon(
                Icons.local_laundry_service,
                color: AppColors.secondary,
                size: size * 0.55,
              ),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : const SizedBox.shrink(),
            )
          : Icon(
              Icons.local_laundry_service,
              color: AppColors.secondary,
              size: size * 0.55,
            ),
    );
  }
}