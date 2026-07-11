/// Pure budget/estimate math (PLAN §3 "Budget & prices"). Prices are integer
/// minor units throughout; each line total rounds once.
library;

/// How the estimated total sits against the list budget.
enum BudgetStatus {
  /// No (or zero) budget set — nothing to compare against.
  none,

  /// Below 80% of budget.
  under,

  /// 80%–100% of budget: show amber.
  warn,

  /// Over budget: show red.
  over,
}

/// A priced line: what [estimateTotal] needs from an item row.
typedef PricedLine = ({int? priceMinor, double quantity});

/// Estimate result: known total in minor units + how many lines had no price.
typedef EstTotal = ({int estMinor, int missingPrices});

/// Sums price × quantity over [lines]; lines without a price are counted in
/// `missingPrices` instead of contributing zero silently.
EstTotal estimateTotal(Iterable<PricedLine> lines) {
  var est = 0;
  var missing = 0;
  for (final line in lines) {
    final price = line.priceMinor;
    if (price == null) {
      missing++;
    } else {
      est += (price * line.quantity).round();
    }
  }
  return (estMinor: est, missingPrices: missing);
}

/// Amber at 80% of budget, red past it (PLAN §3 shop-mode total bar rules;
/// the list screen reuses them).
BudgetStatus budgetStatus({required int estMinor, int? budgetMinor}) {
  if (budgetMinor == null || budgetMinor <= 0) return BudgetStatus.none;
  if (estMinor > budgetMinor) return BudgetStatus.over;
  if (estMinor * 5 >= budgetMinor * 4) return BudgetStatus.warn;
  return BudgetStatus.under;
}
