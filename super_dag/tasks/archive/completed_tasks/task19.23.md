# Task 19.23 — Validation Layer Profiling & Hot Path Optimization (Phase 1)

## Objective
Reduce validation latency by profiling execution flow, identifying hot paths, and applying first‑stage micro‑optimizations without altering behavior or validation semantics.

## Scope
This task focuses on:
- Profiling the GraphValidationEngine, SemanticIntentEngine, ReachabilityAnalyzer, and GraphHelper.
- Measuring execution time per rule group.
- Identifying repeated computations and redundant passes.
- Preparing a heat-map for Phase 2 optimization (Task 19.24).

No functional changes will be introduced in this task.

---

## Deliverables

### 1. Profiling Instrumentation
- Add lightweight timing markers (microtime) to the following:
  - Node map generation
  - Edge map generation
  - Condition extraction
  - semantic_intent detection
  - reachability passes
  - QC routing normalization
  - structural rule checks
- Produce a `validation_profile.json` after each validation run.

### 2. ProfilingRunner.php (New)
- CLI tool: `php tools/profile_validation.php --fixture=TC-END-01`
- Runs validation N times (default 30).
- Outputs:
  - Average time
  - Max/min time
  - Standard deviation
  - Top 5 slowest functions

### 3. Profiling Report
File: `docs/super_dag/validation/validation_profiling_report.md`
Includes:
- Summary table of rule groups
- Bottleneck analysis
- Candidates for memoization
- Candidates for rule merging
- Candidates for DAG precomputation

### 4. Acceptance Criteria
- Validation correctness unchanged (All tests must still pass)
- Profiling tool outputs deterministic structure
- No regression in validation speed
- Profiling report created with accurate measurements

---

## Notes
This task does *not* modify validation logic.
Only profiling support is added.
Actual performance improvements will happen in Task 19.24 (Optimization Phase 2) and 19.25 (GraphHelper memoization).

---

## Status
**IN PROGRESS** — awaiting implementation steps 1–4.
