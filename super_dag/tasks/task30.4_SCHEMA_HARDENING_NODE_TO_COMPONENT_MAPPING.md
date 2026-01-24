# Task 30.4: Schema Hardening (Node-to-Component Mapping) — Optional

**Status:** 📋 **TODO**  
**Priority:** 🟡 **HIGH**  
**Phase:** 3 (Execution Layer)  
**Estimate:** 1-2 days  
**Depends On:** Task 30.3 findings (only if runtime needs persistent mapping)

---

## Goal

ถ้า runtime ต้องใช้ “node-to-component mapping” แบบถาวร (ไม่อิง config/metadata ชั่วคราว) ให้เพิ่ม schema ที่จำเป็นแบบ idempotent ด้วย tenant migration (PHP) และทำให้การ implement split/merge ตรงตาม SPEC โดยไม่เดา

---

## Decision Gate (Do/Skip)

### Do this task when:
- Split logic ต้องรู้ว่า node ใด “produce component อะไร” แบบถาวร และไม่ควร encode ใน code
- Merge node ต้องรู้ว่า “consume components อะไรบ้าง” แบบ explicit เพื่อคำนวณ readiness อย่างแม่นยำ

### Skip when:
- ใช้ graph snapshot payload/config_json เป็น mapping ได้อย่างปลอดภัย และไม่ต้องเพิ่ม columns ตอนนี้

---

## Proposed Schema (Tenant)

### Add fields to `routing_node`
- `produces_component` VARCHAR(50) NULL
- `consumes_components` JSON NULL

> หมายเหตุ: ต้อง align กับ `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md`

---

## Deliverables

- [ ] Tenant migration (PHP) ใน `database/tenant_migrations/`
  - [ ] add columns idempotent ด้วย `migration_add_column_if_missing()`
  - [ ] add indexes (ถ้าจำเป็น) ด้วย `migration_add_index_if_missing()`
  - [ ] `ANALYZE TABLE routing_node`
- [ ] Update docs/schema reference (ถ้าจำเป็น)
- [ ] Smoke test migration (apply twice ต้องไม่พัง)

---

## Acceptance Criteria

- [ ] ไม่สร้างไฟล์ `.sql` (PHP migration เท่านั้น)
- [ ] Migration รันซ้ำได้ (idempotent)
- [ ] ไม่มี raw SQL string concatenation สำหรับ user input

---

**Next Task:** Return to Task 30.3 (wire mapping into runtime) or close if skipped

