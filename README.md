# E-Commerce Master Layer — dbt Project

A dbt project that implements a canonical master data layer for an e-commerce domain,
built on top of raw data landed by a Fivetran-like ingestion tool.

---

## Stack

- **dbt-core** 1.10.20
- **dbt-duckdb** 1.10.0 — local development (no setup required)
- **dbt-snowflake** 1.10.0 — production target
- **Python** 3.9+

---

## Setup & Running

### 1. Create and activate virtual environment
```bash
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
```

### 2. Install dependencies
```bash
pip install -r requirements.txt
```

### 3. Configure environment (optional)

Copy the example env file and fill in your values:
```bash
cp .env.example .env
```

By default the project runs on **DuckDB locally** with no credentials needed.
To use Snowflake, set `DBT_TARGET=snowflake` and fill in the Snowflake variables.

### 4. Run the pipeline
```bash
# Load raw data
dbt seed --profiles-dir .

# Run all models
dbt run --profiles-dir .

# Run all tests
dbt test --profiles-dir .
```

### Switching to Snowflake
```bash
cp .env.example .env
# Edit .env with your Snowflake credentials and set DBT_TARGET=snowflake
source .env

dbt seed --profiles-dir .
dbt run --profiles-dir .
dbt test --profiles-dir .
```

---

## Project Structure
```
ecommerce_master/
├── profiles.yml                          # Multi-target profile (DuckDB + Snowflake)
├── .env.example                          # Environment variable template
├── requirements.txt                      # Python dependencies
├── dbt_project.yml                       # dbt project config
├── models/
│   ├── staging/
│   │   ├── stg_ecommerce.sql             # Cleans and renames raw source columns
│   │   └── staging.yml                   # Staging tests
│   └── master/
│       ├── master_users.sql              # Deduplicated users with MD5 key
│       ├── master_products.sql           # Normalized products with MD5 key
│       ├── master_orders.sql             # Canonicalized orders, USD + GBP prices
│       └── master.yml                    # Master tests
└── seeds/
    └── ecommerce_dataset_updated.csv     # Raw source (simulates raw schema)
```

---

## Assumptions

1. **Currency:** Source prices are labelled in `Rs.` (Rupees) but treated as USD
   per exercise instructions. Conversion to GBP uses a fixed rate of 0.75.
2. **Single source table:** The dataset has one flat CSV combining users, products,
   and orders. In production these would be separate source tables landed by Fivetran.
3. **Order identity:** A transaction is uniquely identified by
   `(user_id, product_id, purchase_date)`. No explicit order ID exists in the source.
4. **No status transitions:** The dataset has no order status field.
   Late-arriving updates are addressed in the design notes below.
5. **DuckDB schema naming:** DuckDB prefixes custom schemas with the database name
   (`main_staging`, `main_master`). This is adapter behaviour and does not affect
   model logic — on Snowflake schemas will be `staging` and `master` as expected.

---

## Design Choices

### Multi-target profiles.yml (no ~/.dbt required)
`profiles.yml` lives in the project root and is passed via `--profiles-dir .`.
This means anyone can clone the repo and run immediately without creating
`~/.dbt/profiles.yml`. Credentials are never hardcoded — all sensitive values
are read from environment variables via `env_var()`.

### Deterministic keys (MD5)
All master entities use `md5(source_id)` as their surrogate key. This ensures:
- The same source record always produces the same master key (idempotent)
- Keys are consistent across full refreshes and backfills
- Foreign keys in `master_orders` are computed with the same function, guaranteeing
  referential integrity without joins at build time

### Layered architecture (staging → master)
- **Staging** (`view`): light rename/cast layer, no business logic
- **Master** (`table`): deduplicated, enriched, ready for consumption

### Category normalisation
`lower(trim(category))` in `master_products` prevents duplicate categories
caused by inconsistent capitalisation or whitespace in the source.

### Deduplication strategy
- `master_users`: `distinct` on `user_id` — each user appears once
- `master_products`: `row_number() over (partition by product_id order by purchase_date desc)`
  — keeps the most recent product attributes
- `master_orders`: `row_number() over (partition by user_id, product_id, purchase_date)`
  — removes exact duplicates while preserving all distinct transactions

---

## Design Notes (no implementation required)

### SCD2 — best candidates in master_products
The following attributes are most likely to change over time and benefit from
SCD2 tracking:
- `price_usd` — prices change frequently
- `discount_pct` — promotional discounts are temporary
- `category` — products can be recategorised

Implementation would add `valid_from`, `valid_to`, and `is_current` columns,
using dbt snapshots (`strategy: timestamp` or `strategy: check`).

### Late-arriving updates (status transitions, cancellations, refunds)
In a production pipeline with order status transitions the recommended approach is:
1. **Append-only raw table** — never mutate source records; each status change
   arrives as a new row with a timestamp
2. **`row_number()` deduplication** on `(order_id, updated_at desc)` in staging
   to surface the latest status per order
3. **Incremental models** (`materialized: incremental`, `unique_key: order_master_id`)
   in master to merge late arrivals without full table rebuilds
4. **Refunds** modelled as a separate `master_refunds` entity referencing
   `order_master_id`, keeping the original order record immutable

### Metrics for freshness and anomaly detection
| Metric | Description | Alert threshold |
|---|---|---|
| `max(dbt_updated_at)` per model | Data freshness | > 1 hour behind schedule |
| Row count delta vs previous run | Volume anomaly | ± 20% change |
| Null rate per critical column | Data quality drift | > 0% on PK/FK columns |
| Distinct category count | Schema drift | Any new unexpected value |
| Order count per day | Business anomaly | > 3σ from 30-day average |

These would be implemented via dbt's `freshness` blocks on sources and
custom Elementary or dbt_utils tests.

---

## What I Would Extend Next

Given double the time, I would prioritise:

1. **Currency seed** — a `seeds/exchange_rates.csv` with daily USD→GBP rates
   joined on `purchase_date` instead of a fixed 0.75 rate
2. **Incremental models** — replace full table refreshes with
   `materialized: incremental` on `master_orders` for production scalability
3. **GDPR delete handling** — a `deleted_users` seed/table checked in
   `master_users` to null out PII fields on matched `user_source_id`
4. **dbt Elementary** — open-source observability package for automated
   anomaly detection and a data health dashboard
5. **Reusable macros** — `generate_surrogate_key()` macro to standardise
   MD5 key generation across all models