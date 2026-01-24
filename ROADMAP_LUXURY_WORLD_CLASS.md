# 🗺️ Bellavier ERP Roadmap — Luxury World‑Class Operating System

**Version:** 1.0  
**Last Updated:** 2026-01-07  
**Audience:** Product Owner, CTO, Engineering, Operations (Factory), QA/QC Leads  
**Scope:** Internal system first, designed to scale into partner/customer‑facing workflows safely

---

## 0) วิสัยทัศน์ (Vision)

> สร้าง “Operating System สำหรับโรงงาน Luxury” ที่ **คุณภาพมาก่อน** และ **อธิบายได้**:  
> “ทุกชิ้นมีเรื่องเล่า (Trace), ทุกการตัดสินใจมีเหตุผล (QC), ทุกเหตุการณ์ย้อนกลับได้ (Audit), ทุกการไหลงานไม่ขาด (Flow).”

### 0.1 คำจำกัดความ “World‑Class Luxury”
ระบบจะถือว่าเข้าใกล้ระดับโลกเมื่อผ่าน 6 เสาหลัก:
- **Quality Governance**: QC/Rework เป็นระบบตัดสินใจแบบมนุษย์ (human‑in‑the‑loop) พร้อมหลักฐานและเหตุผล
- **Full Traceability**: ต้นทางวัสดุ → กระบวนการ → คน/สถานี → ผล QC → ลูกค้า (รวม export/share ที่ควบคุมสิทธิ์)
- **Resilient Orchestration**: DAG/SuperDAG รองรับ split/join, exception, self‑healing และไม่ทำให้ “งานหาย”
- **Security & Privacy by Design**: uniform security posture + PDPA/GDPR‑ready boundary (แม้ใช้งานภายใน)
- **Operational Excellence**: monitoring, audit, backups/restore drills, incident playbook
- **Premium UX**: Operator/Manager UX ที่ลดความผิดพลาดและทำงานเร็ว (มือถือ/แท็บเล็ตเป็น first‑class)

---

## 1) หลักการกำกับ (Non‑negotiables)

### 1.1 Quality > Speed (Luxury ethos)
- หลีกเลี่ยง feature ที่เพิ่มความเสี่ยงใน runtime โดยไม่จำเป็น
- เปลี่ยนระบบแบบ staged + feature flags + tests

### 1.2 Data Integrity / Single Source of Truth
- เหตุการณ์ (events) คือความจริง (canonical), state ต้อง reconstruct ได้
- ไม่ยอมให้เกิด “silent failure”

### 1.3 Governance ก่อน automation
- ลำดับความสำคัญ: **ความถูกต้อง → ความเข้าใจง่าย → ความเร็ว**

---

## 2) สถานะปัจจุบัน (Jan 2026) — สิ่งที่ “แข็งแรงแล้ว”

### 2.1 Production Orchestration
- Hatthasilpa ใช้ DAG mode เป็นหลัก (token lifecycle, assignment, work queue)
- Classic ใช้ Linear minimal/legacy ตามแนว deprecation guide

### 2.2 Product Master: Product Workspace
- Workspace เป็น canonical editor (Phase 1–4 สำเร็จ, Phase 5 กำลัง deprecate legacy modal)
- Readiness gate, revisions lifecycle, publish flow, UI refresh model

### 2.3 Quality / Defect / Rework
- Defect Catalog + QC Rework V2 (human decision + audit)
- Graph Linter + validation engine ป้องกัน graph ผิดมาตรฐาน

### 2.4 Enterprise API & Platform Discipline
- มีมาตรฐาน bootstrap/validation/rate limit/idempotency/ETag และ PSR‑4 services สำหรับงานใหม่

---

## 3) Roadmap Overview (2026–2027)

### 3.1 Roadmap Map (High level)
- **2026 Q1**: Stabilize + Finish Product Workspace Phase 5 + Materials UI + Security hardening P0
- **2026 Q2**: Production Control Center + KPI/Analytics + Material execution integration (reservation→consume)
- **2026 Q3**: Linear extended-mode deprecation execution + multi‑tenant scalability + performance hardening
- **2026 Q4**: Customer trust layer (trace portal/share links/policies) + compliance pack + multi‑factory readiness
- **2027 H1**: Planning intelligence (ETA/SLA + capacity) + Supplier collaboration boundary
- **2027 H2**: Digital twin primitives + optimization loops (quality feedback → graph/product constraints)

---

## 4) Workstreams (รายละเอียดเชิง epics)

## 4A) Product Operating System (Product Workspace & Governance)

### Epic A1 — Product Workspace Phase 5 (Complete deprecation of legacy edit entry points)
**Why:** สร้าง “single canonical editor” ลดการแตกสภาวะ (state divergence) และลด UI debt  
**Deliverables:**
- Legacy edit modal ถูกปิด/ซ่อน (ยังคง fallback ได้เฉพาะกรณีฉุกเฉินที่กำหนด)
- All entry points (list, deep links, duplicate, drafts) เปิด Workspace 100%
- Constraints workflow ถูกย้ายเข้า workspace เต็มรูปแบบ
**DoD / Acceptance:**
- เปิด workspace ≤ 500ms (cached shell) และ data load stable
- ทุก action ที่เคยทำใน modal เก่ามีเทียบเท่าที่ workspace
- ไม่มีการเขียนข้อมูลสองทาง (double write)
**Target:** 2026 Q1 (Jan–Feb)

### Epic A2 — Product Config “Luxury constraints” (contracts → enforcement)
**Why:** Luxury ต้องควบคุมข้อกำหนด: วัสดุ/ขนาด/ชิ้นส่วน/ข้อจำกัดงานฝีมือ  
**Deliverables:**
- constraints contract v1 (already) → validator + UI enforcement
- readiness ไม่ใช่แค่ “ครบ” แต่ “ถูกต้องตามสเปค”
**DoD:**
- Validation rules + audit trail
- Clear UX: error explains what to fix
**Target:** 2026 Q1–Q2

### Epic A3 — Revision governance maturity (Release train)
**Deliverables:**
- Revision policies: who can publish/retire, approval steps (optional)
- Change impact preview: graph/material/component diffs พร้อมความเสี่ยง
**Target:** 2026 Q2

---

## 4B) DAG/SuperDAG Runtime Excellence (Luxury-grade flow)

### Epic B1 — Codify Baseline & Non‑Regression (from LIVE operational baseline)
**Deliverables:**
- Tests that lock baseline invariants (cancel/restart/idempotency/sanitized JSON/work-queue hydration)
- Audit hooks + metrics for drift detection
**DoD:**
- Critical integration suites stay green (Subgraph governance, draft layer, E2E spawn/work queue)
**Target:** 2026 Q1 (ongoing hardening)

### Epic B2 — Graph Draft UX polish (Phase 7.Y)
**Deliverables:**
- Draft badge/banner, publish dialog with validation summary, autosave UX, disable legacy save when draft exists
**Target:** 2026 Q1–Q2

### Epic B3 — Simulation / Dry Run (no DB writes)
**Deliverables:**
- graph_simulate endpoint + UI “Dry Run” report (paths, reachability, join/split warnings)
**Target:** 2026 Q2

---

## 4C) Materials & Inventory (Luxury = traceable materials)

### Epic C1 — Material Requirement UI (Backend exists → UI completion)
**Deliverables:**
- UI to view requirements per job/token/component
- Reservation visibility (shortage detection, FIFO rationale)
**DoD:**
- Operator/manager sees “why shortage”, “what reserved”, “what consumed”
**Target:** 2026 Q1–Q2

### Epic C2 — Execution integration: consume/return/scrap with audit
**Deliverables:**
- Integrate material allocation at node execution
- Scrap flows link to QC outcomes (defect → scrap reason)
**Target:** 2026 Q2–Q3

---

## 4D) QC, Defect, Rework (Luxury quality loop)

### Epic D1 — QC evidence & attachments governance
**Deliverables:**
- Evidence capture rules (photo/video/doc) + retention policy + privacy boundary
- Structured QC checklist templates per product/operation
**Target:** 2026 Q2–Q3

### Epic D2 — Quality analytics loop
**Deliverables:**
- Defect trends by component/material/station/operator/time
- Feedback into product constraints + graph design rules
**Target:** 2026 Q3–Q4

---

## 4E) Traceability & Customer Trust Layer

### Epic E1 — Trace portal (internal first → customer view)
**Deliverables:**
- Internal trace = “single source of truth view”
- Customer view policies (masking, consent, expiry links)
**Target:** 2026 Q3–Q4

### Epic E2 — Luxury certificate export (PDF/QR/Hash)
**Deliverables:**
- Export package: timeline + materials + QC summary + authenticity hash
**Target:** 2026 Q4

---

## 4F) Security & Privacy Hardening (แม้ภายในก็ต้อง “audit‑ready”)

### Epic F1 — Uniform security posture across reachable endpoints
**Deliverables:**
- CSRF coverage policy for state‑changing endpoints (tenant + platform)
- Rate limit coverage report + enforcement tests
- Upload hardening baseline (type/size/permission/storage rules)
 - Standardization audit baseline (file-level): `docs/audit/STANDARDIZATION_AUDIT_2026_01_07.md`
**Target:** 2026 Q1–Q2

### Epic F2 — Identity & access maturity
**Deliverables:**
- Optional MFA/SSO readiness (internal)
- RBAC + separation of duties templates for Luxury operations
**Target:** 2026 Q2–Q3

---

## 4G) Operational Excellence (World‑class means “runs forever”)

### Epic G1 — Observability pack
**Deliverables:**
- Standard dashboards: latency, error rate, queue health, token anomalies
- Correlation ID tracing end‑to‑end + log hygiene
**Target:** 2026 Q1–Q2

### Epic G2 — DR & Reliability drills
**Deliverables:**
- Backup/restore drill playbook + quarterly rehearsal
- Migration safety gates per tenant
**Target:** 2026 Q2

---

## 5) Deprecations & Simplification (ลดความซับซ้อนให้เหลือ “ระบบเดียวที่ดีมาก”)

### 5.1 Linear extended‑mode deprecation (Q3 2026)
**Reference:** `docs/developer/08-guides/10-linear-deprecation.md`  
**Principle:** ไม่รีบ—ต้องมี evidence ว่า DAG stable และไม่มีการใช้งาน linear extended แล้ว

---

## 6) Quality Gates (Luxury Grade) — ผ่านก่อนเรียก “World‑Class”

### 6.1 Non‑regression gates (ทุก release)
- Test suites (integration + critical E2E) ต้อง green
- ไม่มี endpoint state‑changing ที่ไม่มี CSRF/RateLimit/validation
- ไม่มี multi‑chunk JSON จาก orchestrators

### 6.2 KPI gates (รายไตรมาส)
- **First‑Pass Yield (FPY)** ≥ เป้าหมายที่กำหนดต่อไลน์ผลิต
- **Rework rate** ลดลง QoQ
- **Trace coverage**: 100% pieces have trace timeline + materials linkage (for Hatthasilpa)
- **Uptime / error rate** อยู่ในเกณฑ์ และ MTTR ดีขึ้น

---

## 7) การบริหารความเสี่ยง (Risk Register – แบบปฏิบัติ)

### 7.1 Risk: Legacy reachable endpoints
- **Mitigation:** inventory + classify reachable endpoints + stage hardening without refactor

### 7.2 Risk: Dual‑mode complexity
- **Mitigation:** follow linear deprecation guide, add usage telemetry, migrate safely

### 7.3 Risk: Data correctness drift
- **Mitigation:** invariants + periodic integrity checks + self‑healing verified by tests

---

## 8) What “Next” Means (Immediate next 30–60 days)

**Must ship (Q1):**
- Finish Product Workspace Phase 5 (full canonical editor)
- Materials UI (visibility + shortage)
- Security hardening P0: upload + CSRF coverage expansion (staged)

**Should ship (Q1/Q2):**
- Graph draft UX polish + simulation endpoint
- Work queue mobile UX polish (tap targets, speed)

---

## 9) Appendix — Related Docs

- Product Workspace tasks: `docs/06-specs/PRODUCT_WORKSPACE_IMPLEMENTATION_TASKS.md`
- DAG roadmap (deep): `docs/dag/05-implementation-status/DAG_IMPLEMENTATION_ROADMAP.md`
- DAG next steps (condensed): `docs/dag/05-implementation-status/ROADMAP_NEXT_STEPS.md`
- Linear deprecation guide: `docs/developer/08-guides/10-linear-deprecation.md`
- Developer policy: `docs/developer/01-policy/DEVELOPER_POLICY.md`


