# 🛡️ Risk Playbook - DAG Production System

**Version:** 1.0  
**Created:** November 2, 2025  
**Purpose:** Anticipatory risk mitigation for DAG + Serial + PWA  
**Scope:** 50 scenarios across 11 categories

---

## 🎯 **Core Architectural Safeguards**

### **Foundation Principles (Do Once, Protects Everything):**

#### **1. Event Sourcing = Single Source of Truth**
```
Every action = Event (immutable record)
├─ start, pause, resume, complete, qc_pass, qc_fail, scrap
└─ Stored in: atelier_wip_log or token_event (append-only)

Current state = Derived from event history
→ Never modify events, create compensating events instead
```

#### **2. Idempotency Everywhere**
```sql
-- Every request has UUID
INSERT INTO wip_log (
    id_job_task,
    idempotency_key,  -- UUID v4
    event_type,
    operator_id,
    device_id,
    app_version
);

-- Prevent duplicates
UNIQUE KEY idx_idempotency (id_job_task, idempotency_key);

-- Client behavior
if (success || 409_duplicate) → treat as success
```

#### **3. Optimistic Locking with Version**
```sql
-- Tables with current state
ALTER TABLE atelier_task_serial 
ADD COLUMN version INT NOT NULL DEFAULT 1;

-- Every update
UPDATE atelier_task_serial 
SET status = ?, version = version + 1
WHERE id_task_serial = ? AND version = ?;  -- Expected version

-- If affected_rows = 0 → 409 Conflict (client must refresh)
```

#### **4. Server-Time Authoritative**
```php
// Always use server time
$eventTime = date('Y-m-d H:i:s'); // UTC

// Client time = reference only
$clientTime = $_POST['client_time']; // Stored but not used for decisions
```

#### **5. Local Action Queue (Offline-First)**
```javascript
// IndexedDB structure
{
    idempotency_key: 'uuid-v4',
    action: 'complete_token',
    payload: {...},
    created_at: timestamp,
    retry_count: 0,
    status: 'pending' | 'syncing' | 'synced' | 'failed'
}

// Retry policy
exponentialBackoff = Math.min(1000 * Math.pow(2, retryCount), 30000);
```

#### **6. Soft Lock (Gentle Ownership)**
```sql
ALTER TABLE flow_token
ADD COLUMN lock_owner INT NULL,
ADD COLUMN lock_expires_at DATETIME NULL;

-- On start/resume
UPDATE flow_token 
SET lock_owner = ?, 
    lock_expires_at = DATE_ADD(NOW(), INTERVAL 15 MINUTE)
WHERE id_token = ? AND (lock_owner IS NULL OR lock_expires_at < NOW());

-- Auto-expire after 15 minutes (operator left)
```

#### **7. State Machine (Clear Transitions)**
```
States: planned → reserved → in_progress → (done | scrap)

Transition Rules:
├─ reserve: planned → reserved (set reserved_by)
├─ start/resume: planned|reserved → in_progress (set lock_owner)
├─ pause: in_progress → reserved (keep reserved_by)
├─ complete: reserved|in_progress → done (clear lock)
└─ scrap: any (≠done) → scrap (reason required)

Terminal States: done, scrap (no further transitions)
```

---

## 🚨 **Risk Scenarios & Mitigations**

### **Category A: Device/Network (8 scenarios)**

#### **A1. ดับจอกะทันหันหลังคลิก**
```
Symptom: Click Complete → Screen off (power/battery)
Root Cause: Power failure during API call

Mitigation:
1. ✅ Local queue saves event BEFORE API call
2. ✅ Idempotency key persisted
3. ✅ On restart → retry with same key
4. ✅ Server-time authoritative (server decides event_time)

Acceptance Test:
- Turn off device 50ms after click
- Restart → Sync → Verify: event recorded once, correct time
```

#### **A2. ดับจอช่วงกำลังส่ง**
```
Symptom: Unclear if server received request
Root Cause: Network timeout during transmission

Mitigation:
1. ✅ Optimistic UI (show as "syncing...")
2. ✅ Disable button for 3 seconds (prevent rapid re-tap)
3. ✅ Retry with same key on reconnect
4. ✅ Server idempotency → safe to retry

Implementation:
$('#btn-complete').prop('disabled', true).html('<i class="spinner"></i> Saving...');
setTimeout(() => $('#btn-complete').prop('disabled', false), 3000);
```

#### **A3. สัญญาณสวิง/เข้าอุโมงค์**
```
Symptom: Operator taps multiple times (thinks not sent)
Root Cause: Network instability

Mitigation:
1. ✅ Debounce (300ms) + spinner
2. ✅ Exactly-once guarantee (server idempotency)
3. ✅ UI feedback: "Syncing... (attempt 1/5)"

Code:
let submitInProgress = false;
async function submitEvent() {
    if (submitInProgress) return;
    submitInProgress = true;
    try {
        await sendToServer();
    } finally {
        setTimeout(() => submitInProgress = false, 300);
    }
}
```

#### **A4. ออฟไลน์ยาว**
```
Symptom: Queue overflow, slow sync
Root Cause: Extended offline period (hours/days)

Mitigation:
1. ✅ Batch sync (5-10 events per request)
2. ✅ Exponential backoff
3. ✅ Max queue threshold (100 events) → warn supervisor
4. ✅ Priority queue (complete > pause > note)

Alert:
if (queueSize > 100) {
    notifySupervisor('Operator offline with 100+ pending events');
}
```

#### **A5. เวลาเครื่องเพี้ยน (Clock Skew)**
```
Symptom: Event order incorrect
Root Cause: Device clock wrong

Mitigation:
1. ✅ Server-time authoritative (server assigns event_time)
2. ✅ Client-time stored as reference only
3. ✅ Detect skew: if |client_time - server_time| > 5 min → warn

Validation:
$timeDiff = abs(strtotime($clientTime) - time());
if ($timeDiff > 300) {
    error_log("Clock skew detected: {$timeDiff}s for operator {$operatorId}");
}
```

#### **A6. เครื่องสองเครื่องใช้ login เดียวกัน**
```
Symptom: Work conflicts (same operator, different devices)
Root Cause: Shared account or device switching

Mitigation:
1. ✅ lock_owner includes device_id
2. ✅ Warn on second device: "Active session on Device A - Take over?"
3. ✅ Take-over flow: Previous device auto-paused

UI:
Swal.fire({
    title: 'Session Conflict',
    html: 'You have active work on another device (iPad #2).<br>Take over?',
    icon: 'warning',
    showCancelButton: true
}).then(result => {
    if (result.isConfirmed) {
        takeOverSession(tokenId, deviceId);
    }
});
```

#### **A7. หน่วยความจำอุปกรณ์เต็ม**
```
Symptom: Local queue write fails
Root Cause: Device storage full

Mitigation:
1. ✅ Low-space detector (quota API)
2. ✅ Reduce media cache (compress photos)
3. ✅ Purge synced queue entries > 7 days
4. ✅ Critical: Always keep unsynced events (never delete)

Code:
if (navigator.storage && navigator.storage.estimate) {
    const estimate = await navigator.storage.estimate();
    const percentUsed = (estimate.usage / estimate.quota) * 100;
    if (percentUsed > 90) {
        notifyWarning('Storage almost full - clearing cache');
        purgeOldCache();
    }
}
```

#### **A8. อัปเดตแอปกลางงาน**
```
Symptom: Queue format incompatible after update
Root Cause: App version change

Mitigation:
1. ✅ Versioned payload (v1, v2, ...)
2. ✅ Migration layer for queue
3. ✅ Graceful upgrade (sync before update)

Code:
function migrateQueue(oldQueue) {
    return oldQueue.map(item => {
        if (item.version === 1) {
            return {
                ...item,
                version: 2,
                operator_context: {...} // Add new fields
            };
        }
        return item;
    });
}
```

---

### **Category B: Concurrency/State (7 scenarios)**

#### **B9. สองคนเริ่ม serial เดียวกัน**
```
Symptom: Double in_progress
Root Cause: Race condition

Mitigation:
1. ✅ Soft lock check before start
2. ✅ 409 conflict if already locked
3. ✅ Take-over flow (supervisor approval)

SQL:
UPDATE flow_token 
SET lock_owner = ?, lock_expires_at = DATE_ADD(NOW(), INTERVAL 15 MINUTE)
WHERE id_token = ? 
  AND (lock_owner IS NULL OR lock_expires_at < NOW());

if (affected_rows === 0) {
    $current = getLockOwner($tokenId);
    json_error("Token locked by {$current['name']} until {$current['expires']}", 409);
}
```

#### **B10. เริ่มงานใหม่ทั้งที่มีงานค้าง**
```
Symptom: Dangling in_progress
Root Cause: Operator forgets previous work

Mitigation:
1. ✅ Sticky banner: "กำลังทำ: TOTE-003" (always visible)
2. ✅ Confirm dialog before starting new token
3. ✅ Auto-pause previous token

UI:
if (hasActiveuToken()) {
    Swal.fire({
        title: 'คุณมีงานค้าง',
        html: 'Serial: TOTE-003 (ทำมา 15 นาที)<br>จะพักชิ้นนั้นแล้วเริ่มชิ้นใหม่?',
        showCancelButton: true,
        confirmButtonText: 'พัก TOTE-003 แล้วเริ่มใหม่',
        cancelButtonText: 'ยกเลิก'
    });
}
```

#### **B11. Complete ซ้ำ serial เดียว**
```
Symptom: Double count
Root Cause: Duplicate submission

Mitigation:
1. ✅ Check token status before complete
2. ✅ If already 'completed' → return idempotent success (don't error)
3. ✅ UNIQUE constraint (id_token, final_state)

PHP:
$token = getToken($tokenId);
if ($token['status'] === 'completed') {
    json_success([
        'duplicate' => true,
        'message' => 'Token already completed',
        'completed_at' => $token['completed_at']
    ]);
    return;
}
```

#### **B12. Pause ผิด serial**
```
Symptom: Wrong token frozen
Root Cause: Operator tap error

Mitigation:
1. ✅ Sticky banner shows current work
2. ✅ Undo last 3 actions (per operator)
3. ✅ Switch confirmation dialog
4. ✅ Compensating event (undo_pause)

Undo:
function undoLastAction() {
    const lastEvent = undoStack.pop();
    if (lastEvent.type === 'pause') {
        // Create compensating event
        createEvent({
            type: 'undo_pause',
            original_event_id: lastEvent.id,
            reason: 'operator_correction'
        });
        resumeToken(lastEvent.token_id);
    }
}
```

#### **B13. Race: QC pass ช้ากว่า complete**
```
Symptom: Edge not unlocked
Root Cause: QC result arrives after token already moved

Mitigation:
1. ✅ Process gate: Block routing if qc_required && !qc_pass
2. ✅ Token status: 'qc_pending' (separate from 'completed')
3. ✅ QC pass → triggers routing

Flow:
Complete work → status = 'qc_pending' (not 'completed')
QC pass → status = 'completed' → route to next node
QC fail → status = 'qc_failed' → route to rework node
```

#### **B14. Resume บน serial ที่ถูกคนอื่น complete แล้ว**
```
Symptom: 409 conflict
Root Cause: Stale local state

Mitigation:
1. ✅ Version check before resume
2. ✅ Resolve dialog if conflict detected
3. ✅ Options: Convert to note, Pick next serial

UI:
Swal.fire({
    title: 'Serial นี้เสร็จแล้ว',
    html: 'TOTE-003 ถูก complete โดย ช่าง B เมื่อ 10:30<br>ต้องการ:',
    showDenyButton: true,
    confirmButtonText: 'บันทึกเป็น Note',
    denyButtonText: 'เลือก Serial อื่น',
    cancelButtonText: 'ยกเลิก'
});
```

#### **B15. พนักงานลืม logout ย้ายกะ**
```
Symptom: Token stuck with lock
Root Cause: Operator left without logging out

Mitigation:
1. ✅ Auto-expire lock (15 minutes)
2. ✅ Supervisor force-pause (with reason)
3. ✅ Audit trail

Cron job:
UPDATE flow_token 
SET lock_owner = NULL, lock_expires_at = NULL
WHERE lock_expires_at < NOW();

// Alert supervisor
SELECT COUNT(*) FROM flow_token WHERE lock_expires_at BETWEEN DATE_SUB(NOW(), INTERVAL 1 MINUTE) AND NOW();
```

---

### **Category C: Data Integrity (5 scenarios)**

#### **C16. Key เปลี่ยนระหว่าง retry**
```
Symptom: Duplicate events
Root Cause: Client generates new key on each retry

Mitigation:
1. ✅ Cache key in DOM/localStorage per event
2. ✅ Reuse same key until success
3. ✅ Server UNIQUE index enforces

Code:
let eventKey = $form.data('idempotency-key');
if (!eventKey) {
    eventKey = uuidv4();
    $form.data('idempotency-key', eventKey);
    localStorage.setItem('pending_event_key', eventKey);
}
```

#### **C17. Serial format เพี้ยน**
```
Symptom: Traceability breaks
Root Cause: Manual entry typo

Mitigation:
1. ✅ Serial readonly when selected from board
2. ✅ Validate pattern when typed manually
3. ✅ Warn if format mismatch

Validation:
const serialPattern = /^[A-Z]+-\d{3,5}$/;
if (!serialPattern.test(serial)) {
    notifyWarning('Serial format: PREFIX-001 (example: TOTE-001)');
    return false;
}
```

#### **C18. แก้ไขย้อนหลังโดยไม่มี audit**
```
Symptom: Statistics wrong, no trail
Root Cause: Direct database update

Mitigation:
1. ✅ Immutable event log (no UPDATE/DELETE)
2. ✅ Compensating events for corrections
3. ✅ Audit trail (who, when, why)
4. ✅ Supervisor approval required

Correction:
// Don't: UPDATE wip_log SET qty = 5 WHERE id = 123;
// Do:
INSERT INTO wip_log (
    event_type,
    original_event_id,
    correction_reason,
    qty,
    corrected_by
) VALUES (
    'correction',
    123,
    'Operator entered wrong qty',
    5,
    supervisor_id
);
```

#### **C19. ลบ log ผิด**
```
Symptom: Timeline missing
Root Cause: Accidental deletion

Mitigation:
1. ✅ Soft-delete only (deleted_at, deleted_by)
2. ✅ Restore window (30 days)
3. ✅ Supervisor approval for delete
4. ✅ Daily backup

Soft-delete:
UPDATE wip_log 
SET deleted_at = NOW(), deleted_by = ?, delete_reason = ?
WHERE id_wip_log = ?;

// Restore
UPDATE wip_log 
SET deleted_at = NULL, deleted_by = NULL, restored_by = ?
WHERE id_wip_log = ? AND deleted_at > DATE_SUB(NOW(), INTERVAL 30 DAY);
```

#### **C20. จำนวน target/serial ไม่เท่ากัน**
```
Symptom: Pre-gen serials insufficient or excess
Root Cause: Target qty changed after serial generation

Mitigation:
1. ✅ Generator guard (check existing count)
2. ✅ Diff check before spawn
3. ✅ Replenish flow (generate more if increased)
4. ✅ Retire flow (mark unused if decreased)

Logic:
$existing = count(getTicketSerials($ticketId));
$target = $ticket['target_qty'];

if ($existing < $target) {
    generateAdditionalSerials($ticketId, $target - $existing);
} elseif ($existing > $target) {
    retireExcessSerials($ticketId, $existing - $target);
}
```

---

### **Category D: Serial/Assembly/Genealogy (6 scenarios)**

#### **D22. Final ไม่มี component ครบ**
```
Symptom: Assembly completed without all parts
Root Cause: Operator bypassed BOM check

Mitigation:
1. ✅ BOM validation before finalize
2. ✅ Required components list
3. ✅ Block submit if missing

Check:
$required = getBOMComponents($productId);
$scanned = $payload['components'];

foreach ($required as $comp) {
    if (!in_array($comp['type'], array_column($scanned, 'type'))) {
        json_error("Missing component: {$comp['name']}", 400);
    }
}
```

#### **D23. Component ถูกใช้ซ้ำสอง final**
```
Symptom: Double-consume
Root Cause: Same component serial used in 2 assemblies

Mitigation:
1. ✅ consume_flag on component tokens
2. ✅ UNIQUE constraint (parent_serial, child_serial)

SQL:
ALTER TABLE token_genealogy
ADD UNIQUE KEY idx_unique_consumption (parent_token_id, child_token_id);

// Before assembly
$component = getToken($componentSerial);
if ($component['consumed_in_assembly']) {
    json_error("Component already used in {$component['final_serial']}", 400);
}
```

#### **D24. Rework เปลี่ยนชิ้นส่วน**
```
Symptom: Old genealogy not updated
Root Cause: Replace failed component during rework

Mitigation:
1. ✅ Close old edge (mark replaced)
2. ✅ Create new edge (new component)
3. ✅ Reason required

Flow:
-- Mark old component as replaced
UPDATE token_genealogy 
SET status = 'replaced', replaced_at = NOW(), replace_reason = ?
WHERE parent_token_id = ? AND child_token_id = ?;

-- Add new component
INSERT INTO token_genealogy (parent_token_id, child_token_id, relation_type)
VALUES (?, ?, 'replacement');
```

#### **D25. สลับ L/R strap**
```
Symptom: Left strap on right side
Root Cause: Assembly error

Mitigation:
1. ✅ Slot-type constraint (STRAP_L, STRAP_R)
2. ✅ Mismatch detection
3. ✅ Block submission

Validation:
$bomSlot = getBOMSlot($productId, 'strap_right');
if ($bomSlot['type'] !== $scannedComponent['type']) {
    json_error("Wrong component: Expected {$bomSlot['type']}, got {$scannedComponent['type']}", 400);
}
```

#### **D26. Hardware lot trace ขาดตอน**
```
Symptom: Recall impossible
Root Cause: Missing lot number on hardware

Mitigation:
1. ✅ Enforce lot at consume-time
2. ✅ Lot mandatory on assembly
3. ✅ Block if lot missing

Validation:
if ($component['category'] === 'hardware' && empty($component['lot_number'])) {
    json_error('Hardware lot number required for traceability', 400);
}
```

#### **D27. Serial ชนกับชุดที่ผลิตก่อน**
```
Symptom: Duplicate serial across batches
Root Cause: Weak serial generation

Mitigation:
1. ✅ Namespace: {brand}/{sku}/{year}/{batch}
2. ✅ Crypto suffix (6-digit random)
3. ✅ Global uniqueness check

Generator:
$prefix = "{$brand}-{$sku}-{$year}";
$suffix = strtoupper(bin2hex(random_bytes(3))); // 6 chars
$serial = "{$prefix}-{$suffix}"; // TOTE-2025-A7F3C9

// Global check
$exists = db_fetch_one($coreDb, "SELECT 1 FROM global_serial_registry WHERE serial = ?", [$serial]);
```

---

### **Category E: DAG/Dependency (5 scenarios)**

#### **E28. Cycle ใน dependency**
```
Symptom: Tasks never become ready
Root Cause: Circular dependency (A→B→C→A)

Mitigation:
1. ✅ Cycle detector (client + server)
2. ✅ Block save if cycle detected
3. ✅ Show culprit edges

Algorithm:
function detectCycle(graph) {
    const visited = new Set();
    const stack = new Set();
    
    function dfs(node) {
        if (stack.has(node)) return true; // Cycle!
        if (visited.has(node)) return false;
        
        visited.add(node);
        stack.add(node);
        
        for (const neighbor of graph[node]) {
            if (dfs(neighbor)) return true;
        }
        
        stack.delete(node);
        return false;
    }
    
    for (const node of Object.keys(graph)) {
        if (dfs(node)) return true;
    }
    return false;
}
```

#### **E29. Orphan task (ไม่เชื่อม)**
```
Symptom: Task never unlocked
Root Cause: No path from start node

Mitigation:
1. ✅ Graph lint: All nodes reachable from start
2. ✅ All nodes reach end
3. ✅ Block publish if orphans detected

Validation:
function findOrphans(graph) {
    const reachableFromStart = bfs(graph, startNode);
    const reachableToEnd = reverseBfs(graph, endNode);
    
    const orphans = [];
    for (const node of graph.nodes) {
        if (!reachableFromStart.has(node) || !reachableToEnd.has(node)) {
            orphans.push(node);
        }
    }
    return orphans;
}
```

#### **E30. Critical path ไม่ชัด**
```
Symptom: Wrong priority
Root Cause: No critical path calculation

Mitigation:
1. ✅ Compute critical path (longest path)
2. ✅ Mark with ★ icon
3. ✅ Sort by criticality

Algorithm:
function findCriticalPath(graph) {
    // Longest path from start to end
    const distances = {};
    const topologicalOrder = topologicalSort(graph);
    
    for (const node of topologicalOrder) {
        distances[node] = 0;
        for (const predecessor of graph.incoming[node]) {
            distances[node] = Math.max(
                distances[node],
                distances[predecessor] + edgeWeight(predecessor, node)
            );
        }
    }
    
    // Backtrack to find path
    return backtrackPath(distances, endNode);
}
```

#### **E31. Parallel group เชื่อมผิด**
```
Symptom: Entire block stuck
Root Cause: Join node misconfigured

Mitigation:
1. ✅ Template import validation
2. ✅ Visual diff before apply
3. ✅ Test with sample token

Preview:
"Importing routing will create:
 - 3 parallel branches (SEW_BODY, SEW_STRAP, SEW_HANDLE)
 - Join at ASSEMBLY (requires all 3)
 
Preview flow with test token? [Yes/No]"
```

#### **E32. Dependency เปลี่ยนกลางคัน**
```
Symptom: State confusion
Root Cause: Graph updated while job running

Mitigation:
1. ✅ Versioned DAG (graph_version)
2. ✅ Job uses snapshot (graph version locked)
3. ✅ Re-evaluate with correct version

Lock:
job_graph_instance.graph_version = 5 (locked)
routing_graph.current_version = 7 (updated)

→ Job continues with version 5 (stable)
```

---

### **Category F: QC/Quality (4 scenarios)**

#### **F33. QC fail แต่เผลอปล่อยต่อ**
```
Symptom: Defect reaches customer
Root Cause: Gate not enforced

Mitigation:
1. ✅ Gate enforcement: Next edge disabled until qc_pass
2. ✅ Token status: 'qc_pending' (can't route)
3. ✅ Visual indicator (🔒 locked until QC)

Flow:
if ($node['qc_required'] && !hasQCPass($tokenId)) {
    json_error('QC approval required before routing', 403);
}
```

#### **F34. รูป QC ใหญ่เกิน/อัปไม่ได้**
```
Symptom: UI stuck
Root Cause: Large image (>10MB)

Mitigation:
1. ✅ On-device compress (max 1920px, 80% quality)
2. ✅ Async upload (background)
3. ✅ Placeholder entry (upload later)

Code:
async function compressAndUpload(file) {
    const compressed = await compressImage(file, {
        maxWidth: 1920,
        maxHeight: 1920,
        quality: 0.8
    });
    
    // Create placeholder
    const placeholderId = createQCEntry({
        status: 'uploading',
        photo_placeholder: true
    });
    
    // Upload in background
    uploadInBackground(compressed, placeholderId);
}
```

#### **F35. เหตุผล QC ไม่ครบ**
```
Symptom: Can't analyze root cause
Root Cause: Free-text only

Mitigation:
1. ✅ Reason code required (dropdown)
2. ✅ Free-text optional (additional notes)
3. ✅ Preset top 10 reasons

UI:
<select id="qc-fail-reason" required>
    <option value="">-- เลือกสาเหตุ --</option>
    <option value="stitch_loose">ตะเข็บหลวม</option>
    <option value="color_mismatch">สีไม่ตรง</option>
    <option value="dimension_off">ขนาดผิด</option>
    ...
</select>
<textarea id="qc-notes" placeholder="รายละเอียดเพิ่มเติม (optional)"></textarea>
```

#### **F36. ของเสียไม่ระบุสาเหตุ**
```
Symptom: Can't do Pareto analysis
Root Cause: Scrap without reason

Mitigation:
1. ✅ Enforce scrap_reason (required)
2. ✅ Preset top 10 reasons
3. ✅ Photo attachment (optional but recommended)

Validation:
if ($eventType === 'scrap' && empty($_POST['reason'])) {
    json_error('Scrap reason is required', 400);
}
```

---

### **Category G: UX/Human Behavior (4 scenarios)**

#### **G37. ปุ่มอยู่ใกล้ กดผิด**
```
Symptom: Start instead of Pause
Root Cause: Button proximity

Mitigation:
1. ✅ Spacing (min 44px touch target)
2. ✅ Confirmation for destructive actions
3. ✅ Color coding (green=safe, red=destructive, yellow=caution)

CSS:
.btn-action {
    min-height: 44px;
    margin: 8px; /* Prevent mis-tap */
}

.btn-destructive {
    background: var(--bs-danger);
}
```

#### **G38. อ่านไม่ออกเวลาเครียด**
```
Symptom: Wrong action
Root Cause: Poor visibility

Mitigation:
1. ✅ Large affordance (big buttons)
2. ✅ Color semantics (green=ready, amber=blocked, gray=paused)
3. ✅ Icons + text (not text only)

Design:
<button class="btn btn-success btn-lg">
    <i class="ri-play-circle-line fs-3"></i>
    <span class="d-block">เริ่มทำ</span>
</button>
```

#### **G39. ลืมว่าทำ serial ไหน**
```
Symptom: Work stalled
Root Cause: No reminder

Mitigation:
1. ✅ Sticky banner (always visible)
2. ✅ Quick resume link
3. ✅ Notification after 15 min idle

UI:
<div class="sticky-top bg-primary text-white p-2">
    ⚙️ กำลังทำ: <strong>TOTE-003</strong> (เริ่ม 15 นาทีที่แล้ว)
    <button class="btn btn-sm btn-light">Resume</button>
</div>
```

#### **G40. ภาษาปน/ศัพท์ยาก**
```
Symptom: Misunderstanding
Root Cause: Technical jargon

Mitigation:
1. ✅ Thai microcopy (clear, simple)
2. ✅ Icon + tooltip (visual aid)
3. ✅ No jargon (use "ชิ้น" not "token", "สถานี" not "node")

Examples:
✅ "พร้อมเริ่ม — dependency ครบแล้ว"
✅ "ยังเริ่มไม่ได้ — รอ: STEP-2"
❌ "Token ready — All edges satisfied"
❌ "Blocked — Upstream node pending"
```

---

### **Category H: Permissions/Security (3 scenarios)**

#### **H41. พนักงานแก้ของคนอื่น**
```
Symptom: Data tampering
Root Cause: Insufficient access control

Mitigation:
1. ✅ RBAC: Operator edits own work only
2. ✅ Supervisor override (with reason)
3. ✅ Audit trail

Check:
if ($event['operator_id'] !== $currentUser['id'] && !$currentUser['is_supervisor']) {
    json_error('You can only edit your own work', 403);
}

// Supervisor override
if ($currentUser['is_supervisor'] && $_POST['override_reason']) {
    logAudit('supervisor_override', $reason);
    // Allow
}
```

#### **H42. Token/Session หลุด**
```
Symptom: Unauthorized access
Root Cause: Stolen/leaked session token

Mitigation:
1. ✅ Short-lived tokens (4 hours)
2. ✅ Device binding (token valid for specific device_id)
3. ✅ Revoke all on risk

Security:
session_token = {
    user_id: 42,
    device_id: 'abc123',
    issued_at: timestamp,
    expires_at: timestamp + 4h
}

// Verify on each request
if (session.device_id !== request.device_id) {
    revokeSession();
    json_error('Session invalid', 401);
}
```

#### **H43. QR payload ถูกแก้**
```
Symptom: Forged work order
Root Cause: QR not signed

Mitigation:
1. ✅ Signed QR (HMAC)
2. ✅ Expiry timestamp
3. ✅ Validate signature before processing

Generate:
$payload = json_encode([
    'ticket_code' => 'JT-001',
    'issued_at' => time(),
    'expires_at' => time() + 86400
]);
$signature = hash_hmac('sha256', $payload, SECRET_KEY);
$qrData = base64_encode($payload) . '.' . $signature;

Validate:
[$payload, $signature] = explode('.', $qrData);
$expected = hash_hmac('sha256', $payload, SECRET_KEY);
if (!hash_equals($expected, $signature)) {
    json_error('Invalid QR code', 403);
}
```

---

## 📊 **KPI & Monitoring**

### **Health Metrics (Set Alerts):**

| Metric | Target | Alert Threshold | Action |
|--------|--------|-----------------|--------|
| **Duplicate rate** | < 0.1% | > 0.5% | Review idempotency |
| **Conflict rate** | < 0.5% | > 2% | Check locking logic |
| **Dangling in_progress** | < 3/day | > 10/day | Review auto-pause |
| **Sync latency (p50)** | < 10s | > 30s | Check server load |
| **Sync latency (p95)** | < 60s | > 120s | Investigate network |
| **QC leak rate** | < 0.3% | > 1% | Review gate enforcement |
| **Orphan/Cycle count** | 0 | > 0 | Block deployment |

### **Monitoring Queries:**

```sql
-- Duplicate detection
SELECT 
    COUNT(*) as total_events,
    COUNT(DISTINCT idempotency_key) as unique_keys,
    (COUNT(*) - COUNT(DISTINCT idempotency_key)) as duplicates,
    ROUND((COUNT(*) - COUNT(DISTINCT idempotency_key)) / COUNT(*) * 100, 2) as duplicate_rate
FROM wip_log
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY);

-- Dangling in_progress
SELECT 
    t.serial_number,
    t.lock_owner,
    t.lock_expires_at,
    TIMESTAMPDIFF(HOUR, s.started_at, NOW()) as hours_active
FROM flow_token t
JOIN token_work_session s ON s.id_token = t.id_token AND s.status = 'active'
WHERE t.status = 'active'
  AND TIMESTAMPDIFF(HOUR, s.started_at, NOW()) > 2;

-- Conflict rate
SELECT 
    COUNT(*) as total_409_conflicts,
    COUNT(*) / (SELECT COUNT(*) FROM wip_log WHERE created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY)) * 100 as conflict_rate
FROM api_error_log
WHERE status_code = 409
  AND created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY);
```

---

## ✅ **Implementation Checklist**

### **Must-Do Items (Do Once, Protect Forever):**

- [ ] **Idempotency**
  - [ ] Add `idempotency_key` column to wip_log/token_event
  - [ ] UNIQUE index (id_job_task, idempotency_key)
  - [ ] Client: Generate UUID v4 per action
  - [ ] Server: Check duplicate before insert

- [ ] **Optimistic Locking**
  - [ ] Add `version` column to state tables
  - [ ] Update: WHERE id = ? AND version = ?
  - [ ] 409 response if version mismatch

- [ ] **Soft Lock**
  - [ ] Add `lock_owner`, `lock_expires_at` to flow_token
  - [ ] Check lock before start/resume
  - [ ] Auto-expire after 15 minutes

- [ ] **Local Queue**
  - [ ] IndexedDB setup (queue store)
  - [ ] Retry policy (exponential backoff)
  - [ ] Sync on reconnect

- [ ] **UI Safeguards**
  - [ ] Sticky banner (current work)
  - [ ] Disable button 3s after click
  - [ ] Confirm before switch
  - [ ] Undo last 3 actions

- [ ] **Supervisor Dashboard**
  - [ ] Dangling in_progress > 2h
  - [ ] Conflict inbox
  - [ ] Force-pause with reason
  - [ ] Audit trail

- [ ] **Validation Gates**
  - [ ] Cycle detector (client + server)
  - [ ] Orphan detector
  - [ ] BOM completeness check
  - [ ] QC gate enforcement

---

## 🧪 **Acceptance Tests (Critical)**

### **Test Suite:**

```javascript
// Test 1: Idempotency
test('duplicate submission with same key creates single event', async () => {
    const key = 'test-uuid-123';
    await submitEvent(key);
    await submitEvent(key); // Same key
    const events = await getEvents();
    expect(events.length).toBe(1);
});

// Test 2: Offline + Power off
test('power off 50ms after click, restart, event recorded once', async () => {
    clickComplete();
    await sleep(50);
    powerOff();
    powerOn();
    await sync();
    const events = await getEvents();
    expect(events).toHaveLength(1);
    expect(events[0].status).toBe('completed');
});

// Test 3: Concurrent start
test('two operators start same serial, second gets 409', async () => {
    const operator1 = startToken(tokenId, op1);
    const operator2 = startToken(tokenId, op2);
    
    await expect(operator1).resolves.toMatchObject({ok: true});
    await expect(operator2).rejects.toMatchObject({status: 409});
});

// Test 4: Pause wrong serial
test('pause wrong serial, undo restores state', async () => {
    await startToken(1, op1); // TOTE-001
    await pauseToken(2, op1);  // TOTE-002 (wrong!)
    await undoLastAction(op1);
    
    const token2 = await getToken(2);
    expect(token2.status).not.toBe('paused');
});

// Test 5: QC gate
test('complete without QC pass blocks routing', async () => {
    const node = {id: 10, qc_required: true};
    await completeToken(tokenId);
    
    const token = await getToken(tokenId);
    expect(token.status).toBe('qc_pending'); // Not 'completed'
    expect(token.current_node_id).toBe(10); // Not routed yet
    
    await qcPass(tokenId);
    const token2 = await getToken(tokenId);
    expect(token2.status).toBe('completed');
    expect(token2.current_node_id).toBe(11); // Routed!
});
```

---

## 📈 **Observability**

### **Structured Logging:**

```php
// Every event includes context
error_log(json_encode([
    'type' => 'wip_event',
    'event_id' => $eventId,
    'operator_id' => $operatorId,
    'device_id' => $deviceId,
    'app_version' => $appVersion,
    'idempotency_key' => $key,
    'client_seq' => $clientSeq,
    'latency_ms' => $latency,
    'duplicate' => $isDuplicate,
    'conflict' => $hadConflict
]));
```

### **Dashboards:**

```sql
-- Duplicate rate (last 24h)
CREATE VIEW v_duplicate_rate_24h AS
SELECT 
    DATE_FORMAT(created_at, '%Y-%m-%d %H:00') as hour,
    COUNT(*) as total,
    COUNT(DISTINCT idempotency_key) as unique_keys,
    ROUND((COUNT(*) - COUNT(DISTINCT idempotency_key)) / COUNT(*) * 100, 2) as duplicate_rate
FROM wip_log
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
GROUP BY hour;

-- Dangling work alert
CREATE VIEW v_dangling_work AS
SELECT 
    t.serial_number,
    o.name as operator_name,
    s.started_at,
    TIMESTAMPDIFF(HOUR, s.started_at, NOW()) as hours_stalled,
    n.node_name
FROM flow_token t
JOIN token_work_session s ON s.id_token = t.id_token
JOIN account o ON o.id_member = s.operator_user_id
JOIN routing_node n ON n.id_node = t.current_node_id
WHERE s.status = 'active'
  AND TIMESTAMPDIFF(HOUR, s.started_at, NOW()) > 2
ORDER BY hours_stalled DESC;
```

---

## 🎯 **Risk Mitigation Summary**

### **Automated Safeguards (Code):**
- ✅ Idempotency (duplicate prevention)
- ✅ Optimistic locking (conflict detection)
- ✅ Soft locks (gentle ownership)
- ✅ Auto-expire (abandoned work)
- ✅ Validation gates (QC, BOM, cycle)

### **UI/UX Safeguards:**
- ✅ Confirm dialogs (before destructive)
- ✅ Sticky banner (current work)
- ✅ Undo capability (last 3 actions)
- ✅ Disabled states (prevent mis-tap)
- ✅ Clear microcopy (Thai, simple)

### **Operational Safeguards:**
- ✅ Supervisor dashboard (review exceptions)
- ✅ Force actions (with audit)
- ✅ Monitoring (KPIs, alerts)
- ✅ Daily backups (restore capability)

---

## 🎓 **For Development Team**

### **When Building Any Feature:**

**Checklist:**
1. [ ] Does it handle offline? (local queue)
2. [ ] Does it prevent duplicates? (idempotency)
3. [ ] Does it detect conflicts? (optimistic lock)
4. [ ] Does it have clear UX? (microcopy, icons)
5. [ ] Does it have audit trail? (who, when, why)
6. [ ] Does it have acceptance test? (edge cases)

### **When Reviewing Code:**

**Red Flags:**
- ❌ No idempotency_key
- ❌ Direct state update (no event)
- ❌ No conflict handling (assume success)
- ❌ Silent failures (try-catch with no log)
- ❌ No button disable (rapid re-tap possible)

**Green Flags:**
- ✅ Event-sourced (immutable log)
- ✅ Idempotent (safe retry)
- ✅ Conflict-aware (409 handling)
- ✅ Logged errors (observable)
- ✅ UI safeguards (confirm, disable)

---

**Last Updated:** November 2, 2025  
**Status:** Active risk mitigation guide  
**Review:** Monthly or after incident

---

## 🏭 **Next Level: Production Hardening**

This playbook covers **50 risk scenarios**.

For **production hardening** (quality multipliers):
- 🔧 Engineering Hardening (feature flags, shadow mode, observability)
- 💾 Data Integrity & Recovery (disaster playbook, PITR)
- 🎨 UX Error Prevention (sticky context, smart defaults)
- 🚀 Operations (rollout strategy, supervisor playbook)
- 🔐 Security & Customer Trace (signed QR, trace portal)

→ See [`PRODUCTION_HARDENING.md`](PRODUCTION_HARDENING.md)

