Hatthasilpa Manager Assignment — Propagation Plan (Spec‑Only)

Scope: Document the current state, architectural gap, desired behavior, and implementation/test plan to propagate `manager_assignment` plans into `token_assignment` at token spawn time. No code changes in this document.

⸻

1) Current Status (What we see)

- Manager sets node‑level plans in `manager_assignment` (“Node X for Job 290 → User A”).
- Start Job spawns tokens (e.g., 10 pieces) successfully.
- Tokens tab: all tokens remain “Unassigned”.
- Trace/Serial overview: serials created and status follow job lifecycle (OK).

Summary: Serial/traceability works; assignment propagation is missing.

⸻

2) Architectural Reason

Flow today:
1. Plan configured in `manager_assignment`.
2. Start Job (`hatthasilpa_jobs_api.php?action=start_job|start_production`) creates `job_graph_instance` and `flow_token`, then calls `dag_token_api.php?action=token_spawn`.
3. In `dag_token_api.php`, services route execution; `AssignmentEngine::autoAssignOnSpawn(...)` runs in soft mode.
4. Gap: `autoAssignOnSpawn()` does not consult `manager_assignment`, so tokens remain Unassigned unless auto rules kick in.
5. Serial/trace modules rely on serial registry and job/token status and are correct.

⸻

3) Desired Behavior (According to design)

On first spawn:
- For each token, derive `id_job_ticket` and initial `id_node` (or node code).
- Resolve plan from `manager_assignment` (job/node).
- If a plan exists: create `token_assignment` with:
  - `token_id`, `assigned_user_id`, `assignment_method='manager'`, `assigned_by_user_id`, timestamps.
- If no plan exists: apply auto‑assign policy or leave unassigned per soft policy.
- Work Queue must show `assigned_to_*` for these tokens.

⸻

4) Implementation Plan (Spec)

4.1 Files / Classes to Touch
- `BGERP\Service\AssignmentEngine` (enhance `autoAssignOnSpawn`)
- `BGERP\Service\HatthasilpaAssignmentService` (plan lookup & helpers; if present)
- `source/dag_token_api.php` (keep orchestration call; do not move logic here)

4.2 Logic to Add in `autoAssignOnSpawn()` (pseudo‑flow)
1. Input: `$tokenIds`
2. For each `$tokenId`:
   - Join `flow_token` → get `id_instance`, `current_node_id`
   - Join `job_graph_instance` → get `id_job_ticket`
   - Lookup `manager_assignment` by (`id_job_ticket`, `id_node` or `node_code`)
3. If plan found:
   - Check existing `token_assignment` for this token
   - If none: INSERT assignment with `assignment_method='manager'`
4. If no plan:
   - Fall back to existing auto‑assign or soft‑mode skip

Constraints:
- Transactional, idempotent, and no overrides in soft mode.
- No schema changes; prepared statements only.

4.3 Assignment Resolution Hierarchy (for completeness)
1) token‑specific override  
2) node‑level assignment (manager_assignment)  
3) job_ticket‑level assignment  
4) fallback to auto‑assignment

⸻

5) Test Plan (Integration)

Add to `tests/Integration/HatthasilpaAssignmentIntegrationTest.php`:
- `testManagerPlanAppliedOnSpawn`
  - Seed: minimal graph/job, instance, and `manager_assignment` (e.g., START/OP1 → user X).
  - Trigger: `start_job` → `token_spawn`.
  - Assert: `token_assignment` exists for spawned tokens with `assignment_method='manager'`.
  - Assert: Work Queue API returns `assigned_to_*` fields consistent with the plan.

Notes:
- Keep soft‑mode expectations for non‑planned nodes (no blocking).
- Ensure test cleanup respects FK order (child → parent).

⸻

6) Guardrails & Anti‑Spaghetti Rules

- Scope changes to Assignment layer; do not refactor unrelated DAG core.
- No global search/replace; keep names aligned to spec.
- Do not modify schema, migrations, or bootstrap flows.
- All state‑changing endpoints must be transactional.
- Maintain hotfix baseline: no resurrection; idempotent spawn; single JSON payload.
- Update documentation and audit after implementation; do not delete tests.

⸻

7) Developer Note (Context to share with agents)

Context update:
- `manager_assignment` plans are NOT propagated to `token_assignment` on spawn.
- Tokens appear Unassigned; serial_registry and trace flows are correct.
- Required change: in `AssignmentEngine::autoAssignOnSpawn` (or `HatthasilpaAssignmentService`), for each spawned token, look up `manager_assignment` by (`job_ticket_id`, `node_id`/`node_code`) and create `token_assignment` rows with `assignment_method='manager'` before fallback. Add an integration test to verify `start_job → token_spawn → work_queue` produces assigned tokens when manager plans exist.
``` 
This is a specification file; no code is included here.
```
*** End Patch*** }}}Ejson()?> ***!
# Hatthasilpa Manager Assignment Enablement Plan

**Date:** December 2025  
**Owner:** DAG Architecture Team  
**Linked Roadmap Items:** Phase 2B.6 (Mobile Work Queue UX), Hatthasilpa Assignment Integration Audit (Mandatory)

---

## 1. Objective

Enable “real” assignment-aware Work Queue so that:
- Manager decisions (who should do the work) are enforced at the API layer
- Work Queue (desktop + mobile) shows assignment status clearly
- Helper / takeover flows are logged explicitly
- Tests + audit prove the behavior before we roll forward to Phase 2B.6 mobile polish

Delivering this plan unlocks:
1. Accurate operator tracking (who owns the task?)
2. Clean UX for mobile cards (no confusing “Start” buttons on other people’s work)
3. Compliance with Roadmap checkpoint “Hatthasilpa Assignment Integration Audit”

---

## 2. Task A — Business Rules (Specification)

1. **Assignment States**
   - `manager`: A manager explicitly assigned the job/node to an operator
   - `auto`: Nobody assigned yet; first operator that starts becomes the assignee
   - `helper`: Operator is helping but original assignee remains
   - `replace`: Operator takes over permanently (requires reason)
2. **Start Policy (Policy Locked)**
   - **POLICY:** Hatthasilpa uses **Option B (Preferred)** → allow helper (`assist`) + takeover (`replace`) flows; strict block is *not* enabled unless a future manager flag turns it on.
   - If `assigned_to_id === current_user_id` → allow Start / Pause / Complete immediately
   - If assignment exists and belongs to someone else:
     - Show helper/takeover dialog; Start is blocked until user chooses a helper or takeover path
     - “ช่วย (assist)” → log helper session, does **not** change assignment
     - “รับแทน (replace)” → requires reason, updates assignment to new user
   - If no assignment exists → `auto-assign` to the operator who presses Start (assignment method = `auto`)
3. **Buttons**
   - **Start / Pause / Complete** show only for the current assignee
   - **ช่วย (Assist)** and **รับแทน (Takeover)** show when current user ≠ assignee
   - Desktop + mobile must show identical policy
4. **Subgraph Awareness**
   - Assignments must resolve correctly when tokens enter subgraph nodes
   - If a node launches a subgraph, assignment applies to the active subgraph instance (same operator rules propagate inside)
3. **Buttons**
   - **Start / Pause / Complete** show only for the current assignee
   - **ช่วย (Assist)** and **รับแทน (Takeover)** show when current user ≠ assignee
   - Desktop + mobile must show identical policy

> **Action:** Policy above is now locked; update only if Ops/Manager explicitly change requirements.

---

## 3. Task B — Backend Integration (`dag_token_api.php`)

### 3.1 Required Changes
1. **Load Assignment Context**
   ```php
   $assignment = $assignmentService->findForToken($tokenId);
   $currentUserId = session_get_member_id();
   ```
   _Status:_ ✅ Backend enforcement wired into `dag_token_api.php` (Dec 2025) using `HatthasilpaAssignmentService`.
2. **Enforce Policy**
   - If assignment exists:
     - `manager` → only assigned operator can use Start/Pause/Complete  
     - Others must call helper/takeover endpoints before they can work
   - If no assignment:
     - When Start succeeds → `assignmentService->assignAuto($tokenId, $currentUserId)`
3. **Helper / Takeover Actions**
   - New action IDs (or extend existing `help_token` / `takeover_token`)
   - Require reason when replacing
   - Store metadata in `token_event` or session table
4. **Events + Logging**
   - Start event must include `assignment_method` (`manager`, `auto`, `helper`, `replace`)
   - When takeover occurs → log both the old assignee and the new assignee

### 3.2 Services & Tables
- `manager_assignment`
  - `id_manager_assignment`, `id_job_ticket`, `id_node`, `assigned_to`, `assigned_by`, `method`, `reason`, `is_strict`
- `flow_token_assignment`
  - `id_token`, `assigned_to`, `assignment_method`, `assigned_at`, `helper_user_id`, `replaced_user_id`
- `token_event` (existing table) — ensure events store `assignment_method`, `helper_user_id`, `replaced_user_id`, `assignment_reason`

> **Action:** Produce PHP interface stubs and confirm with DB schema before coding.

### 3.3 Assignment Resolution Hierarchy
When resolving “who owns this token right now?” apply the following order:
1. **Token-level override** (generated by helper or takeover sessions)
2. **Node-level manager assignment** (explicit assignment for a specific graph node)
3. **Job-level assignment** (default operator for the whole Hatthasilpa job ticket)
4. **Fallback** → auto-assignment (first operator who starts becomes assignee)

AssignmentService must respect this hierarchy so subgraphs and multi-node jobs stay consistent.

### 3.4 AssignmentService Interface (reference)
```php
interface AssignmentService {
    public function findForToken(int $tokenId): ?Assignment;
    public function assignAuto(int $tokenId, int $userId): void;
    public function assignManager(int $tokenId, int $userId, ?string $reason = null): void;
    public function assignHelper(int $tokenId, int $userId): void;
    public function assignReplace(int $tokenId, int $newUserId, string $reason): void;
}
```

**API Actions**
- `action=start_token` → respects hierarchy above
- `action=token_help_start` (new) → begin helper session
- `action=token_takeover` (new or reuse `takeover_token`) → request replacement (requires reason)
- `action=pause_token` / `complete_token` → must also enforce assignment checks

---

## 4. Task C — Work Queue (Desktop & Mobile)

### 4.1 API Payload
Ensure `get_work_queue` returns:
- `assigned_to_id`
- `assigned_to_name`
- `assignment_method` (`manager`, `auto`, `helper`, `replace`)
- `can_current_user_start` (boolean after policy computed)
- `helper_allowed` / `takeover_allowed`
- `node_name`
- `stage_index` (int)
- `stage_total` (int)
- `assigned_team` / `team_category` (if manager hints apply)
- `assignment_reason` (string | null)
- `is_strict_assignment` (boolean; helper disabled when true)
- `sla_status` (`ok`, `warning`, `overdue`)

### 4.2 Desktop UX
- On Kanban card:
  - Show assignment badge (e.g., “มอบหมายให้ พี่บี”)
  - If current user ≠ assignee:
    - Hide default Start button
    - Show helper/takeover buttons instead

### 4.3 Mobile UX (Phase 2B.6 cards)
- Reuse same payload
- Primary CTA ≠ “Start” when current user is not assignee
- Display warning badge with the assigned operator name
- Provide helper/takeover buttons with the same behavior as desktop

> **Action:** Keep button data-attributes identical (`data-token-id`, `data-node-id`, `data-action`) so handlers remain shared.

---

## 5. Task D — Tests & Audit

### 5.1 Integration Tests
Create `tests/Integration/HatthasilpaAssignmentIntegrationTest.php`:
1. **Assigned user starts → success**
2. **Non-assigned user tries to start → blocked or forced helper/takeover (per policy)**
3. **Auto-assign on first start when no assignment exists**
4. **Takeover flow** updates assignment + logs reason
5. **Helper flow** logs session without changing assignment
6. **Non-assigned user cannot Pause/Complete** another operator’s token
7. **Assigned user pauses/completes successfully** (ensures enforcement beyond Start)
- เสริม: `tests/Integration/HatthasilpaStartJobWorkQueueTest.php` ครอบ flow start_job → token_spawn → work_queue (ต้องรันควบคู่ทุกครั้งที่แตะ start_job)

### 5.2 Audit Document
- File: `docs/dag/02-implementation-status/HATTHASILPA_ASSIGNMENT_INTEGRATION_AUDIT.md`
- Contents:
  - Coverage checklist (API, UI, tests)
  - Proof of test runs (command output)
  - Known limitations (e.g., multi-assignee not supported yet)

> **Completion Criteria:** Audit document signed off + tests green → Roadmap item “Hatthasilpa Assignment Integration Audit” can be marked ✅.

---

## 6. Deliverables Checklist

| Item | Description | Owner | Status |
|------|-------------|-------|--------|
| Spec finalized | Section 2 updated with final business rules | Product/Ops | ⏳ |
| Backend enforcement | `start_token`, helper, takeover flows | Backend | ⏳ |
| API payload | assignment fields exposed to Work Queue | Backend | ⏳ |
| Desktop UI | Kanban respects assignment | Frontend | ⏳ |
| Mobile UI | Phase 2B.6 cards respect assignment | Frontend | ⏳ |
| Integration tests | 5 scenarios implemented | QA/Backend | ⏳ |
| Audit document | `HATTHASILPA_ASSIGNMENT_INTEGRATION_AUDIT.md` | QA/Tech Writer | ⏳ |

---

## 7. Next Steps
1. Review this plan with Ops/Manager stakeholders → confirm policy choice for helper/takeover.
2. Update Section 2 (Business Rules) once policy is locked.
3. Implement Tasks B–D in order; keep Roadmap checklist updated.
4. Only after Audit is ✅, proceed with remaining Phase 2B.6 mobile polish items (Draft indicator, publish dialog, autosave UX, etc.).

---

**References**
- `DAG_IMPLEMENTATION_ROADMAP.md` (Phase 2B.6 section)
- `HATTHASILPA_ASSIGNMENT_INTEGRATION_AUDIT.md` (to be created after implementation)
- `work_queue.js`, `views/work_queue.php`, `dag_token_api.php`
- `manager_assignment` schema, `flow_token_assignment` schema (see Section 3.2)

---

## 8. Guardrails & Implementation Rules (Anti-Spaghetti Rules)

กฎเหล็กเหล่านี้ใช้กับทุกงานที่เกี่ยวกับ Hatthasilpa Assignment (Task B–D) เพื่อป้องกันสปาเก็ตตี้โค้ด และการแก้ไฟล์ใหญ่แล้วพัง

### 8.1 Scope การแก้โค้ด

- โฟกัสเฉพาะไฟล์ที่เกี่ยวข้องกับงานนี้จริง ๆ เช่น
  - `source/dag_token_api.php`
  - `assets/javascripts/pwa_scan/work_queue.js`
  - `views/work_queue.php`
  - ไฟล์ service/helper ใหม่ที่สร้างขึ้น, ไฟล์ test ใหม่ใน `tests/Integration/`
- ห้ามแก้ไขไฟล์ core / infra ต่อไปนี้ เว้นแต่ Roadmap หรือเอกสารจะสั่งชัดเจน:
  - `config.php`, bootstrap หลัก, migration runner ทั่วไป, composer config ฯลฯ
- ถ้าจำเป็นต้องแก้ behavior ในไฟล์ใหญ่ (1,000+ บรรทัด):
  - จำกัดการแก้ไขให้อยู่ใน block เล็ก ๆ เท่าที่จำเป็น
  - ห้าม refactor ทั้งไฟล์ใน patch เดียว
  - ห้าม rename ฟังก์ชัน/คลาสที่ใช้งานกว้าง ๆ เว้นแต่มีเหตุผล และอัปเดต test ครบ

### 8.2 หลักการเขียนโค้ด

- ใช้หลักการ “**เพิ่มชั้นบาง ๆ แทนการแก้ของเดิม**”:
  - ถ้าต้องเพิ่ม assignment logic → ห่อผ่าน `AssignmentService` / helper layer แทนเขียน logic ยาว ๆ กระจายหลายที่
  - พยายามไม่ยัด business rule ใหม่เข้าไปกลางโค้ดที่ซับซ้อนอยู่แล้ว
- ห้ามทำ **search/replace กว้าง ๆ** ที่มีความเสี่ยง เช่น แทนที่ string หรือ pattern ที่อาจไปโดนหลายบริบท
- ใช้ชื่อฟังก์ชัน/เมธอด/ตัวแปรให้ **สะท้อนความหมายตามสเปค** ในเอกสาร เช่น `assignment_method`, `helper_allowed`, `takeover_allowed`, `is_strict_assignment`
- หลีกเลี่ยงการเพิ่ม global state, static ตัวแปรแบบ shared ที่ไม่มีความจำเป็น

### 8.3 Assignment Logic Isolation

- กฎ assignment ทั้งหมด (manager / auto / helper / replace) ควรถูกรวมศูนย์อยู่ใน service / helper เดียว เช่น `AssignmentService`
- ห้าม copy-paste เงื่อนไขซ้ำ ๆ (เช่น `if ($assignment && $assignment->method === 'manager' && ...)`) ไปหลายจุด:
  - ให้ดึงไปทำในฟังก์ชันเดียว เช่น `canUserStartToken($tokenId, $userId)` หรือเมธอดใน `AssignmentService`
- ทุก behavior ที่เกี่ยวกับ assignment ต้องสอดคล้องกับ Section:
  - 2. Task A — Business Rules
  - 3.3 Assignment Resolution Hierarchy

### 8.4 การเปลี่ยนแปลง API และ Payload

- ทุกการเพิ่ม field ใน payload ของ `get_work_queue` หรือ API อื่น ๆ:
  - ต้องอ้างอิงชื่อ field ตาม Section 4.1 เท่านั้น
  - ห้ามเปลี่ยนชื่อ field เดิมที่ Frontend ใช้อยู่แล้ว ยกเว้นเอกสารสั่งชัดเจน
- ถ้าจำเป็นต้องเปลี่ยนรูปแบบ response:
  - เพิ่ม field ใหม่ (backward-compatible) แทนการเปลี่ยนรูปแบบเดิม
  - ระบุการเปลี่ยนแปลงในเอกสาร (เช่น เพิ่ม note ใน HATTHASILPA_ASSIGNMENT_PLAN.md หรือ AUDIT.md)

### 8.5 Tests ก่อน – แก้โค้ดทีหลัง

- ถ้าจะเปลี่ยน behavior ที่มีความเสี่ยง:
  - เขียนหรืออัปเดต **integration test** ก่อน หรืออย่างน้อยใน patch เดียวกัน
- ทุกครั้งที่แก้ assignment behavior:
  - ต้องรันอย่างน้อย:
    - `vendor/bin/phpunit tests/Integration/GraphDraftLayerTest.php`
    - `vendor/bin/phpunit tests/Integration/SubgraphGovernanceTest.php`
    - `vendor/bin/phpunit tests/Integration/HatthasilpaAssignmentIntegrationTest.php` (เมื่อสร้างแล้ว)
- ห้ามลบหรือ comment out tests เพื่อให้ “เขียว” โดยไม่แก้ logic ให้ตรงสเปค

### 8.6 การจัดการกับ Foreign Key / Data Integrity

- ห้ามสร้างตารางใหม่, column ใหม่, หรือ FK ใหม่ โดยพลการนอกเหนือจากที่ระบุใน Roadmap/Spec
- ห้ามแก้ schema ของตาราง core (เช่น `routing_graph`, `routing_node`, `job_graph_instance`) ยกเว้น:
  - มีการเพิ่ม migration ใหม่ที่อธิบายการเปลี่ยนแปลงชัดเจน
  - เอกสาร Roadmap ระบุให้ทำ
- เวลาลบข้อมูลในการทดสอบ:
  - ต้องลบตามลำดับ FK ที่ถูกต้อง (เช่น binding → job_graph_instance → draft → version → edges → nodes → graph)
  - ห้ามใช้ `TRUNCATE` ใส่ production-like tables โดยไม่จำเป็น

### 8.7 Subgraph & Future Compatibility

- การ implement assignment ต้อง:
  - ใช้ Assignment Resolution Hierarchy เดียวกันทั้ง main graph และ subgraph
  - อย่าเขียน logic ที่ผูกกับ `node_type` แบบ hard-coded เฉพาะกรณีเดียว จนทำให้ subgraph หรือ node type ใหม่ใช้ไม่ได้ในอนาคต
- ห้ามเขียนเงื่อนไขที่แตก behavior ของ draft/publish แบบ silent:
  - ถ้า draft mode ผ่อนกฎ → ต้องบันทึกชัดเจนในเอกสาร และ tests ต้องครอบคลุม

### 8.8 ขนาด Patch และรูปแบบการแก้ไข

- แบ่งงานออกเป็น patch เล็ก ๆ ตาม Task:
  - Patch สำหรับ Backend Assignment Enforcement
  - Patch สำหรับ API Payload
  - Patch สำหรับ Desktop UI
  - Patch สำหรับ Mobile UI
  - Patch สำหรับ Tests + Audit
- ในแต่ละ patch:
  - จำกัดการแก้ไขให้โฟกัสที่ scope นั้น ๆ
  - หลีกเลี่ยง “mega patch” ที่แก้ทั้ง backend + frontend + tests + refactor ไฟล์ใหญ่พร้อมกัน ถ้าไม่จำเป็น
- ทุก patch ต้องอ่าน diff แล้วเข้าใจได้ง่ายว่า:
  - “เปลี่ยนอะไร”
  - “เพื่อเป้าหมายอะไรในสเปค”

### 8.9 เอกสารต้อง sync กับโค้ดเสมอ

- ทุกครั้งที่ behavior เปลี่ยนจากที่สเปคเดิมเขียนไว้:
  - อัปเดต `HATTHASILPA_ASSIGNMENT_PLAN.md` ให้ตรงกับ implementation ล่าสุด
  - อัปเดต `HATTHASILPA_ASSIGNMENT_INTEGRATION_AUDIT.md` (เมื่อสร้างแล้ว) ด้วยผลการทดสอบจริง
- ห้ามเปลี่ยน behavior เงียบ ๆ โดยไม่อัปเดตเอกสาร

---

## 9. Hatthasilpa Job Start Flow (Blocking Tasks Before Phase 2B.6)

งานฝั่ง Hatthasilpa Job Start ต้องเรียงตามลำดับ B.1 → B.2 → B.3 เพื่อให้ Work Queue เห็น token พร้อม assignment (และไม่หลุด guardrails)

### Task B.1 – Audit ปุ่ม Start ของ `hatthasilpa_jobs`
- ตรวจ flow ปัจจุบันว่าเมื่อกด Start (`source/hatthasilpa_jobs_api.php`, action `start_job`):
  - `job_ticket.status` ถูกอัปเดตเป็น `in_progress` พร้อม `started_at`
  - มี `job_graph_instance` ผูกกับ ticket
  - **แต่ปัจจุบัน** (Dec 2025) เรียก `TokenLifecycleService::spawnTokens()` ภายในตัวเอง → AssignmentEngine ไม่ถูกเรียก
- ต้องแก้ให้หลัง transaction เสร็จเรียก `dag_token_api.php?action=token_spawn&ticket_id=...` (พร้อม HTTP idempotency key) แทนการ spawn เอง และลบโค้ด spawn/serial link ที่ซ้ำซ้อน
- ห้าม insert `flow_token` / `node_instance` ภายใน `start_job` ตรง ๆ (ย้ายไปใช้ API กลางเพื่อให้ Assignment hooks ทำงาน)
- Implementation (Dec 2025):
  - `hatthasilpa_jobs_api.php` ใส่ guardrail header + helper `internalDagTokenPost()`
  - `handleStartJob()` อัปเดตสถานะแล้วเรียก `dag_token_api?action=token_spawn` ผ่าน HTTP (fallback CLI สำหรับ PHPUnit)
  - จำเป็นต้องส่ง `X-Internal-Request` + `Idempotency-Key` ทุกครั้งและ reuse helper นี้เสมอ

### Task B.2 – Hook Assignment หลัง Spawn
- หลัง `handleTokenSpawn()` ได้ `$tokenIds` ต้องเรียก:
  ```php
  AssignmentEngine::autoAssignOnSpawn($db->getTenantDb(), $tokenIds);
  ```
- AssignmentEngine ต้อง:
  - อ่าน `manager_assignment` ที่โดน plan ไว้
  - สร้าง `token_assignment` ให้ทุก token (ตาม plan ถ้ามี, ไม่งั้น auto)
  - ทำงานแบบ transaction-safe และมีเทสต์ครอบ
- **สถานะปัจจุบัน:** Hook นี้อยู่ใน `dag_token_api.php?action=token_spawn` แล้ว → เมื่อ Task B.1 เปลี่ยนให้ใช้ API นี้, AssignmentEngine จะถูกเรียกอัตโนมัติ (ไม่ต้องเขียนซ้ำ)
- Soft mode (Dec 2025): ถ้าไม่พบ plan สำหรับ instance+node → log `[hatthasilpa_assignment] No pre-assignment ... (soft mode - skip auto-assign)` และไม่โยน error (token ยัง spawn + มองเห็นใน Work Queue)
- TokenLifecycleService constructor รับ `$tenantCode` แล้วเพื่อให้ AssignmentResolver cache-aware; ใครเรียก service นี้โดยตรงต้องส่งต่อ tenant code

### Task B.3 – Verify End-to-End
- ขั้นตอนเทสต์ (ต้องบันทึกผล):
  1. สร้าง job ใหม่ใน `hatthasilpa_jobs`
  2. วาง `manager_assignment` ให้ operator A
  3. กด Start Job แล้วตรวจ:
     - `flow_token` มี token ครบตาม `target_qty`
     - `token_assignment` มี row ผูกกับ token ที่ spawn
     - `GET /source/dag_token_api.php?action=get_work_queue` แสดง node/token ที่คาดไว้
- ถ้าขั้นตอนไหนไม่ผ่าน → หยุดและไล่จาก Task B.1/B.2 ทันที (ดู `hatthasilpa_jobs_api.php` บรรทัด ~560–750 เพื่อเทียบกับสเปก)
- Integration test `tests/Integration/HatthasilpaStartJobWorkQueueTest.php` ครอบ flow นี้: start_job → spawn (ผ่าน dag_token_api) → `get_work_queue` เห็น token

> 🔥 **Root Cause Recap (Dec 2025):**
> - `start_job` ไม่เรียก `dag_token_api?action=token_spawn` → assignment engine ไม่ทำงาน
> - Work Queue require `token_assignment` (`ta.id_assignment IS NOT NULL`) จึงไม่เห็น token แม้ spawn แล้ว
> - ต้องปรับ flow ตาม Task B.1 ก่อน Phase 2B.6 ถึงจะไปต่อได้

### Implementation Spec (อ้างอิงเต็ม)

```
/**
 * ============================================================================
 * HATTHASILPA JOB START FLOW – IMPLEMENTATION SPEC (FOR DEVELOPERS & AI AGENT)
 * ============================================================================
 *
 * เป้าหมาย:
 * - เมื่อกดปุ่ม "Start Job" จากหน้า hatthasilpa_jobs → ต้องได้ทั้ง:
 *   1) job_ticket.status = 'in_progress'
 *   2) มี job_graph_instance + flow_token ครบตาม target_qty
 *   3) token ถูก assign ตาม manager_assignment (ผ่าน AssignmentEngine)
 *   4) token ปรากฏใน Work Queue (dag_token_api?action=get_work_queue)
 *
 * กฎเหล็ก:
 * - ห้าม duplicate logic จาก dag_token_api.php (โดยเฉพาะส่วน spawn token)
 * - ถ้าต้อง spawn token ให้เรียกผ่าน dag_token_api?action=token_spawn เสมอ
 * - ห้ามแก้ dag_token_api.php ให้แตกต่างจาก guardrails ที่หัวไฟล์
 * - ทุกการเปลี่ยน state ของ job/token ต้องอยู่ใน transaction
 *
 * --------------------------------------------------------------------------
 * A) FLOW ระดับสูง (High-level Flow)
 * --------------------------------------------------------------------------
 *
 * เมื่อผู้ใช้กด "Start Job" บนหน้า hatthasilpa_jobs:
 *
 * 1) Backend รับ request: action=start_job, ticket_id = {id ของงาน}
 * 2) ภายใน handler start_job:
 *    - ตรวจสิทธิ์ (permission): hatthasilpa.job.manage (หรือเทียบเท่า)
 *    - โหลด job_ticket โดยใช้ ticket_id
 *    - ถ้าไม่เจอ → return error 404
 *    - ถ้า status == 'completed' หรือ 'cancelled' → return error (ห้าม start)
 *
 * 3) ถ้า job ยังไม่เคย start:
 *    - BEGIN TRANSACTION
 *    - UPDATE job_ticket:
 *         - status      = 'in_progress'
 *         - started_at  = NOW() (ถ้ายังเป็น NULL)
 *    - ถ้ายังไม่มี job_graph_instance:
 *         - สร้าง row ใน job_graph_instance ให้ใช้ routing_graph ที่ถูกต้อง
 *           (อาจอ้างอิงจาก graph ที่ pin ไว้ใน job_ticket, ไม่ใช่เลือกล่าสุดสุ่ม ๆ)
 *    - COMMIT
 *
 * 4) หลัง COMMIT ขั้นตอน start job เสร็จ:
 *    - เรียก spawn token ผ่าน dag_token_api:
 *
 *      ตัวเลือกที่แนะนำ:
 *      - ให้ frontend ยิง HTTP POST ไปที่:
 *          /source/dag_token_api.php?action=token_spawn
 *        พร้อมส่ง:
 *          - ticket_id = {id_job_ticket}
 *        และ header:
 *          HTTP_IDEMPOTENCY_KEY = ค่า random/UUID (กัน double-click)
 *
 *      NOTE:
 *      - ไม่ควร include dag_token_api.php แล้วเรียกฟังก์ชันภายในตรง ๆ
 *        เพราะไฟล์นั้นใช้ json_success/json_error + exit; เป็น flow หลัก
 *        และมี guardrails + side-effect เยอะอยู่แล้ว
 *
 * 5) dag_token_api?action=token_spawn จะจัดการให้:
 *    - สร้าง node_instance ตาม routing_graph
 *    - REUSE serial จาก job_ticket_serial
 *    - spawn flow_token ตาม target_qty
 *    - auto-route token ที่อยู่บน START node ไปยัง node ถัดไป
 *    - เรียก AssignmentEngine::autoAssignOnSpawn(...) ให้ auto assign
 *
 * 6) เมื่อเสร็จข้อ 5 → token ที่ spawn แล้ว + มี token_assignment
 *    จะถูกแสดงใน Work Queue โดย handleGetWorkQueue()
 *
 * --------------------------------------------------------------------------
 * B) เงื่อนไขที่ต้อง “พร้อม” เพื่อให้ Work Queue เห็น token
 * --------------------------------------------------------------------------
 *
 * Work Queue จะดึงข้อมูลผ่าน SQL ระดับสูง:
 *   FROM flow_token t
 *   LEFT JOIN token_assignment ta ON ta.id_token = t.id_token
 *     AND ta.status IN ('assigned','accepted','started','paused')
 *   WHERE t.status IN ('ready','active','waiting','paused')
 *     AND ta.id_assignment IS NOT NULL
 *     AND n.node_type IN ('operation','qc')
 *     AND job_ticket.status = 'in_progress'
 * ดังนั้นหลัง Start + Spawn ต้องตรวจให้ครบตามตารางด้านบน
 *
 * --------------------------------------------------------------------------
 * C) CHECKLIST สำหรับ Implement start_job (Backend)
 * --------------------------------------------------------------------------
 *
 * [ ] Permission check (hatthasilpa.job.manage)
 * [ ] Validate ticket_id, forbid completed/cancelled jobs
 * [ ] Transaction: update job_ticket + create job_graph_instance (ถ้ายังไม่มี)
 * [ ] หลัง commit → เรียก POST dag_token_api?action=token_spawn (พร้อม idempotency key)
 * [ ] ห้าม insert flow_token/node_instance เองใน start_job
 * [ ] หลังเสร็จรัน PHPUnit:
 *       - GraphDraftLayerTest.php
 *       - SubgraphGovernanceTest.php
 *       - HatthasilpaAssignmentIntegrationTest.php
 *
 * --------------------------------------------------------------------------
 * D) QUICK MANUAL VERIFY (เวลาเทสบนหน้าเว็บ)
 * --------------------------------------------------------------------------
 *
 * 1) สร้างงานใหม่ (ATELIER-XXXX-YYYY)
 * 2) วาง manager_assignment ให้ operator A
 * 3) กด Start Job → ตรวจ DB:
 *      - job_ticket.status = 'in_progress'
 *      - job_graph_instance มี row
 *      - flow_token ครบ target_qty
 *      - token_assignment ถูกสร้าง
 * 4) เปิด Work Queue → ต้องเห็น token ของงานนี้ใน node operation/qc
 *
 * ถ้าขั้นตอนใดไม่ผ่าน → หยุดและเทียบกับ checklist ด้านบน
 * ============================================================================
 */
```

