# Task 24.6.1 — Operator Field Audit Report

**Date:** 2025-11-29  
**Status:** ✅ **COMPLETED**  
**Objective:** รวบรวมข้อมูลทั้งหมดที่เกี่ยวข้องกับ operator assignment ในระบบ Job Ticket (Classic Line) เพื่อตรวจสอบการใช้ operator fields และระบุจุดที่ต้องทำความสะอาด

---

## 1. Operator Fields Summary

### job_ticket.assigned_to
**Type:** `VARCHAR(150) NULL`  
**Used in:**
- ✅ `source/job_ticket.php`:
  - SELECT in `list` action (line 700): `ajt.assigned_to`
  - SELECT in `get` action (line ~768): included in `ajt.*`
  - INSERT in `create` action (line 1019, 1021): included in INSERT statement
  - UPDATE in `update` action (line 1190, 1193): included in UPDATE statement
  - Read from request payload (line 918, 1034, 1205)
- ✅ `assets/javascripts/hatthasilpa/job_ticket.js`:
  - Display in table (line 390-395): fallback for operator name display
  - Display in detail view (line 2039): `data.assigned_to || data.assigned_name || "-"`
  - Send in create/update payload (line 1916, 1917, 1979, 1980, 3023, 3024)
- ⚠️ **Status:** Legacy field - ยังใช้อยู่แต่ควร migrate ไปใช้ `assigned_operator_id` แทน

### job_ticket.assigned_user_id
**Type:** `INT(11) NULL`  
**Used in:**
- ✅ `source/job_ticket.php`:
  - SELECT in `list` action (line 701): `ajt.assigned_user_id`
  - JOIN in `list` action (line 715): `LEFT JOIN bgerp.account_org ao ON ao.id_member = ajt.assigned_user_id`
  - SELECT in `get` action (line 796-804): Used to fetch `assigned_name` from `bgerp.account`
  - INSERT in `create` action (line 1019, 1021): included in INSERT statement
  - UPDATE in `update` action (line 1190, 1193): included in UPDATE statement
  - Read from request payload (line 919, 1035, 1206)
- ✅ `assets/javascripts/hatthasilpa/job_ticket.js`:
  - Send in create/update payload (line 1917, 1980, 3024)
  - Used in form fill (line 3082-3089): Set value in `#ticket_assigned` select
- ⚠️ **Status:** Legacy field - ยังใช้อยู่แต่ควร migrate ไปใช้ `assigned_operator_id` แทน

### job_ticket.assigned_operator_id
**Type:** `INT(11) NULL` (NEW - Task 24.6)  
**Used in:**
- ✅ `source/job_ticket.php`:
  - SELECT in `start` action (line 257, 266): Validate operator before start
  - Validation in `start` action (line 286): Check if operator is required
  - SELECT in `list` action (line 694): Included in `ajt.*` (if column exists)
  - SELECT in `get` action (line 768): Included in query
  - INSERT in `create` action (line 1019, 1021): included in INSERT statement
  - UPDATE in `update` action (line 1190): included in UPDATE statement (if column exists)
  - Read from request payload (line 907-908, 920, 1036, 1207)
  - Event logging (line 1186, 1221-1227): Log `OPERATOR_CHANGED` event
- ✅ `assets/javascripts/hatthasilpa/job_ticket.js`:
  - Load in detail view (line 2070-2071): Set value in `#jt-operator` select
  - Pass to lifecycle buttons (line 2066): `renderLifecycleButtons(..., data.assigned_operator_id)`
  - Send in create/update payload (line 1897, 1960, 3025)
  - Auto-save on change (line ~2080-2095): `saveOperatorAssignment()`
- ✅ `views/job_ticket.php`:
  - UI field (line ~580): `<select id="jt-operator">` in offcanvas
- ✅ **Status:** NEW field (Task 24.6) - Primary field สำหรับ operator assignment

### job_task.assigned_to (Related - for task-level assignment)
**Type:** `INT(11) NULL`  
**Used in:**
- ✅ `source/job_ticket.php`:
  - SELECT in `task_list` action (line 1288): `array_column($tasks, 'assigned_to')`
  - Display in task list (line 1310-1313): Merge user data from `bgerp.account`
  - UPDATE in `task_update` action (line 1496, 1501): Update task assignment
  - UPDATE in `task_assign` action (line 1536, 1544): Assign/unassign task
- ✅ `assets/javascripts/hatthasilpa/job_ticket.js`:
  - Task form (line 1333, 1497): Task assignment dropdown
- ✅ **Status:** Separate concern - สำหรับ task-level assignment (ไม่เกี่ยวกับ ticket-level operator)

---

## 2. API Usage

### GET job_ticket.php?action=list
**File:** `source/job_ticket.php` (line 673-750)  
**Fields Read:**
- `assigned_to` (line 700) - SELECT explicitly
- `assigned_user_id` (line 701) - SELECT explicitly
- `assigned_operator_id` (line 694) - Included in `ajt.*` (if column exists)

**JOIN for Operator Name:**
- `assigned_user_id` → `bgerp.account_org` → `bgerp.account` (line 715-716)
- Result: `assigned_name` field in response

**Current Usage:**
- ⚠️ **Mixed usage:** ใช้ทั้ง `assigned_to`, `assigned_user_id`, และ `assigned_operator_id`
- ⚠️ **Conflict:** `assigned_name` มาจาก `assigned_user_id` แต่ UI อาจใช้ `assigned_operator_id`

### GET job_ticket.php?action=get
**File:** `source/job_ticket.php` (line 752-849)  
**Fields Read:**
- `assigned_operator_id` - Included in `ajt.*` SELECT
- `assigned_user_id` (line 796-804) - Used to fetch `assigned_name` from `bgerp.account`

**Current Usage:**
- ✅ **Primary:** ใช้ `assigned_operator_id` (new field)
- ⚠️ **Fallback:** `assigned_name` มาจาก `assigned_user_id` (legacy)

### POST job_ticket.php?action=create
**File:** `source/job_ticket.php` (line 851-1070)  
**Fields Written:**
- `assigned_to` (line 918, 1034) - From request payload
- `assigned_user_id` (line 919, 1035) - From request payload
- `assigned_operator_id` (line 907-908, 920, 1036) - From request payload (NEW)

**INSERT Statement:**
- Line 1019, 1021: Include all three fields

**Current Usage:**
- ⚠️ **Redundant:** เขียนทั้ง 3 fields แต่ควรใช้แค่ `assigned_operator_id`
- ⚠️ **Risk:** Data inconsistency - ถ้า payload ไม่สอดคล้องกัน

### POST job_ticket.php?action=update
**File:** `source/job_ticket.php` (line 851-1238)  
**Fields Written:**
- `assigned_to` (line 1205) - From request payload
- `assigned_user_id` (line 1206) - From request payload
- `assigned_operator_id` (line 1207) - From request payload (NEW)

**UPDATE Statement:**
- Line 1190: Include all three fields (if column exists)

**Event Logging:**
- Line 1186, 1221-1227: Log `OPERATOR_CHANGED` event when `assigned_operator_id` changes

**Current Usage:**
- ⚠️ **Redundant:** เขียนทั้ง 3 fields แต่ควรใช้แค่ `assigned_operator_id`
- ✅ **Good:** Event logging สำหรับ operator changes

### POST job_ticket.php?action=start
**File:** `source/job_ticket.php` (line 251-296)  
**Fields Read:**
- `assigned_operator_id` (line 257, 266) - Required validation

**Validation:**
- Line 286: Return error `ERR_OPERATOR_REQUIRED` if `assigned_operator_id` is null

**Current Usage:**
- ✅ **Correct:** ใช้ `assigned_operator_id` สำหรับ validation

### POST job_ticket.php?action=task_update
**File:** `source/job_ticket.php` (line 1480-1519)  
**Fields Written:**
- `job_task.assigned_to` (line 1496, 1501) - Task-level assignment

**Current Usage:**
- ✅ **Separate concern:** Task-level assignment (ไม่เกี่ยวกับ ticket operator)

### POST job_ticket.php?action=task_assign
**File:** `source/job_ticket.php` (line 1533-1552)  
**Fields Written:**
- `job_task.assigned_to` (line 1536, 1544) - Task-level assignment

**Current Usage:**
- ✅ **Separate concern:** Task-level assignment (ไม่เกี่ยวกับ ticket operator)

---

## 3. JS Usage

### assets/javascripts/hatthasilpa/job_ticket.js

#### loadTicketDetail()
**Line:** 1950-2100  
**Fields Used:**
- `data.assigned_operator_id` (line 2070-2071) - Set value in `#jt-operator` select
- `data.assigned_name` (line 2039) - Display in detail view
- `data.assigned_to` (line 2039) - Fallback display

**Current Usage:**
- ✅ **Primary:** ใช้ `assigned_operator_id` สำหรับ operator select
- ⚠️ **Fallback:** Display ใช้ `assigned_name` หรือ `assigned_to` (legacy)

#### gatherTicketPayload()
**Line:** 2767-2800  
**Fields Sent:**
- `assigned_to` (line 3023) - From `#ticket_assigned` select (legacy)
- `assigned_user_id` (line 3024) - From `#ticket_assigned` select (legacy)
- `assigned_operator_id` (line 3025) - From `#jt-operator` select (NEW)

**Current Usage:**
- ⚠️ **Redundant:** ส่งทั้ง 3 fields แต่ควรใช้แค่ `assigned_operator_id`

#### fillTicketForm()
**Line:** 3050-3150  
**Fields Used:**
- `data.assigned_user_id` (line 3082-3089) - Set value in `#ticket_assigned` select (legacy)
- `data.assigned_operator_id` (line 3109-3112) - Set value in `#jt-operator` select (NEW)

**Current Usage:**
- ⚠️ **Mixed usage:** ใช้ทั้ง `assigned_user_id` และ `assigned_operator_id`

#### renderLifecycleButtons()
**Line:** ~2050-2080  
**Fields Used:**
- `assignedOperatorId` parameter (line 2066) - Disable Start button if null

**Current Usage:**
- ✅ **Correct:** ใช้ `assigned_operator_id` สำหรับ UI validation

#### Table Display (renderRowActions)
**Line:** 390-400  
**Fields Used:**
- `row.assigned_to` (line 390) - Check if assigned
- `row.assigned_name` (line 395) - Display operator name

**Current Usage:**
- ⚠️ **Legacy:** ใช้ `assigned_to` และ `assigned_name` (ควร migrate ไปใช้ `assigned_operator_id`)

#### saveOperatorAssignment()
**Line:** ~2080-2095  
**Fields Used:**
- `assigned_operator_id` - Auto-save when operator select changes

**Current Usage:**
- ✅ **Correct:** ใช้ `assigned_operator_id` สำหรับ auto-save

---

## 4. Conflicts / Redundant Fields

### ⚠️ Conflict 1: Multiple Operator Fields in Job Ticket
**Location:** `source/job_ticket.php` (INSERT/UPDATE statements)  
**Issue:**
- Job Ticket มี 3 fields สำหรับ operator: `assigned_to`, `assigned_user_id`, `assigned_operator_id`
- ทั้ง 3 fields ถูกเขียนใน INSERT/UPDATE statements
- ไม่มี clear rule ว่าควรใช้ field ไหนเป็นหลัก

**Risk:**
- Data inconsistency - ถ้า payload ไม่สอดคล้องกัน
- Confusion ในการ query - ไม่รู้ว่า field ไหนเป็น source of truth

**Current Behavior:**
- `assigned_operator_id` = NEW field (Task 24.6) - ควรเป็น primary
- `assigned_user_id` = Legacy field - ยังใช้อยู่
- `assigned_to` = Legacy field (VARCHAR) - ยังใช้อยู่

### ⚠️ Conflict 2: Operator Name Display Logic
**Location:** 
- `source/job_ticket.php` (line 796-804): `assigned_name` มาจาก `assigned_user_id`
- `assets/javascripts/hatthasilpa/job_ticket.js` (line 2039): Display ใช้ `assigned_name` หรือ `assigned_to`
- `assets/javascripts/hatthasilpa/job_ticket.js` (line 2066): UI validation ใช้ `assigned_operator_id`

**Issue:**
- Operator name มาจาก `assigned_user_id` แต่ validation ใช้ `assigned_operator_id`
- UI อาจแสดงชื่อผิดถ้า 2 fields ไม่ตรงกัน

**Risk:**
- User confusion - เห็นชื่อ operator แต่ validation ใช้ field อื่น
- Display inconsistency - อาจแสดงชื่อ operator ผิด

### ⚠️ Conflict 3: Legacy Fields Still in UI
**Location:** `assets/javascripts/hatthasilpa/job_ticket.js`  
**Issue:**
- `#ticket_assigned` select (line 3023-3024) ยังใช้ `assigned_to` และ `assigned_user_id`
- `#jt-operator` select (line 3025) ใช้ `assigned_operator_id` (NEW)
- UI มี 2 selects สำหรับ operator (อาจทำให้สับสน)

**Current State:**
- `#ticket_assigned` = Legacy select (ยังมีอยู่)
- `#jt-operator` = NEW select (Task 24.6)

**Risk:**
- User confusion - มี 2 selects สำหรับ operator
- Data inconsistency - อาจเขียนทั้ง 2 fields ไม่ตรงกัน

### ⚠️ Conflict 4: List Query JOIN Logic
**Location:** `source/job_ticket.php` (line 715-716)  
**Issue:**
- List query JOIN `assigned_user_id` → `bgerp.account_org` → `bgerp.account`
- แต่ validation และ UI ใช้ `assigned_operator_id`

**Current Behavior:**
- `assigned_name` มาจาก `assigned_user_id` JOIN
- แต่ UI validation ใช้ `assigned_operator_id`

**Risk:**
- Display อาจแสดงชื่อ operator ผิดถ้า `assigned_user_id` ≠ `assigned_operator_id`

### ⚠️ Dead Code: assigned_to in Views
**Location:** `views/job_ticket.php`  
**Issue:**
- Line 523-524: `#ticket_assigned` select (legacy)
- แต่ Task 24.6 เพิ่ม `#jt-operator` select (NEW) ใน offcanvas

**Current State:**
- Legacy select ยังมีอยู่ (อาจไม่ได้ใช้แล้ว)
- NEW select ถูกเพิ่มใน Task 24.6

**Risk:**
- Dead code - legacy select อาจไม่ได้ใช้แล้ว
- Confusion - มี 2 selects สำหรับ operator

### ✅ Separate Concern: job_task.assigned_to
**Location:** `source/job_ticket.php` (task_update, task_assign)  
**Status:** ✅ **OK** - Separate concern  
**Reason:**
- `job_task.assigned_to` = Task-level assignment (ไม่เกี่ยวกับ ticket-level operator)
- ไม่ต้อง migrate

---

## 5. Clean Migration Paths

### → KEEP: assigned_operator_id
**Reason:**
- NEW field (Task 24.6)
- Primary field สำหรับ ticket-level operator assignment
- Validation ใช้ field นี้
- UI ใช้ field นี้

**Actions:**
- ✅ Keep as primary field
- ✅ Use for all ticket-level operator operations

### → DEPRECATE: assigned_to (VARCHAR)
**Reason:**
- Legacy field (VARCHAR - ไม่ ideal)
- Redundant with `assigned_operator_id`
- ไม่มี clear use case

**Actions:**
- ⚠️ Mark as deprecated
- ⚠️ Stop writing to this field (set NULL)
- 🔄 Future: Remove from INSERT/UPDATE statements

### → DEPRECATE: assigned_user_id
**Reason:**
- Legacy field
- Redundant with `assigned_operator_id`
- ใช้เฉพาะ JOIN สำหรับ `assigned_name`

**Actions:**
- ⚠️ Keep for backward compatibility (JOIN logic)
- ⚠️ Stop writing to this field in new tickets
- 🔄 Future: Migrate JOIN logic to use `assigned_operator_id` instead

### → MIGRATION REQUIRED: Unify Operator Display
**Current State:**
- `assigned_name` มาจาก `assigned_user_id` JOIN
- UI validation ใช้ `assigned_operator_id`

**Required Actions:**
1. Change JOIN logic to use `assigned_operator_id` instead of `assigned_user_id`
2. Update `get` action to fetch operator name from `assigned_operator_id`
3. Update list query to JOIN `assigned_operator_id` → `bgerp.account`

**Files to Update:**
- `source/job_ticket.php`:
  - Line 715-716: Change JOIN to use `assigned_operator_id`
  - Line 796-804: Change operator name fetch to use `assigned_operator_id`

### → PATCH REQUIRED: Remove Legacy Fields from INSERT/UPDATE
**Current State:**
- INSERT/UPDATE statements include all 3 fields

**Required Actions:**
1. Remove `assigned_to` from INSERT/UPDATE statements
2. Remove `assigned_user_id` from INSERT/UPDATE statements (or keep for backward compat)
3. Keep only `assigned_operator_id` in INSERT/UPDATE

**Files to Update:**
- `source/job_ticket.php`:
  - Line 1019, 1021: Remove `assigned_to`, `assigned_user_id` from INSERT
  - Line 1190, 1193: Remove `assigned_to`, `assigned_user_id` from UPDATE
  - Line 918-920: Remove from payload construction
  - Line 1205-1207: Remove from payload construction

### → PATCH REQUIRED: Remove Legacy Fields from JS Payload
**Current State:**
- JS sends all 3 fields in create/update payload

**Required Actions:**
1. Remove `assigned_to` from payload
2. Remove `assigned_user_id` from payload
3. Keep only `assigned_operator_id` in payload

**Files to Update:**
- `assets/javascripts/hatthasilpa/job_ticket.js`:
  - Line 1916-1917: Remove from payload
  - Line 1979-1980: Remove from payload
  - Line 3023-3024: Remove from payload

### → PATCH REQUIRED: Remove Legacy Select from UI
**Current State:**
- `#ticket_assigned` select (legacy) ยังมีอยู่
- `#jt-operator` select (NEW) ถูกเพิ่ม

**Required Actions:**
1. Remove `#ticket_assigned` select from views
2. Remove related JS code for `#ticket_assigned`
3. Keep only `#jt-operator` select

**Files to Update:**
- `views/job_ticket.php`:
  - Line 523-524: Remove legacy select
- `assets/javascripts/hatthasilpa/job_ticket.js`:
  - Remove all references to `#ticket_assigned`
  - Remove `fillTicketForm()` code that sets `assigned_user_id`

### → PATCH REQUIRED: Update List Query JOIN
**Current State:**
- List query JOIN `assigned_user_id` → `bgerp.account_org` → `bgerp.account`

**Required Actions:**
1. Change JOIN to use `assigned_operator_id` instead
2. Update column alias to `assigned_operator_name`

**Files to Update:**
- `source/job_ticket.php`:
  - Line 715-716: Change JOIN to use `assigned_operator_id`
  - Update column alias

---

## 6. Risk Assessment

### 🔴 High Risk

1. **Data Inconsistency Between Fields**
   - Risk: `assigned_to`, `assigned_user_id`, และ `assigned_operator_id` อาจมีค่าไม่ตรงกัน
   - Impact: User confusion, validation errors, display issues
   - Priority: HIGH

2. **Operator Name Display Mismatch**
   - Risk: Display ใช้ `assigned_user_id` แต่ validation ใช้ `assigned_operator_id`
   - Impact: User เห็นชื่อ operator ผิด
   - Priority: HIGH

### 🟡 Medium Risk

3. **Legacy Fields Still Written**
   - Risk: Legacy fields ยังถูกเขียนใน INSERT/UPDATE
   - Impact: Data redundancy, confusion
   - Priority: MEDIUM

4. **Two Operator Selects in UI**
   - Risk: UI มี 2 selects สำหรับ operator
   - Impact: User confusion
   - Priority: MEDIUM

### 🟢 Low Risk

5. **Dead Code in Views**
   - Risk: Legacy select ยังมีอยู่ (อาจไม่ได้ใช้)
   - Impact: Code maintenance burden
   - Priority: LOW

---

## 7. Recommendations

### Immediate Actions (Task 24.6.2)

1. ✅ **Unify Operator Display Logic**
   - Change JOIN to use `assigned_operator_id` instead of `assigned_user_id`
   - Update `get` action to fetch operator name from `assigned_operator_id`

2. ✅ **Remove Legacy Fields from Payloads**
   - Remove `assigned_to` and `assigned_user_id` from JS payloads
   - Keep only `assigned_operator_id`

3. ✅ **Remove Legacy Select from UI**
   - Remove `#ticket_assigned` select from views
   - Remove related JS code

### Future Actions (Post-Task 24.6)

1. 🔄 **Stop Writing Legacy Fields**
   - Remove `assigned_to` and `assigned_user_id` from INSERT/UPDATE statements
   - Keep columns for backward compatibility (read-only)

2. 🔄 **Data Migration Script**
   - Migrate existing data from `assigned_user_id` → `assigned_operator_id`
   - Set legacy fields to NULL for new tickets

3. 🔄 **Remove Legacy Columns**
   - After migration complete, consider removing `assigned_to` and `assigned_user_id` columns
   - Update all queries to use `assigned_operator_id` only

---

## 8. Summary

### Current State

**Fields in Use:**
- `assigned_operator_id` (NEW - Task 24.6) - ✅ Primary field
- `assigned_user_id` (Legacy) - ⚠️ Still used for JOIN
- `assigned_to` (Legacy - VARCHAR) - ⚠️ Still written

**Conflicts:**
- ⚠️ Multiple fields for same purpose
- ⚠️ JOIN logic uses `assigned_user_id` but validation uses `assigned_operator_id`
- ⚠️ UI has 2 selects for operator

**Risk Level:**
- 🔴 HIGH: Data inconsistency risk
- 🟡 MEDIUM: Legacy fields still written
- 🟢 LOW: Dead code in views

### Recommended Path

1. **Keep:** `assigned_operator_id` (primary field)
2. **Deprecate:** `assigned_to`, `assigned_user_id` (stop writing)
3. **Migrate:** JOIN logic to use `assigned_operator_id`
4. **Clean:** Remove legacy selects from UI
5. **Future:** Remove legacy columns after migration

---

## 9. Additional Files Scanned

### Service Files

#### JobCreationService.php
**Location:** `source/BGERP/Service/JobCreationService.php`  
**Findings:**
- ⚠️ **createFromBinding()** (line 445-473): INSERT job_ticket **WITHOUT** operator fields
  - Fields included: `ticket_code, job_name, id_product, target_qty, due_date, id_mo, status, routing_mode`
  - **Missing:** `assigned_to`, `assigned_user_id`, `assigned_operator_id`
- ⚠️ **createFromBindingWithoutTokens()** (line 744-766): Same issue - no operator fields
- ⚠️ **createDAGJob()** (line 66-102): Updates existing job_ticket but doesn't set operator fields
- **Impact:** Job Tickets created via JobCreationService will have NULL operator assignments

#### NodeAssignmentService.php
**Location:** `source/BGERP/Service/NodeAssignmentService.php`  
**Findings:**
- ✅ Uses `assigned_to_user_id` (line 195-196) - Separate concern for token-level assignment
- ✅ Creates `token_assignment` records (not job_ticket assignment)
- **Status:** Separate concern - no conflict with job_ticket operator fields

#### OperatorDirectoryService.php
**Location:** `source/BGERP/Service/OperatorDirectoryService.php`  
**Findings:**
- ✅ Centralized service for listing operators
- ✅ Used by `job_ticket.php` → `users_for_assignment` action (line 1639-1659)
- ✅ Used by `assignment_api.php` → `get_available_operators` action (line 411-417)
- **Status:** Does NOT set operator fields - only provides operator lists

### API Files

#### assignment_api.php
**Location:** `source/assignment_api.php`  
**Findings:**
- ✅ Uses `assigned_to_user_id` in `token_assignment` table (line 628, 647)
- ✅ Uses `OperatorDirectoryService` for operator listing (line 411-417)
- **Status:** Separate concern - token-level assignment (not job_ticket level)

#### job_ticket_dag.php
**Location:** `source/job_ticket_dag.php`  
**Findings:**
- ⚠️ Updates `job_ticket.current_node_id` (line 87-92)
- ✅ Uses `operator_user_id` and `operator_name` from session/member (line 97-98)
- **Status:** Legacy API - doesn't set job_ticket operator fields

#### classic_api.php
**Location:** `source/classic_api.php`  
**Findings:**
- ⚠️ **create_classic_job()** (line 325-328): INSERT job_ticket **WITHOUT** operator fields
  - Fields included: `ticket_code, job_name, target_qty, process_mode, production_type, status, id_routing_graph, graph_version, id_mo, notes, created_by`
  - **Missing:** `assigned_to`, `assigned_user_id`, `assigned_operator_id`
- **Impact:** Classic Line Job Tickets created via this API will have NULL operator assignments

#### team_api.php
**Location:** `source/team_api.php`  
**Findings:**
- ✅ Uses `assigned_to_user_id` in token_assignment (line 899-901, 1143, 1145)
- **Status:** Separate concern - team assignment for tokens (not job_ticket level)

#### qc_rework.php
**Location:** `source/qc_rework.php`  
**Findings:**
- ✅ Uses `assigned_to` in `qc_rework_task` table (line 429, 463, 540, 580, 583, 821, 843)
- **Status:** Separate concern - QC rework task assignment (not job_ticket level)

#### token_management_api.php
**Location:** `source/token_management_api.php`  
**Findings:**
- ✅ Token-level operations (reassign, move, cancel)
- **Status:** Separate concern - doesn't touch job_ticket operator fields

#### hatthasilpa_jobs_api.php
**Location:** `source/hatthasilpa_jobs_api.php`  
**Findings:**
- ✅ Uses `operatorId` parameter in functions (line 1820, 1823, 1866, 1872, 1912, 1916, 2046)
- **Status:** Hatthasilpa-specific - separate from Classic Line job_ticket

### Integration Points

#### MO → Job Ticket Creation
**Location:** `source/mo.php` (line 1491-1528)  
**Findings:**
- ✅ Uses `JobCreationService::createDAGJob()` (line 1498-1507)
- ⚠️ **Does NOT pass operator assignment** to job creation
- **Impact:** Job Tickets created from MO will have NULL operator assignments

### Summary of Additional Findings

1. **JobCreationService.php** - ⚠️ **CRITICAL:** Creates job_ticket without operator fields
2. **classic_api.php** - ⚠️ **CRITICAL:** Creates job_ticket without operator fields
3. **assignment_api.php** - ✅ Separate concern (token-level)
4. **team_api.php** - ✅ Separate concern (token-level)
5. **qc_rework.php** - ✅ Separate concern (rework task-level)
6. **NodeAssignmentService.php** - ✅ Separate concern (token-level)
7. **OperatorDirectoryService.php** - ✅ Provides operator lists only
8. **MO integration** - ⚠️ Does not pass operator to job creation

---

## 10. Critical Gaps Identified

### 🔴 Gap 1: JobCreationService Doesn't Set Operator
**Files Affected:**
- `source/BGERP/Service/JobCreationService.php` (createFromBinding, createFromBindingWithoutTokens)
- `source/mo.php` (calls JobCreationService)
- `source/classic_api.php` (creates job_ticket directly)

**Issue:**
- Job Tickets created programmatically have NULL operator assignments
- No way to pass `assigned_operator_id` during creation

**Risk:**
- Job Tickets created from MO or Classic API will fail `start` validation (requires operator)

**Required Action:**
- Add `assigned_operator_id` parameter to JobCreationService methods
- Pass operator from MO → JobCreationService → job_ticket INSERT
- Add operator parameter to classic_api.php job creation

### 🟡 Gap 2: Multiple Creation Paths Don't Set Operator
**Files Affected:**
- `source/job_ticket.php` → `create` action ✅ (supports operator)
- `source/BGERP/Service/JobCreationService.php` → createFromBinding ❌ (no operator)
- `source/classic_api.php` → create_classic_job ❌ (no operator)

**Issue:**
- Inconsistent operator assignment across creation paths
- Only manual creation (via job_ticket.php UI) sets operator

**Risk:**
- Programmatic creation always results in NULL operator

**Required Action:**
- Unify creation paths to always accept `assigned_operator_id`
- Make operator assignment mandatory or optional (but consistent)

---

**Next Step:** Task 24.6.2 — Operator Field Harmonization Patch

