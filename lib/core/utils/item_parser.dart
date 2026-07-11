import 'package:meta/meta.dart';

/// One parsed entry from the quick-add / bulk-add / voice pipeline.
@immutable
class ParsedItem {
  const ParsedItem({
    required this.name,
    this.quantity = 1,
    this.unit = 'pcs',
  });

  final String name;
  final double quantity;
  final String unit;

  @override
  String toString() => 'ParsedItem($quantity $unit $name)';
}

/// Units the parser recognizes as a leading token. Maps the written form to
/// its canonical unit string (kUnits in seed.dart).
const _unitAliases = <String, String>{
  'kg': 'kg',
  'g': 'g',
  'l': 'L',
  'ml': 'ml',
  'pack': 'pack',
  'packs': 'pack',
  'dozen': 'dozen',
  'pcs': 'pcs',
};

const _numberPattern = r'(\d+(?:[.,]\d+)?)';

/// `2x eggs` / `2 x eggs`
final _timesPattern = RegExp('^$_numberPattern\\s*[xX]\\s+(.+)\$');

/// `500g flour` / `2 kg atta` — number + known unit + name. The unit match is
/// checked against [_unitAliases]; unknown words fall through to plain count.
final _unitPattern = RegExp('^$_numberPattern\\s*([a-zA-Z]+)\\s+(.+)\$');

/// `3 lemons` — leading count. Requires whitespace after the number so names
/// like `7up` stay names.
final _countPattern = RegExp('^$_numberPattern\\s+(.+)\$');

/// Splits raw quick-add / paste / dictation input into items: newlines,
/// commas, and the word "and" separate entries; each entry may lead with a
/// quantity (`2x`, `3 `, `500g `). Pure logic — TDD'd first per CLAUDE.md.
List<ParsedItem> parseItems(String raw) {
  // A comma between digits is a decimal (2,5 kg), not a separator: convert
  // to a dot before splitting.
  final protected = raw.replaceAllMapped(
    RegExp(r'(\d),(\d)'),
    (m) => '${m.group(1)}.${m.group(2)}',
  );
  final segments = protected
      .split(RegExp(r'\n|,|\band\b', caseSensitive: false))
      .map(_clean)
      .where((s) => s.isNotEmpty);

  final items = <ParsedItem>[];
  for (final segment in segments) {
    final item = _parseSegment(segment);
    if (item != null) items.add(item);
  }
  return items;
}

ParsedItem? _parseSegment(String segment) {
  final times = _timesPattern.firstMatch(segment);
  if (times != null) {
    return ParsedItem(
      name: _clean(times.group(2)),
      quantity: _parseNumber(times.group(1)!),
    );
  }

  final unit = _unitPattern.firstMatch(segment);
  if (unit != null) {
    final canonical = _unitAliases[unit.group(2)!.toLowerCase()];
    if (canonical != null) {
      return ParsedItem(
        name: _clean(unit.group(3)),
        quantity: _parseNumber(unit.group(1)!),
        unit: canonical,
      );
    }
  }

  final count = _countPattern.firstMatch(segment);
  if (count != null) {
    return ParsedItem(
      name: _clean(count.group(2)),
      quantity: _parseNumber(count.group(1)!),
    );
  }

  // A bare number is noise, not an item.
  if (RegExp('^$_numberPattern\$').hasMatch(segment)) return null;

  return ParsedItem(name: segment);
}

double _parseNumber(String raw) => double.parse(raw.replaceAll(',', '.'));

String _clean(String? s) =>
    (s ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');

/// The catalog dedupe key: lowercased, trimmed, single-spaced.
String normalizeItemName(String name) => _clean(name).toLowerCase();
