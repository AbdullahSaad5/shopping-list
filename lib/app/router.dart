import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tokri/features/items/presentation/categories_screen.dart';
import 'package:tokri/features/items/presentation/list_detail_screen.dart';
import 'package:tokri/features/lists/presentation/archived_screen.dart';
import 'package:tokri/features/lists/presentation/home_screen.dart';
import 'package:tokri/features/lists/presentation/import_preview_screen.dart';
import 'package:tokri/features/lists/presentation/search_screen.dart';
import 'package:tokri/features/lists/presentation/templates_screen.dart';
import 'package:tokri/features/settings/presentation/settings_screen.dart';
import 'package:tokri/features/trips/presentation/shop_mode_screen.dart';

/// Route names, used with `context.goNamed`/`pushNamed` — never raw strings.
enum AppRoute {
  home,
  listDetail,
  categories,
  archived,
  shopMode,
  templates,
  search,
  settings,
  import,
}

/// External `tokri://import?d=...` links Uri-parse with host "import" and an
/// empty path — a location go_router has no route for. Rewrite to the
/// canonical `/import`, keeping the query (same trick as ledgr#18).
Uri? normalizeDeepLink(Uri uri) {
  if (uri.host != 'import' || (uri.path != '' && uri.path != '/')) {
    return null;
  }
  return Uri(
    path: '/import',
    queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
  );
}

/// [initialLocation] implements "default list on launch" (PLAN §3
/// Settings): resolved once at startup from settings.
GoRouter createRouter({String initialLocation = '/'}) => GoRouter(
      initialLocation: initialLocation,
      redirect: (context, state) => normalizeDeepLink(state.uri)?.toString(),
      routes: [
        GoRoute(
          path: '/',
          name: AppRoute.home.name,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/list/:id',
          name: AppRoute.listDetail.name,
          builder: (context, state) => ListDetailScreen(
            listId: int.parse(state.pathParameters['id']!),
          ),
          routes: [
            GoRoute(
              path: 'shop',
              name: AppRoute.shopMode.name,
              // Full-screen dialog transition per PLAN §6.4.
              pageBuilder: (context, state) => MaterialPage(
                fullscreenDialog: true,
                child: ShopModeScreen(
                  listId: int.parse(state.pathParameters['id']!),
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/categories',
          name: AppRoute.categories.name,
          builder: (context, state) => const CategoriesScreen(),
        ),
        GoRoute(
          path: '/archived',
          name: AppRoute.archived.name,
          builder: (context, state) => const ArchivedScreen(),
        ),
        GoRoute(
          path: '/templates',
          name: AppRoute.templates.name,
          builder: (context, state) => const TemplatesScreen(),
        ),
        GoRoute(
          path: '/search',
          name: AppRoute.search.name,
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: AppRoute.settings.name,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/import',
          name: AppRoute.import.name,
          builder: (context, state) => ImportPreviewScreen(
            payload: state.uri.queryParameters['d'] ?? '',
          ),
        ),
      ],
    );

/// Default router for the common case (tests, straight-to-home launches).
final router = createRouter();
