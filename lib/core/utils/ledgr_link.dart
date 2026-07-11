/// Tokri → Ledgr handoff link (ticket #14, counterpart ledgr#18).
///
/// A finished trip offers "Log in Ledgr": `ledgr://tx/new` with the trip
/// total, list name as payee, and a note. Ledgr prefills its new-transaction
/// form and the user confirms there — Tokri never auto-saves anything, and
/// no network is involved on either side.
library;

Uri buildLedgrTxUri({
  required int? amountMinor,
  required String payee,
  required String note,
}) =>
    Uri(
      scheme: 'ledgr',
      host: 'tx',
      path: '/new',
      queryParameters: {
        // A trip with no priced items has no amount; let Ledgr's form
        // start empty rather than prefilling a misleading 0.
        if (amountMinor != null) 'amountMinor': '$amountMinor',
        'payee': payee,
        'note': note,
      },
    );
