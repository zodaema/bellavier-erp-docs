# Task 23.6.2 — MO UI Consolidation & Flow Cleanup

> เป้าหมาย: ทำให้หน้า MO ใช้งานง่าย ไม่สับสน และสอดคล้องกับ Flow ใหม่  
> (MO = Planning, Job Ticket = Execution)

---

## 1. Objective

1. ทำให้หน้า MO เป็น **Planning UI** เท่านั้น
2. ตัด / ซ่อน action ที่เป็นการควบคุมหน้างาน (Start / Pause / Resume / Complete) จาก MO
3. ทำให้ผู้ใช้เข้าใจชัดเจนว่า “ขั้นตอนต่อไป ต้องไปจัดการที่หน้า Job Ticket”
4. ปรับ Modal “สร้าง MO” ให้ตรงกับระบบจริง (Routing suggestion, ETA preview) โดยซ่อน UoM จากผู้ใช้ (ระบบจัดการอัตโนมัติ)
5. เพิ่ม UI สำหรับ **Edit MO**
6. เพิ่ม UI สำหรับ **Restore MO** หลังจาก Cancelled
7. ทำความสะอาด logic/UI ที่ขัดแย้งหรือซ้ำซ้อน

---

## 2. Scope

### รวมในงานนี้

- Backend:
  - เพิ่ม / ปรับ action ใน `source/mo.php`
  - Helper สำหรับคำนวณ action ที่อนุญาตตามสถานะของ MO
- Frontend:
  - หน้า List MO (ตาราง)
  - Modal สร้าง MO
  - Modal แก้ไข MO
  - ปุ่ม Restore สำหรับ MO ที่ถูก Cancelled
  - Banner / message ในหน้า Detail (ถ้ามี)

### ไม่รวมในงานนี้

- การปรับปรุงหน้า Job Ticket (ใช้แค่เป็นปลายทาง navigation)
- การเปลี่ยนแปลง Node Behavior / Canonical events
- การเปลี่ยนแปลง ETA engine core (ใช้ของเดิม, เรียกผ่าน service ที่มีอยู่)

---

## 3. Backend Changes (mo.php)

### 3.1 ตัด/ปิด Action ที่เป็นหน้างาน

ใน `source/mo.php`:

- สำหรับ action เดิมที่เกี่ยวกับหน้างาน เช่น:

  - `start_production`
  - `start`
  - `stop`
  - `complete`
  - `resume` (ถ้ามี)

- ให้คงโครงสร้างเดิมไว้ แต่เปลี่ยนให้ **ไม่ทำงานจริง** แล้วคืนค่า error ชัดเจน เช่น:

  ```php
  function handleStartProduction($db, $member) {
      json_error('MO start/stop is now managed via Job Tickets. Please use Job Tickets UI.', [
          'code' => 'MO_ACTION_MOVED_TO_JOB_TICKET'
      ]);
  }
  ```

  ทำแบบเดียวกันกับ `handleStart`, `handleStop`, `handleComplete`, `handleResume` (ถ้ามี) เพื่อให้ backend ไม่พัง แต่ redirect ผู้ใช้ไปใช้ flow ใหม่

> หมายเหตุ: ยังไม่ลบโค้ดเก่าในทันที แต่ “ปิดไม่ให้ใช้งาน” ด้วย error message แทน เพื่อลด risk

---

### 3.2 เพิ่ม Helper `getMoAvailableActions()`

สร้างฟังก์ชันภายใน `mo.php`:

```php
/**
 * Return list of allowed UI actions for a given MO.
 *
 * @param array $mo  Row from `mo` table.
 * @return string[]  e.g. ['plan', 'edit', 'cancel', 'view_job_tickets', 'restore']
 */
function getMoAvailableActions(array $mo): array
{
    $status = $mo['status'] ?? 'draft';

    switch ($status) {
        case 'draft':
            return ['plan', 'edit', 'cancel'];

        case 'planned':
            return ['view_job_tickets', 'edit', 'cancel'];

        case 'in_progress':
            return ['view_job_tickets'];

        case 'qc':
            return ['view_job_tickets'];

        case 'done':
            return ['view_job_tickets'];

        case 'cancelled':
            return ['restore'];

        default:
            return ['view_job_tickets'];
    }
}
```

- ฟังก์ชันนี้จะใช้จากฝั่ง UI (PHP/JSON) เพื่อ render ปุ่มในตาราง

### 3.3 เพิ่ม Action `restore`

เพิ่มใน switch หลักของ `mo.php`:

```php
case 'restore':
    handleRestore($db, $member);
    break;
```

จากนั้นสร้าง `handleRestore()`:

```php
function handleRestore($db, $member)
{
    must_allow_code($member, 'mo.edit');

    $id_mo = (int)($_POST['id_mo'] ?? 0);
    if ($id_mo <= 0) {
        json_error('Invalid MO ID', ['code' => 'INVALID_MO_ID']);
    }

    $tenantDb = $db->getTenantDb();
    $stmt = $tenantDb->prepare("SELECT id_mo, status, graph_instance_id FROM mo WHERE id_mo = ?");
    $stmt->bind_param('i', $id_mo);
    $stmt->execute();
    $res = $stmt->get_result();
    $mo = $res->fetch_assoc();
    $stmt->close();

    if (!$mo) {
        json_error('MO not found', ['code' => 'MO_NOT_FOUND']);
    }

    if ($mo['status'] !== 'cancelled') {
        json_error('Only cancelled MO can be restored', ['code' => 'MO_RESTORE_INVALID_STATUS']);
    }

    // เพื่อความปลอดภัย: restore ได้เฉพาะ MO ที่ยังไม่เคย start graph จริง
    if (!empty($mo['graph_instance_id'])) {
        json_error('Cannot restore MO that already started production graph', [
            'code' => 'MO_RESTORE_GRAPH_ALREADY_STARTED'
        ]);
    }

    // Update back to draft
    $stmt = $tenantDb->prepare("UPDATE mo SET status = 'draft', updated_at = NOW() WHERE id_mo = ?");
    $stmt->bind_param('i', $id_mo);
    $stmt->execute();
    $stmt->close();

    // Invalidate ETA cache (if service exists)
    try {
        require_once __DIR__ . '/BGERP/MO/MOEtaCacheService.php';
        $etaService = new \BGERP\MO\MOEtaCacheService($db);
        $etaService->invalidateForMo($id_mo);
    } catch (\Throwable $e) {
        // non-blocking
    }

    json_success('MO restored to draft', [
        'id_mo'  => $id_mo,
        'status' => 'draft',
    ]);
}
```

---

## 4. MO List UI (Table)

ไฟล์ที่เกี่ยวข้อง (อาจมีชื่อไม่ตรง ให้ Agent ค้นจากโปรเจกต์จริง):

- `source/ui_mo_list.php` หรือไฟล์ PHP ที่ render ตาราง MO
- JS ที่ผูก DataTables กับ `/source/mo.php?action=list`

### 4.1 เพิ่ม column “Actions”

ใน DataTables config ให้มีคอลัมน์:

- `mo_code`
- `product_sku`
- `product_name`
- `qty`
- `status`
- `due_date`
- `scheduled_start_date`
- `scheduled_end_date`
- **Actions** (คอลัมน์สุดท้าย)

Data JSON จาก `mo.php?action=list` ต้องมี field:

- `available_actions` = array from `getMoAvailableActions($mo)`

ตัวอย่าง mapping ใน backend (ตอน build JSON):

```php
$row['available_actions'] = getMoAvailableActions($row);
```

ฝั่ง JS:

```js
{
  data: 'available_actions',
  render: function(actions, type, row) {
    if (!Array.isArray(actions)) return '';

    const id = row.id_mo;
    const btns = [];

    if (actions.includes('plan')) {
      btns.push('<button class="btn btn-sm btn-outline-primary js-mo-plan" data-id="' + id + '">Plan</button>');
    }

    if (actions.includes('edit')) {
      btns.push('<button class="btn btn-sm btn-outline-secondary js-mo-edit" data-id="' + id + '">Edit</button>');
    }

    if (actions.includes('cancel')) {
      btns.push('<button class="btn btn-sm btn-outline-danger js-mo-cancel" data-id="' + id + '">Cancel</button>');
    }

    if (actions.includes('restore')) {
      btns.push('<button class="btn btn-sm btn-outline-warning js-mo-restore" data-id="' + id + '">Restore</button>');
    }

    if (actions.includes('view_job_tickets')) {
      btns.push('<a href="job_ticket.php?mo=' + id + '" class="btn btn-sm btn-outline-info">Job Tickets</a>');
    }

    return btns.join(' ');
  }
}
```

> สำคัญ: ห้าม render ปุ่ม Start / Stop / Complete จากข้อมูลเก่าอีกต่อไป

---

## 5. Modal “Create MO”

ไฟล์ (ตัวอย่างชื่อ):

- `source/ui_mo_create.php` หรือ component UI ที่ใช้ในหน้า MO

### 5.1 ปรับฟิลด์

- **Product (required)** — dropdown เดิม
- **Production Type** — แสดงเป็น info/badge เช่น “Classic (ชุดผลิต OEM)”  
  - ไม่ต้องให้ user เลือกเปลี่ยนใน Task นี้
- **Routing / Template**:
  - แทนที่จะให้เลือกเอง → แสดงเป็นข้อความแสดงผลจาก backend:
    - ถ้ามี binding:  
      `Routing: {graph_name} (v{version}) — auto-selected from Product Binding`
    - ถ้าไม่มี binding:  
      แสดง alert สีส้ม/แดง + disable ปุ่มสร้าง MO
- **Quantity (required)** — number
- **UoM (backend only)** — ระบบจะกำหนด UoM อัตโนมัติตาม Product (เช่น default_uom_code หรือ fallback เป็น 'PCS') โดยไม่ต้องแสดงให้ผู้ใช้เห็นหรือให้เลือกเอง
- **Due Date** — optional แต่แนะนำให้กรอก
- **Production Schedule (Start/End)** — optional
- **ETA Preview** — เรียก `/source/mo_eta.php?action=preview` หรือ service ที่มีอยู่

### 5.2 Behavior

- เมื่อเลือก product:
  - ยิง AJAX ไป backend (เช่น `mo_assist_api.php?action=suggest`) เพื่อ:
    - เช็คว่ามี routing binding หรือไม่
  - แสดงข้อความ status ใต้ field “Production Template” ตามผลลัพธ์
- ปุ่ม “สร้าง MO” ต้อง **disable** ถ้า:
  - ไม่มีสินค้า
  - qty <= 0
  - ไม่มี routing binding ที่ valid

---

## 6. Modal “Edit MO”

สร้าง modal ใหม่ (หรือไฟล์ UI ใหม่) สำหรับแก้ไข:

- qty
- due_date
- scheduled_start_date
- scheduled_end_date
- notes
- description (ถ้ามีใน schema)

เงื่อนไข:

- แก้ได้เฉพาะ status: `draft`, `planned`
- เมื่อ submit:
  - ส่ง `POST → mo.php?action=update`
  - ถ้า success → reload DataTables
- Product และ routing แสดงเป็น read-only

---

## 7. Restore UI

ใน JS:

- ผูก event กับ `.js-mo-restore`
- แสดง confirm modal:

```js
if (!confirm('Restore this MO back to DRAFT? ETA cache will be invalidated.')) return;
```

- ถ้าผู้ใช้ยืนยัน:
  - POST -> `mo.php?action=restore` พร้อม `id_mo`
  - ถ้า success → reload DataTables

---

## 8. MO Detail Banner (ถ้ามีหน้า detail)

ถ้ามีหน้า detail เช่น `mo_detail.php`:

- ถ้า status = `planned`:
  - แสดง banner เช่น:

    ```html
    <div class="alert alert-info">
      This MO has been planned. Please continue work in Job Tickets.
      <a href="job_ticket.php?mo=<?= (int)$mo['id_mo'] ?>" class="btn btn-sm btn-outline-light ms-2">
        View Job Tickets
      </a>
    </div>
    ```

- ถ้า status = `in_progress` หรือ `qc`:
  - Banner สีเหลือง: งานกำลังดำเนินการใน Job Tickets
- ถ้า status = `done`:
  - Banner สีเขียว: MO เสร็จแล้ว
- ถ้า status = `cancelled`:
  - Banner สีแดง: MO ถูกยกเลิก + ปุ่ม Restore (ถ้าเงื่อนไขผ่าน)

---

## 9. Testing Checklist

1. **สร้าง MO ใหม่ → Plan → ไปหน้า Job Tickets**
2. ตรวจว่าในหน้า MO:
   - ไม่มีปุ่ม Start / Stop / Complete
   - มีปุ่ม Plan / Edit / Cancel ตามสถานะ
3. เปลี่ยนสถานะ MO เป็น cancelled → เห็นปุ่ม Restore → กดแล้วกลับเป็น draft
4. แก้ไข MO (qty/due date) แล้ว DataTables refresh ถูกต้อง
5. สินค้าที่ไม่มี routing binding → Create modal แสดง warning และห้ามสร้าง MO
6. ETA preview ทำงาน (ถ้า engine ทำงานแล้ว) หรืออย่างน้อย UI ไม่พังถ้า backend คืน error

---

## 10. Developer Prompt (สำหรับใช้งานกับ Cursor/Agent)

ให้ใช้ข้อความนี้เป็น prompt หลัก:

```text
You are working on Task 23.6.2 — MO UI Consolidation & Flow Cleanup in a custom ERP.

High-level rules:
- MO is a planning-level entity.
- Job Tickets are the execution-level entity.
- We want to remove execution-style controls (start/pause/resume/complete) from MO UI and direct users to Job Tickets instead.

Backend:
- File: source/mo.php
- Existing actions: list, create, update, cancel, plan, start_production, start, stop, complete, etc.

Your tasks:
1) In source/mo.php:
   - Keep the signatures of start_production/start/stop/complete actions, but make them return a JSON error:
     "MO start/stop is now managed via Job Tickets. Please use Job Tickets UI."
   - Implement a new action `restore` that:
     - Accepts POST[id_mo].
     - Only works when status='cancelled'.
     - Verifies graph_instance_id is NULL.
     - Updates status back to 'draft'.
     - Tries to invalidate ETA cache via MOEtaCacheService::invalidateForMo($id_mo) (non-blocking).
   - Implement a helper function getMoAvailableActions(array $mo): array that returns a list of allowed actions:
     - draft: ['plan', 'edit', 'cancel']
     - planned: ['view_job_tickets', 'edit', 'cancel']
     - in_progress: ['view_job_tickets']
     - qc: ['view_job_tickets']
     - done: ['view_job_tickets']
     - cancelled: ['restore']

   - Ensure the list API (`action=list`) includes `available_actions` for each row.

2) In the MO list UI (PHP + JS, likely ui_mo_list.php + DataTables JS):
   - Add an "Actions" column.
   - Render buttons based on `row.available_actions`:
     - plan:    .js-mo-plan
     - edit:    .js-mo-edit
     - cancel:  .js-mo-cancel
     - restore: .js-mo-restore
     - view_job_tickets: link to job_ticket.php?mo={id_mo}
   - Make sure no legacy start/stop/complete buttons remain.

3) Create or update the Create MO modal:
   - Fields (UI level): product, qty, due_date, scheduled_start_date, scheduled_end_date, notes.
   - UoM must be handled entirely by the backend: auto-resolve from product (default_uom_code) with a safe fallback (e.g. 'PCS'), and must not be shown or editable in the UI.
   - Product selection should trigger an AJAX call (e.g., mo_assist_api.php) to:
     - Resolve routing binding.
   - Optionally call ETA preview, but do not block creation if ETA fails.

4) Implement an Edit MO modal:
   - Triggered by .js-mo-edit.
   - Allows editing: qty, due_date, scheduled_start_date, scheduled_end_date, notes, description.
   - Product and routing are read-only.
   - Submits to mo.php?action=update and reloads the table on success.

5) Implement Restore UI:
   - .js-mo-restore shows a confirm dialog.
   - On confirm, POST to mo.php?action=restore with id_mo.
   - On success, reload the DataTable.

6) If there is a MO detail page:
   - Add an informational banner based on MO status:
     - planned / in_progress / done / cancelled.
   - Always include a "View Job Tickets" button for planned/in_progress/done.

Constraints:
- Do not change the MO core logic (planning, ETA, health) beyond what is requested.
- Keep the UI consistent with existing styles (Bootstrap).

Make sure PHP and JS syntax are valid and consistent with the existing project structure.
```