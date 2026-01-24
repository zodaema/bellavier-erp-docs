# Task 23.4.4 Results — ETA Result Caching Layer

**Phase:** 23.4 — ETA System (Advanced ETA Model)  
**Subphase:** 23.4.4 — ETA Caching Layer  
**Status:** ✅ Completed  
**Date:** 2025-01-XX  
**Owner:** BGERP / DAG Team

---

## 1. Executive Summary

Task 23.4.4 สร้างระบบ **ETA Cache** เพื่อลดภาระการคำนวณ ETA ซ้ำ ๆ โดยใช้กลไก:
- **Signature-based invalidation**: ตรวจสอบการเปลี่ยนแปลงของ MO (qty, routing, status)
- **TTL-based invalidation**: Cache หมดอายุหลังจาก 30 นาที
- **Compact payload storage**: เก็บเฉพาะข้อมูลที่จำเป็นใน JSON format

**ผลลัพธ์:**
- ✅ Migration สำหรับ `mo_eta_cache` table
- ✅ `MOEtaCacheService` พร้อม methods: `getOrCompute()`, `refresh()`, `invalidate()`
- ✅ Integration กับ `mo_eta_api.php` (ใช้ cache แทนคำนวณสดทุกครั้ง)
- ✅ Signature และ TTL logic ทำงานถูกต้อง

---

## 2. Deliverables

### 2.1 Files Created

1. **`database/tenant_migrations/0008_mo_eta_cache.php`**
   - Migration สำหรับสร้างตาราง `mo_eta_cache`
   - Schema: id_eta_cache, id_mo (UNIQUE), eta_best/normal/worst, alert_level, has_problems, eta_payload (JSON), audit_payload (JSON), input_signature, ttl_expires_at, last_computed_at, compute_duration_ms
   - Indexes: uq_mo_eta_cache_mo, idx_eta_cache_ttl, idx_eta_cache_signature

2. **`source/BGERP/MO/MOEtaCacheService.php`** (456 lines)
   - Service class สำหรับจัดการ ETA cache
   - Methods:
     - `getOrCompute(int $moId): array` - ดึงจาก cache หรือคำนวณใหม่
     - `refresh(int $moId, bool $force = false): array` - Refresh cache
     - `invalidate(int $moId): void` - ลบ cache
     - `buildSignature(array $mo): string` - สร้าง signature จาก MO data
     - `getCacheRow(int $moId): ?array` - ดึง cache row
     - `upsertCache(int $moId, array $data): void` - บันทึก cache
     - `computeEtaAndAudit(int $moId): array` - คำนวณ ETA และ Audit
     - `buildResultFromCache(array $mo, array $cacheRow): array` - Build result จาก cache
     - `buildEtaPayload(array $eta): array` - สร้าง compact ETA payload
     - `buildAuditPayload(array $audit): array` - สร้าง compact audit payload
     - `compactNodeTimeline(array $nodeTimeline): array` - Compact node timeline
     - `extractQueueModel(array $eta): array` - Extract queue model
     - `fetchMO(int $moId): ?array` - ดึง MO data

### 2.2 Files Modified

1. **`source/mo_eta_api.php`**
   - เปลี่ยนจากใช้ `MOLoadEtaService` โดยตรง → ใช้ `MOEtaCacheService`
   - `handleEta()` function รับ `MOEtaCacheService` แทน `MOLoadEtaService`
   - เรียก `$cacheService->getOrCompute($moId)` แทน `$etaService->computeETA($moId)`
   - เพิ่ม debug mode (`?debug=1`) เพื่อแสดง cache metadata

---

## 3. Implementation Details

### 3.1 Database Schema

**Table: `mo_eta_cache`**

```sql
CREATE TABLE `mo_eta_cache` (
  `id_eta_cache` INT AUTO_INCREMENT PRIMARY KEY,
  `id_mo` INT NOT NULL UNIQUE,
  
  `eta_best` DATETIME NULL,
  `eta_normal` DATETIME NULL,
  `eta_worst` DATETIME NULL,
  
  `alert_level` ENUM('OK', 'WARNING', 'ERROR') DEFAULT 'OK',
  `has_problems` TINYINT(1) DEFAULT 0,
  
  `eta_payload` JSON NULL,
  `audit_payload` JSON NULL,
  
  `input_signature` VARCHAR(64) NOT NULL,
  `ttl_expires_at` DATETIME NOT NULL,
  `last_computed_at` DATETIME NOT NULL,
  `compute_duration_ms` INT NULL,
  
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  UNIQUE KEY uq_mo_eta_cache_mo (id_mo),
  INDEX idx_eta_cache_ttl (ttl_expires_at),
  INDEX idx_eta_cache_signature (input_signature)
);
```

**Key Features:**
- `id_mo` UNIQUE: MO 1 ตัวมี cache record 1 แถว
- `eta_best/normal/worst`: เก็บเป็น DATETIME สำหรับ UI ที่ต้องการสรุปเร็ว ๆ
- `eta_payload` / `audit_payload`: เก็บโครงสร้างละเอียดในรูป JSON
- `input_signature`: SHA1 hash ของ MO data (mo_id, qty, routing_id, production_type, status, engine_version)
- `ttl_expires_at`: หมดอายุหลังจาก 30 นาที (1800 วินาที)

### 3.2 Cache Invalidation Strategy

#### 3.2.1 Signature-based Invalidation

`input_signature` = SHA1 hash ของข้อมูลสำคัญที่มีผลต่อ ETA:

```php
$signatureData = [
    'mo_id' => (int)$mo['id_mo'],
    'qty' => (int)$mo['qty'],
    'routing_id' => isset($mo['id_routing_graph']) ? (int)$mo['id_routing_graph'] : null,
    'production_type' => $mo['production_type'] ?? null,
    'status' => $mo['status'] ?? null,
    'engine_version' => 'ETA_23.4.4',
];

$inputSignature = sha1(json_encode($signatureData, JSON_UNESCAPED_UNICODE));
```

**Logic:**
- ถ้า signature ปัจจุบัน != signature ใน DB → cache ถือว่า **invalid ทันที** ไม่สน TTL
- Force refresh (`refresh($moId, true)`) เมื่อ signature mismatch

#### 3.2.2 TTL-based Invalidation

- `ttl_expires_at` = `last_computed_at` + 1800 วินาที (30 นาที)
- เมื่อ `now() > ttl_expires_at` แม้ signature ยังตรง → ให้ถือว่า stale และควร recompute แบบ soft refresh
- Soft refresh (`refresh($moId, false)`) เมื่อ TTL หมดอายุ

**Future Enhancement:**
- Dynamic TTL:
  - `status = completed` → TTL ยาวขึ้น (เช่น 3 ชั่วโมง)
  - `status = in_production` → TTL สั้นลง (เช่น 10–15 นาที)

### 3.3 MOEtaCacheService Flow

#### 3.3.1 getOrCompute() Flow

```
1. Load MO (throw exception if not found)
2. Load cache row (if exists)
3. Build current signature from MO
4. Check cache validity:
   - No cache → refresh($moId, true)
   - Signature mismatch → refresh($moId, true)
   - TTL expired → refresh($moId, false)
   - Valid → return cached data
```

#### 3.3.2 refresh() Flow

```
1. Start timer (microtime(true))
2. Load MO
3. Compute ETA and Audit:
   - $eta = $etaService->computeETA($moId)
   - $audit = $auditService->runAudit($moId)
4. Build signature from MO
5. Prepare cache data:
   - Extract eta_best/normal/worst from ETA
   - Extract alert_level and has_problems from Audit
   - Build compact eta_payload and audit_payload
   - Calculate ttl_expires_at (now + 30 minutes)
   - Calculate compute_duration_ms
6. Upsert cache (INSERT ... ON DUPLICATE KEY UPDATE)
7. Return result (mo, eta, audit, cache)
```

#### 3.3.3 Payload Design

**ETA Payload (Compact):**
```json
{
  "eta": {
    "best": "2025-01-01 12:00:00",
    "normal": "2025-01-01 15:00:00",
    "worst": "2025-01-01 18:00:00"
  },
  "stages": [...],
  "node_timeline": [
    {
      "node_id": 100,
      "work_center_id": 8,
      "node_start_at": "...",
      "node_complete_at": "...",
      "waiting_ms": 120000,
      "execution_ms": 600000
    }
  ],
  "queue_model": {
    "8": {
      "current_load_ms": 3600000,
      "waiting_ms": 1200000
    }
  }
}
```

**Audit Payload (Compact):**
```json
{
  "alert_level": "WARNING",
  "simulation_eta_check": {
    "errors": ["NODE_WORKLOAD_MISMATCH"],
    "warnings": ["STATION_QUEUE_DRIFT"]
  },
  "eta_canonical_check": {
    "errors": [],
    "warnings": ["INSUFFICIENT_CANONICAL_DATA"]
  },
  "outliers": [
    {
      "node_id": 100,
      "flags": ["HIGH_DELAY", "HIGH_QUEUE"]
    }
  ],
  "stage_consistency": {
    "errors": [],
    "warnings": []
  },
  "eta_envelope": {
    "valid": true,
    "errors": []
  }
}
```

### 3.4 API Integration

**Before (Task 23.4):**
```php
$loadSimService = new MOLoadSimulationService($tenantDb);
$etaService = new MOLoadEtaService($tenantDb, $loadSimService);
$result = $etaService->computeETA($moId);
```

**After (Task 23.4.4):**
```php
$cacheService = new MOEtaCacheService($tenantDb);
$result = $cacheService->getOrCompute($moId);
$etaResult = $result['eta']; // Same structure as before
```

**Backward Compatibility:**
- API response structure ไม่เปลี่ยน (ยังเป็น `eta` array เดิม)
- เพิ่ม debug mode (`?debug=1`) เพื่อแสดง cache metadata:
  ```json
  {
    "ok": true,
    "data": { /* ETA data */ },
    "_cache": {
      "cached": true,
      "last_computed_at": "2025-01-01 12:00:00",
      "ttl_expires_at": "2025-01-01 12:30:00",
      "compute_duration_ms": 1250
    }
  }
  ```

---

## 4. Code Statistics

- **Lines Added:** ~600 lines
- **Classes Added:** 1 (`MOEtaCacheService`)
- **Migrations Added:** 1 (`0008_mo_eta_cache.php`)
- **API Endpoints Modified:** 1 (`mo_eta_api.php`)
- **Methods Added:** 12 public/private methods
- **Database Tables Added:** 1 (`mo_eta_cache`)

---

## 5. Design Decisions

### 5.1 Signature-based Invalidation

**Decision:** ใช้ SHA1 hash ของ MO data เพื่อตรวจสอบการเปลี่ยนแปลง

**Rationale:**
- ตรวจสอบการเปลี่ยนแปลงได้ทันที (qty, routing, status)
- ไม่ต้อง query database เพิ่มเติม
- Engine version ทำให้ invalidate cache อัตโนมัติเมื่อ logic เปลี่ยน

### 5.2 TTL Fixed at 30 Minutes

**Decision:** ใช้ TTL คงที่ 30 นาที (1800 วินาที)

**Rationale:**
- Balance ระหว่าง freshness และ performance
- ง่ายต่อการ maintain (ไม่ต้อง config)
- Future: สามารถทำ dynamic TTL ตาม status ได้

### 5.3 Compact Payload Storage

**Decision:** เก็บเฉพาะข้อมูลที่จำเป็นใน JSON format

**Rationale:**
- ลดขนาด storage
- UI ต้องการเฉพาะ summary (eta_best/normal/worst, alert_level)
- Dev tool (`eta_audit.php`) ยังใช้คำนวณสดได้อยู่

### 5.4 Cache Service Encapsulation

**Decision:** `MOEtaCacheService` สร้าง `MOLoadSimulationService`, `MOLoadEtaService`, `MOEtaAuditService` เอง

**Rationale:**
- Encapsulation: Cache service จัดการ dependencies เอง
- API ไม่ต้องรู้ว่า cache service ใช้ service อะไรบ้าง
- ง่ายต่อการ maintain

### 5.5 Backward Compatibility

**Decision:** API response structure ไม่เปลี่ยน

**Rationale:**
- Frontend ไม่ต้องแก้ไข
- Cache เป็น implementation detail
- Debug mode สำหรับ dev ที่ต้องการดู cache metadata

---

## 6. Testing Plan

### TC 1 — ไม่มี cache มาก่อน
- ✅ สร้าง MO ใหม่
- ✅ เรียก ETA API → ควรคำนวณสด, สร้าง row ใน `mo_eta_cache`
- ✅ ตรวจ DB: มี row, input_signature ไม่ว่าง, ttl_expires_at ถูกต้อง

### TC 2 — มี cache แล้ว, signature ตรง, TTL ยังไม่หมด
- ✅ เรียก ETA API ซ้ำๆ หลายครั้งในช่วงสั้น ๆ
- ✅ ตรวจ log ว่า Simulation/ETA/Audit ไม่ถูกเรียกซ้ำทุกครั้ง (ต้องลดลงอย่างชัดเจน)

### TC 3 — signature mismatch
- ✅ เปลี่ยน qty หรือ routing ของ MO
- ✅ เรียก ETA API อีกครั้ง
- ✅ ควรคำนวณใหม่, input_signature เปลี่ยน, ttl_expires_at ถูกรีเซ็ต

### TC 4 — TTL หมด
- ✅ Mock เวลาให้เกิน 30 นาที หรือปรับ TTL สั้นเพื่อเทส (เช่น 10 วินาที)
- ✅ เรียก ETA API ครั้งที่ 1 → คำนวณสด
- ✅ รอ TTL หมด → เรียกอีกครั้ง → ต้องคำนวณใหม่ (แต่ signature เดิม)

### TC 5 — Performance
- ⏳ เตรียม MO 100–200 รายการ
- ⏳ ให้หน้า MO List ดึง ETA summary ผ่าน cache
- ⏳ ตรวจเวลาตอบสนองว่าลดลงจากแบบไม่ใช้ cache อย่างชัดเจน

---

## 7. Performance Impact

### 7.1 Expected Improvements

**Before (No Cache):**
- ETA API call: ~1000-2000ms (Simulation + ETA + Audit)
- Database queries: ~50-100 queries per request
- CPU usage: High (complex calculations)

**After (With Cache):**
- ETA API call (cached): ~10-50ms (1 query + JSON decode)
- Database queries: 1 query (SELECT from mo_eta_cache)
- CPU usage: Low (no calculations)

**Improvement:**
- **Response time:** 20-200x faster (1000ms → 10-50ms)
- **Database load:** 50-100x reduction (100 queries → 1 query)
- **CPU usage:** Significant reduction

### 7.2 Cache Hit Rate Target

- **Expected hit rate:** 70-90% (most MOs don't change frequently)
- **Cache invalidation:** Automatic (signature + TTL)
- **Storage:** ~5-10 KB per MO (JSON payloads)

---

## 8. Future Enhancements

### 8.1 Dynamic TTL

```php
private function calculateTTL(array $mo): int {
    $status = $mo['status'] ?? null;
    switch ($status) {
        case 'completed':
            return 3 * 3600; // 3 hours
        case 'in_production':
            return 10 * 60; // 10 minutes
        default:
            return self::TTL_SECONDS; // 30 minutes
    }
}
```

### 8.2 Batch Cache Refresh

```php
public function refreshBatch(array $moIds): array {
    // Refresh multiple MOs in parallel
    // Useful for dashboard / monitor pages
}
```

### 8.3 Cache Warming

```php
public function warmCache(array $moIds): void {
    // Pre-compute ETA for MOs that are likely to be viewed
    // Run in background job
}
```

### 8.4 Cache Statistics

```php
public function getCacheStats(): array {
    // Return cache hit rate, average compute time, etc.
    // Useful for monitoring
}
```

---

## 9. Integration Points

### 9.1 MO Detail API

**Future:** เพิ่ม ETA summary ใน MO Detail API:

```php
$cacheService = new MOEtaCacheService($tenantDb);
$cache = $cacheService->getOrCompute($moId);

$response['eta'] = [
    'best' => $cache['cache']['eta_best'] ?? null,
    'normal' => $cache['cache']['eta_normal'] ?? null,
    'worst' => $cache['cache']['eta_worst'] ?? null,
    'alert_level' => $cache['cache']['alert_level'] ?? 'OK',
];
```

### 9.2 Monitor / Dashboard (Phase 24)

- ใช้ cache เพื่อแสดง ETA summary สำหรับหลาย MOs
- ลด database load และ response time
- Support real-time monitoring

### 9.3 Manual Cache Invalidation

```php
// Admin can manually invalidate cache
$cacheService->invalidate($moId);
```

---

## 10. Known Limitations

1. **Cache invalidation:** ยังไม่ support event-based invalidation (เช่น เมื่อ WIP log เปลี่ยน)
2. **Storage:** JSON payloads อาจใหญ่ถ้า MO มี nodes มาก
3. **TTL:** ยังใช้ fixed TTL (30 minutes) ไม่ได้ dynamic ตาม status
4. **Batch operations:** ยังไม่ support batch refresh/warming

---

## 11. Conclusion

Task 23.4.4 สร้างระบบ **ETA Cache** ที่:
- ✅ ลดภาระการคำนวณ ETA ซ้ำ ๆ ผ่าน signature + TTL invalidation
- ✅ รักษา backward compatibility (API response structure ไม่เปลี่ยน)
- ✅ Support debug mode สำหรับ dev
- ✅ พร้อมสำหรับ Phase 24 (Monitor, Dashboard)

**Next Steps:**
- Test performance improvements (TC 5)
- Integrate with MO Detail API
- Consider dynamic TTL based on MO status
- Monitor cache hit rate and adjust TTL if needed

---

**End of task23_4_4_results.md**

