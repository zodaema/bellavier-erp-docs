# 🧪 Serial Number System - Validation Test Plan

**Purpose:** Comprehensive test plan for Phase 2 Validation  
**Status:** 🟡 **Ready to Execute**  
**Estimated Time:** 2-4 hours

---

## 📋 Test Overview

**Objective:** Validate that Core Infrastructure and Integration Points work correctly before go-live

**Test Environment:**
- Development/Staging environment
- At least 2 tenants (for cross-tenant testing)
- Test data: Job tickets, MOs, DAG graphs

---

## 🔴 Critical Tests (Must Pass)

### **Test 1: Dual-Link Consistency**

**Purpose:** Verify Tenant DB and Core DB links are consistent

**Test Steps:**
1. Create HAT job ticket with `target_qty = 10`
2. Verify serials pre-generated in `job_ticket_serial` (10 serials)
3. Spawn 10 tokens via `dag_token_api.php`
4. Verify Tenant DB links:
   - `job_ticket_serial.spawned_at` is set (10 rows)
   - `job_ticket_serial.spawned_token_id` matches token IDs (10 rows)
5. Verify Core DB links:
   - `serial_registry.dag_token_id` matches token IDs (10 rows)
6. Verify consistency:
   - `job_ticket_serial.spawned_token_id` = `serial_registry.dag_token_id` for same serial

**Expected Results:**
- ✅ All 10 serials linked in Tenant DB
- ✅ All 10 serials linked in Core DB
- ✅ Both links point to same token IDs
- ✅ No orphaned links

**Test File:** `tests/manual/test_dual_link.php`

---

### **Test 2: Context Validation**

**Purpose:** Verify HAT/OEM context mismatch rejection

**Test Scenarios:**

#### **2.1 HAT with mo_id (Should Fail)**
```php
try {
    $service->generateSerial(
        tenantId: 1,
        productionType: 'hatthasilpa',
        sku: 'TEST',
        moId: 999,  // ❌ HAT cannot have mo_id
        jobTicketId: 999
    );
    // Should not reach here
    fail('Should have thrown ERR_CONTEXT_MISMATCH');
} catch (RuntimeException $e) {
    assert(strpos($e->getMessage(), 'ERR_CONTEXT_MISMATCH') !== false);
}
```

#### **2.2 OEM with dag_token_id (Should Fail)**
```php
try {
    $service->generateSerial(
        tenantId: 1,
        productionType: 'oem',
        sku: 'TEST',
        moId: 999,
        dagTokenId: 999  // ❌ OEM cannot have dag_token_id
    );
    // Should not reach here
    fail('Should have thrown ERR_CONTEXT_MISMATCH');
} catch (RuntimeException $e) {
    assert(strpos($e->getMessage(), 'ERR_CONTEXT_MISMATCH') !== false);
}
```

#### **2.3 HAT without job_ticket_id or dag_token_id (Should Fail)**
```php
try {
    $service->generateSerial(
        tenantId: 1,
        productionType: 'hatthasilpa',
        sku: 'TEST'
        // ❌ Missing job_ticket_id and dag_token_id
    );
    // Should not reach here
    fail('Should have thrown ERR_CONTEXT_MISMATCH');
} catch (RuntimeException $e) {
    assert(strpos($e->getMessage(), 'ERR_CONTEXT_MISMATCH') !== false);
}
```

#### **2.4 OEM without mo_id or job_ticket_id (Should Fail)**
```php
try {
    $service->generateSerial(
        tenantId: 1,
        productionType: 'oem',
        sku: 'TEST'
        // ❌ Missing mo_id and job_ticket_id
    );
    // Should not reach here
    fail('Should have thrown ERR_CONTEXT_MISMATCH');
} catch (RuntimeException $e) {
    assert(strpos($e->getMessage(), 'ERR_CONTEXT_MISMATCH') !== false);
}
```

**Expected Results:**
- ✅ All context mismatches rejected
- ✅ Error code: `ERR_CONTEXT_MISMATCH`
- ✅ No serials created for invalid contexts

**Test File:** `tests/manual/test_context_validation.php`

---

### **Test 3: No Duplicate**

**Purpose:** Verify unique constraint prevents duplicate sequence numbers

**Test Steps:**
1. Create HAT job ticket with `target_qty = 100`
2. Generate serials concurrently (simulate multi-thread):
   ```php
   // Simulate concurrent requests
   for ($i = 0; $i < 10; $i++) {
       // Generate serials in parallel (simulated)
       generateSerialsForJob($jobTicketId, $qty = 10);
   }
   ```
3. Verify no duplicate `(id_job_ticket, sequence_no)` pairs:
   ```sql
   SELECT id_job_ticket, sequence_no, COUNT(*) as cnt
   FROM job_ticket_serial
   WHERE id_job_ticket = ?
   GROUP BY id_job_ticket, sequence_no
   HAVING cnt > 1;
   -- Should return 0 rows
   ```
4. Verify all serials have unique `sequence_no` (1 to 100)

**Expected Results:**
- ✅ No duplicate `(id_job_ticket, sequence_no)` pairs
- ✅ Constraint `uniq_ticket_seq` enforced
- ✅ All serials have unique sequence numbers (1-100)

**Test File:** `tests/manual/test_no_duplicate.php`

---

## 🟡 High Priority Tests

### **Test 4: Partial Spawn**

**Purpose:** Verify partial spawn works correctly (spawn some, leave others)

**Test Steps:**
1. Pre-generate 10 serials for job ticket
2. Verify 10 serials in `job_ticket_serial` with `spawned_at = NULL`
3. Spawn only 6 tokens via `dag_token_api.php`
4. Verify first spawn:
   - 6 serials have `spawned_at` set
   - 6 serials have `spawned_token_id` set
   - 4 serials still have `spawned_at = NULL`
5. Spawn 4 more tokens (second spawn)
6. Verify second spawn:
   - Uses remaining 4 serials (not new ones)
   - All 10 serials now have `spawned_at` set
   - No duplicates

**Expected Results:**
- ✅ First spawn: 6 serials linked
- ✅ Remaining: 4 serials unspawned
- ✅ Second spawn: Uses remaining 4 serials (no duplicates)
- ✅ All 10 serials eventually linked

**Test File:** `tests/manual/test_partial_spawn.php`

---

### **Test 5: Salt Rotation**

**Purpose:** Verify salt rotation maintains backward compatibility

**Test Steps:**
1. Generate serials with salt version 1:
   ```php
   // Generate 5 serials
   $serials_v1 = [];
   for ($i = 0; $i < 5; $i++) {
       $serials_v1[] = $service->generateSerial(...);
   }
   ```
2. Verify serials stored with `hash_salt_version = 1`:
   ```sql
   SELECT serial_code, hash_salt_version
   FROM serial_registry
   WHERE serial_code IN (...)
   -- All should have hash_salt_version = 1
   ```
3. Rotate salt to version 2 (via UI or API)
4. Verify secrets file updated:
   ```php
   $secrets = include 'storage/secrets/serial_salts.php';
   assert($secrets['hat']['version'] === 2);
   ```
5. Generate new serials (should use version 2):
   ```php
   $serials_v2 = [];
   for ($i = 0; $i < 5; $i++) {
       $serials_v2[] = $service->generateSerial(...);
   }
   ```
6. Verify new serials stored with `hash_salt_version = 2`
7. Verify old serials still verify correctly:
   ```php
   foreach ($serials_v1 as $serial) {
       $result = $service->verifySerial($serial);
       assert($result['valid'] === true);
       assert($result['hash_valid'] === true);
   }
   ```
8. Verify new serials verify correctly:
   ```php
   foreach ($serials_v2 as $serial) {
       $result = $service->verifySerial($serial);
       assert($result['valid'] === true);
       assert($result['hash_valid'] === true);
   }
   ```

**Expected Results:**
- ✅ Old serials (version 1) verify with salt version 1
- ✅ New serials (version 2) verify with salt version 2
- ✅ `hash_salt_version` stored correctly in registry
- ✅ Backward compatibility maintained

**Test File:** `tests/manual/test_salt_rotation.php`

---

## 📊 Test Execution Summary

### **Test Execution Order**

1. **Test 1: Dual-Link Consistency** (30 min)
2. **Test 2: Context Validation** (20 min)
3. **Test 3: No Duplicate** (30 min)
4. **Test 4: Partial Spawn** (20 min)
5. **Test 5: Salt Rotation** (30 min)

**Total Estimated Time:** 2 hours 10 minutes

### **Test Results Template**

```markdown
## Test Execution Results

**Date:** YYYY-MM-DD
**Tester:** [Name]
**Environment:** [Development/Staging]

| Test | Status | Notes |
|------|--------|-------|
| Test 1: Dual-Link Consistency | ✅ Pass / ❌ Fail | |
| Test 2: Context Validation | ✅ Pass / ❌ Fail | |
| Test 3: No Duplicate | ✅ Pass / ❌ Fail | |
| Test 4: Partial Spawn | ✅ Pass / ❌ Fail | |
| Test 5: Salt Rotation | ✅ Pass / ❌ Fail | |

**Overall Status:** ✅ All Pass / ⚠️ Some Fail / ❌ All Fail

**Issues Found:**
- [List any issues]

**Next Steps:**
- [List next steps]
```

---

## 🔗 Related Documents

- `SERIAL_SYSTEM_READINESS.md` - Readiness assessment
- `SERIAL_SYSTEM_STATUS.md` - Detailed status report
- `SERIAL_NUMBER_IMPLEMENTATION.md` - Implementation guide

---

**Status:** 🟡 **Ready to Execute**  
**Last Updated:** November 9, 2025

