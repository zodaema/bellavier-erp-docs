# Task 27.15 QC Rework V2 — Results

> **Task:** 27.15 QC Rework V2 - Human-Judgment Model  
> **Status:** ✅ **COMPLETE**  
> **Completed:** December 6, 2025, 13:30 ICT  
> **Duration:** ~5 hours  
> **Version:** 2.14.0  

---

## 📋 Summary

Successfully implemented QC Rework V2 with human-judgment model, component-aware rework targeting, defect-based suggestions, and supervisor override capabilities. This replaces the rigid graph-based QC routing with a flexible operator-driven system.

---

## ✅ CTO Audit Fixes Applied (4/4)

| # | Issue | Fix | Status |
|---|-------|-----|--------|
| 1 | UI wording "Send back to" | Changed to "เลือกขั้นตอนที่ต้องแก้ไข" | ✅ |
| 2 | Cross-component rework allowed | Added same-branch validation | ✅ |
| 3 | Defect suggestions not from catalog | Integrated `DefectCatalogService` | ✅ |
| 4 | No supervisor override protection | Added PIN verification system | ✅ |

---

## ✅ Deliverables Completed

### Database

| Item | Status | Notes |
|------|--------|-------|
| `flow_token.rework_count` column | ✅ | Tracks rework iterations |
| `qc_rework_override_log` table | ✅ | Audit trail for overrides |
| Indexes | ✅ | Performance optimization |

### Services

| Service | Methods Added | Status |
|---------|--------------|--------|
| `DAGRoutingService.php` | 6 methods | ✅ |
| `BehaviorExecutionService.php` | `handleQCFailV2()` | ✅ |
| `TokenLifecycleService.php` | `moveTokenToNode()` | ✅ |

**DAGRoutingService Methods:**
- `getReworkTargetsForQC()` - Get valid rework targets
- `getDefectSuggestionPriority()` - Priority based on defect
- `isValidReworkTarget()` - Validate target selection
- `validateReworkTargetSelection()` - Comprehensive validation
- `handleQCRework()` - Main rework orchestration
- `calculateNodeDistance()` - Distance calculation

### API Endpoints

| Endpoint | Action | Description |
|----------|--------|-------------|
| `dag_routing_api.php` | `get_rework_targets` | Get valid targets for QC node |
| `dag_routing_api.php` | `perform_qc_rework` | Execute rework with validation |

### Frontend

| File | Purpose | Status |
|------|---------|--------|
| `assets/javascripts/dag/qc_rework_v2.js` | Rework modal and logic | ✅ |

### Tests

| File | Tests | Status |
|------|-------|--------|
| `tests/Unit/QCReworkV2Test.php` | 18 tests | ✅ 16 pass, 2 skip |

---

## 🔧 Technical Implementation

### Rework Target Selection Algorithm

```
1. Find QC node's anchor_slot (component branch)
2. Get all upstream operation nodes in same branch
3. Filter out: QC nodes, merge nodes, split nodes, completed nodes
4. Calculate distance from QC node
5. If defect code provided:
   - Get rework_hints from DefectCatalogService
   - Match suggested_operation to node behavior_code
   - Boost priority for matching nodes
6. Sort by: suggestion_priority DESC, distance ASC
7. Return ranked list with is_suggested flags
```

### Same-Component Enforcement

```php
// CTO Audit Fix #2
public function isValidReworkTarget(int $qcNodeId, int $targetNodeId): bool
{
    $qcAnchor = $this->findComponentAnchor($qcNodeId);
    $targetAnchor = $this->findComponentAnchor($targetNodeId);
    
    // Must be in same component branch
    if ($qcAnchor && $targetAnchor) {
        if ($qcAnchor['id_node'] !== $targetAnchor['id_node']) {
            return false; // Cross-component REJECTED
        }
    }
    // ... additional validation
}
```

### Supervisor Override System

```php
// CTO Audit Fix #4
if ($riskLevel >= 2) { // MEDIUM or higher
    if (!$supervisorPin) {
        throw new Exception('Supervisor approval required');
    }
    // Validate PIN
    // Log to qc_rework_override_log
}
```

---

## 🛡️ Safety Guards

| Guard | Implementation |
|-------|----------------|
| Max Rework Count | `MAX_REWORK_COUNT_PER_TOKEN = 5` |
| Idempotency | `IdempotencyService::guard()` |
| Feature Flag | `QC_REWORK_V2_ENABLED` |
| Same-Component | `isValidReworkTarget()` check |
| Supervisor PIN | Risk-level based requirement |

---

## 📊 Metrics

| Metric | Value |
|--------|-------|
| New DB columns | 1 (`rework_count`) |
| New DB tables | 1 (`qc_rework_override_log`) |
| Service methods | 8 |
| API endpoints | 2 |
| Frontend files | 1 |
| Unit tests | 18 |
| Translation keys | 38 |

---

## 🎯 Key Features

1. **Human-Judgment Model** - Operators choose rework targets, not rigid graph paths
2. **Defect-Based Suggestions** - Prioritized targets based on defect type
3. **Same-Component Enforcement** - Cannot rework across component branches
4. **Supervisor Override** - PIN required for high-risk overrides
5. **Full Audit Trail** - All actions logged

---

## 🔗 Related Tasks

- **Depends on:** 27.13 (Component Anchor), 27.14 (Defect Catalog)
- **Enables:** Production QC workflow

---

> **"QC Rework V2 = Human judgment + Graph permission"**

