# SuperDAG Time Model

**Date:** 2025-01-XX (Last Updated)  
**Purpose:** Complete time data foundation for Task 20 (ETA / SLA / Predictive Routing)  
**Task:** 19.5 - Time Modeling & SLA Pre-Layer (Updated for Task 20, 20.2)  
**Status:** ✅ **IMPLEMENTED** - EtaEngine uses TimeHelper for canonical timezone normalization

> **⚠️ IMPORTANT:** This document defines the time data structure and formulas used by SuperDAG. Task 19.5 establishes the foundation; Task 20 implements ETA/SLA calculation. All time operations use `TimeHelper` for canonical timezone normalization (Task 20.2.2, 20.2.3).
>
> **Design Context (Bellavier Close System)**  
> - Time Model นี้เป็นส่วนหนึ่งของ “Closed Logic” ของ Bellavier ERP (อ้างอิง Core Principles ข้อ 13–15)  
> - Time Fields และ Formula ถูกกำหนดตายตัว ไม่เปิดให้ผู้ใช้หรือ Dev เพิ่ม field/time logic ใหม่เองตามใจ  
> - การเปลี่ยน Logic ของเวลา ต้องอัปเดตสเปกในไฟล์นี้ + `core_principles_of_flexible_factory_erp.md` + `Node_Behavier.md` ไม่ใช่แก้เฉพาะโค้ด

---

## Table of Contents

1. [Time Concepts](#time-concepts)
2. [Formula Definitions](#formula-definitions)
3. [Storage Locations](#storage-locations)
4. [Handling Null / Missing Data](#handling-null--missing-data)
5. [Time Measurement Units](#time-measurement-units)
6. [Usage Examples](#usage-examples)

---

## Time Concepts

### A. Node Time Fields

#### Expected Minutes (`expected_minutes`)
- **Location:** `routing_node.expected_minutes`
- **Type:** INT NULL
- **Description:** Standard/expected operation time for the node (in minutes)
- **Usage:** Baseline for ETA calculation, performance comparison
- **Example:** `30` = 30 minutes expected

#### SLA Minutes (`sla_minutes`)
- **Location:** `routing_node.sla_minutes`
- **Type:** INT NULL
- **Description:** Service level agreement - maximum allowed time for node completion (in minutes)
- **Usage:** SLA deadline calculation, violation detection
- **Example:** `45` = 45 minutes SLA (must complete within 45 minutes)
- **Note:** Optional field (NULL = no SLA for this node)

#### Actual Minutes (`actual_minutes`)
- **Location:** Computed from `flow_token.actual_duration_ms`
- **Type:** Computed (FLOAT)
- **Description:** Actual time taken to complete the node (in minutes)
- **Formula:** `actual_minutes = actual_duration_ms / 60000`
- **Usage:** Performance analysis, SLA comparison

---

### B. Token Time Fields

#### Start At (`start_at`)
- **Location:** `flow_token.start_at`
- **Type:** DATETIME NULL
- **Description:** When token started work at the current node
- **Set When:** Canonical event `NODE_START` ถูกสร้างสำหรับ token ที่ node ปัจจุบัน (เปลี่ยนสถานะเป็น 'active')
- **Usage:** Calculate actual duration, SLA deadline calculation
- **Note:** NULL if token hasn't started work yet

#### Completed At (`completed_at`)
- **Location:** `flow_token.completed_at`
- **Type:** DATETIME NULL
- **Description:** When token completed work at the current node (or reached end node)
- **Set When:** Canonical event `NODE_COMPLETE` ถูกสร้างสำหรับ token ที่ node ปัจจุบัน (หรือถึง finish node)
- **Usage:** Calculate actual duration, completion time tracking
- **Note:** NULL if token hasn't completed yet

#### Actual Duration Milliseconds (`actual_duration_ms`)
- **Location:** `flow_token.actual_duration_ms`
- **Type:** BIGINT UNSIGNED NULL
- **Description:** Precise duration in milliseconds (from start_at to completed_at)
- **Formula:** `actual_duration_ms = completed_at - start_at` (in milliseconds)
- **Usage:** Precise time measurement, performance analysis
- **Note:** NULL if start_at or completed_at is missing

#### Spawned At (`spawned_at`)
- **Location:** `flow_token.spawned_at`
- **Type:** DATETIME (default: CURRENT_TIMESTAMP)
- **Description:** When token was created/spawned
- **Set When:** Token is created
- **Usage:** Token age calculation, spawn time tracking

---

### C. Event Time Fields

#### Event Time (`event_time`)
- **Location:** `token_event.event_time`
- **Type:** DATETIME (default: CURRENT_TIMESTAMP)
- **Description:** When event occurred
- **Set When:** Event is created
- **Usage:** Event timeline, audit trail

#### Duration Milliseconds (`duration_ms`)
- **Location:** `token_event.duration_ms`
- **Type:** BIGINT UNSIGNED NULL
- **Description:** Duration of the event (if applicable)
- **Set When:** Event represents a time-bounded operation
- **Usage:** Event duration tracking, performance analysis
- **Note:** NULL for instant events (spawn, enter, move)

### C.1 Canonical Event Mapping

ตาม Canonical Event Framework (Core Principles ข้อ 14):

- `token_event.event_time` = เวลาของ canonical events เช่น:
  - `TOKEN_CREATE`, `TOKEN_SHORTFALL`, `TOKEN_ADJUST`
  - `NODE_START`, `NODE_PAUSE`, `NODE_RESUME`, `NODE_COMPLETE`, `NODE_CANCEL`
  - `OVERRIDE_ROUTE`, `OVERRIDE_TIME_FIX`, `OVERRIDE_TOKEN_ADJUST`
  - `COMP_BIND`, `COMP_UNBIND`
- `token_event.duration_ms` ใช้กับ events ที่เป็น “time-bounded operations” เท่านั้น (เช่น work sessions, active processing)

**กติกา:**
- Event ใหม่ทุกประเภทต้อง map เข้าสู่ canonical schema นี้ (ไม่สร้าง event_type แปลก ๆ โดยไม่มี mapping)
- ค่าเวลาใน Time Model (เช่น SLA, actual duration) ต้อง derive จาก canonical events หรือจากฟิลด์ใน `flow_token` ที่ถูกอัปเดตโดย canonical events เหล่านี้เท่านั้น

---

### D. Derived Time Fields

#### Deadline At (`deadline_at`)
- **Location:** Computed (not stored)
- **Type:** DATETIME
- **Description:** SLA deadline (when token must complete to meet SLA)
- **Formula:** `deadline_at = start_at + (sla_minutes * 60)` (in seconds)
- **Usage:** SLA violation detection, ETA calculation
- **Note:** Only computed if `start_at` and `sla_minutes` are both non-NULL

#### Wait Window Minutes (`wait_window_minutes`)
- **Location:** `routing_node.wait_window_minutes`
- **Type:** INT NULL
- **Description:** Maximum wait time for join nodes (timeout window)
- **Usage:** Join node timeout, deadlock detection
- **Note:** Only applicable to join/merge nodes

---

## Formula Definitions

### 1. Actual Duration Calculation

**Formula:**
```
actual_duration_ms = completed_at - start_at
```

**In PHP (Task 20.2.2+):**
```php
use BGERP\Helper\TimeHelper;

if ($token['start_at'] && $token['completed_at']) {
    $startDt = TimeHelper::parse($token['start_at']);
    $completedDt = TimeHelper::parse($token['completed_at']);
    if ($startDt !== null && $completedDt !== null) {
        $actualDurationMs = TimeHelper::durationMs($startDt, $completedDt);
    }
}
```

**Note:** All time operations must use `TimeHelper` for canonical timezone normalization (Task 20.2.2). Do not use bare `strtotime()`, `time()`, or `date()`.

**In SQL:**
```sql
SELECT 
    TIMESTAMPDIFF(MICROSECOND, start_at, completed_at) / 1000 AS actual_duration_ms
FROM flow_token
WHERE start_at IS NOT NULL AND completed_at IS NOT NULL
```

> 📌 **Canonical Source:**  
> โดยหลักการแล้ว `actual_duration_ms` ควรคำนวณจากคู่เวลา `NODE_START` → `NODE_COMPLETE` ของ token นั้น ๆ หากในโค้ดใช้ `start_at` / `completed_at` จาก `flow_token` ให้ถือว่าเป็น cache ของ canonical events ซึ่งต้อง sync ให้ถูกต้องเสมอ

---

### 2. Actual Minutes Conversion

**Formula:**
```
actual_minutes = actual_duration_ms / 60000
```

**In PHP:**
```php
$actualMinutes = $actualDurationMs / 60000;
```

**In SQL:**
```sql
SELECT 
    actual_duration_ms / 60000.0 AS actual_minutes
FROM flow_token
WHERE actual_duration_ms IS NOT NULL
```

---

### 3. SLA Deadline Calculation

**Formula:**
```
deadline_at = start_at + (sla_minutes * 60 seconds)
```

**In PHP (Task 20.2.2+):**
```php
use BGERP\Helper\TimeHelper;

if ($token['start_at'] && $node['sla_minutes']) {
    $startDt = TimeHelper::parse($token['start_at']);
    if ($startDt !== null) {
        $deadlineDt = $startDt->modify("+{$node['sla_minutes']} minutes");
        $deadlineAt = TimeHelper::toMysql($deadlineDt);
    }
}
```

**Note:** All time operations must use `TimeHelper` for canonical timezone normalization (Task 20.2.2, 20.2.3). Do not use bare `strtotime()`, `time()`, or `date()`.

**In SQL:**
```sql
SELECT 
    DATE_ADD(start_at, INTERVAL sla_minutes MINUTE) AS deadline_at
FROM flow_token ft
JOIN routing_node rn ON rn.id_node = ft.current_node_id
WHERE ft.start_at IS NOT NULL 
  AND rn.sla_minutes IS NOT NULL
```

> 🧩 **Alignment กับ Node Behavior:**  
> SLA และ Deadline เป็น “กฎของ Node” ไม่ใช่ของ Token รายตัว  
> - ค่าพื้นฐานมาจาก `routing_node.sla_minutes`  
> - การประเมิน SLA ใช้ควบคู่กับ `node_mode` ของ Work Center + `job.line_type` (Classic/Hatthasilpa) ตามสเปกใน `Node_Behavier.md` และ `node_behavior_model.md`  
> - Time Model ไม่อนุญาตให้สร้าง SLA logic พิเศษต่อ token แบบ ad-hoc โดยไม่ผ่าน Node/Behavior Layer

---

### 4. Event Duration Calculation

**Formula:**
```
duration_ms = event_end_time - event_start_time
```

**Usage:** For events that represent time-bounded operations (e.g., work sessions)

**In PHP (Task 20.2.2+):**
```php
use BGERP\Helper\TimeHelper;

if ($eventStartTime && $eventEndTime) {
    $startDt = TimeHelper::parse($eventStartTime);
    $endDt = TimeHelper::parse($eventEndTime);
    if ($startDt !== null && $endDt !== null) {
        $durationMs = TimeHelper::durationMs($startDt, $endDt);
    }
}
```

**Note:** All time operations must use `TimeHelper` for canonical timezone normalization (Task 20.2.2, 20.2.3). Do not use bare `strtotime()`, `time()`, or `date()`.

---

## Storage Locations

### Database Tables

#### 1. `routing_node`

**Time Fields:**
- `expected_minutes` (INT NULL) - Expected operation time
- `sla_minutes` (INT NULL) - Service level agreement (Task 19.5: NEW)
- `wait_window_minutes` (INT NULL) - Wait window for join nodes

**Schema:**
```sql
ALTER TABLE routing_node
ADD COLUMN IF NOT EXISTS sla_minutes INT NULL DEFAULT NULL
COMMENT 'Service level agreement in minutes';
```

---

#### 2. `flow_token`

**Time Fields:**
- `spawned_at` (DATETIME) - Token creation time (existing)
- `start_at` (DATETIME NULL) - When token started work (Task 19.5: NEW)
- `completed_at` (DATETIME NULL) - When token completed (existing)
- `actual_duration_ms` (BIGINT UNSIGNED NULL) - Actual duration (Task 19.5: NEW)

**Schema:**
```sql
ALTER TABLE flow_token
ADD COLUMN IF NOT EXISTS start_at DATETIME NULL
COMMENT 'When token started work at current node (uses canonical timezone via TimeHelper - Task 20.2.2)';

ALTER TABLE flow_token
ADD COLUMN IF NOT EXISTS actual_duration_ms BIGINT UNSIGNED NULL
COMMENT 'Actual duration in milliseconds (from start_at to completed_at, calculated via TimeHelper - Task 20.2.2)';
```

> ℹ️ **Relationship to Canonical Events:**  
> - `spawned_at` สัมพันธ์กับ canonical event `TOKEN_CREATE`  
> - `start_at` สัมพันธ์กับ canonical event `NODE_START` สำหรับ node ปัจจุบัน  
> - `completed_at` สัมพันธ์กับ canonical event `NODE_COMPLETE`  
> - `actual_duration_ms` = duration ระหว่าง `NODE_START` → `NODE_COMPLETE` (หรือค่าที่คำนวณจากเวลาที่สอดคล้องกัน)  
> ฟิลด์เหล่านี้ทำหน้าที่เป็น “cache ระดับ token” ไม่ใช่ source of truth แทน canonical events

---

#### 3. `token_event`

**Time Fields:**
- `event_time` (DATETIME) - When event occurred (existing)
- `duration_ms` (BIGINT UNSIGNED NULL) - Event duration (Task 19.5: NEW)

**Schema:**
```sql
ALTER TABLE token_event
ADD COLUMN IF NOT EXISTS duration_ms BIGINT UNSIGNED NULL
COMMENT 'Event duration in milliseconds (for time-bounded events)';
```

---

## Handling Null / Missing Data

### Rules

#### 1. Start At Missing

**Condition:** `start_at IS NULL`

**Impact:**
- Cannot calculate `actual_duration_ms`
- Cannot calculate `deadline_at` (SLA deadline)
- Cannot evaluate SLA compliance

**Behavior:**
- `actual_duration_ms` remains NULL
- SLA evaluation skipped (no error)
- Token can still complete (no blocking)

**Use Case:** Legacy tokens created before Task 19.5

---

#### 2. SLA Minutes Null

**Condition:** `sla_minutes IS NULL`

**Impact:**
- No SLA deadline calculation
- No SLA violation detection

**Behavior:**
- Node has no SLA requirement
- `deadline_at` not computed
- Token can complete at any time (no SLA constraint)

**Use Case:** Nodes without SLA requirements

---

#### 3. Completed At Missing

**Condition:** `completed_at IS NULL`

**Impact:**
- Cannot calculate `actual_duration_ms`
- Cannot determine completion time

**Behavior:**
- `actual_duration_ms` remains NULL
- Token is still in progress
- Duration calculation deferred until completion

**Use Case:** Active tokens (not yet completed)

---

#### 4. Actual Duration Missing

**Condition:** `actual_duration_ms IS NULL`

**Possible Causes:**
- `start_at` is NULL
- `completed_at` is NULL
- Token not yet completed

**Behavior:**
- Performance metrics unavailable
- SLA comparison unavailable
- Historical analysis incomplete

**Mitigation:**
- Calculate on-demand from `start_at` and `completed_at` if both exist
- Use `event_time` from `token_event` as fallback for start time

#### 5. Canonical Event Fallback

หากพบว่า `start_at` หรือ `completed_at` ขาดหาย แต่ canonical events ยังอยู่ครบ:

- ให้ใช้เวลาใน `token_event` (NODE_START / NODE_COMPLETE) เป็น source of truth
- สามารถเติมค่า `start_at`, `completed_at`, `actual_duration_ms` ย้อนหลังจาก canonical events ได้
- ห้าม “เดาเวลา” โดยใช้ time() ปัจจุบัน หรือเวลาจาก UI โดยตรง

**หลักการ:**  
- Canonical events คือแหล่งข้อมูลระดับ 1  
- `flow_token.*` ทำหน้าที่เป็น level 2 cache ที่ต้อง sync มาจาก events ไม่ใช่คิดเอง

---

## Time Measurement Units

### Units Used

| Unit | Description | Storage Type | Example |
|------|-------------|-------------|---------|
| **Minutes** | Standard time unit for expected/SLA | INT | `30` = 30 minutes |
| **Milliseconds** | Precise duration measurement | BIGINT UNSIGNED | `1800000` = 30 minutes |
| **DATETIME** | Timestamp (absolute time) | DATETIME | `2025-12-18 14:30:00` |

### Conversion Factors

- **Minutes → Milliseconds:** `minutes * 60000`
- **Milliseconds → Minutes:** `milliseconds / 60000`
- **Seconds → Milliseconds:** `seconds * 1000`
- **Milliseconds → Seconds:** `milliseconds / 1000`

### Precision

- **DATETIME:** Second precision (MySQL DATETIME)
- **Milliseconds:** Millisecond precision (BIGINT)
- **Minutes:** Integer precision (INT)

**Note:** For sub-second precision, use milliseconds. For human-readable times, use DATETIME or minutes.

> 🛡️ **Close System Rule:**  
> - ระบบใช้เฉพาะ 3 หน่วยนี้เป็นหลัก (Minutes, Milliseconds, DATETIME)  
> - ห้ามเพิ่มหน่วยใหม่ เช่น “hours” หรือ “days” เป็นฟิลด์ database แยกโดยไม่ผ่านสเปกนี้  
> - การแสดงผลใน UI สามารถ format เป็นชั่วโมง/วันได้ แต่ต้องมาจากการแปลงหน่วยเหล่านี้เท่านั้น

---

## Usage Examples

### Example 1: Basic Start + Complete Timestamps

**Scenario:** Token starts work at node, completes after 25 minutes

**Data:**
```php
$token = [
    'id_token' => 1,
    'current_node_id' => 5,
    'start_at' => '2025-12-18 10:00:00',
    'completed_at' => '2025-12-18 10:25:00'
];
```

**Calculation (Task 20.2.2+):**
```php
use BGERP\Helper\TimeHelper;

$startDt = TimeHelper::parse($token['start_at']);
$completedDt = TimeHelper::parse($token['completed_at']);
$actualDurationMs = TimeHelper::durationMs($startDt, $completedDt); // 1500000 ms
$actualMinutes = $actualDurationMs / 60000; // 25 minutes
```

**Result:**
- `actual_duration_ms = 1500000`
- `actual_minutes = 25`

---

### Example 2: SLA Deadline Calculation

**Scenario:** Token starts at 10:00, node has 45-minute SLA

**Data:**
```php
$token = [
    'id_token' => 2,
    'current_node_id' => 10,
    'start_at' => '2025-12-18 10:00:00'
];
$node = [
    'id_node' => 10,
    'sla_minutes' => 45
];
```

**Calculation (Task 20.2.2+):**
```php
use BGERP\Helper\TimeHelper;

$startDt = TimeHelper::parse($token['start_at']);
if ($startDt !== null) {
    $deadlineDt = $startDt->modify("+{$node['sla_minutes']} minutes");
    $deadlineAt = TimeHelper::toMysql($deadlineDt);
}
```

**Result:**
- `deadline_at = '2025-12-18 10:45:00'`

---

### Example 3: SLA Violation Detection

**Scenario:** Token completed at 10:50, but SLA deadline was 10:45

**Data:**
```php
$token = [
    'id_token' => 3,
    'current_node_id' => 10,
    'start_at' => '2025-12-18 10:00:00',
    'completed_at' => '2025-12-18 10:50:00'
];
$node = [
    'id_node' => 10,
    'sla_minutes' => 45
];
```

**Calculation (Task 20.2.2+):**
```php
use BGERP\Helper\TimeHelper;

$startDt = TimeHelper::parse($token['start_at']);
$deadlineDt = $startDt->modify("+{$node['sla_minutes']} minutes");
$completedDt = TimeHelper::parse($token['completed_at']);
$isViolated = $completedDt > $deadlineDt;
```

**Result:**
- `deadline_at = '2025-12-18 10:45:00'`
- `completed_at = '2025-12-18 10:50:00'`
- `isViolated = true` (completed 5 minutes late)

---

### Example 4: Performance Comparison

**Scenario:** Compare actual vs expected time

**Data:**
```php
$token = [
    'actual_duration_ms' => 1800000  // 30 minutes
];
$node = [
    'expected_minutes' => 25
];
```

**Calculation:**
```php
$actualMinutes = $token['actual_duration_ms'] / 60000; // 30
$expectedMinutes = $node['expected_minutes'];            // 25
$variance = $actualMinutes - $expectedMinutes;          // +5 minutes
$variancePercent = ($variance / $expectedMinutes) * 100; // +20%
```

**Result:**
- `actual_minutes = 30`
- `expected_minutes = 25`
- `variance = +5 minutes` (20% over expected)

---

## Integration Points

### TokenLifecycleService

**Methods Updated (Task 20.2.2):**
- `moveToken()` - Set `start_at` when token enters node (uses `TimeHelper::now()`)
- `completeToken()` - Set `completed_at` and calculate `actual_duration_ms` (uses `TimeHelper`)
- `createEvent()` - Include `duration_ms` for time-bounded events (uses `TimeHelper`)

**Example (Task 20.2.2+):**
```php
use BGERP\Helper\TimeHelper;

// When token starts work (canonical NODE_START)
$now = TimeHelper::now();
$startAt = TimeHelper::toMysql($now);
// UPDATE flow_token SET start_at = :start_at WHERE id_token = :token_id;

// When token completes (canonical NODE_COMPLETE)
$completedAt = TimeHelper::toMysql(TimeHelper::now());
$startDt = TimeHelper::parse($token['start_at']);
$durationMs = TimeHelper::durationMs($startDt, TimeHelper::now());
// UPDATE flow_token SET completed_at = :completed_at, actual_duration_ms = :duration_ms WHERE id_token = :token_id;
```

> ❗ **CRITICAL:** อย่าใช้ `NOW()`, `time()`, `date()`, `strtotime()` โดยตรงในโค้ด PHP  
> ให้ใช้ `TimeHelper` เพื่อสร้าง canonical timestamps แล้ว bind เข้ามาใน SQL เสมอ ตาม Task 20.2.2, 20.2.3

### TimeEventReader (Task 21.5)

**Purpose:** Read canonical timeline from `token_event` table

**Key Methods:**
- `getTimelineForToken(int $tokenId)` - Build canonical timeline
- `getDurationStats(int $tokenId, ?string $nodeId)` - Calculate duration statistics

**Integration:**
- Used by `MOCreateAssistService` for time estimation (Task 23.2)
- Used by `MOLoadEtaService` for ETA calculation (Task 23.4)
- Syncs time data to `flow_token` (start_at, completed_at, actual_duration_ms)
- All timeline reads must go through this service (never query `token_event` directly)

### Frontend Timezone Normalization (Task 20.2.3)

**File:** `assets/javascripts/dag/modules/GraphTimezone.js`

**Purpose:** Frontend timezone normalization layer

**Key Functions:**
- `normalize(dt)` - Normalize date to canonical timezone
- `toLocal(dt)` - Convert to local timezone
- `fromLocal(dt)` - Convert from local timezone
- `now()` - Current time in canonical timezone
- `format(dt, format)` - Format date

**Integration:**
- Used by `graph_sidebar.js` for date operations
- Loaded in `page/routing_graph_designer.php`
- All frontend time operations should use `GraphTimezone`

---

### DAGRoutingService

**Methods to Update:**
- `routeToken()` - Ensure `start_at` is set when token enters node
- `selectNextNode()` - No changes (routing logic unchanged)

**Note:** Task 19.5 only ensures timestamps are recorded. No routing logic changes.

---

### Graph Designer UI

**Fields to Add:**
- SLA Minutes field (hidden in Advanced view)
- Display actual duration (read-only, computed)

**Location:** Node Properties Panel

---

## Task 20 Integration

**Implemented (Task 20, 20.2, 20.2.2, 20.2.3):**

1. **ETA Calculation (Task 20):**
   - ✅ `EtaEngine::computeNodeEtaForToken()` - Calculate ETA for token at node
   - ✅ Uses `TimeHelper` for all time operations
   - ✅ Returns: `planned_finish_at`, `remaining_ms`, `sla_status` (ON_TRACK, AT_RISK, BREACHING)
   - ✅ Exposed via `dag_routing_api.php?action=token_eta`

2. **SLA Monitoring (Task 20):**
   - ✅ `EtaEngine::calculateSlaStatus()` - Calculate SLA status
   - ✅ Threshold: 80% of planned time = AT_RISK
   - ✅ Used by Graph Designer for ETA preview

3. **Timezone Normalization (Task 20.2):**
   - ✅ `TimeHelper` (PHP) - Canonical timezone normalization layer
   - ✅ `GraphTimezone.js` (JS) - Frontend timezone normalization
   - ✅ Canonical timezone: `BGERP_TIMEZONE = 'Asia/Bangkok'`
   - ✅ All services migrated to TimeHelper (TokenLifecycleService, TokenWorkSessionService, DAGRoutingService, WorkSessionTimeEngine)

**Foundation Provided by Task 19.5:**
- ✅ Time data structure
- ✅ Timestamp recording
- ✅ Duration calculation
- ✅ SLA field support

**Task 21.5 Enhancement:**
- ✅ `TimeEventReader` - Read canonical timeline from `token_event`
- ✅ Syncs time data to `flow_token` (start_at, completed_at, actual_duration_ms)
- ✅ Provides duration statistics (avg, p50, p90, min, max)

**Task 23.4 Enhancement:**
- ✅ `MOLoadEtaService` - MO-level ETA calculation
- ✅ Stage-level ETA, node-level ETA
- ✅ Queue modeling, delay propagation
- ✅ Best/normal/worst ETA calculation

---


## Alignment With Core Principles & Node_Behavier

Time Model นี้ต้องสอดคล้องกับเอกสารสถาปัตย์หลักดังนี้:

- **Core Principles 13–15 (Closed Logic, Canonical Events, Golden Rule)**  
  - เวลาในระบบต้องมาจาก canonical events หรือฟิลด์ที่ sync จาก canonical events เท่านั้น  
  - ความจริงในโรงงานอาจเละได้ แต่ Time Logic ต้อง “ตบกลับเข้ารูป” ด้วยกติกาชุดเดียว

- **Node_Behavier.md / node_behavior_model.md**  
  - SLA / expected_minutes เป็น property ของ Node/Behavior ไม่ใช่ของ token รายตัว  
  - การใช้เวลา (start_at, completed_at, actual_duration_ms) ต้องเข้าได้กับ Node Mode (เช่น HAT_SINGLE, BATCH_QUANTITY, CLASSIC_SCAN ฯลฯ)  
  - Time Engine จะใช้ข้อมูลจาก Time Model เป็น input สำหรับ ETA / SLA / Predictive Routing โดยไม่ให้ logic พิเศษหลุดออกนอกกรอบ Node Mode

- **SuperDAG_Execution_Model.md**  
  - Token state transitions และ movement ต้องใช้เวลาในรูปแบบเดียวกับที่กำหนดใน Time Model นี้  
  - ถ้ามี behavior หรือ path ที่ใช้เวลาแบบอื่น ให้ถือว่าเป็นหนี้เทคนิคและต้อง migrate กลับเข้ารูป

การแก้ไข Time Model ในอนาคต ต้องระบุเสมอว่ามีผลกระทบกับเอกสารสามชุดนี้หรือไม่ และ update ให้สอดคล้องกันทุกครั้ง เพื่อป้องกันไม่ให้ Time Logic แตกสาขาเกินควบคุม

**End of Time Model Document**

