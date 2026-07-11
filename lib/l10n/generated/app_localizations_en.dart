// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Tokri';

  @override
  String get homeTitle => 'My Lists';

  @override
  String get homeEmptyTitle => 'Your tokri is empty';

  @override
  String get homeEmptyMessage => 'Create your first list and start filling it.';

  @override
  String get newList => 'New list';
}
