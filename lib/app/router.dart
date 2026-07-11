import 'package:go_router/go_router.dart';
import 'package:tokri/features/items/presentation/categories_screen.dart';
import 'package:tokri/features/items/presentation/list_detail_screen.dart';
import 'package:tokri/features/lists/presentation/archived_screen.dart';
import 'package:tokri/features/lists/presentation/home_screen.dart';

/// Route names, used with `context.goNamed`/`pushNamed` — never raw strings.
enum AppRoute { home, listDetail, categories, archived }

final router = GoRouter(
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
  ],
);
