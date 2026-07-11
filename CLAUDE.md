# CLAUDE.md — Tokri

Offline-first shopping list app (working title in older docs: CartList). Flutter, Android-first. **`PLAN.md` is the authoritative spec** — read the relevant section before building anything; this file is orientation + rules, not the spec.

## Current state

Empty repo, freshly charted. Work is driven by the wayfinder map — see `docs/agents/issue-tracker.md` for the map issue and conventions. Claim the first open, unblocked, unassigned ticket; one ticket per session.

## What Tokri is (30 seconds)

Add groceries in seconds (autocomplete, bulk paste, flagged voice add); shop with one hand in a dedicated shop mode sorted by aisle; the app learns what you buy (frequency + recency suggestions, price memory per store); running total against a per-list budget. Multiple lists, templates, trips history. 100% local Drift/SQLite in v1 — no backend, no network permission. Sharing v1 = export/import text + QR deep link. v2 adds Firebase shared lists (fenced). Details: PLAN.md §1–§3.

## Stack (locked — do not substitute)

Flutter 3 / Dart 3, Material 3, Riverpod 2, Drift (SQLite), go_router, freezed + json_serializable, shared_preferences, speech_to_text (M2, feature-flagged), fl_chart (v1.1), home_widget (v1.1). PLAN.md §2.

Heads-up from ledgr (same machine, same stack):
- `riverpod_generator` broke build_runner via a `custom_lint_core`/analyzer conflict → if it recurs, fall back to **classic Riverpod providers** (still Riverpod 2).
- `file_picker` pin ^8.3.7 + root-Gradle compileSdk-36 subprojects override pattern lives in ledgr's `android/build.gradle.kts` if plugin AAR metadata checks bite.
- Drift stream gotcha: never reuse identical `customSelect('SELECT 1', readsFrom: ...)` markers across repositories — drift caches streams **by SQL text** and later watchers silently never re-emit. Use `db.tableUpdates(TableUpdateQuery.onAllTables([...]))` for multi-table recompute streams.
- **Modal sheets (learned twice — do not regress):** every `showModalBottomSheet` gets `useRootNavigator: true`, `useSafeArea: true`, `showDragHandle: true`, and content bottom-padding via `sheetBottomInset(context)` (core/widgets/sheet_insets.dart) or bottom actions clip behind 3-button navigation.
- **Snackbars:** only via `showToast()` (core/widgets/toast.dart) — it replaces the current bar instead of queueing. Raw `ScaffoldMessenger.showSnackBar` calls stack up on rapid actions.
- **Widget tests + Drift:** never `await` a stream's `.first` inside `testWidgets` (zero-duration timer + fake clock deadlocks) — wrap DB reads in `tester.runAsync`; pump a `SizedBox` before test end to flush the stream-close timer. Buttons that enable on controller changes need a `tester.pump()` between `enterText` and `tap`.

## Non-negotiable engineering rules

1. **Quantities are ints or fixed-point, prices are integer minor units** (paisa). Never double/REAL for money.
2. **Derived, never stored**: list progress (checked/total), running totals, suggestion ranks — computed from rows/streams, not cached columns.
3. **The quick-add / bulk-add parser is pure logic and ships tests FIRST** (`2x eggs`, `500g flour`, "milk and bread", comma/newline splits). TDD, no exceptions.
4. **DB is the single source of truth.** UI reads Drift `.watch()` streams via Riverpod providers; writes only through repositories; no DB access from widgets.
5. Soft-delete with tombstones + `updatedAt` on syncable tables from day 1 (v2 Firebase sync-ready, mirrors ledgr ADR-0005).
6. No hardcoded colors/strings — theme tokens and constants. Both themes + large-font verified for every screen. Bottom insets: never hardcode clearance; use ambient `MediaQuery` padding (3-button-nav lesson from ledgr).
7. 80% coverage gate, `flutter analyze` clean before every commit.
8. Voice add stays behind a feature flag; degrade to keyboard silently.

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --coverage
flutter build appbundle --release
```

## Git

- Repo: `git@github.com:AbdullahSaad5/shopping-list.git` (personal, private). **Push over SSH only** (`git push origin main`). For `gh` commands prefix the personal token: `GH_TOKEN=$(gh auth token -u AbdullahSaad5) gh <cmd>`. Never `gh auth switch`. Details: `docs/agents/issue-tracker.md`.
- Conventional commits, no attribution footers.

## Agent skills

### Issue tracker

GitHub Issues on `AbdullahSaad5/shopping-list`; external PRs are not a triage surface. See `docs/agents/issue-tracker.md` (includes wayfinder map/ticket conventions and the work-vs-personal `gh` auth caveat).

### Triage labels

Canonical five, unmodified. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/` at repo root. See `docs/agents/domain.md`.

## Scope fence

v1 builds ONLY PLAN.md §3.1 (+ flagged voice add). Firebase shared lists, home widget, stats charts, iOS are specced but fenced (§3.2/§3.3). Do not start them early; do not "prepare abstractions" beyond the sync-ready columns.
