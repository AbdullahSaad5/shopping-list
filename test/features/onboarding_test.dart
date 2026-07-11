import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tokri/core/settings/settings.dart';
import 'package:tokri/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('walks Welcome → promises → Urdu → Get started',
      (tester) async {
    final container = await pump(tester);
    expect(container.read(settingsProvider).onboardingComplete, isFalse);

    expect(find.text('Welcome to Tokri'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Add items in seconds'), findsOneWidget);
    expect(find.text('Yours alone'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Milk · Doodh'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).onboardingComplete, isTrue);
    // Persisted for the next launch too.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboardingComplete'), isTrue);
  });

  testWidgets('Skip finishes onboarding from any page', (tester) async {
    final container = await pump(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).onboardingComplete, isTrue);
  });
}
