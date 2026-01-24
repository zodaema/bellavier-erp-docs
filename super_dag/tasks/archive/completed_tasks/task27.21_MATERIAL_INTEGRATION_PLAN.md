# Task 27.21: Material Integration Plan

> **Created:** December 6, 2025  
> **Updated:** December 8, 2025  
> **Status:** ✅ COMPLETED  
> **Priority:** HIGH  
> **Completed Duration:** ~20 hours  
> **Prerequisites:** Task 27.18 (Material Requirement Backend) ✅

---

## ✅ COMPLETION SUMMARY (Dec 8, 2025)

**All phases completed successfully!**

| Phase | Description | Status |
|-------|-------------|--------|
| Phase 0 | MaterialResolver Consolidation | ✅ DONE |
| Phase 1 | Material Check Panel | ✅ DONE |
| Phase 2 | Reserve on Create | ✅ DONE |

### Deliverables Completed:

**Database Tables Created:**
- `material_requirement` - Requirements per job
- `material_reservation` - Soft-lock inventory
- `material_requirement_log` - Audit trail
- `material_allocation` - Token-level allocation

**Services Implemented:**
- `MaterialRequirementService` - Calculation & availability
- `MaterialReservationService` - Reserve/release logic
- `MaterialAllocationService` - Token allocation

**API Endpoints (source/material_requirement_api.php):**
- `calculate_requirements` - Calculate BOM for job
- `get_requirements` - Get job requirements
- `check_availability` - Check stock
- `calculate_can_produce` - Max producible qty
- `check_shortage` - Shortage analysis
- `get_product_bom` - Get BOM via component path
- `create_reservations` - Reserve materials
- `release_reservations` - Release on cancel
- `get_consumption_log` - Consumption audit

**Integration Points:**
- Product Readiness check before BOM calculation
- Job status `pending_materials` support
- Token-level material tracking

---

## 🚨 CRITICAL DISCOVERY (Dec 7, 2025)

### ปัญหาที่พบจาก Task 27.20 (Work Modal)

**`MaterialResolver` (Task 13.13) มีปัญหา 2 ประการ:**

#### 1. ใช้ Legacy BOM Path
```
Current Path (Wrong):
Token → Job Ticket → Product → bom → bom_line → Material

Should Use (Correct):
Token → Job Ticket → Product → product_component → product_component_material
```

**ผลกระทบ:** CUT Behavior ใน Work Modal ไม่สามารถแสดง Leather Sheet ได้ เพราะ `bom` table ไม่มีข้อมูล (ข้อมูลจริงอยู่ใน `product_component_material`)

#### 2. Wrong Assumption: 1 Token = 1 Material
```
❌ MaterialResolver.resolvePrimaryLeatherSkuForToken() returns: string|null (1 SKU)

✅ Reality: กระเป๋า 1 ใบ (1 Token) ต้องตัดหลาย Material:
   ├── BODY: LEA-VEG-001 (0.8 sqft)
   ├── STRAP: LEA-VEG-001 (0.3 sqft)
   ├── FLAP: LEA-VEG-001 (0.2 sqft)
   └── LINING: FAB-COTTON-001 (1.0 sqft)
```

### แนวทางแก้ไข (Phase 0 - NEW)

1. **Deprecate `MaterialResolver`** (Task 13.13)
2. **Add `getMaterialsForToken()` in `MaterialRequirementService`** (Task 27.18)
   - Return: `array` of materials (not single SKU)
   - Use: `product_component_material` (Layer 3)
3. **Update CUT Behavior UI** to display multiple materials  

---

## ⚠️ MANDATORY GUARDRAILS

> **ต้องอ่านและปฏิบัติตามเอกสารต่อไปนี้ก่อนเริ่มงาน:**

### 📘 Required Reading

| Document | Path | Purpose |
|----------|------|---------|
| **Developer Policy** | `docs/developer/01-policy/DEVELOPER_POLICY.md` | กฎหลักการพัฒนา, Forbidden Changes |
| **API Development Guide** | `docs/developer/chapters/06-api-development-guide.md` | โครงสร้าง API มาตรฐาน |
| **System Wiring Guide** | `docs/developer/SYSTEM_WIRING_GUIDE.md` | การเชื่อมต่อระบบ, DO NOT TOUCH Zones |

### 🔒 Critical Rules (MUST FOLLOW)

1. **API Structure:**
   - ✅ ใช้ `TenantApiBootstrap::init()` สำหรับ Tenant APIs
   - ✅ ใช้ `json_success()` / `json_error()` สำหรับ JSON response (ตาม API Development Guide)
   - ✅ ใส่ Rate Limiting: `RateLimiter::check($member, 120, 60, 'endpoint_name')`
   - ✅ ใช้ `RequestValidator::make()` สำหรับ input validation

2. **Security:**
   - ✅ 100% Prepared Statements (NO string concatenation in SQL)
   - ✅ Input Validation ก่อนประมวลผล
   - ✅ ห้าม log sensitive data
   - ✅ ใช้ `must_allow_code($member, 'permission.code')` สำหรับ permission check

3. **JSON Format (Standard):**
   ```json
   // Success
   {"ok": true, "data": {...}}
   
   // Error  
   {"ok": false, "error": "message", "app_code": "MODULE_CODE"}
   ```

4. **Forbidden Changes:**
   - ❌ ห้ามแก้ไข Bootstrap signature
   - ❌ ห้ามแก้ไข Permission logic ใน `BGERP\Security\PermissionHelper`
   - ❌ ห้ามแก้ไข JSON format โดยไม่มี Task approval

5. **System Wiring:**
   - ✅ ต้องเข้าใจ "Bloodline" ก่อนแก้ไข: Product → BOM → Routing → MO → Job Tickets
   - ✅ Never break a bloodline
   - ✅ ใช้ Canonical Event System สำหรับ DAG operations

6. **Product Readiness Integration:**
   - ✅ ก่อนคำนวณ BOM ต้องเช็ค Product Readiness ก่อน
   - ✅ ใช้ `ProductReadinessService::getProductReadiness($productId)`
   - ✅ ถ้า Product ไม่พร้อม → block Job Creation + แจ้ง error

6. **i18n (Internationalization):**
   - ✅ Default language ในโค้ด = **English**
   - ✅ ใช้ `translate('key', 'Default English Text')` สำหรับ PHP
   - ✅ ใช้ `t('key', 'Default English Text')` สำหรับ JavaScript
   - ✅ เพิ่ม translation keys ใน `lang/th.php` และ `lang/en.php`
   - ❌ ห้าม hardcode ภาษาไทยในโค้ดโดยตรง!

   **ตัวอย่าง:**
   ```php
   // PHP - ถูก ✅
   json_error(translate('material.shortage', 'Material shortage'), 400);
   
   // PHP - ผิด ❌
   json_error('วัสดุไม่เพียงพอ', 400);
   ```
   
   ```javascript
   // JS - ถูก ✅
   notifyError(t('material.shortage', 'Material shortage'));
   
   // JS - ผิด ❌
   notifyError('วัสดุไม่เพียงพอ');
   ```

---

## 📌 Executive Summary

เป็นการ **เชื่อม Material Requirement เข้ากับ MO/Job Creation และ Job Execution** เพื่อให้:
- ผู้ใช้เห็นทันทีว่า "ผลิตได้กี่ใบ" ตอนสร้าง Job
- ระบบ **จองวัสดุตั้งแต่ตอนสร้าง Job** (ไม่ใช่ตอน Start)
- ระบบบล็อกการ Start Job ถ้าวัสดุไม่พอ
- Job Ticket แสดงวัสดุที่ Reserve/Consumed

---

## 🧠 Core Concepts (ต้องเข้าใจก่อนเริ่มงาน)

### 1. Material Requirement Path (สายเลือด)

```
Product → Component Mapping → Product Components → BOM (วัสดุ)
         ↓
    anchor_slot → id_product_component → product_component_material
```

**ห้าม** อ่าน Material ตรงจาก Product อย่างเดียว!  
**ต้อง** ผ่าน Component Mapping → Product Components → BOM เสมอ

### 2. Inventory Variables (ตัวแปรสำคัญ)

| Variable | คำอธิบาย |
|----------|---------|
| `on_hand` | ของที่มีจริงในสต็อก |
| `reserved` | ของที่ถูกจองให้ Job แล้ว |
| `consumed` | ของที่ใช้ไปจริงแล้ว (ตัดหนัง/ใช้กาวไปแล้ว) |
| **`available_for_new_jobs`** | = `on_hand - reserved` ← **ใช้คำนวณว่าเปิดงานใหม่ได้ไหม** |

### 3. Hatthasilpa Job = Production Batch (ไม่ใช่ 1 Job = 1 ใบ)

```
Hatthasilpa Job:
├── qty_target = 20 ใบ
├── BOM per 1 ใบ → x 20 = BOM per Job
├── ระบบสร้าง 20 tokens (serial numbers) ให้อัตโนมัติ
└── Material Requirement คิดจาก (product_id, qty_target)
```

### 4. Reservation Flow (จองตอนสร้าง ไม่ใช่ตอน Start)

```
┌──────────────────────────────────────────────────────────────┐
│ ทำไมต้องจองตอนสร้าง Job?                                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ❌ ถ้าจองตอน Start:                                         │
│     - กด Start พร้อมกัน 2 งาน → แย่งวัสดุกัน                  │
│     - Planner ไม่รู้ล่วงหน้าว่าจะเปิดได้กี่งาน                 │
│                                                              │
│  ✅ ถ้าจองตอนสร้าง Job:                                       │
│     - งานที่สร้างก่อน จองก่อน                                 │
│     - งานที่มาทีหลัง เห็นว่า "ของไม่พอ" ตั้งแต่ตอนกด Create    │
│     - กด Start พร้อมกัน 2 งาน → ไม่แย่งกัน (จองไว้แล้ว)       │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 5. Stock Lifecycle (⚡ POLICY ที่ฟันธงแล้ว)

```
┌──────────────────────────────────────────────────────────────┐
│ 📌 PARTIAL RESERVE POLICY (ฟันธงชัดเจน)                       │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ✅ ถ้าของ "พอครบทุกรายการ":                                  │
│     → status = 'pending'                                     │
│     → จองเต็มจำนวนตาม BOM ทั้งหมด                            │
│     → Start button ENABLED                                   │
│                                                              │
│  ⚠️ ถ้าของ "ไม่พออย่างน้อย 1 รายการ":                        │
│     → จองเท่าที่มี (partial) สำหรับของที่พอ                   │
│     → status = 'pending_materials'                           │
│     → Start button DISABLED จนกว่า shortage = 0              │
│                                                              │
│  📍 KEY RULE:                                                │
│     - Partial reserve = "จองของที่มีอยู่จริง" เท่านั้น         │
│     - อนุญาตให้ Start = เมื่อ shortage = 0 เท่านั้น          │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

**Stock Lifecycle:**

```
ตอนสร้าง Job:
├── เช็ค: available_for_new_jobs = on_hand - reserved
├── ถ้าพอครบ → Job status = 'pending' + จองเต็ม 100%
└── ถ้าไม่พอ → Job status = 'pending_materials' + จองเท่าที่มี

ตอนผ่าน Node ที่ใช้วัสดุ (เช่น CUT):
├── reserved → consumed (ย้ายสถานะ)
└── on_hand ลดลง ← ⚠️ ลดเฉพาะตอน CONSUME เท่านั้น (ไม่ใช่ตอน reserve!)

ตอน Cancel Job:
└── ปลด reservation ทันที (คืนกลับ available)
```

**⚠️ สำคัญมาก: on_hand Logic**
```
❌ ห้าม: ลด on_hand ตอน reserve (จองอย่างเดียว ไม่หักของ)
✅ ถูก:  ลด on_hand ตอน consume เท่านั้น (ใช้ของจริงแล้ว)

เหตุผล: ป้องกัน "หักสองรอบ" ทำให้ stock ติดลบ
```

---

## 🎯 Objectives

1. **Material Check Panel** - แสดง "ผลิตได้กี่ใบ" + Shortage ใน Form สร้าง MO/Job
2. **Reserve on Create** - จองวัสดุตอนสร้าง Job (ไม่ใช่ตอน Start)
3. **Status "pending_materials"** - สถานะใหม่สำหรับ Job ที่รอวัสดุ
4. **Block Start** - ปุ่ม Start ถูก disable ถ้าวัสดุไม่พอ
5. **Materials Tab** - แสดงวัสดุที่ Reserved/Consumed ใน Job Ticket

---

## 🏗️ Architecture

### Data Flow (Material Requirement Path)

```
┌────────────────────────────────────────────────────────────────┐
│              MATERIAL REQUIREMENT DATA PATH                     │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  product (id_product)                                          │
│       │                                                        │
│       ▼                                                        │
│  graph_component_mapping                                       │
│  (id_product, id_graph, anchor_slot, id_product_component)     │
│       │                                                        │
│       ▼                                                        │
│  product_component                                             │
│  (id_product_component, component_type_code, component_name)   │
│       │                                                        │
│       ▼                                                        │
│  product_component_material                                    │
│  (id_product_component, id_material, quantity_per_unit, uom)   │
│       │                                                        │
│       ▼                                                        │
│  BOM per 1 piece → x qty_target = BOM per Job                  │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### UI Flow

```
┌────────────────────────────────────────────────────────────────┐
│                    MATERIAL INTEGRATION FLOW                    │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  [MO/Job Creation Form]                                        │
│  ├── Select Product                                            │
│  ├── Enter Quantity (เช่น 20 ใบ) ──────────────────────────┐   │
│  │                                                         │   │
│  │  ┌─────────────────────────────────────────────────┐   │   │
│  │  │ 📊 Material Check Panel (Real-time)             │◄──┘   │
│  │  │                                                 │       │
│  │  │  คำนวณจาก: available = on_hand - reserved       │       │
│  │  │                                                 │       │
│  │  │  ✅ Green Tea Leather   10 sq.ft → Need 16      │       │
│  │  │     (0.8 sq.ft/ใบ x 20 ใบ)                      │       │
│  │  │  ⚠️ Gold Zipper         5 pcs   → Need 20      │       │
│  │  │     (1 pcs/ใบ x 20 ใบ) → ขาด 15 pcs            │       │
│  │  │  ✅ Cotton Lining       30 m    → Need 10      │       │
│  │  │                                                 │       │
│  │  │  📦 ผลิตได้สูงสุด: 5 ใบ (Bottleneck: Zipper)    │       │
│  │  │                                                 │       │
│  │  │  [Download Purchase List]                       │       │
│  │  └─────────────────────────────────────────────────┘       │
│  │                                                             │
│  └── [Create Job] ─────────────────────────────────────────────┤
│                                                                │
│  ON CREATE (ไม่ใช่ on Start!):                                  │
│  ├── คำนวณ BOM x qty_target                                    │
│  ├── เช็ค available_for_new_jobs = on_hand - reserved          │
│  │                                                             │
│  IF พอ:                                                        │
│  ├── Job.status = 'pending' (normal)                           │
│  ├── สร้าง material_reservation (จองทั้งหมด)                   │
│  └── Start button ENABLED                                      │
│                                                                │
│  IF ไม่พอ:                                                     │
│  ├── Job.status = 'pending_materials'                          │
│  ├── สร้าง material_reservation (จองเท่าที่มี / optional)      │
│  └── Start button DISABLED until sufficient                   │
│                                                                │
│  ON CANCEL:                                                    │
│  └── ปลด reservation ทันที (คืน available)                     │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### Consumption Flow (ตอนผ่าน Node ที่ใช้วัสดุ)

```
┌────────────────────────────────────────────────────────────────┐
│              MATERIAL CONSUMPTION FLOW                          │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Token ผ่าน Node ที่ใช้วัสดุ (เช่น CUT)                         │
│       │                                                        │
│       ▼                                                        │
│  BehaviorExecutionService::handleCUT()                         │
│       │                                                        │
│       ├── qty_produced = 5 (จาก Operator input)                │
│       ├── qty_scrapped = 1 (waste)                             │
│       │                                                        │
│       ▼                                                        │
│  MaterialAllocationService::consumeMaterial()                  │
│       │                                                        │
│       ├── reserved → consumed (ย้ายสถานะ)                      │
│       ├── on_hand -= qty_consumed                              │
│       └── Log to material_requirement_log                      │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

---

## 📂 Phase 0: MaterialResolver Consolidation (2-3 hours) ✅ COMPLETED

> **Priority:** 🔴 CRITICAL - ต้องทำก่อน Phase 1  
> **Blocker for:** Task 27.20 (CUT Behavior UI)
> **Completed:** December 8, 2025

### 0.1 Problem Statement

`MaterialResolver` (Task 13.13) ถูกสร้างขึ้นเพื่อ resolve leather material SKU สำหรับ Token แต่มีปัญหา:

1. **ใช้ Legacy BOM Path:** `bom` + `bom_line` (ไม่มีข้อมูล)
2. **Wrong Assumption:** Return แค่ 1 SKU แต่จริงๆ 1 Token ต้องใช้หลาย Materials

### 0.2 Solution

**Deprecate `MaterialResolver` → Add method ใน `MaterialRequirementService`**

| File | Action |
|------|--------|
| `MaterialResolver.php` | Mark as `@deprecated` |
| `MaterialRequirementService.php` | Add `getMaterialsForToken()` method |
| `leather_sheet_api.php` | Update to use new method |
| `behavior_execution.js` (CUT) | Update UI to support multiple materials |

### 0.3 New Method in MaterialRequirementService

```php
/**
 * Get all materials required for a single token
 * 
 * Uses product_component_material (Layer 3) - NOT legacy bom/bom_line
 * 
 * @param int $tokenId Token ID
 * @return array List of materials with quantities
 */
public function getMaterialsForToken(int $tokenId): array
{
    // 1. Get token → job → product
    $token = $this->getTokenDetails($tokenId);
    if (!$token) {
        return [];
    }
    
    $productId = (int)$token['id_product'];
    
    // 2. Get ALL materials from product_component_material (Layer 3)
    $materials = $this->dbHelper->fetchAll("
        SELECT 
            pcm.material_sku,
            m.name_th AS material_name,
            m.category,
            pc.component_name,
            pc.component_type_code,
            pcm.qty_required AS qty_per_token,
            pcm.uom_code
        FROM product_component pc
        JOIN product_component_material pcm ON pcm.id_product_component = pc.id_product_component
        LEFT JOIN material m ON m.sku = pcm.material_sku AND m.is_active = 1
        WHERE pc.id_product = ?
        ORDER BY pc.component_type_code, pcm.priority
    ", [$productId], 'i');
    
    return $materials;
}

/**
 * Get primary leather material SKU for a token (backward compatible)
 * 
 * @deprecated Use getMaterialsForToken() instead
 * @param int $tokenId Token ID
 * @return string|null First leather material SKU or null
 */
public function resolvePrimaryLeatherSkuForToken(int $tokenId): ?string
{
    $materials = $this->getMaterialsForToken($tokenId);
    
    // Filter leather materials
    foreach ($materials as $mat) {
        if (stripos($mat['category'] ?? '', 'leather') !== false) {
            return $mat['material_sku'];
        }
    }
    
    // Fallback: return first material if no leather found
    return $materials[0]['material_sku'] ?? null;
}
```

### 0.4 Update leather_sheet_api.php

```php
// Before (using MaterialResolver - Legacy)
$materialSku = MaterialResolver::resolvePrimaryLeatherSkuForToken($tenantDb, $tokenId);

// After (using MaterialRequirementService - Layer 3)
$materialService = new MaterialRequirementService($tenantDb);
$materials = $materialService->getMaterialsForToken($tokenId);

// Filter leather materials for sheet selection
$leatherMaterials = array_filter($materials, function($m) {
    return stripos($m['category'] ?? '', 'leather') !== false;
});
```

### 0.5 Testing Checklist

- [x] `getMaterialsForToken()` returns all materials for product ✅
- [x] Materials come from `product_component_material` (Layer 3) ✅
- [x] CUT Behavior UI shows leather materials ✅
- [x] Backward compatibility: `resolvePrimaryLeatherSkuForToken()` still works ✅
- [x] `MaterialResolver` marked as deprecated ✅

### 0.6 Files to Modify

| File | Changes |
|------|---------|
| `source/BGERP/Service/MaterialRequirementService.php` | Add `getMaterialsForToken()`, `resolvePrimaryLeatherSkuForToken()` |
| `source/BGERP/Helper/MaterialResolver.php` | Add `@deprecated` comment |
| `source/leather_sheet_api.php` | Update to use `MaterialRequirementService` |
| `assets/javascripts/dag/behavior_execution.js` | Update CUT handler for multiple materials |

---

## 📂 Phase 1: Material Check Panel (8-10 hours) ✅ COMPLETED

> **Completed:** December 2025

### 1.1 API Endpoints

**File:** `source/material_requirement_api.php` ✅ IMPLEMENTED

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `calculate_can_produce` | GET | คำนวณผลิตได้สูงสุดกี่ใบ |
| `check_shortage` | POST | เช็คว่าผลิต X ใบ ขาดอะไรบ้าง |

```php
// calculate_can_produce
// Input: product_id
// Output: { can_produce: 5, bottleneck: { material_id, name, available, need_per_unit } }

case 'calculate_can_produce':
    $productId = (int)($_GET['product_id'] ?? 0);
    if ($productId <= 0) {
        json_error(translate('material.error.missing_product', 'Product ID required'), 400, 
            ['app_code' => 'MAT_400_MISSING_PRODUCT']);
    }
    
    // 🔒 Product Readiness Check (จาก Task 27.19)
    $readinessService = new \BGERP\Service\ProductReadinessService($tenantDb);
    $readiness = $readinessService->getProductReadiness($productId);
    if (!$readiness['is_ready']) {
        json_error(translate('product.error.not_ready', 'Product configuration incomplete'), 400,
            ['app_code' => 'MAT_400_PRODUCT_NOT_READY', 'readiness' => $readiness]);
    }
    
    $service = new \BGERP\Service\MaterialRequirementService($tenantDb);
    $result = $service->calculateMaxProducible($productId);
    
    json_success($result);
    break;
```

```php
// check_shortage
// Input: { product_id, quantity }
// Output: { 
//   materials: [{ id, name, available, required, shortage, status }],
//   can_produce: bool,
//   total_shortage_count: int
// }

case 'check_shortage':
    $validation = RequestValidator::make($_POST, [
        'product_id' => 'required|integer|min:1',
        'quantity' => 'required|integer|min:1'
    ]);
    
    if (!$validation['valid']) {
        $firstError = $validation['errors'][0] ?? null;
        json_error($firstError['message'] ?? translate('common.error.validation', 'Validation failed'), 400, [
            'app_code' => 'MAT_400_VALIDATION',
            'errors' => $validation['errors']
        ]);
    }
    
    $data = $validation['data'];
    
    // 🔒 Product Readiness Check
    $readinessService = new \BGERP\Service\ProductReadinessService($tenantDb);
    $readiness = $readinessService->getProductReadiness($data['product_id']);
    if (!$readiness['is_ready']) {
        json_error(translate('product.error.not_ready', 'Product configuration incomplete'), 400,
            ['app_code' => 'MAT_400_PRODUCT_NOT_READY']);
    }
    
    $service = new \BGERP\Service\MaterialRequirementService($tenantDb);
    $result = $service->checkShortageForQuantity($data['product_id'], $data['quantity']);
    
    json_success($result);
    break;
```

### 1.2 Service Methods

**File:** `source/BGERP/Service/MaterialRequirementService.php` (existing)

```php
/**
 * ดึง BOM ผ่าน Component Mapping Path
 * 
 * Path: Product → Component Mapping → Product Components → BOM
 * 
 * @param int $productId
 * @return array [ { material_id, material_name, quantity_per_unit, uom, component_name } ]
 */
public function getBOMViaComponentMapping(int $productId): array
{
    // 1. Get graph binding for product
    $graphId = $this->getGraphIdForProduct($productId);
    
    // 2. Get component mappings (anchor_slot → id_product_component)
    // SELECT gcm.id_product_component, pc.component_name
    // FROM graph_component_mapping gcm
    // JOIN product_component pc ON pc.id_product_component = gcm.id_product_component
    // WHERE gcm.id_product = ? AND gcm.id_graph = ?
    
    // 3. Get materials for each product_component
    // SELECT pcm.id_material, m.name, pcm.quantity_per_unit, pcm.uom_code
    // FROM product_component_material pcm
    // JOIN materials m ON m.id = pcm.id_material
    // WHERE pcm.id_product_component IN (...)
    
    // 4. Aggregate by material (same material from different components)
    // Return: [ { material_id, material_name, total_per_unit, uom, components: [...] } ]
}

/**
 * คำนวณ Available Stock (on_hand - reserved)
 * 
 * @param int $materialId
 * @return float available_for_new_jobs
 */
public function getAvailableStock(int $materialId): float
{
    // SELECT 
    //   COALESCE(SUM(on_hand), 0) as on_hand,
    //   COALESCE((SELECT SUM(quantity) FROM material_reservation WHERE material_id = ? AND status = 'active'), 0) as reserved
    // FROM inventory WHERE material_id = ?
    
    // return on_hand - reserved
}

/**
 * คำนวณจำนวนสูงสุดที่ผลิตได้
 * 
 * @param int $productId
 * @return array { can_produce, bottleneck, materials }
 */
public function calculateMaxProducible(int $productId): array
{
    // 1. Get BOM via Component Mapping path (not direct!)
    $bom = $this->getBOMViaComponentMapping($productId);
    
    // 2. For each material, get available_for_new_jobs = on_hand - reserved
    foreach ($bom as &$item) {
        $item['available'] = $this->getAvailableStock($item['material_id']);
        $item['max_producible'] = floor($item['available'] / $item['quantity_per_unit']);
    }
    
    // 3. Find bottleneck (material with lowest max_producible)
    $bottleneck = min(array_column($bom, 'max_producible'));
    
    // 4. Return result
    return [
        'can_produce' => $bottleneck,
        'bottleneck' => $this->findBottleneckMaterial($bom),
        'materials' => $bom
    ];
}

/**
 * เช็ค shortage สำหรับจำนวนที่ต้องการ (Batch)
 * 
 * @param int $productId
 * @param int $qtyTarget  ← จำนวน batch (เช่น 20 ใบ)
 * @return array { materials, can_produce, total_shortage_count }
 */
public function checkShortageForQuantity(int $productId, int $qtyTarget): array
{
    // 1. Get BOM via Component Mapping path
    $bom = $this->getBOMViaComponentMapping($productId);
    
    // 2. For each material:
    foreach ($bom as &$item) {
        $item['available'] = $this->getAvailableStock($item['material_id']);
        $item['required'] = $item['quantity_per_unit'] * $qtyTarget;  // BOM x qty_target
        $item['shortage'] = max(0, $item['required'] - $item['available']);
        $item['status'] = $item['shortage'] > 0 ? 'shortage' : 'ok';
    }
    
    // 3. Summary
    $shortageCount = count(array_filter($bom, fn($m) => $m['shortage'] > 0));
    
    return [
        'materials' => $bom,
        'can_produce' => $shortageCount === 0,
        'total_shortage_count' => $shortageCount
    ];
}

/**
 * เช็ค shortage WITH LOCK (สำหรับ Job Creation)
 * 
 * ⚠️ ใช้เฉพาะใน Transaction เท่านั้น!
 * ป้องกัน race condition เมื่อสร้าง 2 Job พร้อมกัน
 * 
 * @param int $productId
 * @param int $qtyTarget
 * @return array Same as checkShortageForQuantity
 */
public function checkShortageForQuantityWithLock(int $productId, int $qtyTarget): array
{
    // 1. Get BOM via Component Mapping path
    $bom = $this->getBOMViaComponentMapping($productId);
    
    // 2. For each material - WITH LOCK:
    foreach ($bom as &$item) {
        // ⚠️ SELECT ... FOR UPDATE เพื่อ lock แถวจนกว่า transaction จบ
        $item['available'] = $this->getAvailableStockWithLock($item['material_id']);
        $item['required'] = $item['quantity_per_unit'] * $qtyTarget;
        $item['shortage'] = max(0, $item['required'] - $item['available']);
        $item['status'] = $item['shortage'] > 0 ? 'shortage' : 'ok';
    }
    
    $shortageCount = count(array_filter($bom, fn($m) => $m['shortage'] > 0));
    
    return [
        'materials' => $bom,
        'can_produce' => $shortageCount === 0,
        'total_shortage_count' => $shortageCount
    ];
}

/**
 * Get available stock WITH ROW LOCK
 */
private function getAvailableStockWithLock(int $materialId): float
{
    // SELECT ... FOR UPDATE locks the row until COMMIT/ROLLBACK
    $sql = "
        SELECT 
            COALESCE(SUM(on_hand), 0) as on_hand,
            COALESCE((SELECT SUM(quantity) FROM material_reservation 
                      WHERE material_id = ? AND status = 'active'), 0) as reserved
        FROM inventory 
        WHERE material_id = ?
        FOR UPDATE
    ";
    // ... execute and return on_hand - reserved
}
```

### 1.3 UI Integration

**Files to modify:**
- `assets/javascripts/hatthasilpa/jobs.js` (Hatthasilpa Job creation)
- `views/hatthasilpa_jobs.php` (Add Material Check Panel HTML)

```javascript
// jobs.js - Material Check Panel

// Trigger on product or quantity change
$('#atelier_product, #quantity').on('change', debounce(function() {
    const productId = $('#atelier_product').val();
    const quantity = $('#quantity').val() || 0;
    
    if (productId && quantity > 0) {
        checkMaterialShortage(productId, quantity);
    } else if (productId) {
        calculateCanProduce(productId);
    }
}, 300));

async function calculateCanProduce(productId) {
    const resp = await $.get('source/material_requirement_api.php', {
        action: 'calculate_can_produce',
        product_id: productId
    });
    
    if (resp.ok) {
        renderCanProduceSummary(resp.data);
    }
}

async function checkMaterialShortage(productId, quantity) {
    const resp = await $.post('source/material_requirement_api.php', {
        action: 'check_shortage',
        product_id: productId,
        quantity: quantity
    });
    
    if (resp.ok) {
        renderMaterialCheckPanel(resp.data);
    }
}

function renderMaterialCheckPanel(data) {
    const $panel = $('#material-check-panel');
    
    // 📌 i18n: ใช้ t() function สำหรับทุก user-facing string
    let html = '<div class="card border-info mb-3"><div class="card-body">';
    html += `<h6 class="card-title"><i class="ri-box-3-line"></i> ${t('material.check.title', 'Material Check')}</h6>`;
    
    // Material list
    html += '<table class="table table-sm mb-2">';
    html += `<thead><tr>
        <th>${t('material.column.name', 'Material')}</th>
        <th>${t('material.column.available', 'Available')}</th>
        <th>${t('material.column.required', 'Required')}</th>
        <th>${t('material.column.status', 'Status')}</th>
    </tr></thead>`;
    html += '<tbody>';
    
    data.materials.forEach(m => {
        const statusBadge = m.shortage > 0 
            ? `<span class="badge bg-danger">${t('material.status.shortage', 'Shortage')}: ${m.shortage} ${m.uom}</span>`
            : `<span class="badge bg-success">✓ ${t('material.status.sufficient', 'Sufficient')}</span>`;
        
        html += `<tr>
            <td>${m.name}</td>
            <td>${m.available} ${m.uom}</td>
            <td>${m.required} ${m.uom}</td>
            <td>${statusBadge}</td>
        </tr>`;
    });
    
    html += '</tbody></table>';
    
    // Summary
    if (data.can_produce) {
        html += `<div class="alert alert-success mb-0">✅ ${t('material.summary.ready', 'Materials sufficient. Ready to produce.')}</div>`;
    } else {
        html += `<div class="alert alert-warning mb-0">
            ⚠️ ${t('material.summary.shortage', 'Insufficient materials')} (${data.total_shortage_count} ${t('common.items', 'items')})
            <br><small>${t('material.summary.pending_status', 'Job will be created with "Pending Materials" status')}</small>
        </div>`;
    }
    
    html += '</div></div>';
    
    $panel.html(html).show();
}
```

---

## 📂 Phase 1B: Status "pending_materials" + Block Start (4-6 hours)

### 1B.1 Job Creation Logic (Reserve on Create)

**File:** `source/hatthasilpa_jobs_api.php`

**⚠️ CRITICAL: Concurrency & Transaction Rules**
```
┌──────────────────────────────────────────────────────────────┐
│ 🔒 TRANSACTION & LOCKING REQUIREMENTS                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│ 1. การคำนวณ BOM + การจองวัสดุ ต้องอยู่ใน Transaction เดียว    │
│                                                              │
│ 2. การอ่าน stock เพื่อ available_for_new_jobs ต้องใช้:        │
│    SELECT ... FOR UPDATE                                     │
│    เพื่อกัน race condition ถ้าสร้าง 2 Job พร้อมกัน            │
│                                                              │
│ 3. ลำดับ: BEGIN → FOR UPDATE → check → reserve → COMMIT     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

```php
// In create_job action:

use BGERP\Service\MaterialRequirementService;
use BGERP\Service\MaterialReservationService;
use BGERP\Service\ProductReadinessService;
use BGERP\Service\DatabaseTransaction;

// 🔒 0. Product Readiness Check FIRST
$readinessService = new ProductReadinessService($tenantDb);
$readiness = $readinessService->getProductReadiness($productId);
if (!$readiness['is_ready']) {
    json_error(translate('product.error.not_ready', 'Product configuration incomplete'), 400,
        ['app_code' => 'JOB_400_PRODUCT_NOT_READY']);
}

$materialService = new MaterialRequirementService($tenantDb);
$reservationService = new MaterialReservationService($tenantDb);

// 1. Create job + reserve materials in SINGLE transaction
$transaction = new DatabaseTransaction($tenantDb);
$result = $transaction->execute(function($db) use ($productId, $qtyTarget, $materialService, $reservationService, $member) {
    
    // 1.1 Check material availability WITH LOCK (FOR UPDATE)
    // ⚠️ ต้องใช้ FOR UPDATE เพื่อกัน race condition
    $shortage = $materialService->checkShortageForQuantityWithLock($productId, $qtyTarget);
    
    // 1.2 Determine initial status
    $initialStatus = $shortage['can_produce'] ? 'pending' : 'pending_materials';
    
    // 1.3 Create job with appropriate status
    $stmt = $db->prepare("
        INSERT INTO hatthasilpa_job 
        (product_id, qty_target, status, created_by, created_at) 
        VALUES (?, ?, ?, ?, NOW())
    ");
    $stmt->bind_param('iisi', $productId, $qtyTarget, $initialStatus, $member['id_member']);
    $stmt->execute();
    $jobId = $db->insert_id;
    $stmt->close();
    
    // 1.4 Reserve materials (จองตั้งแต่ตอนสร้าง!)
    // 📌 POLICY: จองเท่าที่มี (partial reserve) ถ้าไม่พอ
    foreach ($shortage['materials'] as $material) {
        $reserveQty = min($material['required'], $material['available']);
        
        if ($reserveQty > 0) {
            $reservationService->createReservation(
                $jobId,
                $material['material_id'],
                $reserveQty,
                $member['id_member']
            );
        }
    }
    
    return [
        'job_id' => $jobId,
        'status' => $initialStatus,
        'shortage' => $shortage
    ];
});

// 2. Return response with reservation info
json_success([
    'job_id' => $result['job_id'],
    'status' => $result['status'],
    'materials_reserved' => $result['shortage']['can_produce'],
    'shortage_count' => $result['shortage']['total_shortage_count']
], 201);
```

### 1B.2 Cancel Job = Release Reservation

**File:** `source/hatthasilpa_jobs_api.php`

```php
// In cancel_job action:

case 'cancel_job':
    $jobId = (int)($_POST['job_id'] ?? 0);
    
    $transaction = new DatabaseTransaction($tenantDb);
    $transaction->execute(function($db) use ($jobId, $reservationService) {
        
        // 1. Update job status
        $stmt = $db->prepare("UPDATE hatthasilpa_job SET status = 'cancelled', cancelled_at = NOW() WHERE id = ?");
        $stmt->bind_param('i', $jobId);
        $stmt->execute();
        
        // 2. Release all reservations for this job (คืน available ทันที!)
        $reservationService->releaseAllForJob($jobId, 'job_cancelled');
    });
    
    json_success(['message' => 'Job cancelled and materials released']);
    break;
```

### 1B.2 Block Start Button

**File:** `assets/javascripts/hatthasilpa/jobs.js`

```javascript
// In job detail view:

function updateStartButton(job) {
    const $btnStart = $('#btn-start-job');
    
    if (job.status === 'pending_materials') {
        $btnStart.prop('disabled', true)
                 .addClass('btn-secondary')
                 .removeClass('btn-success')
                 .html(`<i class="ri-lock-line"></i> ${t('job.status.pending_materials', 'Waiting for materials')}`);
        
        // Show info tooltip (i18n)
        $btnStart.attr('title', t('job.tooltip.cannot_start_no_materials', 
            'Cannot start job. Insufficient materials.'));
    } else if (job.status === 'pending') {
        $btnStart.prop('disabled', false)
                 .addClass('btn-success')
                 .removeClass('btn-secondary')
                 .html(`<i class="ri-play-line"></i> ${t('job.action.start', 'Start Job')}`);
    }
}
```

### 1B.3 Auto-check on Inventory Update

**File:** `source/BGERP/Service/MaterialReservationService.php`

```php
/**
 * เมื่อ Inventory เปลี่ยน → เช็ค Jobs ที่รอวัสดุ
 * 
 * เรียกใช้เมื่อ:
 * - มีการรับ Material ใหม่เข้าสต็อก
 * - มีการ Cancel Job (ปลด reservation)
 * - มีการ manual adjust inventory
 */
public function recheckPendingMaterialJobs(): array
{
    // 1. Get all jobs with status = 'pending_materials'
    $pendingJobs = $this->db->fetchAll("
        SELECT j.id, j.product_id, j.qty_target
        FROM hatthasilpa_job j
        WHERE j.status = 'pending_materials'
        ORDER BY j.created_at ASC  -- FIFO: งานที่สร้างก่อน check ก่อน
    ");
    
    $updatedJobs = [];
    
    foreach ($pendingJobs as $job) {
        // 2. Check if materials now sufficient
        $shortage = $this->materialService->checkShortageForQuantity(
            $job['product_id'], 
            $job['qty_target']
        );
        
        if ($shortage['can_produce']) {
            // 3. Materials sufficient now!
            
            // 3.1 Reserve remaining materials
            foreach ($shortage['materials'] as $material) {
                $this->topUpReservation($job['id'], $material['material_id'], $material['required']);
            }
            
            // 3.2 Update job status
            $stmt = $this->db->prepare("UPDATE hatthasilpa_job SET status = 'pending' WHERE id = ?");
            $stmt->bind_param('i', $job['id']);
            $stmt->execute();
            
            $updatedJobs[] = $job['id'];
        }
    }
    
    return $updatedJobs;
}

/**
 * Top up reservation (เพิ่มจำนวนที่จองให้ครบ)
 */
private function topUpReservation(int $jobId, int $materialId, float $requiredQty): void
{
    // Get current reservation
    $current = $this->db->fetchOne("
        SELECT SUM(quantity) as reserved
        FROM material_reservation
        WHERE job_id = ? AND material_id = ? AND status = 'active'
    ", [$jobId, $materialId]);
    
    $currentReserved = $current['reserved'] ?? 0;
    $needMore = $requiredQty - $currentReserved;
    
    if ($needMore > 0) {
        $this->createReservation($jobId, $materialId, $needMore, null);
    }
}
```

### 1B.4 Stale Reservation Warning (Jobs ที่จองแล้วไม่เริ่ม)

```php
/**
 * เตือน Jobs ที่จองวัสดุไว้แล้วไม่เริ่มเกิน X วัน
 */
public function getStaleReservationJobs(int $daysThreshold = 7): array
{
    return $this->db->fetchAll("
        SELECT j.id, j.product_id, j.qty_target, j.created_at,
               DATEDIFF(NOW(), j.created_at) as days_pending,
               (SELECT SUM(quantity) FROM material_reservation WHERE job_id = j.id AND status = 'active') as reserved_qty
        FROM hatthasilpa_job j
        WHERE j.status IN ('pending', 'pending_materials')
          AND j.started_at IS NULL
          AND DATEDIFF(NOW(), j.created_at) > ?
        ORDER BY j.created_at ASC
    ", [$daysThreshold]);
}
```

---

## 📂 Phase 2: Job Material Consumption (4-6 hours) ✅ COMPLETED

> **Completed:** December 2025  
> **Services:** `MaterialReservationService`, `MaterialAllocationService`  
> **API Endpoints:** `create_reservations`, `release_reservations`, `get_consumption_log`

### 2.1 Materials Tab in Job Ticket

**File:** `views/hatthasilpa_jobs.php`

```html
<!-- Add new tab (i18n via PHP translate()) -->
<li class="nav-item" role="presentation">
    <button class="nav-link" id="materials-tab" data-bs-toggle="tab" 
            data-bs-target="#materials-content" type="button">
        <i class="ri-box-3-line"></i> <?= translate('job.tab.materials', 'Materials') ?>
    </button>
</li>

<!-- Tab content -->
<div class="tab-pane fade" id="materials-content">
    <div class="card">
        <div class="card-body">
            <h6><?= translate('job.materials.title', 'Materials used in this job') ?></h6>
            <table class="table table-sm" id="job-materials-table">
                <thead>
                    <tr>
                        <th><?= translate('material.column.name', 'Material') ?></th>
                        <th><?= translate('material.column.reserved', 'Reserved') ?></th>
                        <th><?= translate('material.column.consumed', 'Consumed') ?></th>
                        <th><?= translate('material.column.remaining', 'Remaining') ?></th>
                        <th><?= translate('material.column.status', 'Status') ?></th>
                    </tr>
                </thead>
                <tbody id="job-materials-tbody">
                    <!-- JS populate -->
                </tbody>
            </table>
        </div>
    </div>
</div>
```

### 2.2 Load Materials for Job

**File:** `assets/javascripts/hatthasilpa/jobs.js`

```javascript
async function loadJobMaterials(jobId) {
    const resp = await $.get('source/material_requirement_api.php', {
        action: 'get_job_materials',
        job_id: jobId
    });
    
    if (resp.ok) {
        renderJobMaterials(resp.data.materials);
    }
}

function renderJobMaterials(materials) {
    const $tbody = $('#job-materials-tbody');
    $tbody.empty();
    
    materials.forEach(m => {
        const remaining = m.reserved - m.consumed;
        const statusBadge = m.consumed >= m.reserved
            ? `<span class="badge bg-success">${t('material.status.fully_consumed', 'Fully consumed')}</span>`
            : `<span class="badge bg-info">${t('material.status.in_use', 'In use')}</span>`;
        
        $tbody.append(`
            <tr>
                <td>${m.material_name}</td>
                <td>${m.reserved} ${m.uom}</td>
                <td>${m.consumed} ${m.uom}</td>
                <td>${remaining} ${m.uom}</td>
                <td>${statusBadge}</td>
            </tr>
        `);
    });
}
```

---

## 📁 Files Summary

### New Files
- (None - use existing files)

### Modified Files

| File | Changes |
|------|---------|
| `source/material_requirement_api.php` | Add `calculate_can_produce`, `check_shortage`, `get_job_materials` |
| `source/BGERP/Service/MaterialRequirementService.php` | Add `calculateMaxProducible()`, `checkShortageForQuantity()` |
| `source/BGERP/Service/MaterialReservationService.php` | Add `recheckPendingMaterialJobs()` |
| `source/hatthasilpa_jobs_api.php` | Integrate material check in job creation |
| `assets/javascripts/hatthasilpa/jobs.js` | Add Material Check Panel, Block Start logic |
| `views/hatthasilpa_jobs.php` | Add Material Check Panel HTML, Materials Tab |

---

## 🧪 Testing Plan

### Unit Tests

```php
// tests/Unit/MaterialRequirementServiceTest.php

public function testCalculateMaxProducible(): void
{
    // Product with 3 components, each needs different materials
    // Assert: returns correct max based on bottleneck
}

public function testCheckShortageForQuantity(): void
{
    // Quantity 10, stock only for 5
    // Assert: returns shortage list with correct amounts
}

public function testRecheckPendingJobs(): void
{
    // Job with pending_materials status
    // Stock updated to sufficient
    // Assert: job status changes to pending
}
```

### Manual Testing

| Scenario | Expected Result |
|----------|-----------------|
| Create job, materials sufficient | Status = pending, Start enabled |
| Create job, materials insufficient | Status = pending_materials, Start disabled |
| Add stock to fulfill shortage | Status auto-changes to pending |
| Open Materials tab | Shows reserved/consumed/remaining |

---

## 🔥 Phase 3: Material Consumption on Node Complete (✅ COMPLETED)

> **Status:** ✅ COMPLETED (7 Dec 2025)  
> **Prerequisite:** Phase 1 & 2 complete  
> **Complexity:** HIGH (ต้อง integrate กับ DAG Token Execution)

### 3.1 Concept

เมื่อ Token ผ่าน Node ที่ใช้วัสดุ (เช่น CUT, SEWING):
1. ระบบต้องรู้ว่า Node นี้ใช้วัสดุอะไร (link via Component)
2. ลด `qty_consumed` ใน `material_requirement`
3. ลด `on_hand` ใน stock (`material_lot`)
4. Log event ไว้ใน `material_requirement_log`

### 3.2 Architecture Decision

**ทางเลือก A: Node-level Material Binding**
```
routing_node.anchor_slot → component_type_catalog.type_code
graph_component_mapping.anchor_slot → product_component.id_product_component  
product_component_material → material requirements
```

**ทางเลือก B: Behavior-based Consumption**
```
Node behavior = 'CUT' → consume materials for that component
behavior_code tells system what to consume
```

**⚡ RECOMMENDED:** ใช้ทางเลือก A เพราะ:
- มี data path พร้อมแล้ว (Component Mapping)
- Traceability ชัดเจน: Node → Component → Material

### 3.3 Service Methods to Add

**File:** `source/BGERP/Service/MaterialAllocationService.php`

```php
/**
 * Consume materials when token completes a node
 * 
 * Called from TokenExecutionService when token moves
 * 
 * @param int $tokenId Flow token ID
 * @param int $nodeId Routing node ID (destination)
 * @param int $jobTicketId Job ticket ID
 * @return array {success: bool, consumed: array}
 */
public function consumeOnNodeComplete(
    int $tokenId,
    int $nodeId,
    int $jobTicketId
): array {
    // 1. Get node's anchor_slot
    $node = $this->getNode($nodeId);
    if (!$node || empty($node['anchor_slot'])) {
        return ['success' => true, 'consumed' => [], 'reason' => 'no_anchor'];
    }
    
    // 2. Get component mapping for this job's product
    $job = $this->getJobTicket($jobTicketId);
    $productId = $job['id_product'];
    $graphId = $job['id_graph'];
    
    $mapping = $this->getComponentMapping($productId, $graphId, $node['anchor_slot']);
    if (!$mapping) {
        return ['success' => true, 'consumed' => [], 'reason' => 'no_mapping'];
    }
    
    // 3. Get materials for this component
    $componentId = $mapping['id_product_component'];
    $materials = $this->getComponentMaterials($componentId);
    
    // 4. Consume each material
    $consumed = [];
    foreach ($materials as $mat) {
        $result = $this->consumeMaterial(
            $jobTicketId,
            $tokenId,
            $mat['material_sku'],
            $mat['qty_per_component'],
            $mat['uom_code']
        );
        $consumed[] = $result;
    }
    
    return ['success' => true, 'consumed' => $consumed];
}

/**
 * Actually reduce stock and update requirement
 */
private function consumeMaterial(
    int $jobTicketId,
    int $tokenId,
    string $materialSku,
    float $qty,
    string $uomCode
): array {
    // Begin transaction
    $this->db->begin_transaction();
    
    try {
        // 1. Update material_requirement.qty_consumed
        $stmt = $this->db->prepare("
            UPDATE material_requirement 
            SET qty_consumed = qty_consumed + ?,
                status = CASE 
                    WHEN qty_consumed + ? >= qty_reserved THEN 'consumed'
                    ELSE status 
                END
            WHERE id_job_ticket = ? AND material_sku = ?
        ");
        $stmt->bind_param('ddis', $qty, $qty, $jobTicketId, $materialSku);
        $stmt->execute();
        $stmt->close();
        
        // 2. Reduce on_hand in material_lot (FIFO)
        // ⚠️ CRITICAL: Only reduce on_hand on CONSUME, not on RESERVE!
        $this->reduceStockFIFO($materialSku, $qty);
        
        // 3. Log the consumption
        $this->logConsumption($jobTicketId, $tokenId, $materialSku, $qty);
        
        $this->db->commit();
        
        return [
            'material_sku' => $materialSku,
            'qty_consumed' => $qty,
            'success' => true
        ];
        
    } catch (\Throwable $e) {
        $this->db->rollback();
        error_log("Material consumption failed: " . $e->getMessage());
        return [
            'material_sku' => $materialSku,
            'success' => false,
            'error' => $e->getMessage()
        ];
    }
}
```

### 3.4 Integration Point

**File:** `source/BGERP/Service/TokenExecutionService.php`

```php
// Inside moveToken() or completeNodeWork() method:

// After token moves to new node:
if ($destinationNodeType === 'operation') {
    // Task 27.21: Consume materials for this component
    $materialService = new MaterialAllocationService($this->db);
    $consumeResult = $materialService->consumeOnNodeComplete(
        $tokenId,
        $destinationNodeId,
        $jobTicketId
    );
    
    if (!$consumeResult['success']) {
        error_log("Material consumption failed for token $tokenId: " . json_encode($consumeResult));
        // Note: Don't block token movement, just log
    }
}
```

### 3.5 When to Consume?

| Trigger Event | Action |
|---------------|--------|
| Token **enters** operation node | Consume materials for that component |
| Token **leaves** operation node | ❌ No action (already consumed) |
| Token **enters** QC node | ❌ No action (QC doesn't use materials) |
| QC Fail → Rework | Need NEW materials (new token) |

### 3.6 Rework Scenario

เมื่อ Token ถูก QC Fail และต้อง Rework:
1. Original token → cancelled
2. New replacement token → spawned
3. **New token ต้องใช้วัสดุใหม่** (ของเก่าเสียแล้ว)
4. System ต้องเช็คว่ามีวัสดุพอสำหรับ replacement ไหม

```php
// In QC Rework flow:
if ($reworkMode === 'recut') {
    // Need to reserve NEW materials for replacement
    $materialService->reserveForReworkToken($replacementTokenId);
}
```

### 3.7 Files to Modify

| File | Changes |
|------|---------|
| `MaterialAllocationService.php` | Add `consumeOnNodeComplete()`, `reduceStockFIFO()` |
| `TokenExecutionService.php` | Call `consumeOnNodeComplete()` after token moves |
| `material_requirement_api.php` | Add `get_consumption_log` action |
| `job_ticket.js` | Update Materials tab to show consumption in real-time |

### 3.8 Database Changes (if needed)

```php
// Migration: 2025_12_material_consumption_tracking.php

// Add token reference to material_requirement_log
ALTER TABLE material_requirement_log 
ADD COLUMN id_token INT NULL COMMENT 'FK to flow_token (which token consumed this)'
AFTER id_requirement;

// Index for quick lookup
CREATE INDEX idx_mrl_token ON material_requirement_log(id_token);
```

### 3.9 Edge Cases to Handle

| Case | Handling |
|------|----------|
| Node has no anchor_slot | Skip consumption (no material link) |
| anchor_slot has no mapping | Skip consumption (not configured) |
| Component has no materials | Skip consumption (no BOM) |
| Insufficient reserved qty | Log warning, allow token to proceed |
| Concurrent consumption | Use transaction + FOR UPDATE |

### 3.10 Testing Checklist

- [ ] Token moves to CUT node → materials consumed
- [ ] Token moves to QC node → no consumption
- [ ] Multiple tokens consume same material → correct totals
- [ ] Rework token → reserves new materials
- [ ] Materials tab updates after consumption
- [ ] Consumption log shows token reference

---

## ✅ Completion Criteria

### Phase 1 & 2 (✅ COMPLETED)
- [x] `calculate_can_produce` API returns correct max producible
- [x] `check_shortage` API returns correct shortage list
- [x] Material Check Panel shows in Job Creation form
- [x] Job with insufficient materials gets `pending_materials` status
- [x] Start button disabled for `pending_materials` jobs
- [x] Materials section shows in Job Ticket
- [x] Product Readiness check before BOM calculation

### Phase 3 (✅ COMPLETED - 7 Dec 2025)
- [x] Materials consumed when token enters operation node
- [x] on_hand reduced on consume (not on reserve) via FIFO
- [x] Consumption logged with token reference
- [x] Materials tab shows consumption data
- [x] All tests pass (7 tests, 15 assertions)

> **Note:** Rework material handling → See [Task 27.21.1](./task27.21.1_REWORK_MATERIAL_RESERVE_PLAN.md)

---

## 🔗 Related Documents

- [MASTER_IMPLEMENTATION_ROADMAP.md](./MASTER_IMPLEMENTATION_ROADMAP.md)
- [Material Requirement Backend](../archive/completed_plans/task27.18_MATERIAL_REQUIREMENT_PLAN.md)
- [SYSTEM_CURRENT_STATE.md](../SYSTEM_CURRENT_STATE.md)

