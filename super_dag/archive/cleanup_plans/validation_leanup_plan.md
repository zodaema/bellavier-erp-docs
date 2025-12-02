# Validation Lean-Up Plan

**Task 19.19: Validation Engine Lean-Up Precheck Report**

Draft แผน Lean-Up แนะนำ (แต่ยังไม่ลงมือทำ): แบ่งเป็น Phase 1, 2, 3

---

## Overview

แผน Lean-Up นี้แบ่งเป็น 3 phases ตามความเสี่ยงและความซับซ้อน:
- **Phase 1:** Quick Wins (Low risk / High clarity)
- **Phase 2:** Structural Refactor (Medium risk)
- **Phase 3:** Deep Clean & Preparation for ETA Engine (High risk)

**Principle:** Quality > Speed. Never rush implementation. Data integrity and security come first.

---

## Phase 1: Quick Wins (Low Risk / High Clarity)

**Goal:** รวม duplicate logic ง่ายๆ, ลบ legacy code, จัดระเบียบ error codes

**Impact Level:** Low  
**Required Regression Coverage:** Existing test suite (Task 19.18)  
**Estimated Time:** 1-2 days

### 1.1 Extract Shared Helper Methods

**Tasks:**
- สร้าง `GraphHelper` class สำหรับ shared methods
- Extract `buildNodeMap()` และ `buildEdgeMap()` จาก 5 classes → `GraphHelper`
- Extract `extractQCStatusesFromCondition()` จาก 2 classes → `GraphHelper` หรือ `ConditionEvaluator`

**Files to Modify:**
- `source/BGERP/Dag/GraphHelper.php` (new)
- `source/BGERP/Dag/GraphValidationEngine.php`
- `source/BGERP/Dag/SemanticIntentEngine.php`
- `source/BGERP/Dag/ReachabilityAnalyzer.php`
- `source/BGERP/Dag/GraphAutoFixEngine.php`
- `source/BGERP/Dag/ApplyFixEngine.php`

**Risk:** Low (simple extraction, no logic change)

**Test Coverage:**
- Run all existing test fixtures (Task 19.18)
- Ensure no regression

**Validation:**
- All tests pass
- No behavior change

---

### 1.2 Remove Legacy Code

**Tasks:**
- Remove `validateGraphStructure()` function (check error_log for usage first)
- Remove `validateReachabilitySemantic()` deprecated method
- Remove legacy node type validation (`split`, `join`, `wait`, `decision`) - keep only backward compatibility checks

**Files to Modify:**
- `source/dag_routing_api.php` (remove `validateGraphStructure()`)
- `source/BGERP/Dag/GraphValidationEngine.php` (remove deprecated method)

**Risk:** Low (deprecated code, not used by new code)

**Test Coverage:**
- Run all existing test fixtures
- Ensure backward compatibility for old graphs

**Validation:**
- All tests pass
- Old graphs still load correctly

---

### 1.3 Organize Error Codes / Message Mapping

**Tasks:**
- สร้าง `ValidationErrorCodes` class สำหรับ error code constants
- สร้าง `ValidationMessageMapper` class สำหรับ error message mapping
- จัดระเบียบ error codes ใน `dag_routing_api.php`

**Files to Modify:**
- `source/BGERP/Dag/ValidationErrorCodes.php` (new)
- `source/BGERP/Dag/ValidationMessageMapper.php` (new)
- `source/dag_routing_api.php` (use new classes)

**Risk:** Low (organizational change, no logic change)

**Test Coverage:**
- Run all existing test fixtures
- Ensure error codes unchanged

**Validation:**
- All tests pass
- Error codes consistent

---

### 1.4 Document Validation Rules

**Tasks:**
- สร้าง `validation_rules_reference.md` สำหรับ validation rules ทั้งหมด
- Document QC routing rules, parallel rules, reachability rules, etc.
- Link to test cases (Task 19.18)

**Files to Create:**
- `docs/super_dag/validation_rules_reference.md`

**Risk:** None (documentation only)

**Test Coverage:**
- N/A (documentation)

**Validation:**
- Documentation complete and accurate

---

## Phase 2: Structural Refactor (Medium Risk)

**Goal:** แยก concern ของ GraphValidationEngine, รวม QC routing logic, ทำให้ ConditionEvaluator เป็น single source of truth

**Impact Level:** Medium  
**Required Regression Coverage:** Existing test suite + additional edge cases  
**Estimated Time:** 3-5 days

### 2.1 Refactor GraphValidationEngine Structure

**Tasks:**
- แยก validation modules เป็น separate classes:
  - `NodeExistenceValidator`
  - `StartEndValidator`
  - `EdgeIntegrityValidator`
  - `ParallelStructureValidator`
  - `MergeStructureValidator`
  - `QCRoutingValidator` (structural)
  - `ConditionalRoutingValidator`
  - `BehaviorWorkCenterValidator`
  - `MachineBindingValidator`
  - `NodeConfigurationValidator`
  - `SemanticValidator` (uses SemanticIntentEngine)
  - `ReachabilityValidator` (uses ReachabilityAnalyzer)
- `GraphValidationEngine` เป็น orchestrator ที่เรียก validators

**Files to Modify:**
- `source/BGERP/Dag/GraphValidationEngine.php` (refactor)
- `source/BGERP/Dag/Validators/` (new directory, 11 validator classes)

**Risk:** Medium (structural change, but logic unchanged)

**Test Coverage:**
- Run all existing test fixtures
- Add edge case tests for each validator

**Validation:**
- All tests pass
- No behavior change
- Code more maintainable

---

### 2.2 Consolidate QC Routing Logic

**Tasks:**
- รวม QC routing logic ที่กระจายอยู่หลายที่:
  - `GraphValidationEngine::validateQCRouting()` (structural)
  - `GraphValidationEngine::validateQCRoutingSemantic()` (semantic)
  - `SemanticIntentEngine::analyzeQCRoutingIntent()` (intent analysis)
- สร้าง `QCRoutingValidator` class ที่รวม logic ทั้งหมด

**Files to Modify:**
- `source/BGERP/Dag/Validators/QCRoutingValidator.php` (new)
- `source/BGERP/Dag/GraphValidationEngine.php` (use new validator)
- `source/BGERP/Dag/SemanticIntentEngine.php` (extract QC routing intent logic)

**Risk:** Medium (logic consolidation, may affect QC routing behavior)

**Test Coverage:**
- Run all QC test fixtures (TC-QC-01 to TC-QC-04)
- Add edge case tests for QC routing

**Validation:**
- All QC tests pass
- QC routing behavior unchanged
- Code more maintainable

---

### 2.3 Make ConditionEvaluator Single Source of Truth

**Tasks:**
- Move condition validation logic จาก frontend → `ConditionEvaluator`
- Create shared condition serialization helper (backend + frontend)
- Ensure frontend uses same logic as backend

**Files to Modify:**
- `source/BGERP/Dag/ConditionEvaluator.php` (add validation methods)
- `assets/javascripts/dag/modules/conditional_edge_editor.js` (use shared logic)
- `assets/javascripts/dag/modules/GraphSaver.js` (use shared logic)

**Risk:** Medium (frontend-backend synchronization)

**Test Coverage:**
- Run all conditional routing test fixtures (TC-QC-01, TC-QC-02, TC-PL-04)
- Add test cases for condition serialization format

**Validation:**
- All conditional routing tests pass
- Frontend serialization matches backend evaluation
- No behavior change

---

### 2.4 Refactor GraphAutoFixEngine Structure

**Tasks:**
- แยก fix generation logic เป็น separate classes:
  - `MetadataFixGenerator` (v1)
  - `StructuralFixGenerator` (v2)
  - `SemanticFixGenerator` (v3)
- `GraphAutoFixEngine` เป็น orchestrator

**Files to Modify:**
- `source/BGERP/Dag/GraphAutoFixEngine.php` (refactor)
- `source/BGERP/Dag/FixGenerators/` (new directory, 3 generator classes)

**Risk:** Medium (structural change, but logic unchanged)

**Test Coverage:**
- Run all autofix pipeline tests
- Add test cases for each fix generator

**Validation:**
- All autofix tests pass
- No behavior change
- Code more maintainable

---

## Phase 3: Deep Clean & Preparation for ETA Engine (High Risk)

**Goal:** Normalize time/SLA validation, เตรียม interface สำหรับ Phase 20 (ETA / Simulation)

**Impact Level:** High  
**Required Regression Coverage:** Existing test suite + time/SLA test cases  
**Estimated Time:** 5-7 days

### 3.1 Normalize Time/SLA Validation

**Tasks:**
- สร้าง `TimeValidator` class สำหรับ time/SLA validation
- Integrate with `time_model.md` (Task 19.5)
- Normalize timestamp and duration formats
- Add time/SLA validation rules

**Files to Modify:**
- `source/BGERP/Dag/TimeValidator.php` (new)
- `source/BGERP/Dag/GraphValidationEngine.php` (use TimeValidator)
- `docs/super_dag/time_model.md` (reference)

**Risk:** High (new validation rules, may affect existing graphs)

**Test Coverage:**
- Run all existing test fixtures
- Add time/SLA test cases (3-5 cases)
- Test timestamp/duration format normalization

**Validation:**
- All tests pass
- Time/SLA validation works correctly
- Existing graphs unaffected (backward compatible)

---

### 3.2 Prepare Interface for ETA Engine

**Tasks:**
- สร้าง `ETAEngineInterface` สำหรับ Phase 20 integration
- Extract time-related data structures
- Prepare validation hooks for ETA calculation

**Files to Create:**
- `source/BGERP/Dag/ETAEngineInterface.php` (new)
- `docs/super_dag/eta_engine_integration.md` (new)

**Risk:** High (interface design, may change in Phase 20)

**Test Coverage:**
- Interface tests (mock ETA engine)
- Integration tests (when ETA engine ready)

**Validation:**
- Interface defined and documented
- Ready for Phase 20 integration

---

### 3.3 Deep Clean: Remove All Legacy Validation

**Tasks:**
- Remove all legacy validation code (after Phase 1)
- Remove backward compatibility checks for old graphs (if safe)
- Clean up deprecated methods and functions

**Files to Modify:**
- `source/dag_routing_api.php` (remove legacy code)
- `source/BGERP/Dag/GraphValidationEngine.php` (remove deprecated methods)
- `source/BGERP/Service/DAGValidationService.php` (check if still used)

**Risk:** High (removing code, may break backward compatibility)

**Test Coverage:**
- Run all existing test fixtures
- Test backward compatibility (if kept)
- Test old graph loading (if kept)

**Validation:**
- All tests pass
- Backward compatibility maintained (if required)
- Code cleaner

---

### 3.4 Performance Optimization

**Tasks:**
- Optimize validation performance (if needed):
  - Cache validation results (if graph unchanged)
  - Optimize node/edge map building
  - Optimize reachability analysis
- Add performance tests

**Files to Modify:**
- `source/BGERP/Dag/GraphValidationEngine.php` (optimize)
- `source/BGERP/Dag/ReachabilityAnalyzer.php` (optimize)
- `tests/super_dag/PerformanceTest.php` (new)

**Risk:** Medium (optimization, may introduce bugs)

**Test Coverage:**
- Run all existing test fixtures
- Add performance tests

**Validation:**
- All tests pass
- Performance improved (if applicable)
- No behavior change

---

## Implementation Guidelines

### Before Starting Each Phase

1. **Read Documentation:**
   - `validation_engine_map.md` - Understand current structure
   - `validation_dependency_graph.md` - Understand dependencies
   - `validation_risk_register.md` - Understand risks

2. **Run Regression Tests:**
   - `php tests/super_dag/ValidateGraphTest.php`
   - `php tests/super_dag/SemanticSnapshotTest.php`
   - `php tests/super_dag/AutoFixPipelineTest.php`

3. **Create Backup:**
   - Git branch for each phase
   - Document changes in commit messages

### During Implementation

1. **Incremental Changes:**
   - Make small, incremental changes
   - Test after each change
   - Commit frequently

2. **Test Coverage:**
   - Run regression tests after each change
   - Add new test cases if needed
   - Ensure 100% test pass rate

3. **Documentation:**
   - Update documentation as you go
   - Document breaking changes (if any)
   - Update `CHANGELOG.md`

### After Each Phase

1. **Validation:**
   - All tests pass
   - No behavior change (unless intentional)
   - Code more maintainable

2. **Review:**
   - Code review (if applicable)
   - Documentation review
   - Performance review (if applicable)

3. **Deploy:**
   - Deploy to staging
   - Test in staging environment
   - Deploy to production (if stable)

---

## Risk Mitigation

### High-Risk Areas

1. **QC Routing Logic:**
   - Test thoroughly with all QC test fixtures
   - Document QC routing rules clearly
   - Add edge case tests

2. **Semantic Intent Analysis:**
   - Ensure semantic snapshot tests pass
   - Document intent inference rules
   - Add test cases for edge cases

3. **Time/SLA Validation:**
   - Test with time/SLA test cases
   - Ensure backward compatibility
   - Document time model clearly

### Medium-Risk Areas

1. **Structural Refactoring:**
   - Incremental changes
   - Test after each change
   - Ensure no behavior change

2. **Frontend-Backend Synchronization:**
   - Test condition serialization format
   - Ensure frontend matches backend
   - Add integration tests

### Low-Risk Areas

1. **Helper Method Extraction:**
   - Simple extraction, low risk
   - Test after extraction
   - Ensure no behavior change

2. **Legacy Code Removal:**
   - Check usage before removal
   - Test backward compatibility
   - Remove only if safe

---

## Success Criteria

### Phase 1 Success Criteria

- [ ] Shared helper methods extracted
- [ ] Legacy code removed (if safe)
- [ ] Error codes organized
- [ ] Validation rules documented
- [ ] All tests pass
- [ ] No behavior change

### Phase 2 Success Criteria

- [ ] GraphValidationEngine refactored
- [ ] QC routing logic consolidated
- [ ] ConditionEvaluator is single source of truth
- [ ] GraphAutoFixEngine refactored
- [ ] All tests pass
- [ ] Code more maintainable
- [ ] No behavior change

### Phase 3 Success Criteria

- [ ] Time/SLA validation normalized
- [ ] ETA engine interface prepared
- [ ] Legacy validation removed (if safe)
- [ ] Performance optimized (if applicable)
- [ ] All tests pass
- [ ] Ready for Phase 20 integration

---

## Timeline Estimate

**Phase 1:** 1-2 days  
**Phase 2:** 3-5 days  
**Phase 3:** 5-7 days  

**Total:** 9-14 days (approximately 2-3 weeks)

**Note:** Timeline may vary based on complexity and test coverage requirements.

---

## Dependencies

### Phase 1 Dependencies

- None (can start immediately)

### Phase 2 Dependencies

- Phase 1 completed (shared helpers available)

### Phase 3 Dependencies

- Phase 2 completed (structural refactoring done)
- `time_model.md` available (Task 19.5)
- ETA engine requirements defined (Phase 20)

---

## Notes

1. **Quality > Speed:** Never rush implementation. Data integrity and security come first.

2. **Test Coverage:** Ensure 100% test pass rate before moving to next phase.

3. **Backward Compatibility:** Maintain backward compatibility for old graphs (if required).

4. **Documentation:** Update documentation as you go. Document breaking changes (if any).

5. **Incremental Changes:** Make small, incremental changes. Test after each change.

6. **Code Review:** Code review recommended for Phase 2 and Phase 3.

---

**Last Updated:** November 24, 2025  
**Task:** 19.19 - Validation Engine Lean-Up Precheck Report  
**Status:** Draft Plan (Not Yet Implemented)

