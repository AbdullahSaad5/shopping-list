import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tokri/app/router.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/settings/settings.dart';
import 'package:tokri/features/onboarding/presentation/onboarding_screen.dart';
import 'package:tokri/l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    // High-refresh displays default to 60Hz on some devices.
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } on Object {
      // Not fatal anywhere.
    }
  }
  // Edge-to-edge: the system nav bar area shows the app's own surface
  // instead of an unthemed white strip (Saad, seen in ledgr too).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const TokriApp(),
    ),
  );
}

class TokriApp extends ConsumerStatefulWidget {
  const TokriApp({super.key});

  @override
  ConsumerState<TokriApp> createState() => _TokriAppState();
}

class _TokriAppState extends ConsumerState<TokriApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // "Default list on launch" resolves once at startup; the router must
    // not be recreated on rebuilds (theme changes etc.).
    final defaultListId = ref.read(settingsProvider).defaultListId;
    _router = createRouter(
      initialLocation:
          defaultListId == null ? '/' : '/list/$defaultListId',
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        final onboarded = ref.watch(
          settingsProvider.select((s) => s.onboardingComplete),
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            systemNavigationBarIconBrightness:
                brightness == Brightness.dark
                    ? Brightness.light
                    : Brightness.dark,
            statusBarIconBrightness: brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              // First-run gate, ledgr pattern: its own Navigator so
              // sheets and text fields have an Overlay in scope.
              if (!onboarded)
                Positioned.fill(
                  child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => const OnboardingScreen(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      onGenerateTitle: (context) => AppL10n.of(context).appName,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: tokriTheme(Brightness.light),
      darkTheme: tokriTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
