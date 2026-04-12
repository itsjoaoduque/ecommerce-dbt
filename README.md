# E-Commerce Master Layer — dbt Project

A dbt project that implements a canonical master data layer for an e-commerce domain,
built on top of raw data landed by a Fivetran-like ingestion tool.

Supports two targets out of the box:
- **DuckDB** — local development, no credentials needed
- **Snowflake** — production target, configured via environment variables

> For a detailed breakdown of layer design, key decisions, and scalability considerations see [ARCHITECTURE.md](./ARCHITECTURE.md).
> For backfill strategy, replay guarantees, and incremental model guidance see [BACKFILL.md](./BACKFILL.md).

---

## Stack

| Tool | Version | Purpose |
|---|---|---|
| dbt-core | 1.10.20 | Transformation framework |
| dbt-duckdb | 1.10.0 | Local development target |
| dbt-snowflake | 1.10.0 | Production target |
| Python | 3.9+ | Runtime |

---

## Quick Start

### 1. Clone & create a virtual environment
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Configure credentials (Snowflake only)
```bash
cp .env.example .env
# Fill in your Snowflake values in .env
```

### 3. Run the pipeline

Use `make` from the project directory:

```bash
# DuckDB (local, no credentials needed)
make run_ecommerce_duckdb

# Snowflake (requires .env)
make run_ecommerce_snowflake
```

Each command will:
1. Run `scripts/clean_csv.py` to sanitise CSV column names
2. Load the seed file into the target warehouse (`dbt seed`)
3. Build all models (`dbt run`)

### 4. Run snapshots (SCD2)

```bash
# DuckDB
dbt snapshot --profiles-dir ./profiles --target duckdb

# Snowflake
source .env && dbt snapshot --profiles-dir ./profiles --target snowflake
```

> The Python script simulates the sanitisation that would normally happen at ingestion time — in production, Fivetran or a custom connector would land data with clean column names.

---

## Snowflake Setup (first time only)

Before running against Snowflake, a one-time setup is required to create the
database, schemas, warehouse, role, and user that dbt expects.

Run `scripts/snowflake_setup.sql` in a Snowflake worksheet **as ACCOUNTADMIN**:

```sql
-- 1. Open scripts/snowflake_setup.sql
-- 2. Run the entire script
```

Once done, fill in your `.env` with the credentials from the setup script.

---

## Make Commands

| Command | Description |
|---|---|
| `make run_ecommerce_duckdb` | Prepare, seed and run all models on DuckDB |
| `make run_ecommerce_snowflake` | Prepare, seed and run all models on Snowflake |
| `make test_duckdb` | Run all dbt tests on DuckDB |
| `make test_snowflake` | Run all dbt tests on Snowflake |
| `make test_all` | Run all dbt tests on both targets |

---

## Environment Variables

All sensitive values are read from a `.env` file (never hardcoded). Create one from the example:

```bash
cp .env.example .env
```

| Variable | Description |
|---|---|
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier |
| `SNOWFLAKE_USER` | Snowflake username |
| `SNOWFLAKE_PASSWORD` | Snowflake password |
| `SNOWFLAKE_ROLE` | Role (default: `TRANSFORMER`) |
| `SNOWFLAKE_DATABASE` | Database (default: `ECOMMERCE`) |
| `SNOWFLAKE_WAREHOUSE` | Warehouse (default: `COMPUTE_WH`) |
| `DBT_TARGET` | Active target — `duckdb` or `snowflake` (default: `duckdb`) |

---

## Project Structure

```
ecommerce_master/
├── Makefile                                 # Convenience commands
├── ARCHITECTURE.md                          # Layer design, key decisions, scalability notes
├── BACKFILL.md                              # Backfill strategy, replay guarantees, incremental guidance
├── dbt_project.yml                          # dbt project config
├── profiles/
│   └── profiles.yml                         # Multi-target profile (DuckDB + Snowflake)
├── requirements.txt                         # Python dependencies
├── scripts/
│   ├── clean_csv.py                         # Sanitises CSV column names before seeding
│   └── snowflake_setup.sql                  # One-time Snowflake setup (DB, schemas, role, user)
├── macros/
│   ├── parse_date.sql                       # Cross-database date parsing macro
│   └── dateadd.sql                          # Cross-database date arithmetic macro
├── snapshots/
│   └── products_snapshot.sql               # SCD2 snapshot for master_products
├── models/
│   ├── staging/
│   │   ├── stg_ecommerce.sql                # Cleans and renames raw source columns
│   │   └── staging.yml                      # Staging tests & documentation
│   └── master/
│       ├── master_users.sql                 # Deduplicated users with MD5 surrogate key
│       ├── master_products.sql              # Normalised products with MD5 surrogate key
│       ├── master_orders.sql                # Incremental orders model with USD & GBP prices
│       └── master.yml                       # Master tests & documentation
└── seeds/
    ├── ecommerce_dataset_updated.csv        # Original raw source (disabled)
    └── ecommerce_dataset_updated_clean.csv  # Sanitised source (active)
```

---

## Data Flow

```
seeds/ecommerce_dataset_updated_clean.csv
        │
        ▼
  stg_ecommerce  (view)      ← rename, cast, parse dates
        │
        ├──────────────────┬──────────────────┐
        ▼                  ▼                  ▼
  master_users       master_products    master_orders
    (table)             (table)         (incremental)
                           │
                           ▼
                   products_snapshot    ← SCD2 history
                     (snapshot)
```

---

## Cross-Database Compatibility

Models use custom macros that dispatch to the correct function per adapter:

| Macro | DuckDB | Snowflake |
|---|---|---|
| `parse_date` | `strptime(col, fmt)::date` | `TO_DATE(col, fmt)` |
| `date_subtract_days` | `col - INTERVAL 'N' DAY` | `DATEADD('day', -N, col)` |

To add support for another adapter, add a `<adapter>__<macro_name>` implementation
in the corresponding macro file.

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

### Multi-target profiles (no `~/.dbt` required)
`profiles/profiles.yml` is passed via `--profiles-dir ./profiles`.
Anyone can clone the repo and run immediately without touching `~/.dbt/profiles.yml`.
Credentials are never hardcoded — all sensitive values come from environment variables.

### Deterministic keys (MD5)
All master entities use surrogate keys computed via `generate_surrogate_key()`. This ensures:
- The same source record always produces the same master key (idempotent)
- Keys are consistent across full refreshes and backfills
- Foreign keys in `master_orders` are computed with the same function, guaranteeing
  referential integrity without joins at build time

### Layered architecture (staging → master → snapshots)
- **Staging** (`view`): light rename/cast layer, no business logic
- **Master** (`table` or `incremental`): deduplicated, enriched, ready for consumption
- **Snapshots**: SCD2 history for slowly changing dimensions

### Incremental model — master_orders
`master_orders` uses `materialized: incremental` with a 3-day lookback window:
```sql
where purchase_date >= (
    select date_subtract_days(max(purchase_date), 3)
    from {{ this }}
)
```
This handles late-arriving records without reprocessing the full history.
Use `--full-refresh` to rebuild from scratch when needed.

### SCD2 — products_snapshot
`products_snapshot` tracks historical changes to `price_usd`, `discount_pct`, and `category`
using `strategy: check`. Each time one of these values changes, the old record is closed
(`dbt_valid_to` is set) and a new record is inserted (`dbt_valid_to = null`).

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

## Design Notes

### Late-arriving updates (status transitions, cancellations, refunds)
The dataset has no order status field. For a production pipeline with status transitions:
1. **Append-only raw table** — never mutate source records; each status change
   arrives as a new row with a timestamp
2. **`row_number()` deduplication** on `(order_id, updated_at desc)` in staging
   to surface the latest status per order
3. **Incremental model** — `master_orders` already uses incremental materialisation
   with a 3-day lookback to catch late arrivals
4. **Refunds** modelled as a separate `master_refunds` entity referencing
   `order_master_id`, keeping the original order record immutable

### Metrics for freshness and anomaly detection
| Metric | Description | Alert threshold |
|---|---|---|
| `max(record_updated_at)` per model | Data freshness | > 1 hour behind schedule |
| Row count delta vs previous run | Volume anomaly | ± 20% change |
| Null rate per critical column | Data quality drift | > 0% on PK/FK columns |
| Distinct category count | Schema drift | Any new unexpected value |
| Order count per day | Business anomaly | > 3σ from 30-day average |

These would be implemented via dbt's `freshness` blocks on sources and dbt Elementary.

---

## What I Would Extend Next

1. **Currency seed** — a `seeds/exchange_rates.csv` with daily USD→GBP rates
   joined on `purchase_date` instead of a fixed 0.75 rate
2. **GDPR delete handling** — a `deleted_users` seed/table checked in
   `master_users` to null out PII fields on matched `user_source_id`
3. **dbt Elementary** — open-source observability package for automated
   anomaly detection and a data health dashboard
4. **CI/CD** — GitHub Actions pipeline running `dbt run` + `dbt test` + `dbt snapshot`
   against an ephemeral Snowflake schema on every pull request