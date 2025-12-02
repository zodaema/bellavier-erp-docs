# Task 19.24.1 — SuperDAG Lean‑Up: Safety Markers & Autoload Roadmap

## Purpose
This task establishes the safety‑marker structure for all Lean‑Up refactors in Phase 19.24.x before applying large‑scale removals, merges, or reorganizations.

## Scope
- Define the standardized TODO marker format.
- Apply phase-level markers across all DAG engine files.
- Identify preconditions before removing `require_once` blocks.
- Identify preconditions before consolidating helper classes.
- Prepare the codebase for 19.24.2–19.24.9 Lean‑Up operations.

## Safety Marker Format
All Lean‑Up markers must follow this format:

```php
// TODO(SuperDAG-LeanUp-<ID>): <description>
// SAFE-REMOVE-WHEN: <condition>
```

### Examples
```php
// TODO(SuperDAG-LeanUp-R1): remove legacy require_once
// SAFE-REMOVE-WHEN: test harness uses Composer autoload
```

```php
// TODO(SuperDAG-LeanUp-R2): remove duplicated helper method
// SAFE-REMOVE-WHEN: GraphHelper fully covers all call sites
```

## Required Marker Categories

### R1 — require_once cleanup
Placed in:
- GraphHelper
- GraphValidationEngine
- SemanticIntentEngine
- ReachabilityAnalyzer
- ApplyFixEngine
- GraphAutoFixEngine

Condition:
```
SAFE-REMOVE-WHEN: test harness uses Composer autoload
```

### R2 — Duplicate Method Removal
Condition:
```
SAFE-REMOVE-WHEN: GraphHelper coverage reaches 100%
```

### R3 — Node/Edge Normalization
Condition:
```
SAFE-REMOVE-WHEN: all tests pass without legacy normalization
```

### R4 — Intent Snapshot Stability
Condition:
```
SAFE-REMOVE-WHEN: snapshot suite stays stable for 3 consecutive runs
```

## Deliverables
- Add markers to all DAG engine files before running 19.24.2.
- DO NOT remove code in this step.
- This file serves as the reference spec for all later Lean‑Up tasks.

## Status
✔️ Ready for execution  
❗ No refactor applied yet — markers only  
