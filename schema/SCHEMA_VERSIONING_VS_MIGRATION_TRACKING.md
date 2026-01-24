# Schema Versioning vs Migration Tracking - ความแตกต่างและความสัมพันธ์

**Date:** January 5, 2026  
**Purpose:** อธิบายความแตกต่างระหว่าง Migration Tracking และ Schema Versioning  
**Status:** ✅ **DOCUMENTED**

---

## 📊 ภาพรวม

ระบบมี **2 ระบบที่ทำงานคนละระดับ** และ **ไม่ขัดแย้งกัน**:

1. **Migration Tracking** (Technical Level) - เก็บว่า migration FILE ไหนรันไปแล้ว
2. **Schema Versioning** (Business Level) - เก็บว่า business DOMAIN ไหนอยู่ที่ version ไหน

---

## 🔧 Migration Tracking System (มีอยู่แล้ว)

### Purpose
เก็บว่า **migration file** ไหนรันไปแล้ว เพื่อป้องกันการรันซ้ำ

### Tables

#### 1. `tenant_migrations` (PRIMARY - ใช้ตัวนี้!)
- **Used by:** Migration Wizard UI ✅, BootstrapMigrations.php
- **Columns:**
  - `migration` VARCHAR(191) PRIMARY KEY - ชื่อไฟล์ migration (เช่น "2026_01_schema_version_registry")
  - `executed_at` DATETIME - เวลาที่รัน
  - `execution_time` INT(11) - เวลาที่ใช้รัน (milliseconds)
- **Format:** ไฟล์ชื่ออะไรก็ได้ (แนะนำ `YYYY_MM_` สำหรับ sorting)

#### 2. `tenant_schema_migrations` (LEGACY)
- **Used by:** run_tenant_migrations.php (old script)
- **Columns:**
  - `version` VARCHAR(191) PRIMARY KEY - ชื่อไฟล์ migration
  - `applied_at` DATETIME - เวลาที่รัน
- **Format:** `NNNN_` (old format)
- **⚠️ Avoid using this for new migrations!**

### ตัวอย่างข้อมูล
```sql
-- tenant_migrations table
SELECT * FROM tenant_migrations;
+----------------------------------+---------------------+----------------+
| migration                        | executed_at         | execution_time |
+----------------------------------+---------------------+----------------+
| 2026_01_schema_version_registry  | 2026-01-05 10:00:00 | 45             |
| 2025_12_december_consolidated   | 2025-12-15 14:30:00 | 120            |
+----------------------------------+---------------------+----------------+
```

**คำถามที่ตอบ:** "ไฟล์ `2026_01_schema_version_registry.php` รันไปแล้วหรือยัง?"

---

## 📋 Schema Versioning System (ใหม่ - Step 2)

### Purpose
เก็บว่า **business domain** ไหนอยู่ที่ **schema version** ไหน เพื่อ:
- Runtime visibility ของ schema version
- Breaking change detection
- Version compatibility checking

### Table: `app_schema_version`

- **Columns:**
  - `domain_key` VARCHAR(100) PRIMARY KEY - Domain identifier (เช่น "products.constraints")
  - `schema_version` INT NOT NULL - Schema version number (1, 2, 3, ...)
  - `updated_at` DATETIME - Last update timestamp
  - `notes` TEXT - Optional notes about version changes

### ตัวอย่างข้อมูล
```sql
-- app_schema_version table
SELECT * FROM app_schema_version;
+----------------------+----------------+---------------------+----------------------------------+
| domain_key           | schema_version | updated_at          | notes                            |
+----------------------+----------------+---------------------+----------------------------------+
| products.constraints | 1              | 2026-01-05 10:00:00 | Initial Constraints System v1    |
| dag.routing          | 1              | 2025-12-01 09:00:00 | Initial DAG Routing System v1    |
+----------------------+----------------+---------------------+----------------------------------+
```

**คำถามที่ตอบ:** "products.constraints domain อยู่ที่ version ไหน?"

---

## 🔄 ความสัมพันธ์ระหว่าง 2 ระบบ

### ตัวอย่าง: Migration `2026_01_schema_version_registry.php`

**Migration Tracking:**
```sql
-- เก็บว่าไฟล์รันแล้ว
INSERT INTO tenant_migrations (migration, executed_at)
VALUES ('2026_01_schema_version_registry', NOW());
```

**Schema Versioning:**
```sql
-- Migration file นี้สร้าง app_schema_version table และ insert domain
INSERT INTO app_schema_version (domain_key, schema_version, notes)
VALUES ('products.constraints', 1, 'Initial Constraints System schema - v1');
```

### Flow Diagram

```
1. Migration File: 2026_01_schema_version_registry.php
   ↓
2. BootstrapMigrations.php รัน migration
   ↓
3. migration_run_php_migration() ตรวจสอบ tenant_migrations
   ↓
4. ถ้ายังไม่รัน → รัน migration function
   ↓
5. Migration function:
   - สร้าง app_schema_version table (ถ้ายังไม่มี)
   - INSERT domain 'products.constraints' version 1
   ↓
6. migration_run_php_migration() INSERT ลง tenant_migrations
   ↓
7. Result:
   - tenant_migrations: มี record '2026_01_schema_version_registry'
   - app_schema_version: มี record 'products.constraints' version 1
```

---

## ✅ สรุป: ไม่ขัดแย้งกัน

| Aspect | Migration Tracking | Schema Versioning |
|--------|-------------------|-------------------|
| **Level** | Technical (file-level) | Business (domain-level) |
| **Question** | "ไฟล์ไหนรันแล้ว?" | "Domain ไหน version ไหน?" |
| **Table** | `tenant_migrations` | `app_schema_version` |
| **Key** | Migration filename | Domain key |
| **Value** | executed_at timestamp | Schema version number |
| **Purpose** | Prevent duplicate execution | Track business schema evolution |

### ตัวอย่างการใช้งานร่วมกัน

```php
// 1. Check if migration file ran (Migration Tracking)
$stmt = $tenantDb->prepare("SELECT migration FROM tenant_migrations WHERE migration = ?");
$stmt->bind_param('s', '2026_01_schema_version_registry');
// → ถ้ามี = migration รันแล้ว

// 2. Check schema version (Schema Versioning)
$stmt = $tenantDb->prepare("SELECT schema_version FROM app_schema_version WHERE domain_key = ?");
$stmt->bind_param('s', 'products.constraints');
// → ได้ version 1, 2, 3, ... (business schema version)
```

---

## 🎯 Best Practices

1. **Migration Tracking:**
   - ใช้ `tenant_migrations` table (ไม่ใช่ `tenant_schema_migrations`)
   - Track ทุก migration file ที่รัน

2. **Schema Versioning:**
   - ใช้ `app_schema_version` table
   - Update version เมื่อมี breaking changes
   - เก็บ version ต่อ domain (ไม่ใช่ต่อ file)

3. **Breaking Changes:**
   - Migration file ใหม่ → track ใน `tenant_migrations`
   - Breaking change → bump version ใน `app_schema_version`
   - ตัวอย่าง:
     ```php
     // ใน migration file
     $db->query("
       INSERT INTO app_schema_version (domain_key, schema_version, notes)
       VALUES ('products.constraints', 2, 'Breaking: removed deprecated columns')
       ON DUPLICATE KEY UPDATE schema_version = 2, updated_at = NOW()
     ");
     ```

---

## 📚 Related Documents

- **Migration Guide:** `database/MIGRATION_GUIDE.md`
- **Schema Versioning Policy:** `docs/schema/SCHEMA_VERSIONING_POLICY.md`
- **Migration Helpers:** `database/tools/migration_helpers.php`

---

**Status:** ✅ **DOCUMENTED**  
**Last Updated:** January 5, 2026
