# 🧠 Serial Number System - Complete System Context

**Created:** November 9, 2025  
**Purpose:** Complete understanding of DAG, Job Ticket, Assignment, and Serial Number integration for AI Agents  
**Status:** ✅ **Verified Against Real Codebase**

---

## ⚠️ **CRITICAL: Read This Before Implementation**

This document provides **verified system context** based on actual codebase inspection. It supplements `SERIAL_NUMBER_INTEGRATION_ANALYSIS.md` with semantic understanding required for correct implementation.

---

## 📐 Semantic Mapping (Factory Reality)

### **Core Concepts:**

| Term | Real-World Meaning | Database Representation |
|------|-------------------|------------------------|
| **Node** | Work station/step (Cutting, Edge Paint, Stitching, QC, Pack) | `routing_node` (template) + `node_instance` (runtime) |
| **Edge/Route** | Path between work stations (may have conditions/splits/merges) | `routing_edge` |
| **DAG Instance** | One running job (linked to Job Ticket / MO) | `job_graph_instance` |
| **Token** | Physical work unit: HAT=per-piece, OEM=per-batch | `flow_token` |
| **Session** | Operator working on Token at Node (Start/Pause/Resume/Complete) | `token_work_session` (DAG) or `hatthasilpa_task_operator_session` (Linear) |
| **Operator / Team** | Artisan/group assigned to Node | `account.id_member` + `team_member` |
| **Job Ticket** | Work order: HAT (per-piece) or OEM (per-batch) | `hatthasilpa_job_ticket` |
| **MO** | Manufacturing Order (OEM-centric) | `mo` |

**Golden Rule:** Token = Real work unit / Node = Work station / Session = Working time

---

## 🏗️ DAG Architecture (Three-Layer Model)

### **Layer 1: Graph Template (Static Design)**

**Tables:** `routing_graph`, `routing_node`, `routing_edge`

**Purpose:** Template designed by planner (reusable across jobs)

```sql
-- Template: "TOTE Production V1"
routing_graph: id_graph=1, code='TOTE_V1', name='Tote Bag Production'
routing_node: id_node=10 (Cutting), id_node=20 (Stitching), id_node=30 (QC)
routing_edge: from_node_id=10 → to_node_id=20 (normal)
```

### **Layer 2: Graph Instance (Runtime Execution)**

**Tables:** `job_graph_instance`, `node_instance`

**Purpose:** One instance per job ticket (runtime state)

```sql
-- Instance for Job Ticket #42
job_graph_instance: id_instance=100, id_job_ticket=42, id_graph=1
node_instance: id_node_instance=1001 (Cutting instance), id_node_instance=1002 (Stitching instance)
```

**Key Point:** `node_instance` tracks runtime state (token_count_at_node, status), but **tokens reference `routing_node.id_node` directly**.

### **Layer 3: Token Flow (Work Unit Tracking)**

**Tables:** `flow_token`, `token_event`, `token_assignment`, `token_work_session`

**Purpose:** Individual work units flowing through graph

```sql
-- Token for piece #1 of Job Ticket #42
flow_token: id_token=5001, id_instance=100, current_node_id=10, serial_number='MA01-HAT-TOTE-...'
token_assignment: id_assignment=2001, id_token=5001, id_node=10, assigned_to_user_id=123
token_work_session: id_session=3001, id_token=5001, operator_user_id=123, status='active'
```

**⚠️ CRITICAL:** `flow_token.current_node_id` FK to `routing_node.id_node` (NOT `node_instance.id_node_instance`!)

**Verified in:** `dag_token_api.php` line 17-24 (CRITICAL INVARIANT comment)

---

## 🎭 Production Context (HAT vs OEM)

### **Hatthasilpa (HAT) - Atelier Craftsmanship**

**Serial Characteristics:**
- `serial_scope = 'piece'` (one serial per physical item)
- `linked_source = 'dag_token'` (must have `dag_token_id`)
- `production_type = 'hatthasilpa'`
- Salt: `SERIAL_SECRET_SALT_HAT`
- Visibility: **Public-facing** (customer can verify, but NO PII exposure)

**Traceability Sources:**
- `dag_token` → `token_work_session` → `operator_user_id` → `account` (artisan info)
- `people_profile` (if exists) → artisan skills, display name
- `token_event` → complete audit trail

**Assignment Model:**
- Manual assignment (Manager assigns to specific artisan)
- Team-based (assign to team, system picks best member)
- Auto (skill matching + load balancing)

**Session Tracking:**
- Uses `token_work_session` (DAG system)
- One active session per token
- Help modes: `own`, `assist`, `replace`

### **OEM (Industrial) - Batch Manufacturing**

**Serial Characteristics:**
- `serial_scope = 'batch'` (one serial per batch/lot)
- `linked_source = 'job_ticket'` or `'mo'` (must have `job_ticket_id` or `mo_id`)
- `production_type = 'oem'`
- Salt: `SERIAL_SECRET_SALT_OEM`
- Visibility: **Internal-only** (manager dashboard)

**Traceability Sources:**
- `job_ticket` → batch info
- `mo` → manufacturing order header
- `team` → operator team (not individual artisans)

**Assignment Model:**
- Rule-based auto-assignment (less manual intervention)
- Team-based (assign to team, system distributes)

**Session Tracking:**
- May use Linear system (`hatthasilpa_task_operator_session`) if not using DAG
- Or `token_work_session` if using DAG

---

## 🔗 Serial Integration Flow (Verified)

### **Flow 1: Hatthasilpa Job Ticket Creation**

**File:** `source/hatthasilpa_job_ticket.php` (lines 450-475)

**Current Implementation:**
```php
// ✅ Pre-generate serials at job creation
if ($processMode === 'piece' && $targetQty > 0 && $targetQty <= 1000) {
    $prefix = $sku ?: preg_replace('/[^A-Z0-9]/', '', strtoupper($jobName));
    $serialService = new \BGERP\Service\SerialManagementService($tenantDb);
    $generatedSerials = $serialService->generateSerialsForJob(
        $insertId,
        $targetQty,
        $processMode,
        $prefix
    );
    // Stores in job_ticket_serial table
}
```

**What Happens:**
1. ✅ Serials generated using `SecureSerialGenerator` (legacy format)
2. ✅ Stored in `job_ticket_serial` table with `sequence_no` (1, 2, 3...)
3. ✅ `spawned_at = NULL`, `spawned_token_id = NULL` (not yet spawned)

**Required Change:**
- Replace `SecureSerialGenerator` with `UnifiedSerialService::generateSerial()`
- Register in `serial_registry` (Core DB) with `linked_source='job_ticket'`, `dag_token_id=NULL`
- Use standardized format: `{TENANT}-HAT-{SKU}-{YYYYMMDD}-{SEQ}-{HASH-4}-{CHECKSUM}`

---

### **Flow 2: DAG Token Spawn**

**File:** `source/dag_token_api.php` (lines 333-358)

**Current Implementation:**
```php
// ⚠️ PROBLEM: Generates serials AGAIN (duplicate!)
$serials = [];
if ($ticket['process_mode'] === 'piece') {
    for ($i = 0; $i < $ticket['target_qty']; $i++) {
        $serial = SecureSerialGenerator::generate(...);  // ← Generate again!
        $serials[] = $serial;
    }
}

// Spawn tokens
$tokenService = new TokenLifecycleService($db->getTenantDb());
$tokenIds = $tokenService->spawnTokens($instanceId, $targetQty, $processMode, $serials);

// Auto-assign spawned tokens
AssignmentEngine::autoAssignOnSpawn($db->getTenantDb(), $tokenIds);
```

**What Happens:**
1. ❌ Generates serials again (even though `job_ticket_serial` already has them)
2. ✅ Passes serials to `TokenLifecycleService::spawnTokens()`
3. ✅ Stores serial in `flow_token.serial_number`
4. ✅ Auto-assigns tokens using `AssignmentEngine::autoAssignOnSpawn()`
5. ❌ **Missing:** No link back to `job_ticket_serial.spawned_token_id`
6. ❌ **Missing:** No update to `serial_registry.dag_token_id`

**Required Change:**
1. ✅ Reuse serials from `job_ticket_serial` (don't generate again)
2. ✅ Link back: `SerialManagementService::markAsSpawned($serial, $tokenId)`
3. ✅ Link registry: `UnifiedSerialService::linkDagToken($serial, $tokenId)`

---

### **Flow 3: OEM Manufacturing Order**

**File:** `source/mo.php` (lines 930-948)

**Current Implementation:**
```php
// ⚠️ PROBLEM: Legacy format
for ($i = 1; $i <= $tokensToSpawn; $i++) {
    $serialNumber = $mo['mo_code'] . '-' . str_pad($i, 4, '0', STR_PAD_LEFT);
    // Example: "MO-2025-0001"
    
    $stmt = $dbConn->prepare("
        INSERT INTO flow_token
        (id_graph_instance, id_mo, current_node_id, token_code, ...)
        VALUES (?, ?, ?, ?, ...)
    ");
    // Direct insert, no serial_registry
}
```

**What Happens:**
1. ❌ Uses legacy format: `{mo_code}-{sequence}`
2. ❌ No registration in `serial_registry`
3. ❌ No standardized format validation

**Required Change:**
- Use `UnifiedSerialService::generateSerial()` with `production_type='oem'`
- Register in `serial_registry` with `serial_scope='batch'`, `linked_source='mo'` or `'job_ticket'`

---

## 🎯 Assignment Logic (Verified from Code)

### **AssignmentEngine Precedence: PIN > PLAN > AUTO**

**File:** `source/BGERP/Service/AssignmentEngine.php`

**Verified Logic:**

```php
// 1. PIN (Highest Priority)
$pin = db_fetch_one($db, "
    SELECT assigned_to_user_id, pinned_by, pin_reason
    FROM token_assignment
    WHERE id_token=? AND pinned_at IS NOT NULL
    ORDER BY pinned_at DESC LIMIT 1
", [$tokenId]);

if ($pin) {
    // Use pinned assignment
    return;
}

// 2. PLAN (Job > Node)
// 2a. Job Plan (highest specificity)
$planJob = db_fetch_all($db, "
    SELECT assignee_type, assignee_id, priority
    FROM assignment_plan_job
    WHERE id_job_ticket=? AND id_node=? AND active=1
    ORDER BY priority ASC
", [$jobTicketId, $nodeId]);

// 2b. Node Plan (fallback)
if (!$planJob) {
    $planNode = db_fetch_all($db, "
        SELECT assignee_type, assignee_id, priority
        FROM assignment_plan_node
        WHERE id_graph=? AND id_node=? AND active=1
        ORDER BY priority ASC
    ", [$graphId, $nodeId]);
}

// Expand team/member assignees
$candidates = self::expandAssignees($db, $planJob ?? $planNode);

// 3. AUTO (Skill Matching + Load Balancing)
if (!$candidates) {
    $candidates = self::findBySkillMatch($db, $nodeId);
}

// Filter by availability
$candidates = self::filterAvailable($db, $candidates);

// Pick best candidate (lowest load)
$chosen = self::pickByLowestLoad($db, $candidates);
```

**Assignment Modes:**

1. **Pinned Assignment (Manual Override):**
   - Manager pins specific operator to token/node
   - Stored in `token_assignment.pinned_at`, `pinned_by`
   - **Always wins** (highest priority)

2. **Plan Assignment (Pre-configured):**
   - **Job Plan:** `assignment_plan_job` (specific to job + node)
   - **Node Plan:** `assignment_plan_node` (applies to all jobs using this node)
   - Can assign to `member` or `team`
   - Team expansion: `expandAssignees()` → expands team to member IDs

3. **Auto Assignment (Rule-based):**
   - Skill matching: `findBySkillMatch()` → matches `node_required_skill` with `operator_skill`
   - Availability filtering: `filterAvailable()` → checks `operator_availability`
   - Load balancing: `pickByLowestLoad()` → picks operator with lowest active sessions

**Assignment Invariants:**

- ✅ One open assignment per token (`token_assignment.status IN ('assigned','accepted','started','paused')`)
- ✅ PIN always wins (even if plan exists)
- ✅ Plan failure → Log and stop (don't fallback to auto)
- ✅ Team expansion → All active team members become candidates

---

## 🔧 Required Service Methods (Verified)

### **SerialManagementService Methods:**

**Existing:**
- ✅ `generateSerialsForJob($jobTicketId, $targetQty, $processMode, $prefix)` - Generates serials
- ✅ `getJobSerials($jobTicketId)` - Gets all serials (includes spawned ones)
- ✅ `markAsSpawned($serial, $tokenId)` - Links serial to token

**Missing (Must Add):**
- ❌ `getUnspawnedSerials($jobTicketId)` - Gets only unspawned serials (ORDER BY sequence_no)

**Implementation:**
```php
public function getUnspawnedSerials(int $jobTicketId): array
{
    $stmt = $this->db->prepare("
        SELECT serial_number, sequence_no
        FROM job_ticket_serial 
        WHERE id_job_ticket = ? AND spawned_at IS NULL
        ORDER BY sequence_no ASC
    ");
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

### **UnifiedSerialService Methods:**

**Must Implement:**
- ✅ `generateSerial(...)` - Generate standardized serial
- ✅ `verifySerial($serial)` - Verify serial format and registry
- ❌ `linkDagToken($serial, $dagTokenId)` - Link serial to DAG token (HAT only)

**Implementation:**
```php
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
        throw new RuntimeException('ERR_UPDATE_FAILED: Failed to link serial');
    }
    
    return true;
}
```

---

## 🗄️ Database Schema (Verified)

### **Core DB Tables:**

**serial_registry:**
```sql
CREATE TABLE serial_registry (
    id_serial BIGINT PRIMARY KEY AUTO_INCREMENT,
    serial_code VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin UNIQUE NOT NULL,
    tenant_id INT NOT NULL,
    org_code VARCHAR(50) NOT NULL,
    production_type ENUM('hatthasilpa', 'oem') NOT NULL,
    sku VARCHAR(50) NULL,
    mo_id BIGINT NULL,
    job_ticket_id BIGINT NULL,
    dag_token_id BIGINT NULL,  -- ← For HAT only
    created_at DATETIME NOT NULL DEFAULT (UTC_TIMESTAMP()),
    serial_scope ENUM('piece','batch') DEFAULT 'piece',
    linked_source ENUM('dag_token','job_ticket') NULL,  -- ← NO DEFAULT!
    -- ... other fields
);
```

**serial_seq_daily:**
```sql
CREATE TABLE serial_seq_daily (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    tenant_id INT NOT NULL,
    prod_type ENUM('hatthasilpa', 'oem') NOT NULL,
    sku VARCHAR(50) NOT NULL,
    ymd CHAR(8) NOT NULL COMMENT 'YYYYMMDD (UTC)',
    seq INT NOT NULL,
    UNIQUE KEY uniq_scope (tenant_id, prod_type, sku, ymd, seq)
);
```

### **Tenant DB Tables:**

**job_ticket_serial:**
```sql
CREATE TABLE job_ticket_serial (
    id_serial INT PRIMARY KEY AUTO_INCREMENT,
    id_job_ticket INT NOT NULL,
    serial_number VARCHAR(100) NOT NULL,
    sequence_no INT NOT NULL,
    generated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    spawned_at DATETIME NULL,  -- ← Set when token spawned
    spawned_token_id INT NULL,  -- ← Link to flow_token.id_token
    UNIQUE KEY idx_serial (serial_number),
    UNIQUE KEY uniq_ticket_seq (id_job_ticket, sequence_no),  -- ← Must add!
    KEY idx_ticket_unspawned (id_job_ticket, spawned_at)  -- ← Must add!
);
```

**flow_token:**
```sql
CREATE TABLE flow_token (
    id_token INT PRIMARY KEY AUTO_INCREMENT,
    id_instance INT NOT NULL,
    token_type ENUM('batch', 'piece', 'component') NOT NULL DEFAULT 'piece',
    serial_number VARCHAR(100) NULL,  -- ← Serial stored here
    current_node_id INT NULL,  -- ← FK to routing_node.id_node (NOT node_instance!)
    status ENUM('active', 'completed', 'scrapped') NOT NULL DEFAULT 'active',
    qty DECIMAL(10,2) DEFAULT 1.00,
    spawned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    -- ...
);
```

**token_assignment:**
```sql
CREATE TABLE token_assignment (
    id_assignment INT PRIMARY KEY AUTO_INCREMENT,
    id_token INT NOT NULL,
    id_node INT NOT NULL,  -- ← FK to routing_node.id_node
    assigned_to_user_id INT NOT NULL,
    status ENUM('assigned','accepted','started','paused','completed','cancelled','rejected'),
    pinned_by INT NULL,
    pinned_at DATETIME NULL,
    pin_reason VARCHAR(255) NULL,
    id_work_session INT NULL,  -- ← FK to token_work_session
    -- ...
    UNIQUE KEY uk_token_node (id_token, id_node)
);
```

**token_work_session:**
```sql
CREATE TABLE token_work_session (
    id_session INT PRIMARY KEY AUTO_INCREMENT,
    id_token INT NOT NULL,
    operator_user_id INT NOT NULL,
    operator_name VARCHAR(150),
    status ENUM('active','paused','completed','cancelled'),
    help_type ENUM('own','assist','replace'),
    replacement_reason VARCHAR(255),
    started_at DATETIME,
    -- ...
);
```

---

## ⚠️ Critical Invariants (Must Enforce)

### **1. Serial Context Invariants:**

**Hatthasilpa:**
- ✅ `dag_token_id` **MUST NOT** be NULL (after spawn)
- ✅ `mo_id` **MUST** be NULL
- ✅ `serial_scope` **MUST** be 'piece'
- ✅ `linked_source` **MUST** be 'dag_token'

**OEM:**
- ✅ `mo_id` OR `job_ticket_id` **MUST NOT** be NULL (at least one)
- ✅ `dag_token_id` **MUST** be NULL
- ✅ `serial_scope` **MUST** be 'batch'
- ✅ `linked_source` **MUST** be 'job_ticket' or 'mo'

**Violation:** Throw `ERR_CONTEXT_MISMATCH` exception

---

### **2. Node Reference Invariant:**

**⚠️ CRITICAL:** `flow_token.current_node_id` FK to `routing_node.id_node` (NOT `node_instance.id_node_instance`!)

**Verified in:** `dag_token_api.php` lines 17-24

**When Querying:**
```php
// ✅ CORRECT:
$token = db_fetch_one($db, "
    SELECT t.*, n.node_name, n.node_type
    FROM flow_token t
    JOIN routing_node n ON n.id_node = t.current_node_id
    WHERE t.id_token = ?
", [$tokenId]);

// ❌ WRONG:
$token = db_fetch_one($db, "
    SELECT t.*, ni.status
    FROM flow_token t
    JOIN node_instance ni ON ni.id_node_instance = t.current_node_id  -- ← WRONG!
    WHERE t.id_token = ?
", [$tokenId]);
```

**Exception:** Use `node_instance` ONLY when querying instance-level aggregates (token count, instance status)

---

### **3. Assignment Invariants:**

- ✅ One open assignment per token (`status IN ('assigned','accepted','started','paused')`)
- ✅ PIN always wins (even if plan exists)
- ✅ Plan failure → Log and stop (don't fallback to auto)
- ✅ Team expansion → All active team members become candidates
- ✅ Availability check → Filter out unavailable operators
- ✅ Load balancing → Pick operator with lowest active sessions

---

### **4. Session Invariants:**

- ✅ One active session per token (`token_work_session.status='active'`)
- ✅ Help modes: `own` (normal), `assist` (help, no reassign), `replace` (takeover)
- ✅ Auto-pause operator's current session when starting new work

---

## 🔗 Integration Points (Code Changes Required)

### **Point 1: hatthasilpa_job_ticket.php (Job Creation)**

**Current:** Uses `SerialManagementService::generateSerialsForJob()` with `SecureSerialGenerator`

**Required:**
1. Replace with `UnifiedSerialService::generateSerial()` (standardized format)
2. Register in `serial_registry` (Core DB) with:
   - `production_type='hatthasilpa'`
   - `job_ticket_id` set
   - `dag_token_id=NULL` (not spawned yet)
   - `serial_scope='piece'`
   - `linked_source='job_ticket'`
3. Store in `job_ticket_serial` (Tenant DB) for tracking

---

### **Point 2: dag_token_api.php (Token Spawn)**

**Current:** Generates serials again (duplicate)

**Required:**
1. **Reuse** serials from `job_ticket_serial` (don't generate again)
2. Use `SerialManagementService::getUnspawnedSerials($ticketId)` (must add method)
3. If not enough serials, generate additional ones using `UnifiedSerialService`
4. After spawn, link back:
   - `SerialManagementService::markAsSpawned($serial, $tokenId)` → Tenant DB
   - `UnifiedSerialService::linkDagToken($serial, $tokenId)` → Core DB

---

### **Point 3: mo.php (OEM Serial Generation)**

**Current:** Uses legacy format `{mo_code}-{sequence}`

**Required:**
1. Replace with `UnifiedSerialService::generateSerial()` with `production_type='oem'`
2. Register in `serial_registry` with:
   - `serial_scope='batch'`
   - `linked_source='mo'` or `'job_ticket'`
   - `mo_id` set
   - `dag_token_id=NULL`

---

## 🧪 Test Scenarios (Must Pass)

### **Test 1: No-Duplicate on Spawn**
- Pre-generate 10 serials → Spawn 10 tokens → Verify no new generation
- Verify all `job_ticket_serial.spawned_at` set
- Verify all `serial_registry.dag_token_id` linked

### **Test 2: Partial Spawn**
- Pre-generate 10 → Spawn 6 → Verify 6 linked, 4 remain unspawned
- Next spawn uses remaining 4 serials

### **Test 3: OEM Standardization**
- MO creates 3 batch tokens → Verify standardized format
- Verify all in `serial_registry` with `production_type='oem'`

### **Test 4: Context Invariant Enforcement**
- Try HAT with `mo_id` → `ERR_CONTEXT_MISMATCH`
- Try OEM with `dag_token_id` → `ERR_CONTEXT_MISMATCH`
- Try link serial twice → `ERR_ALREADY_LINKED`

### **Test 5: Assignment Precedence**
- PIN exists → Use PIN (ignore plan/auto)
- Plan exists → Use plan (expand team if needed)
- No PIN/Plan → Use auto (skill + availability + load)

### **Test 6: Cross-Salt Verification**
- HAT serial verified with OEM salt → Must fail
- OEM serial verified with HAT salt → Must fail

---

## 📊 Error Codes (Standardized)

| Code | HTTP | When | Example |
|------|------|------|---------|
| `ERR_CONTEXT_MISMATCH` | 400 | HAT with `mo_id` or OEM with `dag_token_id` | `Hatthasilpa cannot have mo_id` |
| `ERR_ALREADY_LINKED` | 409 | Serial already linked to token | `Serial already linked to token 5001` |
| `ERR_SERIAL_NOT_FOUND` | 404 | Serial not in registry | `Serial not found in registry` |
| `ERR_ASSIGNMENT_PIN_CONFLICT` | 409 | Pinned assignment conflict | `Token already pinned to different operator` |
| `ERR_TEAM_EMPTY` | 400 | Team has no active members | `Team 'Cutting Team' has no available members` |
| `ERR_AVAILABILITY_OFF` | 400 | Operator unavailable/on leave | `Operator is on leave until 2025-11-15` |
| `ERR_NO_SERIAL_AVAILABLE` | 500 | No unspawned serials and generation failed | `Failed to generate additional serials` |

---

## 🔍 Key Database Relationships

### **Serial Flow:**
```
hatthasilpa_job_ticket (id_job_ticket)
    ↓
job_ticket_serial (id_job_ticket, serial_number, sequence_no)
    ↓ (after spawn)
flow_token (id_token, serial_number)
    ↓ (link back)
job_ticket_serial.spawned_token_id = flow_token.id_token
serial_registry.dag_token_id = flow_token.id_token
```

### **Assignment Flow:**
```
flow_token (id_token, current_node_id)
    ↓
token_assignment (id_token, id_node, assigned_to_user_id)
    ↓ (when started)
token_work_session (id_token, operator_user_id, status='active')
```

### **Node Reference:**
```
routing_graph (id_graph) ← Template
    ↓
routing_node (id_node) ← Template node
    ↓
flow_token.current_node_id → routing_node.id_node ← Token references template!
    ↓
node_instance (id_node_instance, id_node) ← Runtime state (separate!)
```

---

## ✅ Implementation Checklist

### **Pre-Implementation:**

- [ ] Understand semantic mapping (Node/DAG/Token/Session)
- [ ] Understand production context (HAT vs OEM)
- [ ] Understand assignment logic (PIN > PLAN > AUTO)
- [ ] Understand node reference rule (`routing_node` not `node_instance`)

### **Code Changes:**

- [ ] Add `SerialManagementService::getUnspawnedSerials()`
- [ ] Add `UnifiedSerialService::linkDagToken()`
- [ ] Update `hatthasilpa_job_ticket.php` (use UnifiedSerialService)
- [ ] Update `dag_token_api.php` (reuse serials, link back)
- [ ] Update `mo.php` (standardize OEM format)
- [ ] Add invariant validation to `UnifiedSerialService::generateSerial()`

### **Database Changes:**

- [ ] Apply SQL hardening patches (3 patches)
- [ ] Verify `serial_registry` table exists (Core DB)
- [ ] Verify `serial_seq_daily` table exists (Core DB)
- [ ] Verify `job_ticket_serial` indexes exist

### **Testing:**

- [ ] Run all 6 test scenarios
- [ ] Verify assignment precedence works
- [ ] Verify context invariants enforced
- [ ] Verify cross-salt verification fails

---

## 🔁 Dual-Write Resilience (Tenant ↔ Core)

**Problem:** When linking `serial_registry.dag_token_id` (Core DB), if Core DB is unavailable, spawn operation should not fail.

**Solution:** Outbox Pattern with eventual consistency.

### **Outbox Schema (Tenant DB):**

```sql
CREATE TABLE serial_link_outbox (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    serial_code VARCHAR(64) NOT NULL,
    dag_token_id BIGINT NOT NULL,
    status ENUM('pending','done','dead') DEFAULT 'pending',
    retry_count INT DEFAULT 0,
    last_error TEXT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_status (status, created_at),
    INDEX idx_retry (status, retry_count)
) ENGINE=InnoDB;
```

### **Implementation Flow:**

1. **On Spawn (dag_token_api.php):**
   ```php
   try {
       // Link in Core DB
       $unifiedSerialService->linkDagToken($serial, $tokenId);
   } catch (\Throwable $e) {
       // Core DB unavailable → Write to outbox
       $stmt = $tenantDb->prepare("
           INSERT INTO serial_link_outbox 
           (serial_code, dag_token_id, status, last_error)
           VALUES (?, ?, 'pending', ?)
       ");
       $stmt->bind_param('sis', $serial, $tokenId, $e->getMessage());
       $stmt->execute();
       $stmt->close();
       
       // Log but don't fail spawn
       error_log("Core DB link failed, queued to outbox: $serial");
   }
   ```

2. **Background Worker (Retry Logic):**
   ```php
   // Exponential backoff: 1m, 5m, 15m, 1h, 6h (max 10 retries)
   $pending = db_fetch_all($tenantDb, "
       SELECT * FROM serial_link_outbox 
       WHERE status='pending' AND retry_count < 10
       ORDER BY created_at ASC
       LIMIT 100
   ");
   
   foreach ($pending as $entry) {
       try {
           $unifiedSerialService->linkDagToken($entry['serial_code'], $entry['dag_token_id']);
           
           // Success → Mark done
           $tenantDb->query("
               UPDATE serial_link_outbox 
               SET status='done', updated_at=NOW()
               WHERE id={$entry['id']}
           ");
       } catch (\Throwable $e) {
           // Increment retry count
           $retryCount = $entry['retry_count'] + 1;
           $status = $retryCount >= 10 ? 'dead' : 'pending';
           
           $tenantDb->query("
               UPDATE serial_link_outbox 
               SET retry_count=$retryCount, 
                   status='$status',
                   last_error='" . $tenantDb->real_escape_string($e->getMessage()) . "',
                   updated_at=NOW()
               WHERE id={$entry['id']}
           ");
           
           if ($status === 'dead') {
               // Alert: Manual intervention required
               error_log("ALERT: Outbox entry $entry[id] marked dead after 10 retries");
           }
       }
   }
   ```

**Invariant:** Spawn succeeds even if Core link fails; outbox guarantees eventual consistency.

---

## 🧾 Idempotency (Spawn & Link)

**Problem:** Double-click, network retry, or duplicate requests can cause duplicate token spawns.

**Solution:** Idempotency keys stored in spawn log.

### **Spawn Log Schema (Tenant DB):**

```sql
CREATE TABLE token_spawn_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    idempotency_key CHAR(36) UNIQUE NOT NULL COMMENT 'UUID v4',
    payload_hash VARCHAR(64) NOT NULL COMMENT 'SHA256 of request payload',
    id_instance INT NOT NULL,
    token_ids JSON NOT NULL COMMENT 'Array of spawned token IDs',
    result_json JSON NOT NULL COMMENT 'Full response payload',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_idempotency (idempotency_key),
    INDEX idx_instance (id_instance)
) ENGINE=InnoDB;
```

### **Implementation:**

```php
// dag_token_api.php (handleTokenSpawn)
$idempotencyKey = $_SERVER['HTTP_X_IDEMPOTENCY_KEY'] ?? null;

if ($idempotencyKey) {
    // Check for duplicate
    $existing = db_fetch_one($tenantDb, "
        SELECT result_json 
        FROM token_spawn_log 
        WHERE idempotency_key = ?
    ", [$idempotencyKey]);
    
    if ($existing) {
        // Return previous result (HTTP 200, not 201)
        json_success(json_decode($existing['result_json'], true), 200);
        return;
    }
}

// ... spawn tokens ...

// Store result
if ($idempotencyKey) {
    $payloadHash = hash('sha256', json_encode($_POST));
    $resultJson = json_encode([
        'id_instance' => $instanceId,
        'token_count' => count($tokenIds),
        'token_ids' => $tokenIds
    ]);
    
    $stmt = $tenantDb->prepare("
        INSERT INTO token_spawn_log 
        (idempotency_key, payload_hash, id_instance, token_ids, result_json)
        VALUES (?, ?, ?, ?, ?)
    ");
    $tokenIdsJson = json_encode($tokenIds);
    $stmt->bind_param('ssiss', $idempotencyKey, $payloadHash, $instanceId, $tokenIdsJson, $resultJson);
    $stmt->execute();
    $stmt->close();
}
```

**Invariant:** Same `idempotency_key` always returns same result (even if request payload differs slightly).

---

## 🧪 Feature Flags & Rollout Plan

**Purpose:** Gradual rollout with tenant-level control.

### **Feature Flags:**

| Flag | Default | Purpose |
|------|---------|---------|
| `FF_SERIAL_STD_HAT` | `off` (per tenant) | Enable standardized serial for Hatthasilpa |
| `FF_SERIAL_STD_OEM` | `off` (per tenant) | Enable standardized serial for OEM |
| `FF_VERIFY_PUBLIC_MODE` | `minimal` | Public verify privacy level: `minimal|standard|internal` |

### **Storage:**

```sql
-- Tenant DB: feature_flags table (or tenant_config)
CREATE TABLE tenant_feature_flags (
    id INT PRIMARY KEY AUTO_INCREMENT,
    tenant_id INT NOT NULL,
    flag_key VARCHAR(50) NOT NULL,
    flag_value VARCHAR(50) NOT NULL,
    enabled_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_tenant_flag (tenant_id, flag_key)
) ENGINE=InnoDB;
```

### **Usage:**

```php
// Check flag before using UnifiedSerialService
function isSerialStandardizationEnabled(string $productionType, int $tenantId): bool
{
    $flagKey = $productionType === 'hatthasilpa' 
        ? 'FF_SERIAL_STD_HAT' 
        : 'FF_SERIAL_STD_OEM';
    
    $flag = db_fetch_one($tenantDb, "
        SELECT flag_value 
        FROM tenant_feature_flags 
        WHERE tenant_id = ? AND flag_key = ?
    ", [$tenantId, $flagKey]);
    
    return ($flag && $flag['flag_value'] === 'on');
}

// In hatthasilpa_job_ticket.php
if (isSerialStandardizationEnabled('hatthasilpa', $tenantId)) {
    // Use UnifiedSerialService
} else {
    // Use legacy SecureSerialGenerator
}
```

### **Rollout Plan:**

1. **Week 1:** Enable `FF_SERIAL_STD_HAT` for test tenant only
2. **Week 2:** Enable for 1 production tenant (monitor metrics)
3. **Week 3:** Enable for all Hatthasilpa tenants
4. **Week 4:** Enable `FF_SERIAL_STD_OEM` for test tenant
5. **Week 5:** Enable for all OEM tenants

---

## 📈 SLO & Monitoring Metrics

### **Service Level Objectives (SLO):**

| Metric | Target | Measurement |
|--------|--------|-------------|
| `serial_generation_p99` | < 200ms | 99th percentile latency |
| `registry_link_error_rate` | < 0.1% | Failed Core DB links / Total links |
| `assignment_resolution_p95` | < 150ms | 95th percentile assignment time |

### **Metrics to Emit:**

**Serial Metrics:**
- `serial.pre_generated_total` - Total serials pre-generated per day
- `serial.spawn_used_total` - Total serials used during spawn
- `serial.spawn_missing_total` - Serials generated during spawn (should be 0)
- `serial.link_failed_total` - Failed Core DB links (outbox entries)
- `serial.link_success_total` - Successful Core DB links
- `serial.oem_generated_total` - Total OEM serials generated
- `serial.hat_generated_total` - Total Hatthasilpa serials generated

**Assignment Metrics:**
- `assignment.pin_hits` - PIN assignments used
- `assignment.plan_hits` - Plan assignments used (job + node)
- `assignment.auto_hits` - Auto assignments used
- `assignment.unassignable_total` - Tokens with no available operator
- `assignment.resolution_latency_ms` - Assignment resolution time

**Error Metrics:**
- `serial.context_mismatch_total` - Context validation failures
- `serial.duplicate_total` - Duplicate serial attempts
- `serial.invalid_format_total` - Invalid format rejections

### **Monitoring Dashboard Queries:**

```sql
-- Serial generation rate (last 24h)
SELECT 
    DATE(created_at) as date,
    production_type,
    COUNT(*) as total_serials,
    COUNT(CASE WHEN dag_token_id IS NOT NULL THEN 1 END) as linked_tokens
FROM serial_registry
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
GROUP BY DATE(created_at), production_type;

-- Outbox health (pending entries)
SELECT 
    status,
    COUNT(*) as count,
    MAX(retry_count) as max_retries,
    MAX(created_at) as oldest_pending
FROM serial_link_outbox
GROUP BY status;

-- Assignment source distribution
SELECT 
    DATE(assigned_at) as date,
    CASE 
        WHEN pinned_at IS NOT NULL THEN 'pin'
        WHEN EXISTS (SELECT 1 FROM assignment_plan_job WHERE id_job_ticket=ta.id_job_ticket) THEN 'plan_job'
        WHEN EXISTS (SELECT 1 FROM assignment_plan_node WHERE id_node=ta.id_node) THEN 'plan_node'
        ELSE 'auto'
    END as source,
    COUNT(*) as count
FROM token_assignment ta
WHERE assigned_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY DATE(assigned_at), source;
```

---

## 🔐 Security & Salt Management

### **Salt Storage Policy:**

- ✅ **Stored in:** Environment variables (`.env`) or `tenant_config` table
- ❌ **Never:** Hardcoded in source code
- ✅ **Access:** Read-only at runtime (no write access)

### **Environment Variables:**

```bash
# Production (set in .env or server config)
SERIAL_SECRET_SALT_HAT=hatthasilpa_secret_salt_2025_v1
SERIAL_SECRET_SALT_OEM=oem_secret_salt_2025_v1
```

### **Salt Rotation Playbook:**

**Step 1: Set New Salt (Environment)**
```bash
# Set new salt environment variable
export SERIAL_SECRET_SALT_HAT_V2='hatthasilpa_secret_salt_2026_v2'
```

**Step 2: Update Service (Code)**
```php
// UnifiedSerialService::generateSerial()
$saltVersion = 2; // Increment for new serials
$salt = getenv("SERIAL_SECRET_SALT_HAT_V{$saltVersion}") ?: getenv("SERIAL_SECRET_SALT_HAT");

// Store version in registry
$hashSignature = hash_hmac('sha256', $serial, $salt);
// ... insert with hash_salt_version = 2
```

**Step 3: Verify Backward Compatibility**
```php
// UnifiedSerialService::verifySerial()
$row = $this->registryGet($serialCode);
$saltVersion = $row['hash_salt_version'] ?? 1;

// Choose salt based on version
$salt = $saltVersion >= 2 
    ? getenv("SERIAL_SECRET_SALT_HAT_V{$saltVersion}") ?: getenv("SERIAL_SECRET_SALT_HAT")
    : getenv("SERIAL_SECRET_SALT_HAT");

$expectedHash = hash_hmac('sha256', $serialCode, $salt);
if (!hash_equals($row['hash_signature'], $expectedHash)) {
    throw new RuntimeException('ERR_INVALID_HASH');
}
```

**Verification:**
- ✅ Old serials (version 1) verify with `SERIAL_SECRET_SALT_HAT`
- ✅ New serials (version 2) verify with `SERIAL_SECRET_SALT_HAT_V2`
- ✅ Both remain valid (no breaking changes)

---

## 🔒 Public Verify - Privacy Mode

**Problem:** Public verify API must not expose PII (Personally Identifiable Information) of artisans.

**Solution:** Privacy mode switch with data filtering.

### **Privacy Modes:**

| Mode | Description | Data Returned |
|------|-------------|---------------|
| `minimal` | Public-facing (default) | Display name, role/skill, node name, timestamps (generalized) |
| `standard` | Internal use | + Work session duration, node sequence |
| `internal` | Full access | All data (including operator_user_id, full timestamps) |

### **Implementation:**

```php
// UnifiedSerialService::verifySerial()
public function verifySerial(string $serialCode, string $privacyMode = 'minimal'): array
{
    $row = $this->registryGet($serialCode);
    
    // ... validation ...
    
    // Build traceability data
    $traceability = $this->buildTraceability($row, $privacyMode);
    
    return [
        'valid' => true,
        'verified' => true,
        'data' => [
            'serial' => $serialCode,
            'production_type' => $row['production_type'],
            'traceability' => $traceability
        ]
    ];
}

private function buildTraceability(array $row, string $privacyMode): array
{
    if ($row['production_type'] !== 'hatthasilpa' || !$row['dag_token_id']) {
        return []; // OEM or not linked
    }
    
    // Fetch artisan chain from token_work_session
    $sessions = db_fetch_all($this->tenantDb, "
        SELECT 
            n.node_name,
            s.operator_name,
            s.started_at,
            s.completed_at,
            TIMESTAMPDIFF(MINUTE, s.started_at, s.completed_at) as work_minutes
        FROM token_work_session s
        JOIN flow_token t ON t.id_token = s.id_token
        JOIN routing_node n ON n.id_node = t.current_node_id
        WHERE s.id_token = ? AND s.status = 'completed'
        ORDER BY s.completed_at ASC
    ", [$row['dag_token_id']]);
    
    $artisanChain = [];
    foreach ($sessions as $session) {
        $entry = [
            'node' => $session['node_name'],
            'artisan' => $this->anonymizeName($session['operator_name'], $privacyMode),
            'completed_at' => $this->generalizeTimestamp($session['completed_at'], $privacyMode)
        ];
        
        if ($privacyMode !== 'minimal') {
            $entry['work_minutes'] = $session['work_minutes'];
        }
        
        $artisanChain[] = $entry;
    }
    
    return ['artisan_chain' => $artisanChain];
}

private function anonymizeName(string $fullName, string $privacyMode): string
{
    if ($privacyMode === 'minimal') {
        // Return display name only (e.g., "Somchai R." instead of full legal name)
        $parts = explode(' ', $fullName);
        return $parts[0] . ' ' . (isset($parts[1]) ? substr($parts[1], 0, 1) . '.' : '');
    }
    
    return $fullName; // standard/internal modes
}

private function generalizeTimestamp(string $timestamp, string $privacyMode): string
{
    if ($privacyMode === 'minimal') {
        // Return date only (no time)
        return date('Y-m-d', strtotime($timestamp));
    }
    
    return $timestamp; // standard/internal modes
}
```

**Privacy Policy:**
- ✅ **Allowed:** Display name (e.g., "Somchai R."), role/skill, node name, generalized timestamps
- ❌ **Prohibited:** Full legal names, personal IDs, employee numbers, contact information, exact timestamps (in minimal mode)

---

## 🏭 OEM Batch Scope Guard

**Problem:** Even when OEM uses DAG per unit, serial must remain batch-level.

**Solution:** Enforce `serial_scope='batch'` invariant for OEM.

### **Rule:**

**OEM Production Type:**
- ✅ `serial_scope` **MUST** be `'batch'` (never `'piece'`)
- ✅ All sub-tokens reference the **same batch serial**
- ❌ **Never** mint per-piece serial for OEM (unless dedicated design change approved)

### **Implementation:**

```php
// UnifiedSerialService::generateSerial()
if ($productionType === 'oem') {
    // Force batch scope
    if ($serialScope !== 'batch') {
        throw new RuntimeException('ERR_CONTEXT_MISMATCH: OEM must use batch scope');
    }
    
    // Generate ONE batch serial for entire MO/job
    $batchSerial = $this->generateSerial(
        tenantId: $tenantId,
        productionType: 'oem',
        sku: $sku,
        moId: $moId,
        jobTicketId: $jobTicketId,
        dagTokenId: null,
        originSource: 'auto_mo'
    );
    
    // All tokens in batch reference same serial
    return $batchSerial;
}

// mo.php (OEM token spawn)
$batchSerial = $unifiedSerialService->generateSerial(... 'oem' ...);

for ($i = 1; $i <= $tokensToSpawn; $i++) {
    // All tokens get same batch serial
    $stmt = $dbConn->prepare("
        INSERT INTO flow_token
        (id_instance, id_mo, current_node_id, serial_number, ...)
        VALUES (?, ?, ?, ?, ...)
    ");
    $stmt->bind_param('iisi', $graphInstanceId, $mo['id_mo'], $startNode['id_node'], $batchSerial, ...);
    $stmt->execute();
}
```

**Invariant:** One batch serial → Multiple tokens (all reference same serial).

---

## 🛡️ Hourly Consistency Checker

**Purpose:** Background job to detect and fix data inconsistencies.

### **Checks (Run Hourly):**

**Check 1: Missing Link (job_ticket_serial → flow_token)**

```sql
-- Find serials that should be linked but aren't
SELECT 
    jts.id_serial,
    jts.serial_number,
    jts.id_job_ticket,
    ft.id_token
FROM job_ticket_serial jts
JOIN flow_token ft ON ft.serial_number = jts.serial_number
WHERE jts.spawned_token_id IS NULL
  AND ft.status = 'active'
LIMIT 100;

-- Fix: Update job_ticket_serial
UPDATE job_ticket_serial jts
JOIN flow_token ft ON ft.serial_number = jts.serial_number
SET jts.spawned_token_id = ft.id_token,
    jts.spawned_at = ft.spawned_at
WHERE jts.spawned_token_id IS NULL
  AND ft.status = 'active';
```

**Check 2: Missing Registry Link (serial_registry → flow_token)**

```sql
-- Find serials in tokens but not linked in registry
SELECT 
    ft.serial_number,
    ft.id_token,
    sr.id_serial
FROM flow_token ft
LEFT JOIN serial_registry sr ON sr.serial_code = ft.serial_number
WHERE ft.serial_number IS NOT NULL
  AND ft.status = 'active'
  AND (sr.dag_token_id IS NULL OR sr.dag_token_id != ft.id_token)
LIMIT 100;

-- Fix: Enqueue to outbox (let worker retry)
INSERT INTO serial_link_outbox (serial_code, dag_token_id, status)
SELECT ft.serial_number, ft.id_token, 'pending'
FROM flow_token ft
LEFT JOIN serial_registry sr ON sr.serial_code = ft.serial_number
WHERE ft.serial_number IS NOT NULL
  AND ft.status = 'active'
  AND sr.production_type = 'hatthasilpa'
  AND (sr.dag_token_id IS NULL OR sr.dag_token_id != ft.id_token)
ON DUPLICATE KEY UPDATE updated_at = NOW();
```

**Check 3: Invalid Format (Quarantine)**

```sql
-- Find serials failing regex/checksum/hash
CREATE TABLE IF NOT EXISTS serial_quarantine (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    serial_code VARCHAR(64) NOT NULL,
    source_table VARCHAR(50) NOT NULL,
    source_id BIGINT NULL,
    reason ENUM('invalid_format','checksum_fail','hash_fail','duplicate') NOT NULL,
    detected_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    resolved_at DATETIME NULL,
    INDEX idx_status (resolved_at, reason)
) ENGINE=InnoDB;

-- Detect invalid serials
INSERT INTO serial_quarantine (serial_code, source_table, source_id, reason)
SELECT 
    ft.serial_number,
    'flow_token',
    ft.id_token,
    CASE 
        WHEN ft.serial_number NOT REGEXP '^[A-Z0-9]{2,8}-[A-Z]{2,4}-[A-Z0-9]{2,8}-[0-9]{8}-[0-9]{5}-[A-Z0-9]{4}-[A-Z0-9]$' 
        THEN 'invalid_format'
        ELSE 'checksum_fail'
    END
FROM flow_token ft
WHERE ft.serial_number IS NOT NULL
  AND ft.serial_number NOT IN (SELECT serial_code FROM serial_quarantine)
  AND (
      ft.serial_number NOT REGEXP '^[A-Z0-9]{2,8}-[A-Z]{2,4}-[A-Z0-9]{2,8}-[0-9]{8}-[0-9]{5}-[A-Z0-9]{4}-[A-Z0-9]$'
      OR NOT EXISTS (
          SELECT 1 FROM serial_registry sr 
          WHERE sr.serial_code = ft.serial_number 
            AND sr.checksum = SUBSTRING_INDEX(ft.serial_number, '-', -1)
      )
  );
```

### **Consistency Checker Job:**

```php
// cron/consistency_checker.php (run hourly)
function runConsistencyChecks(mysqli $tenantDb, mysqli $coreDb): void
{
    $checks = [
        'missing_link' => checkMissingLink($tenantDb),
        'missing_registry' => checkMissingRegistry($tenantDb, $coreDb),
        'invalid_format' => checkInvalidFormat($tenantDb)
    ];
    
    // Log results
    foreach ($checks as $check => $result) {
        error_log("Consistency check '$check': {$result['fixed']} fixed, {$result['failed']} failed");
    }
    
    // Alert if failures exceed threshold
    $totalFailed = array_sum(array_column($checks, 'failed'));
    if ($totalFailed > 100) {
        // Send alert
        error_log("ALERT: Consistency checker found $totalFailed issues requiring attention");
    }
}
```

**Invariant:** Consistency checker fixes auto-fixable issues and alerts on manual intervention required.

---

## 🔗 Related Documents

- `SERIAL_NUMBER_DESIGN.md` - Design specification
- `SERIAL_CONTEXT_AWARENESS.md` - Production context differences
- `SERIAL_NUMBER_INTEGRATION_ANALYSIS.md` - Current system analysis + Action Plan
- `SERIAL_NUMBER_IMPLEMENTATION.md` - Implementation guide
- `SERIAL_NUMBER_INDEX.md` - Master index

---

**Status:** ✅ **Complete System Context Verified + Production Hardening**  
**Last Updated:** November 9, 2025

