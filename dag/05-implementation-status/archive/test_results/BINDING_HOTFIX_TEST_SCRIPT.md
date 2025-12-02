# Binding-First Hotfix - Test Script

**Date:** November 15, 2025  
**Purpose:** Manual testing checklist for Binding-First implementation  
**Tester:** _________________  
**Test Environment:** http://localhost:8888/bellavier-group-erp  
**Credentials:** admin / iydgtv

---

## 🧪 Test Script

### Pre-Test Setup

#### 1. Verify Migration
```bash
cd /Applications/MAMP/htdocs/bellavier-group-erp
/Applications/MAMP/Library/bin/mysql -u root -proot bgerp_t_maison_atelier \
  -e "DESCRIBE product_graph_binding" | grep binding_label
```
**Expected:** Should show `binding_label VARCHAR(255) NO`

#### 2. Create Test Binding (if none exists)
```sql
-- Connect to tenant DB
USE bgerp_t_maison_atelier;

-- Check existing bindings
SELECT * FROM product_graph_binding LIMIT 5;

-- If empty, create a test binding
INSERT INTO product_graph_binding 
(id_product, id_graph, binding_label, default_mode, is_active, priority)
SELECT 
    p.id_product,
    rg.id_graph,
    CONCAT(p.name, ' / DAG: ', rg.graph_name) AS binding_label,
    'hatthasilpa',
    1,
    0
FROM product p
CROSS JOIN routing_graph rg
WHERE p.id_product = 1 AND rg.id_graph = 1
LIMIT 1;
```

---

### Test 1: UI Verification

#### 1.1 Open Hatthasilpa Jobs Page
- Navigate to: `http://localhost:8888/bellavier-group-erp/index.php?p=hatthasilpa_jobs`
- Click: **"New Job"** button

**Expected:**
- ✅ Modal opens with title "Create Hatthasilpa Job"
- ✅ "Production Template" section is **NOT visible**
- ✅ "Production Binding" dropdown **IS visible**

**Status:** [ ] PASS [ ] FAIL

---

#### 1.2 Select Product
- Select any product from "Product" dropdown
- Wait for bindings to load

**Expected:**
- ✅ "Production Binding" dropdown populates with bindings
- ✅ Binding label format: `{Product/Pattern Name} / DAG: {Graph Name}`
- ✅ First binding is auto-selected
- ✅ Binding info card appears below dropdown

**Status:** [ ] PASS [ ] FAIL

**Screenshot Location:** _________________

---

#### 1.3 Binding Info Card
- Verify binding info card contents

**Expected:**
- ✅ Shows: Graph name with code
- ✅ Shows: Pattern name + version (if exists)
- ✅ Shows: Mode badge (Atelier/OEM/Hybrid)
- ✅ Card has primary border

**Status:** [ ] PASS [ ] FAIL

---

### Test 2: API Endpoint Testing

#### 2.1 Test get_bindings_for_product
```bash
# Open browser console (F12)
# Paste this code:
```
```javascript
$.getJSON('source/hatthasilpa_jobs_api.php', {
  action: 'get_bindings_for_product',
  id_product: 1
}, function(resp) {
  console.log('API Response:', resp);
  if (resp.ok && resp.bindings) {
    console.log(`✅ Found ${resp.bindings.length} bindings`);
    console.table(resp.bindings);
  } else {
    console.error('❌ No bindings found');
  }
});
```

**Expected:**
- ✅ Response: `{ok: true, bindings: [...]}`
- ✅ Each binding has: `id_binding`, `binding_label`, `graph_name`, etc.

**Status:** [ ] PASS [ ] FAIL

---

### Test 3: Job Creation (Critical!)

#### 3.1 Fill Job Form
- **Product:** Select any product with binding
- **Production Binding:** Auto-selected (first binding)
- **Job Name:** `TEST-BINDING-HOTFIX-001`
- **Quantity:** `5`
- **Due Date:** (optional, can leave empty)
- Click: **"Create & Start"**

**Expected:**
- ✅ Confirmation dialog appears
- ✅ Dialog shows: Job name, Quantity, Auto-actions list
- ✅ Click "Create & Start"
- ✅ Success dialog appears with ticket code (e.g., `ATELIER-20251115-0001`)
- ✅ Success message: "5 tokens spawned and ready in Work Queue"
- ✅ Modal closes
- ✅ Job appears in DataTable

**Status:** [ ] PASS [ ] FAIL

**Ticket Code Created:** _________________

---

#### 3.2 Verify Database Records
```sql
-- Connect to tenant DB
USE bgerp_t_maison_atelier;

-- Verify job_ticket created
SELECT 
    id_job_ticket,
    ticket_code,
    job_name,
    routing_mode,
    graph_instance_id,
    status
FROM job_ticket
WHERE job_name = 'TEST-BINDING-HOTFIX-001';
```

**Expected:**
- ✅ 1 row returned
- ✅ `routing_mode = 'dag'`
- ✅ `graph_instance_id` is NOT NULL
- ✅ `status = 'in_progress'`

**Status:** [ ] PASS [ ] FAIL

---

#### 3.3 Verify Graph Instance Created
```sql
-- Using job_ticket_id from above
SELECT 
    id_instance,
    id_graph,
    job_ticket_id,
    status
FROM job_graph_instance
WHERE job_ticket_id = ?; -- Replace with actual ID
```

**Expected:**
- ✅ 1 row returned
- ✅ `status = 'active'`

**Status:** [ ] PASS [ ] FAIL

---

#### 3.4 Verify Tokens Spawned
```sql
-- Using graph_instance_id from above
SELECT 
    COUNT(*) AS token_count,
    MIN(status) AS first_status,
    MAX(status) AS last_status
FROM flow_token
WHERE id_instance = ?; -- Replace with actual graph_instance_id
```

**Expected:**
- ✅ `token_count = 5` (matches quantity entered)
- ✅ All tokens have `status = 'ready'` or `'active'`

**Status:** [ ] PASS [ ] FAIL

---

### Test 4: Job Ticket Viewer Integration

#### 4.1 Open Job in hatthasilpa_job_ticket
- Click "View" button for the created job in DataTable
- Or navigate to: `http://localhost:8888/bellavier-group-erp/index.php?p=hatthasilpa_job_ticket&id={job_ticket_id}`

**Expected:**
- ✅ Page loads successfully
- ✅ "DAG Mode" badge is visible
- ✅ **Tasks section is HIDDEN**
- ✅ **Import Routing section is HIDDEN**
- ✅ DAG Info Panel is visible with:
  - Graph Instance ID
  - Token Count
  - "Open in Token Management" link
  - "Open in Work Queue" link

**Status:** [ ] PASS [ ] FAIL

---

#### 4.2 Open in Token Management
- Click "Open in Token Management" link

**Expected:**
- ✅ Redirects to: `token_management` page
- ✅ Job dropdown is auto-selected
- ✅ Token table shows 5 tokens
- ✅ All tokens belong to the created job

**Status:** [ ] PASS [ ] FAIL

---

#### 4.3 Open in Work Queue
- Go back to job ticket page
- Click "Open in Work Queue" link

**Expected:**
- ✅ Redirects to: `work_queue` page
- ✅ Work queue is auto-filtered by job_ticket_id
- ✅ Shows 5 tokens in Kanban columns
- ✅ All tokens belong to the created job

**Status:** [ ] PASS [ ] FAIL

---

### Test 5: Legacy Code Verification

#### 5.1 Verify Legacy Template is Disabled
```bash
# Open browser console (F12) on hatthasilpa_jobs page
# Paste this code:
```
```javascript
console.log('Legacy template section:', $('#legacy-template-section').length); // Should be 1
console.log('Is visible?:', $('#legacy-template-section').is(':visible')); // Should be false
console.log('Template select disabled?:', $('#atelier_template').prop('disabled')); // Should be true
```

**Expected:**
- ✅ Section exists but is hidden (`d-none`)
- ✅ Template select is disabled

**Status:** [ ] PASS [ ] FAIL

---

#### 5.2 Verify Legacy API Ignores template_id
```bash
# Open browser console (F12)
# Paste this code (should fail validation):
```
```javascript
$.post('source/hatthasilpa_jobs_api.php', {
  action: 'create_and_start',
  job_name: 'SHOULD-FAIL',
  id_product: 1,
  target_qty: 1,
  template_id: 999, // LEGACY - should be ignored
  // Missing binding_id - should fail validation
}, function(resp) {
  console.log('Response:', resp);
  if (!resp.ok && resp.app_code === 'HATTHASILPA_JOBS_400_VALIDATION') {
    console.log('✅ Correctly rejected (binding_id required)');
  } else {
    console.error('❌ Should have failed validation!');
  }
}, 'json');
```

**Expected:**
- ✅ Response: `{ok: false, app_code: 'HATTHASILPA_JOBS_400_VALIDATION'}`
- ✅ Error message mentions `binding_id` is required

**Status:** [ ] PASS [ ] FAIL

---

### Test 6: Error Handling

#### 6.1 No Bindings Available
```javascript
// Test with a product that has no bindings
$.getJSON('source/hatthasilpa_jobs_api.php', {
  action: 'get_bindings_for_product',
  id_product: 9999 // Non-existent product
}, function(resp) {
  console.log('Response:', resp);
  if (resp.ok && resp.bindings.length === 0) {
    console.log('✅ Correctly returns empty bindings array');
    console.log('Error message:', resp.error);
  }
});
```

**Expected:**
- ✅ Response: `{ok: true, bindings: [], error: 'No bindings configured...'}`
- ✅ UI shows warning alert in binding info area

**Status:** [ ] PASS [ ] FAIL

---

#### 6.2 Invalid Binding ID
```javascript
// Try to create job with invalid binding_id
$.post('source/hatthasilpa_jobs_api.php', {
  action: 'create_and_start',
  job_name: 'SHOULD-FAIL-2',
  id_product: 1,
  target_qty: 1,
  binding_id: 99999 // Invalid
}, function(resp) {
  console.log('Response:', resp);
  if (!resp.ok) {
    console.log('✅ Correctly rejected invalid binding');
  } else {
    console.error('❌ Should have failed!');
  }
}, 'json').fail(function() {
  console.log('✅ Request failed as expected');
});
```

**Expected:**
- ✅ Response: `{ok: false, app_code: 'HATTHASILPA_JOBS_500_CREATE_FAILED'}` OR
- ✅ Server error (500) with error message

**Status:** [ ] PASS [ ] FAIL

---

## 📊 Test Results Summary

| Test Section | Status | Notes |
|--------------|--------|-------|
| 1. UI Verification | [ ] PASS [ ] FAIL | |
| 2. API Endpoint Testing | [ ] PASS [ ] FAIL | |
| 3. Job Creation | [ ] PASS [ ] FAIL | |
| 4. Job Ticket Viewer | [ ] PASS [ ] FAIL | |
| 5. Legacy Code | [ ] PASS [ ] FAIL | |
| 6. Error Handling | [ ] PASS [ ] FAIL | |

**Overall Status:** [ ] ALL PASS [ ] FAILED

---

## 🐛 Bugs Found

| Bug ID | Description | Severity | Status |
|--------|-------------|----------|--------|
|  |  |  |  |

---

## 📝 Notes

_________________
_________________
_________________

---

## ✅ Sign-Off

**Tester:** _________________  
**Date:** _________________  
**Signature:** _________________

**Status:** [ ] APPROVED FOR PRODUCTION [ ] REQUIRES FIXES

