
# Task 13.9 — Leather Sheet UI (Embedded in Materials)

**Status:** PLANNED  
**Depends on:**  
- Task 13.3–13.8 (component foundation + serial + allocation layer)  
- `leather_sheet` / `component_allocation.php` from Task 13.8

---

## เป้าหมาย

เพิ่มความสามารถในการจัดการ **Leather Sheets** (ผืนหนังแต่ละผืน)  
โดย **ไม่สร้างเมนูใหม่** แต่ฝัง UI ไว้ในหน้า **Materials เดิม** เพื่อลดสปาเก็ตตี้:

- ฝ่ายคลังสามารถ “ลงทะเบียนผืนหนัง” ต่อวัสดุ (Material) ได้
- ดูรายการแผ่นหนังของวัสดุแต่ละตัวได้ (sheet list per SKU)
- ใช้ API `component_allocation.php` ที่มีอยู่แล้ว (ไม่สร้างไฟล์ใหม่)
- ยัง **ไม่ต้อง** เชื่อมกับ CUT UI (นัดไว้ Task 13.10)

---

## Scope

### In Scope

1. **Materials Page Integration**
   - เพิ่มปุ่ม/ไอคอน “แผ่นหนัง / Sheets” ในแถวของวัสดุแต่ละตัว
   - กดแล้วเปิด modal / side panel แสดงรายการ leather sheets เฉพาะ SKU นั้น

2. **Leather Sheet List UI**
   - แสดงจากตาราง `leather_sheet` (ผ่าน API `component_allocation.php?action=list_sheets`)
   - ข้อมูลที่ต้องมีอย่างน้อย:
     - `sheet_code`
     - `batch_code`
     - `area_sqft`
     - `area_remaining_sqft`
     - `status` (active, used_up, scrap ฯลฯ)
     - `created_at`

3. **Create Leather Sheet (ต่อ 1 material SKU)**
   - ปุ่ม “เพิ่มแผ่นหนัง” ใน modal
   - ฟอร์ม input:
     - `sku_material` (readonly — มาจาก material row)
     - `sheet_code` (required)
     - `batch_code` (optional)
     - `area_sqft` (required, number > 0)
   - ส่งไปที่ `component_allocation.php?action=create_sheet`
   - Reload sheet list หลังสร้างสำเร็จ

4. **Filter เฉพาะวัสดุที่เป็นหนัง (ถ้าทำได้ง่าย)**
   - ถ้าใน DB มี field บอกว่าเป็นหนัง (เช่น `is_leather` หรือ `material_type = 'leather'`)
     - ให้โชว์ปุ่ม “แผ่นหนัง” เฉพาะวัสดุที่เป็นหนัง
   - ถ้าไม่มี field ชัดเจน → ให้แสดงปุ่มกับทุก row ไปก่อน (อย่าดัดแปลง schema เดิม)

5. **Permission**
   - ใช้ permission เดิมของ Materials + ของ component allocation:
     - ดู sheets: `component.binding.view` (หรือ `materials.view` + `component.binding.view`)
     - สร้าง sheet: จำกัดที่ tenant admin / warehouse manager (เลือกจาก permission ที่มีอยู่แล้ว)
   - ถ้า user ไม่มีสิทธิ์ → ซ่อนปุ่มจาก UI (หรือ disable พร้อม tooltip)

---

### Out of Scope (อย่าแตะใน Task นี้)

- ไม่ต้องปรับ **CUT Behavior Panel** (เลือก sheet ตอน CUT ไว้ Task 13.10)
- ไม่ต้องปรับ **Work Queue / PWA Scan** ใด ๆ
- ไม่ต้องปรับ logic allocation / prediction ที่ทำใน Task 13.8 แล้ว
- ไม่ต้องเปลี่ยนโครงสร้าง **Materials** DB เดิม (ห้ามยุ่งกับ stock logic ปัจจุบัน)

---

## Implementation Notes

### 1) Materials Page Integration

**ไฟล์ที่คาดว่าจะยุ่งเกี่ยว (ชื่ออาจต่างได้ ให้ Agent ค้นหาก่อน):**

- `page/materials.php` — page definition  
- `views/materials.php` หรือ `views/materials_list.php` — HTML  
- `assets/javascripts/materials.js` — DataTable & JS logic

**สิ่งที่ต้องทำ:**

1. เพิ่มคอลัมน์ “การทำงาน / Actions” หรือเพิ่ม icon เพิ่มในคอลัมน์เดิม:
   - ปุ่มเล็ก ๆ เช่น
     - ไอคอนหนัง: 🐄 หรือไอคอนใบมีด ✂ + label “แผ่นหนัง”
   - data attribute ต้องมี:
     - `data-sku="<material_sku>"`
     - อาจมี `data-name` เพื่อใช้แสดงในหัว modal

2. คลิกปุ่ม → เปิด modal `#modalLeatherSheets` แล้วเรียก JS function:
   ```js
   BG.Materials.openLeatherSheetsModal(sku, name);


⸻

2) Leather Sheet Modal + DataTable

เพิ่มใน view materials:
	•	Modal โครงแบบ Bootstrap (เหมือน modal ที่มีอยู่แล้วใน project):

<div class="modal fade" id="modalLeatherSheets" tabindex="-1" aria-hidden="true">
  <div class="modal-dialog modal-xl">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title">แผ่นหนังสำหรับวัสดุ: <span id="ls-material-name"></span> (<span id="ls-material-sku"></span>)</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <div class="d-flex justify-content-between mb-3">
          <div></div>
          <button class="btn btn-primary btn-sm" id="btn-add-leather-sheet">+ เพิ่มแผ่นหนัง</button>
        </div>
        <table id="tbl-leather-sheets" class="table table-striped w-100">
          <thead>
            <tr>
              <th>Sheet Code</th>
              <th>Batch</th>
              <th>Area (sq.ft)</th>
              <th>Remaining</th>
              <th>Status</th>
              <th>Created At</th>
            </tr>
          </thead>
        </table>
      </div>
    </div>
  </div>
</div>

JS Logic (ใน materials.js หรือไฟล์ใหม่ materials_leather_sheet.js):
	•	สร้าง namespace:

window.BG = window.BG || {};
BG.Materials = BG.Materials || {};


	•	ฟังก์ชันหลัก:

BG.Materials.openLeatherSheetsModal = function (sku, name) {
  $('#ls-material-sku').text(sku);
  $('#ls-material-name').text(name || '');
  // init DataTable ถ้ายังไม่เคย init, ถ้าเคยแล้วให้เปลี่ยน ajax data + reload
};


	•	DataTable ใช้ server-side AJAX:

$('#tbl-leather-sheets').DataTable({
  ajax: {
    url: 'source/component_allocation.php',
    type: 'GET',
    data: function (d) {
      d.action = 'list_sheets';
      d.sku_material = $('#ls-material-sku').text();
    }
  },
  columns: [
    { data: 'sheet_code' },
    { data: 'batch_code' },
    { data: 'area_sqft' },
    { data: 'area_remaining_sqft' },
    { data: 'status' },
    { data: 'created_at' }
  ]
});


	•	ปุ่ม #btn-add-leather-sheet → เปิด mini form (inline หรือ modal ซ้อน) ให้กรอก sheet_code, batch_code, area_sqft แล้วส่ง AJAX POST ไปที่:
	•	component_allocation.php?action=create_sheet

⸻

3) Backend / API Adjustments (ถ้าจำเป็น)

ไฟล์: source/component_allocation.php
	•	ตรวจสอบว่า list_sheets รองรับ sku_material อยู่แล้ว (จาก Task 13.8)
	•	ถ้ารับแค่บางพารามิเตอร์ ให้เพิ่ม sku_material filter
	•	ตรวจสอบว่า create_sheet สามารถรับ sku_material ที่ส่งมาจาก modal ได้ (ต้อง map กับ field sku_material ใน leather_sheet)

ห้าม:
	•	ห้ามเปลี่ยน response structure ของ actions ที่มีอยู่แล้วในแบบ breaking change
	•	ถ้าต้องเพิ่ม field ให้เพิ่มในรูปแบบ optional (UI อื่นที่เรียกอยู่จะไม่พัง)

⸻

Acceptance Criteria
	1.	Materials Page
	•	แต่ละ row มีปุ่ม “แผ่นหนัง” (หรือ icon) ที่กดแล้วเปิด modal ได้
	•	ถ้า DB มี flag แยกประเภทหนัง: ปุ่มจะแสดงเฉพาะวัสดุที่เป็นหนัง
	2.	Leather Sheet Modal
	•	แสดง list แผ่นหนังที่ผูกกับ SKU นั้นถูกต้อง
	•	ชื่อวัสดุ + SKU แสดงบนหัว modal
	3.	Create Sheet
	•	กรอกฟอร์ม + กดบันทึก → สร้าง record ใน leather_sheet
	•	area_remaining_sqft เริ่มต้นเท่ากับ area_sqft
	•	Reload ตาราง sheet โดยอัตโนมัติ
	4.	Permissions
	•	User ที่ไม่มีสิทธิ์ตามที่กำหนด:
	•	ไม่เห็นปุ่ม หรือเห็นแต่ถูก disable
	•	Admin สามารถใช้ได้เต็มที่
	5.	Safety & Compatibility
	•	ไม่แตะโค้ดของ CUT / STITCH behavior, Work Queue, PWA Scan, MO
	•	ไม่เปลี่ยน behavior ของ Materials เดิม (แค่เพิ่ม feature)
	•	ไม่มี error ใน console / PHP syntax

⸻

Notes to AI Agent
	•	ค้นหาไฟล์จริงจากโครงโปรเจกต์ก่อนเปลี่ยน (ชื่อไฟล์ด้านบนเป็น “คาดการณ์”)
	•	ยึด style UI + JS เดิมของระบบ (DataTables, BG.utils, toastr ฯลฯ)
	•	หลีกเลี่ยงการสร้าง global function มั่ว ๆ → เก็บใต้ BG.Materials เท่านั้น
	•	ถ้าเจอ logic เก่าเกี่ยวกับ lot/batch ของวัสดุ ให้ อย่าแก้ — Leather Sheet layer เป็น complement ไม่ใช่ replacement
