# Task 27.21 Results: Material Integration

> **Completed:** December 8, 2025  
> **Duration:** ~20 hours (across multiple sessions)  
> **Status:** ✅ ALL PHASES COMPLETE

---

## 📊 Summary

Task 27.21 implemented comprehensive **Material Requirement & Reservation System** integrated with Job Creation and Execution workflows.

---

## ✅ Phase Completion

| Phase | Description | Status | Duration |
|-------|-------------|--------|----------|
| **Phase 0** | MaterialResolver Consolidation | ✅ Done | 2-3 hrs |
| **Phase 1** | Material Check Panel | ✅ Done | 8-10 hrs |
| **Phase 2** | Reserve on Create + Consumption | ✅ Done | 4-6 hrs |

---

## 🗃️ Database Tables Created

| Table | Purpose |
|-------|---------|
| `material_requirement` | Requirements per job (BOM × qty) |
| `material_reservation` | Soft-lock inventory (reserved qty) |
| `material_requirement_log` | Audit trail (events) |
| `material_allocation` | Token-level material allocation |

---

## 🔧 Services Implemented

### MaterialRequirementService.php
```php
// Key Methods
calculateRequirements(int $jobTicketId): array
getRequirements(int $jobTicketId): array
checkAvailability(int $jobTicketId): array
calculateMaxProducible(int $productId): array
checkShortageForQuantity(int $productId, int $qty): array
getBOMViaComponentMapping(int $productId): array
getMaterialsForToken(int $tokenId): array        // Phase 0
getLeatherMaterialsForToken(int $tokenId): array // Phase 0
resolvePrimaryLeatherSkuForToken(int $tokenId): ?string // Backward compat
```

### MaterialReservationService.php
```php
// Key Methods
createReservations(int $jobTicketId, int $userId, int $expirationHours): array
releaseReservationsForJob(int $jobTicketId, int $userId, string $reason): array
getReservationsForJob(int $jobTicketId): array
```

### MaterialAllocationService.php
```php
// Key Methods
allocateMaterial(int $tokenId, string $materialSku, float $qty): array
consumeMaterial(int $allocationId): array
returnMaterial(int $allocationId, float $qty, string $reason): array
```

---

## 🌐 API Endpoints

**File:** `source/material_requirement_api.php`

| Action | Method | Description |
|--------|--------|-------------|
| `calculate_requirements` | POST | Calculate BOM for job ticket |
| `get_requirements` | GET | Get requirements list |
| `recalculate_requirements` | POST | Recalculate after changes |
| `check_availability` | GET | Check stock availability |
| `calculate_can_produce` | GET | Max producible qty |
| `check_shortage` | GET/POST | Check material shortage |
| `get_product_bom` | GET | Get BOM via component path |
| `create_reservations` | POST | Reserve materials |
| `release_reservations` | POST | Release on cancel |
| `get_reservations` | GET | Get job reservations |
| `get_consumption_log` | GET | Consumption audit trail |
| `get_job_material_summary` | GET | Summary for job |

---

## 🔗 Integration Points

### 1. Product Readiness Check (Task 27.19)
- APIs check `ProductReadinessService::isReady()` before BOM calculation
- Returns `MAT_400_PRODUCT_NOT_READY` if incomplete

### 2. Job Creation Flow
```
Job Created → Calculate Requirements → Check Stock 
    → Reserve Materials → Job status set
    → IF sufficient: status = 'pending'
    → IF shortage: status = 'pending_materials'
```

### 3. Token Execution (CUT Behavior)
```
Token at CUT → Select Leather Sheet → Record Usage
    → MaterialAllocationService::consumeMaterial()
    → Update reservation (reserved → consumed)
    → Log to material_requirement_log
```

### 4. CUT Behavior UI (Task 27.20)
- `leather_sheet_api.php` updated to use `MaterialRequirementService`
- Sheet selection modal shows available sheets
- Usage recorded to `leather_sheet_usage` table

---

## 📁 Files Modified/Created

### New Files
- `source/BGERP/Service/MaterialRequirementService.php`
- `source/BGERP/Service/MaterialReservationService.php`
- `source/BGERP/Service/MaterialAllocationService.php`
- `source/material_requirement_api.php`

### Modified Files
- `source/BGERP/Helper/MaterialResolver.php` → @deprecated
- `source/leather_sheet_api.php` → Uses new service
- `assets/javascripts/dag/behavior_execution.js` → CUT handler updated

### Database Migrations
- Tables created via migration system

---

## 🧪 Testing Results

| Test | Status |
|------|--------|
| `getMaterialsForToken()` returns all materials | ✅ Pass |
| Materials from `product_component_material` (Layer 3) | ✅ Pass |
| Backward compat: `resolvePrimaryLeatherSkuForToken()` | ✅ Pass |
| CUT Behavior UI shows leather sheets | ✅ Pass |
| Sheet selection modal works | ✅ Pass |
| Usage binding saves correctly | ✅ Pass |
| Reservation create/release | ✅ Pass |

---

## 📝 Notes

1. **MaterialResolver Deprecation:** Old helper marked as `@deprecated`, delegates to `MaterialRequirementService` for backward compatibility.

2. **BOM Path:** Uses Layer 3 path (`product_component_material`) instead of legacy `bom/bom_line` tables.

3. **Multi-Material Support:** `getMaterialsForToken()` returns ALL materials for a product, not just one SKU. This supports complex products with multiple leather/fabric components.

4. **Stock Calculation:** `available_for_new_jobs = on_hand - reserved`

---

## 🔜 Next Task

**Task 27.21.1:** Rework Material Reserve
- Handle recut scenarios when token fails QC
- Reserve new materials for replacement tokens
- Track waste/scrap

---

*Documented: December 8, 2025*

