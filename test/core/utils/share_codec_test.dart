import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/utils/share_codec.dart';

void main() {
  const items = [
    ShareItem(name: 'Milk', quantity: 2, unit: 'pcs', category: 'Dairy'),
    ShareItem(name: 'Flour', quantity: 500, unit: 'g'),
    ShareItem(name: 'Bread', quantity: 1, unit: 'pcs', checked: true),
  ];

  group('shareText', () {
    test('formats the PLAN §3 shape: checkbox, qty, name, category', () {
      final text = shareText('Groceries', items);
      expect(text, '''
Groceries
☐ 2x Milk (Dairy)
☐ 500g Flour
☑ Bread''');
    });

    test('fractional quantities keep their decimal', () {
      final text = shareText('L', const [
        ShareItem(name: 'Chicken', quantity: 2.5, unit: 'kg'),
      ]);
      expect(text, contains('☐ 2.5kg Chicken'));
    });
  });

  group('list payload codec (tokri://import?d=)', () {
    test('round-trips a list through encode/decode', () {
      final encoded = encodeListPayload('Groceries', items);
      // URL-safe: no +, /, or padding surprises when embedded in a link.
      expect(encoded, isNot(contains('+')));
      expect(encoded, isNot(contains('/')));

      final decoded = decodeListPayload(encoded);
      expect(decoded.name, 'Groceries');
      expect(decoded.items, hasLength(3));
      expect(decoded.items.first.name, 'Milk');
      expect(decoded.items.first.quantity, 2);
      expect(decoded.items.first.unit, 'pcs');
      expect(decoded.items.first.category, 'Dairy');
      // Checked state intentionally not exported: an imported list starts
      // fresh.
      expect(decoded.items.every((i) => !i.checked), isTrue);
    });

    test('deep link builder embeds the payload', () {
      final uri = buildImportUri('Groceries', items);
      expect(uri.scheme, 'tokri');
      expect(uri.host, 'import');
      final decoded = decodeListPayload(uri.queryParameters['d']!);
      expect(decoded.name, 'Groceries');
    });

    test('hostile payloads throw ImportException, not random errors', () {
      expect(
        () => decodeListPayload('not-base64!!'),
        throwsA(isA<ImportException>()),
      );
      expect(
        () => decodeListPayload('aGVsbG8'), // valid base64, not gzip
        throwsA(isA<ImportException>()),
      );
      // Valid gzip+base64 of the wrong JSON shape.
      expect(
        () => decodeListPayload(gzipB64('"just a string"')),
        throwsA(isA<ImportException>()),
      );
      expect(
        () => decodeListPayload(gzipB64('{"v":99,"name":"x","items":[]}')),
        throwsA(isA<ImportException>()),
      );
      expect(
        () => decodeListPayload(gzipB64('{"v":1,"items":[{"q":"x"}]}')),
        throwsA(isA<ImportException>()),
      );
    });

    test('oversized payloads are rejected', () {
      final big = List.generate(
        3000,
        (i) => ShareItem(name: 'Item $i', quantity: 1, unit: 'pcs'),
      );
      expect(
        () => encodeListPayload('Huge', big),
        throwsA(isA<ImportException>()),
      );
    });
  });
}
