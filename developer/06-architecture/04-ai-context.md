# 🤖 Context for Future AI Agents

**Created:** November 2, 2025  
**Last Updated:** December 6, 2025  
**Purpose:** Critical context for AI agents working on this codebase  
**Read This:** Before making any major changes

---

## 🎯 **Current System State (December 2025)**

### **System is Production Ready:**
```
✅ SuperDAG Engine - Complete (Token flow, parallel execution, self-healing)
✅ Component Architecture V2 - Complete (3-layer model)
✅ Product Readiness - Complete (Configuration validation)
✅ Material Requirement - Complete (Backend: calculate, reserve, allocate)
✅ QC Rework V2 - Complete (Component-aware, defect-based)
✅ Graph Linter - Complete (30+ validation rules)
✅ MCI (Component Injection) - Complete

✅ Node Behavior UI - Complete (Task 27.20)
✅ Material Integration UI - Complete (Task 27.21)
✅ Work Modal Refactor - Complete (Task 27.24)
✅ Permission UI Improvement - Complete (Task 27.25)
✅ Token Card Component Refactor - Complete (Task 27.22)
✅ Token Card Logic Issues - Complete (Task 27.22.1)
✅ Permission Engine Refactor - Phase 0-4 Complete (Task 27.23)
```

### **What's Working:**
- ✅ Dual production lines (Hatthasilpa/DAG + Classic/Linear)
- ✅ Token-based tracking for Hatthasilpa
- ✅ WIP log-based tracking for Classic
- ✅ Component Mapping (graph anchor → product component)
- ✅ Product Readiness validation
- ✅ Material Requirement calculation (backend)
- ✅ 104+ tests passing

---

## 🔍 **How to Identify System Version**

### **Check Production Line:**
```php
// Product determines routing mode
if ($product['production_line'] === 'hatthasilpa') {
    // Uses DAG routing
    // Graph binding required
    // Component mapping required
    // Token-based tracking
}

if ($product['production_line'] === 'classic') {
    // Uses Linear routing
    // No graph binding (deprecated)
    // Component Mapping tab hidden
    // WIP log-based tracking
}
```

### **Check Token vs WIP:**
```php
// Hatthasilpa uses tokens
$tokens = db_fetch_all($db, "SELECT * FROM flow_token WHERE id_job = ?", [$jobId]);

// Classic uses WIP logs
$logs = db_fetch_all($db, "SELECT * FROM atelier_wip_log WHERE id_job_ticket = ? AND deleted_at IS NULL", [$ticketId]);
```

---

## 📚 **Essential Reading Order**

### **For Understanding Current System:**
1. `docs/super_dag/SYSTEM_CURRENT_STATE.md` - Current state overview
2. `docs/super_dag/DOCUMENTATION_INDEX.md` - Full documentation index
3. `docs/super_dag/01-concepts/PRODUCT_COMPONENT_ARCHITECTURE.md` - Component model
4. `docs/DATABASE_SCHEMA_REFERENCE.md` - Table structures

### **For Understanding Tasks:**
1. `docs/super_dag/tasks/MASTER_IMPLEMENTATION_ROADMAP.md` - Roadmap
2. `docs/super_dag/tasks/TASK_PRIORITY_ANALYSIS.md` - Current task status
3. `docs/super_dag/tasks/task27.20_WORK_MODAL_BEHAVIOR.md` - ✅ Complete
4. `docs/super_dag/tasks/task27.21.1_REWORK_MATERIAL_RESERVE_PLAN.md` - ✅ Complete
5. `docs/super_dag/tasks/task27.22_TOKEN_CARD_COMPONENT_REFACTOR.md` - ✅ Complete
6. `docs/super_dag/tasks/task27.22.1_TOKEN_CARD_LOGIC_ISSUES.md` - ✅ Complete
7. `docs/super_dag/tasks/task27.23_PERMISSION_ENGINE_REFACTOR.md` - Phase 0-4 Complete
8. `docs/super_dag/tasks/task27.24_WORK_MODAL_REFACTOR.md` - ✅ Complete
9. `docs/super_dag/tasks/task27.25_PERMISSION_UI_IMPROVEMENT.md` - ✅ Complete

### **For Making Changes:**
1. `docs/DEVELOPER_POLICY.md` - Coding standards
2. `docs/developer/02-api-development/` - API development guide
3. `.cursorrules` - Project rules

---

## 🎓 **Key Architectural Decisions**

### **Decision 1: 3-Layer Component Architecture**

**Structure:**
```
Layer 1: component_type_catalog (Generic Types)
├─ 24 types: BODY, FLAP, STRAP, HANDLE, LINING, etc.
├─ Used in Graph Designer as anchor_slot
└─ Fixed catalog - rarely changes

Layer 2: product_component (Product-Specific)
├─ Per-product components: "BODY สำหรับ Aimee Mini สีเขียว"
├─ Links to Layer 1 type
└─ Created in Product → Components tab

Layer 3: product_component_material (BOM)
├─ Materials for each component
├─ Quantity, UoM, waste factor
└─ Used for material requirement calculation
```

**Why this structure:**
- ✅ Separates generic types from product-specific components
- ✅ Allows same graph to work with different products
- ✅ BOM tied to component, not product directly
- ✅ Component Mapping connects graph to product

### **Decision 2: Reserve Materials at Job Creation**

**Flow:**
```
Job Creation
    ↓
1. Calculate BOM requirements (qty × BOM per piece)
2. Check available stock (on_hand - reserved)
3. Reserve materials (material_reservation)
    ↓
Job Execution
    ↓
4. Allocate at CUT node (material_allocation)
5. Consume when complete
```

**Why at Job Creation:**
- ✅ Prevents "double-booking" of materials
- ✅ Shows accurate availability for new jobs
- ✅ Planners see shortage warnings early
- ✅ No race conditions when multiple jobs start

### **Decision 3: Product Readiness Validation**

**Criteria (Hatthasilpa):**
```
✓ Production Line = 'hatthasilpa'
✓ Graph Binding (has bound graph)
✓ Graph Published
✓ Graph has START node
✓ Has Components (at least 1)
✓ Each Component has Materials (BOM)
✓ Component Mapping complete (all anchor_slots mapped)
```

**Criteria (Classic):**
```
✓ Production Line = 'classic'
✓ Has Components (at least 1)
✓ Each Component has Materials (BOM)
```

**Why:**
- ✅ Prevents job creation from incomplete products
- ✅ Ensures all downstream systems work correctly
- ✅ Clear feedback to users about what's missing

---

## 🚨 **Common Mistakes to Avoid**

### **Mistake 1: Forgetting i18n**
```php
// ❌ WRONG - Hardcoded Thai
json_error('วัสดุไม่เพียงพอ', 400);

// ✅ CORRECT - English default with translation key
json_error(translate('material.shortage', 'Material shortage'), 400);
```

```javascript
// ❌ WRONG
notifyError('วัสดุไม่เพียงพอ');

// ✅ CORRECT
notifyError(t('material.shortage', 'Material shortage'));
```

### **Mistake 2: Wrong Column Names**
```php
// ❌ WRONG - Old column name
SELECT pc.component_type FROM product_component pc

// ✅ CORRECT - Current column name
SELECT pc.component_type_code FROM product_component pc
```

```php
// ❌ WRONG - Old column name
SELECT ct.type_group FROM component_type_catalog ct

// ✅ CORRECT - Current column name
SELECT ct.category FROM component_type_catalog ct
```

### **Mistake 3: Missing Soft-Delete Filter**
```php
// ❌ WRONG - No filter
SELECT * FROM atelier_wip_log WHERE id_job_ticket = ?

// ✅ CORRECT - Filter deleted
SELECT * FROM atelier_wip_log WHERE id_job_ticket = ? AND deleted_at IS NULL
```

### **Mistake 4: Wrong API Response Check**
```javascript
// ❌ WRONG
if (response.success) { ... }

// ✅ CORRECT
if (response.ok) { ... }
```

### **Mistake 5: bind_param Order**
```php
// ❌ WRONG - Parameters in wrong order
$stmt = $db->prepare("INSERT INTO table (col_a, col_b) VALUES (?, ?)");
$stmt->bind_param('ii', $b, $a);  // Wrong order!

// ✅ CORRECT - Match SQL order
$stmt->bind_param('ii', $a, $b);  // Match INSERT order
```

### **Mistake 6: Creating Features for Classic DAG**
```
❌ Classic DAG mode was deprecated in Task 25.3-25.5
❌ Don't create graph binding features for Classic products
✅ Classic uses Linear routing only (job_ticket → tasks → wip_logs)
✅ Classic products hide Component Mapping tab
```

---

## 🔮 **Future Development Guidelines**

### **When Adding New Features:**

**Ask yourself:**
1. Does this affect Hatthasilpa, Classic, or both?
2. Does this need i18n (translation)?
3. Does this need API validation?
4. Does this affect Product Readiness?
5. Are there existing services/patterns to follow?

### **When Working on Material System:**

**Key formulas:**
```
available_for_new_jobs = on_hand - reserved
required_qty = BOM_qty × job_qty × waste_factor
shortage = MAX(0, required_qty - available)
```

**Services to use:**
- `MaterialRequirementService` - Calculate requirements
- `MaterialReservationService` - Reserve/release stock
- `MaterialAllocationService` - Consume materials

### **When Working on Node Behavior:**

**Files to modify:**
- `assets/javascripts/dag/behavior_ui_templates.js` - UI templates
- `source/pwa_scan_v2_api.php` - API handlers
- `assets/javascripts/pwa_scan/pwa_scan.js` - PWA integration

**Existing behaviors:**
- `CUT` - Material cutting, quantity input
- `STITCH` - Sewing operations
- `QC_PASS` - Quality check pass
- `QC_FAIL` - Quality check fail + rework
- More defined in `behavior_ui_templates.js`

---

## 📊 **Database Quick Reference**

### **Core Tables (December 2025):**

```sql
-- Component Architecture V2
component_type_catalog      -- 24 generic types
product_component           -- Product-specific components
product_component_material  -- BOM per component
graph_component_mapping     -- anchor_slot → product_component

-- Material System
material_requirement        -- Calculated requirements
material_reservation        -- Reserved stock
material_allocation         -- Consumed materials
v_material_available        -- Available stock view
v_job_material_status       -- Job material summary view

-- QC & Defect
defect_category             -- 8 categories
defect_catalog              -- 36 defects
qc_rework_override_log      -- Supervisor override audit

-- Audit
product_config_log          -- Product config changes
component_injection_log     -- MCI audit
```

### **Key Relationships:**
```
product
    ↓
product_component (via id_product)
    ↓
product_component_material (via id_product_component)
    
routing_graph
    ↓
routing_node (via id_graph)
    ↓
graph_component_mapping (via id_graph, anchor_slot)
    ↓
product_component (via id_product_component)
```

---

## 🧪 **Testing Guidelines**

### **Run Tests:**
```bash
# All tests
vendor/bin/phpunit

# Specific file
vendor/bin/phpunit tests/Unit/ProductReadinessServiceTest.php

# With coverage
vendor/bin/phpunit --coverage-html coverage/
```

### **Test Patterns:**
```php
// Unit test
public function testMaterialCalculation(): void {
    $service = new MaterialRequirementService($this->db);
    $result = $service->calculateForJob($jobId, $productId, 20);
    
    $this->assertArrayHasKey('requirements', $result);
    $this->assertGreaterThan(0, count($result['requirements']));
}

// Integration test
public function testProductReadinessAPI(): void {
    $response = $this->callAPI('get_product_readiness', ['product_id' => 1]);
    
    $this->assertTrue($response['ok']);
    $this->assertArrayHasKey('is_ready', $response);
}
```

---

## 🎯 **Your Mission (Future AI Agent)**

### **If Working on Task 27.20 (Work Modal Behavior):**
1. Read: `docs/super_dag/tasks/task27.20_WORK_MODAL_BEHAVIOR.md` ✅ Complete
2. See: `docs/super_dag/tasks/archive/results/task27.20_results.md`
3. Files: `assets/javascripts/pwa_scan/WorkModalController.js`

### **If Working on Task 27.21.1 (Rework Material Reserve):**
1. Read: `docs/super_dag/tasks/task27.21.1_REWORK_MATERIAL_RESERVE_PLAN.md` ✅ Complete
2. See: `docs/super_dag/tasks/archive/results/task27.21.1_results.md`
3. Migration: `database/tenant_migrations/2025_12_rework_material_logging.php`
4. Service: `source/BGERP/Service/MaterialAllocationService.php`
5. API: `source/dag_token_api.php` (handleScrapMaterials integration)

### **If Working on Task 27.22 (Token Card Component):**
1. Read: `docs/super_dag/tasks/task27.22_TOKEN_CARD_COMPONENT_REFACTOR.md` ✅ Complete
2. Files: `assets/javascripts/pwa_scan/token_card/TokenCardComponent.js`
3. Architecture: Single component pattern (State → Parts → Layouts)

### **If Working on Task 27.22.1 (Token Card Logic Issues):**
1. Read: `docs/super_dag/tasks/task27.22.1_TOKEN_CARD_LOGIC_ISSUES.md` ✅ Complete
2. See: `docs/super_dag/00-audit/` for audit reports
3. Specs: `docs/super_dag/specs/QC_POLICY_RULES.md`

### **If Working on Task 27.23 (Permission Engine):**
1. Read: `docs/super_dag/tasks/task27.23_PERMISSION_ENGINE_REFACTOR.md` (Phase 0-4 Complete)
2. Service: `source/BGERP/Service/PermissionEngine.php`
3. Pattern: `ACTION_PERMISSIONS` mapping in API files

### **If Working on Task 27.24 (Work Modal Refactor):**
1. Read: `docs/super_dag/tasks/task27.24_WORK_MODAL_REFACTOR.md` ✅ Complete
2. Files: `assets/javascripts/pwa_scan/WorkModalController.js`

### **If Working on Task 27.25 (Permission UI):**
1. Read: `docs/super_dag/tasks/task27.25_PERMISSION_UI_IMPROVEMENT.md` ✅ Complete

### **If Working on New Feature:**
1. Check: Is similar feature implemented?
2. Read: `docs/DEVELOPER_POLICY.md`
3. Follow: Existing patterns
4. Test: Write unit tests
5. Document: Update relevant .md files

---

## 📞 **Need Help?**

### **Read These Files:**
1. `docs/DEVELOPER_POLICY.md` - Coding standards
2. `docs/super_dag/DOCUMENTATION_INDEX.md` - SuperDAG docs
3. `.cursorrules` - Project rules

### **Run These Checks:**
```bash
# Syntax check
php -l source/your_file.php

# Tests
vendor/bin/phpunit

# Lints
php source/your_api.php  # Check for errors
```

### **Common Commands:**
```bash
# MySQL
/Applications/MAMP/Library/bin/mysql -h localhost -P 8889 -u root -proot

# Check table schema
DESCRIBE table_name;

# Check column exists
SHOW COLUMNS FROM table_name LIKE 'column_name';
```

---

**Remember:** 
- 🌐 i18n: Default English, translate to Thai
- 🔒 Security: Always prepared statements
- ✅ Test: Write tests for new features
- 📚 Document: Update docs when done

**Good luck!** 🚀

---

**Last Updated:** December 6, 2025  
**Next Review:** When new major features are added  
**Maintained By:** System Architect
