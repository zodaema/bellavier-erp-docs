## Atelier Engineering Standards

### Core Principles
- **Reliability First**: ทุกฟีเจอร์ต้องป้องกันข้อผิดพลาดไว้ก่อน (validate, fallback, log) เพื่อไม่ให้กระทบการผลิต
- **Consistency By Design**: routing, view, controller, JS, DB ใช้โครงสร้างเดียวกันเพื่อให้คนทำต่อเข้าใจทันที
- **Field Friendly UX**: UI ต้องเรียบง่าย เข้าใจได้แม้ผู้ใช้ไม่ถนัดคอมพิวเตอร์ (ปุ่มชัด, ภาษาไทย, feedback ตรงไปตรงมา)
- **Transparency & Traceability**: ทุก action ต้องมี log/alert ที่บอกสาเหตุความผิดพลาดได้เร็ว
- **Offline Aware**: พิจารณา scenario ออฟไลน์/เชื่อมต่อไม่เสถียรเป็น baseline
- **Security & Privacy First**: RBAC, least privilege, audit trail ครบ; ข้อมูลอ่อนไหวต้องแยก/มาส์กตามมาตรฐาน
- **Observability & Reliability**: ทุก endpoint ต้องมี log/metric/healthcheck รองรับ incident grouping
- **Continuous Testing**: unit/API/E2E/load test เป็นส่วนหนึ่งของการปล่อยทุกครั้ง

### Routing & Page Structure
- `index.php` คือ single router: กำหนด path ทั้งหมดผ่าน `$objPage->storePath`
- ทุกหน้า UI ใช้คู่ไฟล์ `page/<name>.php` (กำหนด `$page_detail`) + `views/<name>.php`
- Layout ต้องเริ่มด้วย
  ```html
  <div class="main-content app-content">
    <div class="container-fluid p-4">
      ...
  ```
- CSS/JS ที่หน้าใดต้องการให้ระบุผ่าน `$page_detail['css']` / `$page_detail['jquery']` เท่านั้น
- Sidebar-menu แก้ไขผ่าน `views/template/sidebar-left.template.php` พร้อม permission code เสมอ

### Controller & API Guidelines (`source/*.php`)
- เปิดไฟล์ด้วย `session_start();`, require: `config.php`, `model/member_class.php`, `permission.php`
- ตรวจ session (`member`) → permission → tenant db ก่อน switch action
- Response format: ใช้ `json_success()` + `json_error($message, $code)` (status code ต้องถูกต้อง)
- SQL ทุกคำสั่งต้องใช้ `prepare + bind_param` ผ่าน helper (`db_fetch_all`, `migration_*`)
- Error message เป็นภาษาไทย, ชัดเจน, บอกว่าต้องแก้อะไร
- Log สำคัญ (เช่น insert WIP) ต้องบันทึก operator, actor, payload เพื่อ audit

### Frontend / JavaScript
- วางไฟล์ใน `assets/javascripts/<module>/` ใช้ IIFE:
  ```js
  (function ($) {
    $(function () {
      // code
    });
  })(window.jQuery);
  ```
- เก็บ selector ตอนต้น, แยกฟังก์ชันย่อยชัดเจน (`load`, `render`, `bindEvents`)
- Error handling: แสดง alert ที่เข้าใจง่าย + log รายละเอียดผ่าน `console.warn/error`
- รองรับออฟไลน์ (queue, retry, token fallback) เป็น default
- ใช้ภาษาไทยสำหรับข้อความ UI, บอกวิธีแก้ควบคู่เสมอ

### Database & Migrations
- ใช้ helper ใน `database/tools/migration_helpers.php` ทุกครั้ง (ไม่เขียน SQL ตรง)
- Schema ต้อง idempotent; เพิ่ม index/column ผ่าน `migration_add_*`
- Permission/seed แยก core vs sample ตามโครงปัจจุบัน (`seed/core_seed.php`, `seed/sample_seed.php`)
- Naming: ตาราง `atelier_*`, column snake_case, foreign key ระบุให้ชัดพร้อม index

### UX & Content Rules
- ปุ่ม/ข้อความสั้น ชัด และเน้นการกระทำ (เช่น “บันทึกเหตุการณ์”, “ซิงก์คิว”)
- Feedback ต้อง realtime: loading state, success, error พร้อมสาเหตุและวิธีแก้
- รองรับภาษาไทยเต็มรูปแบบ; เก็บ key/message ในที่เดียวเมื่อมีระบบแปล (เตรียม `lang/`)
- เมื่อสร้างหรือปรับปรุง module/view/API/JS ทุกครั้ง ต้องอัปเดต dictionary (`lang/th.php`, `lang/en.php`) และตรวจว่า key ที่เพิ่มถูกใช้งานจริงทั้งฝั่ง PHP และ JS
- Flow ต้องพิจารณาผู้ใช้ที่ไม่ชำนาญ: ขั้นตอนให้น้อยที่สุด, ใช้คำ/สัญลักษณ์เข้าใจง่าย
- ปุ่มขนาด ≥44px, contrast ≥4.5:1, รองรับ kiosk/screen touch และการสแกนปุ่ม physical
- ข้อความ error ต้องบอก “วิธีแก้” สั้นๆ เสมอ เช่น “เช็กสถานีเดิมก่อนสแกนถัดไป”
- รองรับ multi-language (ไทย/อังกฤษ/จีน) ผ่าน i18n key
- เส้นทางการใช้งานพยายามพาผู้ใช้ไป action ที่ “ควร” ทำถัดไป (zero-conf path)

### QA Checklist (ทุก Pull Request / Deployment)
1. ✅ Routing ถูกประกาศใน `index.php`
2. ✅ Page ใช้ layout มาตรฐาน + `$page_detail`
3. ✅ Controller มี session + permission check + response format
4. ✅ SQL ผ่าน helper และ tested บน tenant ตัวอย่าง (`DEFAULT`, `MAISON_ATELIER`)
5. ✅ JS มี error handling + รองรับออฟไลน์ (ถ้ามีคิว)
6. ✅ UX ตรวจด้วยผู้ใช้จำลอง (เดิน flow หลัก) + คำเตือนภาษาไทยตรงไปตรงมา
7. ✅ Log/console ไม่มี error ที่ยังไม่จัดการ
8. ✅ เอกสาร/คู่มือ (ถ้ามีฟีเจอร์ใหม่) อัปเดตแล้ว

### Documentation & Handoff
- อัปเดต `at.plan.md` เมื่อเพิ่ม feature/sprint ใหม่
- เอกสารมาตรฐานทั้งหมดเก็บใน `docs/`
- สำหรับ feature ที่ผู้ใช้งานต้องเรียนรู้ ให้เพิ่ม quick guide ภาษาไทย (PDF หรือ markdown)
- บันทึกข้อจำกัด/known issues ในเอกสารถัดไปเพื่อให้ทีมต่อยอดรู้ context
- README_for_cursor.md, erp_addons_plan.md, changelog ต้อง update ทุก release
- รวม security/privacy guideline สำหรับ developer (RBAC, secret, audit trail)

### Security, Privacy & Compliance
- AuthN/AuthZ: ใช้ RBAC + scope (tenant_id, brand/client_id, role_claims) ตรวจทุก endpoint
- Least privilege: ค่าเริ่มต้น deny, grant ผ่าน permission เท่านั้น
- Secret management: ห้ามฮาร์ดโค้ด; ใช้ `.env` หรือ Secret Manager
- PII/Factory IP: คอลัมน์อ่อนไหวแยกจัดเก็บ, มาส์กใน log
- Audit trail: บันทึก who/what/before/after/why สำหรับ action สำคัญ
- Data retention: นิยามอายุเก็บ (เช่น WIP raw 18 เดือน, QC รูป 36 เดือน) + งานล้างข้อมูล
- Backup & DR: snapshot รายวัน, ทดสอบ restore รายไตรมาส (RPO ≤ 24h, RTO ≤ 4h)

### Observability & SRE
- Logging: Structured log พร้อม trace_id, tenant, actor, station_code, job_ticket ทุกครั้ง
- Metrics: app latency/p95, error rate, WIP queue size per station, FPY, rework TAT
- Healthchecks: `/healthz` (DB, queue, storage) และ `/readyz` (migration applied)
- Incident level: P1 หยุดผลิต, P2 ชะลอ, P3 ไม่กระทบผลิต พร้อม playbook สื่อสาร
- Rate limit & backpressure: ป้องกันสแปมสแกน/คิวล้น

### API Standards
- Versioning: `/api/v1/...` ห้าม breaking change โดยไม่เพิ่มเวอร์ชัน
- Idempotency: ทุก POST ที่เขียนข้อมูลรองรับ `Idempotency-Key`
- Error taxonomy: ใช้รหัส VALIDATION_ERROR / PERMISSION_DENIED / CONFLICT / OBSOLETE_VERSION
- Timezone: เก็บ UTC, แสดง Asia/Bangkok ที่ UI เท่านั้น
- Naming: DB ใช้ snake_case, JSON ใช้ camelCase

### Data & Schema Governance
- Migration idempotent (IF NOT EXISTS, rollback script)
- Naming: prefix `atelier_` สำหรับชั้นงาน Atelier
- Foreign key & index ต้องครบตามคีย์ค้น (tenant, station, timestamp)
- Master versioning: product.version, route.version, ECO ต้องมี effective_from ก่อนใช้งาน MO

### Testing Strategy
- Unit test: service layer ควรมี coverage ≥70%
- API Contract: ตรวจ request/response ตาม `plans/api_addons_spec.md`
- Integration: seed tenant ตัวอย่างแล้วรัน migration ทุกครั้ง
- E2E: Happy path “Scan→QC→Serialize→Pack” ผ่าน Playwright
- Load test: สคริปต์สแกน 20 req/s ต่อ station (p95 < 300ms)

### Release & Change Management
- Feature flag เปิด/ปิดโมดูล (ECO, Offline WIP, Labels)
- Canary/Pilot line: เปิดใช้ 1 ไลน์ผลิตก่อนระบบจริง 1 สัปดาห์
- Changelog + migration note ทุก release

### Performance & Reliability Budgets
- UI: หน้า WIP โหลด < 1.5s/4G, feedback action ≤ 150ms
- DB: Query WIP ล่าสุด ≤ 100ms (index workpiece_id, station_id, ts)
- Queue: ออฟไลน์ sync ≤ 5 นาที, แจ้งเตือนถ้าเกิน

### Multi-Tenant Safety
- ทุก query/insert ต้อง filter ด้วย tenant_id
- Export/Download ต้องใส่ลายน้ำ tenant/code + expire link
- หลีกเลี่ยง cross-tenant join โดยใช้ DAO กลาง

### Barcode/Label Standards
- Payload มาตรฐาน: `BGERP|TICKET|<id>|<token>|STATION|<code>|EVENT|scan_in`
- Token rotation: regenerate label ต้องเปลี่ยน token และบันทึก revoke
- Profiles: WIP/TRAY/FG/SHIP พร้อมฟอนต์ไทย/ขนาดคงที่

### Queues & Offline Handling
- Exactly-once (pragmatic): ใช้ idempotency key + marking ที่ `atelier_wip_log`
- Dead-letter: บันทึก log เมื่อ error > N ครั้ง ให้หัวหน้าสถานีแก้
- Conflict policy: สแกนย้อนลำดับต้องแจ้ง “ยังไม่ scan out จากสถานีก่อนหน้า”

### Coding Conventions
- PHP: PSR-12, service class แยกต่อ module (เช่น `AtelierWipService`)
- JS: IIFE module, ห้าม leak global; ใช้ fetch wrapper ร่วม (timeout, retry, json envelope)
- Linter: PHP-CS-Fixer / ESLint + pre-commit hook

## Internationalization
- ทุก module ที่แก้ไขต้องตรวจสอบและเพิ่ม key ใน `lang/en.php` และ `lang/th.php` พร้อมใช้งานใน view และ JS
- ข้อความใน JS ควรเรียกผ่าน helper `t(key, fallback)`; ใน PHP view ใช้ `translate()` หรือ `data-i18n`
- เมื่อเพิ่ม/แก้ไขข้อความ ควรบันทึกในเอกสารนี้เพื่อให้ทีมรับรู้การเปลี่ยนแปลงมาตรฐาน

### Sprint 4 – QC Fail / Rework Workflow
- เก็บเหตุการณ์ QC fail, root cause, ปริมาณ, station, operator และแนบหลักฐาน (รูป/หมายเหตุ)
- ระบบต้องรองรับการตัดสินใจ rework หรือ scrap พร้อมกำหนดผู้รับผิดชอบ/นัดหมาย
- ทุกการเปลี่ยนสถานะต้อง log และแสดงในรายงาน (tenant-aware)
- หน้า UI เพื่อบันทึก/ติดตามรวมถึง mobile WIP ต้องรองรับ i18n และมาตรฐาน UX เดิม
- รายงาน defect และ rework ต้อง export ได้ (CSV) และเชื่อมกับ dashboard KPI
