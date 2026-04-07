# Architecture Note

## Layer Design

```
┌─────────────────────────────────────────────────────┐
│                   Data Sources                      │
│         (Fivetran → Snowflake raw schema)           │
└────────────────────────┬────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│              Staging Layer (views)                  │
│  - Rename and cast columns                          │
│  - Parse dates                                      │
│  - No business logic                                │
└────────────────────────┬────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│               Master Layer (tables)                 │
│  - Deduplicated canonical entities                  │
│  - Deterministic surrogate keys (MD5)               │
│  - Referential integrity enforced via dbt tests     │
│  - Monetary hygiene (USD + GBP)                     │
└────────────────────────┬────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│           Consumers (BI, Analytics, ML)             │
└─────────────────────────────────────────────────────┘
```

---

## Key Design Decisions

### Surrogate Keys (MD5)
All master entities use deterministic MD5 keys computed from source IDs. This guarantees stability across full refreshes and backfills — downstream consumers are never broken by re-ingestion events.

### Staging as Views
Staging models are materialised as views to avoid redundant storage. They act as a lightweight, cost-free transformation layer between raw and master.

### Master as Tables
Master models are materialised as tables for query performance. These are the primary consumption layer and are expected to be queried frequently by BI tools.

### Cross-Database Compatibility
A `parse_date` macro dispatches to the correct date function per adapter (`strptime` for DuckDB, `TO_DATE` for Snowflake). This keeps all models adapter-agnostic and allows local development with DuckDB while targeting Snowflake in production.

---

## Scalability Considerations

| Concern | Current approach | Production recommendation |
|---|---|---|
| Full refresh cost | Acceptable at 3K rows | Incremental models on `master_orders` |
| Late-arriving data | Not applicable (static dataset) | Append-only raw + incremental merge |
| Currency conversion | Fixed 0.75 rate | Daily exchange rate seed joined on date |
| Schema evolution | Manual `accepted_values` tests | dbt Elementary for automated drift detection |
| GDPR compliance | Not implemented | Nullify PII on `deleted_users` match |

---

## What Was Intentionally Left Out

- **SCD2** — best candidates identified (`price_usd`, `discount_pct`, `category`) but not implemented per exercise scope
- **CI/CD** — out of scope per exercise instructions
- **dbt docs** — out of scope per exercise instructions
- **Incremental models** — full refresh is acceptable at this dataset size