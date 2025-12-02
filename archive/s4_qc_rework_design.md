# Sprint 4 – QC Fail / Rework Workflow Design

## Objectives
- บันทึกเหตุการณ์ QC fail พร้อมรายละเอียดที่ตรวจสอบย้อนหลังได้ (root cause, ปริมาณที่ได้รับผลกระทบ, สถานี, ผู้ปฏิบัติงาน, หลักฐาน)
- สร้างกระบวนการ rework หรือ scrap ที่มีการมอบหมายผู้รับผิดชอบ, กำหนดกำหนดส่ง และติดตามสถานะได้
- เชื่อมโยงข้อมูลกับ Job Ticket / WIP / Dashboard KPI เพื่อคำนวณ defect rate และ turnaround time
- รองรับ multi-tenant, RBAC, multi-language และการ export รายงานตามมาตรฐาน Atelier

## Implementation Status (19 Oct 2025)

### สิ่งที่พร้อมแล้ว
- Migration และ seed สำหรับตาราง `qc_fail_event`, `qc_fail_attachment`, `qc_rework_task`, `qc_rework_log` ถูก merge และรันได้ทั้ง DEFAULT/MAISON
- หน้า `QC Fail & Rework` (web) เชื่อมต่อ i18n, ฟิลเตอร์หลักฐาน, DataTable list และ off-canvas detail skeleton พร้อมปุ่มสำคัญครบถ้วน
- API `source/qc_fail.php` รองรับ action พื้นฐาน: `list`, `detail`, `create_fail`, `create_task`, `update_task`, `options`
- สถานะ Work Center ถูกทำให้เสถียร (toggleใช้งานได้จริง) เพื่อแสดงรายชื่อสถานีในฟิลเตอร์ QC อย่างถูกต้อง

### สิ่งที่กำลังดำเนินการ
- เติม logic ด้านในของ off-canvas ให้รองรับ timeline/log, การปิด/เปิดเหตุการณ์, upload/delete attachments
- ฟอร์ม `Report QC Fail` และ `Assign Rework/Scrap` ยังต้องเชื่อม API (`create_fail`, `create_task`) พร้อม validation
- เสริม state management ใน `qc_fail.js` ให้ update ตาราง/รายละเอียดหลัง action สำเร็จโดยไม่ต้อง refresh
- เตรียม endpoint สำหรับ close/reopen fail event + ลบ/ดาวน์โหลดไฟล์แนบ

### Next Steps (Sprint 4 – Web UI)
1. เชื่อมปุ่ม `Report QC Fail` กับ modal/form และ call API `create_fail`
2. พัฒนา off-canvas ให้รองรับการปิด/เปิดเหตุการณ์, upload และลบ attachments (backend + frontend)
3. Implement modal `Assign Rework/Scrap` → `create_task` และแสดงผลใน timeline พร้อม log record
4. เพิ่ม state feedback (toastr, loading indicator, disabled state) ให้ UX พร้อมใช้งานจริงใน production floor

> หมายเหตุ: หลังงานฝั่ง web เสร็จ จะขยับไปงาน Mobile และ Reporting ตามแผน Sprint 4

## Data Model

### ตาราง `qc_fail_event`
| Column | Type | Notes |
| --- | --- | --- |
| `id_fail_event` | BIGINT PK | auto increment |
| `tenant_id` | INT | อ้างอิง tenant ปัจจุบัน (index) |
| `id_qc_inspection` | INT | FK → `qc_inspection.id_qc_inspection` (nullable กรณีบันทึกด้วยตนเอง) |
| `id_job_ticket` | INT | FK → `atelier_job_ticket.id_job_ticket` (nullable ถ้า entity อื่น) |
| `entity_type` | VARCHAR(30) | เช่น `job_ticket`, `material_lot` |
| `entity_id` | INT | รหัส entity (nullable เมื่อไม่มี) |
| `fail_code` | VARCHAR(50) | รหัส defect (จาก master ถ้ามี) |
| `root_cause` | VARCHAR(255) | เหตุผลหลัก |
| `severity` | VARCHAR(20) | low / medium / high |
| `defect_qty` | INT | จำนวนชิ้นที่ defect |
| `uom` | VARCHAR(20) | หน่วย (ใช้ default จาก product) |
| `station_code` | VARCHAR(50) | สถานีที่ตรวจพบ |
| `operator_name` | VARCHAR(150) | ผู้ปฏิบัติงานตอน fail |
| `reported_by` | INT | ผู้สร้าง record (FK → account id_member) |
| `reported_at` | DATETIME | default NOW |
| `status` | VARCHAR(20) | `open` / `in_progress` / `closed` |
| `current_action` | VARCHAR(20) | `pending`, `rework`, `scrap` |
| `notes` | TEXT | หมายเหตุเพิ่มเติม |
| `closed_at` | DATETIME | เวลาปิดงาน |
Indices: (`tenant_id`,`id_qc_inspection`), (`tenant_id`,`id_job_ticket`), (`status`)

### ตาราง `qc_fail_attachment`
| Column | Type | Notes |
| --- | --- | --- |
| `id_attachment` | BIGINT PK |
| `id_fail_event` | BIGINT FK → `qc_fail_event` |
| `file_path` | VARCHAR(255) | relative path ใน storage |
| `file_name` | VARCHAR(150) |
| `mime_type` | VARCHAR(100) |
| `uploaded_by` | INT | account id_member |
| `uploaded_at` | DATETIME |
Indices: (`id_fail_event`)

### ตาราง `qc_rework_task`
| Column | Type | Notes |
| --- | --- | --- |
| `id_rework_task` | BIGINT PK |
| `id_fail_event` | BIGINT FK → `qc_fail_event` |
| `action_type` | VARCHAR(20) | `rework` หรือ `scrap` |
| `assigned_to` | INT | account id_member ที่รับผิดชอบ |
| `assigned_at` | DATETIME |
| `due_at` | DATETIME | deadline |
| `qty_target` | INT | จำนวนที่ต้อง rework/scrap |
| `qty_completed` | INT | จำนวนที่ทำเสร็จ |
| `status` | VARCHAR(20) | `pending` / `in_progress` / `completed` / `cancelled` |
| `priority` | VARCHAR(20) | optional (low/medium/high) |
| `remarks` | TEXT | หมายเหตุ |
Indices: (`id_fail_event`), (`status`), (`assigned_to`)

### ตาราง `qc_rework_log`
| Column | Type | Notes |
| --- | --- | --- |
| `id_rework_log` | BIGINT PK |
| `id_rework_task` | BIGINT FK |
| `event_type` | VARCHAR(30) | `status_change`, `qty_update`, `note` ฯลฯ |
| `old_status` | VARCHAR(20) |
| `new_status` | VARCHAR(20) |
| `qty_delta` | INT | จำนวนที่เพิ่ม/ลด |
| `notes` | TEXT |
| `actor_id` | INT | account id_member |
| `created_at` | DATETIME | default NOW |
Indices: (`id_rework_task`)

### การเปลี่ยนแปลงตารางเดิม
- `qc_inspection`: เพิ่มคอลัมน์ `has_fail_event` (TINYINT) เพื่อ flag การมี fail
- `atelier_wip_log`: เพิ่มคอลัมน์ `id_fail_event` (nullable) เพื่อเชื่อม log กับ fail event

### ความสัมพันธ์
- `qc_fail_event` 1:N `qc_fail_attachment`
- `qc_fail_event` 1:N `qc_rework_task`
- `qc_rework_task` 1:N `qc_rework_log`
- `qc_fail_event` เชื่อมกับ `qc_inspection` และ `atelier_job_ticket` เพื่อรายงาน

## API / Service Flow
ใช้ไฟล์ใหม่ `source/qc_fail.php` (ตามมาตรฐาน controller) + helper service:
- `POST action=create_fail`: รับข้อมูล fail (inspection id, root cause, qty, station, note) → สร้าง `qc_fail_event`
- `POST action=attach_file`: อัปโหลดหลักฐาน (เรียกผ่าน upload handler) → บันทึก `qc_fail_attachment`
- `POST action=create_task`: ระบุ action (rework/scrap), ผู้รับผิดชอบ, deadline → สร้าง `qc_rework_task`
- `POST action=update_task`: ปรับสถานะ/qty → บันทึก `qc_rework_log` และอัปเดต `qc_rework_task`
- `POST action=close_fail`: ปิด fail เมื่อ task ทั้งหมดเสร็จ → อัปเดต status + `closed_at`
- `GET action=detail`: ดึงข้อมูล fail + attachments + tasks + log
- `GET action=list`: ตาราง list (filter ตามวันที่, สถานี, status)

มาตรฐาน response: `json_success(data)` / `json_error(message, code)` พร้อม status code ที่ถูกต้อง

## UI / UX
### Web (Production)
**Navigation**
- เมนูหลักภายใต้ Production → `QC Fail & Rework`
- Breadcrumbs: `Production / QC / QC Fail & Rework`

**Main List View**
- DataTable (ใช้ DataTables + Server-side) columns: Fail ID, วันที่รายงาน, Job Ticket, สถานี, Severity (badge สี), ปริมาณ defect, สถานะปัจจุบัน, Current Action, ผู้รับผิดชอบล่าสุด, ปุ่ม Actions (`View`, `Close`, `Reopen`)
- Filter bar ด้านบน: วันที่ (range picker), สถานี (Select2), Severity (Pill buttons), Status (multi-select), Assigned To (Select2), Toggle แสดงเฉพาะของฉัน
- Button `Report QC Fail` (primary) เปิด modal/side-panel ฟอร์มสร้างเหตุการณ์
- แสดง empty state ด้วย `common.table.empty` เมื่อไม่มีข้อมูล

**Fail Detail Drawer**
- Side panel (width 540px) เปิดจากปุ่ม `View`
- Section 1: Summary (Defect info, root cause, linked job ticket, operator, reported by)
- Section 2: Attachments (thumbnail list + ปุ่ม upload เพิ่ม, preview modal)
- Section 3: Rework Tasks (table + ปุ่ม `Add Task`)
- Section 4: Timeline (vertical timeline จาก `qc_rework_log`)
- CTA ด้านล่าง: `Assign Rework`, `Assign Scrap`, `Close Event`, `Cancel`

**Report QC Fail Modal**
- Step form 2 ขั้น: (1) Select Context → เลือก Inspection หรือ Job Ticket (Auto-complete) + station + operator (prefill) (2) Fail Details → fail code (Select2), severity (radio pill), defect qty + UoM, root cause (textarea), note, upload (dropzone)
- Validate realtime; error tooltip ใช้ `data-i18n` key `qc.fail.validation.*`
- เมื่อบันทึกสำเร็จ แสดง Toastr success + ปิด modal + refresh list

**Rework Task Modal**
- Fields: Action Type (radio: Rework / Scrap), Assign To (Select2), Due Date (Flatpickr datetime), Target Qty, Priority (optional), Remarks
- ปุ่ม `Start Now` (auto-set status = in_progress) และ `Save As Pending`
- การอัปเดตสถานะ/qty ทำใน card list ภายใน detail drawer → inline controls (dropdown status, input qty, textarea note) → บันทึกแล้ว append log row

**Empty / Loading States**
- Skeleton loader 3 แถวสำหรับ DataTable
- เมื่อ timeline ไม่มีข้อมูล แสดงข้อความ `qc.rework.timeline.empty`

### Mobile (Atelier WIP)
**Entry Points**
- หลังสแกน Job Ticket → ปุ่ม `รายงาน QC Fail` ปรากฏใน action sheet
- เมนูใหม่ `งาน Rework ของฉัน` ใน mobile dashboard (แสดง count badge)

**Report Fail Flow**
- Fullscreen modal (mobile friendly form)
  - Header: Ticket info + station badge
  - Section Photo: ปุ่ม `ถ่ายรูป` (Camera API) + preview carousel
  - Fields: severity (segmented buttons), defect qty, fail code (autocomplete), root cause (textarea with suggestions), note
  - ปุ่ม `บันทึก` (primary) + `ยกเลิก`
- Validation แสดงด้วย toast + highlight field

**My Rework Tasks**
- List card แสดงเลขงาน, fail summary, due at (badge สี), status pill, progress bar (qty_completed / qty_target)
- กดเข้า card → หน้า details: ข้อมูล fail, attachment, action buttons (`เริ่ม`, `เสร็จแล้ว`, `แจ้งปัญหา`, `เพิ่มหลักฐาน`)
- Inline input สำหรับเพิ่มจำนวนที่ทำเสร็จ (numeric keypad)
- Timeline log แสดงในรูปแบบ chat bubble (ล่าสุดบนสุด)

**Offline Considerations**
- บันทึก fail ทุกครั้ง sync ผ่าน queue (เหมือน WIP log) → แสดง status `รอส่ง`, `ส่งแล้ว`
- Attachment upload บังคับออนไลน์ (แจ้งเตือนผู้ใช้เมื่อ offline)

### Accessibility & i18n
- ทุก label, placeholder, ปุ่ม ใช้ `data-i18n`
- Severity badge ใช้สี + icon (Low=info, Medium=warning, High=danger)
- ฟอร์มรองรับ keyboard navigation และ screen reader (`aria-label` สอดคล้อง)


## Reporting & Dashboard

### QC Fail Listing (Web)
- หน้าใหม่ `page/qc_fail_report.php` + `views/qc_fail_report.php`
- Filter Controls (เหนือ DataTable)
  - Date range (default = 7 วันล่าสุด)
  - Station (multi-select)
  - Severity (checkbox pill)
  - Action type (rework / scrap / pending)
  - Assigned to (Select2 แสดงเฉพาะ active users)
  - Toggle `แสดงเฉพาะที่ปิดแล้ว` / `แสดงเฉพาะที่ยังเปิดอยู่`
- Columns ที่ต้องแสดง: Fail ID, วันที่, Job Ticket, Product SKU, Station, Severity (badge), Defect Qty, Current Action, Task Status, Age (diff รายงานถึงปัจจุบัน), ผู้ดูแลล่าสุด
- Summary Row (footer) แสดง Defect Qty รวม + Rework Qty รวม + Scrap Qty รวม (ใช้ aggregation จาก query)
- Export buttons (DataTables): CSV, XLSX, Print → ใช้ชื่อไฟล์ `qc_fail_report_{YYYYMMDD}.csv`
- Permission guard: `must_allow('qc.fail.view')`

### รายงาน Pivot (CSV / XLSX)
- Endpoint `source/qc_fail_report.php?action=export` รับ filter เหมือน DataTable และส่งกลับไฟล์ CSV/XLSX
- โครงไฟล์
  - Sheet1: รายการ fail (ข้อมูลเดียวกับ DataTable + เพิ่ม root cause, notes)
  - Sheet2: Pivot summary (group by station & severity → defect qty, rework qty, scrap qty, turnaround time เฉลี่ย)
- ใช้ helper `export_to_csv()` / `export_to_xlsx()` (จะเพิ่มใน `source/service/export_helper.php`)
- ระบุ encoding UTF-8 + BOM เพื่อเปิดใน Excel ภาษาไทยได้

### Dashboard Metrics
- Dashboard main (page/dashboard.php) เพิ่ม widget ใหม่ในหมวด Production
  1. **Defect Rate** = Σ defect_qty ÷ Σ production_qty (ดึงจาก job ticket / MO) → กราฟเส้น 7 วัน
  2. **Rework Turnaround** = ค่าเฉลี่ย (task completed_at - assigned_at) เฉพาะ action_type = rework → แสดงค่าชั่วโมง พร้อม sparkline
  3. **Scrap Volume** = Σ qty_target action_type = scrap ช่วง 7 วัน → bar chart เทียบสถานี
  4. **Open Tasks** = จำนวน task status != completed → แสดง list 5 รายการล่าสุด
- ทุก widget ต้องรองรับ i18n (ใช้ `dashboard.qc.*`)
- เพิ่ม API endpoint `source/qc_fail_dashboard.php?action=metrics` คืน JSON:
  ```json
  {
    "defect_rate": {"series": [...], "labels": [...]},
    "rework_turnaround": {"avg_hours": 4.3, "trend": [...]},
    "scrap_volume": {"series": [...], "stations": [...]},
    "open_tasks": [{"task_id":1,"fail_id":9,"station":"POLISH","assigned_to":"Somchai","due_at":"2025-10-20T12:00:00+07:00"}]
  }
  ```
- Cache metrics 5 นาที (ใช้ `CacheHelper::remember('qc_dashboard_metrics', 300, fn(){...})`)

### Notifications & Follow-up
- เมื่อสร้าง fail severity = high → trigger แจ้งเตือนผ่าน vorhand notification system (`source/notifications.php?action=publish`)
- เมื่อ task ใกล้ due (<= 4 ชม.) ให้ cron job (`tools/cron/check_rework_due.php`) scan ทุก 15 นาที แล้วส่ง notification + email template (เพิ่ม i18n key `email.qc.rework_due.*`)

### Data Quality Checks
- Nightly job (`tools/cron/generate_qc_fail_snapshot.php`) สร้าง snapshot summary ลง `qc_fail_snapshot` table (date, station, defect_qty, rework_qty, scrap_qty, avg_turnaround)
- ใช้ snapshot สำหรับ long-range analytics และลดภาระ query หนักบนหลัก


## Permissions
- `qc.fail.manage` – สร้าง/แก้ไข/ปิด fail event
- `qc.fail.view` – อ่านอย่างเดียว
- `qc.rework.manage` – มอบหมายและอัปเดต rework task
- ปรับตาราง permission_allow seed ใน migration core bootstrap

## Migration Notes
- ใช้ helper `migration_create_table_if_missing`, `migration_add_column_if_missing`, `migration_add_index_if_missing`
- ต้องวน tenant ทั้งหมด (ใช้ `run_tenant_migrations_for_all()` ตามมาตรฐาน)
- ระบุ rollback script ใน plans/001x_down.sql หลังออกแบบเสร็จ

## Auditing & Observability
- ทุก action ใน controller log ผ่าน `LogHelper::info` (tenant, fail_id, actor)
- `qc_rework_log` ถือเป็น audit trail หลัก (who/what/when)
- Healthcheck: ตรวจว่ามี migration ล่าสุด (`tenant_schema_migrations`) ก่อนเปิดใช้งาน

## Backward Compatibility
- ไม่มีการอัปเดตข้อมูลเดิม (ตารางใหม่ทั้งหมด + คอลัมน์เพิ่มเติมเป็น nullable)
- Dashboard KPI เก่าจะได้ข้อมูลเพิ่มทันทีจากตารางใหม่ (ต้องอัปเดต query หลังจากมีฟิลด์ใหม่)


