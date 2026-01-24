# Task 23.4.5 — ETA Cache Hardening & Engine Version Binding

**Phase:** 23.4 — ETA System (Advanced ETA Model)  
**Subphase:** 23.4.5 — ETA Cache Hardening & Consistency Guard  
**Owner:** BGERP / DAG Team  
**Status:** Ready for implementation  
**Target Files:**
- `database/tenant_migrations/0008_mo_eta_cache.php` (patch index, optional)
- `source/BGERP/MO/MOEtaCacheService.php`
- `source/mo_eta_api.php`
- (optional) `source/BGERP/MO/MOLoadEtaService.php`
- (optional) `source/BGERP/MO/MOLoadSimulationService.php`

---

## 1. Objective

Task 23.4.5 มีเป้าหมายเพื่อ **“เก็บแข็ง” ETA Cache Layer** ที่สร้างใน 23.4.4 ให้พร้อมระดับ Production ของ Bellavier Group โดย:

1. ผูก ETA Cache ให้ **ผูกแน่นกับเวอร์ชันของ Routing Graph + Simulation/ETA Engine** (ไม่เอาผลเก่ามาใช้ผิด context)
2. เพิ่ม **safety guard** ให้ MOEtaCacheService เมื่อ Audit / Engine มีปัญหา → cache ไม่พังไปทั้งก้อน
3. ปรับ **API layer** ให้สะอาด, ปลอด warning, ไม่มี header ขัดกัน
4. ปรับ schema/index เล็กน้อยเพื่อรองรับ Monitoring & Query ในอนาคต

แนวคิดหลัก: **ไม่ยืด Task 23.4 ไปอีก** แต่แทรก Patch ที่จำเป็นเข้าไปในงานหลักของ 23.4.5 เลย เพื่อให้ Phase 23.4 ปิดจบและพร้อมต่อยอด Phase 24 (Monitoring / Dashboard) ได้ทันที

---

## 2. Scope

### 2.1 สิ่งที่ต้องทำใน Task นี้

1. **MOEtaCacheService Hardening**
   - ผูก `input_signature` ให้รวมข้อมูล routing graph version/hash + engine version
   - ปรับ `refresh()` ให้ regen signature ทุกครั้ง และกันกรณี Audit/Engine error (safe fallback)
   - เพิ่ม validation เวลาสร้าง result จาก cache (กัน payload เก่า/ขาด field)

2. **ETA API Patch (mo_eta_api.php)**
   - ปรับการอ่าน `$member[...]` ให้ปลอดภัยแม้ auth fail
   - เคลียร์ conflict ระหว่าง `disable_response_cache()` กับ `set_cache_header(300)`
   - ลบ `use` imports ที่ไม่ได้ใช้งาน

3. **Index/Schema Minor Patch (optional)**
   - เพิ่ม index ที่จำเป็นสำหรับการ query cache ในอนาคต (เช่น `idx_ttl_expires_at`)

### 2.2 สิ่งที่ **ไม่** ทำใน Task นี้

- ไม่เปลี่ยน API structure / contract ของ mo_eta_api (response JSON เดิมต้องใช้ได้เหมือนเดิม)
- ไม่เปลี่ยน business logic ของ ETA Engine หรือ Simulation Engine โดยตรง (ยกเว้น expose metadata เพื่อ build signature)
- ไม่เพิ่ม feature flag ใหม่

---

## 3. MOEtaCacheService Hardening

### 3.1 ปัจจุบัน (จาก 23.4.4)

- มี method `buildSignature(array $mo)` ที่ใช้ข้อมูล MO หลัก ๆ (เช่น id_mo, qty, routing_id, production_type, status, engine_version) → สร้าง SHA1
- ใช้ signature + TTL ใน `getOrCompute()` เพื่อตัดสินใจว่าจะใช้ cache เดิม หรือเรียก `refresh()`
- `refresh()` สร้าง ETA + Audit แล้ว upsert ลง `mo_eta_cache`

### 3.2 ปัญหาที่พบ

1. **Routing Graph Version/Hash ไม่ถูกนับใน signature**
   - ถ้า designer เปลี่ยน routing graph (เพิ่ม/ลบ node, เปลี่ยน structure) โดยที่ `id_routing_graph` ยังเท่าเดิม → signature จะยังเดิม และ cache จะไม่ถูก invalid ทั้ง ๆ ที่ ETA ควรเปลี่ยน

2. **Simulation/ETA Engine Version ไม่ผูกแน่นกับ logic จริง**
   - ตอนนี้ `engine_version` เป็น string ที่ hard-coded (เช่น `ETA_23.4.4`) แต่ไม่ได้ผูกกับเวอร์ชันของ Simulation/ETA service จริง ๆ
   - ถ้า agent แก้ logic ใน MOLoadEtaService / MOLoadSimulationService โดยไม่อัปเดต engine_version → cache จะยังใช้ผลเก่าอยู่

3. **Audit Failure → อาจทำให้ refresh พังทั้ง block**
   - ถ้า `MOEtaAuditService::runAudit()` เจอ exception → ตอนนี้ refresh อาจ fail ทั้งชุด ทำให้ ETA cache ใช้ไม่ได้

4. **Cache Payload Backward Compatibility**
   - ในอนาคต schema ของ `eta_payload` / `audit_payload` อาจเปลี่ยน
   - ต้องมีชั้น validation เวลาอ่าน cache กลับขึ้นมา เพื่อกัน payload เก่าหรือขาด field แล้วทำให้ consumer พัง

5. **Signature Regeneration**
   - `refresh()` ต้อง regen signature ทุกครั้ง (ทั้ง force และ soft) เพื่อให้ค่าใน DB สอดคล้องกับ input ปัจจุบันเสมอ

### 3.3 สิ่งที่ต้องแก้ (Patch Plan)

#### 3.3.1 buildSignature() — เพิ่ม Routing Graph Version/Hash + Engine Version จริง

1. ดึง routing metadata จาก service ที่มีอยู่แล้ว (เช่น `RoutingSetService` หรือ helper อื่น) เพื่อให้ได้อย่างน้อย:
   - `routing_id`
   - `routing_version` (ถ้ามี)
   - `graph_hash` (เช่น md5 ของ adjacency list หรือ canonical JSON ของ graph)

2. เพิ่มค่าต่อไปนี้ใน `$signatureData`:

```php
$signatureData = [
  'mo_id'           => (int)$mo['id_mo'],
  'qty'             => (float)$mo['qty'],
  'routing_id'      => (int)($mo['id_routing_graph'] ?? 0),
  'routing_version' => (int)($routingMeta['version'] ?? 0),
  'routing_hash'    => (string)($routingMeta['graph_hash'] ?? ''),
  'production_type' => (string)($mo['production_type'] ?? ''),
  'status'          => (string)($mo['status'] ?? ''),
  'engine_version'  => (string)$this->getEngineVersion(),
];
```

3. สร้าง method `getEngineVersion()` ภายใน `MOEtaCacheService` หรือรับจาก constructor เพื่อผูกกับ:
   - เวอร์ชันของ `MOLoadEtaService`
   - เวอร์ชันของ `MOLoadSimulationService`
   - (อาจใช้ constant จาก config หรือ compose string เช่น `SIM_23.4.3|ETA_23.4.2`)

> หมายเหตุ: ไม่ต้อง implement การคำนวณ `graph_hash` หรือ engine version แบบละเอียดใน Task นี้ แค่เตรียม field และโครงให้ครบ และให้ agent ใช้ service/helper ที่มีอยู่แล้วในโปรเจกต์เพื่อเติมค่าที่เหมาะสม

#### 3.3.2 refresh() — Regenerate Signature & Safe Audit

1. ปรับ `refresh(int $moId, bool $force = false)` ให้ **เรียก `buildSignature($mo)` ทุกครั้ง** และใช้ signature ใหม่นี้อัปเดต DB
2. ห่อการเรียก Audit ด้วย try/catch:

```php
try {
    $audit = $this->auditService->runAudit($moId, $simulation, $eta);
} catch (\Throwable $e) {
    // Log แต่ไม่บล็อก cache
    log_file('mo_eta_cache_audit_error', [...context + $e->getMessage()...]);
    $audit = [
        'simulation_eta_check' => [
            'errors'   => ['AUDIT_ENGINE_ERROR'],
            'warnings' => [],
        ],
        'eta_canonical_check'  => [
            'errors'   => [],
            'warnings' => [],
        ],
        'outliers'             => [],
        'stage_consistency'    => [
            'errors'   => [],
            'warnings' => [],
        ],
        'eta_envelope'         => [
            'valid'    => false,
            'problems' => ['AUDIT_SKIPPED_DUE_TO_ERROR'],
        ],
    ];
}
```

3. ทำให้แน่ใจว่าแม้ audit พัง → ETA ยังถูก compute และ cache ยังทำงานได้ (แค่ audit payload บอกว่า error)

#### 3.3.3 buildResultFromCache() — Payload Validation

สมมติใน `MOEtaCacheService` มี helper สำหรับอ่าน cache row แล้วแปลงเป็น structure ที่ API ใช้ (ถ้ายังไม่มีให้สร้าง):

```php
private function buildResultFromCache(array $mo, array $cacheRow): array
{
    $etaPayload = json_decode($cacheRow['eta_payload'] ?? 'null', true) ?: [];
    $auditPayload = json_decode($cacheRow['audit_payload'] ?? 'null', true) ?: [];

    // Validation แบบ defensive
    $eta = $etaPayload['eta'] ?? [
        'best'   => $cacheRow['eta_best'] ?? null,
        'normal' => $cacheRow['eta_normal'] ?? null,
        'worst'  => $cacheRow['eta_worst'] ?? null,
    ];

    $stageTimeline = $etaPayload['stage_timeline'] ?? [];
    $nodeTimeline  = $etaPayload['node_timeline'] ?? [];

    // Audit summary fallback
    $audit = [
        'simulation_eta_check' => $auditPayload['simulation_eta_check'] ?? ['errors' => [], 'warnings' => []],
        'eta_canonical_check'  => $auditPayload['eta_canonical_check'] ?? ['errors' => [], 'warnings' => []],
        'outliers'             => $auditPayload['outliers'] ?? [],
        'stage_consistency'    => $auditPayload['stage_consistency'] ?? ['errors' => [], 'warnings' => []],
        'eta_envelope'         => $auditPayload['eta_envelope'] ?? ['valid' => true, 'problems' => []],
    ];

    return [
        'mo'     => $mo,
        'eta'    => [
            'eta'            => $eta,
            'stage_timeline' => $stageTimeline,
            'node_timeline'  => $nodeTimeline,
        ],
        'audit'  => $audit,
        'cache'  => $cacheRow,
    ];
}
```

เป้าหมาย: แม้ payload schema จะ evolve ในอนาคต → ส่วนหลักที่ consumer ใช้ (eta summary, stage timeline, basic audit) จะยังไม่พังทันที

---

## 4. API Patch — `mo_eta_api.php`

### 4.1 ปัญหาที่พบ

1. การอ้าง `$member['id_member']` และ `$member['username']` ใน `catch` / `finally` มีความเสี่ยงหาก `$member` ไม่ใช่ array (เช่น auth ล้มเหลว / memberDetail เปลี่ยน behavior) → จะเกิด warning: *Trying to access array offset on value of type bool*
2. มีการเรียก `disable_response_cache()` ตอนต้นไฟล์ และ `set_cache_header(300)` ตอนจบ response → ค่า Cache-Control header ขัดกันในเชิงแนวคิด
3. มี `use` import ของ `MOLoadEtaService` และ `MOLoadSimulationService` ที่ไม่ได้ใช้งานแล้ว → ทำให้ code อ่านยากและทำให้ dev สับสน

### 4.2 สิ่งที่ต้องแก้ (Patch Plan)

#### 4.2.1 Member Access Safety

ก่อน `try` หรือในต้นสคริปต์ ให้ประกาศตัวแปร safe:

```php
$userId = 0;
$username = 'unknown';
```

เมื่อ `memberDetail->thisLogin()` คืนค่า:

```php
$member = $memberDetail->thisLogin();

if (is_array($member)) {
    $userId = isset($member['id_member']) ? (int)$member['id_member'] : 0;
    $username = isset($member['username']) ? (string)$member['username'] : 'unknown';
}
```

จากนั้นใน `catch` และ `finally` ให้ใช้ `$userId` / `$username` แทน `$member[...]` ตรง ๆ เพื่อกัน warning ในอนาคต

#### 4.2.2 Cache Header Conflict

ตัดสินใจให้ชัดเจนว่า **ETA API ไม่ควรถูก browser cache** เพราะเราใช้ internal cache (MOEtaCacheService) แล้ว และ ETA เป็นข้อมูลที่มีเวลาเกี่ยวข้อง

ดังนั้น:
- **คง `disable_response_cache()` ไว้**
- **ลบ `set_cache_header(300)` ออกจาก `handleEta()`**

ให้ agent ลบบรรทัด `set_cache_header(300);` ในส่วนท้ายของฟังก์ชัน `handleEta()`

#### 4.2.3 ลบ use ที่ไม่ได้ใช้งาน

ลบบรรทัดที่ไม่ใช้ เช่น:

```php
use BGERP\MO\MOLoadEtaService;
use BGERP\MO\MOLoadSimulationService;
```

คงเหลือเฉพาะ `use` ที่จำเป็น (เช่น `MOEtaCacheService`)

---

## 5. Schema / Index Patch (Optional แต่ควรทำ)

ใน migration `0008_mo_eta_cache.php` ให้เพิ่ม index สำหรับช่วย query ตามเวลา/สถานะในอนาคต เช่น:

```sql
ALTER TABLE `mo_eta_cache`
  ADD KEY `idx_ttl_expires_at` (`ttl_expires_at`),
  ADD KEY `idx_alert_level` (`alert_level`),
  ADD KEY `idx_last_computed_at` (`last_computed_at`);
```

หรือถ้าต้องการรวมไว้ใน migration เดิม ให้ agent แทรกในส่วนสร้างตาราง เรียงตาม style ของโปรเจกต์

---

## 6. Acceptance Criteria

1. **Signature Binding**
   - เมื่อ routing graph เปลี่ยน (version/hash เปลี่ยน) → signature ใหม่ → cache ถูก refresh อัตโนมัติ
   - เมื่อ Simulation/ETA engine version เปลี่ยน → signature ใหม่ → cache ถูก refresh อัตโนมัติ

2. **Audit Safety**
   - ถ้า Audit engine พัง (throw exception) → ETA API ยังตอบได้จากผล compute สด และ cache บันทึก audit error ไว้ใน payload แต่ไม่ระเบิดทั้งระบบ

3. **Cache Payload Compatibility**
   - ถ้าแก้ schema ของ eta_payload / audit_payload ในอนาคต → เวอร์ชันเก่าที่เก็บไว้ยัง decode ได้โดยไม่พัง (มี fallback values)

4. **API Cleanliness**
   - ไม่เกิด PHP warning `Trying to access array offset on value of type bool` จาก `$member[...]`
   - ไม่เกิด header ขัดแย้งระหว่าง no-cache และ max-age
   - ไม่มี `use` import ที่ไม่ได้ใช้งานใน `mo_eta_api.php`

---

## 7. Developer Prompt (สำหรับ Agent)

ให้ Agent ใช้ prompt แนวนี้ในการ implement:

```text
Implement Task 23.4.5 (ETA Cache Hardening & Engine Version Binding) based on docs/super_dag/tasks/task23.4.5.md

Scope:
1) MOEtaCacheService
- Extend buildSignature() to include routing_version, routing_hash, and engine_version (from a dedicated helper or constant)
- Regenerate signature in every refresh(), both force and TTL-based
- Wrap auditService->runAudit() in try/catch: on error, log and produce a safe default audit payload instead of failing
- Add a helper to build result from cache with defensive validation of eta_payload and audit_payload

2) mo_eta_api.php
- Introduce $userId and $username variables, populated only when $member is an array
- Replace any direct $member['id_member'] / $member['username'] access in catch/finally with these safe variables
- Remove set_cache_header(300) so ETA API is not browser-cached
- Remove unused use statements for MOLoadEtaService and MOLoadSimulationService

3) Migration / Index (optional but recommended)
- Add helpful indexes to mo_eta_cache: ttl_expires_at, alert_level, last_computed_at

Constraints:
- Do NOT change the public API contract of mo_eta_api (response shape stays the same)
- Do NOT introduce new feature flags
- Do NOT change business logic of ETA/Simulation engines beyond what is necessary to expose routing/version/hash metadata
- Keep code style and logging consistent with existing project conventions
```

หลังจาก implement เสร็จ ให้สร้าง `docs/super_dag/tasks/results/task23_4_5_results.md` สรุป:
- ไฟล์ที่แก้ไข
- รายละเอียด patch หลัก
- ผลการทดสอบ / syntax check

---

**End of task23.4.5.md**
