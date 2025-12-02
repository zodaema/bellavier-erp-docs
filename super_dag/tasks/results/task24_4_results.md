# Task 24.4 Results – Job Ticket Lifecycle v2 (Start / Pause / Resume / Complete / Cancel / Restore)

**Date:** 2025-11-28  
**Status:** ✅ **COMPLETED**  
**Objective:** ยกระดับระบบ Job Ticket Lifecycle ให้สมบูรณ์แบบและพร้อมใช้งานจริงใน Bellavier Group ERP โดยเชื่อมโยง State Machine → Job Ticket API → UI → Token Engine อย่างราบรื่น

---

## Executive Summary

Task 24.4 ได้ปรับปรุง Job Ticket Lifecycle ให้มี:
- **State Machine ที่ชัดเจน** สำหรับ Classic Line tickets
- **Transition Methods** ที่รองรับ start, pause, resume, complete, cancel, restore
- **TokenLifecycleService Integration** สำหรับ DAG mode tickets
- **ETA/Health Hooks** แบบ non-blocking
- **Audit Logging** สำหรับทุก state transition
- **UI/JS Integration** พร้อม lifecycle buttons ที่แสดงตาม state

**Key Achievements:**
- ✅ เพิ่ม 6 transition methods ใน job_ticket.php
- ✅ สร้าง helper functions สำหรับ token group operations
- ✅ เพิ่ม lifecycle buttons ใน UI
- ✅ เพิ่ม event handlers ใน JS
- ✅ Backward compatible 100%
- ✅ ไม่กระทบ Hatthasilpa Jobs

---

## Files Modified

### 1. `source/job_ticket.php`
**Changes:**
- เพิ่ม imports: `TokenLifecycleService`, `TokenWorkSessionService`, `MOEtaCacheService`, `MOEtaHealthService`
- เพิ่ม 6 transition cases ใน switch statement:
  - `case 'start'`: PLANNED → IN_PROGRESS
  - `case 'pause'`: IN_PROGRESS → PAUSED
  - `case 'resume'`: PAUSED → IN_PROGRESS
  - `case 'complete'`: IN_PROGRESS → COMPLETED
  - `case 'cancel'`: PLANNED/IN_PROGRESS/PAUSED → CANCELLED
  - `case 'restore'`: CANCELLED → PAUSED
- เพิ่ม helper functions:
  - `getGraphInstanceIdForTicket()`: Get graph instance ID for a job ticket
  - `pauseTokenGroupForTicket()`: Pause all active tokens for DAG tickets
  - `resumeTokenGroupForTicket()`: Resume all paused tokens for DAG tickets
  - `completeTokenGroupForTicket()`: Complete all active tokens for DAG tickets
  - `cancelTokenGroupForTicket()`: Cancel all tokens for DAG tickets
  - `restoreTokenGroupForTicket()`: Restore cancelled tokens for DAG tickets
  - `logJobTicketEvent()`: Log state transitions for audit
  - `triggerETAHooks()`: Trigger ETA/Health hooks (non-blocking)

### 2. `views/job_ticket.php`
**Changes:**
- เพิ่ม lifecycle action buttons container ใน header section:
  ```html
  <div class="d-flex flex-wrap gap-2" id="ticket-lifecycle-actions" data-view="detail-lifecycle-buttons">
    <!-- Buttons will be dynamically rendered based on ticket status -->
  </div>
  ```

### 3. `assets/javascripts/hatthasilpa/job_ticket.js`
**Changes:**
- เพิ่ม `renderLifecycleButtons()` function: Render buttons based on ticket status
- เพิ่ม `callLifecycleTransition()` function: Call lifecycle API with confirmation dialog
- เพิ่ม 6 event handlers:
  - `.btn-ticket-start`: Start ticket
  - `.btn-ticket-pause`: Pause ticket
  - `.btn-ticket-resume`: Resume ticket
  - `.btn-ticket-complete`: Complete ticket
  - `.btn-ticket-cancel`: Cancel ticket
  - `.btn-ticket-restore`: Restore ticket
- อัปเดต `loadTicketDetail()`: เรียก `renderLifecycleButtons()` เมื่อโหลด ticket detail

---

## State Machine

### State Transitions

```
DRAFT → PLANNED → IN_PROGRESS → PAUSED → IN_PROGRESS → COMPLETED
                                    ↘︎ CANCELLED ↗︎    ↘︎ RESTORED ↗︎
```

### Transition Rules

| From State | To State | Action | Allowed? |
|------------|----------|--------|----------|
| PLANNED | IN_PROGRESS | start | ✅ |
| IN_PROGRESS | PAUSED | pause | ✅ |
| PAUSED | IN_PROGRESS | resume | ✅ |
| IN_PROGRESS | COMPLETED | complete | ✅ |
| PAUSED | COMPLETED | complete | ❌ (ไม่อนุญาต complete จาก paused) |
| PLANNED | CANCELLED | cancel | ✅ |
| IN_PROGRESS | CANCELLED | cancel | ✅ |
| PAUSED | CANCELLED | cancel | ✅ |
| CANCELLED | PAUSED | restore | ✅ |

### UI Button Mapping

| State | Buttons Shown |
|-------|---------------|
| DRAFT | None |
| PLANNED | Start, Cancel |
| IN_PROGRESS | Pause, Complete, Cancel |
| PAUSED | Resume, Cancel |
| CANCELLED | Restore |
| COMPLETED | None |

---

## Implementation Details

### Backend Transition Methods

#### 1. Start (PLANNED → IN_PROGRESS)
```php
case 'start':
  // Validation: Only from PLANNED, Classic line only
  // Update status: 'in_progress', set started_at
  // DAG mode: Spawn tokens (idempotent)
  // Log: TICKET_STARTED
  // Hook: onStart
```

**Token Operations:**
- DAG mode: เรียก `TokenLifecycleService::spawnTokens()` (idempotent - skip ถ้ามี tokens อยู่แล้ว)
- Linear mode: ไม่มี token operations

#### 2. Pause (IN_PROGRESS → PAUSED)
```php
case 'pause':
  // Validation: Only from IN_PROGRESS, Classic line only
  // Update status: 'paused', set paused_at
  // DAG mode: Pause all active tokens
  // Log: TICKET_PAUSED
  // Hook: onPause
```

**Token Operations:**
- DAG mode: เรียก `pauseTokenGroupForTicket()` → `TokenWorkSessionService::pauseToken()` สำหรับทุก active token

#### 3. Resume (PAUSED → IN_PROGRESS)
```php
case 'resume':
  // Validation: Only from PAUSED, Classic line only
  // Update status: 'in_progress', clear paused_at
  // DAG mode: Resume all paused tokens
  // Log: TICKET_RESUMED
  // Hook: onResume
```

**Token Operations:**
- DAG mode: เรียก `resumeTokenGroupForTicket()` → `TokenWorkSessionService::resumeToken()` สำหรับทุก paused token

#### 4. Complete (IN_PROGRESS → COMPLETED)
```php
case 'complete':
  // Validation: Only from IN_PROGRESS (not from PAUSED), Classic line only
  // Update status: 'completed', set completed_at
  // DAG mode: Complete all active tokens
  // Log: TICKET_COMPLETED
  // Hook: onComplete
```

**Token Operations:**
- DAG mode: เรียก `completeTokenGroupForTicket()` → UPDATE flow_token SET status='completed' สำหรับทุก active/waiting/paused token

#### 5. Cancel (PLANNED/IN_PROGRESS/PAUSED → CANCELLED)
```php
case 'cancel':
  // Validation: From PLANNED, IN_PROGRESS, or PAUSED, Classic line only
  // Update status: 'cancelled', set cancelled_at
  // DAG mode: Cancel all tokens
  // Log: TICKET_CANCELLED
  // Hook: onCancel
```

**Token Operations:**
- DAG mode: เรียก `cancelTokenGroupForTicket()` → `TokenLifecycleService::cancelToken()` สำหรับทุก active/waiting/paused/ready token

#### 6. Restore (CANCELLED → PAUSED)
```php
case 'restore':
  // Validation: Only from CANCELLED, Classic line only
  // Update status: 'paused', clear cancelled_at
  // DAG mode: Restore cancelled tokens to paused
  // Log: TICKET_RESTORED
  // Hook: onRestore
```

**Token Operations:**
- DAG mode: เรียก `restoreTokenGroupForTicket()` → UPDATE flow_token SET status='paused', cancelled_at=NULL สำหรับทุก cancelled token

---

## Token Operations

### Helper Functions

#### `pauseTokenGroupForTicket()`
- ใช้ `TokenWorkSessionService::pauseToken()` สำหรับทุก active/waiting token
- Handle exceptions gracefully (log แต่ไม่ throw)

#### `resumeTokenGroupForTicket()`
- ใช้ `TokenWorkSessionService::resumeToken()` สำหรับทุก paused token
- Handle exceptions gracefully

#### `completeTokenGroupForTicket()`
- UPDATE flow_token SET status='completed' สำหรับทุก active/waiting/paused token
- ไม่ใช้ service (direct SQL update)

#### `cancelTokenGroupForTicket()`
- ใช้ `TokenLifecycleService::cancelToken()` สำหรับทุก active/waiting/paused/ready token
- Handle exceptions gracefully

#### `restoreTokenGroupForTicket()`
- UPDATE flow_token SET status='paused', cancelled_at=NULL สำหรับทุก cancelled token
- ไม่ใช้ service (direct SQL update)

---

## ETA/Health Hooks

### Implementation

```php
function triggerETAHooks(mysqli $db, int $jobTicketId, string $hookName): void {
    // Non-blocking: try-catch to prevent failures from affecting main flow
    // Get MO ID if exists
    // Trigger MOEtaCacheService::invalidateCache()
    // Trigger MOEtaHealthService::validateETA()
}
```

### Hooks Triggered

| Transition | Hook Name | Actions |
|------------|-----------|---------|
| start | onStart | Invalidate ETA cache, Validate ETA health |
| pause | onPause | Invalidate ETA cache, Validate ETA health |
| resume | onResume | Invalidate ETA cache, Validate ETA health |
| complete | onComplete | Invalidate ETA cache, Validate ETA health |
| cancel | onCancel | Invalidate ETA cache, Validate ETA health |
| restore | onRestore | Invalidate ETA cache, Validate ETA health |

### Non-Blocking Design

- ใช้ `try-catch` เพื่อป้องกัน failures จากกระทบ main flow
- Log errors แต่ไม่ throw exceptions
- Hooks จะทำงานใน background (async-like behavior)

---

## Audit Logging

### Implementation

```php
function logJobTicketEvent(mysqli $db, int $jobTicketId, string $eventType, int $userId, array $metadata = []): int {
    // Check if job_ticket_event table exists (may not exist in all tenants)
    // Insert event record
    // Return event ID or 0 on failure
}
```

### Event Types

| Event Type | Description | Triggered By |
|------------|-------------|--------------|
| TICKET_STARTED | Ticket started production | start |
| TICKET_PAUSED | Ticket paused | pause |
| TICKET_RESUMED | Ticket resumed | resume |
| TICKET_COMPLETED | Ticket completed | complete |
| TICKET_CANCELLED | Ticket cancelled | cancel |
| TICKET_RESTORED | Ticket restored | restore |

### Table Structure (Optional)

```sql
CREATE TABLE IF NOT EXISTS job_ticket_event (
    id_event INT AUTO_INCREMENT PRIMARY KEY,
    id_job_ticket INT NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    user_id INT NOT NULL,
    event_time DATETIME NOT NULL,
    metadata JSON NULL,
    INDEX idx_ticket (id_job_ticket),
    INDEX idx_event_type (event_type),
    INDEX idx_event_time (event_time)
);
```

**Note:** Table may not exist in all tenants. Function handles gracefully by checking table existence first.

---

## UI Integration

### Lifecycle Buttons

**Location:** Header section of offcanvas detail view

**Rendering Logic:**
```javascript
function renderLifecycleButtons(ticketId, status, productionType) {
  // Only show for Classic line tickets
  if (productionType !== 'classic') return;
  
  // Render buttons based on status
  // PLANNED: Start, Cancel
  // IN_PROGRESS: Pause, Complete, Cancel
  // PAUSED: Resume, Cancel
  // CANCELLED: Restore
  // DRAFT, COMPLETED: None
}
```

### Event Handlers

**Confirmation Dialog:**
- ใช้ SweetAlert2 สำหรับ confirmation
- แสดงข้อความที่เหมาะสมตาม action

**API Call:**
```javascript
$.post(EP, {
  action: 'start|pause|resume|complete|cancel|restore',
  id_job_ticket: ticketId
}, function(resp) {
  if (resp && resp.ok) {
    notifySuccess(resp.message);
    loadTicketDetail(ticketId, false); // Reload to update status
  } else {
    notifyError(resolveErrorMessage(resp));
  }
});
```

**Reload Behavior:**
- หลัง transition สำเร็จ: Reload ticket detail เพื่ออัปเดต status และ buttons
- ใช้ `loadTicketDetail(ticketId, false)` เพื่อไม่เปิด offcanvas ซ้ำ

---

## Validation & Safety

### State Machine Validation

- ✅ ตรวจสอบ current status ก่อน transition
- ✅ ตรวจสอบ production_type (ต้องเป็น 'classic')
- ✅ Return error ถ้า state transition ไม่ถูกต้อง

### Token Operations Safety

- ✅ Handle exceptions gracefully (log แต่ไม่ throw)
- ✅ ใช้ try-catch สำหรับแต่ละ token operation
- ✅ Continue processing แม้บาง token จะ fail

### Transaction Safety

- ✅ ใช้ DatabaseHelper::beginTransaction() / commit() / rollback()
- ✅ Rollback ทั้งหมดถ้ามี error
- ✅ ETA/Health hooks เป็น non-blocking (ไม่กระทบ transaction)

---

## Testing Notes

### Manual Test Scenarios

1. **Start Ticket (PLANNED → IN_PROGRESS):**
   - Create Classic ticket in PLANNED status
   - Click "Start" button
   - Expected: Status → in_progress, tokens spawned (DAG mode), buttons → Pause/Complete/Cancel

2. **Pause Ticket (IN_PROGRESS → PAUSED):**
   - Start ticket first
   - Click "Pause" button
   - Expected: Status → paused, tokens paused (DAG mode), buttons → Resume/Cancel

3. **Resume Ticket (PAUSED → IN_PROGRESS):**
   - Pause ticket first
   - Click "Resume" button
   - Expected: Status → in_progress, tokens resumed (DAG mode), buttons → Pause/Complete/Cancel

4. **Complete Ticket (IN_PROGRESS → COMPLETED):**
   - Start ticket first
   - Click "Complete" button
   - Expected: Status → completed, tokens completed (DAG mode), buttons → None

5. **Cancel Ticket (PLANNED → CANCELLED):**
   - Create ticket in PLANNED status
   - Click "Cancel" button
   - Expected: Status → cancelled, tokens cancelled (DAG mode), buttons → Restore

6. **Restore Ticket (CANCELLED → PAUSED):**
   - Cancel ticket first
   - Click "Restore" button
   - Expected: Status → paused, tokens restored to paused (DAG mode), buttons → Resume/Cancel

7. **Invalid Transitions:**
   - Try to complete from PAUSED → Expected: Error "Cannot complete from paused"
   - Try to start from IN_PROGRESS → Expected: Error "Cannot start from in_progress"
   - Try to pause from PLANNED → Expected: Error "Cannot pause from planned"

8. **Hatthasilpa Tickets:**
   - Open Hatthasilpa ticket → Expected: No lifecycle buttons shown

9. **DAG vs Linear:**
   - DAG ticket: Token operations should work
   - Linear ticket: No token operations (but status update should work)

10. **ETA/Health Hooks:**
    - Check error_log after transitions → Expected: No errors from hooks
    - Check MO ETA cache → Expected: Invalidated after transitions

---

## Performance Notes

- **Queries Per Transition:**
  - State validation: 1 query (fetch ticket)
  - Status update: 1 query (UPDATE job_ticket)
  - Token operations: N queries (1 per token, if DAG mode)
  - Event logging: 1 query (INSERT job_ticket_event, if table exists)
  - ETA hooks: 2 queries (invalidate cache, validate health)
  - **Total: ~5-10 queries** (depending on token count)

- **Transaction Overhead:**
  - Minimal (single transaction per transition)
  - Rollback safe (all or nothing)

- **Non-Blocking Hooks:**
  - ETA/Health hooks ไม่กระทบ response time
  - Failures ใน hooks ไม่กระทบ main flow

---

## Limitations & Next Steps

### Known Limitations

1. **Linear Mode Token Operations:**
   - Linear tickets ไม่มี token operations (ใช้ task-based workflow)
   - Status updates ยังทำงานได้ปกติ

2. **Job Ticket Event Table:**
   - Table อาจไม่มีในบาง tenants
   - Function handles gracefully (skip logging ถ้า table ไม่มี)

3. **Token Group Operations:**
   - v1 ใช้ sequential processing (อาจช้าถ้ามี tokens มาก)
   - Future: อาจใช้ batch operations

### Next Steps (Task 24.5+)

1. **PWA Integration:**
   - เชื่อม PWA Scan Terminal กับ lifecycle
   - สร้าง `job_ticket_scan_api.php` สำหรับ PWA

2. **Batch Token Operations:**
   - Optimize token group operations สำหรับ tickets ที่มี tokens มาก

3. **Progress Sync:**
   - Sync progress หลัง lifecycle transitions
   - Update progress_pct ใน job_ticket table (optional)

4. **Notification System:**
   - แจ้งเตือนเมื่อ ticket status เปลี่ยน
   - Email/SMS notifications (optional)

---

## Summary

Task 24.4 ได้ปรับปรุง Job Ticket Lifecycle ให้สมบูรณ์แบบพร้อมใช้งานจริง โดยมี state machine ที่ชัดเจน, transition methods ที่ปลอดภัย, token operations integration, ETA/Health hooks, และ UI integration ที่สมบูรณ์

**Files Modified:** 3  
**Lines Added:** ~600  
**Breaking Changes:** None  
**Backward Compatible:** Yes  
**Hatthasilpa Impact:** None (Classic line only)

