

# Task 23.4.4 — ETA Result Caching Layer (MOEtaCacheService + Cache Table + Invalidation Rule)

**Phase:** 23.4 — ETA System (Advanced ETA Model)
**Subphase:** 23.4.4 — ETA Caching Layer  
**Owner:** BGERP / DAG Team  
**Status:** Ready for implementation  
**Target Files:**
- `database/migrations/` (new)
- `source/BGERP/MO/MOEtaCacheService.php` (new)
- `source/mo_eta_api.php` (modify, ถ้าชื่อไฟล์ต่างให้ map ให้ถูกต้องกับของจริง)
- `source/MO_get_detail_api.php` (modify, ถ้ามี)

---

## 1. Objective

สร้างระบบ **ETA Cache** ที่:

- ลดภาระการรัน Simulation + ETA + Audit ซ้ำ ๆ ทุกครั้งที่ UI ขอข้อมูล
- ให้หน้า MO (เช่น MO Detail / Future Monitor) ดึง ETA ได้ใน O(1) (1 query + 1 JSON decode)
- ยังคงรักษา **ความถูกต้องในระดับเพียงพอ** ผ่านกลไก `input_signature` + `TTL`
- ปูทางสำหรับ Phase ถัดไป (Monitor, Dashboard, ML การคาดการณ์ ETA)

ระบบนี้ออกแบบสำหรับ Close System (ใช้ภายใน Bellavier Group เท่านั้น) ไม่จำเป็นต้อง generic หรือปรับแต่งได้จากภายนอก

---

## 2. Deliverables

1. **Migration ใหม่**: ตาราง `mo_eta_cache`
2. **Service ใหม่**: `MOEtaCacheService`
3. **Integration กับ ETA API / MO Detail API** (อ่านจาก cache แทนคำนวณสดทุกครั้ง)
4. **Signature + TTL Logic** เพื่อควบคุมความสดของข้อมูล
5. เอกสารสรุป (ไฟล์นี้ + task23_4_4_results.md หลัง implement เสร็จ)

---

## 3. Database Schema — `mo_eta_cache`

สร้าง migration ใหม่ใน `database/migrations/` เช่น `00xx_create_mo_eta_cache.php`

สคีมาแนะนำ:

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

  `created_at` DATETIME NOT NULL,
  `updated_at` DATETIME NOT NULL
);
```

หมายเหตุ:
- `id_mo` UNIQUE: MO 1 ตัวมี cache record 1 แถว
- `eta_best/normal/worst` ใช้สำหรับ UI ที่ต้องการสรุปเร็ว ๆ โดยไม่ต้อง decode JSON
- `eta_payload` / `audit_payload` เก็บโครงสร้างละเอียดในรูป JSON
- `input_signature` และ `ttl_expires_at` คุมการ invalidation

---

## 4. Cache Invalidation Strategy

ใช้ 2 กลไกผสมกัน:

### 4.1 Signature-based Invalidation

`input_signature` = แฮชของข้อมูลสำคัญที่มีผลต่อ ETA เช่น:

- `id_mo`
- `qty`
- `id_routing_graph` (หรือ field binding routing ที่ใช้จริง)
- `production_type` (classic / hatthasilpa / hybrid)
- `status` ของ MO (draft / in_production / completed / cancelled)
- `engine_version` (string คงที่ เช่น `ETA_23.4.4` เพื่อให้ invalid เองอัตโนมัติเมื่อ logic เปลี่ยน)

ตัวอย่าง pseudo:

```php
$signatureData = [
  'mo_id'           => $mo['id_mo'],
  'qty'             => $mo['qty'],
  'routing_id'      => $mo['id_routing_graph'] ?? null,
  'production_type' => $mo['production_type'] ?? null,
  'status'          => $mo['status'] ?? null,
  'engine_version'  => 'ETA_23.4.4',
];

$inputSignature = sha1(json_encode($signatureData));
```

ถ้า signature ปัจจุบัน != signature ใน DB → cache ถือว่า **invalid ทันที** ไม่สน TTL

---

### 4.2 TTL-based Invalidation

นอกจาก signature แล้ว ยังใช้ TTL (time-to-live):

- `ttl_expires_at` = `last_computed_at` + 1800 วินาที (30 นาที) เป็นค่าเริ่มต้น
- เมื่อ `now() > ttl_expires_at` แม้ signature ยังตรง → ให้ถือว่า stale และควร recompute แบบ soft refresh

ในอนาคตอาจทำ dynamic TTL:
- ถ้า `status = completed` → TTL ยาวขึ้น (เช่น 3 ชั่วโมง)
- ถ้า `status = in_production` → TTL สั้นลง (เช่น 10–15 นาที)

ใน Task 23.4.4 ใช้ค่า fixed TTL 30 นาทีไปก่อน

---

## 5. MOEtaCacheService — Design

สร้างไฟล์ใหม่ `source/BGERP/MO/MOEtaCacheService.php`:

```php
namespace BGERP\MO;

class MOEtaCacheService
{
    /** @var \mysqli */
    private $db;

    public function __construct(\mysqli $db)
    {
        $this->db = $db;
    }

    public function getOrCompute(int $moId): array;

    public function refresh(int $moId, bool $force = false): array;

    public function invalidate(int $moId): void;

    private function computeEtaAndAudit(int $moId): array;

    private function buildSignature(array $mo): string;

    private function getCacheRow(int $moId): ?array;

    private function upsertCache(int $moId, array $data): void;
}
```

### 5.1 getOrCompute(int $moId): array

Flow:

1. โหลด MO (ถ้าไม่เจอ → throw exception หรือคืน error)
2. โหลด cache row (`mo_eta_cache`) ถ้ามี
3. สร้าง signature ปัจจุบันจากข้อมูล MO
4. ถ้า **ไม่มี cache** → `refresh($moId, true)`
5. ถ้ามี cache:
   - ถ้า signature ต่างจาก `input_signature` → `refresh($moId, true)`
   - else ถ้า `now() > ttl_expires_at` → `refresh($moId, false)` (soft refresh ตาม TTL)
   - else → คืน cache เดิม

Return structure แนะนำ:

```php
return [
  'mo'     => $mo,
  'eta'    => $etaArray,   // ค่าที่ decode แล้วจาก eta_payload หรือจาก compute สด
  'audit'  => $auditArray, // สรุป audit ที่ decode แล้ว
  'cache'  => $cacheRow,   // raw row จาก mo_eta_cache
];
```

### 5.2 refresh(int $moId, bool $force = false): array

1. เริ่มจับเวลา (microtime(true))
2. โหลด MO
3. เรียก Simulation + ETA + Audit (ตรงนี้ควรใช้ service เดิม ๆ ที่ทำไว้แล้ว)
4. สร้าง signature ใหม่จาก MO
5. สร้างค่าที่จะเก็บใน cache:
   - `eta_best/normal/worst` จาก ETA summary
   - `alert_level` และ `has_problems` จาก Audit summary
   - `eta_payload` (JSON encode เฉพาะ fieldที่จำเป็น เช่น stage_timeline, node_timeline, queue_model)
   - `audit_payload` (JSON encode เฉพาะ summary ไม่ต้องยาวมาก)
   - `ttl_expires_at` = `now + 1800 sec`
   - `last_computed_at` = now
   - `compute_duration_ms` = (microtime diff × 1000)
6. ทำ `INSERT ... ON DUPLICATE KEY UPDATE` ลง `mo_eta_cache`
7. คืน array เดียวกับใน getOrCompute (mo, eta, audit, cache)

### 5.3 invalidate(int $moId): void

ทำการลบ row จาก `mo_eta_cache`:

```sql
DELETE FROM mo_eta_cache WHERE id_mo = ?
```

เมธอดนี้จะถูกเรียกในอนาคตเมื่อมี event สำคัญมาก ๆ เช่น Manual Recompute หรือ Admin Clear Cache

---

## 6. ETA & Audit Payload Design

ETA และ Audit Payload ไม่จำเป็นต้องเก็บทุก field แบบละเอียดทั้งหมดใน cache เพราะ Dev สามารถใช้ tool สดได้อยู่แล้ว (เช่น `eta_audit.php`)

แนวทาง v1:

### 6.1 eta_payload

```json
{
  "eta": {
    "best": "2025-01-01 12:00:00",
    "normal": "2025-01-01 15:00:00",
    "worst": "2025-01-01 18:00:00"
  },
  "stage_timeline": [
    { "stage_id": 1, "start_at": "...", "complete_at": "...", "risk_factor": 0.4 },
    { "stage_id": 2, "start_at": "...", "complete_at": "...", "risk_factor": 0.9 }
  ],
  "node_timeline": [
    { "node_id": 100, "work_center_id": 8, "start_at": "...", "complete_at": "...", "waiting_ms": 120000, "execution_ms": 600000 },
    { "node_id": 101, "work_center_id": 9, "start_at": "...", "complete_at": "...", "waiting_ms": 0, "execution_ms": 300000 }
  ],
  "queue_model": {
    "8": { "current_load_ms": 3600000, "waiting_ms": 1200000 },
    "9": { "current_load_ms": 1800000, "waiting_ms": 300000 }
  }
}
```

### 6.2 audit_payload

```json
{
  "simulation_eta_check": {
    "errors": ["NODE_WORKLOAD_MISMATCH"],
    "warnings": ["STATION_QUEUE_DRIFT"]
  },
  "eta_canonical_check": {
    "errors": [],
    "warnings": ["INSUFFICIENT_CANONICAL_DATA"]
  },
  "outliers": [
    {"node_id": 100, "flags": ["HIGH_DELAY", "HIGH_QUEUE"]}
  ],
  "stage_consistency": {
    "errors": [],
    "warnings": []
  },
  "eta_envelope": {
    "valid": true,
    "problems": []
  }
}
```

---

## 7. API Integration (ETA API / MO Detail API)

> ชื่อไฟล์จริงของ API ฝั่ง MO อาจต่างจากตัวอย่าง ให้ Agent map ให้ถูกกับโปรเจ็กต์จริง

### 7.1 ETA API (`mo_eta_api.php` หรือชื่อใกล้เคียง)

จุดที่ปัจจุบันเรียก ETA สด เช่น:

```php
$etaService = new MOLoadEtaService($db);
$eta = $etaService->computeEta($moId);
```

ให้ปรับเป็น:

```php
$cacheService = new MOEtaCacheService($db);
$result = $cacheService->getOrCompute($moId);

$eta = $result['eta'];
// ส่ง $eta ออกใน JSON response ตามเดิม
```

### 7.2 MO Detail API (`mo_get_detail_api.php` หรือใกล้เคียง)

ถ้ามี endpoint ที่ดึงรายละเอียด MO มาแสดงในหน้าเดียว ให้เพิ่ม ETA summary เข้าไปใน payload:

```php
$cacheService = new MOEtaCacheService($db);
$cache = $cacheService->getOrCompute($moId);

$response['eta'] = [
    'best'        => $cache['cache']['eta_best'] ?? null,
    'normal'      => $cache['cache']['eta_normal'] ?? null,
    'worst'       => $cache['cache']['eta_worst'] ?? null,
    'alert_level' => $cache['cache']['alert_level'] ?? 'OK',
];
```

Frontend สามารถใช้ค่าเหล่านี้โชว์ ETA แบบสั้นได้เลย

---

## 8. Test Plan (สำหรับ Dev)

### TC 1 — ไม่มี cache มาก่อน
- สร้าง MO ใหม่
- เรียก ETA API → ควรคำนวณสด, สร้าง row ใน `mo_eta_cache`
- ตรวจ DB: มี row, input_signature ไม่ว่าง, ttl_expires_at ถูกต้อง

### TC 2 — มี cache แล้ว, signature ตรง, TTL ยังไม่หมด
- เรียก ETA API ซ้ำๆ หลายครั้งในช่วงสั้น ๆ
- ตรวจ log ว่า Simulation/ETA/Audit ไม่ถูกเรียกซ้ำทุกครั้ง (ต้องลดลงอย่างชัดเจน)

### TC 3 — signature mismatch
- เปลี่ยน qty หรือ routing ของ MO
- เรียก ETA API อีกครั้ง
- ควรคำนวณใหม่, input_signature เปลี่ยน, ttl_expires_at ถูกรีเซ็ต

### TC 4 — TTL หมด
- Mock เวลาให้เกิน 30 นาที หรือปรับ TTL สั้นเพื่อเทส (เช่น 10 วินาที)
- เรียก ETA API ครั้งที่ 1 → คำนวณสด
- รอ TTL หมด → เรียกอีกครั้ง → ต้องคำนวณใหม่ (แต่ signature เดิม)

### TC 5 — Performance
- เตรียม MO 100–200 รายการ
- ให้หน้า MO List ดึง ETA summary ผ่าน cache
- ตรวจเวลาตอบสนองว่าลดลงจากแบบไม่ใช้ cache อย่างชัดเจน

---

## 9. Developer Prompt (สำหรับ Cursor / Agent)

ให้สร้างไฟล์ `task23_4_4_results.md` แยกต่างหากเพื่อสรุปงานที่ทำ และอ้างอิง spec จากไฟล์นี้

ตัวอย่าง prompt ย่อย:

```text
Implement Task 23.4.4 (ETA Result Caching Layer) based on docs/super_dag/tasks/task23.4.4.md

- Create migration for mo_eta_cache
- Create MOEtaCacheService with methods: getOrCompute, refresh, invalidate, buildSignature, getCacheRow, upsertCache, computeEtaAndAudit
- Integrate MOEtaCacheService into ETA API and MO Detail API
- Use SHA1 input_signature and 30-min TTL
- Store compact eta_payload and audit_payload as JSON
- Do not break existing API contracts
- No DB writes beyond mo_eta_cache modifications
```

---

## 10. หมายเหตุสรุป

หลังจาก Task 23.4.4 เสร็จสิ้น:

- ETA Engine + Audit Engine จะไม่ต้องรันซ้ำทุกครั้งเมื่อ UI เปิดหน้าดู MO
- สามารถรองรับ Monitor / Dashboard ใน Phase 24 ได้โดยไม่ล่ม
- ระบบยังยืดหยุ่นพอที่จะ invalidate cache ได้ง่ายหาก Logic เปลี่ยน หรือหากต้องการ Recompute แบบ manual

**End of task23.4.4.md**