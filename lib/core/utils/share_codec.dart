/// Share/import codecs (PLAN §3 "Sharing", §6.7; format locked by M4).
///
/// Text export: `☐ 2x Milk (Dairy)` lines under the list name.
/// Link export: `tokri://import?d=<base64url(gzip(json))>` with a versioned
/// envelope: `{"v":1,"name":...,"items":[{"n","q","u","c"}]}`. Checked
/// state never travels — an imported list starts fresh.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Friendly failure for anything wrong with an import payload. UI shows
/// [message]; nothing else escapes the codec.
class ImportException implements Exception {
  const ImportException(this.message);

  final String message;

  @override
  String toString() => 'ImportException: $message';
}

/// One shareable line: what leaves the app when a list is exported.
@immutable
class ShareItem {
  const ShareItem({
    required this.name,
    required this.quantity,
    required this.unit,
    this.category,
    this.checked = false,
  });

  final String name;
  final double quantity;
  final String unit;
  final String? category;
  final bool checked;
}

/// A decoded import payload.
typedef ImportedList = ({String name, List<ShareItem> items});

/// QR payloads get unreadable (and Forem-style scanners flaky) past a few
/// KB; 2000 items is far beyond any real list anyway.
const _maxItems = 2000;

String _qty(double quantity, String unit) {
  final n = quantity == quantity.roundToDouble()
      ? quantity.round().toString()
      : quantity.toString();
  if (unit == 'pcs') return '${n}x';
  return '$n$unit';
}

/// Plain-text export, WhatsApp-ready.
String shareText(String listName, List<ShareItem> items) {
  final buffer = StringBuffer(listName);
  for (final item in items) {
    buffer
      ..write('\n')
      ..write(item.checked ? '☑' : '☐')
      ..write(' ');
    final showQty = item.quantity != 1 || item.unit != 'pcs';
    if (showQty) buffer.write('${_qty(item.quantity, item.unit)} ');
    buffer.write(item.name);
    if (item.category != null) buffer.write(' (${item.category})');
  }
  return buffer.toString();
}

/// Encodes a list into the `d=` payload: versioned JSON → gzip → base64url.
String encodeListPayload(String listName, List<ShareItem> items) {
  if (items.length > _maxItems) {
    throw const ImportException('This list is too large to share as a link.');
  }
  final envelope = {
    'v': 1,
    'name': listName,
    'items': [
      for (final i in items)
        {
          'n': i.name,
          'q': i.quantity,
          'u': i.unit,
          if (i.category != null) 'c': i.category,
        },
    ],
  };
  final bytes = gzip.encode(utf8.encode(jsonEncode(envelope)));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// The full import deep link.
Uri buildImportUri(String listName, List<ShareItem> items) => Uri(
      scheme: 'tokri',
      host: 'import',
      queryParameters: {'d': encodeListPayload(listName, items)},
    );

/// Decodes a `d=` payload. Throws [ImportException] on anything hostile:
/// bad base64, bad gzip, wrong JSON shape, unknown version, junk fields.
ImportedList decodeListPayload(String payload) {
  const failed = ImportException("This link doesn't look like a Tokri list.");
  final Object? decoded;
  try {
    final padded = payload.padRight(
      payload.length + (4 - payload.length % 4) % 4,
      '=',
    );
    decoded = jsonDecode(utf8.decode(gzip.decode(base64Url.decode(padded))));
  } on Exception {
    throw failed;
  }
  if (decoded is! Map<String, Object?>) throw failed;
  if (decoded['v'] != 1) {
    throw const ImportException(
      'This list was shared from a newer Tokri — update to import it.',
    );
  }
  final name = decoded['name'];
  final rawItems = decoded['items'];
  if (name is! String || name.isEmpty || rawItems is! List) throw failed;
  if (rawItems.length > _maxItems) throw failed;

  final items = <ShareItem>[];
  for (final raw in rawItems) {
    if (raw is! Map<String, Object?>) throw failed;
    final n = raw['n'];
    final q = raw['q'];
    final u = raw['u'];
    final c = raw['c'];
    if (n is! String || n.isEmpty || q is! num || u is! String) throw failed;
    if (c != null && c is! String) throw failed;
    items.add(
      ShareItem(
        name: n,
        quantity: q.toDouble(),
        unit: u,
        category: c as String?,
      ),
    );
  }
  return (name: name, items: items);
}

/// Test seam: gzip+base64url an arbitrary JSON string the way the encoder
/// does, so hostile-shape payloads can be crafted.
@visibleForTesting
String gzipB64(String json) =>
    base64UrlEncode(gzip.encode(utf8.encode(json))).replaceAll('=', '');
