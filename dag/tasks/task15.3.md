

# Task 15.3 — Backfill & Sync Codes (work_center_code / uom_code)

## 1. Objective
Populate all newly added `*_code` columns introduced in Task 15.2 by synchronizing them with their master tables:

- `work_center_code` ← from `work_center.code`
- `uom_code` / `default_uom_code` ← from `unit_of_measure.code`

This step is **non-destructive**, **idempotent**, and prepares the system for full ID → CODE migration.

---

## 2. Scope of Backfill

### Work Center–related tables (6)
| Table | Column | Source |
|-------|---------|-----------|
| routing_node | work_center_code | work_center.code |
| job_task | work_center_code | work_center.code |
| job_ticket | work_center_code | work_center.code |
| work_center_team_map | work_center_code | work_center.code |
| work_center_behavior_map | work_center_code | work_center.code |
| routing_step (legacy V1) | work_center_code | work_center.code |

### Unit of Measure–related tables (8)
| Table | Column | Source |
|--------|------------|------------|
| product | default_uom_code | unit_of_measure.code |
| bom_line | uom_code | unit_of_measure.code |
| material | default_uom_code | unit_of_measure.code |
| material_lot | uom_code | unit_of_measure.code |
| stock_item | uom_code | unit_of_measure.code |
| stock_ledger | uom_code | unit_of_measure.code |
| purchase_rfq_item | uom_code | unit_of_measure.code |
| mo | uom_code | unit_of_measure.code |

---

## 3. Backfill Strategy

### 3.1 Work Center Sync
```
UPDATE <table> t
LEFT JOIN work_center wc ON wc.id_work_center = t.id_work_center
SET t.work_center_code = wc.code
WHERE t.work_center_code IS NULL;
```

Tables:
- routing_node
- job_task
- job_ticket
- work_center_team_map
- work_center_behavior_map
- routing_step (legacy)

### 3.2 UOM Sync
```
UPDATE <table> t
LEFT JOIN unit_of_measure u ON u.id_unit = t.id_uom
SET t.uom_code = u.code
WHERE t.uom_code IS NULL;
```

For product/material default UOM:
```
UPDATE product p
LEFT JOIN unit_of_measure u ON u.id_unit = p.default_uom
SET p.default_uom_code = u.code
WHERE p.default_uom_code IS NULL;
```

---

## 4. Migration File Summary

Migration file created in Task 15.3:
- `2025_12_wc_uom_backfill_codes.php`
- Contains 14 UPDATE statements (idempotent)
- Includes IF EXISTS checks for all tables
- Logs rows affected for debugging

---

## 5. Testing Instructions

1. Run migration on DEV
2. Check 3 rows per table:
   - A record with id_work_center → should have work_center_code
   - A record with id_uom → should have uom_code
3. Run migration twice to confirm idempotency
4. Test production flow:
   - Create MO → ensure uom_code populated
   - Create Job Ticket → ensure work_center_code populated

---

## 6. Expected Result

After Task 15.3:

- All tables contain both legacy IDs **and** new CODE values
- Safe to begin Task 15.4 (API/JS refactor to CODE-first)
- No breaking changes in existing flows

---

**Task 15.3 Completed — System Ready for Task 15.4**