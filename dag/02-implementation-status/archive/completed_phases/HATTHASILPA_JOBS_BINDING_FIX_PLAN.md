# 🔧 Hatthasilpa Jobs Binding-First Hotfix Plan

**Created:** November 15, 2025  
**Status:** 🚨 **URGENT** - Blocking production use  
**Priority:** 🔴 **CRITICAL** - Must fix before continuing DAG roadmap  
**Approach:** Binding-First Hotfix (not full refactor)

---

## 📋 Problem Summary

### Current State (Broken)
- **`hatthasilpa_jobs` page** requires manual **Production Template (Pattern) selection**
- **UI uses "Template/Pattern" language** but **backend needs "Binding"**
- **Mismatch**: UI shows Pattern selection → Backend expects Binding → **Cannot create DAG jobs**
- **Result**: Cannot test Phase 2/3/4 features because cannot create jobs
- **Root cause**: System developed forward but left old Pattern-based model behind

### Expected State (Fixed - Binding-First)
- **Binding is the canonical production unit** (Product + Pattern + Pattern Version + Graph + BOM)
- **Modal selects Binding** (not Template/Pattern)
- **JobCreationService has `createFromBinding()`** method
- **One-liner job creation**: `JobCreationService::createFromBinding($bindingId, $params)`
- **No more manual graph selection** - Binding resolves everything

---

## 🎯 Root Cause Analysis

### The Core Mismatch

**UI Language:** "Production Template" = Pattern/Pattern Version (old world)  
**Backend Expectation:** Binding = Product + Pattern + Pattern Version + Graph + BOM (new world)

**Current Flow (Broken):**
```
User selects Product → UI shows Pattern dropdown → User selects Pattern
→ Backend receives pattern_id → Cannot resolve to Binding → Cannot create DAG job
```

**Expected Flow (Fixed):**
```
User selects Product → UI shows Binding dropdown → User selects Binding
→ Backend receives binding_id → Resolves Product + Pattern + Graph + BOM
→ JobCreationService::createFromBinding() → Creates DAG job successfully
```

### Current Database State

**Existing Tables:**
- ✅ `product_graph_binding` - Has Product + Graph (missing Pattern fields)
- ✅ `pattern` - Has Pattern (id_pattern, id_product, pattern_code)
- ✅ `pattern_version` - Has Pattern Version (id_version, id_pattern, version_no, is_active)
- ✅ `bom` - Has BOM templates

**Missing:** Canonical Binding model that combines all of the above

### Code Locations

**Hatthasilpa Jobs (Needs Fix):**
- Backend: `source/hatthasilpa_jobs_api.php` line 254 → Requires `id_routing_graph` (should be `binding_id`)
- Frontend: `assets/javascripts/hatthasilpa/jobs.js` line 204-257 → Loads templates (should load bindings)
- Frontend: `views/hatthasilpa_jobs.php` line 127-136 → Template dropdown (should be Binding dropdown)
- Service: `source/BGERP/Service/JobCreationService.php` → No `createFromBinding()` method yet

---

## 🔧 Implementation Plan (Binding-First Hotfix)

### 🎯 PART A: Define Canonical Binding Model

**Goal:** Create a canonical Binding model/view that combines Product + Pattern + Pattern Version + Graph + BOM

**Option 1: Extend `product_graph_binding` table (Recommended)**
- Add `id_pattern` (nullable) - FK to `pattern`
- Add `id_pattern_version` (nullable) - FK to `pattern_version`
- Add `id_bom_template` (nullable) - FK to `bom`
- Add `binding_label` (VARCHAR 255) - Human-readable label

**Option 2: Create canonical view/helper (If Option 1 too invasive)**
- Create `ProductionBindingHelper` class
- JOIN `product_graph_binding` + `pattern` + `pattern_version` + `bom`
- Generate `binding_label` dynamically
- Return canonical binding structure

**Decision:** Use **Option 1** (extend table) for clarity and performance. Create migration.

**Migration File:** `database/tenant_migrations/2025_11_extend_product_graph_binding.php`

```php
// Add columns to product_graph_binding
ALTER TABLE product_graph_binding
ADD COLUMN id_pattern INT NULL COMMENT 'FK to pattern(id_pattern)',
ADD COLUMN id_pattern_version INT NULL COMMENT 'FK to pattern_version(id_version)',
ADD COLUMN id_bom_template INT NULL COMMENT 'FK to bom(id_bom)',
ADD COLUMN binding_label VARCHAR(255) NOT NULL DEFAULT '' COMMENT 'Human-readable label (e.g., "Tote A / Pattern V2 / DAG: Diagonal_V2")',
ADD INDEX idx_pattern (id_pattern),
ADD INDEX idx_pattern_version (id_pattern_version),
ADD INDEX idx_bom (id_bom_template);
```

**Binding Label Generation Logic:**
- Format: `"{Pattern Name} / V{Version} / DAG: {Graph Name}"`
- Example: `"Tote A / V2 / DAG: Diagonal_V2"`
- If no pattern: `"{Product Name} / DAG: {Graph Name}"`
- Generated automatically when binding created/updated
- Helper method: `ProductionBindingHelper::generateBindingLabel($binding)` (to be created)

**For Legacy Products:**
- Products with only 1 graph → Create 1 binding row (pattern fields = NULL)
- Migration script can auto-create bindings for existing products
- Binding label: `"{Product Name} / DAG: {Graph Name}"`

---

### 🎯 PART B: Fix Modal to Use Binding (Not Template)

**Files:**
- `views/hatthasilpa_jobs.php` (Modal HTML)
- `assets/javascripts/hatthasilpa/jobs.js` (JavaScript logic)

**Changes:**

1. **Modal HTML** (`views/hatthasilpa_jobs.php` line 127-136):
   - Change label from "Production Template" to **"Production Binding"**
   - Change field ID from `#atelier_template` to `#atelier_binding`
   - Update placeholder: "Select binding..."
   - Add info display: `#bindingInfo` panel

2. **JavaScript** (`assets/javascripts/hatthasilpa/jobs.js`):
   - Rename `loadTemplatesForProduct()` → `loadBindingsForProduct()`
   - New API endpoint: `get_bindings_for_product` (returns bindings, not templates)
   - Display binding labels in dropdown (e.g., "Pattern A / V1 / DAG: Diagonal_V1")
   - Each option has `binding_id` value (not `graph_id`)

3. **API Endpoint** (`source/hatthasilpa_jobs_api.php`):
   - New case: `get_bindings_for_product`
   - Returns: Array of bindings with `binding_id`, `binding_label`, `graph_name`, `pattern_name`, etc.

**New UX Flow:**
```
1. User selects Product
2. System loads Bindings for that Product
3. Dropdown shows: "Pattern A / V1 / DAG: Diagonal_V1"
4. User selects Binding
5. System shows binding details (graph, pattern, BOM)
6. User fills other fields → Create Job
```

---

### 🎯 PART E: Legacy "Production Template" Handling (Disable but Keep for Future Use)

**Goal:** Clearly separate the new **Binding-first** flow from the old **Template/Pattern-based** flow, without deleting legacy code. The legacy "Production Template" selection must be **disabled and hidden in the UI**, but kept in codebase for potential future use.

#### 1) UI: Disable & Hide "Production Template" Selection

**Current issue:**
- The `hatthasilpa_jobs` modal currently shows a "Production Template" dropdown, which is actually Pattern/Template based.
- This path is no longer valid for DAG job creation and conflicts with the new Binding-first design.

**New behavior:**
- [ ] Keep the legacy "Production Template" HTML/JS code in place, but:
  - [ ] Disable the control (`disabled` attribute) so it cannot be interacted with.
  - [ ] Hide it from normal users via CSS (e.g. `d-none` or equivalent).
- [ ] Add a small code comment in both view + JS:
  ```php
  // LEGACY: Production Template selection (Pattern-based).
  // Currently disabled & hidden. Do NOT delete.
  // All new Hatthasilpa jobs must use Binding (binding_id) instead.
  ```
  ```javascript
  // LEGACY: template-based flow (deprecated for DAG).
  // Kept for future use, but not used in current job creation.
  ```
- [ ] Ensure that no UX element suggests that "Template" is needed to create a job.
- [ ] All visible UX should only talk about Binding, not Template.

#### 2) JS/API: Do NOT Use Template in New Jobs (But Keep Code)

- [ ] Any JS code that previously sent `template_id` / `pattern_id` to `hatthasilpa_jobs_api.php`:
  - [ ] Must no longer be called in the current "Create Job" flow.
  - [ ] Can remain in the file as legacy functions, but should be clearly commented as unused in the new Binding-first flow.
- [ ] The `create_job` / `create_and_start` API must:
  - [ ] Require `binding_id`
  - [ ] Explicitly ignore / reject `template_id` if accidentally sent:
  ```php
  if (!empty($request['template_id'])) {
      error_log(sprintf(
          '[Hatthasilpa Jobs] WARNING: Legacy template_id provided but ignored in Binding-first mode. template_id=%d',
          $request['template_id']
      ));
      // Do NOT use template_id for DAG jobs.
  }
  ```

#### 3) Non-goals (to avoid accidental refactors)

To be extremely explicit for future agents/devs:

- ❌ **Do NOT remove legacy "Production Template" code.**
- ❌ **Do NOT re-enable the template-based path for DAG job creation.**
- ❌ **Do NOT mix Template-based configuration with Binding-based DAG routing in this hotfix.**

This hotfix explicitly:

- ✅ Uses Binding as the only source of truth for Hatthasilpa job creation.
- ✅ Keeps legacy Template/Pattern code disabled + hidden, but available for future refactors.
- ✅ Ensures `hatthasilpa_jobs` stays clean and Binding-first, without losing the option to reintroduce a higher-level "Template" concept later (e.g., Template → pre-selected Binding + job params).

#### 4) Acceptance Criteria (Legacy Template Handling)

- [ ] "Production Template" control is not visible to normal users in `hatthasilpa_jobs` modal.
- [ ] No new job can be created using Template/Pattern-based parameters.
- [ ] `binding_id` is always required for DAG job creation from this page.
- [ ] Legacy template code paths remain in the repo, commented as LEGACY/unused.
- [ ] No regression/errors when older JS functions exist but are not used in the current flow.

---

### 🎯 PART C: Extend JobCreationService with `createFromBinding()`

**File:** `source/BGERP/Service/JobCreationService.php`

**New Method:**
```php
/**
 * Create DAG job from Binding (canonical method)
 * 
 * @param int $bindingId - Binding ID (resolves Product + Pattern + Graph + BOM)
 * @param array $jobParams {
 *   'target_qty' => int,
 *   'due_date' => string|null,
 *   'id_mo' => int|null,
 *   'created_by' => int|null
 * }
 * @return array {
 *   'job_ticket_id' => int,
 *   'graph_instance_id' => int,
 *   'token_count' => int,
 *   'binding_id' => int
 * }
 */
public function createFromBinding(int $bindingId, array $jobParams = []): array
{
    // 1. Load binding (with Product + Pattern + Graph + BOM)
    $binding = $this->loadBinding($bindingId);
    if (!$binding) {
        throw new \RuntimeException("Binding not found: {$bindingId}");
    }
    
    // 2. Create job_ticket (job_ticket table does NOT have id_pattern/id_pattern_version fields)
    // Pattern info is stored in binding, not duplicated in job_ticket
    $ticketCode = 'ATELIER-' . date('Ymd') . '-' . str_pad(rand(1, 999), 3, '0', STR_PAD_LEFT);
    $jobName = $jobParams['job_name'] ?? $binding['product_name'] ?? 'Job from Binding';
    $targetQty = (int)($jobParams['target_qty'] ?? 1);
    $dueDate = $jobParams['due_date'] ?? null;
    $moId = $jobParams['id_mo'] ?? null;
    
    $jobTicketId = $this->dbHelper->insert("
        INSERT INTO job_ticket 
        (ticket_code, job_name, id_product, target_qty, production_type, 
         routing_mode, id_routing_graph, id_mo, due_date, status, created_at)
        VALUES (?, ?, ?, ?, 'hatthasilpa', 'dag', ?, ?, ?, 'planned', NOW())
    ", [
        $ticketCode, 
        $jobName, 
        $binding['id_product'], 
        $targetQty,
        $binding['id_graph'], // Store graph reference for quick lookup
        $moId, 
        $dueDate
    ], 'ssiiisis');
    
    // 3. Create graph_instance from id_graph
    $graphInstanceId = $this->graphService->createInstance(
        $binding['id_graph'],
        $jobParams['id_mo'] ?? null,
        $jobTicketId,
        'hatthasilpa'
    );
    
    // 4. Create node instances
    $this->graphService->createNodeInstances($graphInstanceId, $binding['id_graph']);
    
    // 5. Update job_ticket with graph_instance_id
    $this->dbHelper->execute("
        UPDATE job_ticket 
        SET graph_instance_id = ?, routing_mode = 'dag'
        WHERE id_job_ticket = ?
    ", [$graphInstanceId, $jobTicketId], 'ii');
    
    // 6. Spawn tokens
    $targetQty = (int)($jobParams['target_qty'] ?? 1);
    $sku = $binding['product_sku'] ?? 'ITEM';
    
    // Generate serials if needed (for piece mode)
    // Uses existing generateSerials() method from JobCreationService (same as createDAGJob)
    $serials = $jobParams['serials'] ?? [];
    if (empty($serials) && $targetQty > 1) {
        $serials = $this->generateSerials(
            'hatthasilpa',
            $sku,
            $targetQty,
            $moId,
            $jobTicketId,
            $jobParams['tenant_id'] ?? null
        );
    }
    
    // Spawn tokens using TokenLifecycleService (matches existing createDAGJob pattern)
    // Signature: spawnTokens(int $instanceId, int $targetQty, string $processMode, array $serials = [])
    $tokenIds = $this->tokenService->spawnTokens(
        $graphInstanceId,
        $targetQty,
        'piece', // Hatthasilpa always uses piece mode
        $serials
    );
    
    return [
        'job_ticket_id' => $jobTicketId,
        'graph_instance_id' => $graphInstanceId,
        'token_count' => count($tokenIds),
        'token_ids' => $tokenIds,
        'binding_id' => $bindingId
    ];
}

private function loadBinding(int $bindingId): ?array
{
    // JOIN product_graph_binding + pattern + pattern_version + routing_graph + product
    $sql = "
        SELECT 
            pgb.id_binding,
            pgb.id_product,
            pgb.id_pattern,
            pgb.id_pattern_version,
            pgb.id_graph,
            pgb.id_bom_template,
            pgb.binding_label,
            pgb.default_mode,
            p.sku AS product_sku,
            p.name AS product_name,
            pat.pattern_code,
            pat.pattern_name,
            pv.version_no,
            rg.graph_name,
            rg.graph_code
        FROM product_graph_binding pgb
        JOIN product p ON p.id_product = pgb.id_product
        LEFT JOIN pattern pat ON pat.id_pattern = pgb.id_pattern
        LEFT JOIN pattern_version pv ON pv.id_version = pgb.id_pattern_version
        JOIN routing_graph rg ON rg.id_graph = pgb.id_graph
        WHERE pgb.id_binding = ? AND pgb.is_active = 1
    ";
    
    return $this->dbHelper->fetchOne($sql, [$bindingId], 'i');
}
```

**Update API** (`source/hatthasilpa_jobs_api.php`):
- Change `create_and_start` case to accept `binding_id` instead of `id_routing_graph`
- Validation: `binding_id` is required (not `id_routing_graph`)
- Call `JobCreationService::createFromBinding($bindingId, $params)`
- Return binding info in response
- **Note:** `job_name` should come from `$jobParams` (user input), not from binding

---

### 🎯 PART D: Minimal Tests

**Test Checklist:**

1. **Database Setup:**
   - [ ] Migration runs successfully
   - [ ] At least 1 Binding created for test Product (via SQL or UI)

2. **Modal Flow:**
   - [ ] Open `hatthasilpa_jobs` → Click "New Job"
   - [ ] Select Product → Binding dropdown loads (not empty)
   - [ ] Select Binding → Binding info displayed
   - [ ] Fill other fields → Submit

3. **Job Creation:**
   - [ ] API creates `job_ticket` row
   - [ ] API creates `graph_instance` row (linked to job_ticket)
   - [ ] API spawns tokens at START node
   - [ ] Response includes `binding_id`

4. **Job Viewing:**
   - [ ] Open `hatthasilpa_job_ticket` for created job
   - [ ] DAG mode detected (`routing_mode='dag'`)
   - [ ] DAG info panel shows correct `graph_instance_id`
   - [ ] Tokens visible in Token Management / Work Queue

5. **No Regression:**
   - [ ] MO page still works (no changes to MO code)
   - [ ] Old "pattern-only" path not used for DAG jobs

---

## 📝 Implementation Checklist (Detailed)

### PART A: Canonical Binding Model
- [ ] Create migration: `2025_11_extend_product_graph_binding.php`
- [ ] Add columns: `id_pattern`, `id_pattern_version`, `id_bom_template`, `binding_label`
- [ ] Add indexes for new foreign keys
- [ ] Create helper method: `ProductionBindingHelper::generateBindingLabel()`
- [ ] Test migration on test tenant

### PART B: Modal & Frontend
- [ ] Update `views/hatthasilpa_jobs.php`: Change Template → Binding dropdown
- [ ] Update `assets/javascripts/hatthasilpa/jobs.js`: `loadBindingsForProduct()`
- [ ] Create API endpoint: `get_bindings_for_product` in `hatthasilpa_jobs_api.php`
- [ ] Update `handleCreateJob()`: Send `binding_id` instead of `id_routing_graph`
- [ ] Add binding info display panel in modal
- [ ] Test: Product selection → Binding dropdown loads

### PART E: Legacy Template Handling
- [ ] Disable & hide "Production Template" dropdown in `views/hatthasilpa_jobs.php` (add `disabled` + `d-none`)
- [ ] Add LEGACY comments to template-related code (both view and JS)
- [ ] Update API to reject `template_id` if sent (log warning, ignore it)
- [ ] Comment legacy JS functions as unused in Binding-first flow
- [ ] Verify: No template-based job creation possible
- [ ] Verify: Legacy code still exists but disabled

### PART C: JobCreationService Extension
- [ ] Add `createFromBinding()` method to `JobCreationService`
- [ ] Add `loadBinding()` private method (JOIN all tables)
- [ ] Update `hatthasilpa_jobs_api.php`: Use `createFromBinding()`
- [ ] Remove old `id_routing_graph` validation (replace with `binding_id`)
- [ ] Test: Create job from binding → Verify all data correct

### PART D: Testing
- [ ] Create test binding (Product + Pattern + Graph)
- [ ] Test: Modal → Select Product → Select Binding → Create Job
- [ ] Verify: `job_ticket` created with correct fields
- [ ] Verify: `graph_instance` created and linked
- [ ] Verify: Tokens spawned correctly
- [ ] Verify: DAG mode detected in `hatthasilpa_job_ticket`
- [ ] Regression: MO page still works

---


---

## 🚨 Critical Notes

1. **Hotfix Strategy (Not Full Refactor):**
   - This is a **hotfix** to make system usable, not a complete redesign
   - We extend `product_graph_binding` table (minimal change)
   - We add `createFromBinding()` method (new canonical path)
   - Old `createDAGJob()` method still works (backward compatibility)

2. **Binding Label Generation:**
   - Format: `"{Pattern Name} / V{Version} / DAG: {Graph Name}"`
   - Example: `"Tote A / V2 / DAG: Diagonal_V2"`
   - If no pattern: `"{Product Name} / DAG: {Graph Name}"`
   - Generated automatically when binding created/updated

3. **Legacy Products:**
   - Products with only 1 graph → Auto-create binding (pattern fields = NULL)
   - Migration script can backfill bindings for existing products
   - Binding label: `"{Product Name} / DAG: {Graph Name}"`

4. **Error Messages:**
   - Must be user-friendly
   - Guide user to configure binding if missing
   - Example: "No binding found for this product. Please configure Product-Graph Binding first."

5. **No Breaking Changes:**
   - MO page unchanged (still uses `ProductGraphBindingHelper::getActiveBinding()`)
   - Old `createDAGJob()` method still works
   - New `createFromBinding()` is the canonical path for Hatthasilpa Jobs

---

## 📅 Timeline

**Estimated Duration:** 4-6 hours

- **PART A (Binding Model):** 1-2 hours (migration + helper)
- **PART B (Modal & Frontend):** 1-2 hours (UI changes + API)
- **PART C (JobCreationService):** 1 hour (new method)
- **PART D (Testing):** 1 hour (end-to-end tests)

**Priority:** 🔴 **URGENT** - Blocking production use and DAG roadmap progress

**Why This Must Be Done First:**
- Cannot test Phase 2/3/4 features without being able to create jobs
- System developed forward but left old Pattern model behind
- This hotfix unblocks the entire DAG roadmap

---

## ✅ Success Criteria

- [ ] **Binding is canonical unit**: Every job creation uses `binding_id`
- [ ] **Modal shows Binding dropdown**: Not Template/Pattern dropdown
- [ ] **JobCreationService has `createFromBinding()`**: One-liner job creation
- [ ] **Binding resolves everything**: Product + Pattern + Graph + BOM from single ID
- [ ] **No manual graph selection**: Binding contains all needed info
- [ ] **Legacy products supported**: Auto-create bindings for products with 1 graph
- [ ] **MO page unchanged**: No regression (still uses `getActiveBinding()`)
- [ ] **End-to-end works**: Create job → View job → Tokens visible → Work Queue works

---

## 🎯 Why This Approach?

**Binding-First Philosophy:**
- **Binding = Single Source of Truth** for production configuration
- **No more Pattern-only thinking** - Everything goes through Binding
- **Canonical method**: `createFromBinding()` is the standard way to create jobs
- **Future-proof**: Easy to extend (add BOM, QC policies, etc.)

**Hotfix Strategy:**
- **Minimal changes** - Extend existing table, add new method
- **Backward compatible** - Old methods still work
- **Unblocks roadmap** - Can now test Phase 2/3/4 features
- **Production-ready** - System becomes usable immediately

---

**Status:** Ready for Review & Implementation  
**Next Step:** Review plan → Start PART A (Binding Model Extension)

