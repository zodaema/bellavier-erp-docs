# Task 27.21.1: Rework Material Reserve Plan

> **Created:** December 7, 2025  
> **Updated:** December 8, 2025  
> **Status:** ✅ **COMPLETE** (All Phases 0-4 Done)  
> **Priority:** HIGH - Critical Business Logic  
> **Estimated Duration:** 5-7 hours  
> **Prerequisites:** 
> - Task 27.21 Phase 0-2 ✅ COMPLETE
> - Task 27.15 (QC Rework V2) ✅ COMPLETE  
> **Phase:** 4 (Logging & Audit) ✅ COMPLETE
> **Risk Level:** 🔴 HIGH - QC Rework + Material Allocation = Factory-critical

---

## 🎯 CONFIRMED POLICY (CTO Approved - Dec 8, 2025)

```
┌──────────────────────────────────────────────────────────────────┐
│               BELLAVIER FINAL POLICY (Hermès-tier)               │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. QC FAIL → Replacement Token ALWAYS created                   │
│     (Never block spawn - needed for traceability)                │
│                                                                  │
│  2. Reserve Materials:                                           │
│     ✅ If sufficient → Reserve full amount                       │
│     ⚠️ If shortage → Reserve partial + Mark shortage             │
│                                                                  │
│  3. Replacement Token with shortage:                             │
│     ❌ BLOCK START WORK (cannot begin until materials ready)     │
│     ✅ Show in work queue with "pending materials" status        │
│     ✅ Notify supervisor immediately                             │
│                                                                  │
│  4. Scrapped Token Materials:                                    │
│     • consumed = 0 → RETURN to stock                             │
│     • consumed > 0 → MARK as waste                               │
│                                                                  │
│  5. Rework Mode Decision:                                        │
│     REPAIR → No new materials needed                             │
│     RECUT  → NEW materials required (this task)                  │
│     SCRAP  → Return/waste per rule #4                            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🔗 Dependencies (All Complete)

| Dependency | Status | Note |
|------------|--------|------|
| Task 27.21 Phase 0 | ✅ DONE | `MaterialRequirementService.getMaterialsForToken()` ready |
| Task 27.21 Phase 1-2 | ✅ DONE | Material reservation/allocation working |
| Task 27.15 (QC Rework V2) | ✅ DONE | Human-judgment QC routing ready |

---

## ⚠️ MANDATORY GUARDRAILS

> **ต้องอ่านและปฏิบัติตามเอกสารต่อไปนี้ก่อนเริ่มงาน:**

### 📘 Required Reading

| Document | Path | Purpose |
|----------|------|---------|
| **Developer Policy** | `docs/developer/01-policy/DEVELOPER_POLICY.md` | กฎหลักการพัฒนา |
| **API Development Guide** | `docs/developer/08-guides/01-api-development.md` | โครงสร้าง API มาตรฐาน |
| **System Wiring Guide** | `docs/developer/SYSTEM_WIRING_GUIDE.md` | การเชื่อมต่อระบบ |

### 🔒 Critical Rules

1. **API Response Format:**
   - ✅ ใช้ `json_success()` / `json_error()` (ไม่ใช่ echo json_encode)
   - ✅ Response: `{"ok": true, ...}` หรือ `{"ok": false, "error": "..."}`

2. **Transaction Safety:**
   - ✅ ใช้ transaction สำหรับ multi-step operations
   - ✅ ใช้ `SELECT ... FOR UPDATE` เมื่อต้อง lock rows

3. **i18n:**
   - ✅ Default = English ในโค้ด
   - ✅ ใช้ `translate()` สำหรับ PHP, `t()` สำหรับ JS
   - ❌ ห้าม hardcode ภาษาไทย

---

## 📌 Executive Summary

เมื่อ Token ถูก QC Fail และต้อง **Recut (ตัดใหม่)** ระบบต้อง:
1. สร้าง Replacement Token ใหม่
2. **จองวัสดุใหม่** สำหรับ Replacement Token
3. ตรวจสอบว่าวัสดุเพียงพอหรือไม่
4. ถ้าไม่พอ → แจ้งเตือน / Block หรือ Queue

---

## 🔍 Scenario Analysis

### Normal Flow (Task 27.21 - ✅ Done)

```
Token A → CUT (consume materials) → STITCH → QC ✅ → Complete
                    ↓
            Materials consumed from reservation
```

### Rework Flow (This Task - 📋 Planned)

```
Token A → CUT → STITCH → QC ❌ FAIL
                          │
                          ▼
              ┌─────────────────────────┐
              │    Rework Decision      │
              │  (by Supervisor/QC)     │
              └───────────┬─────────────┘
                          │
         ┌────────────────┼────────────────┐
         ▼                ▼                ▼
    ┌─────────┐     ┌──────────┐     ┌─────────┐
    │ REPAIR  │     │  RECUT   │     │  SCRAP  │
    │ (ซ่อม)   │     │ (ตัดใหม่)  │     │ (ทิ้ง)   │
    └────┬────┘     └────┬─────┘     └────┬────┘
         │               │                │
         ▼               ▼                ▼
    No new          NEW materials     Return materials
    materials       required!         to available?
    needed          │                 │
                    ▼                 ▼
              ┌─────────────┐   ┌───────────────┐
              │ Reserve     │   │ Update        │
              │ materials   │   │ reservation   │
              │ for Token B │   │ status        │
              └─────────────┘   └───────────────┘
```

---

## 📋 Safe Path Implementation Plan

> **Strategy:** Incremental implementation to minimize QC flow disruption

### Phase 0: Prepare & Test Data (1 hour) ✅ COMPLETE

**Goals:**
- Create test scenarios for QC fail → rework flow
- Verify existing infrastructure works
- Document current state

**Tasks:**
- [x] 0.1 Create test job with material requirements ✅
- [x] 0.2 Test QC fail → spawn replacement token flow ✅
- [x] 0.3 Verify `getMaterialsForToken()` works for replacement tokens ✅
- [x] 0.4 Document current gaps ✅

#### Phase 0 Results (Dec 8, 2025)

**Test Data:**
- Job 827 has material requirements (LEA-NAV-001: 13 sqft reserved)
- Token 1770-1779 ready for testing at "Cut Leather" node
- Product 20 has 3 components: BODY (0.8), FLAP (0.2), STRAP (0.3) = 1.3 sqft/unit

**Verification:**
- `getMaterialsForToken()` works for normal tokens ✅
- `getMaterialsForToken()` works for replacement tokens ✅ (Token 1233)
- `getLeatherMaterialsForToken()` filters correctly ✅

**GAP CONFIRMED:**
```
┌─────────────────────────────────────────────────────────────────┐
│ TokenLifecycleService.php                                       │
├─────────────────────────────────────────────────────────────────┤
│ spawnReplacementToken() (line ~750)                             │
│   - Creates replacement token ✅                                 │
│   - Links to original token ✅                                   │
│   - Creates spawn event ✅                                       │
│   - ❌ NO MATERIAL RESERVATION!                                  │
│                                                                 │
│ spawnReworkToken() (line ~2012)                                 │
│   - Creates rework token ✅                                      │
│   - Sets token_type = 'rework' ✅                                │
│   - ❌ NO MATERIAL RESERVATION!                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Test Scripts Created:**
- `tests/manual/test_material_for_token.php` - Verifies getMaterialsForToken()
- `tests/manual/test_qc_fail_flow.php` - Analyzes QC fail flow

---

### Phase 1: Read-Only Check (2 hours) ✅ COMPLETE

**Goals:**
- Add material availability check before spawn
- Log warnings but DON'T block

**Implementation (Dec 8, 2025):**

**File modified:** `source/BGERP/Service/TokenLifecycleService.php`

**Changes:**
1. Added `checkMaterialAvailabilityForRework()` helper method
2. Added `getAvailableStock()` helper method
3. Hooked check into `spawnReplacementToken()` (line ~769)
4. Hooked check into `spawnReworkToken()` (line ~2037)

**Log format:**
```
[REWORK_MATERIAL_SHORTAGE] Token X (replacement from Y): LEA-NAV-001 needs 1.3000 sqft, available 30.0000
[TokenLifecycleService] Token X (replacement): All 3 materials available
```

**Test scripts created:**
- `tests/manual/test_rework_material_check.php` - Verifies Phase 1 logic

---

### Phase 2: Reservation Hook (3 hours) ✅ COMPLETE

**Goals:**
- Connect spawn → reserve flow
- Implement `reserveForReworkToken()`
- Transaction safety

**Implementation (Dec 8, 2025):**

**File 1:** `source/BGERP/Service/MaterialAllocationService.php`

**New methods added:**
| Method | Purpose |
|--------|---------|
| `reserveForReworkToken()` | Main entry point for rework reservation |
| `handleScrapMaterials()` | Return/waste materials from scrapped token |
| `getAvailableStockBySku()` | Check stock availability |
| `createReworkRequirement()` | Create material_requirement record |
| `createReworkReservation()` | Create material_reservation record |
| `logReworkReservationEvent()` | Audit trail |
| `returnMaterialToStock()` | Return unused materials |
| `markAsWaste()` | Mark consumed materials as waste |

**File 2:** `source/BGERP/Service/TokenLifecycleService.php`

| Method | Change |
|--------|--------|
| `spawnReplacementToken()` | Calls `reserveMaterialsForRework()` |
| `spawnReworkToken()` | Calls `reserveMaterialsForRework()` |
| `reserveMaterialsForRework()` | New - calls `MaterialAllocationService.reserveForReworkToken()` |

**Test script:**
- `tests/manual/test_rework_reservation.php`

---

### Phase 3: Shortage Handling (2 hours) ✅ COMPLETE

**Goals:**
- Block START for tokens with shortage
- Show warning in Work Queue
- Notify supervisor

**Implementation (Dec 8, 2025):**

**File 1:** `source/dag_token_api.php`

| Method | Purpose |
|--------|---------|
| `checkMaterialShortageForToken()` | New - Check if token has shortage |
| `handleStartToken()` | Added shortage check (returns 409 if shortage) |
| `handleGetWorkQueue()` | Added `material_status` to each token |

**File 2:** `assets/javascripts/pwa_scan/work_queue.js`

| Function | Change |
|----------|--------|
| `renderKanbanTokenCard()` | +shortage warning + disabled start button |
| `renderTokenCard()` | +shortage warning + disabled start button |

**UI Changes (implemented):**
- Red alert box: "Material Shortage - Contact supervisor"
- Disabled Start button shows "Blocked" text
- Both Kanban and List views updated

---

### Phase 1 (Original): Service Methods (2-3 hours)

**File:** `source/BGERP/Service/MaterialAllocationService.php`

```php
/**
 * Reserve materials for a rework (recut) token
 * 
 * Called when QC Fail → Recut decision is made.
 * The replacement token needs NEW materials.
 * 
 * @param int $replacementTokenId New token that replaces failed one
 * @param int $originalTokenId Original token that failed QC
 * @param int $jobTicketId Job ticket ID
 * @param int|null $userId User performing action
 * @return array {success, shortage, reserved_materials, message}
 */
public function reserveForReworkToken(
    int $replacementTokenId,
    int $originalTokenId,
    int $jobTicketId,
    ?int $userId = null
): array {
    // 1. Get component_code from replacement token
    $token = $this->getTokenDetails($replacementTokenId);
    $componentCode = $token['component_code'];
    
    if (!$componentCode) {
        return [
            'success' => false,
            'error' => 'Token has no component_code'
        ];
    }
    
    // 2. Get materials for this component via mapping
    $materials = $this->getComponentMaterials($jobTicketId, $componentCode);
    
    if (empty($materials)) {
        return [
            'success' => true,
            'message' => 'No materials defined for this component',
            'reserved_materials' => []
        ];
    }
    
    // 3. Begin transaction
    $this->db->begin_transaction();
    
    try {
        $reservedMaterials = [];
        $shortages = [];
        
        foreach ($materials as $mat) {
            $available = $this->getAvailableForNewJobs($mat['material_sku']);
            $required = (float)$mat['qty_per_component'];
            
            if ($available < $required) {
                $shortages[] = [
                    'material_sku' => $mat['material_sku'],
                    'required' => $required,
                    'available' => $available,
                    'shortage' => $required - $available
                ];
            }
            
            // Reserve what we can (partial if shortage)
            $reserveQty = min($required, $available);
            
            if ($reserveQty > 0) {
                $this->createReworkReservation(
                    $replacementTokenId,
                    $originalTokenId,
                    $jobTicketId,
                    $mat['material_sku'],
                    $reserveQty,
                    $mat['uom_code'],
                    $userId
                );
                
                $reservedMaterials[] = [
                    'material_sku' => $mat['material_sku'],
                    'qty_reserved' => $reserveQty,
                    'uom_code' => $mat['uom_code']
                ];
            }
        }
        
        // 4. Log rework reservation event
        $this->logReworkReservationEvent(
            $jobTicketId,
            $replacementTokenId,
            $originalTokenId,
            $reservedMaterials,
            $shortages,
            $userId
        );
        
        $this->db->commit();
        
        $hasShortage = !empty($shortages);
        
        return [
            'success' => true,
            'has_shortage' => $hasShortage,
            'shortages' => $shortages,
            'reserved_materials' => $reservedMaterials,
            'message' => $hasShortage 
                ? translate('material.rework.partial_reserve', 'Materials partially reserved due to shortage')
                : translate('material.rework.fully_reserved', 'Materials fully reserved for rework')
        ];
        
    } catch (\Throwable $e) {
        $this->db->rollback();
        error_log("[MaterialAllocationService][reserveForReworkToken] Failed: " . $e->getMessage());
        return [
            'success' => false,
            'error' => $e->getMessage()
        ];
    }
}

/**
 * Handle materials when token is scrapped
 * 
 * Options:
 * - Return unused reserved materials
 * - Mark consumed materials as waste
 * 
 * @param int $tokenId Scrapped token ID
 * @param int $userId User performing action
 * @return array Result
 */
public function handleScrapMaterials(int $tokenId, int $userId): array
{
    // Get allocations for this token
    $allocations = $this->getAllocationsForToken($tokenId);
    
    $returned = 0;
    $wasted = 0;
    
    foreach ($allocations as $alloc) {
        if ($alloc['status'] === 'allocated' && (float)$alloc['qty_consumed'] === 0.0) {
            // Not yet consumed - can return
            $this->returnMaterials($tokenId, $userId, 'token_scrapped');
            $returned++;
        } else {
            // Already consumed - mark as waste
            $wasteQty = (float)$alloc['qty_consumed'];
            if ($wasteQty > 0) {
                $this->recordWaste(
                    (int)$alloc['id_allocation'],
                    $wasteQty,
                    'qc_fail_scrap',
                    $userId
                );
                $wasted++;
            }
        }
    }
    
    return [
        'success' => true,
        'returned_count' => $returned,
        'wasted_count' => $wasted
    ];
}
```

### Phase 2: QC Rework Integration (1-2 hours)

**File:** `source/BGERP/Service/QCReworkService.php` (or equivalent)

```php
// Inside handleReworkDecision() or similar:

if ($reworkMode === 'recut') {
    // 1. Spawn replacement token
    $replacementTokenId = $tokenService->spawnReworkToken(
        $originalTokenId,
        $targetNodeId,
        $reason,
        $operatorId
    );
    
    // 2. Task 27.21.1: Reserve materials for replacement
    $materialService = new MaterialAllocationService($this->db);
    $reserveResult = $materialService->reserveForReworkToken(
        $replacementTokenId,
        $originalTokenId,
        $jobTicketId,
        $operatorId
    );
    
    // 3. Handle shortage scenario
    if ($reserveResult['has_shortage']) {
        // Option A: Block rework until materials available
        // Option B: Allow rework but flag for procurement
        // Option C: Notify supervisor
        
        $this->notifyMaterialShortageForRework(
            $jobTicketId,
            $replacementTokenId,
            $reserveResult['shortages']
        );
    }
    
    return [
        'ok' => true,
        'replacement_token_id' => $replacementTokenId,
        'materials_reserved' => !$reserveResult['has_shortage'],
        'shortages' => $reserveResult['shortages'] ?? []
    ];
}

if ($reworkMode === 'scrap') {
    // Handle materials for scrapped token
    $materialService = new MaterialAllocationService($this->db);
    $scrapResult = $materialService->handleScrapMaterials($originalTokenId, $operatorId);
    
    return [
        'ok' => true,
        'scrapped' => true,
        'materials_returned' => $scrapResult['returned_count'],
        'materials_wasted' => $scrapResult['wasted_count']
    ];
}
```

### Phase 3: Database (if needed) (30 min)

```php
// Migration: 2025_12_rework_material_tracking.php

// Add rework reference columns to material_reservation
ALTER TABLE material_reservation 
ADD COLUMN is_rework_reserve TINYINT(1) NOT NULL DEFAULT 0 
COMMENT '1 if reserved for rework token';

ALTER TABLE material_reservation 
ADD COLUMN original_token_id INT NULL 
COMMENT 'Original token ID (for rework reserves)';

// Add index
CREATE INDEX idx_mr_rework ON material_reservation(is_rework_reserve, original_token_id);
```

### Phase 4: Logging & Audit (30 min) ✅ COMPLETE

**Implementation (Dec 9, 2025):**

**File 1:** `database/tenant_migrations/2025_12_rework_material_logging.php`
- Created migration to add event types to `material_requirement_log.event_type` ENUM:
  - `rework_reserve` - For rework material reservation logging
  - `material_returned_scrap` - For materials returned when token scrapped
  - `material_wasted_scrap` - For materials marked as waste when token scrapped

**File 2:** `source/BGERP/Service/MaterialAllocationService.php`
- `logReworkReservationEvent()` - ✅ Already implemented (line 1208)
  - Uses `event_type = 'rework_reserve'`
  - Logs replacement token ID, original token ID, reserved materials, and shortages
- `returnMaterialToStock()` - ✅ Already implemented (line 1240)
  - Uses `event_type = 'material_returned_scrap'`
  - Logs reason in details JSON
- `markAsWaste()` - ✅ Already implemented (line 1279)
  - Uses `event_type = 'material_wasted_scrap'`
  - Logs reason in details JSON

**File 3:** `source/dag_token_api.php`
- Integrated `handleScrapMaterials()` into `handleTokenScrap()` (line ~1179)
- Called after token status update and event creation
- Handles materials before transaction commit
- Logs result but doesn't fail scrap operation if material handling fails

**Logging Format:**
```php
// Rework reservation
INSERT INTO material_requirement_log 
(id_job_ticket, event_type, details, created_by)
VALUES (?, 'rework_reserve', ?, ?)
// details: {
//   "replacement_token_id": 1234,
//   "original_token_id": 1233,
//   "reserved_materials": [...],
//   "shortages": [...],
//   "event": "rework_material_reserve"
// }

// Material returned (scrap)
INSERT INTO material_requirement_log 
(id_job_ticket, event_type, material_sku, qty, details, created_by)
VALUES (?, 'material_returned_scrap', ?, ?, ?, ?)
// details: {"reason": "token_scrapped"}

// Material wasted (scrap)
INSERT INTO material_requirement_log 
(id_job_ticket, event_type, material_sku, qty, details, created_by)
VALUES (?, 'material_wasted_scrap', ?, ?, ?, ?)
// details: {"reason": "qc_fail_scrap"}
```

**Test Script:**
- Migration can be tested by running: `php source/bootstrap_migrations.php --tenant=xxx`
- Verify ENUM values: `SHOW COLUMNS FROM material_requirement_log WHERE Field = 'event_type'`

---

## 📊 Decision Matrix: Shortage Handling

| Scenario | Action | User Experience |
|----------|--------|-----------------|
| **Full Reserve** | Proceed normally | ✅ Green status |
| **Partial Reserve** | Reserve what's available, flag shortage | ⚠️ Yellow warning |
| **Zero Available** | Block rework OR queue for later | 🔴 Red alert + options |

### Recommended Policy

```
┌─────────────────────────────────────────────────────────────────┐
│  REWORK MATERIAL POLICY                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  IF materials_available >= required:                            │
│     → Reserve all, proceed with rework                         │
│                                                                 │
│  ELSE IF materials_available > 0:                               │
│     → Reserve partial                                          │
│     → Alert supervisor: "วัสดุไม่เพียงพอ กรุณาเติม"               │
│     → Allow rework to start (can complete later)               │
│                                                                 │
│  ELSE (materials_available = 0):                                │
│     → Show modal: "ไม่มีวัสดุ ต้องการ Scrap แทนหรือไม่?"          │
│     → Options: [Queue for Later] [Scrap Token]                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## ✅ Testing Checklist

- [ ] QC Fail → Recut with sufficient materials → Reserve success
- [ ] QC Fail → Recut with partial materials → Reserve partial + warning
- [ ] QC Fail → Recut with zero materials → Block/queue option
- [ ] QC Fail → Scrap → Unused materials returned
- [ ] QC Fail → Scrap → Consumed materials marked as waste
- [ ] Concurrent rework requests → No double-reserve
- [ ] Rework log shows all reservations correctly

---

## 📁 Files to Modify

| File | Changes |
|------|---------|
| `MaterialAllocationService.php` | Add `reserveForReworkToken()`, `handleScrapMaterials()` |
| `QCReworkService.php` | Call material reserve on recut decision |
| `qc_rework_v2.js` | Show material status in rework modal |
| `material_requirement_api.php` | Add `reserve_for_rework` endpoint (optional) |

---

## 🔗 Related Documents

- [task27.21_MATERIAL_INTEGRATION_PLAN.md](./task27.21_MATERIAL_INTEGRATION_PLAN.md) - Parent task
- [task27.15_QC_REWORK_V2_PLAN.md](./task27.15_QC_REWORK_V2_PLAN.md) - QC Rework integration
- [SYSTEM_WIRING_GUIDE.md](../../developer/SYSTEM_WIRING_GUIDE.md) - Integration rules

---

## ⏱️ Estimated Timeline

| Phase | Description | Hours |
|-------|-------------|-------|
| 1 | Service Methods | 2-3h |
| 2 | QC Rework Integration | 1-2h |
| 3 | Database Migration | 0.5h |
| 4 | Logging & Audit | 0.5h |
| 5 | Testing | 1h |
| **Total** | | **5-7h** |

---

> **"ของเสียเกิดขึ้นได้ แต่ระบบต้องจัดการได้อย่างมีระเบียบ"**

