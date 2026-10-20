# Catalog Search & Filters — implementation pattern

React + Tailwind reference implementation. Shapes are generic; the field
names map onto any catalog API.

## Normalized matching

```js
// Normalize before comparing: lowercase + strip everything but letters/digits.
function normalize(value) {
  return (value ?? '').toLowerCase().replace(/[^a-zа-яё0-9]/gi, '')
}

function matchesQuery(product, query) {
  const needle = normalize(query)
  if (!needle) return true
  return [
    product.name,
    product.brand,
    product.sku,          // article number — customers type these a lot
    product.category,
    product.description,
  ]
    .map(normalize)
    .some((value) => value.includes(needle))
}
```

Searching only `name` is the most common miss: customers type the brand
("Brembo") or the article number more often than the full product title.

## Deriving filter options from data

```js
const categories = useMemo(() => {
  const map = new Map()
  products.forEach((item) => {
    if (!item.category) return
    map.set(item.category, (map.get(item.category) ?? 0) + 1)
  })
  return [...map.entries()].sort((a, b) => a[0].localeCompare(b[0], 'ru'))
}, [products])

const brands = useMemo(() => {
  const set = new Set()
  products.forEach((item) => {
    if (item.brand) set.add(item.brand)
  })
  return [...set].sort((a, b) => a.localeCompare(b, 'ru'))
}, [products])
```

Never hardcode the category list — it changes with the inventory, and a
stale option filters the customer to zero results for no visible reason.

## One filter memo

```js
const visibleProducts = useMemo(() => {
  let list = products
  if (stockFilter === 'stock') list = list.filter((i) => i.in_stock)
  else if (stockFilter === 'order') list = list.filter((i) => i.is_on_order && !i.in_stock)
  if (query.trim()) list = list.filter((i) => matchesQuery(i, query))
  if (category) list = list.filter((i) => i.category === category)
  if (brand) list = list.filter((i) => i.brand === brand)
  return sortProducts(list, sort)
}, [products, stockFilter, query, category, brand, sort])

const activeFilters =
  (query.trim() ? 1 : 0) +
  (category ? 1 : 0) +
  (brand ? 1 : 0) +
  (stockFilter !== 'all' ? 1 : 0)
```

One memo drives both the grid and the counter, so the count can never
disagree with what is rendered.

## Sort helper

```js
export const SORTS = [
  { id: 'popular', title: 'По популярности' },
  { id: 'price_asc', title: 'Сначала дешевле' },
  { id: 'price_desc', title: 'Сначала дороже' },
  { id: 'discount', title: 'По скидке' },
  { id: 'name', title: 'По названию' },
]

export function sortProducts(items, sortId) {
  const list = [...items]
  switch (sortId) {
    case 'price_asc':  return list.sort((a, b) => a.price - b.price)
    case 'price_desc': return list.sort((a, b) => b.price - a.price)
    case 'discount':   return list.sort((a, b) => discountFor(b) - discountFor(a) || a.price - b.price)
    case 'name':       return list.sort((a, b) => a.name.localeCompare(b.name, 'ru'))
    default:
      // Popular: in-stock first, then biggest discount, then cheapest.
      return list.sort((a, b) =>
        Number(b.in_stock) - Number(a.in_stock) ||
        discountFor(b) - discountFor(a) ||
        a.price - b.price)
  }
}
```

The default sort surfaces purchasable items first — a customer scrolling a
catalog should not hit unavailable items before orderable ones.

## Filter button with active-count badge

```jsx
<button
  type="button"
  data-testid="catalog-filters-toggle"
  onClick={() => setFiltersOpen((v) => !v)}
  className={`relative flex items-center gap-1.5 rounded-xl border px-3.5 py-3 text-sm font-medium transition ${
    filtersOpen || activeFilters
      ? 'border-accent bg-accent-soft text-accent-strong'
      : 'border-gray-200 bg-white text-gray-700 hover:bg-gray-50'
  }`}
>
  <span aria-hidden="true">⚙</span>
  <span className="hidden sm:inline">Фильтры</span>
  {activeFilters ? (
    <span
      data-testid="catalog-filters-count"
      className="flex h-5 min-w-5 items-center justify-center rounded-full bg-accent-strong px-1 text-[11px] font-bold text-white"
    >
      {activeFilters}
    </span>
  ) : null}
</button>
```

## Category chips

```jsx
<button
  type="button"
  data-testid={`catalog-chip-${name}`}
  onClick={() => setCategory(category === name ? '' : name)}
  className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition ${
    category === name
      ? 'bg-accent-strong text-white'
      : 'bg-white text-gray-600 shadow-card hover:bg-gray-50'
  }`}
>
  {name}
  <span className="ml-1.5 opacity-70">{amount}</span>
</button>
```

Toggling off on a second click is expected behaviour, not a bug.

## Empty state

```jsx
{!loading && visibleProducts.length === 0 && !loadError ? (
  <div className="card p-8 text-center">
    <p className="text-4xl">🔍</p>
    <p className="mt-2 text-sm font-semibold text-gray-900">Ничего не нашлось</p>
    <p className="mt-1 text-sm text-gray-500">
      {query.trim()
        ? `По запросу «${query.trim()}» деталей нет. Попробуйте другое слово или сбросьте фильтры.`
        : 'Под текущие фильтры не подходит ни одна деталь. Сбросьте фильтры, чтобы увидеть весь каталог.'}
    </p>
    {activeFilters ? (
      <button type="button" onClick={resetFilters} className="btn-secondary mt-4">
        Сбросить фильтры
      </button>
    ) : null}
  </div>
) : null}
```

## Contact header

The store details arrive from one endpoint:

```js
const [store, setStore] = useState(null)
useEffect(() => {
  fetchStoreInfo().then(setStore).catch(() => setStore(null))
}, [])
```

Dark contact strip (desktop) — phone and address are links:

```jsx
<a
  href={store?.phone_href ?? 'tel:+79610108001'}
  data-testid="header-phone"
  className="flex items-center gap-1.5 transition hover:text-white focus:outline-none focus:ring-2 focus:ring-orange-500"
>
  <span aria-hidden="true">📞</span>
  <span className="font-medium">{store?.phone}</span>
</a>

<a
  href={store?.maps_url}
  target="_blank"
  rel="noreferrer"
  data-testid="header-address"
  className="flex items-center gap-1.5 transition hover:text-white focus:outline-none focus:ring-2 focus:ring-orange-500"
>
  <span aria-hidden="true">📍</span>
  <span>{store?.address}</span>
</a>
```

On narrow screens the strip is hidden, so surface the same two actions as
icon buttons in the main header row — otherwise mobile users lose the
store's contact details entirely:

```jsx
<a href={store?.phone_href} data-testid="header-phone-mobile"
   className="flex h-10 w-10 items-center justify-center rounded-xl bg-accent-soft text-accent-strong md:hidden"
   aria-label={`Позвонить ${store?.phone}`}>
  <span aria-hidden="true">📞</span>
</a>
```

Repeat the contacts as tappable cards below the catalog so mobile users
scrolling the grid do not have to travel back to the header.

## Backend shape

One endpoint, so every consumer agrees:

```python
@app.get("/api/store")
async def store_info():
    return {
        "name": settings.STORE_NAME,
        "phone": settings.STORE_PHONE,          # pretty, for display
        "phone_href": settings.STORE_PHONE_HREF,  # digits only, for tel:
        "address": settings.STORE_ADDRESS,
        "maps_url": settings.STORE_MAPS_URL,
        "lat": settings.STORE_LAT,
        "lon": settings.STORE_LON,
        "rating": settings.STORE_RATING,
        "rating_count": settings.STORE_RATING_COUNT,
        "open_hour": settings.STORE_OPEN_HOUR,
        "close_hour": settings.STORE_CLOSE_HOUR,
        "is_open": is_open,
        "pickup_only": True,
    }
```

Put these in settings (env-overridable), not in the route body — the store
rebrands without a code change.

## Verification checklist

- Search for a fragment of a product name → one result, counter agrees.
- Search for a brand → that brand's items.
- Search + a conflicting category → zero results, not a stale list.
- Each filter dimension narrows on its own.
- Active-filters badge increments and decrements correctly.
- Reset restores the full catalog.
- `header-phone` href starts with `tel:` and contains only digits/`+`.
- `header-address` href points at a maps URL and opens in a new tab.
- On a narrow viewport the icon buttons are present and tappable.
