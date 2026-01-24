# Task 30.3: Component Parallel Flow Runtime (Split + Merge)

**Status:** ✅ **COMPLETE**  
**Priority:** 🔴 **CRITICAL**  
**Phase:** 3 (Execution Layer)  
**Estimate:** 2-3 days  
**Depends On:** Task 30.1–30.2 (Determinism), `flow_token.component_code` SSOT, `parallel_merge_policy` SSOT
**Results:** `docs/super_dag/tasks/results/task30.3.results.md`

---

## Goal

Implement runtime สำหรับ “natural flow” ของ Hatthasilpa:
- **Split**: เมื่อ final token เข้า parallel split node → สร้าง component tokens ที่ทำงานแยกกันได้
- **Merge readiness**: คุม final token ให้ไปต่อได้เมื่อ component tokens “พร้อม” ตาม `parallel_merge_policy`

---

## Problem Statement

ปัจจุบัน concept/spec ชัดแล้วว่า:
- `flow_token.component_code` เป็น SSOT (CURRENT)
- merge policy SSOT อยู่ที่ `routing_node.parallel_merge_policy`

แต่ runtime ยังต้องทำให้ครบ:
- สร้าง component tokens แบบ deterministic + idempotent
- ประเมิน merge readiness ตาม policy จริง
- กำหนด marker/state ที่สอดคล้องกับ schema ปัจจุบัน (หลีกเลี่ยงการเพิ่ม enum status แบบสุ่ม)

---

## Scope

### Included
- Split behavior: final token → component tokens
- Merge readiness evaluation: `ALL|ANY|AT_LEAST|TIMEOUT_FAIL`
- Merge action: unblock/route final token เมื่อ ready
- Integration tests ครอบ split/merge + safety/idempotency

### Excluded
- เพิ่ม UI ใหม่ทั้งหมดสำหรับ component handling (เว้น minimal data ที่จำเป็นให้ work queue แยกได้)
- เปลี่ยน schema ครั้งใหญ่ (ยกเว้นจำเป็นจริง → ส่งต่อไป task30.4)

---

## SSOT / Determinism Rules (Binding)

- **Component identity SSOT:** `flow_token.component_code`
  - ห้ามใช้ `metadata.component_code` เป็น SSOT
- **Merge policy SSOT:** `routing_node.parallel_merge_policy`
- หาก token/job pinned:
  - Routing ต้องใช้ snapshot edges/nodes ผ่าน `GraphSnapshotRuntimeService`

---

## Split: Required Data Contract

เมื่อสร้าง component token ต้องมีอย่างน้อย:
- `token_type = 'component'`
- `parent_token_id = <final_token_id>`
- `parallel_group_id` (shared among siblings)
- `parallel_branch_key` (unique per branch within group)
- `component_code` (SSOT)
- `current_node_id` (node ของ branch start/target)

### Idempotency Requirement (Critical)
- Split operation ต้องไม่สร้าง component tokens ซ้ำเมื่อถูกเรียกซ้ำ (เช่น retry)
- ต้องมี guard เช่น:
  - ใช้ idempotency key ผูกกับ `(final_token_id, split_node_id)` หรือ
  - ตรวจว่ามี component tokens สำหรับ `(parent_token_id, parallel_group_id/split_node)` แล้ว

---

## Merge Readiness: Policy Semantics

### `ALL`
- final token ไปต่อได้เมื่อ component tokens ในกลุ่ม “ครบทุก branch ที่คาดหวัง”

### `ANY`
- ไปต่อได้เมื่อ component ใด component หนึ่งพร้อม

### `AT_LEAST`
- ไปต่อได้เมื่อจำนวน component พร้อม ≥ `parallel_merge_at_least_count`

### `TIMEOUT_FAIL`
- ถ้าพ้น `parallel_merge_timeout_seconds` แล้วยังไม่ครบตามเกณฑ์ → mark fail (ตาม marker ที่ตกลง) และหยุด flow

> หมายเหตุ: “component พร้อม” ต้องนิยามจาก state/เหตุการณ์ที่ runtime ใช้จริง (เช่น token_event หรือ status lifecycle ปัจจุบัน) ไม่เพิ่ม enum แบบสุ่ม

---

## Merge Action: What Must Happen

เมื่อ merge ready:
- route/unblock final token ให้ไปต่อ node ถัดไป
- (optional) set marker ให้ component tokens ว่า merged แล้ว (ใช้ **metadata target** ที่ระบุใน concept/spec)

---

## Deliverables

- [ ] Routing/Split:
  - [ ] เพิ่ม/ต่อยอด logic ใน `DAGRoutingService` (หรือ service ที่เหมาะสม) เพื่อ detect `is_parallel_split=1`
  - [ ] สร้าง component tokens ผ่าน `TokenLifecycleService` (หรือ centralized creator) โดยใส่ field ตาม contract
- [ ] Merge readiness + action:
  - [ ] Implement evaluation ที่ node `is_merge_node=1` โดยใช้ `parallel_merge_policy` เป็น SSOT
  - [ ] Route final token ต่อเมื่อ ready
- [ ] Tests
  - [ ] Split creates deterministic component tokens (no duplicates)
  - [ ] Merge readiness policy tests (ALL/ANY/AT_LEAST/TIMEOUT_FAIL)
  - [ ] Pinned snapshot routing still deterministic during split/merge

---

## Acceptance Criteria

- [ ] Split ไม่สร้าง token ซ้ำเมื่อ retry
- [ ] `component_code` ถูก set เป็น SSOT ทุก component token
- [ ] Merge readiness ใช้ `parallel_merge_policy` เป็น SSOT และทำงานตาม semantics
- [ ] Final token ไม่ไปต่อก่อน merge ready (ตาม policy)
- [ ] Tests ผ่านทั้งหมด (`vendor/bin/phpunit`)

---

**Next Task:** 30.4 (Schema Hardening - optional)

