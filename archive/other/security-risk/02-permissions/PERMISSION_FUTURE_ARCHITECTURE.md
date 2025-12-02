# 🔮 Permission System - Future Architecture Options

**When:** เมื่อ tenants > 50 หรือ performance เป็นปัญหา  
**Current:** Controlled Customization (Tenant DB)  
**Goal:** Scale to 100-1000+ tenants

---

## 📊 **3 แนวทางสำหรับ Re-architecture**

---

## 🏗️ **Option 1: Hybrid Model** (แนะนำ)

### Concept: Core DB + Override

```
Core DB (Master):
  ├─ permission (93 permissions) ← Master list
  └─ permission_default_assignment ← Default ว่า role ไหนได้อะไร

Tenant DB (Override Only):
  └─ tenant_permission_override ← เฉพาะที่แก้จาก default
```

### ตัวอย่าง:

```sql
-- Core DB: Default assignments
permission_default_assignment:
  role_template: "production_manager"
  permissions: ["mo.view", "mo.create", "schedule.view", ...]

-- Tenant DB: Override (เฉพาะที่ต่าง)
tenant_permission_override:
  Tenant A: production_manager + "mo.delete" (เพิ่ม)
  Tenant B: production_manager - "mo.create" (ลบ)
  Tenant C: (ไม่มี override = ใช้ default)
```

### Check Logic:

```php
function permission_allow_code($member, $code) {
  // 1. Get default from core DB
  $default = get_default_permission($role, $code); // TRUE/FALSE
  
  // 2. Check override in tenant DB
  $override = get_tenant_override($tenant, $role, $code); // TRUE/FALSE/NULL
  
  // 3. Return
  if ($override !== null) {
    return $override; // Use override
  }
  return $default; // Use default
}
```

### ✅ ข้อดี:

- 🟢 **Storage:** ประหยดมาก (เก็บเฉพาะที่แก้)
- 🟢 **Performance:** Query น้อยลง
- 🟢 **Sync:** แค่ sync defaults (1 set)
- 🟢 **Flexibility:** Tenant override ได้

### ❌ ข้อเสีย:

- 🔴 **Complexity:** Logic ซับซ้อนกว่า
- 🟡 **Migration:** ต้อง migrate ข้อมูลเดิม

### ⭐ **Best For:**
- 20-200 tenants
- ต้องการ balance ระหว่าง control และ flexibility

---

## 🌐 **Option 2: Pure Core DB** (Centralized)

### Concept: ทุกอย่างอยู่ Core DB

```
Core DB:
  ├─ permission (93 permissions)
  ├─ tenant_role (แต่อยู่ใน core!)
  └─ tenant_role_permission (แยก by tenant_id)

Tenant DB:
  └─ (ไม่มี permissions เลย, เก็บแค่ business data)
```

### Schema:

```sql
-- Core DB
CREATE TABLE tenant_role_global (
  id INT PRIMARY KEY,
  id_tenant INT,  -- เพิ่ม tenant_id
  code VARCHAR(100),
  name VARCHAR(150),
  UNIQUE KEY (id_tenant, code)
);

CREATE TABLE tenant_role_permission_global (
  id INT PRIMARY KEY,
  id_tenant INT,  -- เพิ่ม tenant_id
  id_role INT,
  id_permission INT,
  allow TINYINT(1),
  UNIQUE KEY (id_tenant, id_role, id_permission)
);
```

### Check Logic:

```php
function permission_allow_code($member, $code) {
  $coreDb = core_db();
  $tenant = get_current_tenant();
  
  // All in one query!
  $sql = "SELECT trp.allow 
          FROM tenant_role_permission_global trp
          WHERE trp.id_tenant = ? 
            AND trp.id_role = ?
            AND trp.id_permission = ?";
  
  return query_result($sql);
}
```

### ✅ ข้อดี:

- 🟢 **Simple:** Query เดียวเท่านั้น
- 🟢 **Fast:** Index ดี performance สูง
- 🟢 **No Sync:** ไม่ต้อง sync หลาย DB
- 🟢 **Centralized Backup:** Backup core DB เดียวพอ

### ❌ ข้อเสีย:

- 🔴 **Not True Multi-tenant:** ข้อมูล permissions รวมกัน
- 🔴 **Security Risk:** Tenant A อาจเห็นข้อมูล tenant B (ถ้า query ผิด)
- 🔴 **Single Point of Failure:** Core DB down = ทุกคนใช้ไม่ได้

### ⭐ **Best For:**
- Large SaaS (100-1000+ tenants)
- Performance-critical
- มี DevOps team ดูแล

---

## 🚀 **Option 3: Microservices** (Ultra Scale)

### Concept: แยก Permission เป็น Service

```
┌─────────────────────────────────────────┐
│  Permission Service (Separate)          │
│  ├─ API: /check-permission              │
│  ├─ API: /get-user-permissions          │
│  ├─ Cache: Redis                        │
│  └─ DB: permission_service_db           │
└─────────────────────────────────────────┘
           ↓ REST API ↓
┌─────────────────────────────────────────┐
│  ERP Service (Main App)                 │
│  - เรียก Permission Service ผ่าน API   │
│  - Cache results ที่ application level │
└─────────────────────────────────────────┘
```

### Check Logic:

```php
function permission_allow_code($member, $code) {
  // Call Permission Service via HTTP
  $response = http_post('http://permission-service/check', [
    'tenant_id' => get_tenant_id(),
    'user_id' => $member['id_member'],
    'permission' => $code
  ]);
  
  return $response['allowed'];
}
```

### ✅ ข้อดี:

- 🟢 **Scalability:** รองรับ 1000+ tenants
- 🟢 **Independent:** แยกการ scale permissions จาก main app
- 🟢 **Caching:** Redis cache ที่ service level
- 🟢 **Modern:** Architecture ทันสมัย

### ❌ ข้อเสีย:

- 🔴 **Complexity:** ซับซ้อนมาก
- 🔴 **Infrastructure:** ต้องมี servers แยก, load balancer
- 🔴 **Network:** เพิ่ม network latency
- 🔴 **Cost:** เพิ่มค่า infrastructure

### ⭐ **Best For:**
- Enterprise SaaS (1000+ tenants)
- Global deployment
- มี budget และ team ดูแล

---

## 📈 **Migration Path (Roadmap)**

### Phase 1: **ปัจจุบัน** (2-10 tenants)
```
✅ Controlled Customization (Tenant DB)
   - Sync permissions to tenant DB
   - Admin assigns per tenant
```

### Phase 2: **Growth** (10-50 tenants)
```
→ Optimize Current System
   - Add caching (Redis/Memcached)
   - Batch sync operations
   - Monitor performance
```

### Phase 3: **Scale** (50-200 tenants)
```
→ Option 1: Hybrid Model
   - Migrate to Core DB + Override
   - Reduce data duplication
   - Faster sync
```

### Phase 4: **Enterprise** (200+ tenants)
```
→ Option 2: Pure Core DB
   - Centralize permissions
   - Heavy caching
   - Database sharding
```

### Phase 5: **Global** (1000+ tenants)
```
→ Option 3: Microservices
   - Separate Permission Service
   - Distributed architecture
   - Multi-region deployment
```

---

## 🎯 **Decision Matrix**

| Tenants | Recommended Approach | Estimated Effort |
|---------|---------------------|------------------|
| 1-10 | ✅ **Current (Tenant DB)** | Done |
| 10-50 | Optimize + Cache | 1-2 weeks |
| 50-200 | **Option 1 (Hybrid)** | 2-4 weeks |
| 200-1000 | **Option 2 (Core DB)** | 4-8 weeks |
| 1000+ | **Option 3 (Microservices)** | 3-6 months |

---

## 🛠️ **Option 1 Implementation (Hybrid) - Sample Code**

### Database Schema:

```sql
-- Core DB
CREATE TABLE permission_role_template (
  id_template INT PRIMARY KEY AUTO_INCREMENT,
  role_code VARCHAR(100),
  permission_code VARCHAR(100),
  allow TINYINT(1) DEFAULT 1,
  UNIQUE KEY (role_code, permission_code)
);

-- Insert defaults
INSERT INTO permission_role_template (role_code, permission_code, allow) VALUES
('owner', 'mo.view', 1),
('owner', 'mo.create', 1),
('owner', 'schedule.view', 1),
-- ... all 93 permissions for owner

('production_manager', 'mo.view', 1),
('production_manager', 'mo.create', 1),
('production_manager', 'schedule.view', 1),
-- ... subset for production_manager
;

-- Tenant DB
CREATE TABLE tenant_permission_override (
  id INT PRIMARY KEY AUTO_INCREMENT,
  id_tenant_role INT,
  id_permission INT,
  allow TINYINT(1),
  UNIQUE KEY (id_tenant_role, id_permission)
);
```

### PHP Logic:

```php
function permission_allow_code_hybrid($member, $code) {
  $role = get_user_role($member);
  
  // 1. Check override first (tenant DB)
  $override = check_tenant_override($role, $code);
  if ($override !== null) {
    return $override; // Tenant customized this
  }
  
  // 2. Use default from core DB
  return check_default_template($role, $code);
}

function check_tenant_override($role, $code) {
  $tenantDb = tenant_db();
  $sql = "SELECT allow FROM tenant_permission_override tpo
          JOIN tenant_role tr ON tr.id_tenant_role = tpo.id_tenant_role
          JOIN permission p ON p.id_permission = tpo.id_permission
          WHERE tr.code = ? AND p.code = ?";
  // Return TRUE/FALSE/NULL
}

function check_default_template($role, $code) {
  $coreDb = core_db();
  $sql = "SELECT allow FROM permission_role_template
          WHERE role_code = ? AND permission_code = ?";
  // Return TRUE/FALSE
}
```

### Migration from Current:

```sql
-- 1. Extract current tenant assignments to core as defaults
INSERT INTO permission_role_template (role_code, permission_code, allow)
SELECT tr.code, p.code, trp.allow
FROM tenant_role_permission trp
JOIN tenant_role tr ON tr.id_tenant_role = trp.id_tenant_role
JOIN permission p ON p.id_permission = trp.id_permission
WHERE tr.id_tenant_role IN (SELECT id_tenant_role FROM tenant_role WHERE code = 'owner')
GROUP BY tr.code, p.code;

-- 2. Drop tenant_role_permission (if all same as defaults)
-- Or keep as override table
```

---

## 📉 **Storage Comparison**

### Current System (Tenant DB):

```
10 tenants × 93 permissions × 18 roles = 16,740 rows
50 tenants × 93 permissions × 18 roles = 83,700 rows
100 tenants × 93 permissions × 18 roles = 167,400 rows
```

### Hybrid Model:

```
Core: 93 permissions × 18 roles = 1,674 rows (default)
Tenant overrides: ~5% different = 8,370 rows (100 tenants)
Total: ~10,000 rows (save 94%)
```

### Pure Core DB:

```
Core: All assignments in one place
Total: 167,400 rows (but single DB, better index)
```

---

## ⚡ **Performance Comparison**

| Approach | Query Count | Latency | Cache Hit |
|----------|-------------|---------|-----------|
| **Current (Tenant DB)** | 3 queries | ~10ms | N/A |
| **+ Redis Cache** | 1 query | ~2ms | 90% |
| **Hybrid** | 1-2 queries | ~5ms | 95% |
| **Pure Core** | 1 query | ~3ms | 98% |
| **Microservices** | 1 HTTP call | ~15ms | 99% |

---

## 🎯 **คำแนะนำตาม Use Case**

### **Use Case คุณ: Atelier → Maison (5-20 tenants)**

**Phase 1 (Now - 2 years):**
```
✅ Current System (Tenant DB)
   + Add Redis cache
   
Effort: 2-3 days (cache only)
```

**Phase 2 (2-5 years):**
```
→ Option 1 (Hybrid)
   + Migrate to default + override model
   
Effort: 2-4 weeks
```

---

### **Use Case: SaaS Platform (50-200 tenants)**

**From Start:**
```
→ Option 1 (Hybrid)
   Better foundation for scale
```

**Or:**
```
→ Option 2 (Pure Core DB)
   Simpler, faster, but less isolation
```

---

### **Use Case: Enterprise SaaS (200+ tenants)**

**From Start:**
```
→ Option 2 (Pure Core DB)
   + Heavy caching (Redis Cluster)
   + Database sharding
```

**Or:**
```
→ Option 3 (Microservices)
   Complete separation of concerns
```

---

## 🔄 **Migration Strategy (Current → Hybrid)**

### Step 1: Create Default Templates (1 week)

```sql
-- Analyze current tenant assignments
-- Find common patterns
-- Create defaults in core DB

-- Example: 95% of tenants give production_manager the same permissions
-- → Make that the default
-- → 5% can override
```

### Step 2: Implement Hybrid Logic (1 week)

```php
// New functions:
- get_default_permissions($role)
- get_tenant_overrides($tenant, $role)
- merge_permissions($defaults, $overrides)
```

### Step 3: Migrate Data (3-5 days)

```sql
-- For each tenant:
-- 1. Compare with defaults
-- 2. Keep only differences as overrides
-- 3. Drop redundant data
```

### Step 4: Test & Deploy (1 week)

---

## 💰 **Cost-Benefit Analysis**

### **ถ้าอยู่ที่ 10 tenants:**

**Current System:**
- Storage: ~1 MB
- Query time: 10ms
- **Cost:** Free (included)

**Re-architect:**
- Effort: 2-4 weeks
- Benefit: Minimal
- **ROI:** ❌ Not worth it

---

### **ถ้าอยู่ที่ 100 tenants:**

**Current System:**
- Storage: ~10 MB
- Query time: 15ms
- Sync time: 5-10 minutes

**Re-architect (Hybrid):**
- Storage: ~2 MB (save 80%)
- Query time: 5ms (faster 3x)
- Sync time: 30 seconds (faster 10x)
- Effort: 2-4 weeks
- **ROI:** ✅ Worth it!

---

## 🎯 **สรุปสำหรับคุณ**

### คำถาม: "ถ้า re-architect ทำยังไง?"

**คำตอบ:**

#### **ถ้า 10-50 tenants:**
```
→ Option 1 (Hybrid Model)
   - Core DB: defaults
   - Tenant DB: overrides only
   - Best balance
```

#### **ถ้า 50-200 tenants:**
```
→ Option 2 (Pure Core DB)
   - Centralize everything
   - Heavy caching
   - Simpler but less isolated
```

#### **ถ้า 200+ tenants:**
```
→ Option 3 (Microservices)
   - Separate Permission Service
   - Distributed architecture
   - Expensive but scales infinitely
```

---

## ⏰ **When to Re-architect?**

### Triggers (เมื่อเจอข้อใดข้อหนึ่ง):

1. ✅ **Tenants > 30** และ sync ใช้เวลา > 5 นาที
2. ✅ **Performance:** Permission check > 50ms
3. ✅ **Storage:** Tenant DB > 100 MB (เฉพาะ permissions)
4. ✅ **Maintenance:** Sync errors บ่อย

### **ตอนนี้ (2 tenants):**

❌ ยัง**ไม่ถึงเวลา** re-architect  
✅ ใช้ระบบปัจจุบันต่อได้เลย  
⏰ Review อีกครั้งเมื่อ tenants > 20

---

## 📚 **Summary Table**

| Metric | Current | Hybrid | Core DB | Microservices |
|--------|---------|--------|---------|---------------|
| **Tenants Limit** | 10-30 | 30-200 | 200-1000 | 1000+ |
| **Complexity** | 🟢 Low | 🟡 Medium | 🟡 Medium | 🔴 High |
| **Performance** | 🟡 OK | 🟢 Good | 🟢 Great | 🟢 Excellent |
| **Isolation** | 🟢 Full | 🟢 Full | 🟡 Partial | 🟢 Full |
| **Cost** | 🟢 $0 | 🟡 $$ | 🟡 $$ | 🔴 $$$$ |
| **Effort** | ✅ Done | 2-4 weeks | 4-6 weeks | 3-6 months |

---

## ✅ **Final Recommendation**

### สำหรับ Bellavier Group ERP:

**ปัจจุบัน (2-10 tenants):**
```
✅ ใช้ระบบปัจจุบันต่อ (Tenant DB)
✅ เพิ่ม Redis cache (optional)
```

**อนาคต (20-50 tenants):**
```
→ Migrate to Hybrid Model
   Timeline: เมื่อเห็น performance issues
   Effort: 2-4 weeks
```

**อนาคตไกล (100+ tenants):**
```
→ Re-evaluate ตอนนั้น
   อาจเป็น Pure Core DB หรือ Microservices
```

---

**มั่นใจได้ครับว่าแนวทางปัจจุบันเหมาะสม และมีแผน B, C, D สำหรับอนาคต!** ✅

**ต้องการให้ผมเขียน code สำหรับ Option ไหนเป็นตัวอย่างเพิ่มไหมครับ?** 😊

