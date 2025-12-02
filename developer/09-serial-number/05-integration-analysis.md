# 🔍 Serial Number System - Integration Analysis

**Created:** November 9, 2025  
**Purpose:** Analysis of current DAG and Job Ticket serial number logic to ensure UnifiedSerialService integration compatibility  
**Status:** ✅ **Pre-Implementation Analysis Complete**

---

## 📋 Executive Summary

This document analyzes the current serial number generation logic in the DAG Token and Job Ticket systems to identify integration points, potential conflicts, and required modifications for `UnifiedSerialService` deployment.

**Key Findings:**
- ✅ Job Ticket system pre-generates serials in `job_ticket_serial` table
- ⚠️ DAG Token spawn generates serials again (duplicate generation)
- ⚠️ Missing link between `job_ticket_serial` and `flow_token` after spawn
- ⚠️ OEM flow uses legacy format (not standardized)
- ✅ `SerialManagementService` has `markAsSpawned()` but not used

---

## 🔄 Current System Flow

### **1. Hatthasilpa Job Ticket Creation Flow**

**File:** `source/hatthasilpa_job_ticket.php` (lines 450-475)

**Process:**
1. Job ticket created with `process_mode = 'piece'`
2. **Auto-generate serials** using `SerialManagementService::generateSerialsForJob()`
3. Serials stored in `job_ticket_serial` table:
   - `id_job_ticket` (FK)
   - `serial_number` (pre-generated)
   - `sequence_no` (1, 2, 3...)
   - `generated_at` (timestamp)
   - `spawned_at` = NULL (not yet spawned)
   - `spawned_token_id` = NULL (not yet linked)

**Current Serial Format:**
- Uses `SecureSerialGenerator::generate()` or `bulkGenerate()`
- Format: `{PREFIX}-{YEAR}-{HASH-6}` (legacy format)
- Example: `TOTE-2025-A7F3C9`

**Code Reference:**
```php
// hatthasilpa_job_ticket.php:450-475
if ($processMode === 'piece' && $targetQty > 0 && $targetQty <= 1000) {
    $prefix = $sku ?: preg_replace('/[^A-Z0-9]/', '', strtoupper($jobName));
    $serialService = new \BGERP\Service\SerialManagementService($tenantDb);
    $generatedSerials = $serialService->generateSerialsForJob(
        $insertId,
        $targetQty,
        $processMode,
        $prefix
    );
}
```

---

### **2. DAG Token Spawn Flow**

**File:** `source/dag_token_api.php` (lines 333-355)

**Process:**
1. User triggers token spawn for job ticket
2. **⚠️ PROBLEM: Generate serials AGAIN** (even though `job_ticket_serial` already has them)
3. Uses `SecureSerialGenerator::generate()` directly (not `SerialManagementService`)
4. Passes serials array to `TokenLifecycleService::spawnTokens()`
5. Tokens created with `flow_token.serial_number` set
6. **⚠️ PROBLEM: No link back to `job_ticket_serial.spawned_token_id`**

**Code Reference:**
```php
// dag_token_api.php:333-355
// ⚠️ CRITICAL: Generate serials BEFORE spawning tokens
$serials = [];
if ($ticket['process_mode'] === 'piece') {
    for ($i = 0; $i < $ticket['target_qty']; $i++) {
        $serial = SecureSerialGenerator::generate(
            $ticket['ticket_code'], 
            $db->getTenantDb(), 
            $ticketId
        );
        $serials[] = $serial;
    }
}

$tokenService = new TokenLifecycleService($db->getTenantDb());
$tokenIds = $tokenService->spawnTokens(
    $instanceId,
    $ticket['target_qty'],
    $ticket['process_mode'],
    $serials  // ← Serial array passed here
);
```

**TokenLifecycleService Behavior:**
```php
// TokenLifecycleService.php:37-99
public function spawnTokens(int $instanceId, int $targetQty, string $processMode, array $serials = []): array
{
    if ($processMode === 'piece') {
        for ($i = 0; $i < $targetQty; $i++) {
            $serial = $serials[$i] ?? null;  // ← Uses provided serial
            $tokenId = $this->createToken([
                'instance_id' => $instanceId,
                'token_type' => 'piece',
                'serial_number' => $serial,  // ← Stored in flow_token
                // ...
            ]);
        }
    }
}
```

---

### **3. OEM Manufacturing Order Flow**

**File:** `source/mo.php` (lines 930-948)

**Process:**
1. MO created with `production_type = 'oem'`
2. **Legacy serial format:** `{mo_code}-{sequence}`
3. Direct insert to `flow_token` (no pre-generation table)
4. **⚠️ PROBLEM: Not using standardized format**

**Code Reference:**
```php
// mo.php:930-948
for ($i = 1; $i <= $tokensToSpawn; $i++) {
    $serialNumber = $mo['mo_code'] . '-' . str_pad($i, 4, '0', STR_PAD_LEFT);
    // Example: "MO-2025-0001"
    
    $stmt = $dbConn->prepare("
        INSERT INTO flow_token
        (id_graph_instance, id_mo, current_node_id, token_code, 
         status, spawned_at, spawned_by)
        VALUES (?, ?, ?, ?, 'active', NOW(), ?)
    ");
    // ← Direct insert, no serial_registry
}
```

---

## 🗄️ Current Database Schema

### **job_ticket_serial** (Tenant DB)

**Purpose:** Pre-assigned serials for job tickets (generated at creation, used at spawn)

```sql
CREATE TABLE job_ticket_serial (
    id_serial INT PRIMARY KEY AUTO_INCREMENT,
    id_job_ticket INT NOT NULL,
    serial_number VARCHAR(100) NOT NULL,
    sequence_no INT NOT NULL,
    generated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    spawned_at DATETIME NULL,  -- ← Should be set when token spawned
    spawned_token_id INT NULL, -- ← Should link to flow_token.id_token
    UNIQUE KEY idx_serial (serial_number),
    KEY idx_ticket (id_job_ticket),
    KEY idx_spawned (spawned_at, spawned_token_id)
);
```

**Current State:**
- ✅ Serials generated at job ticket creation
- ❌ `spawned_at` and `spawned_token_id` NOT set during token spawn
- ❌ No link between `job_ticket_serial` and `flow_token`

---

### **flow_token** (Tenant DB)

**Purpose:** DAG tokens flowing through routing graph

```sql
CREATE TABLE flow_token (
    id_token INT PRIMARY KEY AUTO_INCREMENT,
    id_instance INT NOT NULL,
    token_type ENUM('batch', 'piece', 'component') NOT NULL DEFAULT 'piece',
    serial_number VARCHAR(100) NULL,  -- ← Serial stored here
    current_node_id INT NULL,
    status ENUM('active', 'completed', 'scrapped') NOT NULL DEFAULT 'active',
    qty DECIMAL(10,2) DEFAULT 1.00,
    spawned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    -- ...
);
```

**Current State:**
- ✅ Serial stored in `flow_token.serial_number`
- ❌ No foreign key to `job_ticket_serial`
- ❌ No link to `serial_registry` (Core DB)

---

## ⚠️ Identified Issues

### **Issue 1: Duplicate Serial Generation**

**Problem:**
- Serials generated **twice**: once at job creation, once at token spawn
- Different serials generated each time (no reuse of `job_ticket_serial`)

**Impact:**
- Wasted serials in `job_ticket_serial` (never used)
- Potential serial collision if both systems generate same serial
- Data inconsistency

**Current Code:**
```php
// Job Ticket Creation (hatthasilpa_job_ticket.php)
$generatedSerials = $serialService->generateSerialsForJob(...);  // ← First generation

// Token Spawn (dag_token_api.php)
$serial = SecureSerialGenerator::generate(...);  // ← Second generation (different serial!)
```

---

### **Issue 2: Missing Link Between Tables**

**Problem:**
- `SerialManagementService` has `markAsSpawned()` method but **not called**
- `job_ticket_serial.spawned_token_id` never set
- Cannot trace which token uses which pre-generated serial

**Impact:**
- Cannot query "which serials are still unspawned?"
- Cannot trace serial lifecycle (generation → spawn → completion)
- Reporting gaps

**Available Method (Not Used):**
```php
// SerialManagementService.php:217-238
public function markAsSpawned(string $serial, int $tokenId): bool
{
    // Updates job_ticket_serial.spawned_at and spawned_token_id
    // ← This method exists but is NEVER called!
}
```

---

### **Issue 3: Legacy OEM Serial Format**

**Problem:**
- OEM flow uses `{mo_code}-{sequence}` format (e.g., `MO-2025-0001`)
- Not using standardized format: `{TENANT}-{PROD_TYPE}-{SKU}-{YYYYMMDD}-{SEQ}-{HASH-4}-{CHECKSUM}`
- No registry entry in `serial_registry` (Core DB)

**Impact:**
- Cannot verify OEM serials via public API
- No global uniqueness check
- No security hash/checksum validation

---

### **Issue 4: No Production Type Context**

**Problem:**
- Current system doesn't distinguish `production_type` ('hatthasilpa' vs 'oem')
- Both use same `SecureSerialGenerator` service
- No context-aware serial generation

**Impact:**
- Cannot apply different serial formats per production type
- Cannot use production-type-specific salts
- Cannot enforce HAT vs OEM validation rules

---

## ✅ Integration Points for UnifiedSerialService

### **Integration Point 1: Job Ticket Creation**

**Current:** `hatthasilpa_job_ticket.php:450-475`

**Required Changes:**
1. Replace `SerialManagementService::generateSerialsForJob()` with `UnifiedSerialService::generateSerial()`
2. Store serials in `job_ticket_serial` table (keep existing structure)
3. **Also register** in `serial_registry` (Core DB) with:
   - `production_type = 'hatthasilpa'`
   - `job_ticket_id` set
   - `dag_token_id` = NULL (not spawned yet)
   - `serial_scope = 'piece'`
   - `linked_source = 'job_ticket'`

**Proposed Code:**
```php
// hatthasilpa_job_ticket.php (modified)
if ($processMode === 'piece' && $targetQty > 0 && $targetQty <= 1000) {
    $unifiedSerialService = new \BGERP\Service\UnifiedSerialService($coreDb, $tenantDb);
    
    for ($i = 0; $i < $targetQty; $i++) {
        // Generate standardized serial
        $serial = $unifiedSerialService->generateSerial(
            tenantId: $tenantId,
            productionType: 'hatthasilpa',
            sku: $sku ?: $jobName,
            jobTicketId: $insertId,
            dagTokenId: null,  // Not spawned yet
            originSource: 'auto_job'
        );
        
        // Store in job_ticket_serial (existing table)
        $stmt = $tenantDb->prepare("
            INSERT INTO job_ticket_serial 
            (id_job_ticket, serial_number, sequence_no)
            VALUES (?, ?, ?)
        ");
        $stmt->bind_param('isi', $insertId, $serial, $i + 1);
        $stmt->execute();
        $stmt->close();
        
        $generatedSerials[] = $serial;
    }
}
```

---

### **Integration Point 2: DAG Token Spawn**

**Current:** `dag_token_api.php:333-355`

**Required Changes:**
1. **Reuse** serials from `job_ticket_serial` (don't generate again!)
2. Link `job_ticket_serial.spawned_token_id` when token created
3. Update `serial_registry.dag_token_id` when token spawned

**Proposed Code:**
```php
// dag_token_api.php (modified)
// ✅ REUSE serials from job_ticket_serial (don't generate again!)
$serialService = new \BGERP\Service\SerialManagementService($db->getTenantDb());
$preGeneratedSerials = $serialService->getJobSerials($ticketId);

$serials = [];
if ($ticket['process_mode'] === 'piece') {
    foreach ($preGeneratedSerials as $idx => $serialRow) {
        if ($serialRow['spawned_at'] === null) {  // Only unspawned serials
            $serials[] = $serialRow['serial_number'];
        }
    }
    
    // If not enough serials, generate additional ones
    if (count($serials) < $ticket['target_qty']) {
        $unifiedSerialService = new \BGERP\Service\UnifiedSerialService($db, $db->getTenantDb());
        for ($i = count($serials); $i < $ticket['target_qty']; $i++) {
            $serial = $unifiedSerialService->generateSerial(
                tenantId: $tenantId,
                productionType: 'hatthasilpa',
                sku: $ticket['sku'],
                jobTicketId: $ticketId,
                dagTokenId: null,  // Will be set after spawn
                originSource: 'auto_job'
            );
            $serials[] = $serial;
        }
    }
}

// Spawn tokens
$tokenService = new TokenLifecycleService($db->getTenantDb());
$tokenIds = $tokenService->spawnTokens(
    $instanceId,
    $ticket['target_qty'],
    $ticket['process_mode'],
    $serials
);

// ✅ Link job_ticket_serial to flow_token
foreach ($tokenIds as $idx => $tokenId) {
    if (isset($serials[$idx])) {
        $serialService->markAsSpawned($serials[$idx], $tokenId);
        
        // ✅ Update serial_registry.dag_token_id
        $unifiedSerialService->linkDagToken($serials[$idx], $tokenId);
    }
}
```

---

### **Integration Point 3: OEM Manufacturing Order**

**Current:** `mo.php:930-948`

**Required Changes:**
1. Replace legacy format with standardized format
2. Register in `serial_registry` (Core DB) with:
   - `production_type = 'oem'`
   - `mo_id` set
   - `job_ticket_id` = NULL (if no job ticket)
   - `dag_token_id` = NULL (OEM doesn't use DAG)
   - `serial_scope = 'batch'`
   - `linked_source = 'job_ticket'` (if job ticket exists)

**Proposed Code:**
```php
// mo.php (modified)
$unifiedSerialService = new \BGERP\Service\UnifiedSerialService($coreDb, $tenantDb);

for ($i = 1; $i <= $tokensToSpawn; $i++) {
    // Generate standardized OEM serial
    $serialNumber = $unifiedSerialService->generateSerial(
        tenantId: $tenantId,
        productionType: 'oem',
        sku: $mo['sku'] ?? $mo['mo_code'],
        moId: $mo['id_mo'],
        jobTicketId: null,  // OEM may not have job ticket
        dagTokenId: null,   // OEM doesn't use DAG
        originSource: 'auto_mo'
    );
    
    // Create token with standardized serial
    $stmt = $dbConn->prepare("
        INSERT INTO flow_token
        (id_graph_instance, id_mo, current_node_id, serial_number, 
         status, spawned_at, spawned_by)
        VALUES (?, ?, ?, ?, 'active', NOW(), ?)
    ");
    $stmt->bind_param('iiisi', 
        $graphInstanceId, $mo['id_mo'], $startNode['id_node'], 
        $serialNumber, $member['id_member']
    );
    $stmt->execute();
    $stmt->close();
}
```

---

## 🔗 Required Service Methods

### **UnifiedSerialService::linkDagToken()**

**Purpose:** Link existing serial in `serial_registry` to DAG token

```php
public function linkDagToken(string $serialCode, int $dagTokenId): bool
{
    // Update serial_registry.dag_token_id
    // Validate that production_type = 'hatthasilpa'
    // Validate that dag_token_id was NULL (not already linked)
}
```

---

### **UnifiedSerialService::getUnspawnedSerials()**

**Purpose:** Get unspawned serials for a job ticket

```php
public function getUnspawnedSerials(int $jobTicketId): array
{
    // Query job_ticket_serial WHERE spawned_at IS NULL
    // Return serial_number array
}
```

---

## 📊 Migration Strategy

### **Phase 1: Backward Compatibility**

1. ✅ Keep `job_ticket_serial` table (existing structure)
2. ✅ Keep `flow_token.serial_number` field (existing structure)
3. ✅ Add `serial_registry` table (new, Core DB)
4. ✅ Dual-write: Write to both old and new tables during transition

### **Phase 2: Integration**

1. ✅ Update `hatthasilpa_job_ticket.php` to use `UnifiedSerialService`
2. ✅ Update `dag_token_api.php` to reuse `job_ticket_serial` serials
3. ✅ Update `mo.php` to use standardized format
4. ✅ Add `markAsSpawned()` calls after token creation

### **Phase 3: Cleanup**

1. ✅ Migrate legacy serials to `serial_registry` (if needed)
2. ✅ Deprecate `SecureSerialGenerator` (keep for backward compatibility)
3. ✅ Update all serial verification to use `serial_registry`

---

## ✅ Validation Checklist

### **Pre-Integration Checks:**

- [ ] `serial_registry` table created (Core DB)
- [ ] `serial_seq_daily` table created (Core DB)
- [ ] `organization.org_serial_code` populated for all tenants
- [ ] `SERIAL_SECRET_SALT_HAT` environment variable set
- [ ] `SERIAL_SECRET_SALT_OEM` environment variable set
- [ ] PHP timezone set to UTC

### **Integration Checks:**

- [ ] Job ticket creation generates standardized serials
- [ ] Serials registered in `serial_registry` (Core DB)
- [ ] Token spawn reuses `job_ticket_serial` serials (no duplicate generation)
- [ ] `job_ticket_serial.spawned_token_id` linked after spawn
- [ ] `serial_registry.dag_token_id` updated after spawn
- [ ] OEM serials use standardized format
- [ ] Legacy serials still verify (backward compatibility)

### **Post-Integration Checks:**

- [ ] All serials verify via `UnifiedSerialService::verifySerial()`
- [ ] Public verify API works for Hatthasilpa serials
- [ ] Public verify API works for OEM serials
- [ ] No serial collisions (unique constraint works)
- [ ] Daily sequence reset works correctly

---

## 📝 Notes for Implementation

1. **Critical Order:** Generate serials BEFORE spawning tokens (already correct in `dag_token_api.php`)
2. **Reuse Pattern:** Always check `job_ticket_serial` first, generate only if missing
3. **Link Pattern:** Always call `markAsSpawned()` after token creation
4. **Context Validation:** Enforce HAT vs OEM rules (see `SERIAL_NUMBER_DESIGN.md`)
5. **Error Handling:** Fail fast on context mismatch (HAT with `mo_id`, OEM with `dag_token_id`)

---

## 🔗 Related Documents

- `SERIAL_NUMBER_DESIGN.md` - Design specification
- `SERIAL_CONTEXT_AWARENESS.md` - Production context differences
- `SERIAL_NUMBER_IMPLEMENTATION.md` - Implementation guide
- `SERIAL_NUMBER_INDEX.md` - Master index

---

---

## 🎯 Implementation Action Plan

**Status:** ✅ **Ready to Execute**  
**Priority:** 🔴 **CRITICAL** - Fix before UnifiedSerialService deployment

This section provides **actionable steps** with **copy-paste ready code** to fix all identified issues.

---

### **Step 1: Fix DAG Token Spawn - Reuse Pre-Generated Serials**

**Problem:** `dag_token_api.php` generates serials again instead of reusing `job_ticket_serial` entries.

**Solution:** Always fetch from `job_ticket_serial` first, generate only if missing.

**Code Changes:**

```php
// dag_token_api.php (replace lines 333-346)

// ✅ STEP 1: Get pre-generated serials from job_ticket_serial
$serialService = new \BGERP\Service\SerialManagementService($db->getTenantDb());
$preGeneratedSerials = $serialService->getUnspawnedSerials($ticketId);

$serials = [];
if ($ticket['process_mode'] === 'piece') {
    // Use pre-generated serials (deterministic order by sequence_no)
    foreach ($preGeneratedSerials as $serialRow) {
        $serials[] = $serialRow['serial_number'];
    }
    
    // ✅ STEP 2: If not enough serials, generate additional ones
    if (count($serials) < $ticket['target_qty']) {
        $unifiedSerialService = new \BGERP\Service\UnifiedSerialService($db, $db->getTenantDb());
        $tenantId = $db->getTenantId(); // Get tenant ID
        
        for ($i = count($serials); $i < $ticket['target_qty']; $i++) {
            // Generate standardized serial
            $serial = $unifiedSerialService->generateSerial(
                tenantId: $tenantId,
                productionType: 'hatthasilpa',
                sku: $ticket['sku'] ?: preg_replace('/[^A-Z0-9]/', '', strtoupper($ticket['job_name'])),
                jobTicketId: $ticketId,
                dagTokenId: null,  // Will be set after spawn
                originSource: 'auto_job'
            );
            
            // Insert into job_ticket_serial for tracking
            $stmt = $db->getTenantDb()->prepare("
                INSERT INTO job_ticket_serial 
                (id_job_ticket, serial_number, sequence_no)
                VALUES (?, ?, ?)
            ");
            $sequenceNo = $i + 1;
            $stmt->bind_param('isi', $ticketId, $serial, $sequenceNo);
            $stmt->execute();
            $stmt->close();
            
            $serials[] = $serial;
        }
    }
    
    // Ensure we have exactly target_qty serials
    $serials = array_slice($serials, 0, $ticket['target_qty']);
}
```

**Required Method (add to SerialManagementService):**

```php
// SerialManagementService.php

/**
 * Get unspawned serials for a job ticket (ordered by sequence_no)
 * 
 * @param int $jobTicketId
 * @return array Array of serial rows with 'serial_number' key
 */
public function getUnspawnedSerials(int $jobTicketId): array
{
    $stmt = $this->db->prepare("
        SELECT serial_number, sequence_no
        FROM job_ticket_serial 
        WHERE id_job_ticket = ? AND spawned_at IS NULL
        ORDER BY sequence_no ASC
    ");
    
    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $this->db->error);
    }
    
    $stmt->bind_param('i', $jobTicketId);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $serials = [];
    while ($row = $result->fetch_assoc()) {
        $serials[] = $row;
    }
    
    $stmt->close();
    
    return $serials;
}
```

---

### **Step 2: Link Back After Spawn (Dual-Write Pattern)**

**Problem:** `markAsSpawned()` exists but never called. No link between `job_ticket_serial` and `flow_token`.

**Solution:** Call `markAsSpawned()` and `linkDagToken()` after token creation.

**Code Changes:**

```php
// dag_token_api.php (after spawnTokens(), before commit)

// Spawn tokens
$tokenService = new TokenLifecycleService($db->getTenantDb());
$tokenIds = $tokenService->spawnTokens(
    $instanceId,
    $ticket['target_qty'],
    $ticket['process_mode'],
    $serials
);

// ✅ STEP 2: Link serials back to tokens (dual-write pattern)
$unifiedSerialService = new \BGERP\Service\UnifiedSerialService($db, $db->getTenantDb());

foreach ($tokenIds as $i => $tokenId) {
    $serial = $serials[$i] ?? null;
    if (!$serial) continue;
    
    try {
        // Link in Tenant DB (job_ticket_serial)
        $serialService->markAsSpawned($serial, $tokenId);
        
        // Link in Core DB (serial_registry)
        $unifiedSerialService->linkDagToken($serial, $tokenId);
        
    } catch (\Throwable $e) {
        // Log error but don't fail entire spawn
        error_log(sprintf(
            "[CID:%s][dag_token_api][linkSerial] Failed to link serial %s to token %d: %s",
            $cid ?? 'N/A',
            $serial,
            $tokenId,
            $e->getMessage()
        ));
        
        // TODO: Add retry job for Core DB failures
        // For now, log and continue (Tenant DB link is critical)
    }
}
```

**Required Method (add to UnifiedSerialService):**

```php
// UnifiedSerialService.php

/**
 * Link existing serial in serial_registry to DAG token
 * 
 * @param string $serialCode Serial code to link
 * @param int $dagTokenId DAG token ID
 * @return bool Success
 * @throws RuntimeException If serial not found, wrong production type, or already linked
 */
public function linkDagToken(string $serialCode, int $dagTokenId): bool
{
    // Get serial from registry
    $row = $this->registryGet($serialCode);
    if (!$row) {
        throw new RuntimeException('ERR_NOT_FOUND: Serial not found in registry');
    }
    
    // Validate production type
    if ($row['production_type'] !== 'hatthasilpa') {
        throw new RuntimeException('ERR_CONTEXT_MISMATCH: Only Hatthasilpa serials can link to DAG tokens');
    }
    
    // Validate not already linked
    if (!is_null($row['dag_token_id'])) {
        throw new RuntimeException('ERR_ALREADY_LINKED: Serial already linked to token ' . $row['dag_token_id']);
    }
    
    // Update registry
    $stmt = $this->coreDb->prepare("
        UPDATE serial_registry 
        SET dag_token_id = ?
        WHERE serial_code = ? AND dag_token_id IS NULL
    ");
    $stmt->bind_param('is', $dagTokenId, $serialCode);
    $stmt->execute();
    $affected = $stmt->affected_rows;
    $stmt->close();
    
    if ($affected === 0) {
        throw new RuntimeException('ERR_UPDATE_FAILED: Failed to link serial (may have been linked concurrently)');
    }
    
    return true;
}
```

**Update markAsSpawned() Method:**

```php
// SerialManagementService.php (update existing method)

public function markAsSpawned(string $serial, int $tokenId): bool
{
    $stmt = $this->db->prepare("
        UPDATE job_ticket_serial 
        SET spawned_at = UTC_TIMESTAMP(),
            spawned_token_id = ?
        WHERE serial_number = ? 
          AND spawned_at IS NULL
        LIMIT 1
    ");
    
    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $this->db->error);
    }
    
    $stmt->bind_param('is', $tokenId, $serial);
    $stmt->execute();
    $affected = $stmt->affected_rows;
    $stmt->close();
    
    return $affected > 0;
}
```

---

### **Step 3: Standardize OEM Serial Format**

**Problem:** OEM flow uses legacy format `{mo_code}-{sequence}` instead of standardized format.

**Solution:** Use `UnifiedSerialService::generateSerial()` with `production_type='oem'`.

**Code Changes:**

```php
// mo.php (replace lines 930-948)

$unifiedSerialService = new \BGERP\Service\UnifiedSerialService($coreDb, $tenantDb);
$tenantId = $db->getTenantId(); // Get tenant ID

for ($i = 1; $i <= $tokensToSpawn; $i++) {
    // Generate standardized OEM serial
    $serialNumber = $unifiedSerialService->generateSerial(
        tenantId: $tenantId,
        productionType: 'oem',
        sku: $mo['sku'] ?? preg_replace('/[^A-Z0-9]/', '', strtoupper($mo['mo_code'])),
        moId: $mo['id_mo'],
        jobTicketId: null,  // OEM may not have job ticket
        dagTokenId: null,   // OEM doesn't use DAG
        originSource: 'auto_mo'
    );
    
    // Create token with standardized serial
    $stmt = $dbConn->prepare("
        INSERT INTO flow_token
        (id_instance, id_mo, current_node_id, serial_number, 
         status, spawned_at, spawned_by)
        VALUES (?, ?, ?, ?, 'active', NOW(), ?)
    ");
    $stmt->bind_param('iiisi', 
        $graphInstanceId, 
        $mo['id_mo'], 
        $startNode['id_node'], 
        $serialNumber, 
        $member['id_member']
    );
    
    if (!$stmt->execute()) {
        $stmt->close();
        throw new \Exception('Failed to create token: ' . $stmt->error);
    }
    
    $stmt->close();
}
```

---

### **Step 4: Enforce Invariants (Fail-Fast Validation)**

**Problem:** No validation for context mismatch (HAT with `mo_id`, OEM with `dag_token_id`).

**Solution:** Add validation in `UnifiedSerialService::generateSerial()` and `linkDagToken()`.

**Code Changes:**

```php
// UnifiedSerialService.php (add to generateSerial method)

public function generateSerial(
    int $tenantId,
    string $productionType,
    string $sku,
    ?int $moId = null,
    ?int $jobTicketId = null,
    ?int $dagTokenId = null,
    string $originSource = 'auto_job'
): string {
    // ✅ STEP 4: Enforce invariants (fail fast)
    
    // Validate production type
    if (!in_array($productionType, ['hatthasilpa', 'oem'], true)) {
        throw new RuntimeException('ERR_INVALID_PRODUCTION_TYPE: Must be hatthasilpa or oem');
    }
    
    // Hatthasilpa invariants
    if ($productionType === 'hatthasilpa') {
        if ($moId !== null) {
            throw new RuntimeException('ERR_CONTEXT_MISMATCH: Hatthasilpa cannot have mo_id');
        }
        if ($dagTokenId === null && $jobTicketId === null) {
            throw new RuntimeException('ERR_CONTEXT_MISMATCH: Hatthasilpa must have dag_token_id or job_ticket_id');
        }
    }
    
    // OEM invariants
    if ($productionType === 'oem') {
        if ($dagTokenId !== null) {
            throw new RuntimeException('ERR_CONTEXT_MISMATCH: OEM cannot have dag_token_id');
        }
        if ($moId === null && $jobTicketId === null) {
            throw new RuntimeException('ERR_CONTEXT_MISMATCH: OEM must have mo_id or job_ticket_id');
        }
    }
    
    // Continue with serial generation...
    // (rest of method)
}
```

---

## 🧱 SQL Hardening Patches

### **Patch 1: Deterministic Serial Order + Prevent Duplicates**

```sql
-- Tenant DB: job_ticket_serial
ALTER TABLE job_ticket_serial
  ADD UNIQUE KEY uniq_ticket_seq (id_job_ticket, sequence_no) COMMENT 'Prevent duplicate sequence numbers',
  ADD KEY idx_ticket_unspawned (id_job_ticket, spawned_at) COMMENT 'Fast lookup for unspawned serials';
```

### **Patch 2: Fast Link Queries**

```sql
-- Core DB: serial_registry
ALTER TABLE serial_registry
  ADD KEY idx_link_dag (dag_token_id) COMMENT 'Fast lookup by DAG token',
  ADD KEY idx_link_job (job_ticket_id, production_type) COMMENT 'Fast lookup by job ticket',
  ADD KEY idx_link_mo (mo_id, production_type) COMMENT 'Fast lookup by MO';
```

### **Patch 3: Case-Sensitive Serial Code**

```sql
-- Core DB: serial_registry (if not already applied)
ALTER TABLE serial_registry 
  MODIFY serial_code VARCHAR(64) 
    CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL 
    COMMENT 'Case-sensitive serial code';
```

---

## 🧪 Test Scenarios (Must Pass)

### **Test 1: No-Duplicate on Spawn**

**Scenario:**
1. Pre-generate 10 serials for job ticket
2. Spawn 10 tokens
3. Verify no new serials generated
4. Verify all `job_ticket_serial.spawned_at` set

**Expected:**
- ✅ No calls to `UnifiedSerialService::generateSerial()` during spawn
- ✅ All 10 `spawned_at` timestamps set
- ✅ All 10 `spawned_token_id` linked

### **Test 2: OEM Standardization**

**Scenario:**
1. Create MO with `production_type='oem'`
2. Spawn 3 batch tokens
3. Verify serials use standardized format
4. Verify all serials in `serial_registry`

**Expected:**
- ✅ Serial format: `{TENANT}-OEM-{SKU}-{YYYYMMDD}-{SEQ}-{HASH-4}-{CHECKSUM}`
- ✅ All 3 serials in `serial_registry` with `production_type='oem'`
- ✅ `serial_scope='batch'`, `linked_source='job_ticket'` or `'mo'`

### **Test 3: Link Integrity**

**Scenario:**
1. Spawn HAT tokens
2. Verify `serial_registry.dag_token_id` set
3. Verify `job_ticket_serial.spawned_token_id` set

**Expected:**
- ✅ All `serial_registry.dag_token_id` match `flow_token.id_token`
- ✅ All `job_ticket_serial.spawned_token_id` match `flow_token.id_token`
- ✅ No orphaned serials (serial without token link)

### **Test 4: Partial Spawn**

**Scenario:**
1. Pre-generate 10 serials
2. Spawn only 6 tokens (partial)
3. Verify 6 serials linked, 4 remain unspawned

**Expected:**
- ✅ 6 `spawned_at` timestamps set
- ✅ 4 `spawned_at` remain NULL
- ✅ Next spawn uses remaining 4 serials

### **Test 5: Backfill Missing Serials**

**Scenario:**
1. Create job ticket with `target_qty=10`
2. No pre-generated serials exist
3. Spawn tokens
4. Verify serials generated and inserted into `job_ticket_serial`

**Expected:**
- ✅ 10 serials generated during spawn
- ✅ All 10 serials inserted into `job_ticket_serial`
- ✅ All 10 serials linked to tokens

### **Test 6: Invariant Enforcement**

**Scenario:**
1. Try to generate HAT serial with `mo_id` set
2. Try to generate OEM serial with `dag_token_id` set
3. Try to link serial twice

**Expected:**
- ✅ `ERR_CONTEXT_MISMATCH` for HAT with `mo_id`
- ✅ `ERR_CONTEXT_MISMATCH` for OEM with `dag_token_id`
- ✅ `ERR_ALREADY_LINKED` for duplicate link

---

## 📈 Monitoring & Telemetry

### **Metrics to Track:**

```php
// Add to UnifiedSerialService and SerialManagementService

private function recordMetric(string $type, ?int $tenantId = null, int $value = 1): void
{
    $stmt = $this->coreDb->prepare("
        INSERT INTO serial_metrics 
        (metric_date, metric_type, tenant_id, count_value)
        VALUES (CURDATE(), ?, ?, ?)
        ON DUPLICATE KEY UPDATE count_value = count_value + ?
    ");
    $stmt->bind_param('siii', $type, $tenantId, $value, $value);
    $stmt->execute();
    $stmt->close();
}
```

**Key Metrics:**

1. **`serial.pre_generated_total`** - Total serials pre-generated per day
2. **`serial.spawn_used_total`** - Total serials used during spawn
3. **`serial.spawn_missing_total`** - Total serials that had to be generated during spawn (should be 0)
4. **`serial.link_fail_total`** - Total link failures (invariant violations, already linked)
5. **`serial.oem_generated_total`** - Total OEM serials generated
6. **`serial.hat_generated_total`** - Total Hatthasilpa serials generated

**Dashboard Queries:**

```sql
-- Daily pre-generated vs used
SELECT 
    metric_date,
    SUM(CASE WHEN metric_type = 'pre_generated_total' THEN count_value ELSE 0 END) as pre_generated,
    SUM(CASE WHEN metric_type = 'spawn_used_total' THEN count_value ELSE 0 END) as used,
    SUM(CASE WHEN metric_type = 'spawn_missing_total' THEN count_value ELSE 0 END) as missing
FROM serial_metrics
WHERE metric_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY metric_date
ORDER BY metric_date DESC;

-- Production type distribution
SELECT 
    production_type,
    COUNT(*) as total_serials,
    COUNT(CASE WHEN dag_token_id IS NOT NULL THEN 1 END) as linked_tokens
FROM serial_registry
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY production_type;
```

---

## ✅ Implementation Checklist

### **Pre-Implementation:**

- [ ] Review all 4 steps above
- [ ] Apply SQL hardening patches (3 patches)
- [ ] Add required methods to services (`getUnspawnedSerials`, `linkDagToken`)
- [ ] Update `markAsSpawned()` method
- [ ] Add invariant validation to `generateSerial()`

### **Implementation:**

- [ ] Update `dag_token_api.php` (Step 1: Reuse pre-generated serials)
- [ ] Update `dag_token_api.php` (Step 2: Link back after spawn)
- [ ] Update `mo.php` (Step 3: Standardize OEM format)
- [ ] Add monitoring/metrics recording

### **Post-Implementation:**

- [ ] Run all 6 test scenarios
- [ ] Verify monitoring metrics are recording
- [ ] Check dashboard queries return expected data
- [ ] Monitor for `spawn_missing_total` (should be 0)
- [ ] Monitor for `link_fail_total` (should be 0)

---

## ✅ Analysis Completeness Checklist

### **Covered Areas:**

- ✅ **Current System Flow** - Job Ticket, DAG Token Spawn, OEM MO flows analyzed
- ✅ **Database Schema** - `job_ticket_serial`, `flow_token` reviewed
- ✅ **Integration Points** - 3 main integration points identified with proposed code
- ✅ **Issues Identified** - 4 critical issues documented
- ✅ **Migration Strategy** - 3-phase approach defined
- ✅ **Validation Checklist** - Pre/Integration/Post checks defined

### **Additional Considerations (Already Covered in Other Docs):**

- ✅ **Backward Compatibility** - Covered in `SERIAL_NUMBER_IMPLEMENTATION.md` (format detection)
- ✅ **Legacy Serial Verification** - Covered in `SerialManagementService::serialExists()` (checks multiple tables)
- ✅ **Collision Handling** - Covered in `SERIAL_NUMBER_IMPLEMENTATION.md` (Fail-Safe & Recovery section)
- ✅ **Rollback/Cancellation** - Covered in `TokenLifecycleService::cancelToken()` (existing system)
- ✅ **Performance** - Covered in `SERIAL_NUMBER_IMPLEMENTATION.md` (INSERT-only technique, atomic operations)
- ✅ **Edge Cases** - Covered in `SERIAL_TRACKING_EDGE_CASES.md` (15+ edge cases documented)
- ✅ **Security** - Covered in `SERIAL_NUMBER_DESIGN.md` (HMAC-SHA256, production-type-specific salts)

### **Optional Enhancements (Post-Implementation):**

- 🔵 **Legacy Serial Migration Script** - Optional: Migrate existing legacy serials to `serial_registry` (if needed)
- 🔵 **Performance Benchmarks** - Optional: Document actual performance metrics after deployment
- 🔵 **Rollback Plan** - Optional: Detailed rollback procedure if implementation fails (covered in Fail-Safe section)
- 🔵 **Monitoring Dashboard** - Optional: Real-time monitoring dashboard setup (covered in Monitoring Metrics section)

### **Conclusion:**

**Status:** ✅ **Analysis Complete and Comprehensive**

The analysis covers all critical aspects needed for pre-implementation:
- Current system understanding ✅
- Integration points identified ✅
- Issues documented ✅
- Migration strategy defined ✅
- Validation checklist provided ✅

**Ready for UnifiedSerialService implementation.**

---

**Status:** ✅ Analysis complete. Ready for UnifiedSerialService integration.

