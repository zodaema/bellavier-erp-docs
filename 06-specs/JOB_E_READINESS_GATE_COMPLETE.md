# Job E: Readiness Gate for Publish - COMPLETE ✅

**Completed:** 2026-01-07
**Related Tasks:** Task 30.5 (Readiness System)

---

## Summary

Implemented backend enforcement of readiness checks before allowing product or revision publishing. This ensures that only fully-configured products can be published and used in the Hatthasilpa Job system.

---

## Implementation Details

### E1: Backend Gate in `handlePublishRevision`

**File:** `source/product_api.php` (lines ~4708-4737)

```php
// Job E: READINESS GATE (Task 30.5)
// Block publish if product configuration is incomplete
$productId = (int)($current['id_product'] ?? 0);
if ($productId > 0) {
    $readinessService = new \BGERP\Service\ProductReadinessService($db->getConnection());
    $readiness = $readinessService->isReady($productId);
    
    if (!$readiness['ready']) {
        json_error(
            translate('api.product.error.readiness_gate_failed', 
                'Cannot publish: Product configuration is incomplete'),
            400,
            [
                'app_code' => 'REV_400_NOT_READY',
                'error_code' => 'READINESS_GATE_FAILED',
                'production_line' => $productionLine,
                'failed_checks' => $failedChecks,
                'checks' => $readiness['checks'] ?? [],
                'blocking' => array_slice($failedChecks, 0, 5),
                'suggested_action' => 'complete_configuration_first',
            ]
        );
    }
}
```

### E2: Backend Gate in `handlePublishProduct`

**File:** `source/product_api.php` (lines ~2108-2134)

Same pattern as above, applied to draft product publishing.

### E3: Thai Translations Added

**File:** `lang/th.php`

```php
'api.product.error.readiness_gate_failed' => 'ไม่สามารถเผยแพร่ได้: การตั้งค่าสินค้ายังไม่ครบถ้วน',
'products.error.readiness.production_line' => 'ต้องกำหนด Production Line',
'products.error.readiness.graph_binding' => 'ต้องผูก Graph สำหรับการผลิต',
'products.error.readiness.graph_published' => 'Graph ต้องถูกเผยแพร่แล้ว',
'products.error.readiness.graph_has_start' => 'Graph ต้องมี Node เริ่มต้น',
'products.error.readiness.has_components' => 'ต้องมีอย่างน้อย 1 Component',
'products.error.readiness.components_have_materials' => 'ทุก Component ต้องมี Material',
'products.error.readiness.mapping_complete' => 'ต้อง Mapping Component กับ Graph ครบทุก Slot',
```

---

## Readiness Checks (Hatthasilpa)

| Check Key | Description | Tab |
|-----------|-------------|-----|
| `production_line` | Must be 'hatthasilpa' | General |
| `graph_binding` | Graph must be bound | Production |
| `graph_published` | Bound graph must be published | Production |
| `graph_has_start` | Graph must have START node | Production |
| `has_components` | At least 1 component required | Structure |
| `components_have_materials` | All components must have materials | Structure |
| `mapping_complete` | All anchor slots must be mapped | Production |

---

## Readiness Checks (Classic)

| Check Key | Description | Tab |
|-----------|-------------|-----|
| `production_line` | Must be 'classic' | General |
| `has_components` | At least 1 component required | Structure |
| `components_have_materials` | All components must have materials | Structure |

---

## Error Response Format

```json
{
    "ok": false,
    "error": "ไม่สามารถเผยแพร่ได้: การตั้งค่าสินค้ายังไม่ครบถ้วน",
    "app_code": "REV_400_NOT_READY",
    "error_code": "READINESS_GATE_FAILED",
    "production_line": "hatthasilpa",
    "failed_checks": ["graph_binding", "has_components"],
    "checks": {
        "production_line": true,
        "graph_binding": false,
        "graph_published": false,
        "graph_has_start": false,
        "has_components": false,
        "components_have_materials": false,
        "mapping_complete": false
    },
    "blocking": ["graph_binding", "has_components"],
    "suggested_action": "complete_configuration_first"
}
```

---

## Existing UI Integration (Already Complete)

The Workspace UI already has readiness integration (Task 27.19):

1. **loadReadiness()** - Fetches readiness from `get_product_readiness` API
2. **updateReadinessUI()** - Updates tab badges (✓/⚠)
3. **updatePublishButtonState()** - Disables Publish button if not ready
4. **handleQuickPublish()** - Shows Swal with failed checks if not ready

---

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Publish blocked when any check fails (backend) | ✅ |
| Publish allowed when all checks pass (backend) | ✅ |
| Error response includes failed checks | ✅ |
| Error response includes app_code | ✅ |
| Thai translations available | ✅ |
| UI shows failed checks before publish | ✅ (pre-existing) |

---

## Files Changed

1. `source/product_api.php` - Added readiness gate in both publish handlers
2. `lang/th.php` - Added Thai translations for readiness errors
3. `source/products.php` - Hardened HTTP loopback proxy (Job B)

---

## Security Notes

- Readiness gate is enforced at **backend level**, not just UI
- Cannot bypass by calling API directly
- Uses existing `ProductReadinessService` (no new code paths)
- All checks are deterministic and consistent

---

## Next Steps

- **Job C:** Error app_code mapping for Workspace
- **Job D:** CSRF Origin/Referer protection
