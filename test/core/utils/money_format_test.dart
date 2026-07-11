import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/utils/money_format.dart';

void main() {
  test('formats minor units as whole rupees with grouping', () {
    expect(formatMinor(0), 'Rs 0');
    expect(formatMinor(100), 'Rs 1');
    expect(formatMinor(123456), 'Rs 1,235');
    expect(formatMinor(100000000), 'Rs 1,000,000');
  });

  test('honors a custom symbol', () {
    expect(formatMinor(500, symbol: r'$'), r'$5');
  });
}
