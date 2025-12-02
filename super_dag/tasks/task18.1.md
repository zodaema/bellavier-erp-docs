Task 18.1 — Machine × Parallel Combined Execution Logic

Status: NEW
Category: Super DAG – Execution Layer (Phase 7.1)
Depends on:
	•	Task 17 (Parallel/Merge semantics)
	•	Task 18 (Machine cycle support)
	•	Task 17.2 (Parallel validation & legacy cleanup)

⸻

🎯 Objective

เพิ่ม “กฎผสม” ระหว่าง Parallel Execution และ Machine-Based Execution
เพื่อให้ระบบสามารถจัดการกรณีซับซ้อน เช่น:
	1.	Parallel branches ที่แต่ละ branch ใช้เครื่องไม่เหมือนกัน
	2.	Parallel branches ที่ต้องใช้เครื่อง แต่ “หมดคิว” อยู่
	3.	Merge node ที่ต้องตัดสิน “อะไรถือว่าเสร็จจริง” ถ้า branch ต่างกันด้าน machine cycle
	4.	Machine limitations (cycle time / concurrency) ส่งผลต่อ merge semantics เช่น ALL หรือ WAIT-ALL
	5.	การคาดการณ์ total time ของ parallel block

⸻

🧩 ปัญหาปัจจุบันถ้าไม่ทำ Task นี้

แม้ Task 17 และ 18 ทำงานได้ดี แต่มี “รูรั่ว”:

❌ เคส 1: Parallel 2 เส้น แต่เส้น A ต้องใช้เครื่อง, เส้น B ไม่ต้องใช้

→ merge จะรอ A หรือไม่?
→ ถ้า A คิวยาว, B เสร็จเร็ว → merge ตัน

❌ เคส 2: Parallel 2 เส้น ใช้เครื่องชนิดเดียว

→ concurrency_limit = 1
→ ทั้งคู่ต้องรอคิว → แต่ tokens ถูกปล่อยพร้อมกัน
→ ต้องมี Intelligent queue management

❌ เคส 3: Parallel 3 เส้น ใช้คนละเครื่อง แต่เครื่องหนึ่งพัง (deactivated)

→ merge จะไม่มีวันมาถึง
→ DAG จะเข้าสู่ deadlock

❌ เคส 4: Parallel block เวลาเสร็จไม่สามารถคาดการณ์ได้

→ ทำ SLA มิได้
→ จะไป Task 19 ไม่ได้

⸻

📐 Scope

In-Scope (ต้องทำ)
	•	Algorithm merge-aware machine waiting
	•	Parallel + machine-aware scheduling
	•	Merge dependency graph
	•	Timeout/Deadlock detection
	•	Predictive available time (ETA)

Out-of-Scope (ทำต่อใน Task 19–20)
	•	SLA model
	•	Priority dispatch
	•	Skill-based routing

⸻

📦 Deliverables

1. Parallel×Machine Execution Rules Engine (NEW FILE)

File:
source/BGERP/Dag/ParallelMachineCoordinator.php

หน้าที่ของไฟล์นี้:

✔ 1. ตรวจสอบว่า parallel block ควรเริ่มเมื่อไหร่
	•	ถ้า parent node เป็น machine node ต้องรอ “release” ก่อน split
	•	Token child ต้องถูกกระจายอย่างถูกต้อง

✔ 2. บริหาร Machine Allocation แยกต่อ branch
	•	ถ้า branch ใช้เครื่องที่ concurrency = 1
→ ต้องจัด queue token เป็นรายเครื่อง
	•	ถ้าหลาย branch แย่งเครื่องเดียวกัน
→ ต้อง queue โดย priority = branch index หรือ rule ใหม่

✔ 3. คำนวณ merge readiness
	•	สำหรับ merge ALL:
	•	token ทุก branch ต้องอยู่ในสถานะ:
	•	completed หรือ
	•	machine allocated + completed_time ส่งแล้ว
	•	ถ้า branch ใด “pending machine slot” → merge ไม่สามารถ fire ได้
	•	แต่ ต้องรู้ว่ามัน pending เพราะอะไร เช่น:
	•	machine full
	•	machine inactive
	•	machine_binding_mode ไม่ valid

✔ 4. Deadlock detection
กรณี:
	•	node A split → node B,C
	•	node B ต้องใช้เครื่องที่ dead/inactive
	•	node C เสร็จแล้ว → merge stuck ตลอดกาล

ระบบต้อง detect:

parallel_block.deadlock = true
parallel_block.stuck_reason = MACHINE_UNAVAILABLE

และส่ง warning event ให้ frontend

⸻

2. Update DAGRoutingService (patch)

เพิ่ม:

ParallelMachineCoordinator->onSplit($tokenId, $nodeId);
ParallelMachineCoordinator->onMergeCheck($graphId, $mergeNodeId);

จุดที่ patch:
	•	routeToNode() หลัง allocate machine
	•	routeToken() ก่อน merge
	•	allocateMachine() ถ้ machine full → inform coordinator

⸻

3. Merge Node Enhancements

เพิ่มฟิลด์ใหม่:

In routing_node

parallel_merge_timeout_seconds INT NULL
parallel_merge_policy ENUM('ALL','ANY','AT_LEAST','TIMEOUT_FAIL')
parallel_merge_at_least_count INT NULL

ใช้ในอนาคตด้วย แต่เพิ่มไว้เลยเพื่อกัน effort ซ้ำ

⸻

4. Graph Designer UI Enhancements

เพิ่มใน node properties (เฉพาะ merge node):
	•	Merge Policy (ALL, ANY, AT_LEAST)
	•	Timeout (seconds)
	•	At-least count (ถ้า AT_LEAST)

Serializers ต้อง support ค่านี้

⸻

5. Extend GraphSaver.js & dag_routing_api

เพิ่มฟิลด์ใหม่:

parallel_merge_policy
parallel_merge_timeout_seconds
parallel_merge_at_least_count

พร้อม validation

⸻

🔧 Core Algorithm (สำคัญที่สุด)

✔ Split Phase
	1.	parent เสร็จ
	2.	generate parallel_group_id
	3.	generate children
	4.	สำหรับแต่ละ branch:
	•	ถ้า machine_binding_mode=NONE → proceed
	•	ถ้า machine_binding_mode≠NONE → call allocateMachine()
	•	ถ้าขาดเครื่อง → mark waiting

✔ Branch Execution Phase

แต่ละ branch เกิด waiting / active / completed
ParallelMachineCoordinator ติดตาม state

✔ Merge Phase

เมื่อ token ใดใน branch ถึง merge node:

if parallel_merge_policy == ALL:
    if all children status == completed:
        allow merge
    else:
        wait

แต่สิ่งใหม่คือ:

ต้องเรียก coordinator เพื่อตรวจ:

coordinator->isBranchStuck($parallel_group_id)
coordinator->getETA($parallel_group_id)

ถ้า stuck:

status = DEADLOCK
event = parallel_block_deadlocked


⸻

🧪 Test Cases ที่ต้องผ่าน

TC1: Parallel 2 เส้น แต่คิวเครื่องไม่เท่ากัน

→ merge รอถูกต้อง

TC2: Parallel 2 เส้น ใช้เครื่องเดียวกัน แต่ concurrency=1

→ branch A ได้ก่อน
→ branch B ต้อง wait
→ merge รอ B

TC3: Parallel 3 เส้น เส้นหนึ่งเครื่อง inactive

→ coordinator detect deadlock

TC4: ANY merge policy

→ ไม่จำเป็นต้องรอทุกเส้น
→ fire merge ได้เร็ว

TC5: TIMEOUT_FAIL

→ ถ้า wait เกินเวลา → block branch → mark failed → merge fail

⸻

📝 สรุปความสำคัญของ Task 18.1

นี่คือ “กาว” ที่ทำให้ Task 17 (Parallel) และ Task 18 (Machine Cycle) ทำงานเป็นชุดเดียวกัน
ถ้าไม่ทำ task นี้:
	•	merge จะผิด logic
	•	งานจะตีบตันเมื่อเครื่องขาด
	•	ระบบจะไม่รู้จัก deadlock
	•	ไม่สามารถไป Task 19 (SLA) ได้
	•	ไม่สามารถไป Task 20 (AI routing optimization) ได้

ดังนั้น Task 18.1 เป็นหัวใจสำคัญของ Execution Engine ที่สมบูรณ์

⸻
# Task 18.1 — Machine × Parallel Combined Execution Logic

**Status:** NEW  
**Category:** Super DAG – Execution Layer (Phase 7.1)  
**Depends on:**  
- Task 17 (Parallel/Merge semantics)  
- Task 18 (Machine cycle support)  
- Task 17.2 (Parallel validation & legacy cleanup)

---

# 🎯 Objective

เพิ่ม **กฎผสมระหว่าง Parallel Execution และ Machine-Based Execution**
เพื่อให้ระบบสามารถจัดการกรณีซับซ้อน เช่น:

1. Parallel branches ที่แต่ละ branch ใช้เครื่องไม่เหมือนกัน
2. Parallel branches ที่ต้องใช้เครื่อง แต่ “หมดคิว” อยู่
3. Merge node ที่ต้องตัดสินว่า "อะไรถือว่าเสร็จจริง" หากแต่ละ branch มี machine cycle ต่างกัน
4. Machine limitations (cycle time / concurrency) ส่งผลต่อ merge semantics เช่น ALL / ANY / AT_LEAST / TIMEOUT_FAIL
5. การคาดการณ์เวลาเสร็จของทั้ง parallel block (total time / ETA)

Task 18.1 = ทำให้ Task 17 (Parallel) และ Task 18 (Machine) **ทำงานเป็นเซ็ตเดียวกันอย่างถูกต้อง**

---

# 🧩 ปัญหาถ้าไม่ทำ Task นี้

แม้ Task 17 และ 18 ทำงานได้ดีในมิติของตัวเอง แต่เมื่อรวมกันแล้วยังมี “รูรั่ว” สำคัญ:

### ❌ เคส 1: Parallel 2 เส้น แต่เส้น A ใช้เครื่อง, เส้น B ไม่ใช้เครื่อง

- A ต้องรอคิวเครื่อง (machine queue)  
- B ทำเสร็จเร็วแล้วรอ merge
- ถ้าไม่มี logic ผสม → ไม่ชัดเจนว่า merge ควรรอ A หรือไม่ / จะเกิด starvation หรือไม่

### ❌ เคส 2: Parallel 2 เส้น ใช้เครื่องชนิดเดียวกัน

- เครื่องมี `concurrency_limit = 1`
- ระบบปล่อย token ทั้งสอง branch พร้อมกัน → ทั้งคู่แย่งใช้เครื่อง
- ต้องมี **queue ต่อเครื่อง** และ policy ชัดเจนว่าใครได้ก่อน

### ❌ เคส 3: Parallel 3 เส้น แต่เครื่องของเส้นหนึ่งพัง (inactive)

- Branch นั้นไม่มีวันเริ่มได้  
- Merge node ที่รอ ALL จะไม่ถึงตลอดกาล → เกิด deadlock

### ❌ เคส 4: Parallel block ไม่มี ETA ที่แม่นยำ

- ไม่สามารถคำนวณ SLA รวมของ block ได้  
- Task 19 (SLA / Time Modeling) จะขาดฐานข้อมูลที่เชื่อถือได้

---

# 📐 Scope

## In Scope (ต้องทำใน Task นี้)

- Algorithm สำหรับ **merge-aware machine waiting**
- **Parallel + machine-aware scheduling** ต่อ branch
- การ tracking **merge dependency graph** สำหรับ parallel block
- **Timeout / Deadlock detection** ใน parallel block ที่พึ่งพาเครื่องจักร
- การคำนวณ **predictive ETA** แบบคร่าว ๆ ในระดับ block (สำหรับใช้ต่อใน Task 19)

## Out of Scope (ทำใน Task 19–20)

- SLA model เต็มรูปแบบ (per node, per block, per order)
- Priority dispatch / skill-based routing
- แดชบอร์ดแสดง Gantt / Timeline / Machine load แบบ UI เต็มรูปแบบ

---

# 📦 Deliverables

## 1. Parallel × Machine Execution Rules Engine

**New file:**

`source/BGERP/Dag/ParallelMachineCoordinator.php`

### หน้าที่หลักของ ParallelMachineCoordinator

#### 1.1 ตรวจสอบว่า parallel block ควรเริ่มเมื่อไหร่

- ถ้า parent node เป็น machine-bound node → ต้องรอให้ machine cycle ของ parent เสร็จ (release) ก่อน split
- สร้าง `parallel_group_id` และ child tokens อย่างถูกต้อง

#### 1.2 บริหาร Machine Allocation แยกต่อ branch

สำหรับแต่ละ branch ใน parallel group:

- ถ้า branch ใช้เครื่องที่ `concurrency_limit = 1` → ต้องจัด queue token เป็นรายเครื่อง
- ถ้าหลาย branch แย่งเครื่องเดียวกัน → ต้องจัด queue ตาม policy (เช่น FIFO, branch index, priority ในอนาคต)
- ถ้า machine ถูก deactivate หรือไม่พร้อมใช้งาน → mark branch ว่า "blocked by machine"

#### 1.3 คำนวณ merge readiness

สำหรับ **merge node** ภายใต้ `parallel_group_id` เดียวกัน:

- merge_mode = `ALL`:
  - ทุก branch ต้องอยู่ในสถานะ **completed**  
    (รวมถึง complete machine cycle แล้ว ถ้ามี)
- ถ้า branch ใดกำลัง "รอคิวเครื่อง" (pending machine slot) → merge จะยัง fire ไม่ได้
- Coordinator ต้องเก็บ context ว่า branch pending เพราะ:
  - machine full
  - machine inactive
  - machine_binding_mode ไม่ valid

#### 1.4 Deadlock detection (parallel + machine)

กรณีตัวอย่าง:

- Node A split → Node B, C  
- Node B ต้องใช้เครื่องที่ inactive/dead  
- Node C ทำงานเสร็จแล้วและมาถึง merge node  
- ผล: merge จะไม่เกิดขึ้นเลย → deadlock

ระบบต้อง detect และตั้ง state เช่น:

```text
parallel_block.deadlock = true
parallel_block.stuck_reason = 'MACHINE_UNAVAILABLE'
```

และแจ้งเตือนผ่าน event ให้ frontend / log

> **Note:** Task นี้เป็นเพียง detection + state marking  
> การตัดสินใจว่าจะ handle ยังไง (ยกเลิก order, reroute, แจ้งเตือนมนุษย์) ทำใน Task ถัดไป

---

## 2. Update DAGRoutingService (patch)

ไฟล์หลัก:

- `source/BGERP/Service/DAGRoutingService.php`

### 2.1 Integrate Coordinator เข้ากับ flow ที่มี parallel

เพิ่มการเรียกใช้ ParallelMachineCoordinator ในจุดสำคัญ เช่น:

- หลังจาก split token:

```php
$parallelCoordinator->onSplit($parentTokenId, $splitNodeId, $childTokenIds);
```

- ก่อน merge node ประมวลผล:

```php
if ($node['is_merge_node']) {
    if (!$parallelCoordinator->canMerge($graphId, $node['id_node'], $parallelGroupId)) {
        // รอ branch อื่น หรือแจ้ง deadlock ตามสถานะ
        return;
    }
}
```

- หลังจาก machine allocation:
  - ถ้า machine full หรือไม่พร้อมใช้งาน → notify coordinator เพื่อ track สถานะ pending / blocked

ไม่ต้องย้าย core logic ของ routing ออกมา แค่ **ประกบเรียกใช้ coordinator** ในจุดที่เกี่ยวข้องกับ parallel + machine เท่านั้น

---

## 3. Merge Node Enhancements (Schema + Model)

**Migration:**

`database/tenant_migrations/2025_12_18_1_parallel_merge_policy.php`

เพิ่มฟิลด์ใน `routing_node` (หรือ table node metadata ที่ใช้จริง):

- `parallel_merge_policy` ENUM('ALL','ANY','AT_LEAST','TIMEOUT_FAIL') DEFAULT 'ALL'
- `parallel_merge_timeout_seconds` INT NULL  
- `parallel_merge_at_least_count` INT NULL

### ความหมายของค่า

- `ALL` → ต้องรอทุก branch เสร็จ (behavior ปัจจุบัน)
- `ANY` → branch ใด branchหนึ่งถึง merge node ก็ fire ได้เลย (ใช้ในบาง use-case เฉพาะ)
- `AT_LEAST` → ต้องมีตั้งแต่ N branches เสร็จขึ้นไป (config โดย `parallel_merge_at_least_count`)
- `TIMEOUT_FAIL` → ถ้าเกิน timeout ที่กำหนดให้ mark parallel block เป็น fail

> สำหรับ Task 18.1 ให้ implement อย่างน้อย `ALL` ให้สมบูรณ์  
> ค่าอื่นสามารถเตรียม field ไว้ หรือ implement แบบ basic ตามเวลาอนุญาต

---

## 4. Graph Designer UI Enhancements

ไฟล์หลัก:

- `assets/javascripts/dag/graph_designer.js`

### 4.1 Node Properties Panel (เฉพาะ Merge Node)

ใน panel ด้านขวาของ node properties:

- ถ้า node เป็น merge (`isMergeNode = true`) ให้แสดงส่วน:

**Merge Settings**
- Merge Policy: select box (ALL, ANY, AT_LEAST, TIMEOUT_FAIL)  
- Timeout (seconds): input number (ถ้าเลือก TIMEOUT_FAIL)  
- At-least count: input number (ถ้าเลือก AT_LEAST)

### 4.2 Serialization & Deserialization

- เวลาโหลดกราฟจาก API → map field:
  - `parallel_merge_policy`
  - `parallel_merge_timeout_seconds`
  - `parallel_merge_at_least_count`
- เวลา save กราฟ → ส่ง field เดียวกันกลับไปยัง API

---

## 5. Extend GraphSaver.js & dag_routing_api

### 5.1 GraphSaver.js

ไฟล์:

- `assets/javascripts/dag/modules/GraphSaver.js`

เพิ่มใน node payload:

```js
parallel_merge_policy: node.data('parallelMergePolicy') || 'ALL',
parallel_merge_timeout_seconds: node.data('parallelMergeTimeoutSeconds') || null,
parallel_merge_at_least_count: node.data('parallelMergeAtLeastCount') || null,
```

พร้อม validation เบื้องต้นใน `validateGraphStructure()`:

- ถ้า `parallel_merge_policy = 'AT_LEAST'` → `parallel_merge_at_least_count` ต้องเป็นตัวเลข ≥ 1
- ถ้า `parallel_merge_policy = 'TIMEOUT_FAIL'` → `parallel_merge_timeout_seconds` ต้องเป็นตัวเลข ≥ 1

### 5.2 dag_routing_api.php

ไฟล์:

- `source/dag_routing_api.php`

ในส่วนที่รับ node configuration:

- ยอมรับ field:
  - `parallel_merge_policy`
  - `parallel_merge_timeout_seconds`
  - `parallel_merge_at_least_count`
- ตรวจสอบค่าพื้นฐาน:
  - policy ต้องเป็นหนึ่งใน set ที่กำหนด
  - ค่า timeout / count ต้องเป็น integer valid หรือ NULL ตามเงื่อนไข

สามารถ reuse pattern validation จาก Task 17.2

---

# 🔧 Core Algorithm (สำคัญที่สุด)

## Split Phase

1. parent node เสร็จ (รวมถึง machine cycle ถ้ามี)
2. สร้าง `parallel_group_id` ใหม่
3. สร้าง child tokens ตามจำนวน outgoing branches
4. สำหรับแต่ละ branch:
   - ถ้า `machine_binding_mode = NONE` → เดินต่อทันที
   - ถ้า `machine_binding_mode ≠ NONE` → เรียก allocateMachine()
     - ถ้าได้เครื่อง → set `machine_cycle_started_at`
     - ถ้ายังไม่ได้เครื่อง (เต็ม / inactive) → mark token เป็น waiting + แจ้ง coordinator

## Branch Execution Phase

แต่ละ branch จะมีสถานะเปลี่ยนผ่าน:

- `WAITING_MACHINE`
- `IN_MACHINE`
- `COMPLETED`

ParallelMachineCoordinator ติดตาม state ทั้งชุดภายใต้ `parallel_group_id`

## Merge Phase

เมื่อ token ใดเข้าถึง merge node:

- ใช้ `parallel_merge_policy` ตัดสินใจ:

```pseudo
if policy == ALL:
    if ทุก branch ใน group อยู่สถานะ COMPLETED:
        allow merge
    else:
        wait

if policy == ANY:
    allow merge ทันทีที่ branch ใด branchหนึ่งมาถึง

if policy == AT_LEAST:
    if จำนวน branch COMPLETED >= at_least_count:
        allow merge
    else:
        wait
```

จากนั้น:

- เรียก `coordinator->isBlockStuck($parallel_group_id)`
- ถ้า stuck จริง (เช่น machine inactive, branch ไม่มีทางจบ):
  - mark block as DEADLOCK
  - emit event/log สำหรับให้มนุษย์ตัดสินใจ

---

# 🧪 Test Cases ที่ต้องผ่าน

**TC1: Parallel 2 เส้น แต่คิวเครื่องไม่เท่ากัน**  
- branch A ใช้เครื่อง, branch B manual  
- A คิวยาว, B เสร็จเร็ว  
- merge (ALL) ต้องรอ A อย่างถูกต้อง และไม่ deadlock

**TC2: Parallel 2 เส้น ใช้เครื่องเดียวกัน แต่ concurrency=1**  
- branch A และ B ใช้ machine M เดียวกัน  
- ระบบต้อง queue A/B บน M, และ merge รอให้ทั้งคู่จบ

**TC3: Parallel 3 เส้น เส้นหนึ่งเครื่อง inactive**  
- branch C ใช้ machine C1 ที่ inactive  
- coordinator ตรวจพบว่า branch C ไม่มีวันวิ่งได้  
- block ถูก mark เป็น DEADLOCK และ log เหตุผล

**TC4: ANY merge policy**  
- ตั้ง merge policy = ANY  
- branch A มาถึงก่อน → merge fire ได้ทันที  
- branch อื่น ๆ ถือว่า skipped หรือ handled ตาม policy ที่ตัดสินใจภายหลัง

**TC5: TIMEOUT_FAIL**  
- ตั้ง timeout ที่ merge node  
- หากเวลารอรวมของ parallel block เกินค่าที่กำหนด → mark block as FAIL  
- ไม่ปล่อยให้ระบบแช่แข็งไม่รู้จบ

---

# 📝 Summary

Task 18.1 เป็น “กาวเชื่อม” สำคัญระหว่าง:

- Task 17: Parallel / Merge Semantics  
- Task 18: Machine Cycles & Throughput

หากไม่มี Task 18.1:

- merge จะตีความผิดในกรณีมีเครื่องเข้าเกี่ยวข้อง
- งานจะตันเมื่อเครื่องขาด หรือ inactive โดยไม่มี state ชัดเจน
- ระบบไม่รู้จัก deadlock ใน parallel+machine
- ไม่สามารถไปต่อ Task 19 (SLA / Time Modeling) ได้อย่างมั่นใจ

หลัง Task 18.1 เสร็จ:

- Parallel blocks รู้ว่าตัวเองต้องรออะไร (branch ไหน, เครื่องไหน)
- Merge รู้ policy ชัดเจน (ALL/ANY/AT_LEAST/TIMEOUT_FAIL)
- Machine constraints ถูกนำมารวมในการตัดสินใจ merge
- ระบบมีพื้นฐานพร้อมสำหรับ Task 19–20 อย่างเป็นระบบ