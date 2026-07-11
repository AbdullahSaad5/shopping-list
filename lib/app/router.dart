import 'package:go_router/go_router.dart';
import 'package:tokri/features/lists/presentation/home_screen.dart';

/// Route names, used with `context.goNamed`/`pushNamed` — never raw strings.
enum AppRoute { home }

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: AppRoute.home.name,
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
