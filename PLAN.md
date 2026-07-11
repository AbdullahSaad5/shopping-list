> **Locked decisions (wayfinder, 2026-07-11):** Name **Tokri** (Urdu/Hindi for basket; replaces the working title CartList below). App id **com.abdullahsaad5.tokri** (matches the ledgr convention, replaces com.saad.cartlist). Voice add stays in M2 behind a feature flag. Privacy policy at abdullahsaad5.github.io/tokri/privacy. Where this note and the body disagree, this note wins.

# CartList — Shopping List App: Full Implementation Plan

> Working title: **CartList** (alternatives: Listly, Basket, TrolleyGo — decide before Play listing).
> Platform: **Flutter** (Android first, iOS later). This document is the complete spec: hand it to the coding agent and build top to bottom.

---

## 1. Product Vision

A fast, beautiful, offline-first shopping list app. The core loop is: add items in seconds → shop with one hand → check things off with a satisfying swipe → the app learns what you buy and makes next week faster.

Differentiators over the average Play Store list app:

- **Speed of entry**: autocomplete from purchase history, voice add, paste-a-recipe bulk add.
- **Shop mode**: a dedicated in-store UI, sorted by aisle/category, huge touch targets, keeps screen awake.
- **It learns**: suggestions ranked by frequency + recency, price memory per item per store.
- **Budget awareness**: running total against a per-list budget while you shop.

Target user: anyone who grocery shops weekly. No account required, no ads in MVP, everything local. Monetization later (one-time "Pro" unlock), not in scope for v1.

---

## 2. Tech Stack (locked)

| Concern | Choice | Notes |
|---|---|---|
| Framework | Flutter 3.x, Dart 3 | Material 3, stable channel |
| State management | Riverpod 2 (`hooks_riverpod` + `riverpod_generator`) | AsyncNotifier/Notifier codegen style |
| Database | Drift (SQLite) | Type-safe queries, streams for reactive UI, migrations |
| Navigation | go_router | Declarative, deep-link ready |
| Models | freezed + json_serializable | Immutable data classes |
| DI | Riverpod providers (no extra DI lib) | |
| Local prefs | shared_preferences | Theme, settings, flags |
| Voice input | speech_to_text | MVP nice-to-have, feature-flagged |
| Home widget | home_widget | v1.1, not MVP |
| Charts (stats) | fl_chart | v1.1 |
| Icons | Material Symbols + a curated food/category icon set | |
| Lint | very_good_analysis or flutter_lints (strict) | |
| Tests | flutter_test, drift testing utils, integration_test | |

Everything offline/local. **No backend in v1.** Sharing in v1 is via export/import (text + deep link QR). Real-time shared lists = v2 with Firebase (see roadmap).

---

## 3. Feature Set

### 3.1 MVP (v1.0 — ship this)

**Lists**
- Multiple lists (Groceries, Hardware, Pharmacy, Party…), each with name, color, icon, optional budget, optional linked store.
- Pin/favorite lists, reorder lists (drag), archive completed lists, duplicate list.
- List progress indicator (checked/total + progress ring).
- "Templates": save any list as template, instantiate template into new list (weekly shop in one tap).

**Items**
- Add item: name (autocomplete), quantity + unit (pcs, kg, g, L, ml, pack, dozen, custom), optional price, optional note, category, priority flag.
- Quick-add bar always visible at bottom of list screen: type → suggestions appear inline → tap or enter to add. Repeated adds without closing keyboard.
- Bulk add: multiline paste ("milk\n2x eggs\nbread") parsed into items — parse leading quantity patterns (`2x`, `2 `, `500g `).
- Voice add: dictate several items, same parser splits on "and"/commas.
- Check off: tap checkbox or swipe right. Checked items collapse into a "In cart / Done" section at bottom (collapsible). Swipe left = delete (with undo snackbar). Long-press = multi-select mode (delete, move to another list, change category).
- Edit item via bottom sheet (not a full screen): all fields, delete, "move to list".
- Reorder items manually (drag handle) when sort = manual.
- Sort modes per list: manual / category (aisle) / alphabetical / recently added / unchecked first. Persist per list.
- Item images: none in MVP (category icons only). Keep schema ready for image path.

**Catalog & suggestions (the "it learns" layer)**
- Global item catalog table: every distinct item name ever added, with default unit, default category, last price, times purchased, last purchased date.
- Autocomplete ranks: prefix match first, then substring; order by frequency desc, recency desc.
- Seed catalog with ~150 common grocery items (localized names later) so first-run autocomplete isn't empty.
- "Suggestions" chips above keyboard when quick-add focused and empty: top 10 frequent items not already on this list. One tap adds.

**Categories / aisles**
- Default category set (Produce, Dairy, Bakery, Meat & Fish, Frozen, Pantry, Snacks, Drinks, Household, Personal Care, Baby, Pet, Other) each with icon + color.
- User can add/rename/recolor/reorder categories. Category order = aisle order in shop mode (user drags to match their store's layout).
- Item auto-categorization: seeded catalog carries category; new unknown items default to "Other", user assignment is remembered in catalog for next time.

**Shop mode**
- Entered via prominent FAB/button on a list. Full-screen, larger type and touch targets, grouped by category in aisle order, screen wakelock on, checked items animate out of their group.
- Running total bar: sum of (price × qty) of checked items, vs list budget if set — turns amber >80%, red >100%.
- Quick price entry: tapping an item's price chip in shop mode opens numeric pad; entered price saved to catalog (price memory).
- Exit shop mode → summary sheet: items bought, total spent, duration; option to "archive trip" (writes a Trip record for stats) and clear checked items.

**Budget & prices**
- Optional budget per list. Estimated total shown on list screen (sum of known prices × qty), with "n items missing prices".
- Price memory: last known price per item (per store in v1.1; global in MVP).

**Sharing (local, no backend)**
- Export list as plain text (shareable to WhatsApp etc.), formatted: `☐ 2x Milk (Dairy)`.
- Export/import as deep link + QR code (payload: compressed JSON in a `cartlist://import?d=` link). Import screen previews items before adding.

**Settings**
- Theme: system/light/dark + dynamic color (Material You) toggle + 6 accent seed colors.
- Default list on launch, default unit, currency symbol (display only — no FX), haptics toggle, keep-screen-on in shop mode toggle.
- Data: export full backup (JSON file via share sheet / SAF), import backup, clear data.

**Polish (MVP-mandatory, this is the "modern UI" bar)**
- Material 3 everywhere: dynamic color, tonal surfaces, large screens OK.
- Hero/implicit animations: list card → list screen transition, check-off animation (checkbox morph + strike-through + item slides to done section), FAB → shop mode container transform.
- Haptic feedback on check-off, drag, delete.
- Empty states: friendly illustration + one-line CTA for every empty screen (no lists, empty list, no search results, no archived lists).
- Undo snackbars for every destructive action. No confirm dialogs for single-item deletes (undo instead); confirm only for list deletion and clear-all.
- First-run onboarding: 3 lightweight screens (value prop → create first list pre-filled "Groceries" → done). Skippable.

### 3.2 v1.1 (fast follow)

- Home screen widget: top pinned list, check items from widget (`home_widget` + RemoteViews via glance-style layout).
- Stats screen: trips over time, spend per trip (fl_chart), most-bought items, avg basket size.
- Per-store price memory + store entity (name, aisle order per store).
- Item photos (camera/gallery, stored in app dir, path in DB).
- Recurring lists: auto-recreate template every X days with notification ("Your weekly shop is ready").
- App localization: en + ur (Urdu) as first pair, intl/ARB setup done in MVP even if only en ships.

### 3.3 v2 — Firebase era (planned now, built later)

Decision locked: Firebase IS coming, but **offline-first is the architecture forever** — Firebase is a sync layer on top of the local DB, never a replacement. The app must remain 100% functional signed-out.

**v2.0 — Auth + own-device sync**
- Firebase Auth: **Google Sign-In** (primary) + anonymous auth that upgrades/links to Google on sign-in (so pre-login data is never lost).
- Sign-in is optional, prompted softly (Settings + a one-time "back up your lists?" card), never a wall.
- Firestore mirror of local DB: `users/{uid}/lists/{listUuid}`, `.../items/{itemUuid}`, `.../catalog/{entryUuid}`, categories in a single doc.
- Sync engine (local-first):
  - Local Drift DB stays the single source of truth for UI. UI never reads Firestore directly.
  - Push: outbox pattern — every local write also appends a pending-op row; a sync worker drains the outbox to Firestore when online.
  - Pull: Firestore snapshot listeners → upsert into Drift by `uuid` where remote `updatedAt` > local.
  - Conflict rule: last-write-wins per row via `updatedAt` (server timestamp), EXCEPT `checked` flips where latest `checkedAt` wins. Good enough for a list app; no CRDTs.
  - Deletes sync via tombstones (`deletedAt` set, row purged after 30 days both sides).
- First sign-in migration: bulk-upload entire local DB; if account already has data, merge by uuid (no duplicates).
- Sign-out: keep local data (it's the user's), stop sync.

**v2.1 — Shared lists (the payoff)**
- Shared list doc moves to `sharedLists/{uuid}` with `members: {uid: role}` map; invite via dynamic link/QR; roles: owner/editor.
- Live check-off (Firestore listeners already in place), member avatars on items ("checked by Sara").
- Firestore security rules: user docs locked to uid; shared lists readable/writable by members map only; rules unit-tested with emulator.

**v2.x — rest**
- Barcode scan add (mobile_scanner + Open Food Facts lookup).
- Smart "you usually buy milk around now" suggestions (simple periodicity detection).
- Pro unlock (one-time IAP): widgets+, unlimited templates, stats history, icon packs.

**Cost/ops note**: free Spark tier fine until real traction; no Cloud Functions needed for v2.0 (client-driven sync); add crashlytics + analytics only with consent toggle.

---

## 4. Architecture

Feature-first clean-ish layering. No over-engineering: repositories over Drift DAOs, Riverpod notifiers as the only state holders, widgets dumb.

```
lib/
  main.dart                 # bootstrap: ProviderScope, theme, router
  app/
    router.dart             # go_router config, routes enum
    theme/                  # ColorScheme builders, text theme, component themes
    l10n/                   # ARB files, generated localizations
  core/
    db/
      database.dart         # Drift database class + migrations
      tables.dart           # all table definitions
      seed.dart             # category + catalog seeding
    utils/                  # parsers (bulk add), formatters (money, qty), haptics helper
    widgets/                # shared UI: EmptyState, ConfirmSheet, UndoSnackbar, ColorDot,
                            # QuantityStepper, PriceField, IconPickerSheet
  features/
    lists/                  # list-of-lists (home)
      data/                 # ListRepository (wraps DAO)
      domain/               # ShoppingList model (freezed), ListWithStats view model
      presentation/         # HomeScreen, ListCard, CreateListSheet, providers
    items/                  # inside a list
      data/                 # ItemRepository, CatalogRepository
      domain/               # Item, CatalogEntry, ParsedItem
      presentation/         # ListDetailScreen, QuickAddBar, ItemTile, ItemEditSheet,
                            # SuggestionChips, SortMenu, MultiSelectAppBar, providers
    shop_mode/
      presentation/         # ShopModeScreen, RunningTotalBar, PricePadSheet, TripSummarySheet
    templates/
    share/                  # export text, deep link codec, QR screen, ImportPreviewScreen
    stats/                  # v1.1
    settings/
    onboarding/
```

**State pattern rules for the coding agent:**
- Every screen reads a single `@riverpod` provider exposing an immutable state class (freezed). Drift `.watch()` streams feed `StreamProvider`s; notifiers combine them.
- All writes go through repository methods; repositories are the only classes touching DAOs. No DB calls from widgets or notifiers directly.
- All mutations return quickly and UI reacts via streams (single source of truth = DB). Optimistic UI unnecessary because SQLite is fast and local.
- No `setState` except trivial local widget concerns (e.g., text field focus).
- Immutability everywhere: freezed `copyWith`, never mutate.

---

## 5. Data Model (Drift schema v1)

```dart
// tables.dart — authoritative schema

class ShoppingLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get colorSeed => integer()();                    // index into accent palette
  TextColumn get icon => text()();                           // material symbol name
  RealColumn get budget => real().nullable()();              // null = no budget
  IntColumn get sortMode => intEnum<ListSortMode>()();       // manual/category/alpha/recent/uncheckedFirst
  IntColumn get position => integer()();                     // manual ordering of lists
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  BoolColumn get isTemplate => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get icon => text()();
  IntColumn get color => integer()();                        // ARGB
  IntColumn get position => integer()();                     // aisle order
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

class Items extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get listId => integer().references(ShoppingLists, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  RealColumn get price => real().nullable()();               // unit price
  TextColumn get note => text().nullable()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();
  BoolColumn get checked => boolean().withDefault(const Constant(false))();
  BoolColumn get priority => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer()();                     // manual order within list
  TextColumn get imagePath => text().nullable()();           // reserved for v1.1
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get checkedAt => dateTime().nullable()();
}

class CatalogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nameNormalized => text().unique()();        // lowercase, trimmed — dedupe key
  TextColumn get displayName => text()();
  TextColumn get defaultUnit => text().withDefault(const Constant('pcs'))();
  IntColumn get categoryId => integer().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();
  RealColumn get lastPrice => real().nullable()();
  IntColumn get timesPurchased => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPurchasedAt => dateTime().nullable()();
  BoolColumn get isSeeded => boolean().withDefault(const Constant(false))();
}

class Trips extends Table {                                   // written on shop-mode completion
  IntColumn get id => integer().autoIncrement()();
  IntColumn get listId => integer().nullable().references(ShoppingLists, #id, onDelete: KeyAction.setNull)();
  TextColumn get listName => text()();                        // denormalized, survives list deletion
  IntColumn get itemCount => integer()();
  RealColumn get totalSpent => real().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  DateTimeColumn get completedAt => dateTime()();
}
```

Indexes: `Items(listId, checked, position)`, `CatalogEntries(nameNormalized)`, `Trips(completedAt)`.

**Sync-readiness (build into v1 schema NOW — cheap now, painful migration later).** Firebase sync is coming in v2 (§3.3), so every syncable table (`ShoppingLists`, `Items`, `Categories`, `CatalogEntries`) also gets:

```dart
TextColumn get uuid => text().clientDefault(() => const Uuid().v4()).unique()();  // stable cross-device id
DateTimeColumn get updatedAt => dateTime()();       // touched on EVERY write (repository responsibility)
DateTimeColumn get deletedAt => dateTime().nullable()();  // tombstone; queries filter isNull
```

v1 behavior: local int ids remain the FK mechanism; `deletedAt` tombstones replace hard deletes on syncable tables (purge job clears >30-day tombstones); `updatedAt` maintained by repositories from day 1. Backup format includes uuids. This means v2 sync is additive — no schema surgery, no data migration for existing users.

**Catalog update rules** (implement in `CatalogRepository.recordPurchase`): on item checked in shop mode (or trip archived), upsert catalog entry by normalized name — increment timesPurchased, set lastPurchasedAt, update lastPrice if item has price, learn categoryId if user set one.

**Backup format**: single JSON `{version: 1, exportedAt, lists: [...], items: [...], categories: [...], catalog: [...], trips: [...]}`. Import strategy: full replace after confirm (MVP), merge later.

---

## 6. Screen-by-Screen Spec

### 6.1 Home (Lists overview) — route `/`
- Large app bar "My Lists" collapsing on scroll; actions: search, overflow (Archived, Templates, Settings).
- Pinned lists first, then rest by position. Card per list: color-tinted M3 surface, icon, name, "n of m done" + thin progress bar, est. total if prices known, overflow menu (pin, edit, duplicate, save as template, archive, delete).
- Drag to reorder (long-press). FAB "New list" → bottom sheet: name, icon picker (grid sheet), color picker (6 seeds), budget (optional), create. New list opens immediately.
- Empty state: illustration + "Create your first list".

### 6.2 List detail — route `/list/:id`
- App bar: list name (tap to rename inline), progress ring, actions: sort menu, shop mode button (prominent, filled tonal "Shop" with cart icon), overflow (edit list, share/export, clear checked, clear all, delete).
- Body: items grouped by category when sort=category (sticky group headers with category color dot); flat list otherwise. Each `ItemTile`: animated checkbox, name (+ qty×unit chip when ≠1 pcs, + price chip when set, + note preview line, + priority dot), drag handle in manual sort.
- Checked section: collapsed expandable "Done (n)" at bottom, items struck through and dimmed. "Uncheck all" / "Clear checked" buttons inside.
- Quick-add bar docked above keyboard/bottom: TextField + qty stepper (appears once typing) + add button. Autocomplete dropdown anchored above bar (max 5). Suggestion chips row when field empty & focused. Mic icon → voice add flow. Overflow icon in bar → "Paste multiple items" bulk add sheet.
- Gestures: swipe right = check/uncheck, swipe left = delete+undo, tap = toggle check, tap on text area = edit sheet, long-press = multi-select.

### 6.3 Item edit — modal bottom sheet
Name (autocomplete again), qty stepper + unit dropdown (chips: pcs/kg/g/L/ml/pack + "custom…"), price field with currency prefix, category picker (horizontal chip row + "manage"), note field, priority toggle, move-to-list dropdown, delete button. Save button pinned; sheet is scrollable when keyboard up.

### 6.4 Shop mode — route `/list/:id/shop`, full-screen dialog transition
- Wakelock on. Top bar: list name, running total vs budget (`Rs 3,240 / 5,000`, colored), close (confirm if trip in progress? no — confirm only on "finish").
- Groups in aisle (category position) order; only unchecked shown large, checked count shown per group header. Tile: big checkbox (48dp+), name 18sp, qty/unit, price chip (tap → numeric pad sheet, saves price to item + catalog).
- Checking last item in group collapses group with animation. All done → full-screen "🎉 All done" state with Finish button.
- Bottom bar: Finish trip → TripSummarySheet (count, total, duration, [Archive trip & clear checked] [Just close]).

### 6.5 Templates — route `/templates`
List of templates, tap → "Create list from template" (pre-checked all items reset to unchecked), edit template, delete.

### 6.6 Search — route `/search`
Global: matches item names across lists (result rows show list badge) + list names. Tapping jumps to list with item highlighted (scroll + flash).

### 6.7 Share / Import
- Share sheet from list overflow: [Copy as text] [Share…] [QR code].
- QR screen: renders deep link QR. Import route `/import?d=` shows preview screen (items, target: new list or merge into existing) before committing.

### 6.8 Settings — route `/settings`
Sections: Appearance (theme mode, dynamic color, accent), Behavior (default list, default unit, currency symbol, haptics, wakelock), Categories (manage/reorder screen), Data (backup/export, import, clear), About (version, licenses, privacy policy link).

### 6.9 Archived lists — route `/archived`
Simple list, restore/delete forever.

**Navigation map:** Home → List → (ItemSheet | ShopMode | Share) ; Home → Search/Settings/Templates/Archived. go_router paths as noted; deep link scheme `cartlist://` for import.

---

## 7. Design System

- **Color**: Material 3 dynamic color when available; fallback seed `#4CAF7D` (fresh green). Each list's accent = seed palette index, applied as card tint + progress bar + shop mode top bar tint via `ColorScheme.fromSeed(seedColor: listSeed)` scoped theme.
- **Type**: default Material 3 type scale; display font optional — if used, one distinctive but clean font for large headings only (e.g., "Outfit" or "Sora" via google_fonts), body stays default. No more than 2 fonts.
- **Shape**: 16dp radius cards, 28dp radius sheets/FAB (M3 defaults), full-width list tiles with 12dp inner radius on swipe backgrounds.
- **Motion**: standard M3 durations/easing; container transform (Home card → List screen, Shop button → Shop mode) via `animations` package (`OpenContainer`); item check = 200ms checkbox morph + strike draw + 250ms slide-out; deletes = `AnimatedList` removals; reorder = default proxy elevation.
- **Dark mode**: pure token-driven, verify all custom colors have dark variants; no hardcoded whites/blacks (repo rule: no hardcoded values — theme constants only).
- **Accessibility**: 48dp min targets, semantics labels on swipe actions and checkboxes, contrast-check the amber/red budget states, support large font scale (test at 1.3×).

---

## 8. Key Implementation Details & Edge Cases

- **Bulk/voice parser** (`core/utils/item_parser.dart`): input lines/segments → `ParsedItem(name, qty, unit)`. Grammar: optional leading `(\d+[.,]?\d*)\s*(x|×)?\s*(kg|g|l|ml|pcs|pack|dozen)?` then name; also trailing qty ("milk 2l"). Unit synonyms map (litre/liter/l). Write exhaustive unit tests first (TDD) — this is the highest-regression-risk pure logic in the app.
- **Autocomplete debounce** 150ms; query catalog with `LIKE prefix% ORDER BY timesPurchased DESC, lastPurchasedAt DESC LIMIT 5`, fall back to `%substring%` if <5 results.
- **Duplicate adds**: adding an item whose normalized name already exists unchecked on the list → increment that item's quantity instead (snackbar "Milk ×2"), don't create duplicate row. If exists but checked → uncheck it and bump qty.
- **Position management**: new items appended (`max(position)+1`); reorder writes compacted positions in one transaction.
- **Undo**: soft window — keep deleted row in memory in notifier, reinsert on undo; on snackbar timeout do nothing (row already deleted from DB at swipe time, reinsert restores id via fresh insert; acceptable, ids not user-visible).
- **Clear checked vs archive trip**: archiving writes Trip + catalog purchase records THEN deletes checked items — single transaction.
- **Migrations**: Drift schemaVersion from day 1; every future change gets a migration test (drift's `schemaAt` golden tests).
- **Seed data**: run on first launch inside a transaction; localized seed names come from ARB-adjacent JSON so l10n can swap them later.
- **Performance**: lists are small (<500 items) — no pagination needed; still use `ListView.builder`, const tiles, and keys everywhere; Drift streams already diff at query level.
- **Wakelock**: `wakelock_plus`, enable on shop-mode enter, always disable on dispose (guard against exceptions).
- **Deep link import safety**: payload is gzip+base64 JSON, size-capped (~10KB), schema-validated before preview; reject anything malformed with friendly error (never crash on hostile input — validate at boundary per repo rules).

---

## 9. Testing Plan (per repo rules: TDD, 80%+)

- **Unit (pure Dart)**: item parser (30+ cases), autocomplete ranking, budget math, dedupe-on-add logic, deep link codec roundtrip + hostile payloads, backup serialize/parse.
- **DB tests (drift, in-memory)**: every repository method; cascade deletes; catalog upsert rules; trip archival transaction; migration goldens.
- **Widget tests**: QuickAddBar (type→suggest→add), ItemTile gestures (check/swipe/undo), ListCard progress, ShopMode running total reacts to checks, empty states render.
- **Integration test (one happy path)**: create list → add 5 items (incl. bulk paste) → shop mode → check all → finish trip → verify trip + catalog rows.
- **Golden tests** (optional but cheap): ItemTile and ListCard in light/dark.

CI: GitHub Actions — `flutter analyze`, `flutter test --coverage`, coverage gate 80% on `lib/` (exclude generated files).

---

## 10. Milestones (build order for the coding agent)

1. **M0 — Scaffold (½ day)**: project, lints, CI, theme, router, Drift setup + tables + seed, freezed models, folder structure. App boots to empty Home.
2. **M1 — Core CRUD (2–3 days)**: Home (list CRUD, reorder, pin, archive), List detail (add via quick-add w/ autocomplete, check, swipe delete+undo, edit sheet, sort modes, checked section), categories manage screen. *Tests alongside, parser TDD first.*
3. **M2 — Smart layer (1–2 days)**: catalog learning + suggestions chips, dedupe-on-add, bulk paste, voice add (flagged), budget + est. totals.
4. **M3 — Shop mode + trips (1–2 days)**: shop mode screen, price pad, trip summary/archive, wakelock.
5. **M4 — Share/import + templates + search + settings + backup (1–2 days)**.
6. **M5 — Polish pass (1–2 days)**: animations, haptics, empty states, onboarding, dark-mode audit, large-font audit, app icon + splash (flutter_native_splash).
7. **M6 — Release (½ day)**: versioning, ProGuard/R8 ok, Play listing assets (screenshots via integration test screenshots), privacy policy page, closed testing track.

Definition of done per milestone: tests green, `flutter analyze` clean, dark mode verified, no TODOs left in code.

---

## 11. Play Store Release Checklist

- App id: `com.saad.cartlist` (confirm). Signing: new upload keystore, stored in password manager + keychain, never in repo.
- Target latest SDK, min SDK 24. `flutter build appbundle --release`.
- Listing: 4–8 screenshots (Home, List, Shop mode, dark mode), feature graphic, short/full description, category "Shopping", content rating questionnaire (Everyone), Data Safety form ("no data collected/shared" — true, it's offline).
- Privacy policy: static page (host on abdullahsaad5.github.io `/cartlist/privacy`).
- Closed testing (self + friends) ≥14 days per Play's new-personal-account rule if applicable → production.

---

## 12. Risks / Open Decisions

- Final app name + id before first upload (irreversible).
- Voice add quality varies by device — keep behind flag, degrade gracefully to keyboard.
- Widget (v1.1) needs Android-side glue (Kotlin broadcast receiver) — the one place Flutter choice costs extra work; scoped and known.
- If shared-lists demand appears early, v2 Firebase plan gets its own spec; do not smuggle networking into v1.
