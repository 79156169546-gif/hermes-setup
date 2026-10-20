# asyncpg Types, Filtering, and Live-Schema Pitfalls

Depth for the `postgres-backed-api` skill. Read this when binding query
parameters, writing dynamic filters, or diagnosing a type error that only
appears on one route.

## Type mapping

asyncpg binds Python types to Postgres types by inspection — it does not
coerce loosely. Pass the type the column expects:

| Python | Postgres | Use for |
|---|---|---|
| `str` | `text` | names, codes, free text |
| `int` | `bigint` | ids, quantities |
| `Decimal` | `numeric` | money — never `float` for money |
| `datetime.date` | `date` | date filters and date-only columns |
| `datetime.datetime` | `timestamptz` | timestamps |
| `bool` | `boolean` | flags |
| `list[int]` | `int[]` | `WHERE id = ANY($1::int[])` |
| `None` | `NULL` | explicit nulls |

### The failure mode

Binding a `str` where a date is expected does not produce a cast error from
Postgres — asyncpg tries to convert on the Python side and raises:

```
DataError: invalid input for query argument $1: '2026-10-20'
('str' object has no attribute 'toordinal')
```

The message points at the query argument, not at the missing conversion, so
it reads like a SQL bug. The fix is at the call site: parse the string into a
`datetime.date` before it becomes a query parameter.

```python
from datetime import date

def _parse_date(value: str) -> date:
    """Разбирает дату ГГГГ-ММ-ДД. Драйвер требует объект date, не строку."""
    try:
        return date.fromisoformat(value.strip())
    except ValueError as exc:
        raise HTTPException(
            status_code=422, detail=f"Некорректная дата: {value}"
        ) from exc
```

A `::date` cast in the SQL does not save you — asyncpg binds the parameter
before Postgres ever sees the cast.

## Dynamic filters with a parameter list

Build the `WHERE` clause and the parameter list together. The placeholder
number is the parameter's position, so every append must update both.

```python
conditions: list[str] = []
params: list[object] = []

if order_status:
    params.append(order_status)
    conditions.append(f"status = ${len(params)}")

if date_from:
    params.append(_parse_date(date_from))
    conditions.append(f"created_at >= ${len(params)}::date")

if date_to:
    params.append(_parse_date(date_to))
    conditions.append(f"created_at < (${len(params)}::date + interval '1 day')")

if query:
    params.append(f"%{query.strip()}%")
    idx = len(params)
    conditions.append(
        "(order_number ILIKE $"
        f"{idx} OR customer_name ILIKE $"
        f"{idx} OR COALESCE(phone, '') ILIKE $"
        f"{idx})"
    )

where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
```

Two details that matter:

- **Upper bound for an inclusive end date.** `created_at <= '2026-10-20'`
  excludes anything timestamped after midnight on that day. Use
  `< (date + interval '1 day')` so the whole day is included.
- **One parameter reused across several columns.** Reuse the same index
  (`$3`) rather than adding a new placeholder per column — the count stays
  correct and the plan stays simple.

### Ordering

Never interpolate a user value into `ORDER BY`. Map the input to a fixed set
of SQL fragments:

```python
order_by = {
    "newest": "created_at DESC",
    "oldest": "created_at ASC",
    "night_first": "is_night_order DESC, created_at DESC",
}.get(sort, "created_at DESC")
```

The mapping's default branch absorbs any unknown value, so a hostile `sort`
value can never reach the SQL.

## Verifying a live schema

`information_schema` is the source of truth for what a database actually has.
Run this after every migration:

```python
rows = await conn.fetch(
    """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_name = $1 AND table_schema = 'public'
    ORDER BY ordinal_position
    """,
    table,
)
for row in rows:
    print(row["column_name"], row["data_type"], row["column_default"])
```

To see which tables exist:

```python
rows = await conn.fetch(
    """
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public' ORDER BY table_name
    """
)
```

## Live-schema gotcha: CREATE TABLE IF NOT EXISTS

`CREATE TABLE IF NOT EXISTS` is a no-op when the table exists. The entire
definition — including any columns added since — is skipped, so the migration
script succeeds while the new column is absent. The symptom is a runtime 500
on whichever route touches the missing column, long after the migration ran.

Always accompany it with explicit column additions:

```sql
CREATE TABLE IF NOT EXISTS orders (
    id            SERIAL PRIMARY KEY,
    order_number  TEXT UNIQUE NOT NULL,
    ...
);

-- Columns added after the table shipped: CREATE TABLE above will not add them.
ALTER TABLE orders ADD COLUMN IF NOT EXISTS has_on_order BOOLEAN NOT NULL DEFAULT FALSE;
```

For a column with a `NOT NULL` constraint on a table that already has rows,
give it a `DEFAULT` in the same statement — otherwise the existing rows
violate the constraint and the `ALTER` fails.

## Snapshotting mutable state

When an order line points at a catalog row, copy the values that mattered at
order time into the line:

- store `price` on the line, not just the product id;
- store the supplier lead time on the line, not just a live lookup;
- store a flag on the order itself (`has_on_order`) so list views can filter
  without joining.

The reason is that the catalog is edited after the fact — a price change, a
stock correction, a new lead time. A line that reads those values live
silently rewrites what the customer agreed to, and the order total stops
matching the items it was computed from.
