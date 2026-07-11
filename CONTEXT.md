# CONTEXT.md — Tokri domain glossary

Use these exact terms in code, tests, issues, and docs.

## Core concepts

- **List** — a shopping list (Groceries, Hardware, Party…). Has name, color, icon, optional **budget**, optional linked **store**. Can be pinned, reordered, archived, duplicated.
- **Item** — one line on a list: name, **quantity** + **unit**, optional price (integer minor units), optional note, **category**, priority flag, checked state. Checked items collapse into the **done section**.
- **Category** — aisle-style grouping (Produce, Dairy, Bakery…). Drives sort order in **shop mode**. User-manageable.
- **Unit** — pcs, kg, g, L, ml, pack, dozen, custom.
- **Catalog** — the learned dictionary of everything the user has ever added: canonical item name, default unit/category, add count, last-added timestamp. Feeds **suggestions**.
- **Suggestion** — a catalog entry ranked by frequency + recency, surfaced in the **quick-add bar** as you type (autocomplete) and as chips.
- **Quick-add bar** — the always-visible entry field at the bottom of a list. Repeated adds without dismissing the keyboard.
- **Bulk add** — multiline paste parsed into items. The **parser** handles leading quantity patterns (`2x`, `2 `, `500g `) and splits on newlines/commas/"and". Pure logic, TDD'd.
- **Voice add** — dictation routed through the same parser. Feature-flagged.
- **Shop mode** — full-screen in-store UI: category-sorted, huge touch targets, screen kept awake, price pad for entering actual prices, running total vs budget.
- **Trip** — one completed shop: when a list is finished in shop mode, its checked items + prices archive as a trip (history, spend per trip).
- **Price memory** — last known price of a catalog item per store; pre-fills estimates and the price pad.
- **Template** — a saved list shape; instantiating creates a fresh list with all items unchecked.
- **Store** — a named shop, optionally linked to a list; scopes price memory.
- **Export / import** — v1 sharing: plain-text format + QR deep link. No network.

## Avoid

- "Todo" / "task" — items are shopping items, not todos.
- "Sync" — v1 has none; say **export/import**.
- Floating-point money — prices are integer minor units (paisa), like ledgr.
