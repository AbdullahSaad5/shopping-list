import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/settings/settings.dart';

/// First-run welcome (ledgr's onboarding contract: brand moment, three
/// promises, Welcome/Next/Get started). Shown once as a shell overlay;
/// dismissing persists [AppSettings.onboardingComplete].
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pageCount - 1) {
      ref.read(settingsProvider.notifier).setOnboardingComplete();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: const [
                  _BrandPage(),
                  _PromisesPage(),
                  _UrduPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gaps.page,
                Gaps.sm,
                Gaps.page,
                Gaps.lg,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pageCount; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(
                            horizontal: Gaps.xs / 2,
                          ),
                          width: i == _page ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: i == _page
                                ? scheme.primary
                                : scheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Gaps.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(
                        _page == _pageCount - 1 ? 'Get started' : 'Next',
                      ),
                    ),
                  ),
                  if (_page < _pageCount - 1)
                    TextButton(
                      onPressed: () => ref
                          .read(settingsProvider.notifier)
                          .setOnboardingComplete(),
                      child: Text(
                        'Skip',
                        style: text.labelLarge
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPage extends StatelessWidget {
  const _BrandPage();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(Gaps.page * 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              'assets/icon/icon.png',
              width: 112,
              height: 112,
            ),
          ),
          const SizedBox(height: Gaps.xl),
          Text(
            'Welcome to Tokri',
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Gaps.sm),
          Text(
            'Your bazaar list, in seconds.',
            style: text.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: Gaps.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: text.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromisesPage extends StatelessWidget {
  const _PromisesPage();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(Gaps.page * 1.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Made for the weekly\nbazaar run',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: Gaps.lg),
          const _Promise(
            icon: LucideIcons.zap,
            title: 'Add items in seconds',
            body: 'Type "2x anday, doodh, chawal" — quantities, units, and '
                'aisles sort themselves out.',
          ),
          const _Promise(
            icon: LucideIcons.shoppingCart,
            title: 'Shop with one hand',
            body: 'Shop mode groups by aisle, keeps the screen awake, and '
                'tracks your total against a budget.',
          ),
          const _Promise(
            icon: LucideIcons.shieldCheck,
            title: 'Yours alone',
            body: 'No account, no internet, no tracking. Everything stays '
                'on this phone.',
          ),
        ],
      ),
    );
  }
}

class _UrduPage extends StatelessWidget {
  const _UrduPage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(Gaps.page * 1.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'It speaks your\nUrdu too',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: Gaps.md),
          Text(
            'Type doodh, cheeni, sawaiyan — even with typos — and Tokri '
            'knows what you mean. Suggestions show both names:',
            style:
                text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Gaps.lg),
          Wrap(
            spacing: Gaps.sm,
            runSpacing: Gaps.sm,
            children: [
              for (final label in const [
                'Milk · Doodh',
                'Eggs · Anday',
                'Sugar · Cheeni',
                'Vermicelli · Sawaiyan',
              ])
                Chip(label: Text(label)),
            ],
          ),
        ],
      ),
    );
  }
}
