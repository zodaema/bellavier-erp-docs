# Task 15.6 — Hard Cleanup: Drop Legacy `id_work_center` / `id_uom` Columns

**Status:** PLANNED  
**Owner:** Bellavier ERP Core  
**Depends on:**  
- Task 15.1 — Impact Maps (DB / API / JS)  
- Task 15.2 — Add `*_code` Columns  
- Task 15.3 — Backfill `*_code`  
- Task 15.4 — Service Helpers + Dual-Mode  
- Task 15.4.2 — dag_behavior_exec / uom dual-mode  
- Task 15.5 — Hard API/JS switch to `*_code` only  

> เป้าหมายของ Task นี้คือ “ตัดสะดือ” legacy ID columns (`id_work_center`, `id_uom`, `default_uom`) ในทุกตารางที่ convert เป็น `*_code` เรียบร้อยแล้ว เพื่อให้อนาคตการ seed system value (work center, UOM) ไม่ถูกผูกกับ AUTO_INCREMENT ID อีกต่อไป

---

## 1. Scope

### 1.1 Work Center-related Tables

ตารางกลุ่มนี้ต้องลบ `id_work_center` ออกทั้งหมด และใช้ `work_center_code` แทน:

- `routing_node.id_work_center`
- `job_task.id_work_center`
- `job_ticket.id_work_center`
- `work_center_team_map.id_work_center`
- `work_center_behavior_map.id_work_center`
- `routing_step.id_work_center` (legacy V1 — เก็บไว้แค่ในฐานะ archive, แต่ structure ต้องตาม V2 principle)

### 1.2 Unit of Measure-related Tables

ตารางกลุ่มนี้ต้องลบ `default_uom` / `id_uom` และใช้ `*_uom_code` แทน:

- `product.default_uom`
- `bom_line.id_uom`
- `material.default_uom`
- `material_lot.id_uom`
- `stock_item.id_uom`
- `stock_ledger.id_uom`
- `purchase_rfq_item.id_uom`
- `mo.id_uom`

**หมายเหตุ:**  
คอลัมน์ `work_center.code` และ `unit_of_measure.code` เป็น single source of truth; `*_code` ในตารางลูกทุกตัวคือ “foreign key แบบ logical” ที่อ้างอิง code แทน ID

---

## 2. Preconditions (ต้องผ่านครบก่อนรัน migration นี้)

ก่อนรัน `2025_12_drop_wc_uom_id_columns.php` ต้องมั่นใจว่า:

1. **Code migration เสร็จแล้ว**
   - ✅ Task 15.2 — เพิ่ม `*_code` columns ในทุกตาราง
   - ✅ Task 15.3 — Backfill `*_code` จาก ID เดิม
   - ✅ Task 15.4 — Service layer รองรับ code
   - ✅ Task 15.4.2 — dag_behavior_exec / uom API ส่ง/รับ code
   - ✅ Task 15.5 — API/JS ทั้งหมดเลิกใช้ `id_work_center` / `id_uom`

2. **Data completeness**
   - ทุกตารางใน scope ต้องไม่มี `*_code` เป็น `NULL`
   - หากมี `NULL` → ห้ามรัน migration นี้ (migration จะ throw error)

3. **Routing / Work Center / UOM master**
   - master tables `work_center` และ `unit_of_measure` มี `code` ครบทุกแถว
   - ไม่มี work center หรือ UOM record ที่ใช้ในตารางลูก แต่ `code` เป็น `NULL`

---

## 3. Migration Design — `2025_12_drop_wc_uom_id_columns.php`

หลักการ:

1. **Pre-flight checks**
   - ตรวจ `*_code` ในทุกตารางใน scope
   - ถ้าพบแถวที่ `*_code IS NULL` → throw Exception และหยุด migration

2. **Drop constraints and indexes**
   - ถอด FK / INDEX ที่ผูกกับ `id_work_center` / `id_uom` ก่อน
   - ใช้ `information_schema` ตรวจสอบก่อนถอด เพื่อให้ idempotent

3. **Drop columns**
   - ใช้ `ALTER TABLE ... DROP COLUMN ...` เฉพาะเมื่อ column ยังอยู่จริง
   - ทุกคำสั่งหุ้มด้วย logic ตรวจ column existence ก่อน

4. **Idempotent & Safe**
   - รันซ้ำได้โดยไม่มี error (ไม่มี column → ไม่มีการ DROP)
   - ถ้า pre-flight check fail → migration ไม่แตะ schema

---

## 4. รายละเอียดตาราง และเงื่อนไข

### 4.1 Work Center

ตรวจ:

- `routing_node.work_center_code IS NULL`
- `job_task.work_center_code IS NULL`
- `job_ticket.work_center_code IS NULL`
- `work_center_team_map.work_center_code IS NULL`
- `work_center_behavior_map.work_center_code IS NULL`
- `routing_step.work_center_code IS NULL`

ห้ามมีสักแถวเดียว ถ้ามี → ให้ dev ไปแก้ข้อมูลก่อน (data fix) แล้วค่อย rerun migration

### 4.2 UOM

ตรวจ:

- `product.default_uom_code IS NULL` (ยกเว้นกรณี product ที่ intentional ไม่มี UOM → ให้กำหนด default policy เอง ถ้าจะปล่อยไว้)
- `bom_line.uom_code IS NULL`
- `material.default_uom_code IS NULL`
- `material_lot.uom_code IS NULL`
- `stock_item.uom_code IS NULL`
- `stock_ledger.uom_code IS NULL`
- `purchase_rfq_item.uom_code IS NULL`
- `mo.uom_code IS NULL`

แนะนำให้ **ไม่ปล่อยให้มี `NULL`** ในตารางไหนเลย ถ้าพบให้ fix ให้หมด

---

## 5. Pseudo-code ของ Migration

```php
// 1) Pre-flight: ensure no NULL codes
assertNoNullCodes($db, 'routing_node', 'work_center_code');
assertNoNullCodes($db, 'job_task', 'work_center_code');
...
assertNoNullCodes($db, 'mo', 'uom_code');

// 2) Drop FKs / Indexes that reference id_work_center / id_uom
dropFkIfExists($db, 'routing_node', 'fk_routing_node_work_center');
dropIndexIfExists($db, 'routing_node', 'idx_routing_node_wc');
...

// 3) Drop columns
dropColumnIfExists($db, 'routing_node', 'id_work_center');
dropColumnIfExists($db, 'job_task', 'id_work_center');
...
dropColumnIfExists($db, 'mo', 'id_uom');
```

---

## 6. ขั้นตอนการรัน (สำหรับมนุษย์)

1. **ตรวจข้อมูลก่อน**
   - รัน SQL:
     - `SELECT COUNT(*) FROM <table> WHERE work_center_code IS NULL;`
     - `SELECT COUNT(*) FROM <table> WHERE uom_code IS NULL;`
   - ถ้า count > 0 ให้แก้ข้อมูลก่อน

2. **รัน migration**
   - ผ่าน migration runner เดิม:
     ```bash
     php source/bootstrap_migrations.php --tenant={TENANT_CODE}
     ```

3. **ตรวจ schema หลังรัน**
   - `SHOW COLUMNS FROM routing_node LIKE 'id_work_center';`
   - `SHOW COLUMNS FROM job_task LIKE 'id_work_center';`
   - `SHOW COLUMNS FROM product LIKE 'default_uom';`
   - `SHOW COLUMNS FROM bom_line LIKE 'id_uom';`
   - ต้องได้ผลลัพธ์ = empty set ทุกตัว

4. **ทดสอบ**
   - ทดสอบ:
     - สร้าง MO ใหม่
     - Bind routing graph
     - Generate Job Ticket
     - RUN CUT / STITCH / EDGE / QC ครบ flow
   - ทดสอบ product/bom/material creation/update

---

## 7. Acceptance Criteria

- [ ] ทุกตารางใน scope ไม่มี `id_work_center` / `id_uom` / `default_uom` แล้ว
- [ ] ไม่มี FK / INDEX ใดที่อ้างอิง column เหล่านี้เหลืออยู่
- [ ] Application ทั้งระบบยังทำงานปกติ:
  - สร้าง/แก้ไข Product, BOM, Material, MO ได้
  - Hatthasilpa Job Ticket & Super DAG ใช้งานได้
- [ ] Tenant ใหม่ seed `work_center` / `unit_of_measure` เมื่อไหร่ก็ได้ โดยไม่ dependence กับ AUTO_INCREMENT ID

---

## 8. Notes

- การลบ ID ออกจากตารางลูก = ตัด dependency เรื่อง “เลขวิ่ง” ออกจาก business logic ทั้งหมด
- ต่อจากนี้ การ seed work center / UOM สามารถทำผ่าน code ได้ 100%
- เป็นพื้นฐานสำคัญสำหรับ multi-tenant, multi-environment seeding (dev/staging/prod ไม่ต้อง sync ID กัน)

เมื่อ Task 15.6 เสร็จ = ปิดงาน refactor รอบใหญ่ของ work center & UOM schema อย่างเรียบร้อย

<?php

/**
 * 2025_12_drop_wc_uom_id_columns.php
 *
 * Hard cleanup: drop legacy id_work_center / id_uom / default_uom columns
 * AFTER the system has fully migrated to work_center_code / uom_code.
 *
 * This migration is:
 * - Non-interactive (fails fast if preconditions are not met)
 * - Idempotent (safe to run multiple times)
 */

class Migration_2025_12_drop_wc_uom_id_columns
{
    /**
     * @param \BGERP\Helper\DatabaseHelper $db
     * @throws \RuntimeException
     */
    public function up($db)
    {
        // Expecting DatabaseHelper-like object
        if (!method_exists($db, 'getDb')) {
            throw new \RuntimeException('Invalid DB helper passed to migration.');
        }

        /** @var \mysqli $mysqli */
        $mysqli = $db->getDb();

        // Wrap everything in a transaction to avoid half-applied state
        $mysqli->begin_transaction();

        try {
            // 1) Pre-flight checks: ensure no NULL codes remain
            $this->assertNoNullCodes($mysqli, 'routing_node', 'work_center_code');
            $this->assertNoNullCodes($mysqli, 'job_task', 'work_center_code');
            $this->assertNoNullCodes($mysqli, 'job_ticket', 'work_center_code');
            $this->assertNoNullCodes($mysqli, 'work_center_team_map', 'work_center_code');
            $this->assertNoNullCodes($mysqli, 'work_center_behavior_map', 'work_center_code');
            $this->assertNoNullCodes($mysqli, 'routing_step', 'work_center_code');

            $this->assertNoNullCodes($mysqli, 'product', 'default_uom_code');
            $this->assertNoNullCodes($mysqli, 'bom_line', 'uom_code');
            $this->assertNoNullCodes($mysqli, 'material', 'default_uom_code');
            $this->assertNoNullCodes($mysqli, 'material_lot', 'uom_code');
            $this->assertNoNullCodes($mysqli, 'stock_item', 'uom_code');
            $this->assertNoNullCodes($mysqli, 'stock_ledger', 'uom_code');
            $this->assertNoNullCodes($mysqli, 'purchase_rfq_item', 'uom_code');
            $this->assertNoNullCodes($mysqli, 'mo', 'uom_code');

            // 2) Drop FKs / indexes that depend on id_work_center / id_uom / default_uom
            // Work Center FKs / indexes
            $this->dropForeignKeyIfExists($mysqli, 'routing_node', 'fk_routing_node_work_center');
            $this->dropIndexIfExists($mysqli, 'routing_node', 'idx_routing_node_wc');

            $this->dropForeignKeyIfExists($mysqli, 'job_task', 'fk_job_task_work_center');
            $this->dropIndexIfExists($mysqli, 'job_task', 'idx_job_task_work_center');

            $this->dropForeignKeyIfExists($mysqli, 'job_ticket', 'fk_job_ticket_work_center');
            $this->dropIndexIfExists($mysqli, 'job_ticket', 'idx_job_ticket_work_center');

            $this->dropForeignKeyIfExists($mysqli, 'work_center_team_map', 'fk_wctm_work_center');
            $this->dropIndexIfExists($mysqli, 'work_center_team_map', 'idx_wctm_work_center');

            $this->dropForeignKeyIfExists($mysqli, 'work_center_behavior_map', 'fk_wcbm_work_center');
            $this->dropIndexIfExists($mysqli, 'work_center_behavior_map', 'idx_wcbm_work_center');

            $this->dropForeignKeyIfExists($mysqli, 'routing_step', 'fk_routing_step_work_center');
            $this->dropIndexIfExists($mysqli, 'routing_step', 'idx_routing_step_work_center');

            // UOM FKs / indexes
            $this->dropForeignKeyIfExists($mysqli, 'product', 'fk_product_default_uom');
            $this->dropIndexIfExists($mysqli, 'product', 'idx_product_default_uom');

            $this->dropForeignKeyIfExists($mysqli, 'bom_line', 'fk_bom_line_uom');
            $this->dropIndexIfExists($mysqli, 'bom_line', 'idx_bom_line_uom');

            $this->dropForeignKeyIfExists($mysqli, 'material', 'fk_material_default_uom');
            $this->dropIndexIfExists($mysqli, 'material', 'idx_material_default_uom');

            $this->dropForeignKeyIfExists($mysqli, 'material_lot', 'fk_material_lot_uom');
            $this->dropIndexIfExists($mysqli, 'material_lot', 'fk_material_lot_uom'); // index might share name with FK

            $this->dropForeignKeyIfExists($mysqli, 'stock_item', 'fk_stock_item_uom');
            $this->dropIndexIfExists($mysqli, 'stock_item', 'idx_stock_item_uom');

            $this->dropForeignKeyIfExists($mysqli, 'stock_ledger', 'fk_stock_ledger_uom');
            $this->dropIndexIfExists($mysqli, 'stock_ledger', 'idx_stock_ledger_uom');

            $this->dropForeignKeyIfExists($mysqli, 'purchase_rfq_item', 'fk_prfq_item_uom');
            $this->dropIndexIfExists($mysqli, 'purchase_rfq_item', 'idx_prfq_item_uom');

            $this->dropForeignKeyIfExists($mysqli, 'mo', 'fk_mo_uom');
            $this->dropIndexIfExists($mysqli, 'mo', 'idx_mo_uom');

            // 3) Drop columns (if they still exist)
            // Work Center
            $this->dropColumnIfExists($mysqli, 'routing_node', 'id_work_center');
            $this->dropColumnIfExists($mysqli, 'job_task', 'id_work_center');
            $this->dropColumnIfExists($mysqli, 'job_ticket', 'id_work_center');
            $this->dropColumnIfExists($mysqli, 'work_center_team_map', 'id_work_center');
            $this->dropColumnIfExists($mysqli, 'work_center_behavior_map', 'id_work_center');
            $this->dropColumnIfExists($mysqli, 'routing_step', 'id_work_center');

            // UOM
            $this->dropColumnIfExists($mysqli, 'product', 'default_uom');
            $this->dropColumnIfExists($mysqli, 'bom_line', 'id_uom');
            $this->dropColumnIfExists($mysqli, 'material', 'default_uom');
            $this->dropColumnIfExists($mysqli, 'material_lot', 'id_uom');
            $this->dropColumnIfExists($mysqli, 'stock_item', 'id_uom');
            $this->dropColumnIfExists($mysqli, 'stock_ledger', 'id_uom');
            $this->dropColumnIfExists($mysqli, 'purchase_rfq_item', 'id_uom');
            $this->dropColumnIfExists($mysqli, 'mo', 'id_uom');

            $mysqli->commit();
        } catch (\Throwable $e) {
            $mysqli->rollback();
            throw $e;
        }
    }

    /**
     * Assert there is no row in $table where $column IS NULL.
     *
     * @param \mysqli $mysqli
     * @param string  $table
     * @param string  $column
     * @throws \RuntimeException
     */
    private function assertNoNullCodes(\mysqli $mysqli, string $table, string $column): void
    {
        if (!$this->tableExists($mysqli, $table)) {
            // If table does not exist, nothing to validate
            return;
        }

        $sql = sprintf(
            "SELECT COUNT(*) AS c FROM `%s` WHERE `%s` IS NULL",
            $mysqli->real_escape_string($table),
            $mysqli->real_escape_string($column)
        );

        $res = $mysqli->query($sql);
        if (!$res) {
            throw new \RuntimeException("Failed to run NULL-check query on {$table}.{$column}: " . $mysqli->error);
        }

        $row = $res->fetch_assoc();
        $count = (int)($row['c'] ?? 0);
        $res->free();

        if ($count > 0) {
            throw new \RuntimeException("Cannot drop legacy IDs: found {$count} rows with NULL {$column} in {$table}");
        }
    }

    /**
     * Drop a foreign key if it exists on the given table.
     */
    private function dropForeignKeyIfExists(\mysqli $mysqli, string $table, string $fkName): void
    {
        if (!$this->tableExists($mysqli, $table)) {
            return;
        }

        $sql = "SELECT CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = '" . $mysqli->real_escape_string($table) . "'
                  AND CONSTRAINT_NAME = '" . $mysqli->real_escape_string($fkName) . "'";

        $res = $mysqli->query($sql);
        if ($res && $res->num_rows > 0) {
            $res->free();
            $alter = "ALTER TABLE `{$table}` DROP FOREIGN KEY `{$fkName}`";
            $mysqli->query($alter);
        } elseif ($res) {
            $res->free();
        }
    }

    /**
     * Drop an index if it exists on the given table.
     */
    private function dropIndexIfExists(\mysqli $mysqli, string $table, string $indexName): void
    {
        if (!$this->tableExists($mysqli, $table)) {
            return;
        }

        $sql = "SHOW INDEX FROM `{$table}` WHERE Key_name = '" . $mysqli->real_escape_string($indexName) . "'";
        $res = $mysqli->query($sql);
        if ($res && $res->num_rows > 0) {
            $res->free();
            $alter = "ALTER TABLE `{$table}` DROP INDEX `{$indexName}`";
            $mysqli->query($alter);
        } elseif ($res) {
            $res->free();
        }
    }

    /**
     * Drop a column if it exists on the given table.
     */
    private function dropColumnIfExists(\mysqli $mysqli, string $table, string $column): void
    {
        if (!$this->tableExists($mysqli, $table)) {
            return;
        }

        $sql = "SELECT COLUMN_NAME
                FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = '" . $mysqli->real_escape_string($table) . "'
                  AND COLUMN_NAME = '" . $mysqli->real_escape_string($column) . "'";

        $res = $mysqli->query($sql);
        if ($res && $res->num_rows > 0) {
            $res->free();
            $alter = "ALTER TABLE `{$table}` DROP COLUMN `{$column}`";
            $mysqli->query($alter);
        } elseif ($res) {
            $res->free();
        }
    }

    /**
     * Check if a table exists in the current database.
     */
    private function tableExists(\mysqli $mysqli, string $table): bool
    {
        $sql = "SELECT TABLE_NAME
                FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = '" . $mysqli->real_escape_string($table) . "'
                LIMIT 1";

        $res = $mysqli->query($sql);
        if (!$res) {
            throw new \RuntimeException('Failed to query information_schema.TABLES: ' . $mysqli->error);
        }

        $exists = $res->num_rows > 0;
        $res->free();

        return $exists;
    }
}
