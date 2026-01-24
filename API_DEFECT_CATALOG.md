# Defect Catalog API Reference

**Endpoint:** `source/defect_catalog_api.php`  
**Version:** 2.12.0  
**Task:** 27.14 Defect Catalog  
**Last Updated:** 2025-12-05

---

## Overview

The Defect Catalog API provides CRUD operations for managing defect types used in QC processes. Defects are categorized by type (STITCHING, GLUING, etc.) and associated with component types (BODY, STRAP, etc.) from the Material Architecture V2.

---

## Authentication

All endpoints require tenant authentication via `TenantApiBootstrap`.

**Headers:**
- `X-Correlation-Id`: Automatically generated for request tracing
- `X-AI-Trace`: Contains execution time and request metadata

---

## Endpoints

### 1. List All Defects

Get all defects, optionally grouped by category.

**Request:**
```http
GET /source/defect_catalog_api.php?action=list
GET /source/defect_catalog_api.php?action=list&grouped=true
```

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | string | Yes | `list` |
| `grouped` | boolean | No | If true, returns defects grouped by category |

**Response (flat):**
```json
{
    "ok": true,
    "defects": [
        {
            "id": 1,
            "defect_code": "STITCH_BROKEN",
            "display_name_th": "ตะเข็บขาด",
            "display_name_en": "Broken Stitching",
            "description_th": "...",
            "description_en": "...",
            "category_code": "STITCHING",
            "category_name_th": "ข้อบกพร่องการเย็บ",
            "category_name_en": "Stitching Defects",
            "severity": "critical",
            "allowed_component_types": null,
            "rework_hints": {"suggested_operation": "STITCH", "rework_level": "same_piece"},
            "display_order": 10,
            "is_active": 1
        }
    ]
}
```

**Response (grouped):**
```json
{
    "ok": true,
    "defects": [
        {
            "category_code": "STITCHING",
            "category_name_th": "ข้อบกพร่องการเย็บ",
            "category_name_en": "Stitching Defects",
            "defects": [...]
        }
    ]
}
```

---

### 2. Get Single Defect

Get a defect by ID or code.

**Request:**
```http
GET /source/defect_catalog_api.php?action=get&id=1
GET /source/defect_catalog_api.php?action=get&code=STITCH_BROKEN
```

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | string | Yes | `get` |
| `id` | int | Either | Defect ID |
| `code` | string | Either | Defect code |

**Response:**
```json
{
    "ok": true,
    "defect": {
        "id": 1,
        "defect_code": "STITCH_BROKEN",
        "display_name_th": "ตะเข็บขาด",
        "display_name_en": "Broken Stitching",
        "severity": "critical",
        "category_code": "STITCHING",
        "allowed_component_types": null,
        "rework_hints": {"suggested_operation": "STITCH", "rework_level": "same_piece"}
    }
}
```

---

### 3. Get Defects by Component Type

Filter defects applicable to a specific component type.

**Request:**
```http
GET /source/defect_catalog_api.php?action=for_component_type&type_code=STRAP
```

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | string | Yes | `for_component_type` |
| `type_code` | string | Yes | Component type code from `component_type_catalog` |
| `grouped` | boolean | No | If true, returns grouped by category |

**Valid `type_code` values:**
- MAIN: `BODY`, `FLAP`, `POCKET`, `GUSSET`, `BASE`, `DIVIDER`, `FRAME`, `PANEL`
- ACCESSORY: `STRAP`, `HANDLE`, `ZIPPER_PANEL`, `ZIP_POCKET`, `LOOP`, `TONGUE`, `CLOSURE_TAB`
- INTERIOR: `LINING`, `INTERIOR_PANEL`, `CARD_SLOT_PANEL`
- REINFORCEMENT: `REINFORCEMENT`, `PADDING`, `BACKING`
- DECORATIVE: `LOGO_PATCH`, `DECOR_PANEL`, `BADGE`

**Response:**
```json
{
    "ok": true,
    "defects": [
        {
            "defect_code": "STITCH_UNEVEN",
            "display_name_th": "ตะเข็บไม่เท่ากัน",
            "severity": "minor",
            "allowed_component_types": ["STRAP", "BODY", "HANDLE"]
        }
    ]
}
```

---

### 4. Get Categories

List all defect categories.

**Request:**
```http
GET /source/defect_catalog_api.php?action=categories
```

**Response:**
```json
{
    "ok": true,
    "categories": [
        {
            "category_code": "STITCHING",
            "display_name_th": "ข้อบกพร่องการเย็บ",
            "display_name_en": "Stitching Defects",
            "display_order": 10
        },
        {
            "category_code": "GLUING",
            "display_name_th": "ข้อบกพร่องการทากาว",
            "display_name_en": "Gluing Defects",
            "display_order": 20
        }
    ]
}
```

**All Categories:**
| Code | Thai | English |
|------|------|---------|
| STITCHING | ข้อบกพร่องการเย็บ | Stitching Defects |
| GLUING | ข้อบกพร่องการทากาว | Gluing Defects |
| CUTTING | ข้อบกพร่องการตัด | Cutting Defects |
| EDGE | ข้อบกพร่องขอบ | Edge Defects |
| SURFACE | ข้อบกพร่องผิว | Surface Defects |
| ASSEMBLY | ข้อบกพร่องการประกอบ | Assembly Defects |
| HARDWARE | ข้อบกพร่องอุปกรณ์ | Hardware Defects |
| MATERIAL | ข้อบกพร่องวัสดุ | Material Defects |

---

### 5. Get Component Types

List available component types for filtering.

**Request:**
```http
GET /source/defect_catalog_api.php?action=component_types
```

**Response:**
```json
{
    "ok": true,
    "component_types": [
        {"type_code": "BODY", "type_name_th": "ตัวกระเป๋า", "type_name_en": "Body", "category": "MAIN"},
        {"type_code": "STRAP", "type_name_th": "สายสะพาย", "type_name_en": "Strap", "category": "ACCESSORY"}
    ]
}
```

---

### 6. Get Statistics

Get defect catalog statistics.

**Request:**
```http
GET /source/defect_catalog_api.php?action=statistics
```

**Response:**
```json
{
    "ok": true,
    "statistics": {
        "total": 36,
        "by_category": {
            "STITCHING": 6,
            "GLUING": 5,
            "CUTTING": 4,
            "EDGE": 5,
            "SURFACE": 4,
            "ASSEMBLY": 4,
            "HARDWARE": 4,
            "MATERIAL": 4
        },
        "by_severity": {
            "minor": 13,
            "major": 19,
            "critical": 4
        }
    }
}
```

---

### 7. Create Defect

Create a new defect entry.

**Request:**
```http
POST /source/defect_catalog_api.php
```

**Body (form-data):**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | string | Yes | `create` |
| `defect_code` | string | Yes | Unique code (uppercase, 3-50 chars) |
| `display_name_th` | string | Yes | Thai display name |
| `display_name_en` | string | Yes | English display name |
| `category_code` | string | Yes | Category code |
| `severity` | enum | Yes | `minor`, `major`, `critical` |
| `description_th` | string | No | Thai description |
| `description_en` | string | No | English description |
| `allowed_component_types` | JSON | No | Array of type codes, null for all |
| `rework_hints` | JSON | No | `{"suggested_operation": "...", "rework_level": "..."}` |
| `visual_guide_url` | string | No | URL to visual guide image |
| `display_order` | int | No | Sort order (default: 0) |

**Example:**
```json
{
    "action": "create",
    "defect_code": "CUSTOM_DEFECT_1",
    "display_name_th": "ข้อบกพร่องกำหนดเอง",
    "display_name_en": "Custom Defect",
    "category_code": "STITCHING",
    "severity": "minor",
    "allowed_component_types": "[\"BODY\",\"STRAP\"]",
    "rework_hints": "{\"suggested_operation\":\"STITCH\",\"rework_level\":\"same_piece\"}"
}
```

**Response:**
```json
{
    "ok": true,
    "id": 37,
    "message": "Defect created successfully."
}
```

---

### 8. Update Defect

Update an existing defect.

**Request:**
```http
POST /source/defect_catalog_api.php
```

**Body:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | string | Yes | `update` |
| `id` | int | Yes | Defect ID |
| `display_name_th` | string | Yes | Thai display name |
| `display_name_en` | string | Yes | English display name |
| `category_code` | string | Yes | Category code |
| `severity` | enum | Yes | `minor`, `major`, `critical` |
| ... | ... | ... | Same as create |

**Response:**
```json
{
    "ok": true,
    "message": "Defect updated successfully."
}
```

---

### 9. Delete (Deactivate) Defect

Soft-delete a defect by setting `is_active = 0`.

**Request:**
```http
POST /source/defect_catalog_api.php
```

**Body:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | string | Yes | `delete` |
| `id` | int | Yes | Defect ID to deactivate |

**Response:**
```json
{
    "ok": true,
    "message": "Defect deactivated successfully."
}
```

---

### 10. Suggest Rework Targets

Get suggested rework nodes based on defect type.

**Request:**
```http
GET /source/defect_catalog_api.php?action=suggest_rework&defect_code=STITCH_BROKEN&anchor_slot=BODY
```

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | string | Yes | `suggest_rework` |
| `defect_code` | string | Yes | Defect code |
| `anchor_slot` | string | Yes | Component anchor slot |

**Response:**
```json
{
    "ok": true,
    "suggestions": {
        "suggested_operation": "STITCH",
        "rework_level": "same_piece",
        "hint_text": "Suggested: STITCH (Same piece)"
    }
}
```

---

## Error Responses

All errors follow this format:

```json
{
    "ok": false,
    "error": "Error message here",
    "app_code": "DEFECT_001"
}
```

**Common Error Codes:**
| Code | Description |
|------|-------------|
| 400 | Bad Request - Missing or invalid parameters |
| 403 | Forbidden - Permission denied |
| 404 | Not Found - Defect/Category not found |
| 409 | Conflict - Duplicate defect_code |
| 500 | Server Error |

---

## Rate Limiting

- **Limit:** 60 requests per minute per user
- **Header:** `X-RateLimit-Remaining` shows remaining requests

---

## Permissions

| Action | Required Permission |
|--------|---------------------|
| list, get, categories, statistics | `defect.catalog.view` |
| create, update, delete | `defect.catalog.manage` |

---

## Related Files

- **Service:** `source/BGERP/Service/DefectCatalogService.php`
- **Migration:** `database/tenant_migrations/2025_12_defect_catalog.php`
- **Admin UI:** `page/defect_catalog.php`, `views/defect_catalog.php`
- **JS:** `assets/javascripts/defect_catalog/defect_catalog.js`
- **QC Component:** `assets/javascripts/qc/defect_selector.js`

---

## Usage Examples

### JavaScript - Admin UI
```javascript
// Load all defects
$.get('source/defect_catalog_api.php', {action: 'list', grouped: true}, function(resp) {
    if (resp.ok) console.log(resp.defects);
});

// Get defects for STRAP component
$.get('source/defect_catalog_api.php', {
    action: 'for_component_type',
    type_code: 'STRAP'
}, function(resp) {
    if (resp.ok) console.log(resp.defects);
});
```

### JavaScript - QC Form (DefectSelector)
```javascript
// Initialize defect selector in QC form
const selector = new DefectSelector('#defect-container', {
    typeCode: 'BODY',  // Filter by component type
    grouped: true,
    onSelect: function(defect) {
        console.log('Selected:', defect.defect_code, defect.severity);
    }
});

// Get selected defect
const selected = selector.getSelectedDefect();
```

### PHP - Service Layer
```php
use BGERP\Service\DefectCatalogService;

$service = new DefectCatalogService($tenantDb);

// Get all defects
$defects = $service->getAll();

// Filter by component type
$strapDefects = $service->getDefectsForComponentType('STRAP');

// Get rework hints
$hints = $service->getReworkHints('STITCH_BROKEN');
```

---

## Severity Reference

| Level | Code | Description | Example |
|-------|------|-------------|---------|
| 🟢 | `minor` | Cosmetic issues, not affecting function | Uneven stitching, visible glue |
| 🟡 | `major` | Functional issues, needs correction | Loose stitching, weak bond |
| 🔴 | `critical` | Safety/structural issues, immediate fix | Broken stitching, missing hardware |

