# 🎯 Serial Number System - Design Document

**Created:** November 9, 2025  
**Last Updated:** November 9, 2025  
**Purpose:** Complete design specification (Analysis + Proposal + Approved Baseline)  
**Status:** ✅ **APPROVED - Baseline Document**

---

## 📋 Document Structure

This document consolidates:
- **Current State Analysis** - Issues and gaps identified
- **Design Proposal** - Adapted GSG/CLSG concepts
- **Approved Baseline** - Version 1.0 specification

---

## 🎯 Executive Summary

**Design Goal:** Standardize serial number system with human-readable, traceable, secure format

**Key Decisions:**
1. **Format:** `{TENANT}-{PROD_TYPE}-{SKU}-{YYYYMMDD}-{SEQ}-{HASH-4}-{CHECKSUM}`
2. **Security:** Hybrid approach (sequence + hash + checksum)
3. **Registry:** Global registry in Core DB for uniqueness guarantee
4. **Backward Compatibility:** Support old formats, don't migrate existing serials
5. **Future-Ready:** Reserved fields for component tracking (Phase 3)

**Implementation Phases:**
- **Phase 1:** Standardization (Week 1-2) 🔴 CRITICAL
- **Phase 2:** Global Registry + Verification (Week 3-4) 🟡 HIGH
- **Phase 3:** Component Tracking (Future) 🟢 MEDIUM

---

## 📊 Current State Analysis

### **Critical Issues Found (10 Issues)**

#### **Issue 1: Multiple Format Standards** ⚠️ **CRITICAL**

**Problem:** มีหลายรูปแบบ serial number ใช้ในระบบเดียวกัน

**Current Formats Found:**
1. **Secure Format (Current Standard):** `{PREFIX}-{YEAR}-{HASH-6}` (e.g., `TOTE-2025-A7F3C9`)
2. **Legacy Sequential Format:** `{PREFIX}-{YEAR}-{SEQ}` (e.g., `TOTE-2025-0001`) - Predictable, insecure
3. **MO Format:** `{MO_CODE}-{SEQ}` (e.g., `MO-2025-001-0001`) - Different format
4. **Batch Lot Format:** `LOT-{PREFIX}-{YEAR}-{HASH}` - ✅ OK (intentional)

**Impact:**
- ❌ ไม่สามารถ validate format ได้อย่างถูกต้อง
- ❌ Query serials ยาก (ต้องเช็คหลายรูปแบบ)
- ❌ Security risk (sequential format ทำปลอมได้)

#### **Issue 2: Inconsistent Uniqueness Checking** ⚠️ **CRITICAL**

**Problem:** การตรวจสอบ uniqueness ไม่ครอบคลุมทุกที่

- `SecureSerialGenerator::isUnique()` - เช็คแค่ `hatthasilpa_wip_log`
- `SerialManagementService::serialExists()` - เช็ค 3 tables แต่ไม่ครบ

**Impact:** Serial collision risk, data inconsistency

#### **Issue 3-10: Additional Issues**

- **Issue 3:** Multiple generation points (no central control)
- **Issue 4:** Incomplete validation (format only, no business rules)
- **Issue 5:** Database schema inconsistency (multiple tables, no clear ownership)
- **Issue 6:** Prefix handling inconsistency
- **Issue 7:** Error handling inconsistency
- **Issue 8:** Status lifecycle management unclear
- **Issue 9:** Batch vs piece mode handling
- **Issue 10:** QR code integration not used

---

## 📐 Standard Format Specification

### **Format Pattern:**

```
{TENANT_CODE}-{PROD_TYPE}-{SKU}-{YYYYMMDD}-{SEQ}-{HASH-4}-{CHECKSUM}
```

### **Example:**

```
MA01-HAT-DIAG-20251109-00057-A7F3-X
```

### **Component Breakdown:**

| Component | Example | Description | Validation | Notes |
|-----------|---------|-------------|------------|-------|
| `TENANT_CODE` | `MA01` | Tenant serial code (2-8 alphanumeric) | `[A-Z0-9]{2,8}` | From `organization.org_serial_code` |
| `PROD_TYPE` | `HAT` | Production type (2-4 uppercase) | `[A-Z]{2,4}` | HAT=Hatthasilpa, OEM=OEM |
| `SKU` | `DIAG` | Product SKU (2-8 alphanumeric) | `[A-Z0-9]{2,8}` | **NO hyphens or special chars** |
| `YYYYMMDD` | `20251109` | Date (8 digits, CE year) | `\d{8}` | UTC date, supports leap years |
| `SEQ` | `00057` | Sequence number (5 digits, zero-padded) | `\d{5}` | Daily reset, max 99999 per day |
| `HASH-4` | `A7F3` | Security hash (4 alphanumeric) | `[A-Z0-9]{4}` | HMAC-SHA256 derived |
| `CHECKSUM` | `X` | Checksum (1 alphanumeric) | `[A-Z0-9]` | Modulo 36 validation |

**SKU Validation Rules:**
- ✅ **Allowed:** Uppercase letters (A-Z) and digits (0-9)
- ❌ **Prohibited:** Hyphens (-), underscores (_), spaces, special characters
- ✅ **Length:** 2-8 characters
- ✅ **Normalization:** Service must convert to uppercase before use

### **REGEX Validation Pattern:**

```regex
^([A-Z0-9]{2,8})-([A-Z]{2,4})-([A-Z0-9]{2,8})-(\d{8})-(\d{5})-([A-Z0-9]{4})-([A-Z0-9])$
```

**Rationale:**
- ✅ Human-readable (clear structure)
- ✅ Traceable (date + sequence)
- ✅ Secure (hash prevents prediction)
- ✅ Validatable (checksum for error detection)
- ✅ Compatible with current system (uses existing org_code, sku)
- ✅ Machine-readable (regex validation)

---

## 🗄️ Database Schema

### **Field Definitions**

**Tenant Identification:**
- `tenant_id` (INT) - Tenant identity in ERP system (foreign key to `organization.id_org`)
- `org_code` (VARCHAR) - Short code printed on serial (e.g., `MA01`, `DEF01`)

**Relationship:** `tenant_id` is the system identifier, `org_code` is the serial prefix.

---

### **Core DB: serial_registry**

```sql
CREATE TABLE serial_registry (
    id_serial BIGINT PRIMARY KEY AUTO_INCREMENT,
    serial_code VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin UNIQUE NOT NULL COMMENT 'Case-sensitive serial',
    tenant_id INT NOT NULL,
    org_code VARCHAR(50) NOT NULL,
    production_type ENUM('hatthasilpa', 'oem') NOT NULL,
    sku VARCHAR(50) NULL,
    mo_id BIGINT NULL COMMENT 'For OEM batch-level traceability',
    job_ticket_id BIGINT NULL COMMENT 'For OEM or Hatthasilpa job-level traceability',
    dag_token_id BIGINT NULL COMMENT 'For Hatthasilpa piece-level traceability',
    created_at DATETIME NOT NULL DEFAULT (UTC_TIMESTAMP()) COMMENT 'UTC timestamp',
    issued_by VARCHAR(64) NULL,
    status ENUM('active', 'used', 'scrapped', 'cancelled') DEFAULT 'active',
    hash_signature VARCHAR(128) NOT NULL COMMENT 'HMAC-SHA256',
    hash_salt_version TINYINT UNSIGNED DEFAULT 1 COMMENT 'Salt version for key rotation',
    checksum CHAR(1) NOT NULL,
    
    -- Production context fields (NO DEFAULT - Service must set explicitly)
    serial_scope ENUM('piece','batch') DEFAULT 'piece' COMMENT 'Serial granularity level (HAT=piece, OEM=batch)',
    linked_source ENUM('dag_token','job_ticket') NULL COMMENT 'Source system for traceability (NO DEFAULT - Service must set based on HAT/OEM)',
    
    -- Reserved fields for Phase 3 (Component-Level Tracking) - NOT USED in Phase 1-2
    serial_type ENUM('product', 'component', 'subassembly') DEFAULT 'product' COMMENT 'Reserved for Phase 3 - DO NOT USE in Phase 1-2',
    batch_code VARCHAR(50) NULL COMMENT 'Reserved for Phase 3 - DO NOT USE in Phase 1-2',
    component_category VARCHAR(50) NULL COMMENT 'Reserved for Phase 3 - DO NOT USE in Phase 1-2',
    serial_origin_source ENUM('auto_mo', 'auto_job', 'manual_entry', 'import_migration', 'api_generated') DEFAULT 'auto_job',
    
    -- Indexes
    INDEX idx_tenant_date (tenant_id, created_at),
    INDEX idx_status (status),
    INDEX idx_mo (mo_id),
    INDEX idx_job (job_ticket_id),
    INDEX idx_dag_token (dag_token_id),
    INDEX idx_serial_type (serial_type),
    INDEX idx_origin (serial_origin_source),
    INDEX idx_salt_version (hash_salt_version),
    INDEX idx_scope (serial_scope),
    INDEX idx_linked_source (linked_source),
    INDEX idx_daily_sku (tenant_id, production_type, sku, created_at) COMMENT 'For daily/SKU reporting dashboards'
) ENGINE=InnoDB;
```

### **Core DB: serial_seq_daily**

```sql
CREATE TABLE serial_seq_daily (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    tenant_id INT NOT NULL,
    prod_type ENUM('hatthasilpa', 'oem') NOT NULL,
    sku VARCHAR(50) NOT NULL,
    ymd CHAR(8) NOT NULL COMMENT 'YYYYMMDD (UTC)',
    seq INT NOT NULL,
    
    UNIQUE KEY uniq_scope (tenant_id, prod_type, sku, ymd, seq),
    INDEX idx_lookup (tenant_id, prod_type, sku, ymd)
) ENGINE=InnoDB;
```

### **Core DB: organization (Update)**

```sql
ALTER TABLE organization 
ADD COLUMN org_serial_code VARCHAR(8) UNIQUE NULL COMMENT 'Serial prefix (e.g., MA01)';
```

---

## 🔧 Service Specification

### **UnifiedSerialService**

**Namespace:** `BGERP\Service\UnifiedSerialService`

**Key Methods:**

#### **1. generateSerial()**

```php
public function generateSerial(
    int $tenantId,
    string $productionType,
    string $sku,
    ?int $moId = null,
    ?int $jobTicketId = null,
    ?int $dagTokenId = null,
    string $originSource = 'auto_job'
): string
```

**Algorithm:**
1. Determine production context (HAT vs OEM)
2. Get tenant serial code from `organization.org_serial_code`
3. Get daily sequence (per tenant+type+sku+date)
4. Generate security hash (4 chars, production-type-specific salt)
5. Build serial string
6. Calculate checksum
7. Register in global registry
8. Return serial

#### **2. verifySerial()**

```php
public function verifySerial(string $serial): array
```

**Verification Steps:**
1. Format validation (regex)
2. Checksum validation (new format only)
3. Registry lookup
4. Hash signature validation (production-type-specific salt)
5. Status check
6. Return verification result

**Response Format:**
```php
[
    'valid' => bool,
    'verified' => bool,
    'checksum_valid' => bool,
    'hash_valid' => bool,
    'status' => string,
    'production_type' => string,
    'scope' => string, // 'piece' or 'batch'
    'linked_source' => string, // 'dag_token' or 'job_ticket'
    'data' => [
        'serial' => string,
        'tenant' => string,
        'production_type' => string,
        'sku' => string,
        'manufactured_at' => datetime,
        'status' => string,
        'origin' => string,
        'traceability' => array, // Context-specific trace data
        'visibility' => string // 'public' or 'internal'
    ]
]
```

**Privacy Policy for Public Verify:**

⚠️ **CRITICAL:** Public verify endpoint **MUST NOT** return PII (Personally Identifiable Information) of artisans directly.

**Allowed Data:**
- ✅ Artisan display name (e.g., "Somchai R.") - anonymized
- ✅ Artisan role/skill (e.g., "Leather Cutting") - non-PII
- ✅ Node/workstation name (e.g., "Cutting Station")
- ✅ Completion timestamps (generalized)

**Prohibited Data:**
- ❌ Full legal names
- ❌ Personal IDs or employee numbers
- ❌ Contact information
- ❌ Any data that can identify individual artisans without authorization

**Implementation:** Apply privacy policy filter before returning `traceability.artisan_chain` data.

---

## 🔄 Migration Plan

### **Phase 1: Standardization**

1. Add `org_serial_code` to organization table
2. Create `UnifiedSerialService`
3. Update all generation points
4. Add format validation
5. Support backward compatibility (old formats)

### **Phase 2: Global Registry**

1. Create `serial_registry` table
2. Create `serial_seq_daily` table
3. Update `UnifiedSerialService` to register serials
4. Add uniqueness checking
5. Create verification API
6. Add monitoring/audit

### **Phase 3: Component Tracking**

1. Use reserved fields (`serial_type`, `component_category`)
2. Create `serial_relationships` table
3. Update BOM tracking
4. Add traceability UI

---

## 🚨 Critical Considerations

### **1. Backward Compatibility**

**Problem:** Existing serials use old format  
**Solution:** 
- Keep old serials as-is (don't migrate)
- New serials use new format
- Support both formats in validation

### **2. Performance**

**Problem:** Global registry may be bottleneck  
**Solution:**
- Use caching (Redis/APCu)
- Batch registration
- Async registration for high-volume

### **3. Multi-Tenant Isolation**

**Problem:** Global registry in Core DB  
**Solution:**
- Registry stores tenant_id
- Queries filtered by tenant
- Cross-tenant queries only for verification

### **4. Production Context**

**Critical:** Read `SERIAL_CONTEXT_AWARENESS.md` for HAT vs OEM differences

- **Hatthasilpa:** Piece-level, DAG-based, public traceability, `SERIAL_SECRET_SALT_HAT`
- **OEM:** Batch-level, Job Ticket-based, internal traceability, `SERIAL_SECRET_SALT_OEM`

### **5. Salt Management Policy**

**Storage:** Environment variables (`.env` file or system environment)

**Required Variables:**
```bash
# Production-type-specific salts (REQUIRED - both must be set)
SERIAL_SECRET_SALT_HAT=hatthasilpa_secret_salt_change_in_production
SERIAL_SECRET_SALT_OEM=oem_secret_salt_change_in_production
```

**Security Policy:**
- ✅ **DO NOT** hardcode salts in code
- ✅ **DO NOT** use default/fallback salts
- ✅ **DO NOT** share salts between production types
- ✅ **DO** fail fast if salt missing (throw RuntimeException)
- ✅ **DO** rotate salts periodically (use `hash_salt_version` field)

**Implementation:**
```php
// CORRECT: Production-type-specific salt
$salt = getenv($isHatthasilpa ? 'SERIAL_SECRET_SALT_HAT' : 'SERIAL_SECRET_SALT_OEM');
if (!$salt) {
    throw new RuntimeException("Missing salt for {$productionType}");
}

// WRONG: Generic salt or default
$salt = getenv('SERIAL_SECRET_SALT') ?: 'default'; // ❌ DO NOT DO THIS
```

**Salt Rotation Flow:**

When rotating salts (e.g., version 1 → version 2):

```bash
# Step 1: Set new salt environment variable
export SERIAL_SECRET_SALT_HAT_V2='new_hatthasilpa_secret_salt_2026'

# Step 2: Update service to use version 2 for new serials
# (In UnifiedSerialService, set hash_salt_version = 2 for new serials)

# Step 3: Verify backward compatibility
# Old serials (version 1) should still verify with SERIAL_SECRET_SALT_HAT
# New serials (version 2) should verify with SERIAL_SECRET_SALT_HAT_V2
```

**Key Points:**
- ✅ Old serials continue to verify with old salt (version 1)
- ✅ New serials use new salt (version 2)
- ✅ `hash_salt_version` field tracks which salt was used
- ✅ Service uses `getSaltForVersion()` to select correct salt during verification

### **6. Timezone Consistency**

**Requirement:** All timestamps must use UTC

**Database:**
- `created_at DATETIME` - Stored as UTC (use `UTC_TIMESTAMP()`)
- `ymd CHAR(8)` - Date in YYYYMMDD format (UTC)

**PHP Configuration:**
```php
// Set UTC timezone at application bootstrap
date_default_timezone_set('UTC');
```

**Rationale:** Prevents sequence reset issues at midnight boundary across timezones

---

## 🧠 Service Behavior Matrix

**Purpose:** Quick reference for AI Agents implementing serial generation logic

| Production Type | Serial Scope | Registry Link Field | Trace Source | Visibility | Salt ENV |
|-----------------|--------------|---------------------|--------------|------------|----------|
| **Hatthasilpa** | `piece` | `dag_token_id` (required) | `DAG Token + People Profile` | Public | `SERIAL_SECRET_SALT_HAT` |
| **OEM** | `batch` | `job_ticket_id` or `mo_id` (required) | `Job Ticket + MO Header` | Internal | `SERIAL_SECRET_SALT_OEM` |

**Field Usage Rules:**

**For Hatthasilpa (`production_type = 'hatthasilpa'`):**
- ✅ **MUST** set `dag_token_id` (piece-level traceability) - **NOT NULL required**
- ✅ **MAY** set `job_ticket_id` (job-level reference)
- ❌ **MUST NOT** set `mo_id` (OEM only) - **MUST be NULL**
- ✅ **MUST** set `serial_scope = 'piece'`
- ✅ **MUST** set `linked_source = 'dag_token'` (explicitly, no default)

**For OEM (`production_type = 'oem'`):**
- ✅ **MUST** set `mo_id` or `job_ticket_id` (batch-level traceability) - **At least one NOT NULL**
- ❌ **MUST NOT** set `dag_token_id` (Hatthasilpa only) - **MUST be NULL**
- ✅ **MUST** set `serial_scope = 'batch'`
- ✅ **MUST** set `linked_source = 'job_ticket'` (explicitly, no default)

**Service Validation Rules (Application-Level Constraints):**

Since MySQL does not support conditional CHECK constraints across columns, the Service **MUST** enforce these rules:

1. **If `production_type = 'hatthasilpa'`:**
   - `dag_token_id` **MUST NOT** be NULL
   - `mo_id` **MUST** be NULL
   - `serial_scope` **MUST** be 'piece'
   - `linked_source` **MUST** be 'dag_token'

2. **If `production_type = 'oem'`:**
   - `mo_id` OR `job_ticket_id` **MUST NOT** be NULL (at least one)
   - `dag_token_id` **MUST** be NULL
   - `serial_scope` **MUST** be 'batch'
   - `linked_source` **MUST** be 'job_ticket'

**Violation:** Service throws `ERR_CONTEXT_MISMATCH` exception before database insert.

**Phase 3 Reserved Fields (DO NOT USE in Phase 1-2):**
- ❌ `serial_type` - Reserved for component tracking
- ❌ `batch_code` - Reserved for batch tracking
- ❌ `component_category` - Reserved for component categories

**Service Behavior Guard (Context Validation):**

The `UnifiedSerialService::generateSerial()` method **MUST** enforce context validation:

```php
// Context validation (fail fast)
if ($productionType === 'hatthasilpa') {
    if ($moId !== null) {
        throw new RuntimeException('ERR_CONTEXT_MISMATCH: Hatthasilpa cannot have mo_id');
    }
    if ($dagTokenId === null && $jobTicketId === null) {
        throw new RuntimeException('ERR_CONTEXT_MISMATCH: Hatthasilpa must have dag_token_id or job_ticket_id');
    }
    // MUST set serial_scope = 'piece' and linked_source = 'dag_token'
}

if ($productionType === 'oem') {
    if ($dagTokenId !== null) {
        throw new RuntimeException('ERR_CONTEXT_MISMATCH: OEM cannot have dag_token_id');
    }
    if ($moId === null && $jobTicketId === null) {
        throw new RuntimeException('ERR_CONTEXT_MISMATCH: OEM must have mo_id or job_ticket_id');
    }
    // MUST set serial_scope = 'batch' and linked_source = 'job_ticket'
}
```

**Important Notes:**
- ✅ `linked_source` has **NO DEFAULT** - Service must set explicitly based on production type
- ✅ `created_at` uses `DEFAULT (UTC_TIMESTAMP())` for consistency
- ✅ Service **MUST** set `serial_scope` every time (HAT=piece, OEM=batch)
- ✅ Service **MUST** validate context before insert (fail fast on mismatch)

---

## 🧾 Error Code Reference

**Purpose:** Standardized error codes for API responses

| Code | HTTP Status | Message | Typical Cause |
|------|-------------|---------|---------------|
| `ERR_DUPLICATE_SERIAL` | 409 Conflict | Serial already exists in registry | Race condition or duplicate request |
| `ERR_INVALID_HASH` | 401 Unauthorized | Hash signature mismatch | Wrong salt or data corruption |
| `ERR_CHECKSUM_FAIL` | 400 Bad Request | Invalid checksum | Format tampering or transmission error |
| `ERR_NOT_FOUND` | 404 Not Found | Serial not found in registry | Deleted, wrong tenant, or counterfeit |
| `ERR_UNAUTHORIZED_TENANT` | 403 Forbidden | Tenant mismatch | Wrong environment or unauthorized access |
| `ERR_CONTEXT_MISMATCH` | 400 Bad Request | Production type inconsistent | Wrong HAT/OEM logic or field usage |
| `ERR_INVALID_FORMAT` | 400 Bad Request | Serial format does not match pattern | Invalid regex or malformed serial |
| `ERR_MISSING_SALT` | 500 Internal Server Error | Missing SERIAL_SECRET_SALT for production type | Environment variable not configured |
| `ERR_SEQUENCE_RETRY_EXCEEDED` | 500 Internal Server Error | Failed to get sequence after retries | High contention or database issue |
| `ERR_SKU_INVALID` | 400 Bad Request | SKU contains invalid characters | SKU must be [A-Z0-9]{2,8}, no hyphens or special chars |

**API Response Format:**
```json
{
  "success": false,
  "error": {
    "code": "ERR_DUPLICATE_SERIAL",
    "message": "Serial already exists in registry",
    "details": {
      "serial": "MA01-HAT-DIAG-20251109-00057-A7F3-X",
      "existing_id": 12345
    }
  }
}
```

---

## 🧪 Test Matrix

**Purpose:** Comprehensive test scenarios for AI Agents

| Test ID | Scenario | Production Type | Expected Behavior | Validation |
|---------|----------|-----------------|-------------------|------------|
| **T1** | Generate piece-level serial | Hatthasilpa | Creates 1 serial per token, sets `dag_token_id` | `serial_scope = 'piece'`, `dag_token_id` not null |
| **T2** | Generate batch-level serial | OEM | Creates 1 serial per batch, sets `mo_id` or `job_ticket_id` | `serial_scope = 'batch'`, `mo_id` or `job_ticket_id` not null |
| **T3** | Invalid regex format | Both | Returns `ERR_INVALID_FORMAT` | Format validation fails |
| **T4** | Duplicate serial insert | Both | Returns `ERR_DUPLICATE_SERIAL` | UNIQUE constraint violation |
| **T5** | Checksum mismatch | Both | Returns `ERR_CHECKSUM_FAIL` | Checksum validation fails |
| **T6** | Hash signature mismatch | Both | Returns `ERR_INVALID_HASH` | Hash verification fails |
| **T7** | Serial not found | Both | Returns `ERR_NOT_FOUND` | Registry lookup returns null |
| **T8** | Cross-tenant verification | Both | Returns `ERR_UNAUTHORIZED_TENANT` | Tenant mismatch |
| **T9** | Context mismatch (HAT with `mo_id`) | Hatthasilpa | Returns `ERR_CONTEXT_MISMATCH` | Invalid field combination |
| **T10** | Context mismatch (OEM with `dag_token_id`) | OEM | Returns `ERR_CONTEXT_MISMATCH` | Invalid field combination |
| **T11** | Missing salt (HAT) | Hatthasilpa | Returns `ERR_MISSING_SALT` | `SERIAL_SECRET_SALT_HAT` not set |
| **T12** | Missing salt (OEM) | OEM | Returns `ERR_MISSING_SALT` | `SERIAL_SECRET_SALT_OEM` not set |
| **T13** | Daily sequence reset | Both | Sequence resets to 00001 on new day | `ymd` changes, `seq` starts at 1 |
| **T14** | High contention (100 parallel) | Both | All serials unique, retry count < 10 | Race condition handling works |
| **T15** | Backward compatibility (old format) | Both | Old format still verifies | Format detection works |
| **T16** | Leap day sequence reset | Both | Sequence resets correctly on 2024-02-29 | Daily reset works on leap years |
| **T17** | SKU validation (invalid chars) | Both | Returns `ERR_SKU_INVALID` | SKU must be [A-Z0-9]{2,8}, no hyphens |
| **T18** | Salt rotation (version 1 → 2) | Both | Old serials verify with v1, new serials verify with v2 | Key rotation works correctly |

---

## 🔗 Integration Reference

**Purpose:** Real-world integration examples for AI Agents

### **Hatthasilpa Integration (DAG Token API)**

**File:** `source/dag_token_api.php`

**Integration Point:**
```php
// Generate serials BEFORE spawning tokens (CRITICAL ORDER)
$serials = [];
if ($ticket['process_mode'] === 'piece') {
    for ($i = 0; $i < $ticket['target_qty']; $i++) {
        $serial = UnifiedSerialService::generateSerial(
            tenantId: $tenantId,
            productionType: 'hatthasilpa',
            sku: $ticket['sku'],
            jobTicketId: $ticketId,
            dagTokenId: null, // Will be set after token spawn
            originSource: 'auto_job'
        );
        $serials[] = $serial;
    }
}

// Spawn tokens with serials
$tokenIds = $tokenService->spawnTokens(
    $instanceId,
    $ticket['target_qty'],
    $ticket['process_mode'],
    $serials
);

// Update registry with dag_token_id after spawn
foreach ($tokenIds as $idx => $tokenId) {
    UnifiedSerialService::linkDagToken($serials[$idx], $tokenId);
}
```

**Key Points:**
- ✅ Generate serials **BEFORE** token spawn
- ✅ Link `dag_token_id` **AFTER** token spawn
- ✅ Use `SERIAL_SECRET_SALT_HAT` for hash generation

### **OEM Integration (Job Ticket API)**

**File:** `source/hatthasilpa_job_ticket.php` (OEM mode)

**Integration Point:**
```php
// Generate batch serial for OEM production
$serial = UnifiedSerialService::generateSerial(
    tenantId: $tenantId,
    productionType: 'oem',
    sku: $ticket['sku'],
    moId: $moId,
    jobTicketId: $ticketId,
    originSource: 'auto_mo'
);

// Store serial in job_ticket_serial table (for backward compatibility)
$stmt = $tenantDb->prepare("
    INSERT INTO job_ticket_serial 
    (id_job_ticket, serial_number, sequence_no, generated_at)
    VALUES (?, ?, 1, NOW())
");
$stmt->bind_param('is', $ticketId, $serial);
$stmt->execute();
```

**Key Points:**
- ✅ Generate **ONE** serial per batch (not per piece)
- ✅ Link to `mo_id` or `job_ticket_id`
- ✅ Use `SERIAL_SECRET_SALT_OEM` for hash generation

---

## 📡 API Output Examples

### **Verify Serial - Hatthasilpa (Success)**

**Request:**
```
GET /api/public/serial/verify/MA01-HAT-BAG-20251109-00027-A9K2-X
```

**Response:**
```json
{
  "success": true,
  "valid": true,
  "verified": true,
  "checksum_valid": true,
  "hash_valid": true,
  "status": "active",
  "data": {
    "serial": "MA01-HAT-BAG-20251109-00027-A9K2-X",
    "tenant": "maison_atelier",
    "production_type": "hatthasilpa",
    "sku": "BAG",
    "manufactured_at": "2025-11-09T14:32:05Z",
    "status": "active",
    "origin": "auto_job",
    "traceability": {
      "dag_token_id": 12345,
      "job_ticket_id": 15,
      "artisan_chain": [
        {
          "node": "Cutting",
          "artisan": "Somchai",
          "skill": "Leather Cutting"
        },
        {
          "node": "Edge Painting",
          "artisan": "Mali",
          "skill": "Edge Finishing"
        }
      ]
    },
    "visibility": "public"
  }
}
```

### **Verify Serial - OEM (Success)**

**Request:**
```
GET /api/public/serial/verify/MA01-OEM-KFOB-20251109-00001-F73J-D
```

**Response:**
```json
{
  "success": true,
  "valid": true,
  "verified": true,
  "checksum_valid": true,
  "hash_valid": true,
  "status": "active",
  "data": {
    "serial": "MA01-OEM-KFOB-20251109-00001-F73J-D",
    "tenant": "maison_atelier",
    "production_type": "oem",
    "sku": "KFOB",
    "manufactured_at": "2025-11-09T08:15:30Z",
    "status": "active",
    "origin": "auto_mo",
    "traceability": {
      "mo_id": 2025,
      "job_ticket_id": 42,
      "batch_code": "BATCH-2025-0412-A",
      "operator_team": "Team A"
    },
    "visibility": "internal"
  }
}
```

### **Verify Serial - Error (Not Found)**

**Request:**
```
GET /api/public/serial/verify/MA01-HAT-DIAG-20251109-99999-XXXX-X
```

**Response:**
```json
{
  "success": false,
  "valid": false,
  "error": {
    "code": "ERR_NOT_FOUND",
    "message": "Serial not found in registry - may be counterfeit",
    "details": {
      "serial": "MA01-HAT-DIAG-20251109-99999-XXXX-X"
    }
  }
}
```

---

## 🔐 Hardening Checklist

### **Critical Requirements:**

1. **Sequence Scope:** tenant + production_type + sku + Ymd (daily reset)
2. **Race Safety:** Use INSERT-only technique (no counter table)
3. **Regex Validation:** Enforce format at all entry points
4. **Checksum:** Calculate from raw string BEFORE adding checksum
5. **Hash Security:** Use HMAC-SHA256 with production-type-specific salt
6. **Registry Uniqueness:** UNIQUE constraint on serial_code
7. **Backward Compatibility:** Support old format serials in verification
8. **Salt Isolation:** Separate salts for HAT and OEM (security)

---

## 📚 Related Documents

- `docs/SERIAL_NUMBER_IMPLEMENTATION.md` - Complete implementation guide with code
- `docs/SERIAL_CONTEXT_AWARENESS.md` - **CRITICAL: Production context differences**
- `docs/SERIAL_NUMBER_INDEX.md` - Master index of all documents

---

## 🧩 Note for AI Agents

> **⚠️ CRITICAL:** Always read `SERIAL_CONTEXT_AWARENESS.md` together with this file.

This design document provides the technical specification, but `SERIAL_CONTEXT_AWARENESS.md` provides the **behavioral context** that determines how to use the fields correctly.

**Required Reading Order:**
1. Read this document (`SERIAL_NUMBER_DESIGN.md`) for format, schema, and API specs
2. **MUST READ** `SERIAL_CONTEXT_AWARENESS.md` for production context differences
3. Use `SERIAL_NUMBER_IMPLEMENTATION.md` for code examples

**Common Mistakes to Avoid:**
- ❌ Using `mo_id` for Hatthasilpa serials
- ❌ Using `dag_token_id` for OEM serials
- ❌ Using wrong salt (`SERIAL_SECRET_SALT_HAT` for OEM or vice versa)
- ❌ Setting `serial_scope` incorrectly (piece vs batch)
- ❌ Using Phase 3 reserved fields in Phase 1-2

---

**Last Updated:** November 9, 2025  
**Status:** ✅ APPROVED - Baseline Document  
**Version:** 1.0  
**Next Version:** 1.1 (Planned: Add component tracking specification)

