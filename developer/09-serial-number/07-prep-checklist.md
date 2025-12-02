# 🚀 Serial Number System - Pre-Flight Checklist

**Created:** November 9, 2025  
**Purpose:** Pre-implementation context checklist for AI Agents  
**Status:** ✅ **Ready for Implementation**

---

## 🎯 Goal

ออกแบบ/ปรับใช้ Serial แบบมาตรฐานเดียว ที่เชื่อมกับ DAG/Job Ticket/Assignment อย่างถูกต้อง ป้องกันซ้ำ ปลอดภัย ตรวจสอบย้อนกลับได้ และพร้อม production.

---

## 1️⃣ สองโลกการผลิต (ต้องแยกชัด)

### **Hatthasilpa (HAT) - Atelier Craftsmanship**

- ✅ `serial_scope='piece'` (per-piece serial)
- ✅ `linked_source='dag_token'` (must have `dag_token_id` after spawn)
- ✅ Uses `SERIAL_SECRET_SALT_HAT`
- ✅ Public verify (customer-facing, but NO PII)
- ✅ Trace to artisan/session level

### **OEM - Industrial Manufacturing**

- ✅ `serial_scope='batch'` (per-batch serial)
- ✅ `linked_source='job_ticket'` or `'mo'` (must have `job_ticket_id` or `mo_id`)
- ✅ **MUST NOT** have `dag_token_id`
- ✅ Uses `SERIAL_SECRET_SALT_OEM`
- ✅ Internal verify only (manager dashboard)

**❗ Violation:** Context mismatch → Throw `ERR_CONTEXT_MISMATCH`

---

## 2️⃣ รูปแบบ Serial + Case Sensitivity

### **Format:**
```
{TENANT}-{PROD}-{SKU}-{YYYYMMDD}-{SEQ}-{HASH4}-{CHECKSUM}
Example: MA01-HAT-DIAG-20251109-00057-A7F3-X
```

### **Database Requirements:**
- ✅ `serial_registry.serial_code` **MUST** be `utf8mb4_bin` (case-sensitive) + `UNIQUE`
- ✅ `created_at` uses UTC: `DEFAULT (UTC_TIMESTAMP())`
- ✅ PHP timezone **MUST** match DB timezone (both UTC)

---

## 3️⃣ แหล่ง Serial (ห้ามสร้างซ้ำ)

### **Hatthasilpa Flow:**

1. **Job Ticket Creation:**
   - Pre-generate serials using `UnifiedSerialService::generateSerial()`
   - Store in `job_ticket_serial` table (`sequence_no` 1..N)
   - Register in `serial_registry` (Core DB) with `linked_source='job_ticket'`, `dag_token_id=NULL`

2. **DAG Token Spawn:**
   - ✅ **MUST** fetch from `job_ticket_serial` (`spawned_at IS NULL ORDER BY sequence_no`)
   - ❌ **MUST NOT** generate new serials
   - If not enough serials → Generate additional ones and insert into `job_ticket_serial` first

3. **After Spawn (Dual-Link):**
   - Link Tenant DB: `job_ticket_serial.spawned_at`, `spawned_token_id`
   - Link Core DB: `serial_registry.dag_token_id` (via `UnifiedSerialService::linkDagToken()`)

### **OEM Flow:**

- Generate serial at MO/Batch creation using `UnifiedSerialService::generateSerial()`
- Register in `serial_registry` with `serial_scope='batch'`, `linked_source='mo'` or `'job_ticket'`
- All tokens in batch reference **same serial**

---

## 4️⃣ Node/DAG Invariant (กันบั๊ก)

**⚠️ CRITICAL:**

```
flow_token.current_node_id → routing_node.id_node (template)
NOT node_instance.id_node_instance (runtime state)
```

**Why:** `routing_node` is the template (reusable), `node_instance` is runtime state (per job).

**Wrong:** Querying `flow_token` JOIN `node_instance` on `current_node_id` → Will return empty/wrong data

**Correct:** Querying `flow_token` JOIN `routing_node` on `current_node_id` → Returns correct node info

**Verified in:** `dag_token_api.php` lines 17-24 (CRITICAL INVARIANT comment)

---

## 5️⃣ Assignment Precedence (เพื่อไม่ชวนงง)

### **Order of Resolution:**

1. **PIN (Manual Override)** - Highest priority
   - Manager pins specific operator to token/node
   - Always wins (even if plan exists)

2. **PLAN (Pre-configured)**
   - **Job Plan** (`assignment_plan_job`) - Specific to job + node
   - **Node Plan** (`assignment_plan_node`) - Applies to all jobs using this node
   - Can assign to `member` or `team`
   - Team expansion → Distributes to team members with lowest load + available

3. **AUTO (Rule-based)**
   - Skill matching (`node_required_skill` → `operator_skill`)
   - Availability filtering (`operator_availability`)
   - Load balancing (lowest active sessions)

### **Help Modes:**

- **Assist** = Doesn't change owner (logs helper session)
- **Handoff/Replace** = Changes owner (logs replacement reason)

---

## 6️⃣ Idempotency & Dual-Write

### **Idempotency:**

- ✅ All spawn and link operations **MUST** be idempotent
- ✅ Use `X-Idempotency-Key` header (UUID v4)
- ✅ Store in `token_spawn_log` table (`idempotency_key UNIQUE`)
- ✅ If duplicate key → Return previous result (HTTP 200, not 201)

### **Dual-Write Resilience:**

- ✅ When linking `serial_registry.dag_token_id` (Core DB) fails:
  - Write to `serial_link_outbox` (Tenant DB)
  - Background worker retries with exponential backoff (1m, 5m, 15m, 1h, 6h)
  - Max 10 retries → Mark `dead` and alert
- ✅ Spawn succeeds even if Core link fails (eventual consistency)

---

## 7️⃣ ENV / Feature Flags (ห้าม hardcode)

### **Environment Variables:**

```bash
# Salts (REQUIRED - no defaults)
SERIAL_SECRET_SALT_HAT=hatthasilpa_secret_salt_2025_v1
SERIAL_SECRET_SALT_OEM=oem_secret_salt_2025_v1

# Feature Toggles (per tenant)
FF_SERIAL_STD_HAT=on|off  # Default: off
FF_SERIAL_STD_OEM=on|off  # Default: off
FF_VERIFY_PUBLIC_MODE=minimal|standard|internal  # Default: minimal
```

### **Storage:**

- ✅ Store in `.env` or `tenant_feature_flags` table
- ❌ **NEVER** hardcode in source code
- ✅ Read-only at runtime (no write access)

---

## 8️⃣ DB Index ที่ "ต้องมี"

### **Core DB (`serial_registry`):**

```sql
-- Primary uniqueness
UNIQUE KEY uniq_serial (serial_code)  -- utf8mb4_bin

-- Fast lookups
INDEX idx_link_dag (dag_token_id)
INDEX idx_link_job (job_ticket_id, production_type)
INDEX idx_link_mo (mo_id, production_type)
INDEX idx_daily_sku (tenant_id, production_type, sku, created_at)
```

### **Tenant DB (`job_ticket_serial`):**

```sql
-- Prevent duplicate sequence numbers
UNIQUE KEY uniq_ticket_seq (id_job_ticket, sequence_no)

-- Fast lookup for unspawned serials
KEY idx_ticket_unspawned (id_job_ticket, spawned_at)
```

### **Future (Finished Product DB):**

```sql
-- Fast reporting
INDEX idx_tenant_completed (tenant_id, completed_at)
INDEX idx_sku_completed (sku, completed_at)
```

---

## 9️⃣ Privacy / Public Verify

### **Hatthasilpa (Public):**

- ✅ **Allowed:** Display name (e.g., "Somchai R."), role/skill, node name, generalized timestamps
- ❌ **Prohibited:** Full legal names, personal IDs, employee numbers, contact information, exact timestamps (in minimal mode)

### **OEM (Internal):**

- ✅ Internal-only (manager dashboard)
- ❌ Hide individual artisan data

### **Cross-Salt Verification:**

- ✅ HAT serial verified with HAT salt → Pass
- ✅ OEM serial verified with OEM salt → Pass
- ❌ HAT serial verified with OEM salt → **MUST FAIL**
- ❌ OEM serial verified with HAT salt → **MUST FAIL**

---

## 🔟 Error Codes กลาง

| Code | HTTP | When |
|------|------|------|
| `ERR_CONTEXT_MISMATCH` | 400 | HAT with `mo_id` or OEM with `dag_token_id` |
| `ERR_ALREADY_LINKED` | 409 | Serial already linked to token |
| `ERR_SERIAL_NOT_FOUND` | 404 | Serial not found in registry |
| `ERR_NO_SERIAL_AVAILABLE` | 500 | No unspawned serials and generation failed |
| `ERR_ASSIGNMENT_PIN_CONFLICT` | 409 | Pinned assignment conflict |
| `ERR_TEAM_EMPTY` | 400 | Team has no active members |
| `ERR_AVAILABILITY_OFF` | 400 | Operator unavailable/on leave |
| `ERR_INVALID_FORMAT` | 400 | Serial format does not match pattern |
| `ERR_INVALID_HASH` | 401 | Hash signature mismatch |
| `ERR_CHECKSUM_FAIL` | 400 | Invalid checksum |

---

## 1️⃣1️⃣ Acceptance Criteria (ต้องผ่านก่อน merge)

### **Test 1: No-Duplicate on Spawn**

- Pre-generate 10 serials for HAT job ticket
- Spawn 10 tokens
- ✅ No new serials generated during spawn
- ✅ All 10 `job_ticket_serial.spawned_at` set
- ✅ All 10 `job_ticket_serial.spawned_token_id` linked
- ✅ All 10 `serial_registry.dag_token_id` linked

### **Test 2: Partial Spawn**

- Pre-generate 10 serials
- Spawn only 6 tokens
- ✅ 6 `spawned_at` timestamps set
- ✅ 4 `spawned_at` remain NULL
- ✅ Next spawn uses remaining 4 serials

### **Test 3: OEM Standardization**

- Create MO with 3 batch tokens
- ✅ All serials use standardized format
- ✅ All serials in `serial_registry` with `production_type='oem'`
- ✅ `serial_scope='batch'`, `linked_source='mo'` or `'job_ticket'`

### **Test 4: Context Guards**

- Try HAT serial with `mo_id` → ✅ `ERR_CONTEXT_MISMATCH`
- Try OEM serial with `dag_token_id` → ✅ `ERR_CONTEXT_MISMATCH`

### **Test 5: Assignment Precedence**

- PIN exists → ✅ Use PIN (ignore plan/auto)
- Plan exists → ✅ Use plan (expand team if needed)
- No PIN/Plan → ✅ Use auto (skill + availability + load)

### **Test 6: Idempotency**

- Send duplicate request with same `idempotency_key` → ✅ Return previous result (HTTP 200)

### **Test 7: Cross-Salt Verification**

- HAT serial verified with OEM salt → ✅ **MUST FAIL**
- OEM serial verified with HAT salt → ✅ **MUST FAIL**

---

## 1️⃣2️⃣ Minimal Code Hooks ที่ต้องมี

### **SerialManagementService:**

```php
// Get unspawned serials (ordered by sequence_no)
public function getUnspawnedSerials(int $jobTicketId): array

// Mark serial as spawned (link to token)
public function markAsSpawned(string $serial, int $tokenId): bool
```

### **UnifiedSerialService:**

```php
// Generate standardized serial
public function generateSerial(
    int $tenantId,
    string $productionType,
    string $sku,
    ?int $moId = null,
    ?int $jobTicketId = null,
    ?int $dagTokenId = null,
    string $originSource = 'auto_job'
): string

// Verify serial format and registry
public function verifySerial(string $serialCode, string $privacyMode = 'minimal'): array

// Link serial to DAG token (HAT only)
public function linkDagToken(string $serialCode, int $dagTokenId): bool
```

### **AssignmentService (if needed):**

```php
// Resolve assignee for token/node
public function resolveAssignee(int $tokenId, int $nodeId): array
// Returns: ['mode' => 'pinned'|'team'|'auto', 'operator_id' => ?, 'team_id' => ?]
```

---

## 1️⃣3️⃣ Hourly Consistency Checker (งานแบ็คกราวด์)

### **Check 1: Missing Link (job_ticket_serial → flow_token)**

- Find `job_ticket_serial` with `spawned_token_id IS NULL` but referenced by `flow_token.serial_number`
- ✅ Fix: Update `job_ticket_serial.spawned_token_id` and `spawned_at`

### **Check 2: Missing Registry Link (serial_registry → flow_token)**

- Find `serial_registry` with `dag_token_id IS NULL` but serial present in active tokens
- ✅ Fix: Enqueue to `serial_link_outbox` (let worker retry)

### **Check 3: Invalid Format (Quarantine)**

- Find serials failing regex/checksum/hash validation
- ✅ Fix: Insert into `serial_quarantine` table for manual review

---

## 1️⃣4️⃣ สรุป Do/Don't

### **✅ DO:**

- ✅ Reuse serial from `job_ticket_serial` during spawn (HAT)
- ✅ Link back both Tenant (`spawned_*`) and Core (`dag_token_id`)
- ✅ Respect PIN > PLAN > AUTO precedence
- ✅ Check leave/availability before assignment
- ✅ Use idempotency keys for all spawn/link operations
- ✅ Write to outbox if Core DB link fails
- ✅ Enforce context invariants (HAT/OEM separation)
- ✅ Use UTC timestamps consistently
- ✅ Store salts in environment variables (never hardcode)
- ✅ Anonymize PII in public verify mode

### **❌ DON'T:**

- ❌ Generate serial during spawn (HAT) - reuse pre-generated
- ❌ Link `current_node_id` to `node_instance` - use `routing_node`
- ❌ Hardcode salts or feature flags
- ❌ Expose PII in public verify API
- ❌ Mix HAT and OEM contexts (different salts, different scopes)
- ❌ Skip idempotency checks
- ❌ Fail spawn if Core DB link fails (use outbox)
- ❌ Use case-insensitive collation for `serial_code`

---

## 🚀 Order of Operations

### **Phase 1: Database Setup**

1. ✅ Apply DB patches (indexes, collations)
   - Core DB: `serial_registry` indexes
   - Tenant DB: `job_ticket_serial` indexes
   - Create `serial_link_outbox` table
   - Create `token_spawn_log` table
   - Create `serial_quarantine` table

### **Phase 2: Service Methods**

2. ✅ Add required service methods
   - `SerialManagementService::getUnspawnedSerials()`
   - `SerialManagementService::markAsSpawned()` (update existing)
   - `UnifiedSerialService::generateSerial()` (implement)
   - `UnifiedSerialService::verifySerial()` (implement)
   - `UnifiedSerialService::linkDagToken()` (implement)

### **Phase 3: Integration Points**

3. ✅ Update 3 main files:
   - `hatthasilpa_job_ticket.php` (pre-gen + registry)
   - `dag_token_api.php` (reuse + dual-link + idempotent)
   - `mo.php` (OEM standardized + registry)

### **Phase 4: Feature Flags & Testing**

4. ✅ Enable flags per tenant (gradual rollout)
   - Week 1: Test tenant only
   - Week 2: 1 production tenant (monitor)
   - Week 3: All Hatthasilpa tenants
   - Week 4: All OEM tenants

5. ✅ Run smoke tests (all 7 acceptance criteria)

### **Phase 5: Background Jobs**

6. ✅ Enable Consistency Checker (hourly cron)
7. ✅ Enable Outbox Worker (retry failed Core DB links)

---

## 📋 Pre-Implementation Checklist

Before starting implementation, verify:

- [ ] Read `API_DEVELOPMENT_GUIDE.md` (coding standards)
- [ ] Read `.cursorrules` (project-specific rules)
- [ ] Read `SERIAL_NUMBER_DESIGN.md` (specification)
- [ ] Read `SERIAL_CONTEXT_AWARENESS.md` (production context)
- [ ] Read `SERIAL_NUMBER_INTEGRATION_ANALYSIS.md` (current system)
- [ ] Read `SERIAL_NUMBER_SYSTEM_CONTEXT.md` (semantic understanding)
- [ ] Understand Node/DAG invariant (`routing_node` not `node_instance`)
- [ ] Understand Assignment precedence (PIN > PLAN > AUTO)
- [ ] Understand Dual-write pattern (outbox for Core DB failures)
- [ ] Understand Idempotency requirements
- [ ] Environment variables set (`SERIAL_SECRET_SALT_HAT`, `SERIAL_SECRET_SALT_OEM`)
- [ ] Feature flags configured (`FF_SERIAL_STD_HAT`, `FF_SERIAL_STD_OEM`)

---

## 🔗 Related Documents

- `SERIAL_NUMBER_DESIGN.md` - Design specification
- `SERIAL_CONTEXT_AWARENESS.md` - Production context differences
- `SERIAL_NUMBER_INTEGRATION_ANALYSIS.md` - Current system analysis + Action Plan
- `SERIAL_NUMBER_SYSTEM_CONTEXT.md` - Complete system context (semantic understanding)
- `SERIAL_NUMBER_IMPLEMENTATION.md` - Implementation guide
- `SERIAL_NUMBER_INDEX.md` - Master index
- `docs/guide/API_DEVELOPMENT_GUIDE.md` - API development standards

---

**Status:** ✅ **Pre-Flight Checklist Complete**  
**Last Updated:** November 9, 2025

