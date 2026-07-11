import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/utils/budget_math.dart';

void main() {
  group('estimateTotal', () {
    test('sums price × quantity in minor units, rounding per line', () {
      final est = estimateTotal([
        (priceMinor: 25000, quantity: 2.0), // 500.00
        (priceMinor: 999, quantity: 2.5), // 2497.5 → 2498
      ]);
      expect(est.estMinor, 50000 + 2498);
      expect(est.missingPrices, 0);
    });

    test('null prices are skipped and counted', () {
      final est = estimateTotal([
        (priceMinor: 10000, quantity: 1.0),
        (priceMinor: null, quantity: 3.0),
        (priceMinor: null, quantity: 1.0),
      ]);
      expect(est.estMinor, 10000);
      expect(est.missingPrices, 2);
    });

    test('empty input estimates zero with nothing missing', () {
      final est = estimateTotal(const []);
      expect(est.estMinor, 0);
      expect(est.missingPrices, 0);
    });
  });

  group('budgetStatus', () {
    test('no budget → none, regardless of estimate', () {
      expect(budgetStatus(estMinor: 999999, budgetMinor: null),
          BudgetStatus.none);
    });

    test('under 80% → under', () {
      expect(
        budgetStatus(estMinor: 7999, budgetMinor: 10000),
        BudgetStatus.under,
      );
    });

    test('80%..100% → warn (amber)', () {
      expect(
        budgetStatus(estMinor: 8000, budgetMinor: 10000),
        BudgetStatus.warn,
      );
      expect(
        budgetStatus(estMinor: 10000, budgetMinor: 10000),
        BudgetStatus.warn,
      );
    });

    test('over 100% → over (red)', () {
      expect(
        budgetStatus(estMinor: 10001, budgetMinor: 10000),
        BudgetStatus.over,
      );
    });

    test('zero budget treated as no budget', () {
      expect(budgetStatus(estMinor: 1, budgetMinor: 0), BudgetStatus.none);
    });
  });
}
