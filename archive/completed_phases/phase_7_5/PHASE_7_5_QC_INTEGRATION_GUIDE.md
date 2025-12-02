# Phase 7.5 → QC System Integration Guide

**Created:** November 14, 2025  
**Purpose:** เอกสารสำหรับ AI Agent ที่จะพัฒนาระบบ QC เพื่อเชื่อมต่อกับ Phase 7.5 (Scrap & Replacement)  
**Status:** Ready for QC Development  
**Target Audience:** AI Agents developing QC system

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [What Phase 7.5 Already Provides](#what-phase-75-already-provides)
3. [Database Schema Reference](#database-schema-reference)
4. [API Endpoints Available](#api-endpoints-available)
5. [Event Types & Metadata](#event-types--metadata)
6. [QC → Scrap Flow Integration](#qc--scrap-flow-integration)
7. [Integration Points](#integration-points)
8. [Code Examples](#code-examples)
9. [Best Practices](#best-practices)
10. [Testing Checklist](#testing-checklist)

---

## 🎯 Overview

### What is Phase 7.5?

**Phase 7.5: Manual Scrap & Replacement** เป็นระบบที่รองรับการ:
- ✅ **Scrap Token** - ทำเครื่องหมาย token ว่า "ไม่สามารถใช้งานได้" (material defect, max rework exceeded, etc.)
- ✅ **Create Replacement Token** - สร้าง token ใหม่เพื่อแทนที่ token ที่ถูก scrap (manual mode only)
- ✅ **Track History** - บันทึกประวัติ scrap และ replacement ผ่าน `token_event`

### Why QC System Needs This?

**QC System จะต้องเชื่อมต่อกับ Phase 7.5 เมื่อ:**
1. **QC Fail → Rework Limit Reached** - เมื่อ token fail QC และถึง rework limit แล้ว → ต้อง scrap
2. **QC Fail → Material Defect** - เมื่อ QC พบ material defect ที่ไม่สามารถ rework ได้ → ต้อง scrap
3. **QC Fail → Supervisor Decision** - เมื่อ supervisor ตัดสินใจ scrap แทนที่จะ rework → ต้อง scrap

### Integration Flow

```
QC Node → QC Fail
    ↓
Check Rework Count
    ↓
┌─────────────────────────┐
│ Rework Count < Limit?   │
└─────────────────────────┘
    │                    │
   YES                  NO
    │                    │
    ↓                    ↓
Send to Rework      →  Scrap Token
    │                    │
    │                    ↓
    │              Create Replacement
    │              (if supervisor approves)
    │                    │
    └────────────────────┘
```

---

## ✅ What Phase 7.5 Already Provides

### 1. Database Schema

**Tables ที่ Phase 7.5 เพิ่ม/แก้ไข:**

#### `flow_token` Table (New Columns)

```sql
-- Columns added by Phase 7.5 migration: 2025_11_scrap_replacement.php
ALTER TABLE flow_token
ADD COLUMN parent_scrapped_token_id INT NULL COMMENT 'Reference to scrapped token (if this is a replacement)',
ADD COLUMN scrap_replacement_mode VARCHAR(50) NULL COMMENT 'manual, auto_start, auto_cut (future use)',
ADD COLUMN scrapped_at DATETIME NULL COMMENT 'When token was scrapped',
ADD COLUMN scrapped_by INT NULL COMMENT 'Who scrapped the token (id_member)',
ADD INDEX idx_parent_scrapped (parent_scrapped_token_id);

-- Foreign Key (optional, if schema supports)
ALTER TABLE flow_token
ADD CONSTRAINT fk_flow_token_parent_scrapped
  FOREIGN KEY (parent_scrapped_token_id)
  REFERENCES flow_token(id_token)
  ON DELETE SET NULL;
```

**Usage:**
- `parent_scrapped_token_id`: ชี้กลับไปยัง token ที่ถูก scrap (ถ้า token นี้เป็น replacement)
- `scrap_replacement_mode`: `'manual'` สำหรับ Phase 7.5 (auto modes จะทำในอนาคต)
- `scrapped_at` / `scrapped_by`: Audit trail สำหรับ scrap action

#### `token_event` Table (New Event Types)

**Event Types ที่ Phase 7.5 เพิ่ม:**

```sql
-- Event types added to token_event.event_type ENUM:
'scrap'              -- Token ถูก scrap
'replacement_created' -- Replacement token ถูกสร้าง (log บน scrapped token)
'replacement_of'     -- Token นี้เป็น replacement ของ scrapped token (log บน replacement token)
```

**Existing Event Types ที่ QC ใช้:**
- `qc_pass` - QC ผ่าน
- `qc_fail` - QC ไม่ผ่าน
- `rework` - ส่งกลับไป rework

### 2. API Endpoints

**File:** `source/dag_token_api.php`

#### Endpoint 1: Scrap Token

**Action:** `scrap` (alias: `token_scrap`)

**Request:**
```json
POST /source/dag_token_api.php?action=scrap
{
  "token_id": 12345,
  "reason": "material_defect" | "max_rework_exceeded" | "other",
  "comment": "สายหนังมีรอยตำหนิจากการฟอก"
}
```

**Response (Success):**
```json
{
  "ok": true,
  "token_id": 12345,
  "status": "scrapped",
  "message": "Token scrapped successfully"
}
```

**Response (Error):**
```json
{
  "ok": false,
  "error": "TOKEN_CANNOT_BE_SCRAPPED_FROM_THIS_STATUS",
  "app_code": "DAG_400_INVALID_STATUS",
  "meta": {
    "current_status": "completed"
  }
}
```

**Error Cases:**
- `TOKEN_NOT_FOUND` - Token ไม่มีในระบบ
- `TOKEN_CANNOT_BE_SCRAPPED_FROM_THIS_STATUS` - Status ไม่ใช่ `active`, `waiting`, หรือ `rework`
- `UNAUTHORIZED` - ไม่มีสิทธิ์ scrap token (ต้องเป็น supervisor/manager/admin)
- `INVALID_SCRAP_REASON` - Reason ไม่ถูกต้อง (ต้องเป็น `material_defect`, `max_rework_exceeded`, หรือ `other`)

**Permissions:**
- Required: `atelier.token.scrap` หรือ role `supervisor`, `manager`, `admin`
- **Operator ไม่สามารถ scrap token ได้** (ต้องเป็น supervisor/manager เท่านั้น)

#### Endpoint 2: Create Replacement Token

**Action:** `create_replacement`

**Request:**
```json
POST /source/dag_token_api.php?action=create_replacement
{
  "scrapped_token_id": 12345,
  "spawn_mode": "from_start" | "from_cut",
  "comment": "QC ตัดสินว่าต้องตัดหนังใหม่"
}
```

**Response (Success):**
```json
{
  "ok": true,
  "replacement_token_id": 56789,
  "scrapped_token_id": 12345,
  "spawn_node": "START",
  "message": "Replacement token created successfully"
}
```

**Response (Error):**
```json
{
  "ok": false,
  "error": "TOKEN_IS_NOT_SCRAPPED",
  "app_code": "DAG_400_NOT_SCRAPPED",
  "meta": {
    "current_status": "active"
  }
}
```

**Error Cases:**
- `SCRAPPED_TOKEN_NOT_FOUND` - Scrapped token ไม่มีในระบบ
- `TOKEN_IS_NOT_SCRAPPED` - Token ยังไม่ถูก scrap
- `REPLACEMENT_ALREADY_EXISTS` - มี replacement token อยู่แล้ว (idempotency check)
- `START_NODE_NOT_FOUND` - ไม่พบ START node ใน graph

**Permissions:**
- Required: `atelier.token.create_replacement` หรือ role `supervisor`, `manager`, `admin`
- **Operator ไม่สามารถ create replacement ได้** (ต้องเป็น supervisor/manager เท่านั้น)

### 3. Event Metadata Structure

#### Scrap Event Metadata

```json
{
  "event_type": "scrap",
  "event_time": "2025-11-14 14:30:00",
  "event_data": {
    "reason": "material_defect",
    "comment": "สายหนังมีรอยตำหนิจากการฟอก",
    "rework_count": 2,
    "limit": 3,
    "scrapped_by": 1,
    "scrapped_at": "2025-11-14 14:30:00"
  }
}
```

**Fields:**
- `reason`: `"material_defect"` | `"max_rework_exceeded"` | `"other"`
- `comment`: Free-form text (optional)
- `rework_count`: จำนวนครั้งที่ rework ก่อน scrap (optional)
- `limit`: Rework limit ที่ตั้งไว้ (optional)
- `scrapped_by`: `id_member` ของผู้ scrap
- `scrapped_at`: Timestamp เมื่อ scrap

#### Replacement Created Event Metadata

```json
{
  "event_type": "replacement_created",
  "event_time": "2025-11-14 14:35:00",
  "event_data": {
    "replacement_token_id": 56789,
    "spawn_mode": "from_start",
    "created_by": 1,
    "comment": "QC ตัดสินว่าต้องตัดหนังใหม่"
  }
}
```

**Fields:**
- `replacement_token_id`: ID ของ replacement token ที่สร้างขึ้น
- `spawn_mode`: `"from_start"` | `"from_cut"`
- `created_by`: `id_member` ของผู้สร้าง replacement
- `comment`: Free-form text (optional)

#### Replacement Of Event Metadata

```json
{
  "event_type": "replacement_of",
  "event_time": "2025-11-14 14:35:00",
  "event_data": {
    "scrapped_token_id": 12345,
    "spawn_mode": "from_start",
    "created_by": 1,
    "comment": "QC ตัดสินว่าต้องตัดหนังใหม่"
  }
}
```

**Fields:**
- `scrapped_token_id`: ID ของ scrapped token ที่ถูกแทนที่
- `spawn_mode`: `"from_start"` | `"from_cut"`
- `created_by`: `id_member` ของผู้สร้าง replacement
- `comment`: Free-form text (optional)

---

## 🗄️ Database Schema Reference

### Query Examples

#### 1. Check if Token is Scrapped

```sql
SELECT 
    id_token,
    status,
    scrapped_at,
    scrapped_by,
    parent_scrapped_token_id,
    scrap_replacement_mode
FROM flow_token
WHERE id_token = ?
```

**Expected Results:**
- `status = 'scrapped'` → Token ถูก scrap แล้ว
- `scrapped_at IS NOT NULL` → มี timestamp เมื่อ scrap
- `parent_scrapped_token_id IS NOT NULL` → Token นี้เป็น replacement ของ scrapped token

#### 2. Get Scrap Event for Token

```sql
SELECT 
    event_type,
    event_time,
    event_data,
    created_by
FROM token_event
WHERE id_token = ?
  AND event_type = 'scrap'
ORDER BY event_time DESC
LIMIT 1
```

#### 3. Check if Replacement Exists

```sql
SELECT 
    id_token,
    serial_number,
    status,
    scrap_replacement_mode
FROM flow_token
WHERE parent_scrapped_token_id = ?
LIMIT 1
```

#### 4. Get Replacement Chain (for Traceability)

```sql
-- Get all replacements for a scrapped token
SELECT 
    t.id_token,
    t.serial_number,
    t.status,
    t.scrap_replacement_mode,
    t.scrapped_at,
    t.scrapped_by
FROM flow_token t
WHERE t.parent_scrapped_token_id = ?
ORDER BY t.scrapped_at ASC
```

#### 5. Get Scrap History for Token

```sql
SELECT 
    e.event_type,
    e.event_time,
    e.event_data,
    e.created_by
FROM token_event e
WHERE e.id_token = ?
  AND e.event_type IN ('scrap', 'replacement_created', 'replacement_of')
ORDER BY e.event_time ASC
```

---

## 🔌 API Endpoints Available

### Complete API Reference

**Base URL:** `source/dag_token_api.php`

#### 1. Scrap Token

**Method:** `POST`  
**Action:** `scrap` หรือ `token_scrap`

**Request Body:**
```php
$_POST = [
    'token_id' => 12345,           // Required: int
    'reason' => 'material_defect', // Required: 'material_defect' | 'max_rework_exceeded' | 'other'
    'comment' => '...'             // Optional: string
];
$_REQUEST['action'] = 'scrap';
```

**Response (Success):**
```php
[
    'ok' => true,
    'token_id' => 12345,
    'status' => 'scrapped',
    'message' => 'Token scrapped successfully'
]
```

**Response (Error):**
```php
[
    'ok' => false,
    'error' => 'TOKEN_CANNOT_BE_SCRAPPED_FROM_THIS_STATUS',
    'app_code' => 'DAG_400_INVALID_STATUS',
    'meta' => [
        'current_status' => 'completed'
    ]
]
```

**Idempotency:**
- ถ้าเรียก scrap token ที่ถูก scrap แล้ว → จะ return success (idempotent)
- Token status จะไม่เปลี่ยน (ยังคง `'scrapped'`)

#### 2. Create Replacement Token

**Method:** `POST`  
**Action:** `create_replacement`

**Request Body:**
```php
$_POST = [
    'scrapped_token_id' => 12345,  // Required: int
    'spawn_mode' => 'from_start',  // Required: 'from_start' | 'from_cut'
    'comment' => '...'             // Optional: string
];
$_REQUEST['action'] = 'create_replacement';
```

**Response (Success):**
```php
[
    'ok' => true,
    'replacement_token_id' => 56789,
    'scrapped_token_id' => 12345,
    'spawn_node' => 'START',
    'message' => 'Replacement token created successfully'
]
```

**Response (Error):**
```php
[
    'ok' => false,
    'error' => 'REPLACEMENT_ALREADY_EXISTS',
    'app_code' => 'DAG_400_DUPLICATE',
    'meta' => [
        'replacement_token_id' => 56789
    ]
]
```

**Idempotency:**
- ถ้าเรียก create replacement สำหรับ scrapped token ที่มี replacement อยู่แล้ว → จะ return error `REPLACEMENT_ALREADY_EXISTS`
- **ไม่สามารถสร้าง replacement ซ้ำได้** (ต้อง delete replacement token เดิมก่อน)

---

## 📊 Event Types & Metadata

### Event Flow Diagram

```
QC Fail
    ↓
[Check Rework Count]
    ↓
┌─────────────────────────┐
│ Count >= Limit?         │
└─────────────────────────┘
    │                    │
   NO                   YES
    │                    │
    ↓                    ↓
[Create rework event]  [Create scrap event]
    │                    │
    ↓                    ↓
[Route to rework]     [Update token status]
    │                    │
    │                    ↓
    │              [Token status = 'scrapped']
    │                    │
    │                    ↓
    │              [Create replacement?]
    │                    │
    │                    ↓
    │              [Create replacement_created event]
    │                    │
    │                    ↓
    │              [Create replacement_of event]
    │                    │
    └────────────────────┘
```

### Event Sequence Example

**Scenario:** Token fail QC → Rework limit reached → Scrap → Create Replacement

```
1. Token enters QC node
   → token_event(type='enter', node_id=QC_NODE_ID)

2. QC inspection fails
   → token_event(type='qc_fail', metadata={defect_type: 'stitch_loose'})

3. Check rework count (count=3, limit=3)
   → Decision: Scrap (not rework)

4. Scrap token
   → token_event(type='scrap', metadata={
       reason: 'max_rework_exceeded',
       rework_count: 3,
       limit: 3
     })
   → flow_token.status = 'scrapped'
   → flow_token.scrapped_at = NOW()
   → flow_token.scrapped_by = supervisor_id

5. Supervisor creates replacement
   → token_event(type='replacement_created', metadata={
       replacement_token_id: 56789,
       spawn_mode: 'from_start'
     }) [on scrapped token]
   → token_event(type='replacement_of', metadata={
       scrapped_token_id: 12345,
       spawn_mode: 'from_start'
     }) [on replacement token]
   → flow_token.parent_scrapped_token_id = 12345
   → flow_token.scrap_replacement_mode = 'manual'
```

---

## 🔄 QC → Scrap Flow Integration

### Integration Points

#### Point 1: QC Fail Handler

**Location:** QC System → After QC fail event created

**Logic:**
```php
// After creating qc_fail event
$qcFailEvent = createTokenEvent($tokenId, 'qc_fail', [
    'defect_type' => $defectType,
    'severity' => $severity,
    'inspector' => $inspectorId
]);

// Check rework count
$reworkCount = getReworkCount($tokenId);
$reworkLimit = getReworkLimit($tokenId); // From QC node config or token

if ($reworkCount >= $reworkLimit) {
    // Rework limit reached → Scrap token
    // ⚠️ IMPORTANT: Only supervisor/manager can scrap
    if (hasPermission('atelier.token.scrap') || isSupervisor()) {
        scrapToken($tokenId, 'max_rework_exceeded', 
            "Rework limit reached: {$reworkCount}/{$reworkLimit}");
    } else {
        // Notify supervisor
        notifySupervisor($tokenId, 'rework_limit_reached');
    }
} else {
    // Can still rework → Route to rework node
    routeToReworkNode($tokenId);
}
```

#### Point 2: Material Defect Detection

**Location:** QC System → When material defect detected

**Logic:**
```php
// When QC detects material defect
if ($defectType === 'material_defect' && $severity === 'critical') {
    // Material defect → Cannot rework → Scrap immediately
    // ⚠️ IMPORTANT: Only supervisor/manager can scrap
    if (hasPermission('atelier.token.scrap') || isSupervisor()) {
        scrapToken($tokenId, 'material_defect', 
            "Material defect detected: {$defectDescription}");
    } else {
        // Notify supervisor
        notifySupervisor($tokenId, 'material_defect_detected', [
            'defect_description' => $defectDescription
        ]);
    }
}
```

#### Point 3: Supervisor Decision (Manual Scrap)

**Location:** QC System → UI → Supervisor clicks "Scrap" button

**Logic:**
```javascript
// In QC Result View
function handleScrapDecision(tokenId, reason, comment) {
    $.post('source/dag_token_api.php', {
        action: 'scrap',
        token_id: tokenId,
        reason: reason, // 'material_defect' | 'max_rework_exceeded' | 'other'
        comment: comment
    }, function(resp) {
        if (resp.ok) {
            notifySuccess('Token scrapped successfully');
            // Show "Create Replacement" button
            showCreateReplacementButton(tokenId);
        } else {
            notifyError(resp.error || 'Failed to scrap token');
        }
    }, 'json');
}
```

#### Point 4: Replacement Creation (After Scrap)

**Location:** QC System → UI → Supervisor clicks "Create Replacement" button

**Logic:**
```javascript
// In Token Detail View (after scrap)
function handleCreateReplacement(scrappedTokenId, spawnMode, comment) {
    $.post('source/dag_token_api.php', {
        action: 'create_replacement',
        scrapped_token_id: scrappedTokenId,
        spawn_mode: spawnMode, // 'from_start' | 'from_cut'
        comment: comment
    }, function(resp) {
        if (resp.ok) {
            notifySuccess('Replacement token created successfully');
            // Redirect to replacement token detail
            window.location.href = '?p=token_detail&token_id=' + resp.replacement_token_id;
        } else {
            notifyError(resp.error || 'Failed to create replacement token');
        }
    }, 'json');
}
```

---

## 💻 Code Examples

### Example 1: QC Fail → Check Rework Limit → Scrap

**File:** `source/qc_api.php` (QC System - to be created)

```php
<?php
require_once __DIR__ . '/global_function.php';
require_once __DIR__ . '/dag_token_api.php'; // For scrapToken function

/**
 * Handle QC fail result
 * 
 * @param mysqli $db
 * @param int $tokenId
 * @param string $defectType
 * @param string $severity
 * @param int $inspectorId
 * @return array
 */
function handleQCFail($db, $tokenId, $defectType, $severity, $inspectorId) {
    // 1. Create QC fail event
    $qcFailEvent = createTokenEvent($db, $tokenId, 'qc_fail', [
        'defect_type' => $defectType,
        'severity' => $severity,
        'inspector' => $inspectorId,
        'qc_time' => date('Y-m-d H:i:s')
    ]);
    
    // 2. Get rework count and limit
    $token = $db->fetchOne(
        "SELECT rework_count, rework_limit FROM flow_token WHERE id_token = ?",
        [$tokenId],
        'i'
    );
    
    $reworkCount = (int)($token['rework_count'] ?? 0);
    $reworkLimit = (int)($token['rework_limit'] ?? 3); // Default: 3
    
    // 3. Check if rework limit reached
    if ($reworkCount >= $reworkLimit) {
        // Rework limit reached → Scrap token
        // ⚠️ IMPORTANT: Only supervisor/manager can scrap
        $member = $objMemberDetail->thisLogin();
        if (!$member) {
            return [
                'ok' => false,
                'error' => 'UNAUTHORIZED',
                'message' => 'Must be logged in to scrap token'
            ];
        }
        
        // Check permission
        $canScrap = hasPermission('atelier.token.scrap') || 
                    in_array($member['role'], ['supervisor', 'manager', 'admin']);
        
        if (!$canScrap) {
            // Notify supervisor
            notifySupervisor($db, $tokenId, 'rework_limit_reached', [
                'rework_count' => $reworkCount,
                'limit' => $reworkLimit
            ]);
            
            return [
                'ok' => false,
                'error' => 'REWORK_LIMIT_REACHED',
                'message' => 'Rework limit reached. Supervisor will be notified.',
                'requires_supervisor' => true
            ];
        }
        
        // Scrap token
        return handleTokenScrap($db, [
            'token_id' => $tokenId,
            'reason' => 'max_rework_exceeded',
            'comment' => "Rework limit reached: {$reworkCount}/{$reworkLimit}"
        ]);
    } else {
        // Can still rework → Route to rework node
        return routeToReworkNode($db, $tokenId, $defectType);
    }
}

/**
 * Check if user has permission
 * 
 * @param string $permissionCode
 * @return bool
 */
function hasPermission($permissionCode) {
    // Use existing permission system
    try {
        must_allow($permissionCode);
        return true;
    } catch (\Exception $e) {
        return false;
    }
}

/**
 * Notify supervisor about token issue
 * 
 * @param mysqli $db
 * @param int $tokenId
 * @param string $issueType
 * @param array $metadata
 * @return void
 */
function notifySupervisor($db, $tokenId, $issueType, $metadata = []) {
    // TODO: Implement notification system
    // For now, create a notification record or send email
    error_log("Supervisor notification: Token {$tokenId} - {$issueType}");
}
```

### Example 2: Material Defect → Immediate Scrap

**File:** `source/qc_api.php` (QC System - to be created)

```php
/**
 * Handle material defect detection
 * 
 * @param mysqli $db
 * @param int $tokenId
 * @param string $defectDescription
 * @param int $inspectorId
 * @return array
 */
function handleMaterialDefect($db, $tokenId, $defectDescription, $inspectorId) {
    // 1. Create QC fail event with material defect flag
    $qcFailEvent = createTokenEvent($db, $tokenId, 'qc_fail', [
        'defect_type' => 'material_defect',
        'severity' => 'critical',
        'inspector' => $inspectorId,
        'defect_description' => $defectDescription,
        'qc_time' => date('Y-m-d H:i:s')
    ]);
    
    // 2. Check permission (only supervisor/manager can scrap)
    $member = $objMemberDetail->thisLogin();
    if (!$member) {
        return [
            'ok' => false,
            'error' => 'UNAUTHORIZED',
            'message' => 'Must be logged in to scrap token'
        ];
    }
    
    $canScrap = hasPermission('atelier.token.scrap') || 
                in_array($member['role'], ['supervisor', 'manager', 'admin']);
    
    if (!$canScrap) {
        // Notify supervisor
        notifySupervisor($db, $tokenId, 'material_defect_detected', [
            'defect_description' => $defectDescription
        ]);
        
        return [
            'ok' => false,
            'error' => 'MATERIAL_DEFECT_DETECTED',
            'message' => 'Material defect detected. Supervisor will be notified.',
            'requires_supervisor' => true
        ];
    }
    
    // 3. Scrap token immediately
    return handleTokenScrap($db, [
        'token_id' => $tokenId,
        'reason' => 'material_defect',
        'comment' => "Material defect: {$defectDescription}"
    ]);
}
```

### Example 3: QC UI - Scrap Button Integration

**File:** `views/qc_result.php` (QC System - to be created)

```php
<?php
// In QC Result View
$token = getTokenDetails($tokenId);
$reworkCount = $token['rework_count'] ?? 0;
$reworkLimit = $token['rework_limit'] ?? 3;
$canRework = $reworkCount < $reworkLimit;
$isSupervisor = hasPermission('atelier.token.scrap') || 
                in_array($_SESSION['member']['role'], ['supervisor', 'manager', 'admin']);
?>

<!-- QC Result Display -->
<div class="qc-result">
    <h3>QC Result: <?= htmlspecialchars($token['serial_number']) ?></h3>
    
    <?php if ($qcResult === 'fail'): ?>
        <div class="alert alert-danger">
            <strong>QC Failed</strong>
            <p>Defect Type: <?= htmlspecialchars($defectType) ?></p>
            <p>Severity: <?= htmlspecialchars($severity) ?></p>
        </div>
        
        <!-- Rework Count Display -->
        <div class="rework-info">
            <p>Rework Count: <?= $reworkCount ?> / <?= $reworkLimit ?></p>
            <?php if (!$canRework): ?>
                <div class="alert alert-warning">
                    <strong>Rework Limit Reached</strong>
                    <p>This token cannot be reworked anymore.</p>
                </div>
            <?php endif; ?>
        </div>
        
        <!-- Action Buttons -->
        <div class="qc-actions">
            <?php if ($canRework): ?>
                <!-- Can still rework -->
                <button class="btn btn-warning" onclick="routeToRework(<?= $tokenId ?>)">
                    🔄 Send to Rework
                </button>
            <?php endif; ?>
            
            <?php if ($isSupervisor): ?>
                <!-- Supervisor can scrap -->
                <button class="btn btn-danger" onclick="showScrapDialog(<?= $tokenId ?>)">
                    🗑️ Scrap Token
                </button>
            <?php else: ?>
                <!-- Not supervisor → Notify supervisor -->
                <button class="btn btn-secondary" onclick="notifySupervisor(<?= $tokenId ?>)">
                    📧 Notify Supervisor
                </button>
            <?php endif; ?>
        </div>
    <?php endif; ?>
</div>

<script>
// Scrap Token Dialog
function showScrapDialog(tokenId) {
    Swal.fire({
        title: 'Scrap Token',
        html: `
            <div class="mb-3">
                <label class="form-label">Reason</label>
                <select class="form-select" id="scrap-reason">
                    <option value="max_rework_exceeded">Max Rework Exceeded</option>
                    <option value="material_defect">Material Defect</option>
                    <option value="other">Other</option>
                </select>
            </div>
            <div class="mb-3">
                <label class="form-label">Comment</label>
                <textarea class="form-control" id="scrap-comment" rows="3"></textarea>
            </div>
        `,
        showCancelButton: true,
        confirmButtonText: 'Scrap',
        confirmButtonColor: '#dc3545',
        cancelButtonText: 'Cancel'
    }).then((result) => {
        if (result.isConfirmed) {
            const reason = document.getElementById('scrap-reason').value;
            const comment = document.getElementById('scrap-comment').value;
            
            scrapToken(tokenId, reason, comment);
        }
    });
}

// Scrap Token API Call
function scrapToken(tokenId, reason, comment) {
    $.post('source/dag_token_api.php', {
        action: 'scrap',
        token_id: tokenId,
        reason: reason,
        comment: comment
    }, function(resp) {
        if (resp.ok) {
            notifySuccess('Token scrapped successfully');
            // Show "Create Replacement" button
            showCreateReplacementButton(tokenId);
        } else {
            notifyError(resp.error || 'Failed to scrap token');
        }
    }, 'json');
}

// Show Create Replacement Button
function showCreateReplacementButton(scrappedTokenId) {
    Swal.fire({
        title: 'Token Scrapped',
        text: 'Do you want to create a replacement token?',
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Create Replacement',
        cancelButtonText: 'Later'
    }).then((result) => {
        if (result.isConfirmed) {
            showCreateReplacementDialog(scrappedTokenId);
        }
    });
}

// Create Replacement Dialog
function showCreateReplacementDialog(scrappedTokenId) {
    Swal.fire({
        title: 'Create Replacement Token',
        html: `
            <div class="mb-3">
                <label class="form-label">Spawn Mode</label>
                <select class="form-select" id="spawn-mode">
                    <option value="from_start">From START (Remake entire piece)</option>
                    <option value="from_cut">From CUT (Recut material only)</option>
                </select>
            </div>
            <div class="mb-3">
                <label class="form-label">Comment</label>
                <textarea class="form-control" id="replacement-comment" rows="3"></textarea>
            </div>
        `,
        showCancelButton: true,
        confirmButtonText: 'Create',
        confirmButtonColor: '#0dcaf0',
        cancelButtonText: 'Cancel'
    }).then((result) => {
        if (result.isConfirmed) {
            const spawnMode = document.getElementById('spawn-mode').value;
            const comment = document.getElementById('replacement-comment').value;
            
            createReplacementToken(scrappedTokenId, spawnMode, comment);
        }
    });
}

// Create Replacement API Call
function createReplacementToken(scrappedTokenId, spawnMode, comment) {
    $.post('source/dag_token_api.php', {
        action: 'create_replacement',
        scrapped_token_id: scrappedTokenId,
        spawn_mode: spawnMode,
        comment: comment
    }, function(resp) {
        if (resp.ok) {
            notifySuccess('Replacement token created successfully');
            // Redirect to replacement token detail
            window.location.href = '?p=token_detail&token_id=' + resp.replacement_token_id;
        } else {
            notifyError(resp.error || 'Failed to create replacement token');
        }
    }, 'json');
}
</script>
```

---

## 🎯 Integration Points

### Critical Integration Points

#### 1. QC Fail → Rework Limit Check

**When:** After QC fail event created  
**What:** Check if rework count >= limit  
**Action:** If yes → Scrap token (if supervisor) or notify supervisor

**Code Location:** `source/qc_api.php` → `handleQCFail()`

#### 2. Material Defect Detection

**When:** QC detects material defect  
**What:** Immediately scrap token (if supervisor) or notify supervisor  
**Action:** Scrap with reason `'material_defect'`

**Code Location:** `source/qc_api.php` → `handleMaterialDefect()`

#### 3. Supervisor Manual Scrap Decision

**When:** Supervisor clicks "Scrap" button in QC Result View  
**What:** Call scrap API endpoint  
**Action:** Scrap token → Show "Create Replacement" button

**Code Location:** `views/qc_result.php` → `showScrapDialog()`

#### 4. Replacement Creation

**When:** Supervisor clicks "Create Replacement" button  
**What:** Call create replacement API endpoint  
**Action:** Create replacement token → Redirect to replacement token detail

**Code Location:** `views/qc_result.php` → `showCreateReplacementDialog()`

---

## ✅ Best Practices

### 1. Permission Checks

**Always check permissions before scrap:**

```php
// ✅ CORRECT
$canScrap = hasPermission('atelier.token.scrap') || 
            in_array($member['role'], ['supervisor', 'manager', 'admin']);
if (!$canScrap) {
    notifySupervisor($tokenId, 'scrap_required');
    return ['ok' => false, 'error' => 'REQUIRES_SUPERVISOR'];
}

// ❌ WRONG
// Don't allow operator to scrap directly
```

### 2. Idempotency

**Scrap API is idempotent:**

```php
// ✅ CORRECT
// Calling scrap twice on same token → Returns success (idempotent)
scrapToken($tokenId, 'material_defect', 'comment');
scrapToken($tokenId, 'material_defect', 'comment'); // Returns success

// ❌ WRONG
// Don't check if already scrapped before calling API
// Let API handle idempotency
```

### 3. Replacement Creation

**Check if replacement already exists:**

```php
// ✅ CORRECT
// API will return REPLACEMENT_ALREADY_EXISTS if replacement exists
$result = createReplacementToken($scrappedTokenId, 'from_start', 'comment');
if (!$result['ok'] && $result['error'] === 'REPLACEMENT_ALREADY_EXISTS') {
    // Show existing replacement link
    showExistingReplacement($result['meta']['replacement_token_id']);
}

// ❌ WRONG
// Don't create replacement without checking
```

### 4. Event Logging

**Always log events in correct order:**

```php
// ✅ CORRECT Order:
// 1. QC fail event
createTokenEvent($tokenId, 'qc_fail', [...]);
// 2. Scrap event
createTokenEvent($tokenId, 'scrap', [...]);
// 3. Replacement created event (on scrapped token)
createTokenEvent($scrappedTokenId, 'replacement_created', [...]);
// 4. Replacement of event (on replacement token)
createTokenEvent($replacementTokenId, 'replacement_of', [...]);

// ❌ WRONG
// Don't skip events or log in wrong order
```

### 5. Serial Number Policy

**Phase 7.5: Always reuse original serial:**

```php
// ✅ CORRECT (Phase 7.5)
// Replacement token uses same serial as scrapped token
$replacementSerial = $scrappedToken['serial_number']; // Reuse

// ❌ WRONG (Phase 7.5)
// Don't generate new serial
$replacementSerial = generateNewSerial(); // Wrong for Phase 7.5
```

---

## 🧪 Testing Checklist

### Unit Tests

- [ ] `handleQCFail()` - Rework count < limit → Route to rework
- [ ] `handleQCFail()` - Rework count >= limit → Scrap token (if supervisor)
- [ ] `handleQCFail()` - Rework count >= limit → Notify supervisor (if not supervisor)
- [ ] `handleMaterialDefect()` - Material defect → Scrap immediately (if supervisor)
- [ ] `handleMaterialDefect()` - Material defect → Notify supervisor (if not supervisor)
- [ ] Permission check - Operator cannot scrap token
- [ ] Permission check - Supervisor can scrap token
- [ ] Idempotency - Scrap token twice → Returns success

### Integration Tests

- [ ] QC fail → Rework count < limit → Token routed to rework node
- [ ] QC fail → Rework count >= limit → Token scrapped (if supervisor)
- [ ] QC fail → Rework count >= limit → Supervisor notified (if not supervisor)
- [ ] Material defect → Token scrapped immediately (if supervisor)
- [ ] Material defect → Supervisor notified (if not supervisor)
- [ ] Scrap token → Replacement created → Events logged correctly
- [ ] Scrap token → Replacement created → Serial number reused

### Manual Tests

- [ ] QC Result View - Scrap button appears (if supervisor)
- [ ] QC Result View - Scrap button hidden (if operator)
- [ ] Scrap dialog - Reason selection works
- [ ] Scrap dialog - Comment field works
- [ ] Create Replacement dialog - Spawn mode selection works
- [ ] Create Replacement dialog - Comment field works
- [ ] Token Detail View - Shows scrap status
- [ ] Token Detail View - Shows replacement link
- [ ] Token Detail View - Shows replacement of link

---

## 📚 Related Documentation

### Phase 7.5 Specification

- **File:** `docs/dag/02-implementation-status/PHASE_7_5_MANUAL_SCRAP_REPLACEMENT_SPEC.md`
- **Purpose:** Complete specification for Phase 7.5 implementation
- **Contains:** Database schema, API endpoints, UI requirements, testing checklist

### DAG Runtime Flow

- **File:** `docs/dag/01-core/BELLAVIER_DAG_RUNTIME_FLOW.md`
- **Purpose:** Complete DAG runtime flow documentation
- **Contains:** Token lifecycle, event types, QC flow, rework flow

### QC vs Decision Nodes

- **File:** `docs/analysis/QC_VS_DECISION_NODES.md`
- **Purpose:** Comparison between QC and Decision nodes
- **Contains:** When to use QC node, edge types, validation rules

### Database Schema Reference

- **File:** `docs/database/01-schema/DATABASE_SCHEMA_REFERENCE.md`
- **Purpose:** Complete database schema reference
- **Contains:** Table structures, indexes, relationships

### API Reference

- **File:** `docs/api/01-reference/SERVICE_API_REFERENCE.md`
- **Purpose:** Complete API reference
- **Contains:** Endpoint documentation, request/response formats, error codes

---

## 🚀 Next Steps for QC System Development

### Phase 1: Basic QC Integration

1. **Create QC API Endpoint**
   - File: `source/qc_api.php`
   - Functions: `handleQCFail()`, `handleMaterialDefect()`
   - Integration: Call Phase 7.5 scrap API when needed

2. **Create QC Result View**
   - File: `views/qc_result.php`
   - UI: Show QC result, rework count, scrap button (if supervisor)
   - Integration: Call Phase 7.5 scrap API, show replacement button

3. **Add Permission Checks**
   - Check `atelier.token.scrap` permission
   - Fallback to role check (`supervisor`, `manager`, `admin`)

### Phase 2: Advanced QC Features

1. **Rework Limit Configuration**
   - Allow QC node to set rework limit per node
   - Store in `routing_node.qc_policy.rework_limit`

2. **Material Defect Detection**
   - Add material defect flag to QC fail event
   - Auto-scrap if material defect detected (if supervisor)

3. **Supervisor Notifications**
   - Notify supervisor when rework limit reached
   - Notify supervisor when material defect detected

### Phase 3: QC Analytics

1. **Scrap Rate Tracking**
   - Track scrap rate per QC node
   - Track scrap reasons (material_defect, max_rework_exceeded, other)

2. **Replacement Rate Tracking**
   - Track replacement rate per scrapped token
   - Track spawn mode usage (from_start vs from_cut)

---

## 📝 Summary

### What Phase 7.5 Provides

✅ **Database Schema:**
- `flow_token` columns: `parent_scrapped_token_id`, `scrap_replacement_mode`, `scrapped_at`, `scrapped_by`
- `token_event` types: `scrap`, `replacement_created`, `replacement_of`

✅ **API Endpoints:**
- `POST /source/dag_token_api.php?action=scrap` - Scrap token
- `POST /source/dag_token_api.php?action=create_replacement` - Create replacement token

✅ **Event System:**
- Scrap event with metadata (reason, comment, rework_count, limit)
- Replacement events (replacement_created, replacement_of)

✅ **Permission System:**
- `atelier.token.scrap` permission (supervisor/manager/admin only)
- `atelier.token.create_replacement` permission (supervisor/manager/admin only)

### What QC System Must Do

1. **Check Rework Limit** - After QC fail, check if rework count >= limit
2. **Call Scrap API** - If limit reached or material defect → Call scrap API (if supervisor)
3. **Notify Supervisor** - If not supervisor → Notify supervisor for manual scrap
4. **Show Replacement Button** - After scrap → Show "Create Replacement" button
5. **Call Create Replacement API** - When supervisor clicks → Call create replacement API

### Integration Flow

```
QC Fail
    ↓
Check Rework Count
    ↓
┌─────────────────────────┐
│ Count >= Limit?         │
└─────────────────────────┘
    │                    │
   NO                   YES
    │                    │
    ↓                    ↓
Route to Rework      Check Permission
    │                    │
    │                    ↓
    │              ┌─────────────────┐
    │              │ Is Supervisor?  │
    │              └─────────────────┘
    │                    │        │
    │                   YES      NO
    │                    │        │
    │                    ↓        ↓
    │              Scrap Token  Notify Supervisor
    │                    │
    │                    ↓
    │              Show Replacement Button
    │                    │
    │                    ↓
    │              Create Replacement (if clicked)
    │                    │
    └────────────────────┘
```

---

**Status:** Ready for QC System Development  
**Last Updated:** November 14, 2025  
**Maintained By:** AI Agent (Phase 7.5 Implementation)

