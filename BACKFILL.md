# Backfill Strategy and Replay

## Current Behaviour

All models use `materialized: table` (full refresh). This means every `dbt run`
rebuilds all tables from scratch, so backfill is implicit — re-running the
pipeline always produces a correct, deterministic result.

Deterministic MD5 surrogate keys guarantee that re-processed records always
produce the same keys, preventing duplicates or broken references downstream.

---

## Backfill Scenarios

### 1. Bug fix in transformation logic
A column was computed incorrectly (e.g. wrong GBP conversion rate).

**Solution:** Fix the model and run:
```bash
dbt run --profiles-dir ./profiles
```
All tables are rebuilt from the seed. No additional steps required.

---

### 2. New column added to a master model
A new attribute needs to be back-populated for all historical records.

**Solution:** Add the column to the model and run a full refresh:
```bash
dbt run --profiles-dir ./profiles --full-refresh
```

---

### 3. Incremental models (future state)
When `master_orders` is migrated to `materialized: incremental`, a full
backfill would require:

```bash
# Force full rebuild of a specific incremental model
dbt run --profiles-dir ./profiles --full-refresh --select master_orders

# Or rebuild the entire pipeline
dbt run --profiles-dir ./profiles --full-refresh
```

The `--full-refresh` flag tells dbt to drop and recreate the table instead
of merging only new records.

---

### 4. Selective replay (single entity)
To replay only one entity without touching the others:

```bash
dbt run --profiles-dir ./profiles --select master_orders
```

To replay an entity and all its upstream dependencies:

```bash
dbt run --profiles-dir ./profiles --select +master_orders
```

---

## Replay Guarantees

| Property | Guarantee |
|---|---|
| Idempotency | Re-running produces identical results |
| Key stability | MD5 keys never change for the same source record |
| Referential integrity | FK tests validate consistency after every run |
| No data loss | Seed file is the source of truth — always available for replay |