# Phase 2.5: People Monitor - Concept & Design

**Version:** 1.1 (Enhanced with External Review)  
**Status:** 📋 Planned (Implement after Phase 2)  
**Priority:** High (Command Center for Managers)  
**Estimated Time:** 18 hours (2.5 days) - Revised  
**Prerequisite:** Phase 2 Complete (Team Integration)  
**Source:** User Idea + 2x External AI Reviews

**Revision Notes:**
- ✅ Added 13 critical improvements from external review
- ✅ Clock skew & timezone handling
- ✅ Overlapping leave validation
- ✅ PIN override confirmation (2-tier)
- ✅ Performance query optimization (CTE)
- ✅ Data rotation strategy
- ✅ Permission & PII protection
- ✅ 10 additional acceptance tests
- ✅ Alert bar summary
- ✅ reason_code enum structure

---

## 🎯 **Vision**

**"เห็นทุกคนในองค์กร ในตารางเดียว - ทำงาน, ว่าง, ลา, อยู่ทีมไหน"**

ให้ Manager มี **Real-time Command Center** เห็น:
- ✅ ใครทำอะไรอยู่ (Token, Job, Node)
- ✅ ใครว่างพร้อมรับงาน
- ✅ ใครลาป่วย/ลาหยุด (Schedule)
- ✅ อยู่ทีมไหน (หรือยังไม่มีทีม)
- ✅ จัดการ Leave/Assign ได้ทันที

---

## 📱 **UI Location (Recommended)**

### **Primary: Manager Assignment → Tab "People"**
```
Manager Assignment Tabs:
├─ Tokens (existing)
├─ Plans (existing)
└─ People (NEW) ← Full-featured People Monitor
```

**เหตุผล:**
- ✅ Manager Assignment = Run-time / Dispatch Center
- ✅ ต้องเห็นคนจริง ณ ตอนนี้
- ✅ Assign/Override ได้ทันที

---

### **Secondary: Team Management → Panel "People Now"**
```
Team Management:
├─ Team Cards (existing)
├─ Team Navigator (existing)
└─ People Now Panel (NEW) ← Compact view with "Open Full" button
```

**เหตุผล:**
- ✅ Team Management = Setup / Structure
- ✅ ดูภาพรวมสมาชิก
- ✅ Link to full monitor

---

## 🗄️ **Database Schema**

### **1. member_leave Table (NEW)** ✏️ Enhanced
```sql
CREATE TABLE member_leave (
    id_leave INT AUTO_INCREMENT PRIMARY KEY,
    id_member INT NOT NULL COMMENT 'FK → account.id_member',
    leave_type ENUM('sick','personal','vacation','training','other') NOT NULL,
    reason_code ENUM('illness','family','annual','medical','emergency','other') NULL 
        COMMENT 'Standardized reason (for HR stats)', -- ✅ NEW
    reason_text VARCHAR(255) NULL COMMENT 'Optional detailed reason (PII - mask on export)', -- ✅ RENAMED
    start_at DATETIME NOT NULL COMMENT 'Leave start (server timezone)',
    end_at DATETIME NOT NULL COMMENT 'Leave end (server timezone)',
    approved_by INT NULL COMMENT 'Manager who approved',
    created_by INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_member_dates (id_member, start_at, end_at),
    INDEX idx_current (start_at, end_at),  -- For "on leave now" queries
    INDEX idx_reason_code (reason_code, start_at)  -- ✅ NEW: For HR reports
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**Business Rules:** ✅ NEW
- ✅ No overlapping leaves: Validate `(new.start < existing.end) AND (new.end > existing.start)`
- ✅ Auto-pause active sessions when leave created
- ✅ Block auto-assignment if on leave NOW
- ✅ Allow manual override with 2-tier confirmation

### **2. Use Existing team_member columns (Phase 2)**
- ✅ `is_available` - Manual flag
- ✅ `unavailable_until` - Date
- ✅ `unavailable_reason` - Text

---

## 🔧 **API Endpoints (3 new)**

### **1. people_monitor_list**
**Purpose:** Get all people with real-time status

**Request:**
```javascript
POST team_api.php
{
    action: 'people_monitor_list',
    team_id: null,          // Filter by team (optional)
    status: '',             // Filter by status (optional)
    production_type: '',    // Filter by production mode (optional)
    q: '',                  // Search name (optional)
    page: 1,
    size: 50
}
```

**Response:** ✏️ Enhanced
```json
{
    "ok": true,
    "data": [{
        "id_member": 101,
        "name": "สมชาย",
        "username": "somchai",  // ✅ Mask if no people.view_detail permission
        "teams": ["ทีมตัดวัสดุ A", "ทีม QC"],
        "team_ids": [1, 5],
        "production_modes": ["hatthasilpa", "oem"],
        "status": "working",
        "status_detail": "Token #T-4321 · Sewing · started 10:42",
        "workload_tokens": 3,
        "workload_pct": 30,
        "workload_oem": 15,
        "workload_hatthasilpa": 15,
        "current_job": "JOB-2025-1106-001",
        "current_node": "Sewing (Flat-bed)",
        "current_node_id": 15,
        "last_event_at": "2025-11-06 10:42:13",
        "is_available": 1,
        "on_leave_now": false,
        "leave_type": null,
        "leave_reason_code": null,  // ✅ NEW: For display
        "leave_until": null,
        "next_leave_window": "2025-11-09 09:00–17:00",
        "pinned_to_nodes": [12, 15],  // ✅ NEW: Show if member has PIN assignments
        "has_override_permission": true  // ✅ NEW: Can assign to unavailable
    }],
    "server_time": "2025-11-06T14:05:00+07:00",  // ✅ Use for client clock sync
    "summary": {  // ✅ NEW: Alert bar data
        "total": 45,
        "available": 22,
        "working": 18,
        "paused": 3,
        "leave": 2,
        "unavailable": 0
    },
    "page": 1,
    "total_pages": 1
}
```

**Status Logic:** ✏️ Enhanced
```php
// Priority order (STRICT - don't change):
1. member_leave (server_now BETWEEN start_at AND end_at) → 'sick'/'leave'/'vacation'
   ✅ Use server_time, not client NOW() (avoid timezone issues)
2. is_available = 0 → 'unavailable'
3. token_work_session (is_open=1, paused_at IS NULL) → 'working'
4. token_work_session (is_open=1, paused_at IS NOT NULL) → 'paused'
5. Default → 'available'

// ✅ NEW: Server time sync
$serverTime = new DateTime('now', new DateTimeZone('Asia/Bangkok'));
$serverTimeStr = $serverTime->format('Y-m-d H:i:s');

// Check leave with server time
$onLeave = db_fetch_one($db, "
    SELECT leave_type, reason_code, end_at
    FROM member_leave
    WHERE id_member = ?
      AND ? BETWEEN start_at AND end_at
    ORDER BY start_at DESC
    LIMIT 1
", [$memberId, $serverTimeStr]);
```

---

### **2. member_leave_create/delete/list** ✏️ Enhanced
**Purpose:** Manage leave schedules with validation

**Create:**
```php
POST team_api.php
{
    action: 'member_leave_create',
    id_member: 101,
    leave_type: 'sick',
    reason_code: 'illness',  // ✅ NEW: Standardized (for HR)
    reason_text: 'ไข้สูง',   // ✅ NEW: Optional detail (PII)
    start_at: '2025-11-06 14:00:00',
    end_at: '2025-11-06 18:00:00'
}
```

**Validation Steps:** ✅ NEW
```php
// 1. Check overlapping leave
$overlap = db_fetch_one($db, "
    SELECT id_leave 
    FROM member_leave 
    WHERE id_member = ?
      AND (
          (? < end_at AND ? > start_at)  -- New leave overlaps existing
      )
", [$memberId, $newStart, $newEnd]);

if ($overlap) {
    json_error('Leave period overlaps with existing leave', 400);
}

// 2. Check active sessions
$activeSession = db_fetch_one($db, "
    SELECT id_session, id_token
    FROM token_work_session
    WHERE operator_user_id = ?
      AND is_open = 1
    LIMIT 1
", [$memberId]);

if ($activeSession) {
    // Auto-pause session
    require_once __DIR__ . '/service/TokenWorkSessionService.php';
    $sessionService = new \BGERP\Service\TokenWorkSessionService($db);
    $sessionService->pauseToken(
        $activeSession['id_token'], 
        $memberId, 
        'Auto-paused: Member on leave'
    );
    
    // Log event
    error_log("Auto-paused session {$activeSession['id_session']} for member {$memberId} (leave created)");
}

// 3. Set availability
$stmt = $db->prepare("
    UPDATE team_member 
    SET is_available = 0, 
        unavailable_reason = 'On leave',
        unavailable_until = ?
    WHERE id_member = ?
");
$stmt->bind_param('si', $endDate, $memberId);
$stmt->execute();

// 4. Create leave record
$stmt = $db->prepare("
    INSERT INTO member_leave 
    (id_member, leave_type, reason_code, reason_text, start_at, end_at, created_by)
    VALUES (?, ?, ?, ?, ?, ?, ?)
");
// ... execute

// 5. Log decision
$stmt = $db->prepare("
    INSERT INTO assignment_decision_log 
    (id_token, event, source, decision_reason, selected_member_id)
    VALUES (NULL, 'member_leave_created', 'people_monitor', ?, ?)
");
$reason = "Member {$memberName} on leave ({$leaveType}) from {$start} to {$end}";
$stmt->bind_param('si', $reason, $memberId);
$stmt->execute();
```

**Auto-actions on create:**
- ✅ Validate no overlapping leaves
- ✅ Auto-pause active sessions (with log)
- ✅ Set is_available = 0 automatically
- ✅ Update unavailable_until
- ✅ Log decision for audit

---

### **3. people_monitor_set_availability**
**Purpose:** Quick toggle availability

```php
POST team_api.php
{
    action: 'people_monitor_set_availability',
    id_member: 101,
    is_available: 0,
    note: 'เครื่องมือเสีย'
}
```

---

## 🎨 **UI Design (Summary)**

### **Full Mode (Manager Assignment):**
```
People Monitor Tab:
┌────────────────────────────────────────────────────────────┐
│ Filters: [Team ▼] [OEM|Hatt|Hybrid] [Status ▼] [🔍 Search]│
├────────────────────────────────────────────────────────────┤
│ Table (DataTable - server-side):                           │
│ ┌────┬────────┬──────┬────────┬──────┬──────────┬────────┐│
│ │Mbr │Teams   │Status│Workload│Work  │Last Event│Actions ││
│ ├────┼────────┼──────┼────────┼──────┼──────────┼────────┤│
│ │สมชาย│Sew A   │🔵 Wrk│███ 30%│T-432│10:42 am  │Assign..││
│ │สมหญิง│Cut B,QC│🟢 Avl│░░░ 0% │-    │-         │Assign..││
│ │สมศักดิ์│-      │🔴 Sick│░░░ 0%│-    │Today 2PM│Leave.. ││
│ └────┴────────┴──────┴────────┴──────┴──────────┴────────┘│
├────────────────────────────────────────────────────────────┤
│ Alert: 🟢 2 idle | 🔵 5 working | 🔴 1 sick                │
└────────────────────────────────────────────────────────────┘
```

### **Compact Mode (Team Management):**
```
People Now Panel (below Team Cards):
┌──────────────────────────────────────────────────┐
│ 👥 People (12) [Open Full Monitor →]            │
├──────────────────────────────────────────────────┤
│ 🟢 Available: 5 | 🔵 Working: 6 | 🔴 Leave: 1   │
└──────────────────────────────────────────────────┘
```

---

## 🔒 **Security & Permission**

### **New Permissions Required:**
```php
// In platform_permission table:
'people.view_basic'   - View people list (name, status, workload only)
'people.view_detail'  - View detailed info (username, leave reason, history)
'people.manage_leave' - Create/delete leave records
'people.export'       - Export to CSV (with PII masking)
```

### **Permission-based Field Masking:**
```php
// In people_monitor_list endpoint:
if (!permission_allow_code($member, 'people.view_detail')) {
    // Mask sensitive fields
    foreach ($data as &$person) {
        $person['username'] = '***';  // Hide username
        $person['reason_text'] = null;  // Hide leave reason
        $person['next_leave_window'] = null;  // Hide future leaves
    }
}
```

### **Export with PDPA Compliance:**
```php
case 'people_monitor_export':
    must_allow_code($member, 'people.export');
    
    // ... fetch data ...
    
    // Mask PII
    foreach ($data as &$row) {
        $row['reason_text'] = '***';  // Mask leave reasons
        $row['username'] = substr($row['username'], 0, 3) . '***';  // Partial mask
    }
    
    // Generate CSV
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="people_export_' . date('Ymd') . '.csv"');
    // ... output CSV
```

---

## ⏰ **Clock Skew & Timezone Handling**

### **Problem:**
- Client device time ≠ Server time → "on leave" calculated wrong
- Timezone mismatch → Leave schedule incorrect

### **Solution:** ✅ NEW
```php
// 1. Always use server time
$serverTime = new DateTime('now', new DateTimeZone('Asia/Bangkok'));
$serverTimeStr = $serverTime->format('c');  // ISO 8601

// 2. Return in every response
json_success([
    'data' => $data,
    'server_time' => $serverTimeStr  // Client syncs to this
]);
```

**JavaScript:**
```javascript
// Client-side: Use server time for calculations
let serverTimeOffset = 0;  // milliseconds difference

function syncServerTime(serverTimeStr) {
    const serverTime = new Date(serverTimeStr);
    const clientTime = new Date();
    serverTimeOffset = serverTime - clientTime;
}

function getServerTime() {
    return new Date(Date.now() + serverTimeOffset);
}

// Use getServerTime() for all "now" calculations
function isOnLeaveNow(leaveStart, leaveEnd) {
    const now = getServerTime();  // Not new Date()!
    return now >= new Date(leaveStart) && now <= new Date(leaveEnd);
}
```

---

## 🚀 **Performance Optimization**

### **Optimized Query (Single CTE):** ✅ NEW
```sql
-- Instead of N+1 queries, use single CTE:

WITH member_summary AS (
    -- Get team membership
    SELECT 
        tm.id_member,
        GROUP_CONCAT(DISTINCT t.name) as teams,
        GROUP_CONCAT(DISTINCT t.production_mode) as modes,
        tm.is_available,
        tm.unavailable_until
    FROM team_member tm
    LEFT JOIN team t ON t.id_team = tm.id_team
    WHERE tm.active = 1
    GROUP BY tm.id_member
),
active_work AS (
    -- Get active work
    SELECT 
        ta.assigned_to_user_id as id_member,
        jgi.production_type,
        COUNT(*) as token_count,
        MAX(ta.assigned_at) as last_assigned
    FROM token_assignment ta
    JOIN flow_token ft ON ft.id_token = ta.id_token
    JOIN job_graph_instance jgi ON jgi.id_instance = ft.id_instance
    WHERE ta.status IN ('assigned', 'accepted', 'started', 'paused')
      AND ft.status NOT IN ('completed', 'cancelled', 'scrapped')
    GROUP BY ta.assigned_to_user_id, jgi.production_type
),
current_leave AS (
    -- Get current leave
    SELECT 
        id_member,
        leave_type,
        reason_code,
        end_at as leave_until
    FROM member_leave
    WHERE NOW() BETWEEN start_at AND end_at
)
SELECT 
    a.id_member,
    a.name,
    ms.teams,
    ms.modes,
    ms.is_available,
    COALESCE(SUM(CASE WHEN aw.production_type='oem' THEN aw.token_count END), 0) as oem_tokens,
    COALESCE(SUM(CASE WHEN aw.production_type='hatthasilpa' THEN aw.token_count END), 0) as hatthasilpa_tokens,
    cl.leave_type,
    cl.reason_code,
    cl.leave_until
FROM account a
LEFT JOIN member_summary ms ON ms.id_member = a.id_member
LEFT JOIN active_work aw ON aw.id_member = a.id_member
LEFT JOIN current_leave cl ON cl.id_member = a.id_member
WHERE a.user_type = 'tenant_user'
  AND a.status = 1
GROUP BY a.id_member
```

**Performance:**
- ✅ 1 query instead of 3N queries
- ✅ CTE makes it readable
- ✅ Scales to 300+ members
- ✅ < 200ms expected

---

## ⚙️ **Implementation Strategy**

### **Reusable Component Approach:**

**Files:**
```
views/components/
└─ people_monitor.php (Reusable component)

assets/javascripts/people/
└─ monitor.js (Shared logic)

Usage:
// In Manager Assignment:
<?php include 'views/components/people_monitor.php'; ?>
<script>
    initPeopleMonitor({ mode: 'full', filters: true });
</script>

// In Team Management:
<?php include 'views/components/people_monitor.php'; ?>
<script>
    initPeopleMonitor({ mode: 'compact', teamId: currentTeam });
</script>
```

---

## 🔗 **Integration with Phase 2**

### **Dependencies (from Phase 2):**
- ✅ `team_member.is_available` (Phase 2 Task 1.2)
- ✅ `team_member.unavailable_until` (Phase 2 Task 1.2)
- ✅ `team_member.unavailable_reason` (Phase 2 Task 1.2)
- ✅ Workload calculation logic (Phase 2 Task 1.3)
- ✅ `assignment_decision_log` (existing)

### **What Phase 2.5 Adds:**
- 🆕 `member_leave` table (scheduled leave)
- 🆕 People Monitor UI (full + compact)
- 🆕 Leave management API
- 🆕 Real-time people status

---

## 📋 **Benefits Analysis**

### **For Managers:**
- ✅ **Single screen** - See everyone at once
- ✅ **Real-time** - Know who's available NOW
- ✅ **Quick action** - Assign/Leave without navigating
- ✅ **Transparency** - See workload, status, history

### **For Operators:**
- ✅ **Self-service** - Can request leave (if permission given)
- ✅ **Visibility** - Know their status, workload
- ✅ **Fair distribution** - Load visible to all

### **For System:**
- ✅ **Better assignment** - Skip people on leave automatically
- ✅ **Audit trail** - All leave/availability changes logged
- ✅ **Compliance** - Leave records for HR/Payroll
- ✅ **Foundation** - Ready for HR integration later

---

## 🚨 **Risks & Mitigations**

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Complex query (slow)** | Medium | Pagination + indexes + caching |
| **Real-time lag** | Low | 30s polling (acceptable) |
| **Leave conflicts** | Low | Validation (no overlap leaves) |
| **Too many features** | Medium | Start with essentials, expand later |

---

## 🧪 **Acceptance Tests (20 Critical Cases)**

### **Positive Cases (10):**
1. ✅ View all people → See complete list with correct status
2. ✅ Filter by team → See only members of that team
3. ✅ Filter by status → See only available/working/leave
4. ✅ Search by name → Find correct person
5. ✅ Create leave → Session auto-paused, status updated
6. ✅ Delete future leave → Status reverts to available
7. ✅ Member in 2 teams → Appears in both team filters
8. ✅ Workload accurate → OEM vs Hatthasilpa separated
9. ✅ Alert bar → Shows correct counts (idle/working/leave)
10. ✅ Real-time refresh → Status updates within 30s

### **Negative Cases (10):** ✅ NEW
1. ✅ Create overlapping leave → Error "Leave period overlaps"
2. ✅ Assign to person on leave → 2-tier confirmation required
3. ✅ Team with all members on leave → Auto-assign skips team
4. ✅ Delete active leave → Error "Cannot delete ongoing leave"
5. ✅ No permission (view_detail) → Username/reason masked
6. ✅ No permission (manage_leave) → Leave button hidden
7. ✅ Query timeout (>5s) → Show cached data + retry
8. ✅ Server time ≠ Client → Use server_time (correct relative times)
9. ✅ Export without permission → 403 Forbidden
10. ✅ Member with no team → Shows in "No Team" filter

---

## 🎨 **UI Enhancements**

### **Alert Bar (Top of People Monitor):** ✅ NEW
```html
<div class="alert alert-info d-flex justify-content-between align-items-center">
    <div>
        <i class="bi bi-people-fill"></i>
        <strong>Organization Status:</strong>
    </div>
    <div class="d-flex gap-3">
        <span class="badge bg-success">🟢 Available: <strong>22</strong></span>
        <span class="badge bg-primary">🔵 Working: <strong>18</strong></span>
        <span class="badge bg-warning">🟡 Paused: <strong>3</strong></span>
        <span class="badge bg-danger">🔴 Leave: <strong>2</strong></span>
        <span class="badge bg-secondary">⚫ Unavailable: <strong>0</strong></span>
    </div>
</div>
```

### **PIN Override Confirmation (2-Tier):** ✅ NEW
```javascript
// When assigning to unavailable member:
if (!member.is_available || member.on_leave_now) {
    // First warning
    const result1 = await Swal.fire({
        title: 'Member Unavailable',
        html: `
            <div class="alert alert-warning">
                <strong>${member.name}</strong> is currently:
                ${member.on_leave_now ? 
                    `<br>🔴 On ${member.leave_type} leave until ${member.leave_until}` :
                    `<br>⚫ Marked unavailable: ${member.unavailable_reason}`
                }
            </div>
            <p>Do you want to override and assign anyway?</p>
        `,
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'Yes, Continue'
    });
    
    if (!result1.isConfirmed) return;
    
    // Second confirmation (require reason)
    const result2 = await Swal.fire({
        title: 'Override Reason Required',
        html: `
            <p>Please provide reason for override assignment:</p>
            <textarea id="override-reason" class="form-control" 
                      placeholder="e.g., Urgent job, only qualified person"></textarea>
        `,
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Confirm Override',
        preConfirm: () => {
            const reason = document.getElementById('override-reason').value;
            if (!reason || reason.trim().length < 10) {
                Swal.showValidationMessage('Reason must be at least 10 characters');
                return false;
            }
            return reason;
        }
    });
    
    if (!result2.isConfirmed) return;
    
    // Proceed with override + log
    overrideReason = result2.value;
}
```

### **Color Consistency (Match Team Cards):** ✅ NEW
```javascript
function getStatusBadgeClass(status, pct) {
    if (status === 'leave' || status === 'sick') return 'bg-danger';
    if (status === 'unavailable') return 'bg-secondary';
    if (status === 'paused') return 'bg-warning';
    if (status === 'working') return 'bg-primary';
    
    // Available - color by load
    if (pct >= 80) return 'bg-danger';    // 🔴 Overloaded
    if (pct >= 50) return 'bg-warning';   // 🟡 Busy
    return 'bg-success';                  // 🟢 Idle
}
```

---

## 📱 **Mobile UX Optimization**

### **Virtual Scroll for Large Lists:** ✅ NEW
```javascript
// Use DataTables with serverSide processing
$('#people-table').DataTable({
    serverSide: true,
    processing: true,
    pageLength: 50,
    ajax: {
        url: 'source/team_api.php',
        type: 'POST',
        data: function(d) {
            d.action = 'people_monitor_list';
            d.team_id = currentFilters.team;
            d.status = currentFilters.status;
            return d;
        }
    },
    // ... columns
});
```

### **Bottom Sheet for Actions (Mobile):**
```javascript
// On mobile, use Bootstrap Offcanvas instead of Modal
if (window.innerWidth < 768) {
    showBottomSheet('assign', member);  // Slide from bottom
} else {
    showModal('assign', member);  // Center modal
}
```

---

## 🔄 **Data Rotation & Archiving**

### **Archive Strategy:** ✅ NEW

**Problem:** `assignment_decision_log` grows fast (1000+ records/day)

**Solution: Daily Rotation**
```php
// cron/archive_decision_log.php (Run daily at 2 AM)

// 1. Archive old logs (> 30 days)
$db->query("
    INSERT INTO assignment_decision_log_archive 
    SELECT * FROM assignment_decision_log 
    WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
");

// 2. Delete from main table
$db->query("
    DELETE FROM assignment_decision_log 
    WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
");

// 3. Optimize table
$db->query("OPTIMIZE TABLE assignment_decision_log");
```

**member_leave Retention:**
- Keep 18-24 months
- Export to HR system monthly
- Archive > 24 months

---

## ✅ **Recommendation**

### **แนะนำ:**
```
Phase 2 (Week 3) → Team Integration
        ↓
Phase 2.5 (Week 4) → People Monitor
        ↓
Phase 3 (Week 5+) → Analytics (optional)
```

### **เหตุผล:**
1. ✅ **Sequential** - ทำทีละ phase ไม่วุ่นวาย
2. ✅ **Foundation ready** - หลัง Phase 2 ทุกอย่างพร้อม
3. ✅ **High value** - Manager ได้ Command Center
4. ✅ **Low risk** - ไม่ขัดกับ Phase 2
5. ✅ **Quick** - ทำได้ใน 2 วัน (re-use code)

---

## 📊 **Final Priority Assessment**

```
Priority Score:
├─ Phase 2: Team Integration = 100 (Must have!)
├─ Phase 2.5: People Monitor = 90 (Very high value)
└─ Phase 3: Analytics = 60 (Nice to have)

Recommendation:
1. Phase 2 first (foundation)
2. Phase 2.5 next (high value)
3. Phase 3 later (if time permits)
```

---

## 📋 **Implementation Checklist (18 hours)**

### **Day 1: Backend + Validation (8h)**
- [ ] Create `config/assignment_config.php` (30m)
- [ ] Migration: `member_leave` table with reason_code (1h)
- [ ] Add indexes for performance (30m)
- [ ] API: `people_monitor_list` with CTE query (3h)
- [ ] API: `member_leave_create` with validation (2h)
  - Overlap check
  - Auto-pause sessions
  - Set availability
- [ ] API: `member_leave_delete/list` (1h)

### **Day 2: Frontend + Testing (8h)**
- [ ] Permissions seeding (people.*) (30m)
- [ ] People Monitor component (reusable) (2h)
- [ ] Alert bar summary (30m)
- [ ] Leave modal with calendar (1.5h)
- [ ] PIN override confirmation (2-tier) (1h)
- [ ] Mobile bottom sheet (30m)
- [ ] Unit tests (positive + negative) (1h)
- [ ] Browser E2E (20 test cases) (1h)

### **Day 3: Polish + Integration (2h)** ✅ NEW
- [ ] Clock sync implementation (30m)
- [ ] PII masking (30m)
- [ ] Export CSV with compliance (30m)
- [ ] Documentation (Manager guide Thai) (30m)

**Total: 18 hours (2.5 days)**

---

## 🎯 **Critical Improvements from External Review**

### **Integrated (13 items):**
1. ✅ Clock skew handling (server_time sync)
2. ✅ Overlapping leave validation
3. ✅ Auto-pause sessions on leave create
4. ✅ PIN override 2-tier confirmation
5. ✅ Optimized query (CTE instead of N+1)
6. ✅ reason_code enum (HR stats)
7. ✅ Permission-based masking (PII)
8. ✅ Data rotation strategy
9. ✅ Alert bar summary
10. ✅ Color consistency (match Team cards)
11. ✅ Mobile bottom sheet
12. ✅ Multi-team handling
13. ✅ 20 acceptance tests (positive + negative)

### **Benefits:**
- Time: 16h → **18h** (+2h for quality)
- Quality: Good → **Production-Grade**
- Risk: Medium → **Low**
- Compliance: Basic → **PDPA-Ready**

---

**Status:** ✅ **Concept Complete with External Reviews**  
**Quality Level:** Production-Grade (after 2x external validation)  
**Next:** Complete Phase 2 first, then implement People Monitor

**Location in Roadmap:** Week 4 (after Phase 2 - 28h complete)  
**Total Documentation:** 3,650+ lines (Phase 2 + 2.5 combined)


