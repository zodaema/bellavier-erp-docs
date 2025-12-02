# 🧪 Phase 8.2: Testing Checklist

**Date:** 2025-11-12  
**Status:** 📋 Pre-Phase 8.3 Testing  
**Purpose:** Verify all Phase 8.2 integration points before proceeding to Phase 8.3

---

## 📋 Test Coverage Overview

### Integration Points to Test:
1. ✅ MO Creation Integration
2. ✅ Job Ticket Creation Integration (Hatthasilpa + Classic)
3. ✅ Serial Generation Integration
4. ✅ Trace API Integration

---

## 1. MO Creation Integration Tests

### Test 1.1: Auto-Select Graph from Product Binding
**Scenario:** Create MO with product that has active graph binding

**Steps:**
1. Create/select a product with active graph binding (`product_graph_binding.is_active=1`)
2. Create MO with `id_product` (no `id_routing_graph` provided)
3. Verify MO is created with `id_routing_graph` from product binding
4. Verify `graph_version` is set correctly (pinned or latest stable)

**Expected Result:**
- ✅ MO created successfully
- ✅ `id_routing_graph` matches product binding
- ✅ `graph_version` matches binding's `graph_version_pin` (or latest stable if NULL)

**Test Data:**
```sql
-- Setup: Product with binding
SELECT p.id_product, p.sku, pgb.id_graph, pgb.graph_version_pin, pgb.default_mode
FROM product p
JOIN product_graph_binding pgb ON pgb.id_product = p.id_product
WHERE pgb.is_active = 1
LIMIT 1;
```

---

### Test 1.2: Manual Override with Permission
**Scenario:** User with `mo.override.graph` permission overrides product binding

**Steps:**
1. Create MO with `id_product` that has active binding
2. Provide `id_routing_graph` different from product binding
3. User has `mo.override.graph` permission
4. Verify MO uses provided `id_routing_graph`

**Expected Result:**
- ✅ MO created with provided `id_routing_graph`
- ✅ No warning message
- ✅ Override successful

---

### Test 1.3: Manual Override Without Permission
**Scenario:** User without `mo.override.graph` permission tries to override

**Steps:**
1. Create MO with `id_product` that has active binding
2. Provide `id_routing_graph` different from product binding
3. User does NOT have `mo.override.graph` permission
4. Verify MO uses product binding (not provided graph)
5. Verify warning message in response

**Expected Result:**
- ✅ MO created with product binding's `id_routing_graph` (not provided)
- ✅ Warning message: "Graph override requires mo.override.graph permission. Using product binding instead."
- ✅ Response includes `warning` field

---

### Test 1.4: Product Without Binding
**Scenario:** Create MO with product that has no active binding

**Steps:**
1. Create/select a product with no active graph binding
2. Create MO with `id_product` (no `id_routing_graph` provided)
3. Verify MO creation behavior

**Expected Result:**
- ✅ MO created successfully (or appropriate error if graph required)
- ✅ `id_routing_graph` is NULL (or system default)
- ✅ Log message indicates no binding found

---

## 2. Job Ticket Creation Integration Tests

### Test 2.1: Hatthasilpa Job Ticket - Inherit Graph from MO
**Scenario:** Create Hatthasilpa job ticket from MO that has graph

**Steps:**
1. Create MO with `id_routing_graph` and `graph_version`
2. Create Hatthasilpa job ticket with `id_mo`
3. Verify job ticket inherits `id_routing_graph` and `graph_version` from MO

**Expected Result:**
- ✅ Job ticket created successfully
- ✅ `id_routing_graph` matches MO's `id_routing_graph`
- ✅ `graph_version` matches MO's `graph_version`
- ✅ Response includes `id_routing_graph` and `graph_version`

**API:** `POST /source/hatthasilpa_job_ticket.php?action=create`

---

### Test 2.2: Classic Job Ticket - Inherit Graph from MO
**Scenario:** Create Classic job ticket from MO that has graph

**Steps:**
1. Create MO with `id_routing_graph` and `graph_version`
2. Create Classic job ticket via `classic_api.php?action=ticket_create_from_graph`
3. Provide `id_mo` in request
4. Verify job ticket inherits graph from MO

**Expected Result:**
- ✅ Job ticket created successfully
- ✅ `id_routing_graph` matches MO's `id_routing_graph`
- ✅ `graph_version` matches MO's `graph_version`

**API:** `POST /source/classic_api.php?action=ticket_create_from_graph`

---

### Test 2.3: Binding Change Detection - Warning
**Scenario:** Product binding changed after MO creation

**Steps:**
1. Create MO with product that has binding to Graph A
2. Change product binding to Graph B (deactivate old, activate new)
3. Create job ticket from MO
4. Verify warning message about binding change

**Expected Result:**
- ✅ Job ticket created successfully
- ✅ Job ticket uses MO's original graph (Graph A)
- ✅ Warning message: "Product binding changed since MO creation. MO uses graph X, but product now uses graph Y."
- ✅ Response includes `bindingChangeWarning` field

---

### Test 2.4: Binding Change Detection - No Warning
**Scenario:** Product binding unchanged since MO creation

**Steps:**
1. Create MO with product that has binding to Graph A
2. Create job ticket from MO immediately (no binding change)
3. Verify no warning message

**Expected Result:**
- ✅ Job ticket created successfully
- ✅ No `bindingChangeWarning` in response
- ✅ Job ticket uses MO's graph

---

## 3. Serial Generation Integration Tests

### Test 3.1: Serial Metadata Accessible via Job Ticket
**Scenario:** Verify serial can access graph information via job ticket

**Steps:**
1. Create job ticket with `id_routing_graph` and `graph_version`
2. Generate serials for job ticket
3. Query serial → job ticket → graph relationship
4. Verify graph information is accessible

**Expected Result:**
- ✅ Serial generated successfully
- ✅ `job_ticket_serial.id_job_ticket` links to `job_ticket.id_routing_graph`
- ✅ Graph information accessible via JOIN:
  ```sql
  SELECT jts.serial_number, jt.id_routing_graph, rg.code, rg.name, jt.graph_version
  FROM job_ticket_serial jts
  JOIN job_ticket jt ON jt.id_job_ticket = jts.id_job_ticket
  LEFT JOIN routing_graph rg ON rg.id_graph = jt.id_routing_graph
  WHERE jts.serial_number = ?
  ```

---

### Test 3.2: Serial Traceability Chain
**Scenario:** Verify complete traceability: Serial → Job Ticket → Graph → Product

**Steps:**
1. Create product with graph binding
2. Create MO from product (auto-selects graph)
3. Create job ticket from MO (inherits graph)
4. Generate serials for job ticket
5. Query complete traceability chain

**Expected Result:**
- ✅ Serial → Job Ticket → Graph → Product chain is complete
- ✅ All relationships are correct
- ✅ Graph version matches product binding (if pinned)

**Query:**
```sql
SELECT 
    jts.serial_number,
    jt.ticket_code,
    jt.id_routing_graph,
    jt.graph_version,
    rg.code AS graph_code,
    rg.name AS graph_name,
    mo.id_product,
    p.sku,
    p.name AS product_name,
    pgb.graph_version_pin AS binding_version
FROM job_ticket_serial jts
JOIN job_ticket jt ON jt.id_job_ticket = jts.id_job_ticket
LEFT JOIN routing_graph rg ON rg.id_graph = jt.id_routing_graph
LEFT JOIN mo ON mo.id_mo = jt.id_mo
LEFT JOIN product p ON p.id_product = mo.id_product
LEFT JOIN product_graph_binding pgb ON pgb.id_product = p.id_product AND pgb.is_active = 1
WHERE jts.serial_number = ?
```

---

## 4. Trace API Integration Tests

### Test 4.1: Serial View with Production Flow
**Scenario:** Verify `production_flow` is included in trace API response

**Steps:**
1. Create product with active graph binding
2. Create MO → Job Ticket → Serial (complete flow)
3. Call Trace API: `GET /source/trace_api.php?action=serial_view&serial={serial}`
4. Verify `production_flow` section in response

**Expected Result:**
- ✅ Response includes `production_flow` section
- ✅ `production_flow.id_graph` matches product binding
- ✅ `production_flow.graph_code` and `graph_name` are populated
- ✅ `production_flow.graph_version` matches binding's `graph_version_pin` (or null)
- ✅ `production_flow.is_pinned_version` is correct boolean
- ✅ `production_flow.binding_effective_from` is populated

**API:** `GET /source/trace_api.php?action=serial_view&serial={serial}`

**Expected Response Structure:**
```json
{
  "ok": true,
  "header": {
    "serial": "...",
    "product": {
      "id_product": 15,
      "sku": "...",
      "name": "..."
    },
    "graph": {
      "id_graph": 7,
      "code": "...",
      "name": "...",
      "version": "2.3"
    },
    "production_flow": {
      "id_graph": 7,
      "graph_code": "HATTHA_KEYCASE_V2",
      "graph_name": "Hatthasilpa Keycase V2",
      "graph_version": "2.3",
      "default_mode": "hatthasilpa",
      "binding_effective_from": "2025-11-01 00:00:00",
      "is_pinned_version": true
    },
    ...
  },
  "timeline": [...],
  "components": [...]
}
```

---

### Test 4.2: Serial View Without Product Binding
**Scenario:** Serial from product without active binding

**Steps:**
1. Create product without active graph binding
2. Create MO → Job Ticket → Serial (with manual graph selection)
3. Call Trace API: `GET /source/trace_api.php?action=serial_view&serial={serial}`
4. Verify `production_flow` is null

**Expected Result:**
- ✅ Response includes `production_flow: null`
- ✅ No error thrown
- ✅ Other sections (graph, product) still populated

---

### Test 4.3: Production Flow - Pinned Version
**Scenario:** Product binding with pinned version

**Steps:**
1. Create product binding with `graph_version_pin = "2.3"`
2. Create MO → Job Ticket → Serial
3. Call Trace API
4. Verify `production_flow.graph_version = "2.3"` and `is_pinned_version = true`

**Expected Result:**
- ✅ `production_flow.graph_version` matches pinned version
- ✅ `production_flow.is_pinned_version = true`

---

### Test 4.4: Production Flow - Auto Latest Stable
**Scenario:** Product binding without pinned version (auto latest stable)

**Steps:**
1. Create product binding with `graph_version_pin = NULL`
2. Create MO → Job Ticket → Serial
3. Call Trace API
4. Verify `production_flow.graph_version` is null or latest stable version
5. Verify `production_flow.is_pinned_version = false`

**Expected Result:**
- ✅ `production_flow.graph_version` is null (or latest stable if available)
- ✅ `production_flow.is_pinned_version = false`

---

## 5. End-to-End Integration Test

### Test 5.1: Complete Flow - Product → MO → Job Ticket → Serial → Trace
**Scenario:** Full integration test from product binding to trace API

**Steps:**
1. **Setup Product Binding:**
   - Create/select product
   - Create active graph binding with pinned version
   
2. **Create MO:**
   - Create MO with product (auto-selects graph)
   - Verify MO has correct `id_routing_graph` and `graph_version`
   
3. **Create Job Ticket:**
   - Create Hatthasilpa job ticket from MO
   - Verify job ticket inherits graph from MO
   - Verify no binding change warning (binding unchanged)
   
4. **Generate Serials:**
   - Generate serials for job ticket
   - Verify serials are linked to job ticket
   
5. **Trace API:**
   - Call Trace API with serial number
   - Verify `production_flow` matches product binding
   - Verify complete traceability chain

**Expected Result:**
- ✅ All steps complete successfully
- ✅ Graph information flows correctly: Product → MO → Job Ticket → Serial
- ✅ Trace API shows correct `production_flow` matching product binding
- ✅ No warnings or errors

---

## 6. Edge Cases & Error Handling

### Test 6.1: MO with Manual Graph (No Product Binding)
**Scenario:** MO created with manual graph selection, product has no binding

**Steps:**
1. Create product without active binding
2. Create MO with manual `id_routing_graph` selection
3. Create job ticket from MO
4. Call Trace API

**Expected Result:**
- ✅ MO created successfully
- ✅ Job ticket inherits graph from MO
- ✅ Trace API `production_flow` is null (no product binding)
- ✅ Trace API `graph` section still shows MO's graph

---

### Test 6.2: Binding Changed After Job Ticket Creation
**Scenario:** Product binding changed after job ticket already created

**Steps:**
1. Create product binding to Graph A
2. Create MO → Job Ticket (uses Graph A)
3. Change product binding to Graph B
4. Call Trace API for serial from job ticket

**Expected Result:**
- ✅ Trace API `production_flow` shows NEW binding (Graph B)
- ✅ Trace API `graph` section shows OLD graph (Graph A - from job ticket)
- ✅ Both are shown correctly (production_flow = current binding, graph = actual graph used)

---

### Test 6.3: Multiple Active Bindings (Should Not Happen)
**Scenario:** Product has multiple active bindings (data integrity issue)

**Steps:**
1. Manually create multiple active bindings for same product+mode (violates business rule)
2. Create MO from product
3. Verify system handles gracefully

**Expected Result:**
- ✅ System uses first binding (by priority/effective_from)
- ✅ Warning logged about multiple active bindings
- ✅ MO created successfully

---

## 📊 Test Execution Checklist

### Pre-Test Setup:
- [ ] Database has test products with graph bindings
- [ ] Database has test routing graphs (published, with versions)
- [ ] Test user has required permissions (`mo.override.graph`, `trace.view`)
- [ ] Test user has test tenant access
- [ ] Browser access: `http://localhost:8888/bellavier-group-erp/`
- [ ] Login with test user credentials (ensure user has required permissions)

### Test Execution:
- [ ] Test 1.1: Auto-Select Graph from Product Binding
- [ ] Test 1.2: Manual Override with Permission
- [ ] Test 1.3: Manual Override Without Permission
- [ ] Test 1.4: Product Without Binding
- [ ] Test 2.1: Hatthasilpa Job Ticket - Inherit Graph
- [ ] Test 2.2: Classic Job Ticket - Inherit Graph
- [ ] Test 2.3: Binding Change Detection - Warning
- [ ] Test 2.4: Binding Change Detection - No Warning
- [ ] Test 3.1: Serial Metadata Accessible
- [ ] Test 3.2: Serial Traceability Chain
- [ ] Test 4.1: Serial View with Production Flow
- [ ] Test 4.2: Serial View Without Product Binding
- [ ] Test 4.3: Production Flow - Pinned Version
- [ ] Test 4.4: Production Flow - Auto Latest Stable
- [ ] Test 5.1: Complete Flow End-to-End
- [ ] Test 6.1: MO with Manual Graph
- [ ] Test 6.2: Binding Changed After Job Ticket
- [ ] Test 6.3: Multiple Active Bindings

### Post-Test Verification:
- [ ] All tests passed
- [ ] No errors in error logs
- [ ] Database integrity maintained
- [ ] Performance acceptable (< 100ms per API call)

---

## 🐛 Known Issues / Notes

### Current Limitations:
- Serial format does not include graph code (by design - metadata accessible via DB)
- Trace API `production_flow` shows current binding (may differ from actual graph used in production)

### Future Enhancements:
- Add automated test suite (PHPUnit)
- Add performance benchmarks
- Add load testing for serial generation

---

## ✅ Sign-Off

**Tested By:** ________________  
**Date:** ________________  
**Status:** ⏳ Pending / ✅ Passed / ❌ Failed  
**Notes:** ________________

---

**Next Steps:**
- If all tests pass → Proceed to Phase 8.3
- If tests fail → Fix issues and retest
- If critical issues → Block Phase 8.3 until resolved

