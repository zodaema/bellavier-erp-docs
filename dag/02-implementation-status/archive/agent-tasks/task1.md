🔧 Agent Prompt — Implement Manager Assignment Propagation + Audits (Hatthasilpa DAG)

Context:
You are an AI Agent working inside the bellavier-group-erp monorepo.
Your job is to implement Manager Assignment propagation on token spawn for Hatthasilpa DAG, and then run the mandatory audits, in line with the existing roadmap & docs.

0. High-level Goal

Implement the spec under:
	•	docs/dag/02-implementation-status/DAG_IMPLEMENTATION_ROADMAP.md
Section: “Manager Assignment Propagation — Pre-req for Phase 2B.6 (Mobile Work Queue UX)”

Specifically:

When a job is started and tokens are spawned, if there is a manager_assignment plan for that job + node, the newly spawned tokens should automatically receive a token_assignment row with assignment_method='manager', and the Work Queue must reflect that assignee.

You must:
	1.	Implement manager assignment propagation on initial spawn.
	2.	Respect idempotency: never override an existing assignment.
	3.	Keep everything in soft mode (no blocking / no hard failures if plan missing).
	4.	Add / extend tests to prove the behavior.
	5.	Run the 3 DAG audits and produce/update the audit markdown files.

⸻

1. Baseline & Constraints (DO NOT BREAK)

Use docs/dag/02-implementation-status/DAG_IMPLEMENTATION_ROADMAP.md as source of truth.

Baseline behaviors that MUST NOT regress:
	•	Cancel Job: scrapes tokens, no resurrection, no reuse of scrapped token sets.
	•	Restart Job: spawns a clean token set only if no ready tokens exist (idempotent spawn rules).
	•	Work Queue hydration: returns only tokens of active instances with status in {ready, active, waiting}, excluding scrapped/completed tokens and non-active instances.
	•	dag_token_api.php: must always return a single JSON payload, no HTML fragments, no duplicate JSON chunks.
	•	Token spawn idempotency & session/assignment locking must remain intact (no double-start or duplicate tokens).
	•	Serial policy for Hatthasilpa:
	•	FF_SERIAL_STD_HAT enforced for piece-mode (missing row = OFF).
	•	If OFF → piece-mode spawn should fail deterministically with DAG_400_SERIAL_FLAG_REQUIRED and NOT create tokens.
	•	If ON → standardized serials must be generated and linked; no TEMP fallback in normal tenants.
	•	TEMP-* serials remain only for explicit soft-test tenants and never register in serial_registry.

Hard constraints:
	•	❌ Do NOT change DB schema (no new tables / columns for this task).
	•	❌ Do NOT change enum values for status or production_type / production_mode.
	•	❌ Do NOT reintroduce any legacy “Atelier / OEM” naming; use hatthasilpa / classic only.
	•	✅ Use existing services where possible (AssignmentEngine, HatthasilpaAssignmentService, etc.) instead of inventing new ones, unless absolutely required.
	•	✅ All state changes must remain transactional; respect existing transaction boundaries.

⸻

2. Relevant Tables & Concepts

You will work with these tables (names inferred from code / docs):
	•	manager_assignment
	•	Holds manager-defined plans for which user should work on which node for a given job.
	•	Likely keyed by id_job_ticket + id_node or by id_job_ticket + node_code.
	•	token_assignment
	•	Holds actual, per-token assignments (who is assigned to this token).
	•	Fields include (expected):
	•	token_id, assigned_user_id, assignment_method, assigned_by_user_id, timestamps, and possibly status.
	•	flow_token
	•	Represents a token (piece / unit) in the DAG:
	•	id_token, id_instance, current_node_id, status, serial_number, etc.
	•	job_graph_instance
	•	id_instance, id_graph, id_job_ticket, status, etc.
	•	This connects job tickets to routing graphs.
	•	routing_node
	•	id_node, id_graph, node_type, node_code, etc.
	•	Used to match assignments by node.

⸻

3. Files & Services to Inspect First

Before coding, scan and understand:
	1.	source/BGERP/Service/AssignmentEngine.php
	•	Look for autoAssignOnSpawn or similar methods.
	•	See how assignments are currently made (auto rules, team/work_center rules, etc).
	2.	source/BGERP/Service/HatthasilpaAssignmentService.php (if present)
	•	Any helpers for fetching manager plans or assignment strategies.
	3.	source/dag_token_api.php
	•	Identify where token spawn is orchestrated.
	•	Find the call to AssignmentEngine::autoAssignOnSpawn(...) or similar.
	4.	source/BGERP/Service/TokenLifecycleService.php
	•	Look at spawnTokens or similar lifecycle methods.
	•	Understand where assignments should be applied: likely after flow_token rows are created but before work-queue hydration.
	5.	Any existing tests related to assignment:
	•	tests/Integration/HatthasilpaAssignmentIntegrationTest.php
	•	Look for “autoAssignOnSpawn” tests, or anything referencing manager_assignment / token_assignment.

Do not change any logic until you’ve mapped the current flow:

Where do tokens get spawned?
At what point is assignment attempted?
How does work queue read assignment info today?

⸻

4. Target Behavior (Manager Assignment Propagation)

Implement the “Desired behavior (to-be)” from the roadmap:

On first spawn:
	•	For each newly spawned token:
	1.	Resolve job_ticket_id and initial node_id (or node_code).
	2.	Look up manager_assignment by (id_job_ticket, id_node) or (id_job_ticket, node_code).
	3.	If a plan is found:
	•	Insert a token_assignment row:
	•	token_id = current token
	•	assigned_user_id = from manager plan
	•	assignment_method = 'manager'
	•	assigned_by_user_id = manager/admin who configured the plan (if available)
	•	assigned_at / timestamps
	4.	If no plan is found:
	•	Fall back to existing auto-assignment logic (team/work_center) or leave unassigned (soft policy).
	•	Idempotency:
	•	If a token_assignment already exists for that token:
	•	Do NOT override it in soft mode.
	•	This applies both to manager-based assignments and auto assignments.

⸻

5. Implementation Plan (Step-by-Step)

Step 5.1 — Add / Enhance Helper to Fetch Manager Plans
In a suitable service (preferably HatthasilpaAssignmentService or a new dedicated helper under BGERP\Service):
	•	Implement a method like:

public function findManagerAssignmentForToken(
    int $jobTicketId,
    int $nodeId,
    ?string $nodeCode = null
): ?array

Behavior:
	1.	First, look up by id_job_ticket + id_node if schema supports it.
	2.	If node_code is also stored in manager_assignment, optionally fallback to (id_job_ticket, node_code).
	3.	Return an associative array with at least:
	•	assigned_user_id
	•	assigned_by_user_id (if available)
	•	any relevant metadata (role, method type).

Add appropriate logging when:
	•	No manager plan found (debug-level log, not error).
	•	Multiple plans found (warn; pick deterministic strategy; e.g., first by created_at ASC).

Do not change the schema. Work with what’s already present.

⸻

Step 5.2 — Implement “Assignment on Spawn” Hook
Locate where tokens are spawned, likely in:
	•	TokenLifecycleService::spawnTokens(...)
	•	Or the place where flow_token rows are inserted and AssignmentEngine::autoAssignOnSpawn(...) is called.

Implement logic so that:
	1.	After each token is created (but within the same transaction):
	•	Check if there is already a token_assignment row for this token:
	•	If yes → skip (idempotent, no override).
	2.	If there’s no existing token assignment:
	•	Use the helper from Step 5.1 to find manager_assignment based on:
	•	job_ticket_id via the instance.
	•	current_node_id (initial node).
	•	If plan found → create a token_assignment with:
	•	token_id
	•	assigned_user_id
	•	assignment_method = 'manager'
	•	assigned_by_user_id (if available; otherwise nullable)
	•	created_at, updated_at
	•	If no plan found → fall back to the existing AssignmentEngine::autoAssignOnSpawn(...) logic.
	3.	Ensure you do not change existing behavior for tokens that already have assignment (e.g., manually assigned tokens, work center auto-assignment, etc).

Keep the logic inside the same transaction that spawns tokens to avoid partially created tokens with missing assignments.

⸻

Step 5.3 — Integrate With Work Queue Payload
Verify how the Work Queue retrieves and exposes assignment information, likely in:
	•	A service reading from token_assignment when building the payload.
	•	JS files under assets/javascripts/hatthasilpa_jobs.js or similar.

Ensure that:
	•	New manager-based token_assignment rows are visible in the Work Queue output:
	•	e.g. assigned_to_id, assigned_to_name, and assignment_method.

Don’t redesign the Work Queue; just confirm that the new rows show up as expected.

⸻

6. Idempotency & Soft Mode Rules
	•	Idempotency:
	•	For any token, only create a token_assignment if no existing assignment is present.
	•	If an assignment exists (either manager or auto), respect it.
	•	Soft Mode:
	•	If manager_assignment is misconfigured (e.g., references a non-existing user) → log a warning and fall back to auto-assign or leave unassigned.
	•	Do NOT throw hard errors that block spawn.
	•	Do NOT abort token creation due to assignment issues.

⸻

7. Tests — Extend HatthasilpaAssignmentIntegrationTest

Add or update tests under something like:
	•	tests/Integration/HatthasilpaAssignmentIntegrationTest.php

Create at least:

7.1 testManagerPlanAppliedOnSpawn()
Scenario:
	1.	Seed DB with:
	•	A Hatthasilpa job ticket.
	•	A graph with at least one node.
	•	A manager_assignment row mapping (job_ticket_id, node_id) → user_id A.
	2.	Trigger start_job (or equivalent) via the same API the UI uses:
	•	hatthasilpa_jobs_api.php?action=start_job or start_production which calls dag_token_api.php?action=token_spawn.
	3.	Assertions:
	•	Tokens are spawned (check flow_token).
	•	For each spawned token at the initial node:
	•	A token_assignment row exists.
	•	assignment_method = 'manager'.
	•	assigned_user_id = user_id A.
	•	Work queue payload for those tokens includes the assignee info.

7.2 testExistingAssignmentIsNotOverridden()
Scenario:
	1.	Seed DB with:
	•	A job ticket and tokens.
	•	An existing token_assignment for a given token with any method (e.g. 'manual').
	2.	Trigger spawn or any path that would normally trigger manager propagation again (restart / idempotent spawn).
	3.	Assertions:
	•	The existing token_assignment row remains unchanged.
	•	Manager assignment is not applied on top.

7.3 testNoManagerPlanFallsBackToAutoOrUnassigned()
Scenario:
	1.	Job without any manager_assignment.
	2.	Start job / spawn tokens.
	3.	Assertions:
	•	No crash.
	•	Tokens either:
	•	Get auto assignment (if existing auto rules apply), or
	•	Remain unassigned.
	•	No token_assignment rows with assignment_method='manager' are created in this case.

All tests must pass along with the existing DAG & Hatthasilpa test suites.

⸻

8. Run Mandatory DAG Audits (and update files)

After implementation + tests are green, run the 3 audits described in:
	•	docs/dag/02-implementation-status/DAG_IMPLEMENTATION_ROADMAP.md
	•	Section: “🚨 MANDATORY: Audit Workflow (ทุก Phase ต้องรัน)”

Run them in this order (and update the markdown outputs):
	1.	NodeType Policy & UI Audit
Command / intent for yourself:
“Run NodeType Policy & UI Audit - Check that all actions/buttons/APIs respect NodeTypePolicy”

Output file:
	•	docs/dag/02-implementation-status/FULL_NODETYPE_POLICY_AUDIT.md
	2.	Flow Status & Transition Audit
“Run Flow Status & Transition Audit - Check job_ticket and flow_token status consistency”

Output file:
	•	docs/dag/02-implementation-status/FLOW_STATUS_TRANSITION_AUDIT.md
	3.	Hatthasilpa Assignment Integration Audit
“Run Hatthasilpa Assignment Integration Audit - Verify Manager Assignment flow”

Output file:
	•	docs/dag/02-implementation-status/HATTHASILPA_ASSIGNMENT_INTEGRATION_AUDIT.md

Each audit file should:
	•	Describe the current behavior (post-change).
	•	Highlight any inconsistencies found (if any).
	•	Confirm that manager assignment propagation now works as per spec.
	•	Note any residual “tech debt” you detect, but do not fix beyond the scope unless trivial.

⸻

9. Documentation Update

Update docs/dag/02-implementation-status/DAG_IMPLEMENTATION_ROADMAP.md:
	•	Under “Manager Assignment Propagation — Pre-req for Phase 2B.6”:
	•	Mark status as IMPLEMENTED / COMPLETE.
	•	Briefly summarize:
	•	Where the code lives (AssignmentEngine / TokenLifecycleService / HatthasilpaAssignmentService).
	•	How the idempotency and soft-mode rules work.
	•	The fact that HatthasilpaAssignmentIntegrationTest::testManagerPlanAppliedOnSpawn exists and passes.

⸻

10. Final Deliverable

At the end, produce a concise summary (for the human owner) including:
	1.	Files changed (PHP + tests + docs).
	2.	Short explanation of the new manager assignment behavior on spawn.
	3.	Confirmation that:
	•	All related tests are green.
	•	The 3 audit markdown files are regenerated and consistent with the new behavior.
	4.	Any follow-up recommendations (optional) for future phases, but keep the scope of code changes strictly within this task.
