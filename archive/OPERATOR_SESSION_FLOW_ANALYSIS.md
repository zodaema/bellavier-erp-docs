# 🔍 Operator Session Flow Analysis

**Created:** October 30, 2025  
**Purpose:** Design correct session lifecycle for Atelier vs Batch production modes  
**Status:** 🚨 Critical Design Decision Needed

---

## 📋 Table of Contents

1. [Business Context](#business-context)
2. [Current Problem](#current-problem)
3. [Database Structure](#database-structure)
4. [Current Implementation](#current-implementation)
5. [Use Cases & Scenarios](#use-cases--scenarios)
6. [Design Questions](#design-questions)
7. [Proposed Solutions](#proposed-solutions)
8. [Technical Implications](#technical-implications)
9. [Recommendation Request](#recommendation-request)

---

## 🏢 Business Context

### **Two Production Lines:**

#### **1. Atelier Line (Limited Edition - Handcrafted)**
- **Product:** High-end handcrafted leather goods
- **Volume:** Low (typically 10-50 pieces per job)
- **Process:** Manual crafting, each piece is unique
- **Price:** Premium (significantly higher than batch)
- **Customer Value:** Traceability
  - Customer can scan Serial Number to see:
    - ✅ Which craftsman made each piece
    - ✅ How many minutes spent on each step
    - ✅ Timeline (e.g., "08:00-08:25 = 25 minutes")
- **Example:** Limited edition handbag with serial number tracking

#### **2. Batch OEM Line (Mass Production)**
- **Product:** Standard products for retail stock
- **Volume:** High (100-1000+ pieces per job)
- **Process:** Assembly line, standardized
- **Price:** Economy (lower than Atelier)
- **Customer Value:** General tracking
  - Can scan Serial Number but less detail:
    - ✅ Date completed
    - ✅ Batch number
    - ❌ Per-piece timing not required
- **Example:** Wholesale tote bags for retail distribution

---

## 🚨 Current Problem

### **Symptom:**
When operator clicks "Complete 1 piece" button:
- ✅ WIP log created correctly
- ❌ **Operator session closes immediately** (`status='completed'`)
- ❌ **Progress shows 0%** (sessions with `status='completed'` not counted)
- ❌ Next "Complete" creates **new session** instead of continuing

### **User Report:**
> "แค่ 1 ชิ้นแล้วกด complete ระบบมันขึ้น progress 100% เลย ทั้งๆที่ค้างอีก 99 ชิ้น"

### **Root Cause:**
`OperatorSessionService->handleComplete()` marks session as `completed` immediately:
```php
UPDATE atelier_task_operator_session 
SET status = 'completed',  // ← Bug: Closes session too early!
    total_qty = total_qty + ?,
    completed_at = NOW()
WHERE id_session = ?
```

**Expected:** Session should remain `active` for accumulating work over time.

---

## 🗄️ Database Structure

### **atelier_job_ticket**
```sql
id_job_ticket
ticket_code (e.g., JT251030001)
job_name (e.g., "Tote Production")
target_qty (e.g., 50)
process_mode ('piece' or 'batch') ← Job-level default
status (planned, in_progress, completed, etc.)
```

### **atelier_job_task**
```sql
id_job_task
id_job_ticket (FK)
step_name (e.g., "Cutting", "Sewing", "Finishing")
sequence_no (1, 2, 3...)
process_mode ('piece' or 'batch') ← Task-level (can override job-level)
status (pending, in_progress, done, etc.)
assigned_to (operator user_id)
```

**Key Point:** `process_mode` can differ per task!
- Job: Atelier Line (piece)
- Task 1 (Cutting): batch mode (cut 50 pieces at once)
- Task 2 (Sewing): piece mode (sew one by one)
- Task 3 (Finishing): batch mode (inspect in batches)

### **atelier_wip_log**
```sql
id_wip_log
id_job_task (FK)
event_type (start, hold, resume, complete, fail, etc.)
event_time (timestamp) ← Important for serial tracking!
operator_user_id
qty (quantity completed in this event)
notes
deleted_at (soft-delete)
```

### **atelier_task_operator_session**
```sql
id_session
id_job_task (FK)
operator_user_id
operator_name
status ('active', 'paused', 'completed', 'cancelled')
total_qty (cumulative quantity from all complete events)
total_pause_minutes
started_at
paused_at
completed_at
cancelled_at
```

**Key Point:** Multiple operators can have separate sessions on the same task (concurrent work).

---

## 🔧 Current Implementation

### **OperatorSessionService->handleWIPEvent()**

```php
switch ($eventType) {
    case 'start':
        $this->handleStart($taskId, $operatorUserId, $operatorName);
        // Creates new session with status='active'
        break;
        
    case 'hold':
    case 'pause':
        $this->handlePause($taskId, $operatorUserId);
        // Changes status to 'paused', records paused_at
        break;
        
    case 'resume':
        $this->handleResume($taskId, $operatorUserId);
        // Changes status back to 'active', calculates pause duration
        break;
        
    case 'complete':
    case 'qc_pass':
        $this->handleComplete($taskId, $operatorUserId, $qty ?? 0);
        // ❌ BUG: Sets status='completed', completed_at=NOW()
        // This CLOSES the session immediately!
        break;
}
```

### **handleComplete() - Current (Buggy) Code:**

```php
private function handleComplete(int $taskId, int $operatorUserId, int $qty): void
{
    $session = $this->getActiveSession($taskId, $operatorUserId);
    
    if (!$session) {
        // No session exists, create and immediately complete
        $this->handleStart($taskId, $operatorUserId, null);
        $session = $this->getActiveSession($taskId, $operatorUserId);
    }
    
    // ❌ BUG: Closes session every time!
    $stmt = $this->db->prepare("
        UPDATE atelier_task_operator_session 
        SET status = 'completed',      // ← Problem!
            total_qty = total_qty + ?,
            completed_at = NOW()       // ← Problem!
        WHERE id_session = ?
    ");
    
    $stmt->bind_param('ii', $qty, $session['id_session']);
    $stmt->execute();
}
```

**What Happens:**
```
Complete Event 1 (qty=10)
→ Session 1: COMPLETED, total_qty=10, completed_at=08:30

Complete Event 2 (qty=15)
→ Session 1 already completed! (getActiveSession returns null)
→ Creates Session 2: ACTIVE, total_qty=0
→ Immediately: Session 2: COMPLETED, total_qty=15, completed_at=09:00

Result: 2 sessions instead of 1 cumulative session!
```

### **Progress Calculation:**

```php
SELECT COALESCE(SUM(total_qty), 0) as completed_qty
FROM atelier_task_operator_session
WHERE id_job_task = ?
AND status = 'completed'
```

**Why Progress Shows 0%:**
- Sessions keep closing immediately
- New session created with qty=0, then closed
- Query might not catch the latest session before commit (?)

---

## 🎭 Use Cases & Scenarios

### **Scenario 1: Batch Mode - Cutting (Target: 50)**

```
Day 1:
08:00 → ช่าง A: Start
       Session A: ACTIVE, qty=0

10:00 → ช่าง A: Complete 20 pieces
       ❓ Session A should be: ACTIVE (qty=20) OR COMPLETED?

12:00 → ช่าง A: Hold (lunch break)
       Session A: PAUSED, qty=20

13:00 → ช่าง A: Resume
       Session A: ACTIVE, qty=20

15:00 → ช่าง A: Complete 15 pieces (total 35)
       ❓ Session A should be: ACTIVE (qty=35) OR COMPLETED?

17:00 → ช่าง A: End of shift
       ❓ How to close session? New event "End Shift"?

Day 2:
08:00 → ช่าง A: Resume yesterday's work
       ❓ Use Session A (if not closed) OR create Session B?

10:00 → ช่าง A: Complete 16 pieces (total 51)
       ❓ Exceeds target (50) - Session closes? Task done?
```

**Questions:**
1. Should session close on each Complete event?
2. Should session close only at end of shift/day?
3. Should session close when total_qty >= target_qty?
4. How does operator indicate "I'm done working on this task"?

---

### **Scenario 2: Piece Mode - Sewing Atelier (Target: 50)**

```
Day 1:
08:00 → ช่างนำ: Start working on Bag #001

08:30 → ช่างนำ: Complete 1 piece (Bag #001 done)
       ❓ Session should: CLOSE (for timestamp) OR ACTIVE (continue)?
       
       If SESSION CLOSES:
       ✅ Can track: "Bag #001 by ช่างนำ, 30 min (08:00-08:30)"
       ❌ Creates many sessions (50 sessions for 50 bags)
       
       If SESSION STAYS ACTIVE:
       ✅ One session per operator (cleaner)
       ❌ Can't track per-piece timing from session
       ✅ BUT can track from WIP log timestamps!

08:35 → ช่างนำ: Start Bag #002 (or continue?)
08:58 → ช่างนำ: Complete 1 piece (Bag #002 done)

... repeat 48 more times ...

Week later:
       Session: COMPLETED, total_qty=50
       OR
       50 Sessions: Each COMPLETED, total_qty=1
```

**Key Question:** 
**How to track per-piece timing for Atelier line?**

**Option A:** Use session start/complete times
- 1 session = 1 piece
- Session times = piece times

**Option B:** Use WIP log event_time
- 1 session = multiple pieces  
- WIP log timestamps = piece times
- Calculate duration between consecutive complete events

---

### **Scenario 3: Concurrent Work (Multiple Operators)**

```
Task: Sewing (Target: 100)

ช่าง A:
08:00 → Start
       Session A: ACTIVE, qty=0

ช่าง B:
08:00 → Start  
       Session A: ACTIVE, qty=0
       Session B: ACTIVE, qty=0

ช่าง A:
12:00 → Complete 40 pieces
       Session A: ??? (ACTIVE or COMPLETED?)

ช่าง B:
12:30 → Complete 35 pieces
       Session B: ??? (ACTIVE or COMPLETED?)

Day 2:
ช่าง A: Resume work
       ❓ Use Session A (if still active) OR create Session C?
```

**Requirements:**
- Multiple operators can work simultaneously
- Each operator tracks their own progress
- Total progress = SUM(all sessions total_qty)
- Sessions should not interfere with each other

---

## ❓ Design Questions

### **Q1: What is a "Session"?**

**Option A:** Session = "One shift of work" (8 hours)
- Close: End of shift
- Duration: ~8 hours
- Qty: Whatever completed in that shift
- Multiple sessions per operator per task (one per day)

**Option B:** Session = "Operator's entire work on this task"
- Close: When operator done with task OR task status='done'
- Duration: Days or weeks
- Qty: Cumulative from start to finish
- One session per operator per task (across multiple days)

**Option C:** Session = "One work cycle" (e.g., completing one batch)
- Close: Each time "Complete" is clicked
- Duration: Minutes to hours
- Qty: Batch size (could be 1 for piece mode)
- Many sessions per operator per task

---

### **Q2: What does "Complete" event mean?**

**Option A:** "I finished working on X pieces" (intermediate recording)
- Session stays ACTIVE
- Can complete multiple times in one session
- Session closes separately (end shift / task done)

**Option B:** "I'm done with this work batch" (closing a work cycle)
- Session closes (status='completed')
- Next work = new session
- Many small sessions

**Option C:** Context-dependent
- Batch mode: Complete = record progress (session active)
- Piece mode: Complete = finish one piece (session closes)

---

### **Q3: How to track per-piece timing for Atelier?**

**Option A:** 1 Session = 1 Piece
- Session start/complete times = piece start/complete times
- Pros: Direct mapping, simple
- Cons: 50 sessions for 50 pieces (database heavy)

**Option B:** 1 Session = Multiple Pieces (use WIP log timestamps)
- WIP log event_time = piece completion time
- Calculate per-piece duration from consecutive complete events
- Pros: Clean session table, scalable
- Cons: Need to parse WIP logs for serial tracking

**Option C:** Hybrid (process_mode-dependent)
- Atelier piece mode: 1 session per piece (for timing)
- Batch mode: 1 session per operator (accumulative)

---

### **Q4: When should session close?**

**Option A:** Manual close (new "End Shift" button)
```
Events: Start, Hold, Resume, Complete, End Shift
- Complete: Add qty, session active
- End Shift: Close session (operator's choice)
```

**Option B:** Auto-close when target reached
```
if (session.total_qty >= task.target_qty) {
    status = 'completed';
}
```

**Option C:** Auto-close on task done
```
When task status changes to 'done':
→ Close all active sessions for this task
```

**Option D:** Time-based (e.g., end of day)
```
Cron job: Close all paused sessions older than 24 hours
```

---

## 💼 Use Cases & Scenarios

### **Use Case 1: Batch Cutting (50 pieces, batch mode)**

```
Target: 50 pieces
Operator: ช่าง A
Task process_mode: 'batch'

Timeline:
├─ Day 1
│  ├─ 08:00 - Start work
│  │  Session A: ACTIVE, qty=0
│  │
│  ├─ 12:00 - Complete 30 pieces (first batch)
│  │  Expected: Session A stays ACTIVE, total_qty=30
│  │  Progress: 30/50 = 60%
│  │
│  ├─ 12:00 - Hold (lunch)
│  │  Session A: PAUSED, qty=30
│  │
│  ├─ 13:00 - Resume
│  │  Session A: ACTIVE, qty=30
│  │
│  └─ 17:00 - End of shift (qty still 30)
│     ❓ Session A: Should remain PAUSED for tomorrow?
│
└─ Day 2
   ├─ 08:00 - Resume work
   │  ❓ Use Session A OR create Session B?
   │
   ├─ 10:00 - Complete 21 pieces (total 51, exceeds target by 1)
   │  Expected: Session A: total_qty=51
   │  Progress: 51/50 = 102% (within 5% tolerance ✅)
   │
   └─ 10:00 - Task done
      ❓ Session A: Auto-close OR manual close?
```

**Expected Behavior:**
- **1 Session** for ช่าง A across 2 days
- Session closes when: Task done OR operator explicitly ends
- Progress calculation: 51/50 = 102% ✅

---

### **Use Case 2: Atelier Sewing (50 bags, piece mode)**

```
Target: 50 bags (each with unique serial number)
Operator: ช่างนำ
Task process_mode: 'piece'

Requirement:
Customer scans SN001 → Shows:
  "Sewing by ช่างนำ, 30 minutes, Oct 30 08:00-08:30"

Timeline:
├─ 08:00 - Start Bag #001 (SN001)
│  ❓ Session 1: ACTIVE, qty=0
│
├─ 08:30 - Complete Bag #001 (qty=1)
│  ❓ Session 1: COMPLETED (for timing) OR ACTIVE (continue)?
│  
│  If COMPLETED:
│  ✅ Session timing = Bag timing (08:00-08:30 = 30 min)
│  ❌ Need to create Session 2 for Bag #002
│  Result: 50 sessions for 50 bags
│  
│  If ACTIVE:
│  ❌ Session timing ≠ Bag timing (session spans multiple bags)
│  ✅ One session, clean
│  ❓ How to get Bag #001 timing? → Use WIP log!
│
├─ 08:35 - Start Bag #002 (SN002) (or continue?)
│
├─ 09:02 - Complete Bag #002 (qty=1)
│
... repeat 48 more times ...
│
└─ Week later - Bag #050 completed
   Progress: 50/50 = 100%
   Sessions: 1 OR 50?
```

**Critical Question:**
**How to track per-bag timing for serial number display?**

**Option A:** 1 Session per Bag
- Pros: Direct timing (session.started_at → session.completed_at)
- Cons: 50 sessions (database heavy, complex queries)

**Option B:** 1 Session + WIP Log Timestamps
- Session: One continuous session (total_qty=50)
- Timing: Parse WIP logs (consecutive complete events)
  - Bag #001: WIP log event_time difference
  - Bag #002: Next WIP log event_time difference
- Pros: Clean session table, scalable
- Cons: Requires WIP log parsing for serial tracking

---

### **Use Case 3: Concurrent Operators (4 people, batch mode)**

```
Task: Assembly (Target: 200)
Operators: ช่าง A, B, C, D
Task process_mode: 'batch'

Day 1:
08:00 → All 4 start
       Session A, B, C, D: ACTIVE, qty=0 each

12:00 → Results:
       ช่าง A: Complete 45 pieces → Session A: qty=45
       ช่าง B: Complete 50 pieces → Session B: qty=50
       ช่าง C: Complete 40 pieces → Session C: qty=40
       ช่าง D: Complete 48 pieces → Session D: qty=48
       
Total Progress: 183/200 = 91.5%

13:00 → ช่าง A: Complete 20 more (total 65)
       Total Progress: 203/200 = 101.5%
       ❓ Should system auto-close all sessions?
       ❓ OR allow continuing within tolerance (210 max)?

17:00 → End of shift
       ❓ Sessions: PAUSED OR COMPLETED?

Day 2:
08:00 → Only ช่าง A and B return
       ❓ Use Session A, B OR create new sessions?
       ❓ Session C, D: Should they auto-close (abandoned)?
```

**Questions:**
- Should sessions auto-close when task reaches 100%?
- Should sessions auto-close when task status='done'?
- How to handle abandoned sessions (operator doesn't return)?

---

## 🎯 Design Questions (For AI Analysis)

### **Primary Questions:**

1. **Session Lifecycle:**
   - When should a session close?
   - Should it differ by process_mode (piece vs batch)?

2. **Complete Event Behavior:**
   - Should it close the session?
   - Should it only add qty to active session?

3. **Serial Number Tracking (Atelier):**
   - Use session timestamps OR WIP log timestamps?
   - Is 1 session per piece acceptable?

4. **Multi-day Work:**
   - Should sessions span multiple days?
   - Should they close at end of shift?

5. **Progress Calculation:**
   - SUM(completed sessions) OR SUM(all sessions including active)?
   - When to mark task as 'done'?

---

## 💡 Proposed Solutions

### **Solution 1: Current Buggy Behavior (NOT Recommended)**

```php
handleComplete() {
    SET status='completed', completed_at=NOW()
}
```

**Result:**
- ❌ 1 complete = 1 new session
- ❌ Progress calculation broken
- ❌ Can't accumulate work over time

---

### **Solution 2: Never Close on Complete (Accumulative)**

```php
handleComplete(task, operator, qty) {
    session = getActiveSession(task, operator);
    
    // Just add qty, don't close!
    UPDATE session 
    SET total_qty = total_qty + qty
    // status stays 'active' or 'paused'
}

// New method: Close session explicitly
handleEndSession(task, operator) {
    UPDATE session 
    SET status='completed', completed_at=NOW()
}
```

**When to call handleEndSession:**
- Option A: New UI button "End Shift" / "Close Session"
- Option B: Auto when task status='done'
- Option C: Auto when operator starts different task
- Option D: Cron job (daily cleanup)

**Pros:**
- ✅ Natural accumulation (30 → 51 → 80...)
- ✅ Works for both batch and piece modes
- ✅ Progress shows correctly

**Cons:**
- ❓ When to close abandoned sessions?
- ❓ Atelier per-piece timing needs WIP log parsing

---

### **Solution 3: Process Mode Dependent**

```php
handleComplete(task, operator, qty) {
    if (task.process_mode === 'piece') {
        // Atelier mode: Close session for timing
        UPDATE session SET status='completed', total_qty+=qty, completed_at=NOW()
    }
    else if (task.process_mode === 'batch') {
        // Batch mode: Keep active for accumulation
        UPDATE session SET total_qty+=qty
        // Status stays active
    }
}
```

**Pros:**
- ✅ Handles both business models
- ✅ Atelier: Per-piece session timing
- ✅ Batch: Accumulative session

**Cons:**
- ❌ Atelier: 50 sessions for 50 pieces (DB heavy)
- ❓ What if piece-mode task has 1000 pieces?

---

### **Solution 4: Hybrid (Session + WIP Log Timing)**

```php
handleComplete(task, operator, qty) {
    // Always accumulate in session
    UPDATE session SET total_qty = total_qty + qty
    // Never close on complete
}

// For Atelier serial tracking:
function getSerialTiming(serialNumber) {
    // Query WIP logs for this serial
    SELECT event_time as completed_at, operator_name
    FROM atelier_wip_log
    WHERE serial_number = ? 
    AND event_type='complete'
    
    // Calculate start time from previous event or session start
}
```

**Pros:**
- ✅ Clean session table (one session per operator)
- ✅ Scalable for high-volume Atelier
- ✅ Detailed timing from WIP logs
- ✅ Works for both modes

**Cons:**
- Requires serial_number field in WIP log
- Need to parse WIP logs for timing (more complex)

---

## 🔬 Technical Implications

### **Database Impact:**

| Approach | Sessions per Task (100 pcs) | Query Complexity |
|----------|----------------------------|------------------|
| Close per Complete | 100+ sessions | High (many rows) |
| Never Close | 1-5 sessions | Low (few rows) |
| Process Mode Dependent | 1-100 (depends) | Medium |
| Hybrid | 1-5 sessions | Medium (join WIP logs) |

### **Performance:**

**Current (Buggy):**
```sql
SELECT SUM(total_qty) FROM sessions WHERE task=X AND status='completed'
→ Returns random values (sessions close prematurely)
```

**Solution 2 (Never Close):**
```sql
SELECT SUM(total_qty) FROM sessions WHERE task=X AND status IN ('active','paused','completed')
→ Correct cumulative value
```

### **Serial Number Tracking:**

**For Atelier Line customer scan:**

**Method 1:** Session-based
```sql
-- Need 1 session per piece
SELECT started_at, completed_at, operator_name, 
       TIMESTAMPDIFF(MINUTE, started_at, completed_at) as duration
FROM atelier_task_operator_session
WHERE serial_number = 'SN001'  -- Need to add this field!
```

**Method 2:** WIP Log-based
```sql
-- Use WIP logs for timing
SELECT event_time, operator_name, qty
FROM atelier_wip_log
WHERE event_type='complete'
AND notes LIKE '%SN001%'  -- Or dedicated serial_number field
ORDER BY event_time
-- Calculate duration from consecutive events
```

---

## 🎯 Recommendation Request

**Dear AI Analyst,**

Please analyze the above scenarios and recommend:

1. **Session Lifecycle Design:**
   - When should sessions close?
   - Should it differ by process_mode?

2. **Complete Event Behavior:**
   - Should it close session immediately?
   - Should it only accumulate qty?

3. **Atelier Per-Piece Tracking:**
   - Best method to track per-piece timing?
   - Accept 1 session per piece OR use WIP log parsing?

4. **Multi-day Work:**
   - How to handle sessions spanning multiple days?
   - Auto-close or keep open?

5. **Abandoned Sessions:**
   - How to detect and handle?
   - Auto-close after X hours?

---

## 📐 Design Constraints

### **Must Have:**
- ✅ Support concurrent operators (multiple people on same task)
- ✅ Accurate progress calculation (real-time)
- ✅ Handle both batch and piece modes
- ✅ Work across multiple days
- ✅ Atelier: Track per-piece timing for serial numbers
- ✅ Prevent over-production (tolerance system already implemented)

### **Nice to Have:**
- Clean database (avoid hundreds of sessions)
- Simple UI (minimal buttons)
- Backward compatible
- Performance optimized

### **Technical Limitations:**
- MySQL database (not PostgreSQL)
- PHP 8.2 backend
- Must use existing tables (migrations OK for new fields)
- Multi-tenant system

---

## 🧪 Current Data (Real Production DB)

**Task ID 9 (Target: 100, process_mode: 'piece')**

**WIP Logs:**
```
id_wip_log | event_type | qty  | time
52         | complete   | 101  | 21:54  ← Latest
51         | start      | 1    | 21:34
50         | complete   | 1    | 21:27
49         | fail       | 5    | 21:15
48         | resume     | 1    | 21:15
47         | hold       | 1    | 21:14
...
```

**Sessions (Current - BROKEN):**
```
id_session | status    | total_qty | started_at | completed_at
23         | completed | 101       | 21:34      | 21:54
22         | completed | 1         | 21:14      | 21:27
21         | completed | 1         | 21:07      | 21:10
```

**Problem:**
- 3 separate sessions instead of 1 cumulative!
- Progress calculation: SUM where status='completed' = 103
- But API shows: 0% (bug in query or timing issue)

---

## 🎨 Proposed Flow Diagrams

### **Flow A: Batch Mode (Recommended)**

```
┌─────────────┐
│  Start Work │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ Session: ACTIVE │
│ qty = 0         │
└──────┬──────────┘
       │
       ▼
┌──────────────────┐
│ Complete 30 pcs  │◄───┐
│ qty += 30        │    │ Repeat
│ Status: ACTIVE   │    │ (accumulate)
└──────┬───────────┘    │
       │                │
       ├─ Hold/Resume ──┘
       │
       ▼
┌──────────────────┐
│ End Shift OR     │
│ Task Done        │
└──────┬───────────┘
       │
       ▼
┌─────────────────────┐
│ Session: COMPLETED  │
│ total_qty = 51      │
└─────────────────────┘
```

### **Flow B: Piece Mode (Option 1 - Session per Piece)**

```
For each piece:
  ┌─────────────┐
  │ Start Piece │
  └──────┬──────┘
         │
         ▼
  ┌────────────────┐
  │ Session: ACTIVE│
  │ qty = 0        │
  └──────┬─────────┘
         │
         ▼
  ┌──────────────────┐
  │ Complete 1 piece │
  │ qty = 1          │
  └──────┬───────────┘
         │
         ▼
  ┌──────────────────────┐
  │ Session: COMPLETED   │
  │ Duration: 30 min     │ ← Used for serial tracking
  └──────────────────────┘

Repeat 50 times = 50 sessions
```

### **Flow C: Piece Mode (Option 2 - WIP Log Timing)**

```
┌─────────────┐
│  Start Work │
└──────┬──────┘
       │
       ▼
┌──────────────────┐
│ Session: ACTIVE  │
│ qty = 0          │
└──────┬───────────┘
       │
       ▼
┌───────────────────────┐
│ Complete Bag #001     │
│ WIP Log: 08:30, qty=1 │◄───┐
│ Session: qty += 1     │    │
│ Status: ACTIVE        │    │ Repeat
└───────┬───────────────┘    │ (accumulate)
        │                    │
        ├────────────────────┘
        │
        ▼
┌──────────────────────┐
│ End of Task          │
└──────┬───────────────┘
       │
       ▼
┌─────────────────────────┐
│ Session: COMPLETED      │
│ total_qty = 50          │
└─────────────────────────┘

Serial Tracking:
Query WIP logs for timing:
  Bag #001: event_time[1] - session.started_at = 30 min
  Bag #002: event_time[2] - event_time[1] = 27 min
  ...
```

---

## 🔍 Questions for Decision

### **For Batch Mode:**
1. Should "Complete" event close the session?
   - [ ] Yes (close every time) → Many sessions
   - [ ] No (accumulate) → One session ← **Recommended**

2. When should batch mode session close?
   - [ ] Manual (new "End Shift" button)
   - [ ] Auto when task done
   - [ ] Auto when operator starts different task
   - [ ] Time-based (end of day)

### **For Piece Mode (Atelier):**
1. How to track per-piece timing for serial numbers?
   - [ ] 1 Session per piece (session timestamps)
   - [ ] 1 Session total (WIP log timestamps) ← **Recommended**
   - [ ] Add serial_number field to session table

2. Should "Complete 1 piece" close the session?
   - [ ] Yes (for direct timing)
   - [ ] No (accumulate, use WIP logs for timing) ← **Recommended**

### **For Progress Calculation:**
1. Which sessions to count?
   - [ ] Only `status='completed'`
   - [ ] Include `status IN ('active','paused','completed')` ← **Recommended**

2. When to mark task as 'done'?
   - [ ] When progress >= 100%
   - [ ] When progress >= 100% AND all sessions closed
   - [ ] Manual only

---

## 🚀 Recommended Solution (Pending Approval)

### **Design Principles:**
1. **Session = Operator's continuous work on a task**
   - Spans multiple days if needed
   - Closes when: Task done OR operator explicitly ends OR auto-cleanup

2. **Complete Event = "Record completed quantity"**
   - Does NOT close session
   - Accumulates in `total_qty`
   - Works same for both batch and piece modes

3. **Per-Piece Timing = WIP Log based**
   - Session stays open
   - Parse WIP log `event_time` for serial tracking
   - Scalable for both 10 pieces and 1000 pieces

4. **Session Close Triggers:**
   - Auto: When task status changes to 'done'
   - Auto: When operator starts different task
   - Manual: New "End Session" button (optional)
   - Cleanup: Cron job for abandoned sessions (>7 days)

### **Code Changes Required:**

```php
handleComplete(task, operator, qty) {
    // Never close session, just accumulate
    UPDATE atelier_task_operator_session 
    SET total_qty = total_qty + ?
    WHERE id_session = ?
    // NO status='completed'!
}

// New methods:
handleEndSession(task, operator) {
    UPDATE session SET status='completed', completed_at=NOW()
}

autoCloseSessionsOnTaskDone(taskId) {
    // When task.status = 'done'
    UPDATE sessions SET status='completed', completed_at=NOW()
    WHERE id_job_task=? AND status IN ('active','paused')
}
```

**Progress Query:**
```php
// Include active sessions!
SELECT SUM(total_qty) 
FROM atelier_task_operator_session
WHERE id_job_task=? 
AND status IN ('active','paused','completed')  // ← Changed!
```

---

## 📊 Expected Behavior After Fix

### **Batch Mode Example:**

```
Day 1:
08:00 Start → Session: ACTIVE, qty=0
12:00 Complete 30 → Session: ACTIVE, qty=30 ✅
17:00 End shift → Session: PAUSED, qty=30 ✅

Day 2:
08:00 Resume → Session: ACTIVE, qty=30 ✅
12:00 Complete 21 → Session: ACTIVE, qty=51 ✅
12:00 Task done → Session: COMPLETED, qty=51 ✅

Progress: 51/50 = 102% ✅
Sessions: 1 total ✅
```

### **Piece Mode Example (Atelier):**

```
Day 1:
08:00 Start → Session: ACTIVE, qty=0
08:30 Complete 1 → WIP Log: event_time=08:30, qty=1
                → Session: ACTIVE, qty=1 ✅
09:00 Complete 1 → WIP Log: event_time=09:00, qty=1
                → Session: ACTIVE, qty=2 ✅
...
17:00 End shift → Session: PAUSED, qty=8 ✅

Serial Tracking (Bag #001):
Query: SELECT event_time FROM atelier_wip_log 
       WHERE event_type='complete' ORDER BY event_time LIMIT 1
Result: 08:30
Duration: 08:30 - 08:00 (session start) = 30 min ✅

Sessions: 1 total ✅
WIP Logs: 8 events (one per piece) ✅
```

---

## ✅ Action Items (If Approved)

1. **Fix OperatorSessionService->handleComplete()**
   - Remove `status='completed'`
   - Remove `completed_at=NOW()`
   - Keep only `total_qty += qty`

2. **Update Progress Calculation**
   - Include `status IN ('active','paused','completed')`

3. **Add Session Auto-close**
   - Trigger: When task status='done'
   - Close all active/paused sessions

4. **Optional: Add "End Session" Button**
   - For manual session closure
   - Or rely on auto-close only

5. **Update Tests**
   - Fix integration tests
   - Add test for multi-day accumulation

6. **Update Documentation**
   - Explain session lifecycle
   - Document WIP log timing for serials

---

## 🙏 **Request for Decision**

**คุณ:**
1. เห็นด้วยกับ Recommended Solution ไหม?
2. ต้องการเพิ่ม "End Session" button ไหม? หรือ auto-close พอ?
3. Serial tracking ใช้ WIP log timestamps ได้ไหม? (ไม่ต้อง 1 session per piece)

**หรือมี flow อื่นที่ต้องการ?**

---

**ไฟล์นี้พร้อมให้ AI คนอื่นอ่านและวิเคราะห์แล้วครับ!** 📄
