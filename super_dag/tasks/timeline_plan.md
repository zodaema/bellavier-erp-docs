# SuperDAG / BGERP — Timeline Plan (Expanded Master Reference)

> **Purpose:** Provide a stable, authoritative, non‑drifting project roadmap.  
> This file is the *source of truth* for all phases and future development.

---

# PHASE 19 — Lean-Up (Completed)
Status: **100% Complete**

- 19.24.1 — Safety Markers  
- 19.24.2 — Remove Legacy Validation  
- 19.24.3 — API Slimming  
- 19.24.4 — JS Slimming (Unreachable Code)  
- 19.24.5 — Remove Debug Logs  
- 19.24.6 — (Merged)  
- 19.24.7 — Validate saveState()  
- 19.24.8 — Grouped History Actions  
- 19.24.9 — Normalize HistoryManager  
- 19.24.10 — Minimal Snapshot Format  
- 19.24.11 — Action Grouping Improvements  
- 19.24.12 — Remove Legacy Snapshot Format  
- 19.24.13 — IO / Action Layer Extraction  
- 19.24.14 — Node/Edge Update Refactor  
- 19.24.15 — Dead Code Removal  
- 19.24.16 — Normalize Module Structure  
- 19.24.17 — Final Consolidation

**Outcome:**  
Editor is clean, modular, maintainable, and ready for higher‑level engines.

---


# PHASE 20 — Time / SLA Engine (In Progress)
Status: **Focused on 20.1–20.3 in this cycle**


## 20.1 — ETA Engine (Phase 1) ✔
- Core ETA computation engine  
- SLA comparison: ON_TRACK, AT_RISK, BREACHING  
- API + design-time preview

## 20.2.1 — Timezone Audit ✔
- Full system scan for time usage  
- Identified all risky patterns (`strtotime`, `NOW()`, `date`)  
- Migration plan generated

## 20.2.2 — Token Lifecycle Migration ✔
- TokenLifecycleService uses TimeHelper 100%  
- Start/Pause/Resume/Complete normalized  
- All timestamps canonical

## 20.2.3 — DAG Routing Time Migration ✔
- Normalize routing wait/timeout calculations  
- Normalize graph save/publish/snapshot timestamps  
- Normalize work-session timer calculations  
- Replace all direct `time()/date()/NOW()` usage with TimeHelper in routing layer

## 20.3 — Worker App: Token Execution Engine (Completed)
- Phase 1 — Token Execution Core  
  - Start / Pause / Resume / Complete logic  
  - Sync with TokenWorkSessionService  
  - TimeHelper-normalized timestamps

- Phase 2 — Queue Consumption Layer  
  - Pull next token  
  - Station assignment logic  
  - SLA/ETA inline preview

- Phase 3 — Execution Stability + Error Handling  
  - Auto-retry sync  
  - Offline-safe event queue  
  - Conflict resolution (double-start / stale pause)

**Status:** 100% Complete  
(Task 20.3 ถูกยุบรวมและทำเสร็จแล้ว)

## 20.4 — SLA Definition Panel UI (pending)
- SLA per node  
- SLA template groups  
- UI for editing SLA parameters

## 20.5 — Node SLA Integration (pending)
- Node type → SLA auto-fill  
- Preview ETA risk  
- SLA tied to skill/team

## 20.6 — ETA Prediction Improvements (pending)
- Learning model from artisan performance  
- Queue congestion factor  
- QC failure probability

---

# PHASE 21 — Node Behavior Engine (Completed)

Phase 21 was replaced by Canonical Event Engine & Behavior Engine (Tasks 21.1–21.8, completed).

---

# PHASE 22 — Canonical Self‑Healing & Timeline Engine

## 22.1 Canonical Event Engine Core (Completed)

## 22.2 TokenEventService & TimeEventReader (Completed)

## 22.3 Local Self‑Healing Layer (Completed)

## 22.3.1–22.3.6 (Completed)

## 22.4 Orchestrator Layer (Completed)

## 22.5 Reconstruction Engine (Completed)

## 22.6 Test Suite & Dev Tools (Completed)

## 22.7 Integration with TokenLifecycleService (Completed)

---

# PHASE 23 — MO / Production Management (Active Phase)

## Overview
Phase 23 focuses on establishing a stable MO planning layer tightly integrated with the canonical timeline engine.  
MO remains a planning layer, while Job Ticket continues as the execution layer.  
This phase does **not** modify Job Ticket execution logic — only adds planning intelligence.

---

## 23.1 — MOCreateAssistService ✔
Backend assistance tools for selecting routing, validating compatibility, building previews.

## 23.2 — Enhanced Routing Assignment ✔
Cross-routing validation, historic-duration lookup, canonical-duration support.

## 23.3 — Workload Simulation Engine ✔
Station-based timeline simulation, sequential station queue, risk factor analysis.

## 23.4 — MO-level ETA Engine (Completed)
23.4.x deliverables:
- 23.4.1 — ETA Engine v2 (Sequential Queue Model)
- 23.4.2 — ETA Audit Engine
- 23.4.3 — ETA Monitor Dashboard
- 23.4.4 — ETA Cache Engine
- 23.4.5 — Engine Version Binding + Signature Integrity
- 23.4.6 — Health Engine + Cron + Log Store

## 23.5 — MO Lifecycle Integration (Active)
- Hook MO create/update → trigger ETA compute/cache.
- Hook TokenLifecycleService → update drift metrics + ETA health.
- Status-based ETA invalidation.
- Monitoring hooks (non-blocking).

## 23.6 — MO UI Extensions (Upcoming)
- Show ETA per stage.
- Risk factor indicators.
- Timeline per node/station.
- Health summary embedding.

## 23.7 — MO Export / Reporting (Upcoming)
- PDF  
- Excel  
- Manager summary pack  
- Integration hooks

---

# Execution Alignment (New Section)

MO and Job Ticket remain separate layers:

- **MO = Planning Layer**
  ETA, workload simulation, routing checks, risk modeling.

- **Job Ticket = Execution Layer**
  Canonical events, Node Behavior Engine, token lifecycle, real‑time production.

Phase 23 integrates planning → execution **non‑destructively**, without altering existing execution logic.

---

# Sequencing Rule (New)
After Phase 23 completes:

1. **Phase 24 — QC / Inspection**
2. Phase 25 — People / Skill Engine
3. Phase 26 — Inventory / BOM Integration
4. Phase 27 — AI Shopfloor Engine

Node Behavior fine‑tuning per-node occurs **after** production data stabilizes.

---

# PHASE 24 — Job Ticket / Execution Sync (Next Phase)

## Purpose
Establish a modernized execution layer that synchronizes Job Ticket (legacy) with the Canonical Engine and MO Engine. No AI, no People Engine, no Skill Engine — focus strictly on **core factory execution**.

## 24.1 — Job Ticket ETA Integration
- Show ETA per node/stage on Job Ticket.
- Show delay/risk flags extracted from MO ETA + canonical drift.
- Backward-compatible with legacy job_ticket table.

## 24.2 — Execution Timeline Panel
- Real-time timeline (canonical sessions) displayed in Job Ticket.
- Per-node duration breakdown.
- Pause/Resume history view.

## 24.3 — Station Load View (Basic)
- Total active tokens per station.
- Simple color-coded load indicator.
- No auto-assignment.

## 24.4 — Job Ticket → MO Sync
- Update MO progress from Job Ticket state.
- Update MO ETA drift based on actual canonical durations.
- Non-blocking.

## 24.5 — Minimal Dispatch Helper (Optional)
- Button “Pull Next Job” using simple FIFO.
- No prediction, no optimization.

---

# PHASE 25 — Product / Routing Stabilization

## Purpose
Finalize product–graph–routing ecosystem so production can run stably without manual interventions.

## 25.1 — Product Binding UX Refresh
- Stable binding UI.
- Graph versioning visible.
- Prevent broken routing assignments.

## 25.2 — Routing Validation Layer
- Validate graph before publish.
- Detect missing work centers, missing edges, cycles.
- Prevent invalid template from being bound to a product.

## 25.3 — Node Parameter Framework
- Node-level configuration (time defaults, QC flag, batching flag).
- No AI adjustments.

## 25.4 — Node Behavior Per-Node Fine Tuning
- Calibrate node behaviors using canonical durations.
- Tune work_centers one by one.
- Build baseline time per node.

---

# PHASE 26 — Inventory / Material Layer (Modernized Core Only)

## Purpose
Upgrade minimal inventory foundation necessary for real production:

- No AI
- No forecasting
- No supplier automation

Core only.

## 26.1 — Material Definition & UOM Cleanup
- Normalize materials table.
- Fix UOM inconsistencies.

## 26.2 — MO Material Requirement (Basic BOM)
- BOM v1: static quantity per product.
- Auto-calc material usage per MO.

## 26.3 — Material Consumption via Job Ticket
- Deduct stock when Job Ticket reaches completion.
- Log consumption per station/node.

## 26.4 — Stock Ledger v1
- IN / OUT history.
- Cycle count support.

---

# PHASE 27 — Stabilization Cycle

## Purpose
After Canonical Engine + MO Engine + Execution Sync + Routing + Inventory are connected, this phase ensures stability before any further expansion.

## 27.1 — Canonical/ETA Stability Audit
- Multi-week stability checks.
- Fix drift or anomalies.

## 27.2 — Execution Flow Hardening
- Fix edge cases in Start/Pause/Resume/Complete.
- Prevent double-token issues.

## 27.3 — Routing/Node Behavior Refinement
- Re-calibrate nodes once enough production data is collected.

## 27.4 — Inventory Accuracy Review
- Compare theoretical usage vs actual usage.

---

# PHASE 28 — (Reserved for Future Planning)

This phase intentionally left blank. Will only be defined **after**:
- Job Ticket modernized
- Product+Routing stable
- Inventory core running
- Node behavior tuned
- Canonical + ETA stable for at least one production cycle

No AI, no People/Skill Engine, no QC system are planned until the foundation is complete.

## PROJECT ROADMAP (Pinned Reference)
This section is appended to ensure long-term memory consistency across all phases of Bellavier Group ERP development.  
This roadmap does NOT replace the detailed phase plans above — it acts as a fixed, high‑level reference to prevent loss of direction when tasks become complex.

---

### PHASE 24 — Job Ticket / Execution Sync (Current Focus)
Purpose: Modernize execution flow for Classic line only, keeping Hatthasilpa timeline isolated.

Key Milestones:
- Classic-only canonical time separation
- ETA integration into Job Ticket
- Execution timeline panel + session view
- Station load indicators
- Sync MO progress from Job Ticket
- FIFO dispatch helper (optional)

---

### PHASE 25 — Product / Routing Stabilization
Purpose: Lock down all foundations around Product ↔ Routing graph.

Key Milestones:
- Product binding UI refresh
- Routing validation layer (prevent broken graphs)
- Node parameter framework
- Node behavior calibration per node

---

### PHASE 26 — Inventory / Material Layer (Minimal Core)
Purpose: Enable real production with correct stock usage.

Key Milestones:
- Material definition + UOM cleanup
- Basic BOM (static per product)
- Material consumption at Job Ticket completion
- Stock ledger with IN/OUT and cycle count

---

### PHASE 27 — Stabilization Cycle
Purpose: Ensure reliability before any advanced or optional modules.

Key Milestones:
- Canonical / ETA stability audit
- Execution flow hardening
- Routing refinement based on real data
- Inventory accuracy review

---

### PHASE 28 — Reserved (Locked)
Purpose: Prevent scope creep.  
No AI, People Engine, Skill Engine, QC Automation, or advanced features until phases 24–27 are stable and deployed.

---

### NOTES
- Product = Template = Version until Product Module rewrite in Phase 25.
- Classic timelines must not mix with Hatthasilpa timelines.
- MO is Classic only; Hatthasilpa jobs are created elsewhere.
- UOM is backend-only; no visibility to end users.
- Follow strict Close System principles: High flexibility in usage, strict immovable logic.

This Roadmap section should remain pinned in this file and appended to future versions.

---

# IMPORTANT NOTE
Roadmap Stability Rules (v2)
- Existing phase numbers (19, 20, 21, …) are **frozen** and must not be changed.
- Existing task IDs (e.g. 19.24.3, 20.2.2) are **historical records** and must not be renumbered or deleted.
- If a task needs to be adjusted, add a follow-up task (e.g. 20.2.3.1) instead of editing history.
- New tasks must be appended under the appropriate phase without changing previous items.

**This document prevents task drift during deep development.**
