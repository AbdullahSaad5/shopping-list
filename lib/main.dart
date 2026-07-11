import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tokri/app/router.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/settings/settings.dart';
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
