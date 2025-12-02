# 🔐 Platform vs Tenant Admin - Separation Guide

**Problem:** User "admin" เป็นทั้ง Platform Admin และ Tenant Admin → สับสน  
**Solution:** แยกชัดเจนระหว่าง Platform และ Tenant levels

---

## 📊 **ปัจจุบัน (สถานะปัจจุบัน)**

### User "admin":
```
1. Platform User ✅
   - มี platform_role = platform_super_admin
   - Access: ทุก tenants, run migrations, manage platform

2. Tenant User (DEFAULT) ✅
   - มี account_group = admin
   - Access: จัดการ DEFAULT tenant

3. Tenant User (maison_atelier) ✅
   - มี account_group = admin
   - Access: จัดการ maison_atelier tenant
```

**ปัญหา:** 
- ❌ ชื่อ "admin" ซ้ำกัน 3 ที่
- ❌ ไม่ชัดเจนว่าเป็น platform หรือ tenant admin
- ❌ Permission check สับสน

---

## ✅ **แนวทางแก้ไข: 3 Options**

---

## 🏗️ **Option 1: แยก Users ชัดเจน** (แนะนำ)

### Concept: แยก Platform Admin และ Tenant Admin เป็นคนละ user

```
Platform Level (Core DB):
  └─ User: platform_admin
      ├─ platform_role: platform_super_admin
      ├─ Can: จัดการทุก tenants, run migrations
      └─ NOT member of any tenant (ดูได้ทุก tenant แต่ไม่มี role ใน tenant)

Tenant Level:
  ├─ Tenant: DEFAULT
  │   └─ User: admin_default
  │       ├─ account_group: admin
  │       └─ Can: จัดการ DEFAULT เท่านั้น
  │
  └─ Tenant: maison_atelier
      └─ User: admin_maison (หรือ test เป็น owner)
          ├─ account_group: owner/admin
          └─ Can: จัดการ maison_atelier เท่านั้น
```

### Implementation:

#### Step 1: สร้าง Platform Admin User ใหม่

```sql
-- สร้าง user platform_admin (ไม่ใช้ชื่อ "admin")
INSERT INTO account (username, password, name, email, status)
VALUES ('platform_admin', 'hashed_password', 'Platform Administrator', 'platform@bellavier.com', 1);

-- Assign platform_role
INSERT INTO platform_user (id_member, status)
VALUES (LAST_INSERT_ID(), 1);

INSERT INTO platform_user_role (id_platform_user, id_platform_role)
VALUES (LAST_INSERT_ID(), 1); -- platform_super_admin role
```

#### Step 2: Rename Tenant Admins

```sql
-- แยกชื่อให้ชัดเจน
UPDATE account SET username = 'admin_default' WHERE username = 'admin' AND id_member IN (...);
-- หรือใช้ชื่ออื่น เช่น: it_admin, system_admin
```

#### Step 3: Update Permission Check Logic

```php
function is_platform_admin($member) {
    return platform_has_permission('platform.super_admin');
}

function is_tenant_admin($member) {
    $role = get_user_role($member);
    return in_array($role, ['owner', 'admin']);
}

// In admin pages:
if (is_platform_admin($member)) {
    // Show all tenants, all options
} elseif (is_tenant_admin($member)) {
    // Show current tenant only
} else {
    // Forbidden
}
```

### ✅ ข้อดี:
- 🟢 ชัดเจนที่สุด
- 🟢 Security ดี (แยกชัดเจน)
- 🟢 ง่ายต่อการจัดการ

### ❌ ข้อเสีย:
- 🔴 ต้องสร้าง users ใหม่
- 🔴 Migrate existing users

---

## 🏗️ **Option 2: ใช้ Context Switching** (ยืดหยุ่น)

### Concept: User เดียว แต่มี "mode" สลับได้

```
User: admin
├─ Platform Mode
│   ├─ Check: platform_user table
│   ├─ Can: จัดการ platform
│   └─ UI: แสดงทุก tenants, migration options
│
└─ Tenant Mode (เลือก tenant)
    ├─ Check: account_org table
    ├─ Can: จัดการ tenant ที่เลือก
    └─ UI: แสดงแค่ tenant นั้น
```

### Implementation:

#### UI: เพิ่ม Mode Switcher

```html
<!-- ถ้า user เป็น platform_admin -->
<div class="mode-switcher">
  <button class="btn btn-sm" id="platformMode">
    🌐 Platform Mode
  </button>
  <button class="btn btn-sm" id="tenantMode">
    🏢 Tenant Mode (maison_atelier)
  </button>
</div>
```

#### Backend: Check Context

```php
function get_admin_context($member) {
    // Check if platform user
    if (platform_has_permission('platform.super_admin')) {
        $mode = $_SESSION['admin_mode'] ?? 'platform';
        
        if ($mode === 'platform') {
            return ['type' => 'platform', 'can_access_all_tenants' => true];
        } else {
            return ['type' => 'tenant', 'org' => resolve_current_org()];
        }
    }
    
    // Regular tenant admin
    return ['type' => 'tenant', 'org' => resolve_current_org()];
}
```

### ✅ ข้อดี:
- 🟢 User เดียวทำได้ทั้ง 2 mode
- 🟢 ยืดหยุ่น
- 🟢 ไม่ต้องสร้าง users ใหม่

### ❌ ข้อเสีย:
- 🟡 UI ซับซ้อนขึ้น
- 🟡 Logic phức่อนกว่า

---

## 🏗️ **Option 3: Role-based Access (Current + Enhance)**

### Concept: ปรับปรุงระบบปัจจุบัน ให้ชัดเจนขึ้น

```
Platform Level:
  └─ platform_super_admin
      ├─ Can: Everything
      ├─ Check: platform_has_permission()
      └─ UI: Show "Platform Console" menu

Tenant Level:
  ├─ owner (เจ้าของ tenant)
  │   └─ Can: Full access in their tenant
  │
  └─ admin (IT admin of tenant)
      └─ Can: User management, some settings
```

### Implementation:

#### Permission Check Enhancement:

```php
// source/permission.php

function can_manage_platform() {
    return platform_has_permission('platform.tenants.manage')
        || platform_has_permission('platform.migrations.run');
}

function can_manage_tenant_users() {
    return permission_allow_code($member, 'org.user.manage')
        || permission_allow_code($member, 'org.role.assign');
}

function can_access_tenant($member, $org_code) {
    // Platform admin → can access all
    if (can_manage_platform()) {
        return true;
    }
    
    // Tenant user → check account_org
    $coreDb = core_db();
    $org = fetch_org_by_code($org_code);
    
    $stmt = $coreDb->prepare("SELECT 1 FROM account_org 
        WHERE id_member = ? AND id_org = ? LIMIT 1");
    $stmt->bind_param('ii', $member['id_member'], $org['id_org']);
    $stmt->execute();
    $result = $stmt->fetch();
    $stmt->close();
    
    return (bool)$result;
}
```

#### UI Enhancement:

```php
// views/template/sidebar-left.template.php

<?php if (can_manage_platform()): ?>
    <!-- Platform Console Menu -->
    <li class="slide__category platform-only">
        <span>🌐 Platform Console</span>
    </li>
    <li><a href="?p=admin_organizations">Tenants</a></li>
    <li><a href="?p=platform_migrations">Migrations</a></li>
<?php endif; ?>

<!-- Tenant Menu (everyone) -->
<li class="slide__category">
    <span>🏢 <?php echo $current_org['name']; ?></span>
</li>
<li><a href="?p=dashboard">Dashboard</a></li>
...
```

### ✅ ข้อดี:
- 🟢 ไม่ต้องเปลี่ยน users
- 🟢 ใช้ระบบเดิม enhance เท่านั้น
- 🟢 Backward compatible

### ❌ ข้อเสีย:
- 🟡 ยังมี overlap (user เดียวเป็นได้ทั้ง 2)

---

## 💡 **คำแนะนำสำหรับคุณ**

### **ตอนนี้ (2 tenants, internal use):**

**→ Option 3 (Enhance Current System)** ✅

**เพราะ:**
- ไม่ซับซ้อน
- ใช้ระบบเดิมต่อได้
- เพิ่มแค่ checks และ UI hints

### **อนาคต (ขาย SaaS, มีหลาย tenants):**

**→ Option 1 (Separate Users)** ✅

**เพราะ:**
- Security ดีที่สุด
- ชัดเจนที่สุด
- Audit trail ง่าย

---

## 🛠️ **Implementation: Option 3 (Quick Fix)**

ให้ผมเขียน enhancement code ให้ครับ:

### 1. เพิ่ม Helper Functions

```php
// source/permission.php (เพิ่มท้ายไฟล์)

/**
 * Check if user is platform administrator
 */
function is_platform_administrator($member = null) {
    if ($member === null) {
        $member = $_SESSION['member'] ?? null;
    }
    
    if (!$member) return false;
    
    // Check platform_user table
    $coreDb = core_db();
    $id_member = (int)$member['id_member'];
    
    $stmt = $coreDb->prepare("SELECT pu.id_platform_user 
        FROM platform_user pu
        JOIN platform_user_role pur ON pur.id_platform_user = pu.id_platform_user
        JOIN platform_role pr ON pr.id_platform_role = pur.id_platform_role
        WHERE pu.id_member = ? AND pr.code = 'platform_super_admin' AND pu.status = 1
        LIMIT 1");
    
    if (!$stmt) return false;
    
    $stmt->bind_param('i', $id_member);
    $stmt->execute();
    $result = $stmt->fetch();
    $stmt->close();
    
    return (bool)$result;
}

/**
 * Check if user is tenant owner/admin
 */
function is_tenant_administrator($member = null, $org_code = null) {
    if ($member === null) {
        $member = $_SESSION['member'] ?? null;
    }
    
    if (!$member) return false;
    
    if ($org_code === null) {
        $org = resolve_current_org();
        $org_code = $org['code'] ?? null;
    }
    
    if (!$org_code) return false;
    
    // Check if user has owner/admin role in this org
    $coreDb = core_db();
    $org = fetch_org_by_code($org_code);
    
    $stmt = $coreDb->prepare("SELECT ag.group_name 
        FROM account_org ao
        JOIN account_group ag ON ag.id_group = ao.id_group
        WHERE ao.id_member = ? AND ao.id_org = ?
        LIMIT 1");
    
    $stmt->bind_param('ii', $member['id_member'], $org['id_org']);
    $stmt->execute();
    $stmt->bind_result($group_name);
    $found = $stmt->fetch();
    $stmt->close();
    
    if (!$found) return false;
    
    return in_array($group_name, ['owner', 'admin']);
}
```

### 2. อัพเดท UI

```php
// views/template/sidebar-left.template.php

<?php
$isPlatformAdmin = is_platform_administrator($logged_in_member_data);
$isTenantAdmin = is_tenant_administrator($logged_in_member_data);
?>

<!-- Platform Console (เฉพาะ platform admin) -->
<?php if ($isPlatformAdmin): ?>
<li class="slide__category">
    <span class="category-name">🌐 Platform Console</span>
</li>
<li class="slide">
    <a href="?p=admin_organizations">
        <i class="fe fe-globe"></i>
        <span>Manage Tenants</span>
    </a>
</li>
<?php endif; ?>

<!-- Tenant Section (ทุกคน) -->
<li class="slide__category">
    <span class="category-name">
        🏢 <?php echo $org['name'] ?? 'Organization'; ?>
        <?php if ($isTenantAdmin): ?>
            <small>(Admin)</small>
        <?php endif; ?>
    </span>
</li>
```

### 3. Permission Check Logic

```php
// admin_rbac.php

function must_allow_admin($member){
    // Allow if:
    // 1. Platform Super Admin (can manage all)
    // 2. Tenant owner/admin (can manage current tenant)
    
    $isPlatformAdmin = is_platform_administrator($member);
    $isTenantAdmin = is_tenant_administrator($member);
    
    if (!$isPlatformAdmin && !$isTenantAdmin) {
        http_response_code(403);
        echo json_encode(['ok'=>false,'error'=>'forbidden']);
        exit;
    }
}
```

---

## 📋 **Option Comparison**

| Criteria | Option 1 (Separate) | Option 2 (Context) | Option 3 (Enhance) |
|----------|---------------------|--------------------|--------------------|
| **Clarity** | 🟢 Excellent | 🟡 Good | 🟡 Good |
| **Security** | 🟢 Best | 🟡 Medium | 🟢 Good |
| **Complexity** | 🟡 Medium | 🔴 High | 🟢 Low |
| **User Experience** | 🟡 OK (2 logins) | 🟢 Best (1 login) | 🟢 Good |
| **Migration Effort** | 🔴 High (2-3 days) | 🔴 High (3-5 days) | 🟢 Low (1 day) |
| **เหมาะกับ** | SaaS, Large | SaaS | **Internal, Small ✅** |

---

## 🎯 **คำแนะนำของผม**

### **สำหรับ Bellavier Group ERP:**

**ตอนนี้ → Option 3** ✅

**เพราะ:**
- Internal use (ไม่ใช่ public SaaS)
- Tenants น้อย (2 tenants)
- คนดูแลคนเดียว (คุณ)
- ไม่ซับซ้อน

**แต่เพิ่ม:**
```php
// 1. Helper functions (is_platform_administrator, is_tenant_administrator)
// 2. UI hints ("🌐 Platform" vs "🏢 Tenant")
// 3. Permission checks ชัดเจนขึ้น
```

### **อนาคต (ถ้าขาย SaaS) → Option 1**

**เพราะ:**
- ต้องการ security สูง
- Admin แต่ละ tenant คนละคน
- Audit trail ชัดเจน

---

## 🚀 **Quick Implementation (Option 3)**

ให้ผมเพิ่ม helper functions ให้เลยไหมครับ?

**หรือ:**
- ปล่อยไว้แบบนี้ก่อน (ใช้ได้อยู่แล้ว)
- ทำ Option 1 เต็มรูปแบบ (2-3 วัน)

**คุณต้องการแนวทางไหนครับ?** 🤔

