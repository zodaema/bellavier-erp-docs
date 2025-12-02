# Future Features Plan — Bellavier Group ERP

_Consolidated plan for future add-on features (not yet implemented)_

**Status:** 📋 Planning Phase  
**Last Updated:** October 2025

---

## Table of Contents
1. [ERP Add-Ons Overview](#erp-add-ons-overview)
2. [API Specifications](#api-specifications)
3. [QC SOP with AQL](#qc-sop-with-aql)

---

# ERP Add-Ons Overview

## Scope & Guiding Principles
- Add engineering governance, capacity planning, skill control, QC depth, costing accuracy, supplier quality, offline-first WIP, labels, client transparency, and auditability.
- Backward compatible with current multi-tenant architecture (Core DB + per-tenant DB). All objects below are **tenant-scoped** unless stated.
- Keep MVP-first: ship small, observable increments, behind feature flags.

---

## 1) Engineering Change & Document Control (ECO/ECN + Versions)

### Purpose
Control versions of **BOM**, **Routing**, **Specs/Patterns**, and ensure changes are approved and auditable.

### Key Objects
- `eng_change_order` (ECO header), `eng_change_item` (affected objects)
- Versioned `product`, `route`, `routing_step`, optional `bom` versioning field
- `doc_control_file` for attachments/spec PDFs

### Workflow (States)
`draft → review → approved → effective → closed/rejected`  
- Effective date enforces **no MO** with older version after the date.
- Dashboard: open ECOs; "products affected"; defects per version.

### UI/UX
- ECO list/detail, side-by-side diff of BOM/route v1↔v2, "Make effective from next MO" action.
- Attach pattern PDFs, stamping version in print header.

---

## 2) Capacity & Calendar Planning (Workcenter/Shift/Downtime)

### Purpose
Prevent bottlenecks and provide realistic lead times.

### Key Objects
- `workcenter`, `shift_calendar`, `downtime_event`
- `route_step.std_time_sec`, `route_step.workcenter_id`, `route_step.queue_policy`

### Features
- Capacity view by day/workcenter; queue aging; "what-if" extra shift; late-risk highlighting.
- KPI: On-time completion, queue length, utilization.

---

## 3) Skill Matrix & Certification

### Purpose
Assign work to qualified artisans and plan training.

### Key Objects
- `skill`, `employee_skill(level)`, `training_record`, `certification`
- Assignment rule: task with `required_skill=EDGE_PAINT_L2` visible to level ≥ 2 only.

### Features
- Skill heatmap; auto-suggest assignee; training backlog for low-FPY skills.

---

## 4) QC Advanced (AQL/Sampling + Evidence)

### Purpose
Satisfy OEM-grade QC & add visual proof.

### Key Objects
- `qc_sampling_plan`, link to `qc_checklist`
- `qc_photo_evidence` tied to inspections/defects

### Features
- AQL calculator by lot size → sample size.
- Critical defects trigger lot-hold and notification.
- Photo/video required for major/critical.

_See [QC SOP with AQL](#qc-sop-with-aql) section below for detailed workflow._

---

## 5) Rework Costing & Std→Actual Variance

### Purpose
Measure true cost and leakage due to rework/variance.

### Key Objects
- `std_cost_snapshot`, `actual_cost_capture`, `rework_cost_log`
- Tag `atelier_wip_log.time_type` = prod/rework/setup

### Reports
- Std vs Actual by product/MO
- Rework cost % of MO, root-cause by station/defect/employee.

---

## 6) After‑Sales Traceability (Serial Genealogy)

### Purpose
Close the loop to claims/service with full genealogy.

### Key Objects
- `serialization.serial_no` linked to `service_history` / external claim system
- View: serial → materials lots, artisans, edge paint codes, QC photos

---

## 7) Supplier Quality & Inbound QC + VMI‑Lite

### Purpose
Lift supplier discipline (OTD, defect) and ensure bad lots are quarantined.

### Key Objects
- `supplier_scorecard` aggregates OTD, reject rate, lead variance
- `inbound_qc` with lot hold/release
- Min/Max suggestion for materials (reorder hints)

---

## 8) Offline‑First WIP (PWA) + Scan Queue

### Purpose
Guarantee scan logs even with unstable Wi‑Fi.

### Key Objects
- `atelier_wip_scan_queue` (tenant DB), background worker `process_wip_queue.php`

### UX
- PWA page `/page/atelier_wip_mobile.php` (service worker + IndexedDB)
- Retry/sync with conflict safety; supervisor gets a "queue backlog" alert daily.

---

## 9) Label/Barcode Profiles (WIP/Tray/FG/Shipping)

### Purpose
Consistent, printable labels for shop floor and logistics.

### Key Objects
- `label_profile` and `label_template`
- Payloads: `BGERP|TICKET|<id>|<token>`, `BGERP|TASK|<id>|<token>`, `BGERP|SERIAL|<serial>`

### Print
- Server-side generation, printable via browser or print server.
- Template variables for product, color, batch, step, due date.

---

## 10) OEM Client Portal (Read‑Only)

### Purpose
Transparency without operational control for OEM clients.

### Features
- MO status, ETA, defect summary, downloadable DO/Invoice, QC sample photos.
- Role `oem_client_viewer`, tenant/brand scoped.

---

## 11) Cost‑Aware Scheduling (Priority/SLA/Penalty)

### Purpose
Sequence work based on business impact, not FIFO alone.

### Key Objects
- MO fields: `priority`, `late_penalty`, `client_sla_tier`
- Scheduler computes lateness risk score → queue recommendations.

---

## 12) Master Data Governance & Audit

### Purpose
Prevent silent mistakes in BOM/routing/costs and ensure accountability.

### Key Objects
- `audit_log` (before/after JSON), approval gates for cost/price/BOM

### Tooling
- CSV import wizard with validators; Data Quality dashboard.

---

## Rollout Plan
1. **S1**: ECO & Versioning (schema + minimal UI) — feature flag
2. **S2**: Capacity + Skill Matrix (schema + views) — pilot on 1 line
3. **S3**: QC Advanced + Evidence — integrate into existing QC flow
4. **S4**: Offline WIP + Label Pack — deploy to shop floor
5. **S5**: Costing Variance + Supplier Scorecard — management reports
6. **S6**: Client Portal (read‑only) — selected OEMs
7. **S7**: Cost‑Aware Scheduling, Data Governance — stabilization & audits

---

# API Specifications

**Base URL:** `/source/api_addons.php` (single controller with `action=`)  
**Auth:** Session-based; require role claims (see `seed_permissions.sql`)  
**Format:** `application/json` unless stated; timestamps UTC+07 (server)

## Common Response Envelope
```json
{
  "ok": true,
  "data": {...},
  "error": null,
  "ver": "addons@0013"
}
```
On error: `"ok": false, "error": {"code":"VALIDATION_ERROR","message":"...","fields":{"a":"msg"}}`

## Pagination
Query: `?page=1&per_page=50`. Response includes: `"page":1,"per_page":50,"total":123`

---

## 1) ECO / Engineering Change

### 1.1 Create ECO
`POST ?action=eco_create`
```json
{
  "eco_code": "ECO-2025-001",
  "reason": "Update edge paint recipe for CA-BG-024",
  "items": [
    {"object_type":"ROUTING","object_id":42,"action":"UPDATE","old_version":"v1","new_version":"v2"},
    {"object_type":"DOC","object_id":11,"action":"ADD","new_version":"v1"}
  ]
}
```

### 1.2 Approve / Reject / Effective
`POST ?action=eco_approve` → body: `{"eco_id":7}` (require `perm:eco.approve`)  
`POST ?action=eco_reject`  → body: `{"eco_id":7,"note":"..."}`  
`POST ?action=eco_effective` → body: `{"eco_id":7,"effective_from":"2025-11-01 00:00:00"}`  
- Prevent starting **new MO** with obsolete version after `effective_from`

### 1.3 List ECOs
`GET ?action=eco_list&status=draft|review|approved|effective|closed`

---

## 2) Capacity / Workcenter

### 2.1 Workcenter View
`GET ?action=capacity_workcenter_view&date=2025-11-01`
- Returns utilization %, queue size, late-risk for each workcenter

### 2.2 Downtime
`POST ?action=downtime_create`
```json
{"workcenter_id":1,"reason":"maintenance","start_at":"2025-11-02 08:00:00","end_at":"2025-11-02 12:00:00","type":"planned"}
```

---

## 3) Skill Matrix

### 3.1 Assign Skill Level
`POST ?action=skill_assign`
```json
{"employee_id": 101, "skill_code": "EDP", "level": 3}
```
- Validates `level <= skill.level_max`

### 3.2 Visible Tasks For User
`GET ?action=skill_visible_tasks&employee_id=101&station_code=EDP`

---

## 4) QC Evidence & AQL

### 4.1 Upload Evidence (multipart)
`POST ?action=qc_evidence_upload` (`Content-Type: multipart/form-data`)
- fields: `qc_result_id`, `defect_code`, `file` (image/video)

Response: `{"ok":true,"data":{"evidence_id": 55, "url":"https://.../qc/55.jpg"}}`

### 4.2 Sampling Plan Resolve
`GET ?action=qc_sampling_plan_resolve?lot=120&aql=II-1.5`
- Returns: sample_size, accept, reject thresholds

---

## 5) Costing Variance
`GET ?action=costing_variance&mo_id=15`
Response:
```json
{
  "ok": true,
  "data": {
    "std": {"material": 580.00, "labor": 220.00, "oh": 90.00},
    "actual": {"material": 603.10, "labor": 255.50, "oh": 92.00},
    "variance": {"material": 23.10, "labor": 35.50, "oh": 2.00, "total": 60.60},
    "rework_cost_pct": 3.2
  }
}
```

---

## 6) Serial Genealogy
`GET ?action=serial_genealogy&serial=CA24-000123`
```json
{
  "ok": true,
  "data": {
    "serial": "CA24-000123",
    "product": {"sku":"CA-BG-024-LAV","name":"Charlotte Aimée ..."},
    "mo_id": 15,
    "workpieces": [{"id": 9901, "route":"KIT→CUT→...→QC_F"}],
    "materials": [{"lot":"GOAT-LAV-LOT12","type":"leather"},{"lot":"EP-12","type":"edge_paint"}],
    "artisans": [{"station":"STC","employee":"Somchai"},{"station":"EDP","employee":"Nida"}],
    "qc_photos": [{"url":"https://.../qc/9901-1.jpg"}]
  }
}
```

---

## 7) Labels

### 7.1 Render
`GET ?action=label_render&profile=WIP_CARD&ticket_id=123`
- Returns: `text/html` (server-side rendered HTML with variables)

### 7.2 Print (optional)
`POST ?action=label_print`
```json
{"profile":"WIP_CARD","print_to":"ZPL-PRN-01","data":{"ticket_id":123}}
```

---

## 8) Scheduling Recommendation (Cost-Aware)
`GET ?action=schedule_recommend&workcenter=STC&date=2025-11-01`
- Inputs considered: `MO.priority`, `client_sla_tier`, `late_penalty`, current WIP times
- Response: ordered list of tickets with score

---

## Errors & Codes
- `AUTH_REQUIRED`, `PERMISSION_DENIED`, `VALIDATION_ERROR`, `NOT_FOUND`, `OBSOLETE_VERSION`, `CONFLICT`, `IO_ERROR`

## Security
- All actions require role claims. See `seed_permissions.sql` for mapping.
- Uploads scanned for MIME/size; store evidence in object storage; database keeps signed URL.

---

# QC SOP with AQL

## Purpose
กำหนดขั้นตอนตรวจคุณภาพด้วย AQL ให้สอดคล้องงาน OEM/Maison

## Definitions
- **Lot Size:** จำนวนชิ้นใน MO/Batch ที่จะตรวจ
- **AQL Level:** II-1.5 (ตัวอย่างในระบบ), เลือกตามลูกค้ากำหนด
- **Sample Size / Accept / Reject:** ระบบคำนวณให้อัตโนมัติตามตาราง

## Steps
1. เปิดหน้า QC และเลือก MO/Lot → ระบบคำนวณ sample size
2. ดึงตัวอย่างตามจำนวนที่กำหนดแบบสุ่ม (Random Sampling)
3. ตรวจตาม **Final QC Checklist** รายข้อ (Structure/Stitch/Edge/Hardware/...)
4. ถ้าพบ defect:
   - ระบุ **Defect code** และแนบ **Evidence (รูป/วิดีโอ)** สำหรับ Major/Critical
   - ระบบนับ **Accept/Reject** เทียบกับเกณฑ์
5. สรุปผล
   - ถ้า **Reject** → กัก Lot (Hold) และเปิด Rework Plan
   - ถ้า **Pass** → ปล่อยต่อ Serialization/Packing

## Evidence Rules
- Photo minimal 1200px wide, ชัด, แสดงตำแหน่ง
- ชื่อไฟล์อัตโนมัติ: `qc_{mo}_{workpiece}_{defect}.jpg`
- เก็บใน object storage; DB เก็บ URL

## Metrics
- First Pass Yield (FPY)
- Top Defects by category/station
- Rework Turn-around Time

---

**Note:** This is a consolidated plan document. Individual feature implementations will be tracked separately as they are prioritized and started.

