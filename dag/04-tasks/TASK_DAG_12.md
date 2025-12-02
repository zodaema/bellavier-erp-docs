You are working in the Bellavier Group ERP monorepo.

Goal: Implement DAG-12 “Component Serial Binding (Stage 1 – Hatthasilpa Line)” focusing on **capturing & exposing** component serial relations for Hatthasilpa jobs, WITHOUT hard enforcement yet.

This is part of the DAG core line (Hatthasilpa), and must follow all existing developer policies and AI rules:

- docs/developer/README.md
- docs/developer/01-policy/DEVELOPER_POLICY.md
- docs/developer/02-quick-start/QUICK_START.md
- docs/developer/02-quick-start/GLOBAL_HELPERS.md
- docs/developer/02-quick-start/AI_QUICK_START.md
- docs/dag/00-overview/DAG_OVERVIEW.md
- docs/dag/01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md
- docs/dag/02-implementation-status/IMPLEMENTATION_STATUS_SUMMARY.md
- docs/dag/03-tasks/TASK_INDEX.md

Follow the same style as DAG-1..11 tasks.

────────────────────────────────
PHASE 1 – DISCOVERY
────────────────────────────────

1. Scan existing code & schema for any prior work related to component serials:
   - Search terms: `component_serial`, `component_serials`, `serial_component`, `component_bind`, `component_trace`, `bom_component_serial`, `job_component`.
   - Search in:
     - `source/`
     - `tools/`
     - `docs/dag/`
     - `docs/serial/` (if exists)
   - Summarize findings:
     - Is there any existing table or field that hints at per-component serial tracking?
     - Is there any partial implementation for component-level traceability?
     - How does BOM currently represent components per job?

2. Map current Hatthasilpa flow:
   - Which services / APIs are involved in:
     - Creating a job / MO
     - Creating tokens for Hatthasilpa line
     - Tracing a job (trace_api, dag_token_api, dag_routing_api, etc.)
   - Identify the “best anchor point” where component serials should be attached:
     - At job header level?
     - At job BOM line level?
     - At token-level metadata?

3. Create / update the task spec document:
   - Create `docs/dag/03-tasks/TASK_DAG_12_COMPONENT_SERIAL_BINDING.md` with:
     - Context: current state (Hatthasilpa partially live, no component serial binding yet)
     - Goals: capture component→serial relations, expose in APIs, no hard enforcement yet
     - Non-Goals: full Classic line support, hard enforcement, PWA scan overhaul
     - Constraints:
       - No breaking change for existing jobs
       - No enforcement that blocks production
       - Keep JSON output backwards compatible (additive only)
     - Design options (if any) and chosen approach
     - Step plan for PHASE 2/3 (implementation + tests)

Do NOT change any code yet in Phase 1. Just produce the task doc and summary in the spec file.

────────────────────────────────
PHASE 2 – DATA MODEL & STORAGE (STAGE 1)
────────────────────────────────

Once TASK_DAG_12_COMPONENT_SERIAL_BINDING.md is created and consistent:

1. Design a minimal, additive storage model for component serial relations:
   - PREFER additive design, e.g.:
     - New table like `job_component_serial` or similar
     - Or reuse existing table if discovery shows a natural place
   - Requirements:
     - Can link: (tenant / org) + job/MO + component (bom line or product) + serial id/text
     - Supports multiple components and multiple serials per job
     - Has created_at / updated_at timestamps
   - Do NOT break any existing table, do NOT drop or alter existing constraints unless explicitly required and clearly documented.

2. Implement schema changes:
   - If using SQL migration files, follow the existing pattern (see `docs/developer/02-quick-start/QUICK_START.md` and any migration helpers in `BGERP\Migration\BootstrapMigrations`).
   - Ensure:
     - Migrations are idempotent
     - Production-safe (no destructive changes)
   - Document the new schema in the TASK_DAG_12 doc:
     - Table name
     - Columns
     - Indexes
     - Example rows

3. Wire up write path (Stage 1 – minimal):
   - Identify where a Hatthasilpa job/MO is created or updated (job creation services or APIs).
   - Add a minimal way to store component serial bindings:
     - Can be done via:
       - A temporary API endpoint (internal-only)
       - Or a small extension on existing job update API
     - MUST be feature-flagged if there is ANY risk of impacting production flows.
   - Make sure writes:
     - Respect tenant/org boundaries
     - Never throw hard errors in production mode (log + fail-soft if something goes wrong)

────────────────────────────────
PHASE 3 – READ PATH & API EXPOSURE
────────────────────────────────

1. Expose component serial bindings in read APIs:
   - Target APIs:
     - `trace_api.php` (per-serial / per-job trace output)
     - `dag_token_api.php` (token details?)
     - Any “job details” API used by Work Queue or MO screens
   - Requirements:
     - Add new JSON fields, don’t change existing ones:
       - Example: `component_serials`, `components_with_serials`, etc.
     - Keep null-safe and backward compatible:
       - If there is no data → field is null or empty array, NOT missing-key error.
     - Use the DB query patterns from Task 21 (Query Optimizer):
       - Prefer LEFT JOIN + aggregation over N+1 queries.
       - Use `$coreDb` / `DatabaseHelper` with prepared statements.

2. Minimal UI surfacing (Hatthasilpa line only):
   - Pick exactly ONE or TWO UI surfaces to show the component serial data:
     - Candidate: job details drawer, Work Queue details panel, or Hatthasilpa job ticket details.
   - Basic requirement:
     - Read-only list of component serial bindings is visible somewhere.
     - Format can be simple (e.g. list of “Component X → Serial Y”).
   - No need for full editor UI yet — just enough to prove the read-path.

────────────────────────────────
PHASE 4 – TESTS & DOCS
────────────────────────────────

1. Add tests:
   - If possible, add integration tests in the style of:
     - `tests/Integration/SystemWide/…`
     - Or DAG-specific tests if they exist in `tests/…/DAG/…`
   - Focus on:
     - When job has component serials → API returns them correctly.
     - When there are no bindings → field is null or empty, but API still works.
     - Tenant isolation: bindings of one tenant don’t appear in another tenant’s responses.

2. Update documentation:
   - Update `docs/dag/03-tasks/TASK_DAG_12_COMPONENT_SERIAL_BINDING.md`:
     - Mark Phase 1-3 steps as DONE/IN PROGRESS/PLANNED
     - Paste example JSON snippets (before/after)
     - Describe limitations (e.g. only Hatthasilpa for now, no enforcement yet)
   - Update:
     - `docs/dag/03-tasks/TASK_INDEX.md`
     - `docs/dag/02-implementation-status/IMPLEMENTATION_STATUS_SUMMARY.md`
     - If relevant, add a short note in `DAG_IMPLEMENTATION_ROADMAP.md` that DAG-12 Stage 1 is implemented.

────────────────────────────────
SAFETY RAILS (MUST FOLLOW)
────────────────────────────────

- Do NOT:
  - Break any existing JSON contract (only additive changes).
  - Enforce hard blocking based on component serials in DAG-12. This is Stage 1 (capture + expose only).
  - Touch Classic line logic in this task (Hatthasilpa only for now).
  - Refactor unrelated DAG code.

- ALWAYS:
  - Use existing helpers:
    - `BGERP\Security\PermissionHelper`
    - `BGERP\Migration\BootstrapMigrations`
    - `BGERP\Http\TenantApiOutput` for tenant APIs
  - Respect tenant/org boundaries.
  - Log safely (no sensitive data such as internal keys or secrets).

At the end, echo a short summary:

- Created/updated files
- Schema changes (if any)
- APIs impacted
- Any TODO or follow-up recommended for DAG-13+