# Behavior Execution Spec

**Status:** Target Specification (Blueprint for SuperDAG Behavior Engine)  
**Date:** 2025-12-02  
**Version:** 2.0  
**Category:** SuperDAG / Behavior Layer / Execution Engine

**Purpose:** Defines how behaviors interact with TokenLifecycleService, ParallelMachineCoordinator, and Work Sessions.

**Scope:**
- ✅ Specification for `BehaviorExecutionService` + behavior UI contract
- ✅ Integration with Token Lifecycle, Component Flow, Parallel Execution
- ❌ NOT audit report (see `../00-audit/20251202_BEHAVIOR_LAYER_AUDIT_REPORT.md`)
- ❌ NOT task list (see implementation checklists)

**See Also:**
- Lifecycle: `SUPERDAG_TOKEN_LIFECYCLE.md` (token state machine)
- Component: `COMPONENT_PARALLEL_FLOW_SPEC.md` (component rules)
- Developer Guide: `../../developer/03-superdag/03-specs/BEHAVIOR_APP_CONTRACT.md` (API contracts)

---

## 0. Terminology & Actors

### 0.1 Token Types

| Type | `token_type` Value | Description |
|------|-------------------|-------------|
| **Final Token** | `'piece'` | กระเป๋า 1 ใบ (final product) |
| **Component Token** | `'component'` | ชิ้นส่วนย่อย (BODY, FLAP, STRAP) |
| **Batch Token** | `'batch'` | กลุ่มชิ้นงาน process พร้อมกัน |

### 0.2 Service Actors

| Service | Responsibility | Owner Of |
|---------|---------------|----------|
| **BehaviorExecutionService** | Orchestration layer | Validate + Call services + Log + Return |
| **TokenLifecycleService** | Token status transitions | `flow_token.status` updates |
| **TokenWorkSessionService** | Work session management | `token_work_session` records |
| **ComponentFlowService** | Component metadata | `component_code`, `component_times` |
| **ParallelMachineCoordinator** | Split/merge coordination | Component spawn, merge validation |
| **FailureRecoveryService** | Exception handling | QC fail, scrapped, replacement |
| **DagExecutionService** | Routing (legacy) | Node-to-node movement |

### 0.3 Core Principle

**⚠️ ARCHITECTURE LAW:**

```
Behavior ห้ามอัปเดต DB ตรง
ต้องเรียก service ที่เหมาะสมเท่านั้น
```

**Behavior Responsibilities:**
- ✅ Validate worker input
- ✅ Call appropriate services (lifecycle, session, component, parallel)
- ✅ Log behavior actions
- ✅ Return execution result

**Behavior MUST NOT:**
- ❌ `UPDATE flow_token SET status = ...` (ให้ TokenLifecycleService ทำ)
- ❌ Implement split/merge logic (ให้ ParallelMachineCoordinator ทำ)
- ❌ Aggregate component data (ให้ ComponentFlowService ทำ)
- ❌ Define UI layout (ให้ Frontend ทำ)

---

## 1. Behavior vs Work Center (Conceptual Framework)

### 1.1 What is "Behavior"?

**🟦 Behavior Code = Execution Pattern + UI Template + Time Tracking Model**

**Behavior กำหนด:**
- รูปแบบการทำงาน (single piece, batch, multi-round, QC panel)
- UI ที่ใช้ (ปุ่มอะไร: Start/Pause/Complete/Pass/Fail/Reason)
- การจับเวลา (per piece, per batch, per component)
- Handler ใน `BehaviorExecutionService` (handleStitch, handleCut, handleQc)
- Integration กับ TokenLifecycle (startWork, pauseWork, completeNode)

**Examples:**
- `STITCH` = Single-piece work pattern with start/pause/resume/complete
- `CUT` = Batch work pattern with quantity input
- `EDGE` = Multi-round pattern (round tracking)
- `QC_SINGLE` = QC panel pattern with pass/fail/rework
- `GLUE` = Single-piece pattern (bulk-friendly for tray mode)
- `ASSEMBLY` = Final assembly pattern (merge components)

### 1.2 What is "Work Center"?

**🟧 Work Center = Physical Station / Real Skill ที่โรงงานนิยามขึ้น**

**Work Center บอกว่า:**
- ช่างคนไหนอยู่ตรงนี้
- ใช้ Behavior แบบไหน (เลือกจากชุดกลาง)
- รับ token ประเภทไหน (piece, component, batch)

**⚠️ Current Scope:**
- SuperDAG + Work Queue = `line_type = 'hatthasilpa'` เท่านั้น (ตอนนี้)
- Classic/OEM lines = ยังไม่ใช้ Work Queue (out of scope for this spec)
- **Future Extension:** Classic/OEM อาจ adopt Work Queue ในอนาคต (แต่ไม่ใช่ตอนนี้)

**Examples:**
- `Cutting 1` → behavior: `CUT`, token_type: `batch`
- `Skive Body` → behavior: `SKIVE`, token_type: `component`
- `Lining Front Panel` → behavior: `GLUE`, token_type: `component`
- `Stitch Handle` → behavior: `STITCH`, token_type: `component`
- `Hardware Assembly – Strap` → behavior: `HARDWARE_ASSEMBLY`, token_type: `component`
- `Final Assembly` → behavior: `ASSEMBLY`, token_type: `piece`

### 1.3 Relationship

```
Work Center = ชื่อ/สถานีจริง (User สร้างได้เรื่อยๆ)
     ↓
  เลือก Behavior
     ↓
Behavior = รูปแบบการทำงานกลาง (ชุดที่ระบบเตรียมไว้)
```

**Key Principle:**
- ✅ User สร้าง Work Center ใหม่ได้ไม่จำกัด
- ✅ Behavior ควรมีชุดกลางที่นิยามดีแล้ว
- ❌ User ไม่ควรสร้าง Behavior Code เองผ่าน UI (เพราะชนกับ handler + UI template)

---

## 2. Behavior Code Guidelines (When to Create New Behavior)

### 2.1 Behavior Naming Rules

**✅ DO: Behavior ควรเป็นกลางและ reusable**
```
✅ GLUE_SINGLE (pattern: single-piece glue work)
✅ STITCH_SINGLE (pattern: single-piece stitch work)
✅ QC_PANEL (pattern: QC with pass/fail/rework)
✅ ASSEMBLY_FINAL (pattern: merge components into final)
```

**❌ DO NOT: Behavior ไม่ควรผูกชื่อสินค้า/ขั้นตอนเฉพาะ**
```
❌ LINING_REBELLO_26 (too specific)
❌ POCKET_FRONT_STITCH (too specific)
❌ BODY_GLUE_ONLY (too specific)
```

**Why:** Work Center ค่อยเป็นคนอธิบายว่า behavior นี้ใช้กับชิ้นส่วนไหน

### 2.2 When to Create New Behavior

**✅ Create new behavior if:**

1. **Execution pattern ต่างจาก behavior เดิมอย่างมีนัยสำคัญ:**
   - Example: EDGE มี multi-round (ทาหลายรอบ) ≠ GLUE (ทาครั้งเดียว)
   - Example: QC มี pass/fail/rework ≠ STITCH (แค่ complete)

2. **UI template ต่างอย่างชัดเจน:**
   - Example: CUT ต้องกรอก quantity ≠ STITCH (ไม่ต้องกรอก)
   - Example: QC_PANEL ต้องมี defect code picker ≠ STITCH

3. **Time tracking model ต่าง:**
   - Example: BATCH (จับเวลารวม) ≠ PIECE (จับเวลาชิ้นเดียว)

4. **Metadata capture requirements ต่าง:**
   - Example: GLUE+CLAMP ต้องเก็บ "clamp duration timer" (รอกาวเซ็ต 10 นาที)

**❌ DO NOT create new behavior if:**

1. **แค่ "ชื่อขั้นตอนเปลี่ยน" แต่ execution pattern เหมือนเดิม:**
   - Example: Lining (ซับ) = แค่ GLUE ธรรมดา → ใช้ behavior `GLUE` + work center "Lining – Front Panel"
   - Example: Edge Fold Before Stitch = ก็ GLUE → ใช้ behavior `GLUE` + work center "Edge Fold"

2. **แค่ตำแหน่งใน routing เปลี่ยน:**
   - Example: STITCH ที่ต้นทาง vs STITCH ที่ปลายทาง → เป็น work center คนละตัว แต่ behavior เดียวกัน

3. **แค่ช่างคนละคน:**
   - Example: Alice ทำ BODY, Bob ทำ FLAP → work center คนละตัว, behavior เดียวกัน

### 2.3 Example: Lining (ซับ) Decision

**Question:** Lining ควรเป็น Behavior ใหม่ไหม?

**Analysis:**
- Lining = GLUE (ทากาวติดซับกับตัวหนัง)
- อาจมี STITCH บางจุด (เย็บซับ)
- ในมุม execution pattern: ไม่ต่างจาก GLUE/STITCH ปกติ

**Decision:** ❌ ไม่ต้องสร้าง Behavior ใหม่

**Solution:**
- สร้าง Work Center: "Lining – Front Panel" → behavior: `GLUE`
- สร้าง Work Center: "Lining – Pocket Stitch" → behavior: `STITCH`

**Why:**
- Execution pattern เหมือน GLUE/STITCH ทั่วไป
- แค่บริบทว่า "กำลังทำซับ" (ไม่ใช่ pattern ใหม่)
- ถ้าในอนาคตต้องการ "GLUE + CLAMP TIMER" (รอกาวเซ็ต) → ค่อยสร้าง behavior `GLUE_CLAMP`

---

## 3. Behavior-Token Type Compatibility Matrix

**Purpose:** กำหนด hard rule ว่า behavior ไหนรองรับ token_type ไหน

**Based on:** Bellavier Hatthasilpa Factory Model (as of 2025-12-02)

| Behavior | batch | piece | component | Notes |
|----------|:-----:|:-----:|:---------:|-------|
| **CUT** | ✅ | ❌ | ❌ | Cutting = batch only |
| **STITCH** | ❌ | ✅ | ✅ | Single-piece or component |
| **EDGE** | ❌ | ✅ | ✅ | Multi-round supported |
| **GLUE** | ❌ | ✅ | ✅ | Bulk-friendly (tray mode) |
| **SKIVE** | ❌ | ✅ | ✅ | Leather thickness reduction |
| **EMBOSS** | ❌ | ✅ | ✅ | Leather stamping |
| **HARDWARE_ASSEMBLY** | ❌ | ✅ | ❌ | Final assembly only |
| **ASSEMBLY** | ❌ | ✅ | ❌ | Must be after components done |
| **PACK** | ❌ | ✅ | ❌ | End-of-line, final only |
| **QC_SINGLE** | ❌ | ✅ | ✅ | Component or piece QC |
| **QC_INITIAL** | ❌ | ✅ | ✅ | Initial inspection |
| **QC_REPAIR** | ❌ | ✅ | ✅ | After rework |
| **QC_FINAL** | ❌ | ✅ | ❌ | Final product QC only |

**⚠️ IMPORTANT:** Matrix นี้อิงจาก Bellavier Hatthasilpa factory model ปัจจุบัน  
สามารถขยายได้ในอนาคต (ต้องแก้ spec นี้อย่างเป็นทางการก่อน)

### 3.1 Validation Contract

**Before execute behavior:**

```php
function validateBehaviorTokenType(string $behaviorCode, string $tokenType): bool {
    $matrix = [
        'CUT' => ['batch' => true, 'piece' => false, 'component' => false],
        'STITCH' => ['batch' => false, 'piece' => true, 'component' => true],
        'EDGE' => ['batch' => false, 'piece' => true, 'component' => true],
        'GLUE' => ['batch' => false, 'piece' => true, 'component' => true],
        'SKIVE' => ['batch' => false, 'piece' => true, 'component' => true],
        'EMBOSS' => ['batch' => false, 'piece' => true, 'component' => true],
        'HARDWARE_ASSEMBLY' => ['batch' => false, 'piece' => true, 'component' => false],
        'ASSEMBLY' => ['batch' => false, 'piece' => true, 'component' => false],
        'PACK' => ['batch' => false, 'piece' => true, 'component' => false],
        'QC_SINGLE' => ['batch' => false, 'piece' => true, 'component' => true],
        'QC_INITIAL' => ['batch' => false, 'piece' => true, 'component' => true],
        'QC_REPAIR' => ['batch' => false, 'piece' => true, 'component' => true],
        'QC_FINAL' => ['batch' => false, 'piece' => true, 'component' => false],
    ];
    
    return $matrix[$behaviorCode][$tokenType] ?? false;
}

// In execute()
if (!$this->validateBehaviorTokenType($behaviorCode, $token['token_type'])) {
    return [
        'ok' => false,
        'error' => 'BEHAVIOR_TOKEN_TYPE_MISMATCH',
        'message' => "{$behaviorCode} does not support token_type={$token['token_type']}"
    ];
}
```

---

## 4. Behavior → Token Lifecycle Transition

**Purpose:** กำหนด mapping จาก behavior action → lifecycle API ที่ต้องเรียก

### 4.1 Transition Table

| Behavior Action | Lifecycle API Call | Resulting Token Status | Notes |
|-----------------|-------------------|------------------------|-------|
| `start_work` | `TokenLifecycle::startWork($tokenId)` | `ready` → `active` | |
| `pause_work` | `TokenLifecycle::pauseWork($tokenId)` | `active` → `paused` | |
| `resume_work` | `TokenLifecycle::resumeWork($tokenId)` | `paused` → `active` | |
| `complete_normal_node` | `TokenLifecycle::completeNode($tokenId, $nodeId)` | `active` → `active` (next node) | |
| `complete_split_node` | `TokenLifecycle::completeNode($tokenId, $nodeId)` | `active` → `waiting` (+ spawn) | Internally delegates to ParallelCoordinator |
| `complete_merge_node` | `TokenLifecycle::completeNode($tokenId, $nodeId)` | `waiting` → `active` (parent) | Internally delegates to ParallelCoordinator |
| `complete_end_node` | `TokenLifecycle::completeNode($tokenId, $nodeId)` | `active` → `completed` | |
| `qc_fail` | `TokenLifecycle::scrapToken($tokenId, $reason)` | `active` → `scrapped` (+ replace) | |

**⚠️ IMPORTANT - Single Entry Point:**
- Behavior **ALWAYS** calls `TokenLifecycle::completeNode($tokenId, $nodeId)`
- TokenLifecycleService internally checks node type (normal/split/merge/end)
- TokenLifecycleService delegates to ParallelCoordinator if needed
- **Behavior ไม่ต้องรู้** ว่า node เป็น split หรือ merge

### 4.2 Implementation Contract

**BehaviorExecutionService:**
- ✅ อ่าน `node_type`, `behavior_code`, `token_type`
- ✅ ตัดสินใจว่าจะเรียก lifecycle API ตัวไหน
- ❌ ไม่ `UPDATE flow_token.status` เอง

**Example:**

```php
class BehaviorExecutionService {
    private TokenLifecycleService $lifecycleService;
    private TokenWorkSessionService $sessionService;
    
    function handleStitchComplete($tokenId, $nodeId) {
        // 1. Complete session (time tracking)
        $this->sessionService->completeToken($tokenId, $this->workerId);
        
        // 2. Get node info
        $node = $this->fetchNode($nodeId);
        
        // 3. Call lifecycle (single entry point)
        // ❌ NOT: UPDATE flow_token SET status = ...
        // ❌ NOT: Check node type and call different services
        // ✅ YES: Call lifecycle API - it handles routing internally
        $result = $this->lifecycleService->completeNode($tokenId, $nodeId);
        
        // TokenLifecycleService internally:
        // - Checks node type (normal/split/merge/end)
        // - Delegates to ParallelCoordinator if split/merge
        // - Behavior doesn't need to know
        
        // 4. Log behavior
        $this->logBehaviorAction($tokenId, $nodeId, 'STITCH', 'stitch_complete', ...);
        
        return $result;
    }
}
```

---

## 5. Per-Behavior Execution Contract

### 5.1 STITCH (Single-Piece Work)

**Allowed token_types:** `piece`, `component`

**Actions:**
- `stitch_start` - Start work
- `stitch_pause` - Pause work
- `stitch_resume` - Resume work
- `stitch_complete` - Complete work

**Lifecycle Integration:**

```php
// stitch_start
function handleStitchStart($tokenId, $nodeId) {
    // 1. Validate token_type
    $token = $this->fetchToken($tokenId);
    if (!in_array($token['token_type'], ['piece', 'component'])) {
        return ['ok' => false, 'error' => 'STITCH does not support batch tokens'];
    }
    
    // 2. Call lifecycle
    $this->lifecycleService->startWork($tokenId);
    
    // 3. Create session
    $sessionResult = $this->sessionService->startToken($tokenId, $this->workerId, ...);
    
    // 4. Log
    $this->logBehaviorAction($tokenId, $nodeId, 'STITCH', 'stitch_start', ...);
    
    return ['ok' => true, 'effect' => 'stitch_started', 'session_id' => $sessionResult['session_id']];
}

// stitch_complete
function handleStitchComplete($tokenId, $nodeId) {
    // 1. Complete session
    $this->sessionService->completeToken($tokenId, $this->workerId);
    
    // 2. Call lifecycle (handles normal/split/merge automatically)
    $result = $this->lifecycleService->completeNode($tokenId, $nodeId);
    
    return ['ok' => true, 'effect' => 'stitch_completed', 'routing' => $result];
}
```

### 5.2 CUT (Batch Work)

**Allowed token_types:** `batch`

**Execution mode:** Batch quantity input

**Actions:**
- `cut_start` - Start batch
- `cut_complete` - Complete batch with quantity

---

#### 5.2.1 Atelier Ideal: CUT = Component-first Sweep + Partial Release (Rule)

**Factory Reality (Hatthasilpa Atelier):**
- ช่างตัดมัก “กวาดตัดทีละ component” (เช่น BODY 10 ชิ้น) ไม่ได้ทำ “ครบทั้งใบทีละใบ”
- ต้องปล่อยให้ node ถัดไปเริ่มงานได้ก่อน (เช่น EDGE/PAINT ของ BODY) โดยไม่ต้องรอ FLAP/STRAP

**UI Law (Non-negotiable):**
- หน้าแรก Work Queue = **Job-level cards เท่านั้น**
- รายละเอียดงานย่อย/requirement ต่อ component อยู่ใน **Modal/Detail**

**New CUT Actions (Target contract):**
- `cut_batch_yield_save`:
  - บันทึก “ตัดได้เพิ่ม” ต่อ `component_code`
  - ถ้าเกิน requirement → ต้องมี `overshoot_reason`
- `cut_batch_release`:
  - ปล่อย X units ของ `component_code` ไป node ถัดไป (partial release)
  - ทำแบบ idempotent

**Determinism & Routing:**
- ถ้า job/token pinned (`graph_version`) → resolve node ถัดไปต้องอ่านจาก pinned snapshot

**Canonical Logging (SSOT):**
- ทุก yield/release ต้อง persist เป็น canonical events (ผ่าน `TokenEventService`) เพื่อ audit + idempotency

---

#### 5.2.2 “CUT Partial Release Law” (1-page rule for all devs)

> เป้าหมาย: ให้ “ตัด BODY 10 ชิ้นก่อน แล้วปล่อยไป EDGE/PAINT ทันที” ทำได้จริง  
> โดย UI หน้าแรกยังเป็น job-level card และระบบ deterministic + idempotent

##### A) Entities (SSOT model)

- **Final token**: `flow_token.token_type='piece'` (1 ใบ = 1 token)
- **Component token**: `flow_token.token_type='component'` (1 component ต่อ 1 ใบ = 1 token)
  - SSOT ของ component identity = `flow_token.component_code`
  - Relationship = `parent_token_id` (ห้ามใช้ serial pattern)
- **Batch token (optional)**: `flow_token.token_type='batch'`
  - ใช้เพื่อ “จับเวลา/การเริ่มงาน CUT” แบบสถานีตัด (PER_BATCH)
  - ไม่ใช่ตัวแทน “จำนวนชิ้นที่ปล่อยไปขั้นถัดไป”

**Reality check (จากระบบปัจจุบัน):**
- `TokenLifecycleService::spawnTokens()` สร้างได้แค่ `batch` หรือ `piece` ตอน job creation (ยัง **ไม่** pre-spawn component tokens)
- component tokens ในระบบมีได้ 2 ทาง:
  - จาก native parallel split runtime (Task 30.3)
  - จาก `BGERP\Dag\ComponentInjectionService` (Task 27.17) สำหรับ “missing component” และรองรับ idempotency/audit

##### B) What is “Partial Release”?

“Partial release” = การ route/move **component tokens** ของ `component_code` จำนวน X ไป node ถัดไป  
โดย **ไม่ต้องรอ** component อื่น (FLAP/STRAP) และไม่ต้องให้ final token ไปต่อทั้งใบ

##### C) Two operations (must be separate)

1) **Yield (บันทึกว่าตัดได้เพิ่ม)**: `cut_batch_yield_save`
- Inputs (minimum):
  - `job_ticket_id`, `node_id` (CUT), `component_code`
  - `cut_delta_qty` (>= 0)
  - `material_context` (optional)
  - `overshoot_reason` (required if new total exceeds requirement)
- Output:
  - Updated summary per component: required / cut_done / released / available_to_release

2) **Release (ปล่อยไป node ถัดไป)**: `cut_batch_release`
- Inputs (minimum):
  - `job_ticket_id`, `node_id` (CUT), `component_code`
  - `release_qty` (>= 1)
- Preconditions:
  - `available_to_release_qty >= release_qty`
  - resolve next node via **pinned snapshot** when pinned
- Effect:
  - route/move component tokens จำนวน `release_qty` ไป node ถัดไปของ branch นั้น

##### D) Deterministic selection rule (no “random token”)

เมื่อปล่อย `component_code=BODY` จำนวน X:
- query component tokens ที่:
  - อยู่ใน job เดียวกัน
  - `token_type='component'` + `component_code='BODY'`
  - `current_node_id = CUT_NODE_ID` และ status พร้อมปล่อย (เช่น `ready`)
- เลือก X ตัวด้วย order ที่ deterministic เสมอ เช่น:
  - `ORDER BY id_token ASC` (recommended baseline)

##### D.1 Component tokens “ต้องมีอยู่” ก่อนจะ release ได้ (สร้างแบบ deterministic)

สำหรับ `cut_batch_release` ระบบต้อง “มั่นใจว่ามี component tokens ที่ represent งานนั้น” ก่อนจะ move:
- ถ้า component token ยังไม่มี → ต้องสร้างแบบ deterministic และ idempotent
- แนวทางที่ align กับระบบปัจจุบันมากที่สุด:
  - ใช้ `ComponentInjectionService` เพื่อสร้าง component token ต่อ `parent_token_id` (final/piece) + `component_code`
  - ทำแบบ bulk ตามจำนวน `release_qty` ที่ต้องการ (เลือก parent tokens X ใบก่อน แล้ว inject BODY ให้แต่ละใบ)

> กฎสำคัญ: UI ไม่ต้องเห็น token ทีละใบ แต่ runtime ต้องมีตัวแทน token ที่ชัดเจนเพื่อให้ node ถัดไป “เริ่มทำได้จริง”

##### E) Idempotency (must)

ทั้ง `yield_save` และ `release` ต้องรองรับ retry/เน็ตเด้ง/กดซ้ำ:
- client ส่ง `idempotency_key` ทุกครั้ง
- backend ต้องทำ **at-most-once effect**
- SSOT ของการ dedupe = canonical events (`token_event.idempotency_key`)

##### F) Canonical events (SSOT for audit + aggregation)

งาน CUT แบบ Atelier ต้องมี canonical events อย่างน้อย:
- `NODE_YIELD` (payload: component_code, cut_delta_qty, overshoot_qty, overshoot_reason, material_context)
- `NODE_RELEASE` (payload: component_code, release_qty, selected_token_ids[], to_node_id)

> ข้อห้าม: ห้ามเอา “จำนวนที่ตัด/ปล่อย” ไปเก็บใน `flow_token.qty` แบบ ad-hoc เพื่อเลี่ยง audit และจะทำให้ระบบมั่วในอนาคต

**Reality check (TokenEventService constraints):**
- `BGERP\Dag\TokenEventService` มี canonical whitelist + mapping ไป `token_event.event_type` enum
- `token_event.event_type` มี enum `'move'` อยู่แล้ว → แนะนำ map:
  - `NODE_YIELD` → `event_type='move'`
  - `NODE_RELEASE` → `event_type='move'`
  - แล้วเก็บ canonical_type + payload ลง `event_data` (ตาม pattern ของ TokenEventService)
- ดังนั้น implementation ต้อง “เพิ่ม canonical types + mapping” ใน `TokenEventService` ให้ครบ (ไม่เช่นนั้นจะถูก skip)

##### F.1 SSOT ของ requirement (สิ่งที่ต้อง “pin” ให้ได้)

`available_to_release_qty` ต้องคำนวณจาก:
- **required_qty ต่อ component_code** (ต่อ job)
- cut_done_qty (สะสมจาก NODE_YIELD)
- released_qty (สะสมจาก NODE_RELEASE)

**Reality check (จากระบบปัจจุบัน):**
- ระบบมี “snapshot” ใน `product_revision.snapshot_json` (`ProductRevisionService::buildRuntimeSnapshot()`)
  - มี `structure.components[]` (component_code, name, materials…)
  - มี `graph.component_mapping` (anchor_slot ↔ component_code) แบบ snapshot ได้
- แต่ “required_qty ต่อ component_code” (เช่น BODY อาจมี 1 ชิ้น/ใบ หรือหลายชิ้น/ใบ) ยังไม่ได้ถูกระบุเป็น section มาตรฐานใน snapshot schema ปัจจุบัน

**Law:** งาน CUT partial release ของ pinned job ต้องใช้ requirement ที่มาจาก revision snapshot (ห้ามอ่าน live mapping เพื่อกัน drift)  
ดังนั้นก่อน implement จริง ต้องเพิ่ม section ใหม่ใน snapshot (เช่น `structure.component_requirements[]`) หรือ snapshot `product_component_mapping` เข้า revision ให้ครบ

##### F.2 Mapping component_code → branch/node ถัดไป (deterministic)

**Law:** เมื่อ pinned ต้อง resolve “node ถัดไปของ BODY branch” จาก snapshot เท่านั้น

แหล่งข้อมูลที่ระบบปัจจุบัน support:
- `product_revision.snapshot_json.graph.component_mapping.mappings[]` (anchor_slot + component_code)

ข้อห้าม:
- ห้าม assume `anchor_slot == component_code` (แม้โค้ดบางส่วนจะทำแบบนั้นอยู่) เพราะจะพังเมื่อใช้ anchor slot แบบ SLOT_A/SLOT_B

##### H) Concurrency & locking (release พร้อมกัน)

`cut_batch_release` ต้องเป็น transaction เดียวที่:
1) อ่าน summary (cut_done/released/available) แล้ว validate
2) เลือก parent tokens X ใบ + ensure component tokens exist (inject idempotent)
3) move/route component tokens X ตัวไป node ถัดไป
4) persist `NODE_RELEASE` canonical event

**Locking rule:** ต้อง lock ชุด token ที่กำลังเลือก (เช่น SELECT … FOR UPDATE) เพื่อกัน “ปล่อยเกิน available” เมื่อมี 2 request แข่งกัน

##### G) What the downstream station sees

เมื่อ `NODE_RELEASE` สำเร็จ:
- node ถัดไป (EDGE/PAINT ของ BODY) จะ “เห็นงานเพิ่ม” ทันที เพราะ component tokens เดินมาถึง node นั้นแล้ว
- UI หน้าแรก downstream สามารถเป็น job-level card เหมือนเดิม แล้วตัวเลข “available” เพิ่มขึ้น

---

#### 5.2.3 Batch Interleaving Policy (Answer: merge vs new card)

> คำถาม: Batch แรกถูกปล่อยจาก CUT แล้วกำลังทำอยู่ ถ้า batch ถัดไปมาแทรก จะทำอย่างไร?

**Rule (recommended): รวม Card เดิม (merge) ไม่แตก Card ใหม่**

เหตุผล:
- ผู้ใช้ต้องคิดเป็น “งานใหญ่ของรุ่น/ล็อตนี้” ไม่ใช่ “batch ย่อยกองเต็มหน้าจอ”
- batch ย่อยที่ “มาเพิ่ม” ควรสะท้อนเป็น “จำนวน available เพิ่มขึ้น” ใน card เดิม

**Card Aggregation Key (ต้องยึดร่วมกัน):**
- หน้าแรก Work Queue (job-level): group ด้วย `(job_ticket_id, work_center_id, current_node_id)`
  - ถ้าเป็นงานเดียวกัน + สถานีเดียวกัน + node เดียวกัน → **ต้องรวม card**
  - ถ้าคนละ `job_ticket_id` → card ใหม่
  - ถ้าคนละ node (เช่น BODY_EDGE vs FLAP_EDGE) → แยก card (เพราะงาน/skill ต่างกัน)

**In-modal detail (แสดง batch history ได้ แต่ไม่ต้องแตก card):**
- ภายใน modal สามารถแสดง “Release history” เป็น list events (เวลา/จำนวน/ผู้ปล่อย)
- เพิ่ม indicator “New items arrived” เมื่อมี release ใหม่เข้ามาขณะกำลังทำงานอยู่


**Lifecycle Integration:**

```php
// cut_complete
function handleCutComplete($tokenId, $nodeId, $formData) {
    // 1. Validate token_type
    $token = $this->fetchToken($tokenId);
    if ($token['token_type'] !== 'batch') {
        return ['ok' => false, 'error' => 'CUT requires batch token'];
    }
    
    // 2. Validate quantity
    $cutQty = (int)($formData['cut_quantity'] ?? 0);
    if ($cutQty <= 0) {
        return ['ok' => false, 'error' => 'cut_quantity required'];
    }
    
    // 3. Complete session
    $this->sessionService->completeToken($tokenId, $this->workerId);
    
    // 4. Update batch quantity (spec rule)
    // ❌ Do NOT update DB directly from behavior
    // ✅ Use a dedicated service (e.g., BatchService / TokenLifecycleService) + prepared statements
    
    // 5. Call lifecycle (normal node only - CUT never at split/merge)
    $result = $this->lifecycleService->completeNode($tokenId, $nodeId);
    
    return ['ok' => true, 'effect' => 'cut_completed', 'qty' => $cutQty];
}
```

### 5.3 EDGE (Multi-Round Work)

**Allowed token_types:** `piece`, `component`

**Multi-round flag:** `is_multi_round = true` (ใน node หรือ behavior config)

**Actions:**
- `edge_round_start` - Start round
- `edge_round_complete` - Complete round
- `edge_complete` - Complete all rounds

**Lifecycle Integration:**

```php
// edge_round_complete (not final round)
function handleEdgeRoundComplete($tokenId, $nodeId, $roundNum) {
    // 1. Complete session for this round
    $this->sessionService->completeToken($tokenId, $this->workerId);
    
    // 2. Update round metadata (NOT complete node yet)
    $this->db->query("
        UPDATE flow_token 
        SET metadata = JSON_SET(metadata, '$.edge_rounds_completed', ?, '$.current_round', ?)
        WHERE id_token = ?
    ", [$roundNum, $roundNum, $tokenId]);
    
    // 3. Status remains 'active' (ยังไม่จบ node)
    
    return ['ok' => true, 'effect' => 'round_completed', 'round' => $roundNum];
}

// edge_complete (final round)
function handleEdgeComplete($tokenId, $nodeId, $totalRounds) {
    // 1. Complete session
    $this->sessionService->completeToken($tokenId, $this->workerId);
    
    // 2. Validate all rounds done
    $token = $this->fetchToken($tokenId);
    $completedRounds = $token['metadata']->edge_rounds_completed ?? 0;
    
    if ($completedRounds < $totalRounds) {
        return ['ok' => false, 'error' => 'All rounds not completed'];
    }
    
    // 3. Call lifecycle (NOW complete node)
    $result = $this->lifecycleService->completeNode($tokenId, $nodeId);
    
    return ['ok' => true, 'effect' => 'edge_completed', 'rounds' => $totalRounds];
}
```

### 5.4 QC Behaviors (QC_SINGLE, QC_FINAL, QC_REPAIR, QC_INITIAL)

**Allowed token_types:**
- QC_SINGLE, QC_INITIAL, QC_REPAIR: `piece`, `component`
- QC_FINAL: `piece` only

**Actions:**
- `qc_start` - Start inspection
- `qc_pass` - Pass
- `qc_fail` - Fail (spawn replacement)
- `qc_rework` - Send to rework

**Lifecycle Integration:**

```php
// qc_pass
function handleQcPass($tokenId, $nodeId) {
    // 1. Complete session
    $this->sessionService->completeToken($tokenId, $this->workerId);
    
    // 2. Call lifecycle (normal complete)
    $result = $this->lifecycleService->completeNode($tokenId, $nodeId);
    
    // 3. Emit QC event
    $this->emitEvent('QC_PASS', ['token_id' => $tokenId]);
    
    return ['ok' => true, 'effect' => 'qc_pass'];
}

// qc_fail
function handleQcFail($tokenId, $nodeId, $reason) {
    // 1. Complete session (ก่อน scrap)
    $this->sessionService->completeToken($tokenId, $this->workerId);
    
    // 2. Call recovery service (NOT lifecycle directly)
    // Recovery service handles: scrap + spawn replacement
    $result = $this->recoveryService->handleQcFail($tokenId, $reason);
    
    // 3. Log behavior
    $this->logBehaviorAction($tokenId, $nodeId, 'QC_SINGLE', 'qc_fail', ...);
    
    return $result; // {ok, scrapped_token_id, replacement_token_id}
}
```

### 5.5 ASSEMBLY (Merge Components → Final)

**Allowed token_types:** `piece` only (final token)

**Node requirement:** `is_merge_node = 1`

**Actions:**
- `assembly_start` - Start assembly (validate components ready)
- `assembly_complete` - Complete assembly

**Lifecycle Integration:**

```php
// assembly_start
function handleAssemblyStart($tokenId, $nodeId) {
    // 1. Validate token_type
    $token = $this->fetchToken($tokenId);
    if ($token['token_type'] !== 'piece') {
        return ['ok' => false, 'error' => 'ASSEMBLY requires piece token'];
    }
    
    // 2. Validate components ready (call component service)
    $validation = $this->componentService->validateComponentsReady($tokenId);
    if (!$validation['ready']) {
        return [
            'ok' => false,
            'error' => 'COMPONENTS_NOT_READY',
            'missing' => $validation['missing']
        ];
    }
    
    // 3. Call lifecycle
    $this->lifecycleService->startWork($tokenId);
    
    // 4. Create session
    $sessionResult = $this->sessionService->startToken($tokenId, $this->workerId, ...);
    
    return ['ok' => true, 'effect' => 'assembly_started'];
}

// assembly_complete
function handleAssemblyComplete($tokenId, $nodeId) {
    // 1. Complete session
    $this->sessionService->completeToken($tokenId, $this->workerId);
    
    // 2. Call lifecycle (completeNode handles merge node automatically)
    $result = $this->lifecycleService->completeNode($tokenId, $nodeId);
    
    return ['ok' => true, 'effect' => 'assembly_completed', 'routing' => $result];
}
```

### 5.6 PACK (End-of-Line)

**Allowed token_types:** `piece` only (final token)

**Node requirement:** Usually at/near end node

**Actions:**
- `pack_start` - Start packing
- `pack_complete` - Complete packing

**Lifecycle Integration:**

```php
// pack_complete
function handlePackComplete($tokenId, $nodeId) {
    // 1. Complete session
    $this->sessionService->completeToken($tokenId, $this->workerId);
    
    // 2. Call lifecycle (may reach end node → token.status = 'completed')
    $result = $this->lifecycleService->completeNode($tokenId, $nodeId);
    
    return ['ok' => true, 'effect' => 'pack_completed', 'routing' => $result];
}
```

### 5.7 Single-Piece Behaviors (Fallback Pattern)

**Behaviors:** HARDWARE_ASSEMBLY, SKIVE, GLUE, EMBOSS

**Pattern:** เหมือน STITCH (start/pause/resume/complete)

**Implementation:**

```php
function handleSinglePiece($behaviorCode, $sourcePage, $action, $context, $formData) {
    // Validate token_type (per matrix)
    // Call lifecycle APIs (same as STITCH)
    // Create session
    // Log behavior
    
    // Example:
    $actionLower = strtolower($behaviorCode);
    
    if ($action === "{$actionLower}_start") {
        $this->lifecycleService->startWork($tokenId);
        $this->sessionService->startToken($tokenId, $this->workerId, ...);
    } elseif ($action === "{$actionLower}_complete") {
        $this->sessionService->completeToken($tokenId, $this->workerId);
        $this->lifecycleService->completeNode($tokenId, $nodeId);
    }
    
    return ['ok' => true, 'effect' => "{$actionLower}_{$action}"];
}
```

---

## 6. Component Awareness Hook

**Purpose:** Behavior ต้อง "รู้" เรื่อง component แต่ไม่ทำ logic เอง

### 6.1 Component Token Detection

```php
function execute($behaviorCode, $action, $context, $formData) {
    $token = $this->fetchToken($context['token_id']);
    
    // Detect token type
    if ($token['token_type'] === 'component') {
        // Component-specific hook
        $this->handleComponentTokenExecution($token, $behaviorCode, $action, $context, $formData);
    } else {
        // Normal execution
        $this->handlePieceTokenExecution($token, $behaviorCode, $action, $context, $formData);
    }
}
```

### 6.2 Component Token Hooks

**Hook 1: On Component Complete**

```php
// After complete session
if ($token['token_type'] === 'component') {
    // Call component service (owner of metadata)
    $this->componentService->onComponentCompleted($tokenId, [
        'component_code' => $token['metadata']->component_code ?? null,
        'duration_ms' => $sessionSummary['duration_ms'],
        'worker_id' => $this->workerId,
        'node_id' => $nodeId
    ]);
}
```

**Hook 2: Before Assembly Start**

```php
// If token_type = 'piece' AND node has flag "assembly"
if ($token['token_type'] === 'piece' && $node['is_merge_node'] === 1) {
    // Call component service (owner of validation)
    $validation = $this->componentService->isReadyForAssembly($tokenId);
    
    if (!$validation['ready']) {
        return [
            'ok' => false,
            'error' => 'COMPONENTS_NOT_READY',
            'missing' => $validation['missing']
        ];
    }
}
```

**Hook 3: Component Code from Node**

```php
// If node produces component → read from node (TARGET)
$node = $this->fetchNode($nodeId);
if ($node['produces_component']) {
    $componentCode = $node['produces_component'];
    
    // Validate token has same component_code
    $tokenComponentCode = $token['metadata']->component_code ?? null;
    if ($tokenComponentCode && $tokenComponentCode !== $componentCode) {
        return ['ok' => false, 'error' => 'Component code mismatch'];
    }
}
```

**⚠️ Key Principle:**

**Behavior ระบุว่า "ต้องเรียก service อะไร"**  
**ไม่ใช่ "ต้องคำนวณ aggregate เวลาอย่างไร"**

---

## 7. Failure Modes Hook (Behavior Layer Only)

**Purpose:** Behavior เชื่อมกับ FailureRecoveryService (ไม่ใช่ implement recovery logic เอง)

### 7.1 QC Fail

```php
// Behavior calls recovery service (owner of recovery logic)
function handleQcFail($tokenId, $reason) {
    $result = $this->recoveryService->handleQcFail($tokenId, $reason);
    
    // Log behavior
    $this->logBehaviorAction($tokenId, $nodeId, 'QC_SINGLE', 'qc_fail', ...);
    
    return $result;
}
```

**FailureRecoveryService (Owner):**
```php
class FailureRecoveryService {
    function handleQcFail($tokenId, $reason) {
        // 1. Scrap token
        $this->lifecycleService->scrapToken($tokenId, $reason);
        
        // 2. Spawn replacement
        $newTokenId = $this->spawnReplacementToken($tokenId);
        
        return [
            'ok' => true,
            'effect' => 'qc_fail_recovered',
            'scrapped_token_id' => $tokenId,
            'replacement_token_id' => $newTokenId
        ];
    }
}
```

### 7.2 Wrong Tray Detection

```php
// Behavior checks tray (delegates to validation service)
function handleStart($tokenId, $scannedTrayCode) {
    $validation = $this->recoveryService->validateTray($tokenId, $scannedTrayCode);
    
    if (!$validation['valid']) {
        return [
            'ok' => false,
            'error' => 'WRONG_TRAY',
            'message' => $validation['message'],
            'correct_tray' => $validation['correct_tray']
        ];
    }
    
    // Continue normal execution
}
```

### 7.3 Failure Delegation Table

| Failure Scenario | Behavior Action | Service Call |
|------------------|----------------|--------------|
| QC fail | Return error + reason | `FailureRecoveryService::handleQcFail()` |
| Component scrapped | Return error | `FailureRecoveryService::handleComponentScrapped()` |
| Wrong tray | Block operation | `FailureRecoveryService::validateTray()` |
| Partial component | Block merge | `ComponentFlowService::validateMergeReadiness()` |
| Final cancel | Cascade cancel | `FailureRecoveryService::cascadeCancelFinal()` |

**Behavior Responsibility:**
- ✅ Trigger recovery service
- ✅ เก็บ context (reason, scanned_tray, etc.)
- ✅ แจ้งเหตุผล
- ❌ ไม่ implement recovery business logic

---

## 8. Behavior UI Contract (Backend Only)

**Purpose:** กำหนดข้อมูลที่ Behavior API ต้องส่งให้ UI (ไม่ใช่กำหนด layout)

### 8.1 Separation of Concerns

**Backend Responsibility (Behavior API):**
- ✅ Fetch token data
- ✅ Fetch component summary (if component token)
- ✅ Fetch tray info (if applicable)
- ✅ Fetch sibling component status (if parallel group)
- ✅ Return structured JSON

**Frontend Responsibility:**
- ✅ Render template ตาม token_type
- ✅ Display component list, badges, progress
- ✅ Handle layout, styling, i18n wording

**Backend MUST NOT:**
- ❌ Return HTML markup
- ❌ Define CSS classes
- ❌ Define UI wording (ให้ frontend i18n)

### 8.2 API Endpoint: getBehaviorContext

**Endpoint:** `dag_behavior_exec.php?action=get_context&token_id=123`

**Response Structure:**

```json
{
  "ok": true,
  "context": {
    "token": {
      "id_token": 123,
      "token_type": "component",
      "serial_number": "C-BODY-001",
      "status": "active",
      "metadata": {"component_code": "BODY"}
    },
    "node": {
      "id_node": 456,
      "node_name": "Stitch Body",
      "behavior_code": "STITCH",
      "execution_mode": "piece"
    },
    "parent": {
      "id_token": 100,
      "serial_number": "F001",
      "token_type": "piece"
    },
    "tray": {
      "tray_code": "T-F001",
      "final_serial": "F001"
    },
    "siblings": [
      {"component_code": "BODY", "status": "active", "worker_name": "Alice"},
      {"component_code": "FLAP", "status": "completed", "worker_name": "Bob"},
      {"component_code": "STRAP", "status": "ready", "worker_name": null}
    ]
  }
}
```

**Implementation:**

```php
case 'get_context':
    $tokenId = (int)($_GET['token_id'] ?? 0);
    
    $context = [
        'token' => $this->fetchToken($tokenId),
        'node' => null,
        'parent' => null,
        'tray' => null,
        'siblings' => null
    ];
    
    $token = $context['token'];
    
    // Get node
    if ($token['current_node_id']) {
        $context['node'] = $this->fetchNode($token['current_node_id']);
    }
    
    // If component token → get parent + siblings + tray
    if ($token['token_type'] === 'component') {
        $context['parent'] = $this->fetchToken($token['parent_token_id']);
        $context['siblings'] = $this->componentService->getSiblingStatus($token['parallel_group_id']);
        $context['tray'] = $this->componentService->getTrayByFinalToken($token['parent_token_id']);
    }
    
    // If final token at merge → get components
    if ($token['token_type'] === 'piece' && $token['status'] === 'waiting') {
        $context['siblings'] = $this->componentService->getComponentsByParent($tokenId);
        $context['tray'] = $this->componentService->getTrayByFinalToken($tokenId);
    }
    
    json_success(['context' => $context]);
    return;
```

**Frontend Usage:**

```javascript
// Frontend responsibility (NOT backend)
function renderBehaviorUI(tokenId) {
    $.get('dag_behavior_exec.php', {action: 'get_context', token_id: tokenId}, function(resp) {
        if (resp.ok) {
            const {token, node, parent, tray, siblings} = resp.context;
            
            // Frontend decides how to render (NOT backend)
            if (token.token_type === 'component') {
                renderComponentWorkerView(token, parent, tray, siblings, node);
            } else {
                renderAssemblyWorkerView(token, siblings, tray, node);
            }
        }
    });
}
```

---

## 9. Work Center Configuration (User Flexibility)

### 9.1 Work Center Creation Rules

**User CAN:**
- ✅ สร้าง Work Center ใหม่ได้ไม่จำกัด
- ✅ ตั้งชื่อตามสถานีจริง (Lining Front Panel, Skive Body, etc.)
- ✅ เลือก Behavior จากชุดที่ระบบเตรียมไว้
- ✅ กำหนด worker assignment, work center type

**User CANNOT:**
- ❌ สร้าง Behavior Code ใหม่เองผ่าน UI
- ❌ แก้ behavior logic ผ่าน UI
- ❌ เปลี่ยน UI template ของ behavior

**Why:** Behavior ผูกกับ handler + UI template + lifecycle → ต้องให้ dev/admin ดูแล

### 9.2 Work Center UI (Behavior Selection)

**On Create Work Center:**

```
┌─────────────────────────────────────────┐
│ Create Work Center                      │
│                                         │
│ Name: [Lining – Front Panel________]   │
│                                         │
│ Behavior: [Dropdown ▼]                 │
│   - GLUE (Single-piece glue work)      │
│   - STITCH (Single-piece stitch work)  │
│   - EDGE (Multi-round edge work)       │
│   - SKIVE (Leather thickness)          │
│   - QC_SINGLE (Component/Piece QC)     │
│   - ASSEMBLY (Merge components)        │
│   - PACK (End-of-line packing)         │
│   - ... (other predefined behaviors)   │
│                                         │
│ [Save] [Cancel]                        │
└─────────────────────────────────────────┘
```

**⚠️ Token Type Authority:**

**Token type ที่ work center รองรับ = derived from:**
1. Graph routing (node position in routing_graph)
2. Behavior-token compatibility matrix (Section 3)

**NOT user-selected during work center creation.**

**Why:**
- Token type ถูกกำหนดโดย graph design (split node → component tokens, normal node → piece tokens)
- Work center ควร map กับ nodes ที่มี token_type ตรงกับ behavior ที่รองรับ
- ถ้าให้ user เลือก token_type freely → อาจ mismatch กับ graph → validation errors

**Alternative UI Design (Preferred):**
- Work Center creation: เลือกแค่ Behavior + Assign to Nodes (ใน Graph Designer)
- Token type = auto-derived from node position + behavior matrix
- System validates compatibility automatically

**Validation:**
```php
function validateWorkCenterConfig($behaviorCode, $tokenType) {
    // Check compatibility matrix
    if (!$this->validateBehaviorTokenType($behaviorCode, $tokenType)) {
        return [
            'valid' => false,
            'error' => "{$behaviorCode} cannot work with {$tokenType} tokens"
        ];
    }
    
    return ['valid' => true];
}
```

### 9.3 Behavior Neutrality

**Principle:** Behavior ไม่รู้เรื่องชื่อสินค้า/ขั้นตอนเฉพาะ

**Behavior แค่รู้:**
- Token type (piece/component/batch)
- Node type (normal/split/merge)
- Work center context (from `work_center_id`)

**Example:**

```php
// Behavior GLUE ไม่รู้ว่ากำลัง glue:
// - Lining
// - Pocket
// - Edge Fold
// - Body reinforcement

// Behavior แค่รู้ว่า:
function handleGlue($tokenId, $nodeId) {
    $token = $this->fetchToken($tokenId);
    
    // แค่รู้ว่า:
    // - token_type = 'component' หรือ 'piece'
    // - component_code = 'BODY' (ถ้ามี)
    // - work_center_id = 123 (context)
    
    // ไม่สนว่า "GLUE นี่คือขั้นตอน Lining หรือ Edge Fold"
    // Work center description ค่อยบอก
}
```

**Benefits:**
- ✅ Behavior layer กลาง → reusable
- ✅ ถ้าอนาคต Classic line ต้องการ Work Queue → map มาใช้ behavior เดียวกันได้
- ✅ ถ้ามีสินค้าใหม่ → สร้าง work center ใหม่, ไม่ต้องสร้าง behavior ใหม่

---

## 10. Anti-Patterns

### 10.1 DO NOT Update Token Status Directly

```php
// ❌ WRONG
UPDATE flow_token SET status = 'active' WHERE id_token = ?

// ✅ RIGHT
$this->lifecycleService->startWork($tokenId);
```

### 10.2 DO NOT Implement Split/Merge Logic in Behavior

```php
// ❌ WRONG - Split logic in behavior
function handleStitchComplete() {
    if ($node['is_parallel_split']) {
        foreach ($edges as $edge) {
            spawnComponentToken(...); // ❌ Behavior shouldn't spawn
        }
    }
}

// ✅ RIGHT - Delegate to lifecycle
function handleStitchComplete() {
    $this->lifecycleService->completeNode($tokenId, $nodeId);
    // Lifecycle routes to ParallelCoordinator if split node
}
```

### 10.3 DO NOT Create Behavior Code per Product Step

```php
// ❌ WRONG - Too specific
$behaviors = ['LINING_REBELLO', 'LINING_TOTE', 'POCKET_FRONT_STITCH'];

// ✅ RIGHT - Generic pattern
$behaviors = ['GLUE', 'STITCH'];
$workCenters = ['Lining Rebello', 'Lining Tote', 'Pocket Front Stitch'];
```

### 10.4 DO NOT Define UI Layout in Backend

```php
// ❌ WRONG
function getBehaviorUI($tokenId) {
    return [
        'html' => '<div class="component-card">...</div>',
        'css' => '.component-card { color: red; }'
    ];
}

// ✅ RIGHT
function getBehaviorContext($tokenId) {
    return [
        'token' => [...],
        'components' => [...],
        'tray' => [...]
    ];
    // Frontend handles rendering
}
```

---

## 11. Implementation Priority

### Priority 1: Token Lifecycle Integration (BLOCKER)
**Effort:** 2-3 days  
**Owner:** TokenLifecycleService + BehaviorExecutionService glue

**Tasks:**
1. Create `TokenLifecycleService` (if not exists)
   - `startWork($tokenId)` → `ready` → `active`
   - `pauseWork($tokenId)` → `active` → `paused`
   - `resumeWork($tokenId)` → `paused` → `active`
   - `completeNode($tokenId, $nodeId)` → routes by node type
   - `scrapToken($tokenId, $reason)` → `active` → `scrapped`

2. Update BehaviorExecutionService handlers:
   - Remove direct `UPDATE flow_token.status`
   - Add lifecycle API calls
   - Test with all behaviors (STITCH, CUT, EDGE, QC, etc.)

**Deliverables:**
- All token status transitions go through TokenLifecycleService
- Behavior Layer = orchestrator only

### Priority 2: Component Flow Integration (BLOCKER)
**Effort:** 3-5 days  
**Owner:** ComponentFlowService + ParallelMachineCoordinator + Behavior glue

**Tasks:**
1. Create `ComponentFlowService`:
   - `onComponentCompleted($tokenId, $context)` → write component metadata
   - `isReadyForAssembly($finalTokenId)` → validate components complete
   - `getSiblingStatus($parallelGroupId)` → for UI context
   - `aggregateComponentTimes($finalTokenId)` → for merge

2. Update ParallelMachineCoordinator:
   - `handleSplit($tokenId, $nodeId)` → spawn component tokens
   - `completeMergeNode($tokenId, $nodeId)` → validate + re-activate parent

3. Update BehaviorExecutionService:
   - Add token_type validation (matrix check)
   - Add component hooks (onComponentCompleted, isReadyForAssembly)
   - Test component parallel flow

**Deliverables:**
- Component metadata managed by ComponentFlowService
- Split/merge handled by ParallelMachineCoordinator
- Behavior supports all token types

### Priority 3: Failure Recovery (HIGH)
**Effort:** 3-4 days  
**Owner:** FailureRecoveryService

**Tasks:**
1. Create `FailureRecoveryService`:
   - `handleQcFail($tokenId, $reason)` → scrap + spawn replacement
   - `handleComponentScrapped($tokenId)` → recovery options
   - `validateTray($tokenId, $scannedTray)` → wrong tray detection
   - `cascadeCancelFinal($finalTokenId)` → cancel all components

2. Update Behavior handlers to call recovery service

**Deliverables:**
- All failure scenarios handled
- Production-ready error recovery

### Priority 4: UI Data Contract (MEDIUM)
**Effort:** 2-3 days  
**Owner:** Backend API + Frontend

**Tasks:**
1. Create `get_context` API endpoint (return token + components + tray)
2. Frontend updates behavior templates (component view + assembly view)
3. Test UI with component tokens

**Deliverables:**
- Clean data/presentation separation
- Component UI + Assembly UI working

---

## 12. References

**Core Architecture:**
- `SUPERDAG_TOKEN_LIFECYCLE.md` - Token lifecycle model
- `COMPONENT_PARALLEL_FLOW_SPEC.md` - Component flow rules

**Developer Guide:**
- `../../developer/03-superdag/03-specs/BEHAVIOR_APP_CONTRACT.md` - API contracts

**Audit:**
- `../00-audit/20251202_BEHAVIOR_LAYER_AUDIT_REPORT.md` - Current gaps

---

## 13. Version History

**v2.0 (2025-12-02):**
- Complete rewrite based on feedback
- Added Section 1: Behavior vs Work Center (conceptual framework)
- Added Section 2: Behavior Code Guidelines (when to create new)
- Added Section 3: Behavior-Token Type Compatibility Matrix
- Added Section 4: Behavior → Token Lifecycle Transition (mapping table)
- Added Section 5: Per-Behavior Execution Contract (6 behaviors)
- Added Section 6: Component Awareness Hook (3 hooks)
- Added Section 7: Failure Modes Hook (delegation table)
- Added Section 8: Behavior UI Contract (backend only)
- Added Section 9: Work Center Configuration (user flexibility)
- Added Section 10: Anti-Patterns (4 rules)
- Example: Lining decision (ไม่ต้องสร้าง behavior ใหม่)
- Clear ownership model (lifecycle, component, parallel, recovery services)

**v1.0 (2025-12-02):**
- Initial draft

---

**END OF SPEC**
