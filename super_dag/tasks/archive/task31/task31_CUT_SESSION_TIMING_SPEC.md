# Task 31: CUT Session Timing System (First-Class Record)

**Date:** January 2026  
**Status:** 📋 **DESIGN PHASE**  
**Priority:** 🔴 **CRITICAL**

---

## 🎯 Executive Summary

**Problem:** ตอนนี้ CUT timing มี 2 world ที่ชนกัน:
1. **Legacy timing (SSOT เดิม):** จับเวลา "รวมทั้งงาน/ทั้งโหนด" แล้วเฉลี่ย → หยาบ แต่เป็นตัวหลัก
2. **Start Cutting timer (ใหม่):** UI timer ใน Phase 2 → หลอก (refresh หาย, ปลอมได้, ไม่มี audit)

**Solution:** ยกระดับ timing ให้เป็น **CUT_SESSION** ที่เป็น first-class record แล้ว roll-up ไปหา Legacy SSOT

**Goal:** Component-level timing ที่เป็น "Hermès-grade traceability" - ตอบได้ว่า "ช่าง A ใช้เวลาตัด component X (MAIN+sku123) รวม 27:40 นาที (3 sessions)"

---

## 📊 Data Model Design

### CUT_SESSION Table Schema

```sql
CREATE TABLE cut_session (
    id_session INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    
    -- Identity (REQUIRED - hard validation)
    token_id INT(11) NOT NULL COMMENT 'FK to flow_token.id_token (parent batch token)',
    node_id INT(11) NOT NULL COMMENT 'FK to routing_node.id_node (CUT node)',
    component_code VARCHAR(50) NOT NULL COMMENT 'Component being cut (e.g., BODY)',
    role_code VARCHAR(50) NOT NULL COMMENT 'Material role (e.g., MAIN_MATERIAL)',
    material_sku VARCHAR(100) NOT NULL COMMENT 'Material SKU being used',
    operator_id INT(11) NOT NULL COMMENT 'FK to account.id_member (operator working)',
    
    -- Optional identity fields
    material_sheet_id INT(11) DEFAULT NULL COMMENT 'FK to leather_sheet.id_sheet (if selected)',
    session_uuid VARCHAR(36) DEFAULT NULL COMMENT 'Client-generated UUID for idempotency',
    
    -- Timing (SERVER TIME ONLY - SSOT)
    started_at DATETIME NOT NULL COMMENT 'Server time when session started',
    ended_at DATETIME DEFAULT NULL COMMENT 'Server time when session ended',
    paused_at DATETIME DEFAULT NULL COMMENT 'Server time when paused (NULL if not paused)',
    resumed_at DATETIME DEFAULT NULL COMMENT 'Server time when resumed (NULL if never paused)',
    duration_seconds INT(11) NOT NULL DEFAULT 0 COMMENT 'Server-computed: ended_at - started_at - paused_total',
    paused_total_seconds INT(11) NOT NULL DEFAULT 0 COMMENT 'Total paused time (excluded from duration)',
    pause_count INT(11) NOT NULL DEFAULT 0 COMMENT 'Number of times paused',
    
    -- Status
    status ENUM('RUNNING', 'PAUSED', 'ENDED', 'ABORTED') NOT NULL DEFAULT 'RUNNING',
    
    -- Work results (filled on END)
    qty_cut INT(11) DEFAULT NULL COMMENT 'Quantity cut in this session (filled on Save & End)',
    used_area DECIMAL(10,4) DEFAULT NULL COMMENT 'Used area in sq.ft (for leather)',
    overshoot_reason VARCHAR(50) DEFAULT NULL COMMENT 'Reason if qty exceeds required (defect/waste/extra/other)',
    
    -- Audit & Notes
    pause_reason VARCHAR(255) DEFAULT NULL COMMENT 'Reason for pause (optional)',
    notes TEXT DEFAULT NULL COMMENT 'Session notes',
    idempotency_key VARCHAR(255) DEFAULT NULL COMMENT 'Idempotency key for start/end actions',
    
    -- Metadata
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    
    -- Indexes
    INDEX idx_token_node_operator (token_id, node_id, operator_id),
    INDEX idx_status (status),
    INDEX idx_component_identity (component_code, role_code, material_sku),
    INDEX idx_operator_time (operator_id, started_at),
    INDEX idx_idempotency (idempotency_key),
    
    -- Constraints
    UNIQUE KEY uniq_running_session (token_id, node_id, operator_id, status) 
        WHERE status IN ('RUNNING', 'PAUSED'),
    FOREIGN KEY fk_cut_session_token (token_id) REFERENCES flow_token(id_token) ON DELETE CASCADE,
    FOREIGN KEY fk_cut_session_node (node_id) REFERENCES routing_node(id_node) ON DELETE RESTRICT,
    FOREIGN KEY fk_cut_session_operator (operator_id) REFERENCES account(id_member) ON DELETE RESTRICT,
    FOREIGN KEY fk_cut_session_sheet (material_sheet_id) REFERENCES leather_sheet(id_sheet) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='CUT Session timing records - SSOT for component-level work timing';
```

**Key Design Decisions:**
- ✅ **Identity enforced:** component_code + role_code + material_sku (hard validation)
- ✅ **Server time only:** started_at, ended_at, paused_at, resumed_at = server time (ไม่เชื่อ client)
- ✅ **Duration computed:** duration_seconds = ended_at - started_at - paused_total (server-computed)
- ✅ **1 RUNNING session per operator/token/node:** UNIQUE constraint on (token_id, node_id, operator_id, status) WHERE status IN ('RUNNING', 'PAUSED')
- ✅ **Idempotency:** idempotency_key for start/end actions

---

## 🔌 API Design

### Endpoint: `source/dag_behavior_exec.php` (via BehaviorExecutionService)

#### 1. `cut_session_start`

**Action:** `cut_session_start`

**Inputs:**
```json
{
  "token_id": 123,
  "node_id": 456,
  "component_code": "BODY",
  "role_code": "MAIN_MATERIAL",
  "material_sku": "RB-LTH-001",
  "material_sheet_id": 789,  // Optional
  "session_uuid": "uuid-from-client",  // Optional (for idempotency)
  "idempotency_key": "start:token:node:operator:uuid"
}
```

**Preconditions:**
- ✅ No RUNNING/PAUSED session for same (token_id, node_id, operator_id)
- ✅ component_code + role_code + material_sku exists in product structure
- ✅ material_sheet_id matches material_sku (if provided)

**Output:**
```json
{
  "ok": true,
  "session_id": 12345,
  "session_uuid": "server-generated-uuid",
  "started_at": "2026-01-11 10:00:00",  // Server time
  "status": "RUNNING"
}
```

**Idempotency:**
- If idempotency_key exists → return existing session (no-op)

---

#### 2. `cut_session_pause`

**Action:** `cut_session_pause`

**Inputs:**
```json
{
  "session_id": 12345,
  "pause_reason": "Break",  // Optional
  "idempotency_key": "pause:session:timestamp"
}
```

**Preconditions:**
- ✅ Session exists and status = RUNNING

**Output:**
```json
{
  "ok": true,
  "session_id": 12345,
  "status": "PAUSED",
  "paused_at": "2026-01-11 10:15:00",  // Server time
  "work_seconds_so_far": 900  // Seconds worked before pause
}
```

---

#### 3. `cut_session_resume`

**Action:** `cut_session_resume`

**Inputs:**
```json
{
  "session_id": 12345,
  "idempotency_key": "resume:session:timestamp"
}
```

**Preconditions:**
- ✅ Session exists and status = PAUSED

**Output:**
```json
{
  "ok": true,
  "session_id": 12345,
  "status": "RUNNING",
  "resumed_at": "2026-01-11 10:30:00",  // Server time
  "paused_total_seconds": 900  // Total paused time so far
}
```

---

#### 4. `cut_session_end`

**Action:** `cut_session_end`

**Inputs:**
```json
{
  "session_id": 12345,
  "qty_cut": 5,
  "used_area": 2.5,  // Optional (for leather)
  "overshoot_reason": "defect",  // Optional (if qty exceeds required)
  "idempotency_key": "end:session:timestamp"
}
```

**Preconditions:**
- ✅ Session exists and status = RUNNING or PAUSED
- ✅ qty_cut > 0
- ✅ If overshoot → overshoot_reason required

**Output:**
```json
{
  "ok": true,
  "session_id": 12345,
  "status": "ENDED",
  "ended_at": "2026-01-11 10:45:00",  // Server time
  "duration_seconds": 2700,  // Server-computed
  "paused_total_seconds": 900,
  "work_seconds": 1800  // duration_seconds - paused_total_seconds
}
```

**Side Effects:**
- Creates NODE_YIELD event with session timing data
- Updates cut batch totals

---

#### 5. `cut_session_abort`

**Action:** `cut_session_abort`

**Inputs:**
```json
{
  "session_id": 12345,
  "reason": "Cancelled by user"  // Optional
}
```

**Preconditions:**
- ✅ Session exists and status = RUNNING or PAUSED

**Output:**
```json
{
  "ok": true,
  "session_id": 12345,
  "status": "ABORTED"
}
```

**Note:** ABORTED sessions are NOT included in roll-up calculations

---

#### 6. `cut_session_get_active`

**Action:** `cut_session_get_active`

**Inputs:**
```json
{
  "token_id": 123,
  "node_id": 456
}
```

**Output:**
```json
{
  "ok": true,
  "session": {
    "session_id": 12345,
    "session_uuid": "uuid",
    "component_code": "BODY",
    "role_code": "MAIN_MATERIAL",
    "material_sku": "RB-LTH-001",
    "status": "RUNNING",
    "started_at": "2026-01-11 10:00:00",
    "paused_at": null,
    "resumed_at": null,
    "paused_total_seconds": 0,
    "work_seconds_so_far": 900,  // Current work time (if RUNNING)
    "material_sheet_id": 789
  }
}
```

**Use Case:** UI calls this on Phase 2 load to restore timer after refresh

---

## 🔄 Roll-Up Logic

### Component-Level Timing Summary

```sql
-- Get total time per component (for get_cut_batch_detail)
SELECT 
    component_code,
    role_code,
    material_sku,
    COUNT(*) AS session_count,
    SUM(duration_seconds) AS total_duration_seconds,
    SUM(qty_cut) AS total_qty_cut,
    SUM(used_area) AS total_used_area,
    AVG(duration_seconds / NULLIF(qty_cut, 0)) AS avg_seconds_per_piece
FROM cut_session
WHERE token_id = ?
  AND node_id = ?
  AND status = 'ENDED'  -- Only count completed sessions
GROUP BY component_code, role_code, material_sku
```

### Legacy SSOT Roll-Up

```php
// In getCutBatchTotalsForToken() or similar
$legacyCutDurationSeconds = sum(
    SELECT duration_seconds 
    FROM cut_session 
    WHERE token_id = ? AND node_id = ? AND status = 'ENDED'
);
```

**Phase 1 (Current):**
- Legacy SSOT ยังอยู่เหมือนเดิม
- CUT_SESSION เป็น "ground truth" สำหรับ component timing
- Roll-up: `legacy_cut_duration_seconds = sum(session.duration_seconds)`

**Phase 2 (Future):**
- Legacy field กลายเป็น derived/cached summary
- CUT_SESSION เป็น SSOT

---

## 🛡️ Validation Rules

### 1. One RUNNING Session Per Operator/Token/Node

**Enforcement:**
- UNIQUE constraint: `(token_id, node_id, operator_id, status)` WHERE status IN ('RUNNING', 'PAUSED')
- Backend check: Before starting new session, check for existing RUNNING/PAUSED session
- If exists → return error: `CUT_409_SESSION_ALREADY_RUNNING`

### 2. Duration Must Be Server-Computed

**Enforcement:**
- `duration_seconds` = `ended_at - started_at - paused_total_seconds` (server-computed)
- Client can send `duration_seconds` as hint but backend ignores it
- Backend always computes from server timestamps

### 3. Session Must Bind to Identity

**Enforcement:**
- Hard validation: component_code + role_code + material_sku must exist in product structure
- Reject with `CUT_400_ROLE_MATERIAL_MISMATCH` if mismatch

### 4. Idempotency for All Actions

**Enforcement:**
- start/end/pause/resume all require idempotency_key
- Backend checks idempotency_key before processing
- If exists → return existing result (no-op)

### 5. Abort Policy

**Enforcement:**
- If user cancels → mark ABORTED (not included in roll-up)
- ABORTED sessions excluded from timing calculations

---

## 🎨 UI/UX Integration

### Phase 2: Cutting Session

**Current Flow:**
1. User selects Component → Role → Material
2. Clicks "Start Cutting"
3. UI starts client-side timer
4. User enters quantity, selects sheet
5. Clicks "Save & End Session"
6. Timer stops (client-side)

**New Flow (Real Timing):**
1. User selects Component → Role → Material
2. Clicks "Start Cutting"
3. **UI calls `cut_session_start` API**
4. **Server returns `started_at` (server time)**
5. **UI timer syncs from server time** (not `Date.now()`)
6. User enters quantity, selects sheet
7. Clicks "Save & End Session"
8. **UI calls `cut_session_end` API with qty_cut**
9. **Server computes duration_seconds and persists**
10. UI shows success

**Refresh/Restore:**
- On Phase 2 load: Call `cut_session_get_active`
- If RUNNING session exists → restore timer from `started_at` + `paused_total_seconds`
- If no session → show "Start Cutting" button

---

## 📊 Output: Hermès-Grade Traceability

### Queries You Can Answer:

1. **"ช่าง A ใช้เวลาตัด component X (MAIN+sku123) รวมกี่นาที?"**
   ```sql
   SELECT 
       operator_id,
       component_code,
       role_code,
       material_sku,
       SUM(duration_seconds) / 60.0 AS total_minutes,
       COUNT(*) AS session_count
   FROM cut_session
   WHERE operator_id = ? 
     AND component_code = ?
     AND role_code = ?
     AND material_sku = ?
     AND status = 'ENDED'
   GROUP BY operator_id, component_code, role_code, material_sku
   ```

2. **"เวลาเฉลี่ยต่อชิ้นของ component X?"**
   ```sql
   SELECT 
       component_code,
       SUM(duration_seconds) / NULLIF(SUM(qty_cut), 0) AS seconds_per_piece
   FROM cut_session
   WHERE component_code = ? AND status = 'ENDED'
   GROUP BY component_code
   ```

3. **"หนังแผ่นไหนถูกใช้กับ component ไหน ใช้ area เท่าไหร่ ใช้เวลากี่นาที?"**
   ```sql
   SELECT 
       material_sheet_id,
       component_code,
       role_code,
       material_sku,
       SUM(used_area) AS total_used_area,
       SUM(duration_seconds) / 60.0 AS total_minutes
   FROM cut_session
   WHERE material_sheet_id IS NOT NULL AND status = 'ENDED'
   GROUP BY material_sheet_id, component_code, role_code, material_sku
   ```

4. **"งานไหนมี anomaly: เวลาเยอะแต่ qty น้อย / qty เยอะแต่เวลา 0?"**
   ```sql
   SELECT *
   FROM cut_session
   WHERE status = 'ENDED'
     AND (
       (duration_seconds > 3600 AND qty_cut < 5) OR  -- >1 hour but <5 pieces
       (qty_cut > 10 AND duration_seconds = 0) OR    -- >10 pieces but 0 time
       (duration_seconds > 86400)                     -- >24 hours (impossible)
     )
   ```

---

## ✅ Implementation Checklist

### Phase 1: Database & Model
- [ ] Create `cut_session` table migration
- [ ] Add indexes and constraints
- [ ] Create `CutSessionService` class (model layer)

### Phase 2: Backend API
- [ ] Implement `cut_session_start` in BehaviorExecutionService
- [ ] Implement `cut_session_pause` in BehaviorExecutionService
- [ ] Implement `cut_session_resume` in BehaviorExecutionService
- [ ] Implement `cut_session_end` in BehaviorExecutionService
- [ ] Implement `cut_session_abort` in BehaviorExecutionService
- [ ] Implement `cut_session_get_active` in BehaviorExecutionService
- [ ] Add validation: one RUNNING session per operator/token/node
- [ ] Add validation: identity integrity (component+role+material)

### Phase 3: UI Integration
- [ ] Modify Phase 2 "Start Cutting" to call `cut_session_start` API
- [ ] Sync UI timer from server `started_at` (not client `Date.now()`)
- [ ] Modify "Save & End Session" to call `cut_session_end` API
- [ ] Add restore logic: call `cut_session_get_active` on Phase 2 load
- [ ] Handle pause/resume (if needed in future)

### Phase 4: Roll-Up & Reporting
- [ ] Add session timing to `get_cut_batch_detail` response
- [ ] Implement roll-up logic for legacy timing
- [ ] Add anomaly detection queries

### Phase 5: Testing & Audit
- [ ] Unit tests for CutSessionService
- [ ] Integration tests for session lifecycle
- [ ] Test refresh/restore scenario
- [ ] Test concurrent operators
- [ ] Test idempotency

---

## 🎯 Success Criteria

- ✅ Timer ไม่หลอก: ทุก timing มาจาก server
- ✅ Refresh ไม่พัง: restore session ได้หลัง refresh
- ✅ Audit ได้: ตอบคำถาม traceability ได้ทุกข้อ
- ✅ Roll-up ถูกต้อง: legacy timing = sum of sessions
- ✅ Anomaly detection: flag suspicious sessions

---

## 📝 Next Steps

1. **Create migration file** for `cut_session` table
2. **Create `CutSessionService`** class
3. **Implement API endpoints** in BehaviorExecutionService
4. **Update UI** to use real API timing
5. **Add roll-up** to get_cut_batch_detail
