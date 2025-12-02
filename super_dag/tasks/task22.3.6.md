# Task 22.3.6 — Mixed-Problem Orchestration Layer (Self-Healing v1 Finalizer, Extended Spec)

## 1. Executive Overview
This extended specification defines the **full orchestration layer** of Phase 22. Its purpose is to provide AI Agents with a complete architectural guide—ensuring deterministic execution, correct ordering of repairs, and reliable handling of any mixed-problem scenario (TC06–TC10).

The system described here is the final step of **Self-Healing v1**, capable of:
- Identifying all types of canonical timeline problems.
- Running multi-pass, strictly ordered repairs.
- Preventing repair loops and non-deterministic branching.
- Reconstructing timelines when needed.
- Producing a “trustworthy” canonical timeline for every completed token.

This document MUST be treated as the authoritative “blueprint” for the orchestration pipeline. Every implementation must follow this spec exactly.

---

# 2. Architectural Purpose

### 2.1 Why Orchestration is Required
LocalRepairEngine can fix isolated problems.  
CompletionRepair, PauseRepair, StartEndRepair, and ReconstructionEngine can each fix different subsets of issues.  
But real-world tokens often contain *multiple* problems simultaneously.

**Without an orchestrator:**
- Repairs may run out of order.
- A repair may hide a deeper issue.
- Reconstruction may run too early (or not at all).
- Repair handlers may interfere with each other.
- Infinite recursion may occur.

Therefore, an orchestrator is needed to define **one globally-correct deterministic ordering** for all repairs.

---

# 3. Core Philosophy

### (1) Deterministic
For any given token, orchestrator must always produce the same result—no randomization, no AI inference.

### (2) Append-Only
Never modify or delete canonical events. Only append.

### (3) Multi-Pass
Repairs happen in a strict pass order. Later passes must not run before earlier passes complete.

### (4) Single Reconstruction Pass
Reconstruction is a heavy operation and must run **at most once**.

### (5) Validity First
The orchestrator’s mission is NOT to preserve every event—it is to produce a valid canonical timeline.

### (6) No Guessing
Repair handlers operate through deterministic rules, not statistical machine learning.

---

# 4. Problem Classification (L0 → L3)

The validator identifies multiple problem codes. These must be mapped into levels:

### Level 0 — Ignore / Informational
- BAD_FIRST_EVENT → mapped to UNPAIRED_PAUSE
- MISC_WARNING

### Level 1 — Directly Repairable (L1)
Start/End issues:
- MISSING_START
- MISSING_COMPLETE
- TIMELINE_MISSING_START
- TIMELINE_MISSING_COMPLETE

Pause issues:
- UNPAIRED_PAUSE
- PAUSE_BEFORE_START
- INVALID_SEQUENCE_SIMPLE (pause-variant)
- BAD_FIRST_EVENT (after mapping)

Completion/Sequence issues:
- ZERO_DURATION
- NEGATIVE_DURATION
- MULTIPLE_COMPLETE
- EVENT_TIME_DISORDER

### Level 2 — Requires Reconstruction (L2)
- SESSION_OVERLAP_SIMPLE
- MULTI_SESSION_COMPLEX
- CROSS_BOUNDARY_DISORDER
- INVALID_EVENT_ORDER

### Level 3 — Non-Recoverable
- TIMESTAMP_CORRUPTION_EXTREME
- COMPLETE_MISSING_AND_NO_BASELINE
- INVALID_NODE_CONTEXT

---

# 5. Combined Problem Examples

### Example A — Pause + Start issues
```
PAUSE (first event)
RESUME
COMPLETE
```
Problems:
- BAD_FIRST_EVENT → UNPAIRED_PAUSE
- MISSING_START
- ZERO_DURATION (after repairing START incorrectly)

### Example B — Completion disorder
```
START @ 10:00
COMPLETE @ 09:59 (negative)
START @ 09:00 (late sync)
```
Problems:
- NEGATIVE_DURATION
- EVENT_TIME_DISORDER
- INVALID_SEQUENCE_SIMPLE

### Example C — Full chaos
```
PAUSE @ T2
START @ T1
COMPLETE @ T1
PAUSE @ T3
RESUME @ T2
```
Problems:
- EVENT_TIME_DISORDER
- SESSION_OVERLAP_SIMPLE
- INVALID_SEQUENCE_SIMPLE
- ZERO_DURATION
- MULTIPLE_COMPLETE

These cases must be fully repairable by the orchestrator.

---

# 6. Orchestration Pipeline (Formal Specification)

The orchestrator runs the following deterministic pipeline:

```
PASS 1 — L1-StartEndRepair
PASS 2 — L1-PauseRepair
PASS 3 — L1-CompletionRepair
PASS 4 — Validation
PASS 5 — Reconstruction (only once)
PASS 6 — Final Validation
RETURN Result
```

## 6.1 Pass Rules

### PASS 1 — StartEndRepair
Fix:
- MISSING_START
- MISSING_COMPLETE
- TIMELINE_MISSING_START
- TIMELINE_MISSING_COMPLETE
- NO_CANONICAL_EVENTS

### PASS 2 — PauseRepair
Fix:
- UNPAIRED_PAUSE
- PAUSE_BEFORE_START
- INVALID_SEQUENCE_SIMPLE (pause-type)

### PASS 3 — CompletionRepair
Fix:
- ZERO_DURATION
- NEGATIVE_DURATION
- EVENT_TIME_DISORDER
- MULTIPLE_COMPLETE

### PASS 4 — Validation
If problems remain AND the remaining problems ∈ L2 → go to reconstruction.

### PASS 5 — Reconstruction
- SINGLE PASS ONLY.
- Uses TimelineReconstructionEngine.
- Must rebuild entire event list into idealized sessions.

### PASS 6 — Final Validation
- If valid → success.
- If invalid and problems ∈ L3 → return failure state (UNRECOVERABLE_STATE).

---

# 7. Class Specifications

## 7.1 RepairOrchestrator.php

### Methods Required:

```
runFullRepairPipeline($tokenId)
loadTokenEvents()
reloadEvents()
applyRepairs()
runPassStartEnd()
runPassPauseRepair()
runPassCompletionRepair()
runReconstructionPass()
isReconstructionNeeded()
detectRemainingProblemLevels()
summarizeResult()
```

### Internal State
- currentEvents
- repairsApplied
- passesExecuted
- reconstructionUsed (boolean)

---

# 8. LocalRepairEngine Extensions

### MUST add:
- applyMultipleRepairs()
- detectDuplicateRepairs()
- mergeRepairPlans()
- produce before/after snapshots

### MUST return:
```
{
  applied_count: N,
  repairs: [...],
  before_snapshot: {},
  after_snapshot: {}
}
```

---

# 9. Validator Extensions

Add:
```
getProblemLevels($problems)
groupByRepairCategory()
```

---

# 10. Deterministic Timestamp Rules

When creating events:

- START repair:
  - time = existing FIRST_EVENT.time - 60s

- COMPLETE repair:
  - time = max(last_event.time + 60s, flow_token.completed_at)

- RESUME repair:
  - time = PAUSE.time + 60s

- SHIFT operations must always move forward, never backward.

---

# 11. Idempotency Rules

### A repair must NOT run twice:
- hash the repair action
- if hash seen before → skip

### Reconstruction must NOT run twice:
- reconstructionUsed flag

---

# 12. Full Pseudocode

(Abbreviated for readability but deterministic.)

```
function runFullRepairPipeline(tokenId):
    events = loadEvents(tokenId)
    problems = validator.validate(events)

    # PASS 1
    if problems.hasStartEndIssues():
        repairs = engine.repairStartEnd(problems)
        apply(repairs)

    # PASS 2
    problems = validator.validate(events)
    if problems.hasPauseIssues():
        repairs = engine.repairPause(problems)
        apply(repairs)

    # PASS 3
    problems = validator.validate(events)
    if problems.hasCompletionIssues():
        repairs = engine.repairCompletion(problems)
        apply(repairs)

    # PASS 4
    problems = validator.validate(events)
    if problems.remainOnlyL2():
        reconstruction = reconstruct(events)
        events = reconstruction

    # PASS 5
    problems = validator.validate(events)
    if problems.empty():
        return success
    else:
        return UNRECOVERABLE_STATE
```

---

# 13. Edge Cases

### A. Start time after complete time
Reconstruction required.

### B. Floating PAUSE without start
Add START, then fix pause.

### C. Negative session duration
Adjust COMPLETE forward then PAUSE sequences.

### D. Node mismatch (different node_id)
Use current_token.node_id or default node_id = 1 for test tokens.

---

# 14. Loop Protection

### The orchestrator MUST abort if:
- More than 1 reconstruction attempt occurs.
- More than 3 full passes yield no changes.
- Events exceed 200 canonical entries.

---

# 15. Test Suite Mapping Table

| Test | Problem(s) | Expected Fix |
|------|-------------|----------------|
| TC06 | OVERLAP | Reconstruction |
| TC07 | INVALID_SEQUENCE_SIMPLE | PauseRepair + CompletionRepair |
| TC08 | EVENT_TIME_DISORDER | CompletionRepair |
| TC09 | NEGATIVE_DURATION | CompletionRepair |
| TC10 | ZERO_DURATION + OVERLAP | CompletionRepair + Reconstruction |

All MUST pass.

---

# 16. Final Output Contract

The orchestrator must return:

```
{
  success: true/false,
  token_id: n,
  repairs: [...],
  reconstruction_used: true/false,
  final_problems: [],
  duration_ms: number,
  snapshot: {...}
}
```

---

# 17. Implementation Instructions to Agent

- Follow this file strictly.
- No divergence or “creative“ logic.
- MUST maintain determinism.
- All repairs must be append-only.
- Reconstruction must be deterministic.
- MUST implement all required class/methods above.

---

# 18. Deliverables

- RepairOrchestrator.php
- Updates to LocalRepairEngine
- Updates to Validator
- Updates to Test Suite
- task22_3_6_results.md (detailed summary)

---

# END OF EXTENDED SPEC (approx. 560 lines)
