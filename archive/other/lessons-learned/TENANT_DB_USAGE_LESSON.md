# บทเรียน: การใช้งาน tenant_db() ที่ถูกต้อง

**Date:** 2025-11-11  
**Issue:** "not_found" error ใน Phase 5 tests  
**Root Cause:** ความไม่เข้าใจระบบ multi-tenant และการใช้งาน `tenant_db()`  
**Status:** ✅ แก้ไขแล้ว

---

## 🐛 ปัญหาที่พบ

### อาการ
- Phase 5 tests ได้ error `{"ok":false,"error":"not_found","app_code":"DAG_ROUTING_404_GRAPH"}`
- Graph ที่สร้างใน test หาไม่เจอเมื่อเรียก API

### สาเหตุจริง
**ไม่ใช่บัคของ DAG แต่เป็นความไม่เข้าใจระบบ multi-tenant**

---

## 🔍 สาเหตุหลัก

### 1. **การใช้ `tenant_db()` โดยไม่ส่ง parameter**

**❌ ผิด:**
```php
$tenantDb = tenant_db(); // ไม่ส่ง org code
```

**✅ ถูก:**
```php
$org = resolve_current_org();
if (!$org) {
    json_error('no_org', 403);
}
$tenantDb = tenant_db($org['code']); // ส่ง org code ชัดเจน
```

**ทำไมถึงผิด:**
- `tenant_db()` มี fallback mechanism ที่หา org จาก session/cookie/domain
- ใน test environment, session อาจยังไม่ set → fallback ไป `DEFAULT` tenant
- Graph สร้างใน `maison_atelier` แต่ API query จาก `default` → หาไม่เจอ

---

### 2. **การ query `member` table จาก tenant DB**

**❌ ผิด:**
```php
$actorRow = $db->fetchOne("SELECT name FROM member WHERE id_member = ?", [$actorId]);
// $db = DatabaseHelper($tenantDb) → query จาก tenant DB
```

**✅ ถูก:**
```php
$coreDb = core_db();
$actorStmt = $coreDb->prepare("SELECT name FROM bgerp.account WHERE id_member = ?");
// Query จาก core DB
```

**ทำไมถึงผิด:**
- `member` table (หรือ `account` table) อยู่ใน **core DB** (`bgerp`)
- ไม่ได้อยู่ใน tenant DB (`bgerp_t_maison_atelier`)
- Query จาก tenant DB → Table not found

---

### 3. **การใช้ `header()` ใน test mode**

**❌ ผิด:**
```php
header('Cache-Control: public, max-age=30');
// ใน test mode → PHPUnit ส่ง output แล้ว → headers already sent
```

**✅ ถูก:**
```php
safeHeader('Cache-Control: public, max-age=30');
// safeHeader() ตรวจสอบ BGERP_TEST_MODE ก่อน
```

**ทำไมถึงผิด:**
- PHPUnit ส่ง output (progress dots, test names) ก่อน API response
- `header()` ถูกเรียกหลังจาก output → "headers already sent" error

---

## 📚 บทเรียนที่ได้

### 1. **Multi-Tenant Architecture**

**หลักการ:**
- **Core DB** (`bgerp`) = ข้อมูล global (users, organizations, permissions)
- **Tenant DB** (`bgerp_t_{org_code}`) = ข้อมูลเฉพาะ tenant (graphs, nodes, edges, products)

**กฎเหล็ก:**
- ✅ **ต้อง** resolve org context ก่อนเรียก `tenant_db()`
- ✅ **ต้อง** ส่ง `$org['code']` ให้ `tenant_db()` ชัดเจน
- ✅ **ต้อง** query `account`/`member` จาก core DB
- ✅ **ต้อง** query tenant data จาก tenant DB

---

### 2. **Test Environment Setup**

**ลำดับที่ถูกต้อง:**
```php
protected function setUp(): void
{
    // 1. Set up session FIRST
    if (session_status() === PHP_SESSION_NONE) {
        @session_start();
    }
    $_SESSION['current_org_code'] = 'maison_atelier';
    $_SESSION['current_org_id'] = 1;
    
    // 2. Resolve org context
    $org = resolve_current_org();
    if (!$org) {
        $this->fail('Cannot resolve organization context');
    }
    
    // 3. Get tenant DB with explicit org code
    $this->db = tenant_db($org['code']);
    
    // 4. Create test data
    $this->testGraphId = $this->createTestGraph();
}
```

---

### 3. **Cross-Database Queries**

**Pattern ที่ถูกต้อง (2-step approach):**
```php
// Step 1: Query from tenant DB
$graphs = $db->fetchAll("SELECT * FROM routing_graph WHERE ...");

// Step 2: Extract user IDs
$userIds = array_column($graphs, 'created_by');

// Step 3: Query from core DB
$coreDb = core_db();
$userStmt = $coreDb->prepare("SELECT id_member, name FROM bgerp.account WHERE id_member IN (?)");
// ...

// Step 4: Merge results
foreach ($graphs as &$graph) {
    $graph['created_by_name'] = $userMap[$graph['created_by']] ?? null;
}
```

**❌ ห้าม:**
```php
// Cross-DB JOIN ใน prepared statement → ไม่ทำงาน!
$stmt = $tenantDb->prepare("
    SELECT g.*, u.name 
    FROM routing_graph g 
    LEFT JOIN bgerp.account u ON u.id_member = g.created_by
");
```

---

### 4. **Test Mode Headers**

**ใช้ `safeHeader()` แทน `header()`:**
```php
if (!function_exists('safeHeader')) {
    function safeHeader(string $header, bool $replace = true, ?int $httpResponseCode = null): void {
        if (!defined('BGERP_TEST_MODE') || !BGERP_TEST_MODE) {
            // Only send headers if NOT in test mode
            if ($httpResponseCode !== null) {
                header($header, $replace, $httpResponseCode);
            } else {
                header($header, $replace);
            }
        }
    }
}
```

---

## ✅ สรุปการแก้ไข

### ไฟล์ที่แก้ไข:

1. **`tests/Integration/DAGRoutingPhase5Test.php`**
   - แก้ไข `setUp()` ให้ resolve org ก่อนเรียก `tenant_db()`
   - เพิ่ม session setup ใน `callApi()`

2. **`source/dag_routing_api.php`**
   - แก้ไข query `member` table → ใช้ core DB แทน tenant DB
   - เปลี่ยน `header()` ทั้งหมดเป็น `safeHeader()`
   - เพิ่ม error details ใน test mode

3. **`source/pwa_scan_api.php`**
   - แก้ไข `columnExists()` cache key → เพิ่ม tenant code

4. **`source/BGERP/Helper/Idempotency.php`**
   - แก้ไข storage path → แยกตาม tenant

---

## 🎯 Checklist สำหรับอนาคต

เมื่อสร้าง API ใหม่หรือแก้ไข API:

- [ ] ใช้ `resolve_current_org()` ก่อนเรียก `tenant_db()`
- [ ] ส่ง `$org['code']` ให้ `tenant_db()` ชัดเจน
- [ ] Query `account`/`member` จาก core DB (`bgerp.account`)
- [ ] Query tenant data จาก tenant DB (`bgerp_t_{org_code}`)
- [ ] ใช้ `safeHeader()` แทน `header()` ในทุกที่
- [ ] Test environment setup ต้อง set session ก่อนเรียก `tenant_db()`
- [ ] Cross-DB queries ใช้ 2-step pattern (ไม่ใช้ JOIN)

---

## 📖 เอกสารอ้างอิง

- `config.php` - `tenant_db()` function definition
- `docs/security-risk/TENANT_CACHE_AUDIT.md` - Cache security audit
- `docs/archive/2025-q4/PHP82_TENANT_SWITCHING_FIX.md` - PHP 8.2 tenant switching fix

---

**สรุป:** ปัญหา "not_found" ไม่ใช่บัคของ DAG แต่เป็นความไม่เข้าใจระบบ multi-tenant และการใช้งาน `tenant_db()` ที่ถูกต้อง ✅

