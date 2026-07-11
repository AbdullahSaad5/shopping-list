import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokri/app/router.dart';
import 'package:tokri/app/theme/app_theme.dart';
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
  runApp(const ProviderScope(child: TokriApp()));
}

class TokriApp extends StatelessWidget {
  const TokriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppL10n.of(context).appName,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: tokriTheme(Brightness.light),
      darkTheme: tokriTheme(Brightness.dark),
      routerConfig: router,
    );
  }
}
