# Task 24.6 Results – Job Ticket Assigned Operator (Classic Line)

**Date:** 2025-11-29  
**Status:** ✅ **COMPLETED**  
**Objective:** เพิ่มความสามารถในการกำหนด "ผู้รับผิดชอบหลัก" (Assigned Operator) ให้กับ Job Ticket (Classic Line) และบังคับให้การเปลี่ยนสถานะ Start ต้องมี operator ที่ถูกกำหนดไว้ก่อน

---

## Executive Summary

Task 24.6 ได้เพิ่มความสามารถในการกำหนด Assigned Operator ให้กับ Job Ticket โดย:

- **เพิ่ม `assigned_operator_id` field** ใน database table `job_ticket`
- **ปรับปรุง Backend API** (`job_ticket.php`) ให้รองรับ CRUD operations สำหรับ `assigned_operator_id`
- **เพิ่ม UI/JS** สำหรับเลือกและแสดง Assigned Operator ใน offcanvas detail view
- **บังคับให้มี operator ก่อน start** - ป้องกันการ start job ticket ที่ยังไม่มี operator assigned
- **Event logging** - บันทึก event เมื่อ operator เปลี่ยน

**Key Achievements:**
- ✅ เพิ่ม column `assigned_operator_id` ใน `job_ticket` table (via migration)
- ✅ ปรับ CRUD operations (list, get, create, update) ให้รองรับ `assigned_operator_id`
- ✅ เพิ่ม validation rule: ห้าม start ถ้า `assigned_operator_id` เป็น null
- ✅ เพิ่ม UI สำหรับเลือก operator ใน offcanvas detail view
- ✅ เพิ่ม operator dropdown ที่โหลดจาก API endpoint
- ✅ ปรับ Start button ให้ disable ถ้าไม่มี operator assigned
- ✅ เพิ่ม error handling สำหรับ `ERR_OPERATOR_REQUIRED`
- ✅ Event logging เมื่อ operator เปลี่ยน
- ✅ Backward compatible 100%

---

## Files Modified

### 1. Database Migration: `database/tenant_migrations/2025_11_28_add_job_ticket_assigned_operator.php`

**Purpose:** เพิ่ม column `assigned_operator_id` ใน `job_ticket` table

**Changes:**
- เพิ่ม column `assigned_operator_id INT(11) NULL DEFAULT NULL`
- เพิ่ม index `idx_assigned_operator` สำหรับ performance
- Migration idempotent (ใช้ helper functions ที่เช็ค column ก่อน)

**Schema:**
```sql
ALTER TABLE job_ticket 
ADD COLUMN assigned_operator_id INT(11) NULL DEFAULT NULL 
COMMENT 'FK to bgerp.account.id_member - Primary operator assigned to this job ticket (Task 24.6)';

ALTER TABLE job_ticket 
ADD INDEX idx_assigned_operator (assigned_operator_id);
```

**Note:** Migration ถูกรัน manual ผ่าน MySQL command เนื่องจาก bootstrap_migrations.php มี issue ในการรัน migration file นี้

### 2. `source/job_ticket.php`

#### 2.1 CRUD Operations - `assigned_operator_id`

**List Action:**
- ใช้ `ajt.*` ใน SELECT query เพื่อดึง `assigned_operator_id` อัตโนมัติ
- Column จะถูก include ใน response array ผ่าน `ajt.*`

**Get Action:**
- เพิ่ม `assigned_operator_id` ใน SELECT query
- Include ใน response data

**Create Action:**
- อ่าน `assigned_operator_id` จาก request payload
- Validate ว่าเป็น integer หรือ null
- Include ใน INSERT statement

**Update Action:**
- อ่าน `assigned_operator_id` จาก request payload
- ดึงค่าเดิมจาก database ก่อน update (สำหรับ event logging)
- Update `assigned_operator_id` ใน UPDATE statement
- Log event `OPERATOR_CHANGED` ถ้า operator เปลี่ยน

#### 2.2 Start Validation Rule

**Implementation:**
- เพิ่ม validation ใน `start` action:
  ```php
  if (empty($ticket['assigned_operator_id'])) {
      json_error_state_machine('ERR_OPERATOR_REQUIRED', 
          'Cannot start this job because no operator is assigned.', 
          $jobTicketId, 
          $ticket['status']);
  }
  ```

**Error Response:**
```json
{
  "ok": false,
  "error": "Cannot start this job because no operator is assigned.",
  "error_code": "ERR_OPERATOR_REQUIRED",
  "ticket_id": 1234,
  "status": "planned"
}
```

#### 2.3 Event Logging

**Implementation:**
- ใน `update` action:
  - เปรียบเทียบ `oldAssignedOperatorId` กับ `newAssignedOperatorId`
  - ถ้ามีการเปลี่ยน (จาก A → B หรือ null → B หรือ A → null):
    - เรียก `logJobTicketEvent()` ด้วย event type `OPERATOR_CHANGED`
    - Payload: `{ "from": old_operator_id, "to": new_operator_id }`

**Event Table:** `job_ticket_event`

#### 2.4 Column Existence Check

**Implementation:**
- เพิ่ม logic ตรวจสอบว่า column `assigned_operator_id` มีอยู่หรือไม่ก่อน INSERT/UPDATE
- ใช้ `information_schema.COLUMNS` เพื่อเช็ค column
- รองรับกรณีที่ migration ยังไม่ได้รัน

**Pattern:**
```php
$columnExists = false;
$checkColumn = $tenantDb->query("SELECT COUNT(*) as cnt FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'job_ticket' AND COLUMN_NAME = 'assigned_operator_id'");
if ($checkColumn) {
    $row = $checkColumn->fetch_assoc();
    $columnExists = ($row['cnt'] > 0);
    $checkColumn->free();
}
```

### 3. `assets/javascripts/hatthasilpa/job_ticket.js`

#### 3.1 Operator Options Loading

**New Function: `loadOperatorOptions()`**
- โหลด operator list จาก `users_for_assignment` endpoint
- Populate `<select id="jt-operator">` ด้วย operator options
- Support caching และ Promise-based loading
- Handle errors gracefully (fallback to empty options)

**Implementation:**
```javascript
function loadOperatorOptions() {
  const $select = $('#jt-operator');
  if (!$select.length) return Promise.resolve();
  
  // Check cache first
  if (window._operatorOptionsCache) {
    populateOperatorSelect($select, window._operatorOptionsCache);
    return Promise.resolve();
  }
  
  return $.post('source/job_ticket.php', { action: 'users_for_assignment' })
    .done(function(resp) {
      if (resp && resp.ok && Array.isArray(resp.users)) {
        window._operatorOptionsCache = resp.users;
        populateOperatorSelect($select, resp.users);
      }
    })
    .fail(function() {
      console.warn('[Job Ticket] Failed to load operator options');
    });
}
```

#### 3.2 Operator Binding

**In `loadTicketDetail()`:**
- เรียก `loadOperatorOptions()` ก่อน fetch ticket data
- Set ค่าใน `#jt-operator` ตาม `data.assigned_operator_id`

**In `gatherTicketPayload()`:**
- อ่านค่าจาก `#jt-operator` และเพิ่มใน payload:
  ```javascript
  assigned_operator_id: ($('#jt-operator').val() || '').trim() || null
  ```

**In `fillTicketForm()`:**
- Set `assigned_operator_id` เมื่อโหลด ticket สำหรับ editing

#### 3.3 Auto-Save Operator Assignment

**New Function: `saveOperatorAssignment()`**
- เรียกเมื่อ `#jt-operator` select เปลี่ยนแปลง
- Auto-save `assigned_operator_id` โดยเรียก update API
- Reload ticket detail หลัง save สำเร็จ

**Implementation:**
```javascript
$('#jt-operator').on('change', function() {
  const ticketId = getCurrentTicketId();
  if (!ticketId) return;
  
  saveOperatorAssignment(ticketId);
});
```

#### 3.4 Start Button UI Logic

**In `renderLifecycleButtons()`:**
- เช็คว่า `assignedOperatorId` มีค่าหรือไม่
- ถ้า status = `planned` และไม่มี operator:
  - Disable Start button
  - เพิ่ม tooltip: "กรุณาเลือกช่างผู้รับผิดชอบก่อนเริ่มงาน"

**Implementation:**
```javascript
if (normalizedStatus === 'planned') {
  if (!assignedOperatorId) {
    buttons.push(`
      <button type="button" class="btn btn-sm btn-secondary" disabled
        title="กรุณาเลือกช่างผู้รับผิดชอบก่อนเริ่มงาน">
        <i class="fe fe-play"></i> Start
      </button>
    `);
  } else {
    buttons.push(`
      <button type="button" class="btn btn-sm btn-primary js-job-start">
        <i class="fe fe-play"></i> Start
      </button>
    `);
  }
}
```

#### 3.5 Error Handling: `ERR_OPERATOR_REQUIRED`

**In `callLifecycleTransition()`:**
- เช็ค error_code จาก backend response
- ถ้า `error_code === 'ERR_OPERATOR_REQUIRED'`:
  - แสดง warning banner
  - Focus ที่ `#jt-operator` select
  - แสดง error message ที่เข้าใจง่าย

**Implementation:**
```javascript
if (resp && resp.error_code === 'ERR_OPERATOR_REQUIRED') {
  $('#jt-warning').removeClass('d-none').html(`
    <i class="fe fe-alert-circle me-2"></i>
    <strong>Error:</strong> ${escapeHtml(resp.error || 'ไม่สามารถเริ่มงานได้ เนื่องจากยังไม่ได้เลือก Assigned Operator')}
  `);
  $('#jt-operator').focus();
  return;
}
```

### 4. `views/job_ticket.php`

#### 4.1 Assigned Operator Field in Offcanvas

**Location:** Header section of offcanvas detail view

**HTML:**
```html
<!-- Task 24.6 — Assigned Operator -->
<div class="mb-3">
  <label for="jt-operator" class="form-label">
    ช่างผู้รับผิดชอบ (Assigned Operator)
  </label>
  <select id="jt-operator" class="form-select" name="assigned_operator_id">
    <option value="">— ไม่ระบุ —</option>
    <!-- Options will be loaded by JS -->
  </select>
  <small class="form-text text-muted">
    เลือกช่างผู้รับผิดชอบหลักสำหรับงานนี้ (จำเป็นก่อนเริ่มงาน)
  </small>
</div>
```

**Position:** วางไว้ใกล้กับ field อื่นๆ ใน header section (Product, Quantity, Routing)

#### 4.2 Optional: Operator Column in Main Table

**Status:** Not implemented in this task (marked as optional)

**Note:** Column Operator ในตารางหลักเป็น optional และสามารถเพิ่มในอนาคตได้หาก backend ส่ง `operator_name` มาใน list response

---

## Database Schema Changes

### New Column: `assigned_operator_id`

**Table:** `job_ticket`  
**Type:** `INT(11) NULL DEFAULT NULL`  
**Index:** `idx_assigned_operator (assigned_operator_id)`  
**Comment:** FK to bgerp.account.id_member - Primary operator assigned to this job ticket (Task 24.6)

**Migration File:** `database/tenant_migrations/2025_11_28_add_job_ticket_assigned_operator.php`

**Note:** Migration ถูกรัน manual ผ่าน MySQL command เนื่องจาก bootstrap_migrations.php มี issue

---

## API Changes

### 1. List Action

**Endpoint:** `GET job_ticket.php?action=list`

**Response:**
- `assigned_operator_id` จะถูก include ใน response array ผ่าน `ajt.*` SELECT

### 2. Get Action

**Endpoint:** `GET job_ticket.php?action=get&id_job_ticket={id}`

**Response:**
```json
{
  "ok": true,
  "data": {
    "id_job_ticket": 123,
    "assigned_operator_id": 45,
    ...
  }
}
```

### 3. Create Action

**Endpoint:** `POST job_ticket.php?action=create`

**Request:**
```json
{
  "job_name": "...",
  "assigned_operator_id": 45,
  ...
}
```

**Response:**
- `assigned_operator_id` จะถูกบันทึกใน database

### 4. Update Action

**Endpoint:** `POST job_ticket.php?action=update`

**Request:**
```json
{
  "id_job_ticket": 123,
  "assigned_operator_id": 46,
  ...
}
```

**Response:**
- `assigned_operator_id` จะถูก update ใน database
- ถ้า operator เปลี่ยน จะมี event `OPERATOR_CHANGED` ถูกบันทึก

### 5. Start Action (Modified)

**Endpoint:** `POST job_ticket.php?action=start`

**Validation:**
- ต้องมี `assigned_operator_id` (ไม่เป็น null)
- ถ้าไม่มี จะ return error:
  ```json
  {
    "ok": false,
    "error": "Cannot start this job because no operator is assigned.",
    "error_code": "ERR_OPERATOR_REQUIRED",
    "ticket_id": 123,
    "status": "planned"
  }
  ```

### 6. Users for Assignment Action

**Endpoint:** `POST job_ticket.php?action=users_for_assignment`

**Response:**
```json
{
  "ok": true,
  "users": [
    {
      "id_member": 45,
      "label": "John Doe"
    },
    ...
  ]
}
```

**Usage:** ใช้สำหรับ populate operator dropdown ใน UI

---

## Business Rules

### 1. Operator Assignment

- Job Ticket (Classic Line) สามารถมี `assigned_operator_id` ได้ 0 หรือ 1 คน
- `assigned_operator_id` เป็น nullable (สามารถเป็น null ได้)
- สำหรับ transition `planned` → `in_progress` (start action) จะบังคับให้ต้องมี operator ก่อน

### 2. Start Validation

- **Rule:** ห้าม start job ticket ถ้า `assigned_operator_id` เป็น null
- **Scope:** ใช้เฉพาะหน้า Admin UI (`job_ticket.php`)
- **Exception:** ยังไม่บังคับสำหรับ pause/resume/complete actions

### 3. Operator Change

- อนุญาตให้เปลี่ยน operator ได้แม้งานเริ่มแล้ว (status = `in_progress` / `paused`)
- การเปลี่ยน operator จะถูกบันทึกเป็น event `OPERATOR_CHANGED` ใน `job_ticket_event` table
- Payload: `{ "from": old_operator_id, "to": new_operator_id }`

### 4. Backward Compatibility

- Job Tickets เดิมที่ไม่มี `assigned_operator_id` (null) จะยังใช้งานได้
- แต่จะไม่สามารถ start ได้จนกว่าจะเลือก operator
- UI จะแสดง warning เมื่อพยายาม start โดยไม่มี operator

---

## UI/UX Improvements

### 1. Operator Selection Dropdown

**Location:** Offcanvas detail view (header section)

**Features:**
- Dropdown ที่โหลด operator list จาก API
- Options cached เพื่อลด API calls
- Auto-save เมื่อเปลี่ยน operator
- Tooltip และ hint text สำหรับ user guidance

### 2. Start Button State

**Behavior:**
- **Disabled:** เมื่อ status = `planned` และไม่มี `assigned_operator_id`
- **Tooltip:** "กรุณาเลือกช่างผู้รับผิดชอบก่อนเริ่มงาน"
- **Enabled:** เมื่อมี `assigned_operator_id` assigned

**Visual:**
- Disabled button ใช้ class `btn-secondary` และ `disabled` attribute
- Enabled button ใช้ class `btn-primary`

### 3. Error Handling

**Warning Banner:**
- แสดงเมื่อเกิด `ERR_OPERATOR_REQUIRED` error
- Focus ไปที่ `#jt-operator` select
- Error message ที่เข้าใจง่าย (ภาษาไทย)

**Location:** Header section ของ offcanvas detail view

### 4. Auto-Save Behavior

**Implementation:**
- เมื่อ user เปลี่ยน operator ใน dropdown
- System จะ auto-save โดยเรียก update API
- Reload ticket detail หลัง save สำเร็จ
- แสดง loading indicator ถ้าจำเป็น

---

## Testing Scenarios

### 1. Create Job Ticket with Operator

**Steps:**
1. สร้าง Job Ticket ใหม่
2. เลือก Assigned Operator จาก dropdown
3. Save ticket

**Expected:**
- ✅ `assigned_operator_id` ถูกบันทึกใน database
- ✅ Operator name แสดงใน offcanvas detail view

### 2. Create Job Ticket without Operator

**Steps:**
1. สร้าง Job Ticket ใหม่
2. ไม่เลือก Assigned Operator
3. Save ticket

**Expected:**
- ✅ Ticket ถูกสร้างได้ (null `assigned_operator_id`)
- ✅ Start button ถูก disable
- ✅ Tooltip แสดงว่า "กรุณาเลือกช่างผู้รับผิดชอบก่อนเริ่มงาน"

### 3. Start without Operator

**Steps:**
1. Job Ticket ที่ไม่มี operator assigned
2. พยายามกด Start button

**Expected:**
- ❌ Start button ถูก disable (ไม่สามารถกดได้)
- ❌ ถ้า bypass ผ่าน API จะได้ error `ERR_OPERATOR_REQUIRED`
- ✅ Warning banner แสดง error message

### 4. Start with Operator

**Steps:**
1. Job Ticket ที่มี operator assigned
2. กด Start button

**Expected:**
- ✅ Start button enabled
- ✅ Transition ไปที่ `in_progress` สำเร็จ
- ✅ Token lifecycle ทำงานตามปกติ

### 5. Change Operator

**Steps:**
1. Job Ticket ที่มี operator A assigned
2. เปลี่ยนเป็น operator B ใน dropdown
3. Auto-save triggered

**Expected:**
- ✅ `assigned_operator_id` ถูก update เป็น operator B
- ✅ Event `OPERATOR_CHANGED` ถูกบันทึก
- ✅ Payload: `{ "from": A, "to": B }`

### 6. Operator Dropdown Loading

**Steps:**
1. เปิด offcanvas detail view
2. ดู operator dropdown

**Expected:**
- ✅ Operator list โหลดจาก API
- ✅ Options cached สำหรับ performance
- ✅ "— ไม่ระบุ —" option แสดงเป็นตัวแรก

### 7. Backward Compatibility

**Steps:**
1. Job Ticket เดิมที่ไม่มี `assigned_operator_id`
2. เปิด offcanvas detail view

**Expected:**
- ✅ Ticket แสดงได้ปกติ
- ✅ Operator dropdown แสดง "— ไม่ระบุ —"
- ✅ Start button disabled (ถ้า status = `planned`)

---

## Security & Safety

### 1. Input Validation

- `assigned_operator_id` ถูก validate ว่าเป็น integer หรือ null
- SQL injection prevention ผ่าน prepared statements
- XSS prevention ใน UI (ใช้ `escapeHtml()`)

### 2. Authorization

- Permission check ผ่าน `must_allow_code($member, 'hatthasilpa.job.ticket')`
- Operator assignment ไม่ได้จำกัดว่า user login ต้องเป็น operator (Admin สามารถ assign ได้)

### 3. Data Integrity

- Event logging สำหรับ operator changes
- Backward compatible กับ tickets เดิมที่ไม่มี operator

---

## Performance Notes

### 1. Operator Options Caching

- Operator list ถูก cache ใน `window._operatorOptionsCache`
- ลด API calls สำหรับ dropdown loading

### 2. Column Existence Check

- Column existence check ใช้ `information_schema.COLUMNS`
- Caching สามารถเพิ่มได้ในอนาคตเพื่อลด database queries

### 3. Index Performance

- Index `idx_assigned_operator` เพิ่มสำหรับ queries ที่ filter โดย operator

---

## Limitations & Future Enhancements

### Known Limitations

1. **Operator API Endpoint:**
   - ใช้ `users_for_assignment` endpoint ที่มีอยู่แล้ว
   - ยังไม่ได้ integrate กับ People/Skill phase

2. **Operator Column in Main Table:**
   - ยังไม่ได้เพิ่ม Operator column ในตารางหลัก (optional)
   - สามารถเพิ่มในอนาคตได้

3. **Permission System:**
   - ยังไม่มีการจำกัดว่าใครสามารถ assign operator ได้
   - Future: อาจเพิ่ม permission rules

### Future Enhancements

1. **People/Skill Integration:**
   - Integrate กับ People/Skill phase
   - Support operator skills และ availability

2. **Performance Dashboard:**
   - Dashboard สำหรับวัดผลงานช่าง
   - Track performance by operator

3. **Operator History:**
   - แสดง history ของ operator assignments
   - Timeline view สำหรับ operator changes

4. **PWA Integration:**
   - Integrate กับ PWA/Scan Terminal
   - Auto-assign operator จาก PWA login

---

## Migration Notes

### Column Addition

**Migration File:** `database/tenant_migrations/2025_11_28_add_job_ticket_assigned_operator.php`

**Status:** ✅ Migration executed manually

**Note:** Migration ถูกรัน manual ผ่าน MySQL command เนื่องจาก bootstrap_migrations.php มี issue ในการรัน migration file นี้

**SQL Executed:**
```sql
ALTER TABLE job_ticket 
ADD COLUMN assigned_operator_id INT(11) NULL DEFAULT NULL 
COMMENT 'FK to bgerp.account.id_member - Primary operator assigned to this job ticket (Task 24.6)';

ALTER TABLE job_ticket 
ADD INDEX idx_assigned_operator (assigned_operator_id);
```

### Backward Compatibility

- Existing tickets ที่ไม่มี `assigned_operator_id` จะมีค่า null
- Code รองรับกรณีที่ column ยังไม่มี (ผ่าน column existence check)
- ไม่มี breaking changes

---

## Summary

Task 24.6 ได้เพิ่มความสามารถในการกำหนด Assigned Operator ให้กับ Job Ticket (Classic Line) โดย:

**Files Modified:** 3  
**Database Changes:** 1 column added (`assigned_operator_id`)  
**API Changes:** 6 actions modified/added  
**Breaking Changes:** None  
**Backward Compatible:** Yes  
**Error Codes Added:** 1 (`ERR_OPERATOR_REQUIRED`)

**Key Benefits:**
- ✅ Job Tickets สามารถมี "ผู้รับผิดชอบหลัก" ได้
- ✅ ป้องกันการ start job ticket ที่ยังไม่มี operator
- ✅ UI/UX ที่ดีขึ้นสำหรับ operator assignment
- ✅ Event logging สำหรับ operator changes
- ✅ Backward compatible กับ existing tickets
- ✅ รองรับกรณีที่ column ยังไม่มี (graceful degradation)

**Next Steps:**
- Integrate กับ People/Skill phase
- เพิ่ม Performance Dashboard
- PWA integration สำหรับ auto-assign operator

