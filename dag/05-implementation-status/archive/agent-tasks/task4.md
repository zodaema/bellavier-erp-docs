# Task 4 — Normalize `operator_availability` schema detection & logging in `AssignmentEngine::filterAvailable()`

## Context

Current logs when starting a Hatthasilpa job:

```text
[AssignmentEngine] filterAvailable called: candidate_count=1
[AssignmentEngine] filterAvailable schema detected: hasIsActive=false, hasStatus=false, hasAvailable=false, idColumn=id_member
[AssignmentEngine] filterAvailable: Unknown operator_availability schema, assuming all available
[AssignmentEngine] filterAvailable: operator_availability columns = ["id_member","is_available","unavailable_reason","unavailable_until","note","updated_at","updated_by"]

But the actual schema of operator_availability in this environment is:
	•	id_member
	•	is_available (TINYINT(1))
	•	unavailable_reason
	•	unavailable_until (DATETIME)
	•	note
	•	updated_at
	•	updated_by

So:
	•	There is no is_active, status, or available column
	•	There is is_available and unavailable_until which we want to use
	•	Right now, filterAvailable() falls back to “Unknown schema → assume all available”, which works functionally, but we lose the ability to block unavailable operators and the log is noisy.

The goal of this task is to:
	1.	Teach filterAvailable() to understand this schema (is_available + unavailable_until) as a first-class supported pattern.
	2.	Clean up logging: no more “Unknown schema” if columns are known and handled.
	3.	Preserve the existing fail-open behavior for truly unknown schemas.

⸻

Files in scope
	•	source/BGERP/Service/AssignmentEngine.php

Do NOT change any database schema. Only adjust PHP logic + logging in filterAvailable().

⸻

Requirements

1) Schema Detection Improvements

In AssignmentEngine::filterAvailable(), there is already logic like:
	•	$columns = [...] (from DESCRIBE / INFORMATION_SCHEMA)
	•	$hasIsActive  = in_array('is_active', $columns, true);
	•	$hasStatus    = in_array('status', $columns, true);
	•	$hasAvailable = in_array('available', $columns, true);
	•	$idColumn set to either operator_id or id_member.

You must:
	1.	Keep the existing detection for legacy schemas (status, is_active, available) — do not remove them.
	2.	Extend detection to support the new real schema:

$hasIsActive         = in_array('is_active', $columns, true);
$hasStatus           = in_array('status', $columns, true);
$hasAvailableFlag    = in_array('available', $columns, true) || in_array('is_available', $columns, true);
$hasUnavailableUntil = in_array('unavailable_until', $columns, true);


	3.	Keep $idColumn resolution as it is, but ensure it works for this schema:

$idColumn = in_array('operator_id', $columns, true) ? 'operator_id' : 'id_member';


	4.	Update the debug log that prints schema detection to include these booleans (you can rename variables if needed but keep the meaning clear).

Goal: For the current schema, the log should read something like:

[AssignmentEngine] filterAvailable schema detected: hasIsActive=false, hasStatus=false, hasAvailableFlag=true, hasUnavailableUntil=true, idColumn=id_member

Not hasAvailable=false.

⸻

2) New Branch for is_available + unavailable_until Schema

Currently, the code probably looks roughly like:

if ($hasIsActive) {
    // schema 2
} elseif ($hasStatus) {
    // schema 1
} elseif ($hasAvailable) {
    // schema 3
} else {
    // unknown schema -> assume all available
}

You must add a dedicated branch for this schema:
	•	Table has id_member, is_available, unavailable_until
	•	No status
	•	No is_active

Desired behavior for this branch:
	•	Treat operator as available if:
	•	is_available = 1 (or is_available IS NULL if we want to fail-open when not set)
	•	AND unavailable_until IS NULL OR unavailable_until <= UTC_TIMESTAMP()
	•	Treat operator as not available otherwise (filtered out from candidate list)

Concrete implementation sketch (you can refactor for style):

if ($hasIsActive) {
    // existing branch (keep as is)
} elseif ($hasStatus) {
    // existing branch (keep as is)
} elseif ($hasAvailableFlag && $hasUnavailableUntil) {
    // ✅ NEW: schema with is_available + unavailable_until
    error_log("[AssignmentEngine] filterAvailable: using is_available/unavailable_until schema");

    if (empty($candidateIds)) {
        return [];
    }

    $inClause = implode(',', array_fill(0, count($candidateIds), '?'));
    $types    = str_repeat('i', count($candidateIds));

    $sql = "
        SELECT {$idColumn} AS member_id
        FROM operator_availability
        WHERE {$idColumn} IN ($inClause)
          AND (is_available = 1 OR is_available IS NULL)
          AND (unavailable_until IS NULL OR unavailable_until <= UTC_TIMESTAMP())
    ";

    $stmt = $tenantDb->prepare($sql);
    if (!$stmt) {
        error_log('[AssignmentEngine] filterAvailable: prepare failed for is_available schema: ' . $tenantDb->error);
        // Fail-open: return original candidate list
        return $candidateIds;
    }

    $stmt->bind_param($types, ...$candidateIds);
    if (!$stmt->execute()) {
        error_log('[AssignmentEngine] filterAvailable: execute failed for is_available schema: ' . $stmt->error);
        return $candidateIds; // Fail-open
    }

    $result       = $stmt->get_result();
    $availableIds = [];
    while ($row = $result->fetch_assoc()) {
        $availableIds[] = (int)$row['member_id'];
    }
    $stmt->close();

    // Intersect with original candidateIds to preserve order & safety
    $filtered = array_values(array_intersect($candidateIds, $availableIds));

    error_log("[AssignmentEngine] filterAvailable: is_available schema reduced candidates from "
        . count($candidateIds) . " to " . count($filtered));

    return $filtered;
} elseif ($hasAvailableFlag) {
    // existing "available" schema branch (keep as is)
} else {
    // Unknown schema: fail-open
    error_log("[AssignmentEngine] filterAvailable: Unknown operator_availability schema, assuming all available");
    return $candidateIds;
}

Important rules:
	•	Keep fail-open behavior: if DESCRIBE / prepare / execute fails, return original $candidateIds and log the error.
	•	Always intersect with original $candidateIds so we never accidentally add IDs that weren’t candidates.
	•	Respect existing pattern & style of the file (logging format, error prefixes, etc.).

⸻

3) Logging Expectations

After this change, for the current production schema, logs should look like:

[AssignmentEngine] filterAvailable called: candidate_count=1
[AssignmentEngine] filterAvailable schema detected: hasIsActive=false, hasStatus=false, hasAvailableFlag=true, hasUnavailableUntil=true, idColumn=id_member
[AssignmentEngine] filterAvailable: using is_available/unavailable_until schema
[AssignmentEngine] filterAvailable: is_available schema reduced candidates from 1 to 1

or, if someone is actually unavailable:

[AssignmentEngine] filterAvailable: is_available schema reduced candidates from 1 to 0

There should no longer be:

filterAvailable: Unknown operator_availability schema, assuming all available

for this schema.

Keep the detailed log that prints out operator_availability columns = [...] for unknown schemas; it’s useful for future migrations. Do not remove that.

⸻

4) Tests / Safety Check

If there are existing tests touching AssignmentEngine::filterAvailable() or HatthasilpaAssignmentIntegrationTest, they must still pass.

If no tests exist for this function:
	•	At least add a small integration assertion in tests/Integration/HatthasilpaAssignmentIntegrationTest.php that:
	1.	Seeds operator_availability with:
	•	one row for id_member = 1, is_available = 0, unavailable_until in the future
	•	one row for id_member = 2, is_available = 1, unavailable_until NULL
	2.	Seeds a node plan with candidates [1, 2] for some node.
	3.	Calls the internal helper or AssignmentEngine to get filtered candidates.
	4.	Asserts that only 2 remains after filterAvailable().

If adding a test is too heavy for this task, at minimum:
	•	Log the filtered candidate list size, and manually verify via a small local script or an existing integration test run.

⸻

Deliverables
	1.	Updated filterAvailable() in source/BGERP/Service/AssignmentEngine.php with:
	•	Improved schema detection (is_available + unavailable_until).
	•	New branch implementing availability check.
	•	Clean, accurate logging.
	•	Fail-open fallback unchanged for unknown schemas.
	2.	(Optional but preferred) A small integration test that asserts the filter behavior using is_available + unavailable_until.
	3.	A short summary file:
	•	docs/dag/agent-tasks/task4_OPERATOR_AVAILABILITY_SCHEMA.md
	•	Include:
	•	Before / After behavior
	•	Example logs (real from test run)
	•	Summary of supported schemas (status / is_active / available / is_available+unavailable_until)