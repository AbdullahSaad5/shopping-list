import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/utils/ledgr_link.dart';

void main() {
  test('builds the ledgr new-transaction link (#14 contract)', () {
    final uri = buildLedgrTxUri(
      amountMinor: 324050,
      payee: 'Weekly shop',
      note: 'Trip from Tokri',
    );
    expect(uri.scheme, 'ledgr');
    expect(uri.host, 'tx');
    expect(uri.path, '/new');
    expect(uri.queryParameters['amountMinor'], '324050');
    expect(uri.queryParameters['payee'], 'Weekly shop');
    expect(uri.queryParameters['note'], 'Trip from Tokri');
  });

  test('encodes hostile payee characters safely', () {
    final uri = buildLedgrTxUri(
      amountMinor: 100,
      payee: 'A&B ?list=1#x %20',
      note: 'n',
    );
    // Round-trips through Uri parsing unchanged.
    final parsed = Uri.parse(uri.toString());
    expect(parsed.queryParameters['payee'], 'A&B ?list=1#x %20');
    expect(parsed.queryParameters['amountMinor'], '100');
  });

  test('omits a null total instead of sending 0', () {
    final uri = buildLedgrTxUri(
      amountMinor: null,
      payee: 'Weekly shop',
      note: 'Trip from Tokri',
    );
    expect(uri.queryParameters.containsKey('amountMinor'), isFalse);
  });
}
