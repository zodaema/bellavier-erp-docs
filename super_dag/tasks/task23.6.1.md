

# Task 23.6.1 — MO UI: Edit & Update Integration

> Frontend/UI layer for Task 23.6  
> เชื่อม UI หน้า MO เข้ากับ `mo.php?action=update` ที่เพิ่งทำเสร็จ

---

## 1. Objective

ให้ผู้ใช้สามารถ:

- แก้ไขข้อมูลพื้นฐานของ MO (เช่น qty, due date, note ฯลฯ) ผ่านหน้า UI
- กดบันทึก → เรียก `mo.php?action=update`
- ได้รับผลลัพธ์กลับมาเป็น JSON แล้ว refresh ตาราง MO ให้สอดคล้องกับข้อมูลใหม่

**สำคัญ:**  
ไม่ต้องทำ UI ซับซ้อน, ไม่ต้องยุ่งกับ ETA/Health โดยตรง  
ทุกอย่างให้ใช้ backend logic ที่มีอยู่แล้ว (`handleUpdate()` + ETA/Cache/Health)  

---

## 2. ขอบเขต

### รวม

- เพิ่มปุ่ม “Edit” ในหน้า List MO
- สร้าง Modal (Bootstrap) สำหรับแก้ไขค่า
- ดึงข้อมูลจากแถวใน DataTable มาเติมใน Modal
- ส่งฟอร์มไปที่ `source/mo.php?action=update` ผ่าน `POST`
- แสดงผลลัพธ์สำเร็จ/ผิดพลาด
- Reload DataTables หลังแก้ไขสำเร็จ

### ไม่รวม (ใน Task นี้)

- การสร้างหน้า MO ใหม่จากศูนย์ (Create UI มีอยู่แล้ว)
- การแก้ไข routing/graph ผ่าน UI ซับซ้อน
- การแสดง ETA ใน UI (ไว้ Task Phase 24)
- การทำ UX validation ซับซ้อน (เช่น date picker ขั้นสูง, inline validation แปลก ๆ)

---

## 3. Affected Files

ให้ AI Agent ใช้ไฟล์เหล่านี้เป็นหลัก (ชื่อไฟล์อาจต้องปรับตามโปรเจกต์จริง):

1. **MO List / UI**
   - `source/mo_list.php` หรือไฟล์ที่ใช้ render หน้า MO list ปัจจุบัน
   - JS ที่ผูกกับ DataTables หน้าดังกล่าว (เช่นใน `<script>` หรือไฟล์ JS แยก)

2. **Shared Layout / Assets**
   - ถ้ามีไฟล์รวม JS/CSS อยู่แล้ว ให้ reuse เช่น Bootstrap, jQuery, DataTables

> หมายเหตุ: ให้ Agent ใช้สไตล์ UI ปัจจุบันของระบบ (ไม่สร้าง design แปลกใหม่เอง)

---

## 4. UX / UI Requirements

### 4.1 ปุ่ม Edit ในตาราง MO

ในตาราง List MO (DataTables) ให้เพิ่มคอลัมน์ “Actions” (ถ้ายังไม่มี) แล้วมีปุ่ม:

```html
<button 
  type="button"
  class="btn btn-sm btn-outline-primary btn-mo-edit"
  data-id-mo="{{id_mo}}"
>
  Edit
</button>
```

- `{{id_mo}}` ให้แทนด้วยค่า `id_mo` จาก DataTables row
- ถ้ามี action อื่นอยู่แล้ว (view, delete ฯลฯ) ให้วางปุ่ม Edit เพิ่มในคอลัมน์เดียวกัน

### 4.2 Modal สำหรับ Edit MO

สร้าง Bootstrap modal เช่น:

```html
<div class="modal fade" id="moEditModal" tabindex="-1" aria-hidden="true">
  <div class="modal-dialog modal-lg modal-dialog-centered">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title">Edit MO</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
      </div>
      <form id="moEditForm">
        <div class="modal-body">
          <!-- Hidden -->
          <input type="hidden" name="id_mo" id="moEditId">

          <div class="row mb-3">
            <div class="col-md-4">
              <label for="moEditProduct" class="form-label">Product</label>
              <input type="text" class="form-control" id="moEditProduct" disabled>
            </div>
            <div class="col-md-4">
              <label for="moEditQty" class="form-label">Quantity</label>
              <input type="number" step="0.01" class="form-control" name="qty" id="moEditQty" required>
            </div>
            <div class="col-md-4">
              <label for="moEditUom" class="form-label">UOM</label>
              <input type="text" class="form-control" name="uom_code" id="moEditUom">
            </div>
          </div>

          <div class="row mb-3">
            <div class="col-md-4">
              <label for="moEditDueDate" class="form-label">Due Date</label>
              <input type="date" class="form-control" name="due_date" id="moEditDueDate">
            </div>
            <div class="col-md-4">
              <label for="moEditStartDate" class="form-label">Scheduled Start</label>
              <input type="date" class="form-control" name="scheduled_start_date" id="moEditStartDate">
            </div>
            <div class="col-md-4">
              <label for="moEditEndDate" class="form-label">Scheduled End</label>
              <input type="date" class="form-control" name="scheduled_end_date" id="moEditEndDate">
            </div>
          </div>

          <div class="mb-3">
            <label for="moEditNotes" class="form-label">Notes</label>
            <textarea class="form-control" name="notes" id="moEditNotes" rows="2"></textarea>
          </div>

          <div class="mb-3">
            <label for="moEditDescription" class="form-label">Description</label>
            <textarea class="form-control" name="description" id="moEditDescription" rows="2"></textarea>
          </div>

          <div class="alert alert-danger d-none" id="moEditError"></div>
          <div class="alert alert-success d-none" id="moEditSuccess"></div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
          <button type="submit" class="btn btn-primary">Save changes</button>
        </div>
      </form>
    </div>
  </div>
</div>
```

> ใช้ Bootstrap 5 ตามมาตรฐานระบบ (ไม่ต้องเปลี่ยน theme)

---

## 5. Data Binding & Events

### 5.1 ดึงข้อมูลจาก DataTables เมื่อกดปุ่ม Edit

ใน JS:

- ผูก event handler กับ `.btn-mo-edit`
- ดึง row data จาก DataTables แล้ว populate ลง form

ตัวอย่าง pseudo-code:

```js
const moTable = $('#moTable').DataTable(); // หรือชื่อจริงของ table

$('#moTable').on('click', '.btn-mo-edit', function () {
  const $btn = $(this);
  const moId = $btn.data('id-mo');

  const rowData = moTable.row($btn.closest('tr')).data();

  // สมมติว่า rowData มี field ต่อไปนี้ (ปรับตามจริง):
  // rowData.id_mo, rowData.product_name, rowData.qty, rowData.uom_code,
  // rowData.due_date, rowData.scheduled_start_date, rowData.scheduled_end_date,
  // rowData.notes, rowData.description

  $('#moEditId').val(rowData.id_mo);
  $('#moEditProduct').val(rowData.product_name || '');
  $('#moEditQty').val(rowData.qty || '');
  $('#moEditUom').val(rowData.uom_code || '');
  $('#moEditDueDate').val(rowData.due_date || '');
  $('#moEditStartDate').val(rowData.scheduled_start_date || '');
  $('#moEditEndDate').val(rowData.scheduled_end_date || '');
  $('#moEditNotes').val(rowData.notes || '');
  $('#moEditDescription').val(rowData.description || '');

  $('#moEditError').addClass('d-none').text('');
  $('#moEditSuccess').addClass('d-none').text('');

  const modal = new bootstrap.Modal(document.getElementById('moEditModal'));
  modal.show();
});
```

> ถ้า DataTables row ไม่มี field บางตัว ให้ Agent ปรับ mapping ตามโครง JSON จริง  
> หรือถ้าจำเป็นจริง ๆ ค่อยยิง AJAX `mo.php?action=get` ในอนาคต แต่ Task นี้ใช้ข้อมูลจาก list ก่อน

---

## 6. Submit ฟอร์ม → เรียก `mo.php?action=update`

ใช้ fetch หรือ jQuery AJAX ได้ แต่ให้คง style โปรเจกต์ (ถ้าในระบบใช้ jQuery อยู่แล้ว ให้ใช้ jQuery)

ตัวอย่างด้วย fetch:

```js
$('#moEditForm').on('submit', function (e) {
  e.preventDefault();

  const form = this;
  const formData = new FormData(form);

  $('#moEditError').addClass('d-none').text('');
  $('#moEditSuccess').addClass('d-none').text('');

  fetch('source/mo.php?action=update', {
    method: 'POST',
    body: formData,
    credentials: 'include'
  })
    .then(res => res.json())
    .then(json => {
      if (!json || json.status !== 'success') {
        const msg = (json && json.message) ? json.message : 'Update failed';
        $('#moEditError').removeClass('d-none').text(msg);
        return;
      }

      $('#moEditSuccess').removeClass('d-none').text('Update successful');

      // Reload DataTable row
      moTable.ajax.reload(null, false);

      // ปิด modal หลัง delay สั้น ๆ
      setTimeout(() => {
        const modalEl = document.getElementById('moEditModal');
        const modal = bootstrap.Modal.getInstance(modalEl);
        modal.hide();
      }, 600);
    })
    .catch(err => {
      console.error(err);
      $('#moEditError').removeClass('d-none').text('Unexpected error occurred');
    });
});
```

> URL อาจต้องปรับให้ตรงกับ path จริงในโปรเจกต์ เช่น `/source/mo.php?action=update` หรือ `mo.php?action=update`  
> ให้ Agent ตรวจจากโค้ดปัจจุบันก่อนใช้

---

## 7. Validation ขั้นพื้นฐาน

ในฝั่ง UI:

- บังคับให้ `qty` > 0 (ใช้ HTML `min="0.01"` + required)
- ถ้า `qty` เป็น 0 หรือว่าง → show error ใน modal ไม่ต้องยิง API
- Date fields ใช้ `<input type="date">` ตาม browser standard

ไม่ต้องทำ validation ซับซ้อน เพราะ backend `handleUpdate()` จะ validate ซ้ำอีกที

---

## 8. การทดสอบ (Manual QA Checklist)

### 8.1 Case ปกติ

1. เปิดหน้า MO list  
2. กดปุ่ม Edit แถวหนึ่ง → modal เปิด  
3. เปลี่ยน qty จาก 10 → 20 → Save  
4. ดูว่า:
   - Modal แสดง success
   - DataTable refresh แล้ว qty เปลี่ยนเป็น 20
   - (ถ้าดู log) ETA/Health ไม่ error

### 8.2 เปลี่ยนเฉพาะ notes

1. แก้ notes เท่านั้น → Save  
2. qty/ETA-sensitive fields ไม่ควรเปลี่ยน  
3. DataTable แสดง notes ใหม่  
4. ETA cache ไม่ควรโดน invalidate (ตาม logic backend)

### 8.3 Error จาก backend

1. ลองแก้ MO ที่สถานะไม่อนุญาตให้แก้ (เช่น `done` หรือ `cancelled`)  
2. Backend น่าจะ return error (ตาม logic `handleUpdate()`)  
3. UI ต้องขึ้น message ใน `#moEditError`  
4. Modal ไม่ปิดอัตโนมัติ

---

## 9. Developer Prompt (สำหรับ AI Agent ใน Cursor)

ใช้ prompt นี้กับ Cursor/Agent:

```text
You are implementing Task 23.6.1 — MO UI: Edit & Update Integration.

Backend context:
- The MO update endpoint already exists at `source/mo.php?action=update`.
- `handleUpdate()` performs:
  - ETA-sensitive field diff detection.
  - MO update inside a transaction.
  - ETA cache invalidation + recompute (best-effort).
  - MOEtaHealthService::onMoUpdated() call.
  - Non-blocking design via try/catch.

Your job:
- Implement the UI layer for editing MO records from the MO list page.

Requirements:
1) Add an "Edit" button for each MO row in the MO list (DataTables).
   - Class: `btn-mo-edit`
   - Attribute: `data-id-mo` with the MO ID.
   - Insert into the existing Actions column, or create one if needed.

2) Implement a Bootstrap modal with id `moEditModal` and form `#moEditForm`:
   - Hidden `id_mo`
   - Fields: qty, uom_code, due_date, scheduled_start_date, scheduled_end_date, notes, description.
   - A read-only product field is optional for display.

3) When user clicks ".btn-mo-edit":
   - Read the row data from DataTables.
   - Populate the modal fields with existing values.
   - Show the modal.

4) When user submits "#moEditForm":
   - POST to `source/mo.php?action=update` (adjust path to match the project).
   - Send `id_mo` and the editable fields.
   - Expect JSON response: `{ status: 'success', ... }` or error.
   - On success:
     - Show a small success message in the modal.
     - Reload the DataTable via `ajax.reload(null, false)` (no full page reload).
     - Close the modal after a short delay.
   - On error:
     - Show the error message inside `#moEditError`.

5) Keep the implementation consistent with existing code:
   - If the project already uses jQuery and DataTables, use them.
   - Use Bootstrap 5 modal APIs (no custom modal code).
   - Do NOT change any backend logic.

Deliverables:
- Updated MO list PHP/HTML file with:
  - "Edit" button column.
  - The Bootstrap modal markup.
  - JavaScript to handle button click + form submission.

- Make sure PHP and JavaScript syntax is valid.
- Keep the UI minimal and aligned with the existing admin style.
```

---