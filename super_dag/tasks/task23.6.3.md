

# Task 23.6.3 — Finalize MO Page Integration & Close Phase 23 (MO Lifecycle v1)

## 🎯 Objective
ปิดเฟส MO ให้เรียบร้อยทั้งหมด โดยไม่เหลืองานค้าง และเชื่อมทุกส่วนเข้ากับระบบจริง (ETA, Simulation, MOCreateAssist, Routing Binding, Job Ticket Integration)

---

## ✅ Scope

### 1. UI Completion
- แสดงปุ่มให้ครบตามสถานะ:
  - Draft → Plan
  - Planned → Edit, Cancel
  - Running → Pause, Cancel
  - Paused → Resume, Cancel
  - Completed → View Only
  - Cancelled → Restore
- ปรับ Layout ให้ชัดเจนขึ้น (Action Buttons, ETA Card, Product Info)

---

### 2. MO Edit Modal (Final Spec)
- ใช้ข้อมูลจาก Product → Template → Routing (แบบ 1:1)
- ไม่มี UoM ให้เลือก (ซ่อนจาก UI)
- ไม่มี Production Template ให้เลือก (ลบออก)
- Fields ที่แก้ไขได้:
  - Quantity
  - Scheduled Start Date
  - Notes

---

### 3. MOCreateAssist Integration (Final)
- Preview section:
  - ETA Preview (best / normal / worst)
  - Routing Stats
  - Node Sequence
- Simulation preview:
  - Workload distribution
  - Queue model

---

### 4. ETA/Simulation Lifecycle Hooks
- Plan → computePreviewETA()
- Update → invalidate + recompute (best-effort)
- Cancel → invalidate
- Complete → finalize health log

---

### 5. Job Ticket Integration
- MO Plan → Generate Job Ticket
- MO Page: ใส่ปุ่ม “Open Job Ticket”
- Job Ticket Page:
  - เปิดดู DAG
  - ดู timeline
  - ดู logs

---

### 6. Clean Up Legacy Elements
- Production Template → Removed
- UoM selection → Hidden (auto-fixed as “piece”)
- Legacy query cleanup:
  - Replace `mo_qty` → `qty`
  - Replace `id_product_template` → removed

---

### 7. Acceptance Criteria
- ผู้ใช้สามารถสร้างงานได้โดยไม่สับสน
- MO → Job Ticket → Node Execution ทำงานครบสมบูรณ์
- ETA แสดงเสถียรทุกสถานะ
- UI ไม่ล่ม ไม่ missing button
- Codebase ไม่มี leftover legacy fields

---

## 🧪 QA Checklist
- Create MO (Draft) ✔
- Plan MO → Job Ticket Created ✔
- Edit MO (qty, date) ✔
- Cancel MO → Restore ✔
- Pause / Resume flow ✔
- ETA preview correct ✔
- Cache invalidation works ✔

---


## 📌 Conclusion
Task 23.6.3 คือ “จุดปิดเฟส MO Lifecycle v1”  
หลังจากนี้เราจะย้ายเข้าสู่ Phase 24: Job Ticket v2 อย่างเป็นทางการ

---

## 🛠 Developer Prompt (for AI Agent)

```text
You are updating the MO page and related services to fully complete Phase 23 (MO Lifecycle v1).  
Follow these instructions carefully. Do NOT change any unrelated modules.

### 0. General Rules

- Respect the current architecture and naming conventions.
- Do NOT re-introduce UoM or Production Template selection into the UI.
- Product = Template = Routing Graph (1:1) for this phase.
- MO page must remain simple and close-system oriented.
- Keep all ETA / Simulation / Health behaviors NON-BLOCKING (no hard failure for MO actions).

---

### 1. MO List Page UI (views/mo.php or equivalent)

1. Ensure the MO table/list shows:
   - MO Code / ID
   - Product name (and product code)
   - Quantity
   - Status
   - Planned dates (scheduled_start / due date)
   - ETA summary (if available)
   - Action buttons column

2. Implement action buttons per status (server + JS):

   - **Draft**
     - Show: `Plan` (primary), `Edit`, `Delete` (optional)
     - `Plan` → calls `mo.php?action=plan&id=...`
     - `Edit` → opens Edit Modal (see Section 2)

   - **Planned**
     - Show: `Edit`, `Cancel`, `Open Job Ticket`
     - `Edit` → Edit Modal
     - `Cancel` → `mo.php?action=cancel&id=...`
     - `Open Job Ticket` → link to Job Ticket page (if job_ticket_id is available)

   - **Running**
     - Show: `Pause`, `Cancel`, `Open Job Ticket`
     - `Pause` → calls the existing token/job control API (if any), or a placeholder for now
     - `Cancel` → allowed only if business logic permits. Otherwise, hide or disable with tooltip.
     - `Open Job Ticket` → as above

   - **Paused**
     - Show: `Resume`, `Cancel`, `Open Job Ticket`
     - `Resume` → resume token/job execution (or placeholder)
     - `Cancel` → same rule as Running
     - `Open Job Ticket` → as above

   - **Completed**
     - Show: `View`, `Open Job Ticket`
     - No destructive actions
     - `View` → open read-only detail modal or route to MO detail page

   - **Cancelled**
     - Show: `Restore`
     - `Restore` → `mo.php?action=restore&id=...` (must revert status to the previous valid state)
     - Do NOT auto-regenerate Job Tickets here; just restore MO status according to existing rules.

3. Layout:
   - Keep the MO list clean and readable.
   - Group action buttons for each row in a compact button group (e.g., Bootstrap btn-group).
   - Ensure the Action column does not wrap badly (use small buttons / icons if needed).

---

### 2. MO Edit Modal (Create + Edit)

1. **Create Modal**
   - Fields:
     - Product (select) — from active products only.
     - Quantity (required, integer > 0).
     - Scheduled Start Date (optional).
     - Due Date (optional).
     - Notes (optional).

   - Behavior:
     - On Product change:
       - Call `mo_assist_api.php?action=suggest&id_product=...`
       - System resolves routing binding internally (no template selection in UI).
       - If no routing is configured for this product, show a warning and disable the Save button.
     - Show a small “Routing Info” block:
       - e.g., “Routing: {routing_name} (graph #{id})”
       - Read-only, informational only.

   - UoM:
     - Do NOT include any UoM field in the modal.
     - Backend will auto-resolve UoM as “piece” or from product.default_uom_code.

2. **Edit Modal**
   - Can only be opened for statuses: Draft, Planned.
   - Fields editable:
     - Quantity
     - Scheduled Start Date
     - Notes
   - Product should be shown as read-only (no product change allowed at this stage for v1).
   - On Save:
     - Calls `mo.php?action=update&id=...` (use the existing handleUpdate() added in 23.6)
     - Backend:
       - Detect ETA-sensitive field changes (qty, dates).
       - Invalidate ETA cache via `MOEtaCacheService::invalidateForMo()`.
       - Best-effort recompute ETA (do not block MO update if ETA fails).

3. Validation:
   - Ensure quantity > 0.
   - If any required field is missing, block Save and show inline errors.
   - Display backend error messages in a user-friendly alert area within the modal.

---

### 3. MO–ETA–Simulation Integration

1. Planning:
   - When `mo.php?action=plan` is called and MO transitions Draft → Planned:
     - Ensure `MOCreateAssistService::buildCreatePreview()` and/or `MOLoadEtaService::computeETAForPreview()` are used (if already wired in previous tasks).
     - Ensure this step triggers ETA compute and cache fill through `MOEtaCacheService::getOrCompute()`.

2. Update:
   - As already done in Task 23.6, double-check:
     - `handleUpdate()` invalidates ETA cache when ETA-sensitive fields change.
     - ETA recomputation is wrapped in try/catch and never blocks MO update.
     - Health hooks (`MOEtaHealthService::onMoUpdated()`) are called.

3. Cancel:
   - When `mo.php?action=cancel` is called:
     - Invalidate ETA cache for that MO.
     - Call `MOEtaHealthService::logMoCancelled($moId)` if available.
     - Make sure status transitions are correct and consistent with legacy behavior.

4. Complete:
   - When MO is effectively completed (depends on how your system defines MO completion, usually via Job Ticket / tokens):
     - Ensure `TokenLifecycleService::onTokenCompleted()` now routes to `MOEtaHealthService` hooks properly.
     - Verify that final ETA / actual duration comparison is logged (if implemented in previous tasks).

---

### 4. Job Ticket Integration

1. MO Plan → Job Ticket:
   - Confirm that when MO is planned, Job Tickets are generated using the legacy or new job ticket generator.
   - Ensure MO record stores a reference (`job_ticket_id` or similar) if available.

2. MO Page:
   - For any MO with an attached Job Ticket:
     - Show an `Open Job Ticket` button.
     - Link to the existing Job Ticket page, passing the correct ID.

3. Job Ticket Page:
   - Ensure that for a given Job Ticket:
     - DAG view is accessible.
     - Token timeline / logs can be inspected (using existing dev tools or production views).
   - No heavy refactor needed here in this task; just ensure the navigation from MO works.

---

### 5. Clean Up Legacy Elements (Code & UI)

1. Remove Production Template from UI:
   - Delete or comment out any `<select>` or UI blocks that let the user pick “Production Template”.
   - Replace them with a simple read-only “Routing Info” block as described above.
   - Ensure backend no longer expects `id_product_template` from the form.

2. Hide UoM Completely from UI:
   - Remove any UoM dropdown / text input from:
     - MO create modal
     - MO edit modal
     - MO list display (unless it is purely textual like “Qty (pcs)”).
   - Confirm backend uses a default or product-level UoM.

3. Legacy Field Cleanup:
   - In SQL queries, DTOs, and PHP arrays related to MO:
     - Replace any usage of `mo_qty` with `qty` (as already standardized).
     - Remove `id_product_template` references.
   - Make sure all changes are consistent and do not break existing code paths.

---

### 6. QA & Smoke Tests

After code changes:

1. Run basic PHP syntax checks for modified files.
2. Manually test via browser:
   - Create MO (Draft) → Plan → Verify Job Ticket.
   - Edit MO (Planned) → qty and dates change → verify ETA cache invalidates and recomputes without errors.
   - Cancel MO → verify status and buttons update.
   - Restore Cancelled MO → verify it returns to the correct previous status and UI actions update.
   - Pause / Resume (if wired) → buttons update correctly.
3. Verify no UoM or Production Template selection is shown anywhere on the MO page.
4. Check browser console for JS errors and PHP error logs for runtime warnings/notices.

If any inconsistency is found, fix it while staying within this task’s scope (MO page, MO API, ETA/Health hooks, and related UI only).
```
