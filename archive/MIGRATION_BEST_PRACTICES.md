# Migration Best Practices

**Last Updated:** November 15, 2025  
**Version:** 1.0.0

---

## 📋 Overview

เอกสารนี้สรุป Best Practices สำหรับการเขียน Migration ใน Bellavier Group ERP

---

## ✅ **Standard Migration Structure**

### **1. File Header**
```php
<?php
/**
 * Migration: YYYY_MM_description
 * 
 * Description: Brief description of what this migration does
 * 
 * This migration:
 * 1. Step 1 description
 * 2. Step 2 description
 * 
 * @package Bellavier Group ERP
 * @version 1.0
 * @date YYYY-MM-DD
 */

require_once __DIR__ . '/../tools/migration_helpers.php';
```

### **2. Migration Function**
```php
return function (mysqli $db): void {
    echo "=== Migration Title ===\n\n";
    
    // Step 1: Description
    echo "[1/N] Step description...\n";
    // Migration logic here
    
    echo "\n✓ Migration complete!\n";
};
```

---

## 🔧 **Helper Functions (USE THESE!)**

### **1. Table Operations**

#### **Create Table (Idempotent)**
```php
migration_create_table_if_missing($db, 'table_name', "
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
");
```

#### **Check Table Exists**
```php
if (!migration_table_exists($db, 'table_name')) {
    // Create table
}
```

### **2. Column Operations**

#### **Add Column (Idempotent)**
```php
migration_add_column_if_missing($db, 'table_name', 'column_name', "
    `column_name` VARCHAR(100) NOT NULL DEFAULT '' COMMENT 'Description'
");
```

#### **Modify Column (Idempotent)**
```php
migration_modify_column_if_different($db, 'table_name', 'column_name', "
    `column_name` VARCHAR(200) NOT NULL DEFAULT '' COMMENT 'Updated description'
");
```

### **3. Index Operations**

#### **Add Index (Idempotent)**
```php
migration_add_index_if_missing($db, 'table_name', 'idx_column_name', "
    INDEX `idx_column_name` (`column_name`)
");
```

### **4. Data Operations**

#### **Insert If Not Exists (Idempotent)**
```php
migration_insert_if_not_exists(
    $db,
    'table_name',
    ['code' => 'value'],  // WHERE conditions
    [                      // INSERT data
        'code' => 'value',
        'name' => 'Name',
        'status' => 'active'
    ]
);
```

#### **Fetch Value (Helper)**
```php
$roleId = migration_fetch_value(
    $db, 
    'SELECT id_tenant_role FROM tenant_role WHERE code = ?', 
    's', 
    [$roleCode]
);
```

---

## 📝 **Common Patterns**

### **Pattern 1: Permission + Role Assignment**
```php
// 1. Add permission
$permCode = 'permission.code';
$permDesc = 'Permission description';

migration_insert_if_not_exists(
    $db,
    'permission',
    ['code' => $permCode],
    [
        'code' => $permCode,
        'description' => $permDesc
    ]
);

// 2. Get permission ID
$permId = migration_fetch_value(
    $db, 
    'SELECT id_permission FROM permission WHERE code = ?', 
    's', 
    [$permCode]
);

// 3. Assign to roles
$assignPermission = function($roleCode) use ($db, $permId) {
    $roleId = migration_fetch_value(
        $db, 
        'SELECT id_tenant_role FROM tenant_role WHERE code = ?', 
        's', 
        [$roleCode]
    );
    
    if (!$roleId) {
        echo "  ⚠ Role '{$roleCode}' not found, skipping...\n";
        return;
    }
    
    migration_insert_if_not_exists(
        $db,
        'tenant_role_permission',
        ['id_tenant_role' => (int)$roleId, 'id_permission' => (int)$permId],
        [
            'id_tenant_role' => (int)$roleId,
            'id_permission' => (int)$permId,
            'allow' => 1
        ]
    );
    echo "  ✓ Assigned to role '{$roleCode}'\n";
};

$assignPermission('admin');
$assignPermission('production_manager');
```

### **Pattern 2: Create Table with Indexes**
```php
// 1. Create table
migration_create_table_if_missing($db, 'my_table', "
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    status ENUM('active','inactive') DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_status (status),
    KEY idx_created (created_at)
");

// 2. Add additional indexes if needed
migration_add_index_if_missing($db, 'my_table', 'idx_name', "
    INDEX `idx_name` (`name`)
");
```

### **Pattern 3: Update ENUM Values**
```php
// 1. Update data first
$db->query("UPDATE table_name SET column_name = 'new_value' WHERE column_name = 'old_value'");

// 2. Change ENUM definition
$db->query("ALTER TABLE table_name MODIFY COLUMN column_name ENUM('value1','new_value','value3')");
```

---

## ⚠️ **Common Mistakes to Avoid**

### **❌ Mistake 1: Direct SQL Without Checks**
```php
// ❌ BAD: Will fail if table exists
$db->query("CREATE TABLE my_table (...)");

// ✅ GOOD: Idempotent
migration_create_table_if_missing($db, 'my_table', "...");
```

### **❌ Mistake 2: Not Using Helper Functions**
```php
// ❌ BAD: Manual prepared statements (verbose, error-prone)
$stmt = $db->prepare('SELECT id FROM table WHERE code = ?');
$stmt->bind_param('s', $code);
$stmt->execute();
$stmt->bind_result($id);
$stmt->fetch();
$stmt->close();

// ✅ GOOD: Use helper function
$id = migration_fetch_value($db, 'SELECT id FROM table WHERE code = ?', 's', [$code]);
```

### **❌ Mistake 3: Not Handling Missing Data**
```php
// ❌ BAD: Will fail if role doesn't exist
$roleId = migration_fetch_value(...);
migration_insert_if_not_exists(..., ['id_tenant_role' => $roleId, ...]);

// ✅ GOOD: Check first
$roleId = migration_fetch_value(...);
if (!$roleId) {
    echo "  ⚠ Role not found, skipping...\n";
    return;
}
migration_insert_if_not_exists(..., ['id_tenant_role' => $roleId, ...]);
```

### **❌ Mistake 4: Wrong Naming Convention**
```php
// ❌ BAD: Wrong format
0012_feature_name.php
feature_name_2025_11.php

// ✅ GOOD: Correct format
2025_11_feature_name.php
```

---

## 🎯 **Best Practices Checklist**

- [ ] **File naming**: `YYYY_MM_description.php` format
- [ ] **Idempotent**: Safe to run multiple times
- [ ] **Helper functions**: Use `migration_*` helpers instead of direct SQL
- [ ] **Error handling**: Check for missing data before operations
- [ ] **Progress output**: Use `echo` statements to show progress
- [ ] **Comments**: Document what each step does
- [ ] **Testing**: Test on DEFAULT tenant first
- [ ] **Backup**: Backup before major migrations

---

## 📚 **Reference Examples**

### **Example 1: Simple Permission Migration**
```php
<?php
/**
 * Migration: 2025_11_dashboard_production_permission
 * Description: Add dashboard.production.view permission
 */

require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    echo "=== Adding dashboard.production.view Permission ===\n\n";
    
    // Add permission
    migration_insert_if_not_exists(
        $db,
        'permission',
        ['code' => 'dashboard.production.view'],
        [
            'code' => 'dashboard.production.view',
            'description' => 'View Production Dashboard'
        ]
    );
    
    // Get permission ID
    $permId = migration_fetch_value(
        $db, 
        'SELECT id_permission FROM permission WHERE code = ?', 
        's', 
        ['dashboard.production.view']
    );
    
    // Assign to roles
    $assignPermission = function($roleCode) use ($db, $permId) {
        $roleId = migration_fetch_value(
            $db, 
            'SELECT id_tenant_role FROM tenant_role WHERE code = ?', 
            's', 
            [$roleCode]
        );
        if (!$roleId) return;
        
        migration_insert_if_not_exists(
            $db,
            'tenant_role_permission',
            ['id_tenant_role' => (int)$roleId, 'id_permission' => (int)$permId],
            ['id_tenant_role' => (int)$roleId, 'id_permission' => (int)$permId, 'allow' => 1]
        );
    };
    
    $assignPermission('admin');
    $assignPermission('production_manager');
    
    echo "\n✓ Migration complete!\n";
};
```

### **Example 2: Table Creation Migration**
```php
<?php
/**
 * Migration: 2025_11_my_feature
 * Description: Create tables for my feature
 */

require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    echo "=== Creating My Feature Tables ===\n\n";
    
    // Create table
    migration_create_table_if_missing($db, 'my_table', "
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        status ENUM('active','inactive') DEFAULT 'active',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        KEY idx_status (status)
    ");
    
    // Add index
    migration_add_index_if_missing($db, 'my_table', 'idx_name', "
        INDEX `idx_name` (`name`)
    ");
    
    // Seed data
    migration_insert_if_not_exists(
        $db,
        'my_table',
        ['name' => 'Default'],
        ['name' => 'Default', 'status' => 'active']
    );
    
    echo "\n✓ Migration complete!\n";
};
```

---

## 🔗 **Related Documentation**

- [Migration Naming Standard](./MIGRATION_NAMING_STANDARD.md)
- [Migration Wizard Guide](../../guide/MIGRATION_WIZARD_GUIDE.md)
- [Migration Helpers](../../../database/tools/migration_helpers.php)

---

## 📝 **Summary**

**Key Principles:**
1. ✅ Always use helper functions (`migration_*`)
2. ✅ Make migrations idempotent (safe to run multiple times)
3. ✅ Use correct naming convention (`YYYY_MM_description.php`)
4. ✅ Test on DEFAULT tenant first
5. ✅ Add progress output (`echo` statements)
6. ✅ Handle missing data gracefully

**Remember:** Migrations should be **safe**, **idempotent**, and **testable**!

