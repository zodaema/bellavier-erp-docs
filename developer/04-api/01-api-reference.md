# 📘 API Reference - Bellavier ERP

**Version:** 3.0  
**Last Updated:** January 2025  
**Base URL:** `http://your-domain.com/bellavier-group-erp/`

**Current State:**
- **Total API Files:** 85+ files
- **Modern APIs (Bootstrap):** 77+ APIs (65 tenant + 12 platform)
- **Legacy APIs:** 50+ files (not using bootstrap)
- **Bootstrap Migration:** ✅ 77+ APIs migrated

**Latest Changes:**
- ✅ Bootstrap layers integrated (TenantApiBootstrap, CoreApiBootstrap)
- ✅ Enterprise features (Rate limiting, Validation, Idempotency)
- ✅ DAG APIs (dag_routing_api, dag_token_api, dag_approval_api)
- ✅ MO Intelligence APIs (mo_assist_api, mo_eta_api, mo_load_simulation_api)
- ✅ Component APIs (hatthasilpa_component_api, component APIs)

---

## 🔐 **Authentication**

All API endpoints require authentication via PHP session.

**Login:**
```http
POST /login.php
Content-Type: application/x-www-form-urlencoded

username=admin&password=yourpassword
```

**Response:**
```json
{
  "ok": true,
  "redirect": "index.php?p=dashboard"
}
```

**Session:** PHPSESSID cookie will be set

---

## 🎫 **Job Ticket Endpoints**

### **Base URL:** `source/atelier_job_ticket.php`

---

### **List Job Tickets**

```http
POST /source/atelier_job_ticket.php
Content-Type: application/x-www-form-urlencoded

action=list
draw=1
start=0
length=10
```

**Response:**
```json
{
  "ok": true,
  "draw": 1,
  "recordsTotal": 50,
  "recordsFiltered": 50,
  "data": [
    {
      "id_job_ticket": 123,
      "ticket_code": "JT251030001",
      "job_name": "Leather Tote Production",
      "target_qty": 100,
      "process_mode": "piece",
      "status": "in_progress",
      "due_date": "2025-11-15",
      "created_at": "2025-10-30 10:00:00"
    }
  ]
}
```

---

### **Get Job Ticket**

```http
GET /source/atelier_job_ticket.php?action=get&id_job_ticket=123
```

**Response:**
```json
{
  "ok": true,
  "data": {
    "id_job_ticket": 123,
    "ticket_code": "JT251030001",
    "job_name": "Leather Tote Production",
    "target_qty": 100,
    "status": "in_progress",
    "tasks": [
      {
        "id_job_task": 456,
        "step_name": "Cutting",
        "status": "done",
        "progress_pct": 100.0,
        "assigned_to": 2,
        "assigned_name": "John Doe"
      }
    ],
    "logs": [
      {
        "id_wip_log": 789,
        "event_type": "complete",
        "qty": 25,
        "operator_name": "John Doe",
        "event_time": "2025-10-30 14:30:00"
      }
    ]
  }
}
```

---

### **Create/Update Job Ticket**

```http
POST /source/atelier_job_ticket.php
Content-Type: application/x-www-form-urlencoded

action=save
id_job_ticket=    (empty for create, ID for update)
job_name=Leather Tote Production
target_qty=100
process_mode=piece
due_date=2025-11-15
id_mo=45          (optional)
work_center_id=3  (optional)
```

**Validation Rules:**
- `job_name`: Required, max 255 characters
- `target_qty`: Required for piece mode, must be > 0 and ≤ 1,000,000
- `process_mode`: One of [piece, batch]
- `due_date`: Optional, cannot be in past for new tickets

**Response (Success):**
```json
{
  "ok": true,
  "id_job_ticket": 123,
  "message": "Job ticket saved"
}
```

**Response (Validation Error):**
```json
{
  "ok": false,
  "error": "Job name is required, Target quantity must be greater than 0",
  "validation_errors": {
    "job_name": "Job name is required",
    "target_qty": "Target quantity must be greater than 0"
  }
}
```

---

### **Delete Job Ticket**

```http
POST /source/atelier_job_ticket.php
Content-Type: application/x-www-form-urlencoded

action=delete
id_job_ticket=123
```

**Response:**
```json
{
  "ok": true,
  "message": "Job ticket deleted"
}
```

---

## 📋 **Task Endpoints**

### **List Tasks**

```http
POST /source/atelier_job_ticket.php
Content-Type: application/x-www-form-urlencoded

action=task_list
id_job_ticket=123
draw=1
start=0
length=10
```

**Response:**
```json
{
  "ok": true,
  "draw": 1,
  "recordsTotal": 5,
  "recordsFiltered": 5,
  "data": [
    {
      "id_job_task": 456,
      "step_name": "Cutting",
      "sequence_no": 1,
      "status": "done",
      "assigned_to": 2,
      "assigned_name": "John Doe",
      "progress_pct": 100.0,
      "estimated_hours": 2.5,
      "predecessor_task_id": null
    }
  ]
}
```

---

### **Save Task**

```http
POST /source/atelier_job_ticket.php

action=task_save
id_job_ticket=123
id_job_task=      (empty for create)
step_name=Cutting
sequence_no=1
assigned_to=2     (user ID)
predecessor_task_id=  (optional)
estimated_hours=2.5
```

**Validation:**
- `step_name`: Required, max 255 chars
- `sequence_no`: 0-9999
- `estimated_hours`: 0-10,000

**Response:**
```json
{
  "ok": true,
  "id_job_task": 456
}
```

---

## 📝 **WIP Log Endpoints**

### **Create WIP Log**

```http
POST /source/atelier_job_ticket.php

action=log_create
id_job_ticket=123
id_job_task=456   (optional)
event_type=complete
qty=25
operator_name=John Doe
operator_user_id=2  (optional)
notes=Completed batch 1
```

**Event Types:**
- `start` - Begin work
- `hold` - Pause work
- `resume` - Resume after pause
- `complete` - Complete quantity
- `fail` - Report defect
- `qc_start` - Start QC
- `qc_pass` - QC passed
- `qc_fail` - QC failed
- `note` - General note

**Validation:**
- `event_type`: Required, must be valid event type
- `qty`: Required for complete/qc events, must be > 0 and ≤ remaining qty
- `operator_name` or `operator_user_id`: Required
- `notes`: Optional, max 5000 characters

**Response:**
```json
{
  "ok": true,
  "id_wip_log": 789
}
```

**Business Logic (Automatic):**
1. Validates input
2. Inserts WIP log
3. Updates operator sessions
4. Updates task status
5. Updates ticket status
6. Updates MO status (if linked)
7. Refreshes dashboard metrics

---

### **Update WIP Log**

```http
POST /source/atelier_job_ticket.php

action=log_update
id_wip_log=789
event_type=complete  (optional)
qty=30              (optional)
notes=Updated notes  (optional)
```

**Response:**
```json
{
  "ok": true,
  "message": "WIP log updated and sessions recalculated"
}
```

**Note:** Sessions are automatically rebuilt after update

---

### **Delete WIP Log (Soft-delete)**

```http
POST /source/atelier_job_ticket.php

action=log_delete
id_wip_log=789
```

**Response:**
```json
{
  "ok": true,
  "message": "WIP log deleted and sessions recalculated"
}
```

**Note:** This is a SOFT DELETE (sets deleted_at timestamp). Sessions are automatically recalculated.

---

### **List WIP Logs**

```http
POST /source/atelier_job_ticket.php

action=log_list
id_job_ticket=123
draw=1
start=0
length=10
```

**Response:**
```json
{
  "ok": true,
  "draw": 1,
  "recordsTotal": 45,
  "data": [
    {
      "id_wip_log": 789,
      "event_type": "complete",
      "event_time": "2025-10-30 14:30:00",
      "qty": 25,
      "operator_name": "John Doe",
      "task_name": "Cutting",
      "notes": "Completed batch 1"
    }
  ]
}
```

**Note:** Only returns logs where `deleted_at IS NULL`

---

### **Recalculate Operator Sessions**

```http
POST /source/atelier_job_ticket.php

action=recalc_sessions
id_job_ticket=123
```

**Response:**
```json
{
  "ok": true,
  "message": "All operator sessions recalculated successfully"
}
```

**Use When:**
- Data appears inconsistent
- After bulk log updates
- After database recovery
- Progress doesn't match expected value

---

## 🔄 **PWA Scan Station Endpoints**

### **Base URL:** `source/pwa_scan_api.php`

### **Lookup Entity**

```http
GET /source/pwa_scan_api.php?action=lookup&code=JT251030001
```

**Response:**
```json
{
  "ok": true,
  "data": {
    "entity_type": "job_ticket",
    "entity_id": 123,
    "code": "JT251030001",
    "name": "Leather Tote Production",
    "qty": 100,
    "tasks": [...]
  }
}
```

---

### **Check Remaining Quantity** ⭐ NEW

```http
GET /source/pwa_scan_api.php?action=check_remaining&task_id=456
```

**Purpose:** Get real-time remaining quantity for a task (with tolerance info)

**Response:**
```json
{
  "ok": true,
  "data": {
    "target_qty": 100,
    "completed_qty": 95,
    "remaining_qty": 5,
    "progress_pct": 95.0,
    "max_allowed": 105,
    "can_add_max": 10,
    "tolerance_pct": 5
  }
}
```

**Field Descriptions:**
- `target_qty` - Target quantity for the task
- `completed_qty` - Quantity completed so far (from operator sessions)
- `remaining_qty` - Quantity remaining (target - completed)
- `progress_pct` - Progress percentage
- `max_allowed` - Maximum allowed including tolerance (target + 5%)
- `can_add_max` - Maximum quantity that can still be added
- `tolerance_pct` - Tolerance percentage (default 5%)

**Used For:**
- Real-time UI updates when task is selected
- Show operator how much they can still produce
- Prevent over-production beyond tolerance

---

### **Submit (Quick Mode)**

```http
POST /source/pwa_scan_api.php?action=submit

{
  "mode": "quick",
  "entity_type": "job_ticket",
  "entity_id": 123,
  "action": "complete",
  "qty": 25,
  "timestamp": "2025-10-30T14:30:00Z"
}
```

**Quick Actions:**
- `start` - Start work
- `hold` - Pause work
- `resume` - Resume work
- `report_defect` - Report QC fail
- `complete` - Complete quantity

**Response:**
```json
{
  "ok": true,
  "data": {
    "id_wip_log": 789,
    "mode": "quick"
  }
}
```

---

### **Submit (Detail Mode)**

```http
POST /source/pwa_scan_api.php?action=submit

{
  "mode": "detail",
  "entity_type": "job_ticket",
  "entity_id": 123,
  "id_task": 456,
  "event_type": "complete",
  "qty": 25,
  "notes": "Completed",
  "timestamp": "2025-10-30T14:30:00Z"
}
```

**Response:**
```json
{
  "ok": true,
  "data": {
    "id_wip_log": 789,
    "mode": "detail"
  }
}
```

---

## ❌ **Error Responses**

### **Common Error Codes:**

| Code | Meaning | Example |
|------|---------|---------|
| 400 | Bad Request / Validation Failed | Invalid qty, missing required field |
| 401 | Unauthorized | Not logged in |
| 403 | Forbidden | No permission for this action |
| 404 | Not Found | Ticket/task/log not found |
| 409 | Conflict | Concurrent modification |
| 422 | Business Logic Violation | Cannot delete ticket with active tasks |
| 500 | Server Error | Database error, service failure |

### **Error Response Format:**

**Validation Error:**
```json
{
  "ok": false,
  "error": "Quantity exceeds target quantity (100)",
  "validation_errors": {
    "qty": "Quantity (150) exceeds target quantity (100)"
  }
}
```

**Not Found:**
```json
{
  "ok": false,
  "error": "Job Ticket not found",
  "context": {
    "resource": "Job Ticket",
    "id": 999
  }
}
```

**Generic Error:**
```json
{
  "ok": false,
  "error": "An unexpected error occurred"
}
```

---

## 📊 **Data Models**

### **Job Ticket**
```json
{
  "id_job_ticket": 123,
  "ticket_code": "JT251030001",
  "job_name": "Product Name",
  "target_qty": 100,
  "process_mode": "piece",  // or "batch"
  "status": "in_progress",   // planned|in_progress|on_hold|qc|rework|completed|cancelled
  "id_mo": 45,               // optional
  "work_center_id": 3,       // optional
  "due_date": "2025-11-15",
  "started_at": "2025-10-30 10:00:00",
  "completed_at": null
}
```

### **Job Task**
```json
{
  "id_job_task": 456,
  "id_job_ticket": 123,
  "step_name": "Cutting",
  "sequence_no": 1,
  "status": "in_progress",   // pending|in_progress|on_hold|paused|qc|rework|done|cancelled
  "assigned_to": 2,          // user ID
  "assigned_name": "John Doe",
  "predecessor_task_id": null,
  "estimated_hours": 2.5,
  "progress_pct": 45.5,      // AUTO-CALCULATED from operator sessions
  "started_at": "2025-10-30 10:30:00",
  "completed_at": null,
  "total_pause_minutes": 15
}
```

### **WIP Log**
```json
{
  "id_wip_log": 789,
  "id_job_ticket": 123,
  "id_job_task": 456,
  "event_type": "complete",
  "event_time": "2025-10-30 14:30:00",
  "qty": 25,
  "operator_name": "John Doe",
  "operator_user_id": 2,
  "notes": "Completed batch 1",
  "deleted_at": null,        // null if active, timestamp if soft-deleted
  "deleted_by": null
}
```

### **Operator Session**
```json
{
  "id_session": 101,
  "id_job_task": 456,
  "operator_user_id": 2,
  "operator_name": "John Doe",
  "status": "completed",     // active|paused|completed|cancelled
  "total_qty": 25,
  "total_pause_minutes": 5,
  "started_at": "2025-10-30 10:30:00",
  "paused_at": null,
  "completed_at": "2025-10-30 14:30:00"
}
```

---

## 🔄 **Business Logic**

### **Status Cascade Flow:**
```
WIP Log Created/Updated/Deleted
    ↓
Operator Sessions Updated (OperatorSessionService)
    ↓
Task Status Updated (based on sessions)
    ↓
Job Ticket Status Updated (based on tasks)
    ↓
MO Status Updated (if linked)
```

### **Progress Calculation:**
```
Progress % = (Sum of completed operator sessions total_qty / ticket target_qty) * 100

NOT calculated from individual WIP logs!
Multiple operators → multiple sessions → summed for total
```

### **Soft-Delete:**
- WIP logs are NEVER hard deleted
- deleted_at timestamp marks deletion
- deleted_by tracks who deleted
- All queries MUST filter: `WHERE deleted_at IS NULL`
- Sessions automatically rebuilt after delete

---

## 🛡️ **Security**

### **Authentication:**
- All endpoints require valid PHP session
- Check: `$member = $objMemberDetail->thisLogin()`
- 401 if not authenticated

### **Authorization:**
- Permission-based access control
- Check: `must_allow('permission.code')`
- 403 if permission denied

### **Input Validation:**
- **ValidationService** - Comprehensive validation with row locking
  - `validateWIPLog($data, $task, $ticket, $db, $options)` - WIP log validation
    - **Row Locking:** Pass `$db` for real-time quantity check with `FOR UPDATE`
    - **Tolerance Check:** Default 5% over-production allowed
    - **Returns:** `['valid' => bool, 'errors' => array, 'warnings' => array]`
  - `validateJobTicket($data, $isUpdate)` - Job ticket validation
  - `validateJobTask($data, $ticketTargetQty)` - Job task validation
  - `validateStatusTransition($current, $new)` - State machine validation
  - `sanitizeInt/Float/String($value, $min, $max)` - Type-safe sanitization
- **SQL Injection Prevention:** Prepared statements ONLY (NO raw SQL)
- **XSS Prevention:** JSON encoding + `htmlspecialchars()` on output
- **File Uploads:** Type, size, path validation

### **Data Protection:**
- Tenant isolation enforced
- Soft-delete for audit trail
- Sensitive data not in error messages
- Error context logged but not exposed

---

## 📚 **Additional Resources**

- **User Manual:** `docs/USER_MANUAL.md`
- **Deployment Guide:** `docs/DEPLOYMENT_GUIDE_COMPLETE.md`
- **System Architecture:** `docs/platform_overview.md`
- **Troubleshooting:** `docs/guide/TROUBLESHOOTING_GUIDE.md`
- **Migration Guide:** `database/MIGRATION_GUIDE.md`

---

## 💎 **Advanced Features**

### **Quantity Management with Tolerance (NEW)**

**Overview:**
- **Strict Mode** with 5% tolerance prevents over-production
- **Row Locking** prevents concurrent operation issues
- **Real-time Validation** checks latest completed quantity

**How It Works:**
1. Target Quantity: 100 pieces
2. 5% Tolerance: Max 105 pieces allowed
3. Real-time Check: `SELECT ... FOR UPDATE` (row lock)
4. Validation:
   - 100 or less → **PASS** (no warning)
   - 101-105 → **PASS** with **WARNING** (logged)
   - 106+ → **BLOCKED** ❌ (error message)

**Example Scenario:**
```
Ticket Target: 100 pieces
Operator A completes: 95 pieces

Operator B tries to add: 8 pieces
- Real-time check: 95 + 8 = 103
- Max allowed: 105 (100 + 5%)
- Result: PASS ✅ (warning logged)

Operator C tries to add: 15 pieces
- Real-time check: 103 + 15 = 118
- Max allowed: 105
- Result: BLOCKED ❌ (error shown)
```

**Benefits:**
- ✅ Prevents significant over-production (data integrity)
- ✅ Allows small tolerance for operational flexibility
- ✅ Clear error messages for operators
- ✅ Audit trail via error logs

**Customization:**
```php
// Use custom tolerance (e.g., 10%)
$validation = ValidationService::validateWIPLog($data, $task, $ticket, $db, ['tolerance_pct' => 10]);
```

---

## 🆘 **Support**

**Issues?**
1. Check browser Console (F12) for JS errors
2. Check Network tab for API responses
3. Review error message and validation_errors
4. Check docs/guide/TROUBLESHOOTING_GUIDE.md
5. Contact technical support

---

*API Reference v2.1*  
*Last Updated: October 30, 2025 - Added Quantity Management with Tolerance*  
*Status: Production Ready - Enterprise Grade*

