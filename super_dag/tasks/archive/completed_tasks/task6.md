คุณคือ Senior PHP Engineer + System Architect ของโปรเจกต์ Bellavier Group ERP
โฟกัสงานเฉพาะในโฟลเดอร์นี้เท่านั้น: `source/` และ `docs/super_dag/`

เป้าหมาย: Implement Task 6: Token Engine Integration (Phase 1 - Logging + Minimal Token Touch)
อ้างอิงสถาปัตยกรรมจาก:
- `docs/super_dag/tasks/task5.md`
- `docs/super_dag/tasks/task5_results.md`
- `source/dag_behavior_exec.php`
- `assets/javascripts/dag/behavior_execution.js`

ข้อกำหนดหลัก:
1. ห้ามแตะ Time Engine ใด ๆ (JS หรือ PHP)
2. ห้ามแตะ DAG Routing Logic (movement ระหว่าง node)
3. ห้ามแก้ไข behavior UI templates (`behavior_ui_templates.js`)
4. ห้ามเปลี่ยน payload structure จาก frontend
5. ห้ามโยน exception ออกจาก API โดยไม่จับ → ต้องคืน JSON error ผ่าน `TenantApiOutput::error()`
6. ห้ามแก้ไขไฟล์ JS นอกจากเพื่อ debug / log เพิ่ม (แต่ตอนนี้พยายามอย่าแตะเลย)

สิ่งที่ต้องทำ:

1) สร้าง Service กลาง
- สร้างไฟล์ใหม่: `source/BGERP/Dag/BehaviorExecutionService.php`
- namespace: `BGERP\Dag`
- class: `BehaviorExecutionService`
- constructor รับ `$db, $org`
- เมธอด public:
  - `execute(string $behaviorCode, string $sourcePage, string $action, array $context = [], array $formData = []): array`
- ภายใน `execute()`:
  - switch ตาม `$behaviorCode`:
    - 'STITCH' → เรียก `$this->handleStitch(...)`
    - 'CUT' → `$this->handleCut(...)`
    - 'EDGE' → `$this->handleEdge(...)` (อาจยังเป็น stub)
    - 'QC_SINGLE', 'QC_FINAL' → `$this->handleQc(...)`
  - default → return `['ok' => false, 'error' => 'unsupported_behavior']`
- แต่ละ handler (private method) ทำแค่:
  - validate ว่า context มี `token_id`, `node_id` (ถ้าจำเป็น)
  - เขียน log ลง table ที่มีอยู่แล้ว เช่น `dag_token_log` หรือถ้าไม่มี ให้สร้างตารางใหม่ `dag_behavior_log`
  - ห้ามแก้ไข Time Engine
  - ถ้าจะอัปเดต token state ให้ทำแค่:
    - STITCH:
      - `stitch_start` → set token_status = 'IN_PROGRESS'
      - `stitch_pause` → set token_status = 'PAUSED'
      - `stitch_resume` → set token_status = 'IN_PROGRESS'
    - CUT / QC ตอนนี้ log-only ยังไม่ต้องเปลี่ยน state
  - คืนค่า array เช่น:
    - `['ok' => true, 'effect' => 'logged_only']` หรือ
    - `['ok' => true, 'effect' => 'token_status_updated']`
  - ถ้า validation fail → `['ok' => false, 'error' => 'missing_token_id']`

2) อัปเดต `source/dag_behavior_exec.php`
- ใช้ `BehaviorExecutionService` แทนการ log เปล่า ๆ
- flow:
  - bootstrap → parse payload → validate → สร้าง service → `$result = $service->execute(...)`
  - ถ้า `$result['ok'] !== true`:
    - เรียก `TenantApiOutput::error('behavior_exec_failed', [...])` เลือก HTTP status ให้เหมาะ (เช่น 400)
  - ถ้า ok:
    - `TenantApiOutput::success(['received' => true, 'effect' => $result['effect'] ?? 'none'])`

3) สร้าง database migration สำหรับ behavior log (ถ้ายังไม่มี)
- ตำแหน่ง: `database/tenant_migrations/2025_12_dag_behavior_log.php`
- ตาราง: `dag_behavior_log`
  - `id_log` (PK, auto increment)
  - `id_token` (nullable int)
  - `id_node` (nullable int)
  - `behavior_code` (varchar 64)
  - `action` (varchar 64)
  - `source_page` (varchar 64)
  - `context_json` (text)
  - `form_data_json` (text)
  - `created_at` (datetime)
- migration ต้อง idempotent และไม่พังใน tenant ที่รันซ้ำ

4) อัปเดตเอกสาร
- สร้าง `docs/super_dag/tasks/task6.md`:
  - อธิบายเป้าหมาย Task 6
  - ขอบเขต: logging + minimal token status
  - ข้อจำกัด: no time engine, no routing
- สร้าง `docs/super_dag/tasks/task6_results.md`:
  - เติมหลังจาก implement และ test เสร็จ (สรุปไฟล์, logic, test ที่รัน)
- อัปเดต `docs/super_dag/task_index.md` ให้มี Task 6 (IN PROGRESS หรือ COMPLETED)

การทดสอบที่ต้องรัน:
- `php -l source/dag_behavior_exec.php`
- `php -l source/BGERP/Dag/BehaviorExecutionService.php`
- รัน migration เฉพาะ tenant dev
- ทดสอบผ่าน UI:
  - กด STITCH start/pause/resume จาก Work Queue → ตรวจสอบว่ามี log ใน `dag_behavior_log`
  - ดู response JSON ว่ามี field `effect` ตามที่ออกแบบ
- ห้ามแก้ behavior UI หรือ payload structure

ให้แสดง diff แบบเป็นมิตรต่อการ review, อย่าลบ logic เดิมทิ้งโดยไม่จำเป็น