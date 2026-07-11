import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/widgets/app_icons.dart';
import 'package:tokri/features/lists/data/list_repository.dart';

/// Create or edit a list — a full page, not a sheet (creation forms get
/// room to breathe; quick picks stay sheets).
class ListFormScreen extends ConsumerStatefulWidget {
  const ListFormScreen({this.list, super.key});

  final ShoppingList? list;

  static Future<void> show(BuildContext context, {ShoppingList? list}) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ListFormScreen(list: list),
      ),
    );
  }

  @override
  ConsumerState<ListFormScreen> createState() => _ListFormScreenState();
}

class _ListFormScreenState extends ConsumerState<ListFormScreen> {
  final _name = TextEditingController();
  final _budget = TextEditingController();
  int _colorSeed = 0;
  String _icon = 'shopping-basket';

  bool get _isEditing => widget.list != null;

  @override
  void initState() {
    super.initState();
    final l = widget.list;
    if (l != null) {
      _name.text = l.name;
      _colorSeed = l.colorSeed;
      _icon = l.icon;
      if (l.budgetMinor != null) {
        _budget.text = (l.budgetMinor! ~/ 100).toString();
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final budgetRupees = int.tryParse(_budget.text.trim());
    final budgetMinor = budgetRupees == null ? null : budgetRupees * 100;

    final repo = ref.read(listRepositoryProvider);
    if (_isEditing) {
      await repo.update(
        widget.list!.id,
        name: name,
        colorSeed: _colorSeed,
        icon: _icon,
        budgetMinor: budgetMinor,
        clearBudget: budgetMinor == null,
      );
    } else {
      await repo.create(
        name: name,
        colorSeed: _colorSeed,
        icon: _icon,
        budgetMinor: budgetMinor,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = kListAccents[_colorSeed];

    Widget label(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(0, Gaps.xl, 0, Gaps.sm),
          child: Text(
            s,
            style: text.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(_isEditing ? 'Edit list' : 'New list'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Gaps.page,
          0,
          Gaps.page,
          MediaQuery.paddingOf(context).bottom + Gaps.xxl,
        ),
        children: [
          label('Name'),
          TextField(
            controller: _name,
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Groceries, Party, Pharmacy…',
            ),
            onSubmitted: (_) => _save(),
          ),
          label('Color'),
          Row(
            children: [
              for (final (i, color) in kListAccents.indexed) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => setState(() => _colorSeed = i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: _colorSeed == i
                          ? Border.all(color: scheme.onSurface, width: 2.5)
                          : null,
                    ),
                    child: _colorSeed == i
                        ? const Icon(
                            LucideIcons.check,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                if (i < kListAccents.length - 1) const Spacer(),
              ],
            ],
          ),
          label('Icon'),
          Wrap(
            spacing: Gaps.sm,
            runSpacing: Gaps.sm,
            children: [
              for (final name in kListIcons)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _icon = name),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: _icon == name
                          ? accent.withValues(alpha: 0.18)
                          : scheme.surfaceContainer,
                      border: _icon == name
                          ? Border.all(color: accent, width: 2)
                          : null,
                    ),
                    child: Icon(
                      resolveIcon(name),
                      size: 20,
                      color:
                          _icon == name ? accent : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          label('Budget (optional)'),
          TextField(
            controller: _budget,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Rs — leave empty for none',
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          Gaps.page,
          Gaps.sm,
          Gaps.page,
          Gaps.md,
        ),
        child: SizedBox(
          height: 52,
          // Disabled until there's a name — no silent no-op taps.
          child: ValueListenableBuilder(
            valueListenable: _name,
            builder: (context, value, _) => FilledButton(
              onPressed: value.text.trim().isEmpty ? null : _save,
              child: Text(_isEditing ? 'Save' : 'Create list'),
            ),
          ),
        ),
      ),
    );
  }
}
