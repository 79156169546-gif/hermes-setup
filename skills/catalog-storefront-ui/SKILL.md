---
name: catalog-storefront-ui
description: "Use when building a searchable catalog or contact header."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [catalog, storefront, search, filters, sorting, header, contacts, react, tailwind]
    related_skills: [postgres-backed-api, popular-web-designs, dogfood]
---

# Catalog & Storefront UI

## When to use

Building or revising the customer-facing catalog of an online store: making
parts/detail listings easy to search, adding filter dimensions, and putting
the shop's phone and address where customers can act on them (call, open a
map). Also applies to any list-heavy storefront — tyres, accessories, a
repair shop's services list.

## Always-on rules

1. **Serve store details from one API endpoint; never hardcode them in
   components.** A single `GET /api/store` returns name, phone, phone_href,
   address, maps_url, lat/lon, rating, open/close hours and `is_open`. Both
   the header and any contact block read from it. Hardcoding a phone number
   in three JSX files guarantees two of them go stale when it changes.
2. **Phone and address are actions, not text.** Phone renders as
   `<a href="tel:...">` (digits only, no spaces/parens in the href — a
   separate `phone_href` field exists for this). Address renders as
   `<a href={maps_url} target="_blank" rel="noreferrer">`. Plain text that
   looks like a link is a failed conversion.
3. **Search matches across every field a customer might type.** Name,
   brand, article/SKU, category, description. Normalize before comparing —
   lowercase, strip non-alphanumerics — so "колодк", "Колодки" and
   "колодки" all match, and "Brembo" matches "brembo".
4. **Filter dimensions are independent and combinable.** Availability,
   category, brand. They AND together, and the result count always reflects
   every active filter.
5. **Show the number of active filters** as a badge on the filter button,
   and always provide a reset that clears all dimensions at once. A user
   who filtered down to zero results must be able to escape in one click.
6. **An empty result is a screen, not a blank.** Say what was searched and
   what was filtered, then offer "reset filters" as the primary action.
7. **Two ways to reach the same filter.** Category chips above the grid for
   one-tap browsing (with counts), plus a full filter panel for precision.
   Chips toggle off when clicked again.
8. **Every interactive element gets a `data-testid`.** Automation targets
   those, not text or CSS selectors — it makes browser verification
   deterministic and survives copy changes.
9. **Verify in a browser, with data.** After building the catalog, type in
   the search box, click each filter dimension, confirm the count changes
   and the cross-filtering behaves (a category that excludes the search
   term must yield zero, not a stale list). A green build is not a working
   filter.

## Procedure — adding search + filters to a catalog

1. Add the filter state to the page component: `query`, `category`,
   `brand`, `stockFilter`, `sort`.
2. Derive the filter option lists from the loaded data (`useMemo`), not from
   a hardcoded list — categories and brands change with the inventory.
3. Implement one `visibleProducts` memo that applies every dimension in
   sequence, then sorts the result. Keep it a single memo so the count and
   the grid can never disagree.
4. Render the search input, filter toggle button with active-count badge,
   the panel, and the category chips above the grid.
5. Put the sort dropdown beside the search field so the two "narrow" controls
   sit together and the wide sort options stay out of the panel.
6. Compute `activeFilters` as the sum of active dimensions and drive both
   the badge and the reset button's visibility from it.
7. Verify in the browser: search narrows, each dimension narrows, combined
   filters intersect, reset restores everything, empty state renders.

## Pitfalls

- **A search field that only matches `name`.** Customers type brand and
  article number at least as often as the product title. Match every
  searchable field.
- **Case- and space-sensitive comparison.** Without normalization, "Колодки"
  and "колодки" give different results and users conclude search is broken.
- **Filter chips with no count badge.** A user who filters to zero results
  cannot tell whether the filters or the data are at fault; the active
  count tells them.
- **Reset that clears only one dimension.** It reads as a broken button;
  clear all of them at once.
- **Hardcoding the phone in the header and again in the contact cards.**
  They drift apart on the first edit. One endpoint, two consumers.
- **`href="tel:+7 (961) 010-80-01"`.** The href must be digits-only
  (`tel:+79610108001`) — spaces and parentheses break dialing. Keep the
  pretty form for display and a separate normalized form for the href.
- **Screenshotting a tall page element.** An element screenshot of a long
  section times out waiting for stability. Screenshot a bounded region
  (the header, the filter panel) instead of the whole scroll area.

## References

- `references/catalog-search-and-filters.md` — the React implementation
  pattern: normalization, filter memo, sort helper, chips, badge, empty
  state, and the contact header markup.
