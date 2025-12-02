# 🧙‍♂️ Migration Wizard - User Guide

**Last Updated:** October 27, 2025  
**Version:** 1.0  
**Access Level:** Platform Super Admin Only

---

## 📋 Overview

Migration Wizard เป็นเครื่องมือสำหรับ **Platform Super Admins** ในการ deploy database migrations ไปยัง tenants ที่มีอยู่แล้ว

---

## 🎯 Use Cases

### ❓ เมื่อไหร่ใช้ Migration Wizard?

#### ✅ **ใช้เมื่อ:**
- มี migration file **ใหม่** ที่ต้อง deploy ไปยัง existing tenants
- ต้องการ deploy ไปยัง **หลาย tenants** พร้อมกัน
- ต้องการ **test migration** ก่อน deploy จริง (dry run)
- ต้องการ **ดู logs** และ deployment status
- มี schema changes ที่ต้อง apply ให้ทุก tenant

#### ❌ **ไม่ใช้เมื่อ:**
- สร้าง **tenant ใหม่** → ใช้ `provision_tenant()` อัตโนมัติ
- ต้องการแก้ไข migration code → แก้ในไฟล์แล้ว commit
- ต้องการ rollback → ยังไม่ support (ใน roadmap)

---

## 🚀 How to Use

### Step 1: Select Migration File

1. เปิดหน้า Migration Wizard
2. ดูรายการ migration files available
3. เลือกไฟล์ที่ต้องการ deploy

**ข้อมูลที่แสดง:**
- ชื่อไฟล์
- Description (ถ้ามี)
- Has up/down methods
- Syntax check result

**Example:**
```
✅ 2025_01_schedule_system.php
   Description: Production Schedule System
   Has Up: ✅ YES
   Has Down: ✅ YES
   Syntax: ✅ Valid
```

### Step 2: Select Tenants

1. เลือก tenants ที่ต้องการ deploy (checkboxes)
2. สามารถเลือกหลาย tenants พร้อมกัน
3. คลิก "Next: Test Migration"

**ข้อมูลที่แสดง:**
- Tenant code
- Tenant name
- Status (Active/Inactive)
- Database name

### Step 3: Test Migration (Dry Run)

1. ระบบจะ **ทดสอบ** migration โดยไม่ deploy จริง
2. แสดงผลการทดสอบสำหรับแต่ละ tenant:
   - Syntax validation
   - Migration already executed check
   - up/down method detection
   - Warnings (ถ้ามี)

**Possible Results:**
```
✅ Can execute
   - Syntax valid
   - Has up() method
   - Not executed yet

⚠️  Already executed
   - Migration deployed ไปแล้ว
   - Safe to re-run (idempotent)

❌ Cannot execute
   - Syntax error
   - No up() method
   - Database connection failed
```

### Step 4: Deploy

1. Review test results
2. คลิก "Confirm & Deploy"
3. รอ deployment เสร็จสิ้น
4. ดูผลลัพธ์สำหรับแต่ละ tenant

**Deployment Results:**
```
📊 Deployment Results

✅ DEFAULT
   Status: Migration executed successfully
   Output: Migration completed successfully for DEFAULT

✅ maison_atelier
   Status: Migration executed successfully
   Output: Migration completed successfully for maison_atelier
```

---

## 🔧 Migration File Formats

### Format 1: Array-based (Recommended)

```php
<?php
return [
    'description' => 'Add new feature',
    'up' => function($db) {
        // Create tables, add columns
        $db->query("CREATE TABLE ...");
    },
    'down' => function($db) {
        // Rollback changes
        $db->query("DROP TABLE ...");
    }
];
```

**Features:**
- ✅ Has up/down methods
- ✅ Rollback support (future)
- ✅ Modern format

### Format 2: Standalone Function (Legacy)

```php
<?php
return function (mysqli $db): void {
    // Migration logic
    $db->query("CREATE TABLE ...");
};
```

**Features:**
- ✅ Simple format
- ❌ No rollback support
- ⚠️ Legacy format

---

## 📊 Features

### 1. **Multi-Tenant Deployment**
- Deploy ไปยัง 1 หรือหลาย tenants พร้อมกัน
- แสดงผลแยกสำหรับแต่ละ tenant
- Independent execution (1 tenant ล้มเหลวไม่กระทบอีก tenant)

### 2. **Dry Run Testing**
- ทดสอบก่อน deploy จริง
- Syntax validation
- Already-executed detection
- Warning notifications

### 3. **Migration Tracking**
- บันทึกทุก deployment ใน `tenant_migrations` table
- Prevent duplicate execution
- Track execution time
- Store execution timestamp

### 4. **View Logs**
- ดู migration history ของแต่ละ tenant
- แสดง execution time
- Filter by tenant
- View system logs

### 5. **Idempotent Migrations**
- ใช้ helper functions:
  - `migration_add_column_if_missing()`
  - `migration_create_table_if_missing()`
  - `migration_add_index_if_missing()`
- รันซ้ำได้ไม่ error
- Safe deployment

---

## ⚠️ Important Notes

### 1. **Migration File Naming**
```
✅ GOOD:
  - 2025_01_feature_name.php
  - 0001_init_schema.php
  - 2025_10_27_add_columns.php

❌ BAD:
  - migration.php (ไม่มี version/date)
  - feature.php (ไม่ชัดเจน)
```

### 2. **Idempotency**
```php
// ✅ GOOD: Check before create
if (!$db->query("SHOW TABLES LIKE 'my_table'")->num_rows) {
    $db->query("CREATE TABLE my_table ...");
}

// ❌ BAD: Direct create (error if exists)
$db->query("CREATE TABLE my_table ...");
```

### 3. **Testing**
```
Always test on DEFAULT first!
  1. Test with DEFAULT tenant
  2. Verify results
  3. Then deploy to production tenants
```

### 4. **Backup**
```
Before major migrations:
  1. Backup tenant databases
  2. Test on staging first
  3. Have rollback plan ready
```

---

## 🐛 Troubleshooting

### Issue: "HTTP 500" during deployment

**Causes:**
- PHP version compatibility (use PHP 7.4+)
- SQL syntax errors in migration
- Missing database tables

**Solutions:**
```
1. Check browser console for detailed error
2. Check migration syntax: php -l migration_file.php
3. Use Debug Tool: source/debug_migration.php
4. Check PHP error logs
```

### Issue: "No up() method found"

**Cause:**
- Migration file format ไม่ถูกต้อง

**Solution:**
```php
// Ensure migration returns array or callable
return [
    'up' => function($db) { ... },
    'down' => function($db) { ... }
];
```

### Issue: "Migration already executed"

**Cause:**
- Migration ถูก deploy ไปแล้ว
- มี record ใน tenant_migrations

**Solution:**
- ✅ นี่เป็นสถานะปกติ
- ✅ Migration จะ skip automatically
- ℹ️ Idempotent migrations ยังรันได้ (แต่ไม่มี effect)

### Issue: "Missing filename or org_codes"

**Cause:**
- JavaScript error ส่งข้อมูลไม่ครบ

**Solution:**
- Hard refresh (Cmd+Shift+R)
- Clear browser cache
- Check browser console

---

## 📈 Performance

### Execution Times:
```
Small migration (< 10 operations):  50-200ms
Medium migration (10-50 operations): 200-500ms
Large migration (> 50 operations):   500ms-2s
```

### Recommendations:
- Break large migrations into smaller files
- Use bulk inserts instead of loops
- Add progress logging for long migrations
- Use transactions for data integrity

---

## 🔐 Security

### Access Control:
- ✅ Platform Super Admin only
- ✅ Session validation
- ✅ Permission checks on every API call
- ✅ SQL injection protection (prepared statements)

### Best Practices:
```
1. Review migration code before deployment
2. Test on non-production tenant first
3. Backup before major schema changes
4. Monitor deployment results
5. Keep migration files in version control
```

---

## 📚 Related Documentation

- `PLATFORM_ADMIN_FULL_ACCESS.md` - Platform admin capabilities
- `PERMISSION_MANAGEMENT_GUIDE.md` - Permission system
- `DATABASE_MIGRATION_GUIDE.md` - Migration development
- `TROUBLESHOOTING_GUIDE.md` - Common issues

---

## 🎯 Quick Reference

```bash
# Create new migration
cd database/tenant_migrations/
touch 2025_XX_feature_name.php

# Deploy via wizard
1. Login as platform admin
2. Platform Console → Migration Wizard
3. Select file
4. Select tenants
5. Test → Deploy

# Check deployment status
Platform Console → Health Check
→ Migrations section shows applied/total
```

---

**Status:** ✅ Production Ready  
**Support:** Platform Super Admins only  
**Last Tested:** October 27, 2025

