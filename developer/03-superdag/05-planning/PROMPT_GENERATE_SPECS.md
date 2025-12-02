You are an AI Agent running inside the Bellavier Group ERP monorepo.

## CONTEXT

- This repo implements Bellavier Group ERP, with a strong focus on:
  - Hatthasilpa line (hand-craft, token + time engine + DAG)
  - Classic/PWA line (scan based)
  - Super DAG: /docs/super_dag and related specs

- The core “reality” scenarios of the atelier/factory have been written in:
  - docs/super_dag/REALITY_EVENT_IN_HOUSE.md  ← THIS IS YOUR PRIMARY INPUT

- Other important documents you may reference (READ, but DO NOT REWRITE unless explicitly asked later):
  - docs/super_dag/DAG_IMPLEMENTATION_GUIDE.md
  - docs/super_dag/task_index.md
  - docs/bootstrap/Task/*.md
  - docs/performance/*.md
  - docs/developer/*.md

Your job now is **documentation only**.  
You MUST NOT change PHP/JS/SQL code.  
You MUST NOT alter business rules; you may only clarify and structure what is already implied by the existing docs + REALITY_EVENT_IN_HOUSE.md.

We are entering the **“Blueprint → Implementation Tasks”** phase.

---

## HIGH LEVEL GOAL

1. Take all events & realities described in `REALITY_EVENT_IN_HOUSE.md`
2. Expand them into **clean, dense, implementation-ready specs** for each major domain:
   - Work Center Behavior
   - Token Engine
   - Time Engine
   - Component Serial Binding
   - QC System
   - PWA Classic Scan Flow
   - Leather Stock Reality / Leather Steward
3. For each domain, create a **single, tightly written spec file** under `/docs/super_dag/` that:
   - Keeps names consistent with existing system (Hatthasilpa, Classic, work_queue, MO, job_ticket, token, etc.)
   - Maps “real events in factory” → “which screen” → “which data model” → “what the system must do”
   - Ends with a **Task Roadmap section** (ordered, numbered tasks) that can later be turned into taskX.md files.

The human developer must be able to:
- Read the spec quickly
- Understand the system behavior
- See exactly what should be implemented first / later
- Not get lost in narrative or duplicated content

---

## FILES YOU MUST CREATE

Create the following new spec files **and fully populate them**:

1. `docs/super_dag/SPEC_WORK_CENTER_BEHAVIOR.md`
2. `docs/super_dag/SPEC_TOKEN_ENGINE.md`
3. `docs/super_dag/SPEC_TIME_ENGINE.md`
4. `docs/super_dag/SPEC_COMPONENT_SERIAL_BINDING.md`
5. `docs/super_dag/SPEC_QC_SYSTEM.md`
6. `docs/super_dag/SPEC_PWA_CLASSIC_FLOW.md`
7. `docs/super_dag/SPEC_LEATHER_STOCK_REALITY.md`
8. `docs/super_dag/SPEC_IMPLEMENTATION_ROADMAP.md`  ← master ordering across all domains

DO NOT create more files than this.  
If you need sub-sections, use headings inside these files, not more .md files.

---

## GLOBAL STYLE & STRUCTURE RULES

For **every** SPEC_*.md file, follow this structure:

1. `# Title`  
   Short, technical, no marketing. Example: `# Work Center Behavior Spec`

2. `## Purpose & Scope`  
   - 3–7 bullet points max.
   - Answer: “What problem does this spec solve?” and “What is out of scope?”

3. `## Key Concepts & Definitions`  
   - Define the main terms in this spec ONLY (do not redefine things already defined elsewhere unless necessary).
   - Use bullet list: `- Term: definition`.

4. `## Data Model`  
   - Tables, fields, enums, relationships.
   - If schema already exists → reference it and only add constraints / semantics.
   - If new schema needed → propose table + fields in a compact markdown table.
   - Make it concrete enough that a dev can write SQL from it.

5. `## Event → Screen → Data Flow`  
   - This is the bridge from REALITY_EVENT_IN_HOUSE.md.
   - Use subheadings like:
     - `### Scenario: CUT 20 sets but only 18 real`
     - `### Scenario: Stitch over-limit time`
     - etc.
   - For each scenario:
     - Step 1: Where user starts (which screen, which role).
     - Step 2: What they click / input.
     - Step 3: What happens in Time/Token/DB.
     - Step 4: What is visible in reports / dashboards.

6. `## Integration & Dependencies`  
   - List which other modules/specs this depends on.
   - Example: “Depends on SPEC_TIME_ENGINE for over-limit calculation.”

7. `## Implementation Roadmap (Tasks)`  
   - This is critical.
   - Provide a **numbered task list**, not yet per-file, but conceptual steps.
   - Example:

     1. WC-01: Create `work_center_behavior` table and seed presets (CUT, EDGE, STITCH, QC_FINAL).
     2. WC-02: Implement mapping UI in `/work_centers` to attach behavior.
     3. WC-03: Integrate behavior into work_queue rendering.
     4. WC-04: Add over-limit hint using `default_expected_duration`.

   - Keep each task 1–3 lines:
     - What to build
     - Which part of the system
     - Any critical constraints (e.g., “no breaking changes to Classic line yet”).

---

## SPECIFIC GUIDELINES PER FILE

### 1) SPEC_WORK_CENTER_BEHAVIOR.md

Source of truth:
- Section 1) Work Center Behavior Spec in REALITY_EVENT_IN_HOUSE.md
- All batch vs single vs mixed scenarios (CUT, EDGE, STITCH, QC_FINAL, etc.)

You must:

- Formalize the **work_center_behavior** and **work_center_behavior_map** tables already outlined.
- Clearly separate:
  - Behavior (CUT, EDGE, STITCH, QC_FINAL, HARDWARE_ASSEMBLY, QC_REPAIR, etc.)
  - Actual work_center rows created by each factory.
- For each behavior preset, define:
  - execution_mode (BATCH / SINGLE / MIXED)
  - time_tracking_mode (PER_BATCH / PER_PIECE / NO_TIME)
  - requires_quantity_input
  - allows_component_binding
  - allows_defect_capture
  - supports_multiple_passes
  - ui_template_code
- In Event → Screen → Data Flow:
  - Include at least:
    - CUT 20 sets → 18 actual
    - EDGE multiple passes
    - STITCH single-piece Hatthasilpa (over-limit case)
    - QC_FINAL with component completeness check.

Roadmap:
- Start from DB-level behavior table
- Then mapping & UI
- Then integration with work_queue and DAG Designer
- No actual front-end design details, only behavior contracts.

---

### 2) SPEC_TOKEN_ENGINE.md

Use:
- All “Batch→Single”, “Token split”, “Rework token” ideas from REALITY_EVENT_IN_HOUSE.md.
- Anything related to `dag_token`, `dag_routing`, `trace_api` already present in code/docs.

You must:

- Define what a “token” is in system terms:
  - For Hatthasilpa
  - For Classic
- Specify:
  - How batch tokens are represented.
  - How they split into single tokens.
  - How tokens move through nodes.
  - How rework tokens are represented and linked to original.
- Include explicit **state machine**:
  - PLANNED → READY → RUNNING → PAUSED → DONE → REWORK_PENDING → SCRAPPED, etc.
- Integrate with Work Center Behavior:
  - Behavior decides whether a node produces batch tokens, single tokens, or just state updates.

Roadmap:
- T-01: Document current DB structure for tokens.
- T-02: Design extensions for batch/single split.
- T-03: Add API contracts for token state transitions.
- T-04: Integrate with trace API and dashboards.

---

### 3) SPEC_TIME_ENGINE.md

Use:
- All real-life time issues in REALITY_EVENT_IN_HOUSE.md:
  - Forgot to press Start/Pause
  - Over-limit sessions
  - Offline tab
  - Multiple jobs per worker
- Existing time-engine docs & tasks already done for Task 1–2.

You must:

- Describe **time tracking model**:
  - How start/pause/resume is stored.
  - How drift is corrected.
  - How over-limit is detected (using default_expected_duration from behavior).
- Explain:
  - Server-side truth vs client-side display.
  - How to recover when JS is paused or tab is closed.
- Provide scenarios:
  - Single job running
  - Worker tries to start a second job (conflict)
  - Long idle session flagged but not auto-failure.

Roadmap:
- TE-01: Stabilize core time storage (already done – refer to existing tasks).
- TE-02: Implement over-limit detection based on behavior.
- TE-03: Add conflict checker (1 worker → 1 active token).
- TE-04: Add recovery UI hints for supervisors.

---

### 4) SPEC_COMPONENT_SERIAL_BINDING.md

Use:
- All component binding events from REALITY_EVENT_IN_HOUSE.md.
- The new API: `hatthasilpa_component_api.php` and tests in `docs/dag/task13*.md` if they exist.

You must:

- Define:
  - What is a “component” in this context (hardware, straps, etc.).
  - Where component serials are generated (CUT? HARDWARE_ASSEMBLY? PACKING?).
- Specify:
  - Binding model (job_ticket_serial ↔ component_serial).
  - Multi-binding points (some components bound at Node A, others at Node B).
- Event flows:
  - Bind at assembly.
  - Fix incorrect binding.
  - QC checks completeness before shipping.

Roadmap:
- C-01: Finalize DB model for component serial links.
- C-02: Define APIs for bind/unbind/list.
- C-03: Integrate with QC_FINAL and PACKING nodes.
- C-04: Add reporting for “component swap” incidents.

---

### 5) SPEC_QC_SYSTEM.md

Use:
- QC section from REALITY_EVENT_IN_HOUSE.md:
  - Multi-level QC.
  - Defect codes (EP01, SEW05, CUT02).
  - Component-level QC.

You must:

- Define:
  - QC nodes vs normal production nodes.
  - QC_SINGLE vs QC_REPAIR vs QC_FINAL flows.
- Describe:
  - How defect codes are stored and linked to tokens/components.
  - How QC affects token state (PASS / FAIL / REWORK / DISCARD).
- Scenarios:
  - Fail at QC 1 → back to previous node.
  - Fail at QC 2 → skip QC 1 or go back?
  - Final QC with component completeness check.

Roadmap:
- Q-01: Define QC data model and defect catalog.
- Q-02: Attach QC behavior to specific nodes.
- Q-03: Integrate QC with token engine and trace API.
- Q-04: Add QC dashboards (not UI design, just data needs).

---

### 6) SPEC_PWA_CLASSIC_FLOW.md

Use:
- PWA scan events from REALITY_EVENT_IN_HOUSE.md:
  - Scan in / out
  - Mis-scans
  - Missing scans
  - Reverse scans

You must:

- Describe:
  - How Classic line differs from Hatthasilpa.
  - PWA scan contracts: scan_in, scan_out, node transitions.
- Define:
  - Error recovery cases:
    - LOST NODE
    - MISSING SCAN
    - REVERSE SCAN
- Make sure:
  - It integrates with the same Token Engine concepts where possible (same language, slightly different entry points).

Roadmap:
- PWA-01: Document current PWA DB/API.
- PWA-02: Standardize scan event types.
- PWA-03: Implement error recovery patterns.
- PWA-04: Integrate with trace reports.

---

### 7) SPEC_LEATHER_STOCK_REALITY.md

Heavily based on section 2) of REALITY_EVENT_IN_HOUSE.md and the appended “Leather Steward” logic.

You must:

- Extract and formalize:
  - Leather piece types (FULL_HIDE, BIG_PANEL, MEDIUM_PARTS, SMALL_OFFCUT, SCRAP_OR_UNKNOWN).
  - Leather Steward role and workflow.
- Define:
  - Data model additions (e.g., leather_buckets, leather_reality_snapshots).
  - Reconciliation logic:
    - T (system stock) vs B_total (sum of buckets).
    - unknown_ratio, panel_ratio, offcut_ratio.
- Scenarios:
  - Planner tries to create MO for panel-hungry product.
  - System warns based on panel_ratio.
  - Suggest small goods when offcut_ratio high.

Roadmap:
- L-01: Add leather reality tables.
- L-02: Build Leather Steward UI/flow for bucketing.
- L-03: Add MO planner warnings based on ratios.
- L-04: Add “offcut product line” analytics.

---

### 8) SPEC_IMPLEMENTATION_ROADMAP.md

This file is the **top-level execution plan**.

You must:

- Read all other SPEC_*.md files you just created.
- Produce:
  - `## Overview` – short explanation of the big picture.
  - `## Phase 1 – Foundations`
    - Work Center Behavior core DB
    - Token Engine clarifications
    - Time Engine hardening
  - `## Phase 2 – Hatthasilpa Flow`
    - Work queue integration
    - QC basic
    - Component binding minimal
  - `## Phase 3 – Classic/PWA Integration`
    - PWA scan normalization
    - Token + QC alignment
  - `## Phase 4 – Leather Reality Layer`
    - Leather Steward
    - Planner warnings
- For each phase:
  - List 5–10 tasks pointing back to the per-spec Task IDs (e.g., “WC-01, TE-02, T-03”).
  - Clarify prerequisites so that a human can decide iteration order without breaking anything.

Style:
- No storytelling here.
- Pure planning document.
- Short paragraphs + bullet lists.

---

## ABSOLUTE CONSTRAINTS

- DO NOT change any PHP/JS/SQL code in this run.
- DO NOT rename existing tables, columns, or file names.
- DO NOT invent completely new concepts that conflict with REALITY_EVENT_IN_HOUSE.md or DAG_IMPLEMENTATION_GUIDE.md.
- You MAY:
  - Propose additional columns / tables where needed.
  - Tighten terminology and add structure.
  - Introduce IDs for tasks (WC-01, TE-02 etc.) to make planning easier.

- Write everything in **English technical style**, but it must be:
  - Concise
  - Dense
  - Easy to scan for human developers.

When you are done:
- All SPEC_*.md files must exist and be internally consistent.
- SPEC_IMPLEMENTATION_ROADMAP.md must reference the others.
- REALITY_EVENT_IN_HOUSE.md remains the narrative “why”.
- The new SPEC_*.md files become the “how” for developers and future AI agents.