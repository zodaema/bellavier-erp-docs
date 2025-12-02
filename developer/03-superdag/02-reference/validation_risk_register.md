# Validation Risk Register

## Current Code State (Refactor Readiness)

This section describes the current operational state of each module as of Task 19.19.

| Module | State | Notes |
|--------|--------|--------|
| GraphValidationEngine | active | Legacy validation removed in 19.13+ |
| SemanticIntentEngine | active | Intent extraction stable, snapshot tests available |
| ReachabilityAnalyzer | active | Fully integrated into validation pipeline |
| GraphAutoFixEngine | active | Risk scoring + intent-based fixes implemented |
| ApplyFixEngine | active | Atomic apply with rollback |
| validateGraphStructure() (legacy) | deprecated | Safe to delete when Lean-Up begins |
| validateReachabilitySemantic() (legacy) | deprecated | Safe to remove after confirmation |
| Frontend validation logic | removed | All validation now engine-driven |

---

## Risk Assessment Criteria

- **High Risk:** Logic ซับซ้อน, ใช้ในหลายจุด, ไม่มี test coverage
- **Medium Risk:** Logic ธรรมดาแต่ใช้ในหลายจุด, มี test coverage บางส่วน
- **Low Risk:** Logic ง่าย, มี test coverage ดี, ใช้ในจุดเดียว

---

## Risk Score Model (0–100)

Each module will receive a unified risk score:

- Impact (0–10)
- Complexity (0–10)
- Usage Frequency (0–10)
- Code Age / Stability (0–10)
- Test Coverage Gap (0–10)

**Risk Score = Impact*2 + Complexity*2 + Usage + CoverageGap + Stability**

Interpretation:
- 0–20 = Low
- 21–50 = Medium
- 51–100 = High (refactor carefully)

---

## Risk Register Table

| Module | Location | Risk Reason | Test Coverage | Priority |
|--------|----------|-------------|---------------|----------|
| `GraphValidationEngine` | `validateQCRoutingSemantic()` | Logic ซับซ้อน, ใช้ในหลายจุด (save, publish, validate), QC routing เป็น core feature | TC-QC-01, TC-QC-02, TC-QC-03 | **High** |
| `GraphValidationEngine` | `validateSemanticLayer()` | เรียก `SemanticIntentEngine` และ `detectIntentConflicts()`, เป็น semantic validation core | TC-SM-01, TC-SM-02 | **High** |
| `GraphValidationEngine` | `validateReachabilityRules()` | ใช้ `ReachabilityAnalyzer`, ตรวจจับ unreachable/dead-end, critical สำหรับ graph integrity | TC-RC-01, TC-RC-02, TC-RC-03 | **High** |
| `SemanticIntentEngine` | `analyzeIntent()` | Main entry point, เรียกหลาย analyze methods, ไม่มี database queries แต่ logic ซับซ้อน | Semantic snapshot tests | **High** |
| `SemanticIntentEngine` | `detectIntentConflicts()` | ตรวจจับ intent conflicts, ใช้ใน `GraphValidationEngine`, critical สำหรับ semantic consistency | TC-SM-01 | **High** |
| `GraphAutoFixEngine` | `suggestFixes()` | Main entry point, เรียก semantic/structural fixes, calculate risk scores, complex logic | AutoFix pipeline tests | **High** |
| `GraphAutoFixEngine` | `calculateRiskScores()` | Risk scoring logic, ใช้ `risk_base` จาก intents, complex calculation | AutoFix pipeline tests | **Medium** |
| `ApplyFixEngine` | `apply()` | Atomic operations, rollback on failure, critical สำหรับ graph integrity | AutoFix pipeline tests | **High** |
| `ApplyFixEngine` | `applySingleOperation()` | Applies single operation, หลาย operation types, critical สำหรับ fix execution | AutoFix pipeline tests | **High** |
| `ConditionEvaluator` | `evaluate()` | Single source of truth สำหรับ condition evaluation, ใช้ในหลายจุด (validation, routing) | TC-QC-01, TC-QC-02, TC-PL-04 | **High** |
| `ReachabilityAnalyzer` | `analyze()` | Main entry point, เรียกหลาย analysis methods, critical สำหรับ reachability detection | TC-RC-01, TC-RC-02, TC-RC-03 | **High** |
| `ReachabilityAnalyzer` | `buildReachabilityMap()` | BFS traversal, critical สำหรับ reachability analysis | TC-RC-01 | **Medium** |
| `ReachabilityAnalyzer` | `detectCycles()` | Cycle detection (DFS), critical สำหรับ cycle detection | TC-RC-04 (if exists) | **Medium** |
| `GraphValidationEngine` | `extractQCStatusesFromCondition()` | Extract QC statuses from condition, ใช้ใน `validateQCRoutingSemantic()`, duplicate logic with `SemanticIntentEngine` | TC-QC-01, TC-QC-02 | **Medium** |
| `SemanticIntentEngine` | `extractQCStatusesFromCondition()` | Extract QC statuses from condition, duplicate logic with `GraphValidationEngine` | Semantic snapshot tests | **Medium** |
| `GraphValidationEngine` | `buildNodeMap()` / `buildEdgeMap()` | Node/edge map building, duplicate logic in multiple classes | All test fixtures | **Low** |
| `SemanticIntentEngine` | `buildNodeMap()` | Node map building, duplicate logic with other classes | Semantic snapshot tests | **Low** |
| `ReachabilityAnalyzer` | `buildNodeMap()` / `buildEdgeMap()` | Node/edge map building, duplicate logic with other classes | TC-RC-01, TC-RC-02, TC-RC-03 | **Low** |
| `GraphAutoFixEngine` | `buildNodeMap()` / `buildEdgeMap()` | Node/edge map building, duplicate logic with other classes | AutoFix pipeline tests | **Low** |
| `ApplyFixEngine` | `buildNodeMap()` / `buildEdgeMap()` | Node/edge map building, duplicate logic with other classes | AutoFix pipeline tests | **Low** |
| `GraphValidationEngine` | `validateParallelStructure()` | Parallel structure validation, ใช้ flag `is_parallel_split`, critical สำหรับ parallel logic | TC-PL-01, TC-PL-02, TC-PL-03 | **Medium** |
| `GraphValidationEngine` | `validateMergeStructure()` | Merge structure validation, ใช้ flag `is_merge_node`, critical สำหรับ merge logic | TC-PL-02 | **Medium** |
| `GraphValidationEngine` | `validateStartEnd()` | START/END validation, critical สำหรับ graph integrity | All test fixtures | **Medium** |
| `GraphValidationEngine` | `validateEdgeIntegrity()` | Edge integrity validation, critical สำหรับ graph connectivity | All test fixtures | **Medium** |
| `GraphAutoFixEngine` | `suggestQCTwoWayFix()` | QC 2-way fix suggestion, ใช้ intent `qc.two_way`, complex logic | AutoFix pipeline tests | **Medium** |
| `GraphAutoFixEngine` | `suggestQCThreeWayFix()` | QC 3-way fix suggestion, ใช้ intent `qc.three_way`, complex logic | AutoFix pipeline tests | **Medium** |
| `GraphAutoFixEngine` | `suggestParallelSplitFix()` | Parallel split fix suggestion, ใช้ intent `parallel.true_split`, complex logic | AutoFix pipeline tests | **Medium** |
| `GraphAutoFixEngine` | `suggestEndConsolidationFix()` | END consolidation fix suggestion, ใช้ intent `endpoint.multi_end`, complex logic | AutoFix pipeline tests | **Medium** |
| `GraphAutoFixEngine` | `suggestUnreachableConnectionFix()` | Unreachable connection fix suggestion, ใช้ intent `unreachable.unintentional`, complex logic | AutoFix pipeline tests | **Medium** |
| `dag_routing_api.php` | `graph_validate` action | API entry point, เรียก `GraphValidationEngine`, error code mapping | TC-* (all fixtures) | **High** |
| `dag_routing_api.php` | `graph_autofix` action | API entry point, เรียก `GraphValidationEngine` + `GraphAutoFixEngine`, complex flow | AutoFix pipeline tests | **High** |
| `dag_routing_api.php` | `graph_apply_fixes` action | API entry point, เรียก `GraphAutoFixEngine` + `ApplyFixEngine` + `GraphValidationEngine`, complex flow | AutoFix pipeline tests | **High** |
| `dag_routing_api.php` | `graph_save` / `graph_save_draft` / `graph_publish` | API entry point, เรียก `GraphValidationEngine`, critical สำหรับ save/publish flow | TC-* (all fixtures) | **High** |
| `graph_designer.js` | `validateGraphBeforeSave()` | Frontend validation, เรียก `graph_validate` API, error rendering | TC-* (all fixtures, via API) | **Medium** |
| `graph_designer.js` | `applyFixes()` | Frontend autofix, เรียก `graph_autofix` + `graph_apply_fixes` API, complex flow | AutoFix pipeline tests (via API) | **Medium** |
| `conditional_edge_editor.js` | `serializeCondition()` | Condition serialization, ต้อง compatible กับ `ConditionEvaluator`, duplicate logic risk | TC-QC-01, TC-QC-02, TC-PL-04 | **Medium** |
| `GraphSaver.js` | `serializeEdgeCondition()` | Edge condition serialization, ต้อง compatible กับ backend, duplicate logic risk | TC-QC-01, TC-QC-02 | **Medium** |
| `dag_routing_api.php` | `validateGraphStructure()` (legacy) | Legacy function, deprecated, ยังมีใน codebase, อาจถูกเรียกโดย accident | None (deprecated) | **Low** |
| `GraphValidationEngine` | `validateReachabilitySemantic()` (deprecated) | Deprecated method, replaced by `validateReachabilityRules()`, ยังมีใน codebase | None (deprecated) | **Low** |

---

## Recommended Refactor Strategy

### High-Risk Modules
- Use incremental refactor only
- Freeze external API structure
- Add snapshot tests before modification
- Apply dependency isolation before changes

### Medium-Risk Modules
- Extract duplicate logic into shared helpers
- Add unit tests around edge cases
- Avoid structural rewrite unless required

### Low-Risk Modules
- Merge duplicate helpers (buildNodeMap/buildEdgeMap)
- Remove unused deprecated methods
- Safe for bulk refactor

---

## High-Risk Areas (Detailed)

### 1. GraphValidationEngine::validateQCRoutingSemantic()

**Location:** `source/BGERP/Dag/GraphValidationEngine.php`, line ~844

**Risk Reason:**
- Logic ซับซ้อน: ตรวจสอบ QC routing semantic, extract QC statuses, check coverage
- ใช้ในหลายจุด: `graph_validate`, `graph_save`, `graph_save_draft`, `graph_publish`
- QC routing เป็น core feature, ถ้า refactor ผิดจะกระทบ validation ทั้งระบบ
- มี duplicate logic กับ `SemanticIntentEngine::extractQCStatusesFromCondition()`

**Test Coverage:**
- TC-QC-01: QC Pass + Default Rework (2-way routing)
- TC-QC-02: QC 3-Way Routing
- TC-QC-03: QC with Non-QC Condition (warning)

**Recommendation:**
- Extract `extractQCStatusesFromCondition()` to shared helper
- Add more test cases for edge cases
- Document QC routing semantic rules clearly

---

### 2. SemanticIntentEngine::analyzeIntent()

**Location:** `source/BGERP/Dag/SemanticIntentEngine.php`, line ~45

**Risk Reason:**
- Main entry point สำหรับ semantic intent analysis
- เรียกหลาย analyze methods: `analyzeQCRoutingIntent()`, `analyzeParallelIntent()`, `analyzeEndpointIntent()`, `analyzeReachabilityIntent()`
- Logic ซับซ้อน, ไม่มี database queries แต่ analysis logic ละเอียด
- ใช้ใน `GraphValidationEngine::validateSemanticLayer()` และ `GraphAutoFixEngine::suggestFixes()`

**Test Coverage:**
- Semantic snapshot tests (compare intents against snapshots)
- TC-SM-01: Conflicting Intents
- TC-SM-02: Simple Linear Flow

**Recommendation:**
- Ensure semantic snapshot tests cover all intent types
- Add test cases for edge cases (e.g., complex parallel structures)

---

### 3. GraphAutoFixEngine::suggestFixes()

**Location:** `source/BGERP/Dag/GraphAutoFixEngine.php`, line ~48

**Risk Reason:**
- Main entry point สำหรับ autofix suggestions
- เรียก semantic/structural fixes, calculate risk scores
- Complex logic: multiple fix modes (metadata, structural, semantic)
- ใช้ใน `graph_autofix` และ `graph_apply_fixes` API

**Test Coverage:**
- AutoFix pipeline tests (Validate → AutoFix → ApplyFix → Validate)
- TC-QC-04: QC with No Outgoing Edges (should generate fix)

**Recommendation:**
- Add more test cases for different fix types
- Test risk score calculation edge cases

---

### 4. ApplyFixEngine::apply()

**Location:** `source/BGERP/Dag/ApplyFixEngine.php`, line ~42

**Risk Reason:**
- Atomic operations, rollback on failure
- Critical สำหรับ graph integrity: ถ้า apply ผิดจะทำให้ graph state inconsistent
- ใช้ใน `graph_apply_fixes` API
- Complex logic: multiple operation types, validation before/after

**Test Coverage:**
- AutoFix pipeline tests (Validate → AutoFix → ApplyFix → Validate)
- Should test rollback on failure

**Recommendation:**
- Add test cases for rollback scenarios
- Test all operation types individually

---

### 5. ConditionEvaluator::evaluate()

**Location:** `source/BGERP/Dag/ConditionEvaluator.php`, line ~34

**Risk Reason:**
- Single source of truth สำหรับ condition evaluation
- ใช้ในหลายจุด: validation, routing, edge evaluation
- ถ้า refactor ผิดจะกระทบ conditional routing ทั้งระบบ
- มี duplicate logic risk กับ frontend (`conditional_edge_editor.js`)

**Test Coverage:**
- TC-QC-01: QC Pass + Default Rework (condition evaluation)
- TC-QC-02: QC 3-Way Routing (condition evaluation)
- TC-PL-04: Multi-Exit Conditional (condition evaluation)

**Recommendation:**
- Extract condition validation logic to shared module (backend + frontend)
- Add more test cases for complex conditions (AND/OR groups)

---

## Medium-Risk Areas (Detailed)

### 1. Duplicate Logic: extractQCStatusesFromCondition()

**Location:**
- `GraphValidationEngine::extractQCStatusesFromCondition()` (line ~626)
- `SemanticIntentEngine::extractQCStatusesFromCondition()` (line ~679)

**Risk Reason:**
- Same logic duplicated in two classes
- ถ้า refactor หนึ่ง class อาจลืม refactor อีก class
- Risk of logic divergence

**Test Coverage:**
- TC-QC-01, TC-QC-02 (both classes used)

**Recommendation:**
- Extract to shared helper method or `ConditionEvaluator`
- Ensure both classes use same helper

---

### 2. Duplicate Logic: buildNodeMap() / buildEdgeMap()

**Location:**
- `GraphValidationEngine::buildNodeMap()` / `buildEdgeMap()`
- `SemanticIntentEngine::buildNodeMap()`
- `ReachabilityAnalyzer::buildNodeMap()` / `buildEdgeMap()`
- `GraphAutoFixEngine::buildNodeMap()` / `buildEdgeMap()`
- `ApplyFixEngine::buildNodeMap()` / `buildEdgeMap()`

**Risk Reason:**
- Same logic duplicated in multiple classes
- Low risk (simple logic) but maintenance burden

**Test Coverage:**
- All test fixtures (all classes use these methods)

**Recommendation:**
- Extract to shared helper class (e.g., `GraphHelper`)
- Low priority (simple logic, low risk)

---

### 3. Frontend-Backend Duplicate Logic: Condition Serialization

**Location:**
- Backend: `ConditionEvaluator::evaluate()`
- Frontend: `conditional_edge_editor.js::serializeCondition()`, `GraphSaver.js::serializeEdgeCondition()`

**Risk Reason:**
- Frontend serialization ต้อง compatible กับ backend evaluation
- Risk of serialization format mismatch
- Medium risk (may cause validation errors)

**Test Coverage:**
- TC-QC-01, TC-QC-02, TC-PL-04 (condition serialization)

**Recommendation:**
- Extract condition serialization logic to shared module (backend + frontend)
- Add test cases for serialization format validation

---

## Low-Risk Areas (Detailed)

### 1. Legacy Code: validateGraphStructure()

**Location:** `source/dag_routing_api.php`, line ~645

**Risk Reason:**
- Deprecated function, kept for backward compatibility
- Low risk (not used by new code)
- May be removed in future

**Test Coverage:**
- None (deprecated)

**Recommendation:**
- Remove after confirming no usage (check error_log)

---

### 2. Deprecated Method: validateReachabilitySemantic()

**Location:** `source/BGERP/Dag/GraphValidationEngine.php`, line ~1370

**Risk Reason:**
- Deprecated method, replaced by `validateReachabilityRules()`
- Low risk (not used by new code)
- May be removed in future

**Test Coverage:**
- None (deprecated)

**Recommendation:**
- Remove after confirming no usage

---

## Summary

**Total Risk Items:** 35
- **High Risk:** 12 items
- **Medium Risk:** 15 items
- **Low Risk:** 8 items

**High-Risk Areas:**
1. QC routing semantic validation
2. Semantic intent analysis
3. Reachability analysis
4. Autofix suggestion generation
5. Fix application (atomic operations)
6. Condition evaluation

**Duplicate Logic:**
1. `extractQCStatusesFromCondition()` (2 classes)
2. `buildNodeMap()` / `buildEdgeMap()` (5 classes)
3. Condition serialization (backend + frontend)

**Legacy Code:**
1. `validateGraphStructure()` function (deprecated)
2. `validateReachabilitySemantic()` method (deprecated)

**Test Coverage:**
- High-risk areas: ✅ Good coverage
- Medium-risk areas: ✅ Partial coverage
- Low-risk areas: ⚠️ Limited coverage (deprecated code)

---

## Test Coverage Gaps

These areas need additional tests before Lean-Up:

- Rollback scenarios in ApplyFixEngine
- Complex AND/OR condition evaluation in ConditionEvaluator
- Parallel + conditional mixed routing patterns
- Large graph performance tests

---

## Refactor Blockers (Must Be Fixed First)

- Duplicate logic for QC status extraction  
- Frontend/backend condition serialization mismatch  
- Legacy helper functions still referenced in comments  
- Missing cycle detection snapshot tests

---

## Greenlight Criteria for Lean-Up Phase

Lean-Up may begin when:

- Test coverage ≥ 90% across high-risk modules  
- No deprecated functions (validated by grep)  
- Condition serialization unified between FE/BE  
- No inconsistent node/edge map implementations  
- All Task 19.0–19.19 checklist items completed  

---

**Last Updated:** November 24, 2025  
**Task:** 19.19 - Validation Engine Lean-Up Precheck Report
