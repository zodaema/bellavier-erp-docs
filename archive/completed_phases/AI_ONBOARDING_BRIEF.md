# 🤖 AI Agent Onboarding Brief - Bellavier ERP

**Session Handoff:** November 5, 2025  
**Purpose:** Quick context for new AI agent to continue seamlessly  
**Status:** Planning complete → Ready for implementation

---

## 📊 **Current System Status (60/100)**

**Foundation:** 80% ✅ (Database + Services strong)  
**User Experience:** 40% ⚠️ (Critical gaps identified)  
**Overall:** 60% (Honest assessment after full analysis)

---

## 🎯 **What Just Happened (Nov 5 Planning Session)**

### ✅ **Completed Today:**
1. **Master Blueprint** - 16-section complete system design
2. **Gap Analysis** - Identified what's missing (40%)
3. **6-Week Roadmap** - Clear path to 100%
4. **Production Control Center Design** - Unified dashboard planned
5. **Documentation Cleanup** - 25 files removed/archived

### 📋 **Key Decisions Made:**
- MO = OEM only (hardcode production_type)
- Hatthasilpa Jobs = Atelier only (already hardcoded)
- Hybrid = Use both systems separately (linked via id_mo)
- Token cancellation needs 3 types (QC Fail, Redesign, Permanent)
- Graph designer needs validation rules

---

## 📚 **MANDATORY READING (Before Starting ANY Task)**

### **Step 1: Understand Current State (10 minutes)**
```
1. STATUS.md
   → Current: 60/100
   → What's done: Foundation (80%)
   → What's missing: UX (40%)

2. ROADMAP_V4.md
   → 6-week plan to 100%
   → Week 1: Critical fixes
   → Week 2-3: Work Item System
   → Week 4-5: Assignment Engine
   → Week 6: Control Center
```

### **Step 2: Understand Master Design (30 minutes)**
```
3. docs/DUAL_PRODUCTION_MASTER_BLUEPRINT.md ⭐⭐⭐
   → 16 sections covering entire system
   → Core philosophy: "Flow ไม่ขาด, งานไม่หาย, คนไม่หลง"
   → Token lifecycle
   → Work Item System (to implement)
   → Assignment Engine (to implement)
   → Multi-operator nodes
   → Manager/Operator workflows
```

### **Step 3: Understand Gaps (15 minutes)**
```
4. docs/IMPLEMENTATION_STATUS_MAP.md
   → What's implemented (60%)
   → What's missing (40%)
   → Priority matrix
   → Phase-by-phase plan
```

### **Step 4: Check Project Structure (5 minutes)**
```
5. QUICK_START.md
   → Project overview
   → Tech stack
   → File structure
   → Navigation guide
```

---

## 🚀 **What to Implement Next**

### **Week 1: Critical Fixes (Start Here!)**

#### **Day 1-2: Token Cancellation System** (4-6 hours)
**Problem:** Cancel token → Job breaks (99/100 tokens left)

**Solution:** 3 cancellation types
```sql
-- Add columns
ALTER TABLE flow_token 
ADD COLUMN cancellation_type ENUM('qc_fail', 'redesign', 'permanent') NULL,
ADD COLUMN replacement_token_id INT(11) NULL,
ADD COLUMN redesign_required TINYINT(1) DEFAULT 0;
```

**Implementation:**
- [ ] Add database columns (migration)
- [ ] Implement `cancelToken()` with 3 types
- [ ] Implement `spawnReplacementToken()`
- [ ] Implement `markForRedesign()`
- [ ] Create redesign dashboard UI
- [ ] Update Token Management UI
- [ ] Write tests

**Files to Create/Modify:**
- `database/tenant_migrations/2025_11_token_cancellation.php`
- `source/service/TokenLifecycleService.php` (update)
- `source/token_management_api.php` (update)
- `views/token_management.php` (add cancel type selector)
- `page/token_redesign.php` (new)
- `views/token_redesign.php` (new)

---

#### **Day 3-4: Graph Validation Rules** (4-6 hours)
**Problem:** No validation, no serial requirements, no edge rules

**Solution:** Graph validation service

**Implementation:**
- [ ] Create `GraphValidationService.php`
- [ ] Implement serial number rules per node type
- [ ] Implement edge type validation
- [ ] Implement node connection rules
- [ ] Add validation to Graph Designer UI
- [ ] Write tests

**Files to Create/Modify:**
- `source/service/GraphValidationService.php` (new)
- `source/routing_graph_api.php` (add validation)
- `views/routing_graph_designer.php` (add validation feedback)
- `assets/javascripts/routing/designer.js` (update)

---

#### **Day 5: Fix MO = OEM Only** (2 hours)
**Problem:** MO allows production_type selection (should be OEM only)

**Solution:** Hardcode

**Implementation:**
- [ ] Remove production_type dropdown from MO form
- [ ] Hardcode `$production_type = 'oem'` in source/mo.php
- [ ] Update menu label: "Manufacturing Orders (OEM)"
- [ ] Add schedule/update_due/cancel endpoints
- [ ] Test workflow

**Files to Modify:**
- `source/mo.php` (line 135 - hardcode 'oem')
- `views/mo.php` (remove dropdown)
- `views/template/sidebar-left.template.php` (update menu)

---

## 🗂️ **Project Structure (CRITICAL - Follow This!)**

```
index.php                    # Router (loads page/ + views/)
├─ page/                     # Page definitions ($page_detail)
│  └─ {name}.php             # CSS/JS includes, permission
├─ views/                    # HTML templates
│  └─ {name}.php             # UI structure
├─ source/                   # Backend APIs
│  ├─ {module}.php           # API endpoints
│  └─ service/               # Business logic
│     └─ {Name}Service.php   # PascalCase
└─ assets/javascripts/       # Frontend JS
   └─ {module}/
      └─ {name}.js           # snake_case
```

**DO NOT:**
- ❌ Create files in wrong folders (check existing patterns!)
- ❌ Use wrong naming conventions
- ❌ Create .sql files (use PHP migrations!)
- ❌ Skip the mandatory reading above

---

## 🔑 **Key Technical Patterns**

### **Database Migrations:**
```php
// database/tenant_migrations/YYYY_MM_description.php
require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    migration_add_column_if_missing($db, 'table', 'column', 'definition');
    migration_add_index_if_missing($db, 'table', 'index_name', 'definition');
};
```

### **API Endpoints:**
```php
// source/{module}.php
session_start();
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/model/member_class.php';
require_once __DIR__ . '/permission.php';

// Check permission
if (!permission_allow_code($member, 'permission.code')) {
    json_error('Permission denied', 403);
}

// Use prepared statements!
$stmt = $db->prepare("SELECT * FROM table WHERE id = ?");
$stmt->bind_param('i', $id);
$stmt->execute();
```

### **Page Definition:**
```php
// page/{name}.php
$page_detail['name'] = translate('key', 'Default');
$page_detail['permission_code'] = 'permission.code';

// CSS
$page_detail['css'][1] = domain::getDomain().'/assets/vendor/datatables/css/dataTables.bootstrap5.css';

// JS Libraries [1-5]
$page_detail['jquery'][1] = domain::getDomain().'/assets/vendor/datatables/js/dataTables.js';

// Custom JS [6+]
$page_detail['jquery'][6] = domain::getDomain().'/assets/javascripts/module/name.js?v='.time();
```

---

## ⚠️ **Critical Rules (MUST Follow)**

### **Database:**
- ✅ Use PHP migrations (NOT .sql files)
- ✅ Use prepared statements (security)
- ✅ Filter soft-deleted records (deleted_at IS NULL)
- ✅ Use migration helpers (idempotency)

### **Code:**
- ✅ Follow project structure (page/ → views/ → source/)
- ✅ Use existing services (don't recreate)
- ✅ Write tests for all features
- ✅ Use json_success() and json_error()

### **Documentation:**
- ✅ Update STATUS.md when done
- ✅ Update CHANGELOG_NOV2025.md
- ❌ Don't create new .md files unless major milestone

---

## 📖 **Reference Documents (Available)**

**When working on:**
- Database → `docs/DATABASE_SCHEMA_REFERENCE.md`
- Services → `docs/SERVICE_API_REFERENCE.md`
- APIs → `docs/API_REFERENCE.md`
- Troubleshooting → `docs/TROUBLESHOOTING_GUIDE.md`
- Security → `docs/PRODUCTION_HARDENING.md`
- Risks → `docs/RISK_PLAYBOOK.md`

---

## 🎯 **Your First Task**

**Start with:** Week 1, Day 1 - Token Cancellation System

**Before coding:**
1. ✅ Read ROADMAP_V4.md (Week 1 section)
2. ✅ Read DUAL_PRODUCTION_MASTER_BLUEPRINT.md (Section 4.3)
3. ✅ Check existing TokenLifecycleService.php
4. ✅ Plan migration + service changes
5. ✅ Start implementation

**Estimated Time:** 4-6 hours  
**Expected Result:** Jobs never break when tokens cancelled

---

## 💬 **Quick Context**

**Current Score:** 60/100  
**Goal:** 100/100 (6 weeks)  
**Phase:** Week 1 - Critical Fixes  
**Priority:** Fix token cancellation + graph validation  

**What's Done:**
- ✅ Database (35+ tables, 21 migrations)
- ✅ Services (8 core services)
- ✅ Manager tools (3 pages)
- ✅ Token flow working

**What's Missing:**
- ❌ Token cancellation (replacement/redesign)
- ❌ Graph validation
- ❌ Work Item System
- ❌ Assignment Engine
- ❌ Production Control Center

---

## 🚀 **Start Command**

**Ask me:**
> "ผมพร้อมเริ่ม Week 1, Day 1 (Token Cancellation) แล้วครับ ให้เริ่มจากอะไรก่อน?"

**I will:**
1. Confirm you've read the mandatory docs
2. Guide you through the implementation step-by-step
3. Help you create migrations, services, UI, tests
4. Review and test together

---

**Status:** Ready to continue seamlessly! 🚀  
**Next Agent:** Read this brief → Ask to start → Begin implementation

