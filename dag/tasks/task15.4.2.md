

# Task 15.4.2 — API Dual‑Mode Migration (Work Center + UOM)

## เป้าหมาย
ทำให้ API ทั้งหมดที่เคยใช้ `id_work_center` และ `id_uom` รองรับการส่งค่าด้วย **code** ได้ทันที โดยไม่ทำลาย backward compatibility

## หลักการทำงาน
API ทุกตัวต้อง:
1. รับ **code หรือ id** ได้ (dual‑mode)
2. Resolve ด้วย `WorkCenterService::resolveId()` หรือ `UOMService::resolveId()`
3. Response ต้องส่งทั้ง:
   - `id_work_center` + `work_center_code`
   - `id_uom` + `uom_code`
4. หากกรณี code กับ id mismatch → เข้าสู่ error log แต่ไม่ hard fail

---

# รายการไฟล์ที่ต้องแก้ไขใน Phase 2

## 1. `dag_workcenter_api.php`
- start_work
- stop_work
- switch_work_center
- list_work_centers
**Update Required:** resolve by code

## 2. `dag_behavior_exec.php`
- ควรรับ `work_center_code` จาก front‑end
- ส่งคืน code เสมอใน JSON response

## 3. `dag_routing_api.php`
- create/update routing node
- graph designer node properties
- Must replace id lookup → code lookup

## 4. `job_ticket.php`
- job_task_create
- job_task_update
- job_ticket_assign
- job_ticket_reassign

## 5. `work_center.php`
- create
- update
- delete (ต้อง block ถ้า is_system=1)

## 6. `uom.php`
- create/update UOM
- uom conversion tables

## 7. `mo.php`
- mo_create
- mo_update
- mo_import

## 8. `materials.php`
- material_create/update
- lot_create

---

# API Update Template

## Input Handling
```php
$wcService = new \BGERP\Service\WorkCenterService($tenantDb);

$id_work_center = $wcService->resolveId(
    code: $_POST['work_center_code'] ?? null,
    id: isset($_POST['id_work_center']) ? (int)$_POST['id_work_center'] : null
);
```

## Output
```php
$response['work_center'] = [
    'id'   => $row['id_work_center'],
    'code' => $row['work_center_code']
];
```

---

# Error Handling Template
(ไม่ fail hard)
```php
if ($id_work_center === null) {
    LogHelper::warn("WC code resolution failed", [
        'code' => $_POST['work_center_code'] ?? null,
        'id'   => $_POST['id_work_center'] ?? null
    ]);
}
```

---

# Testing Checklist

- [ ] ส่งเฉพาะ id → ผ่าน
- [ ] ส่งเฉพาะ code → ผ่าน
- [ ] ส่ง id + code = mismatch → ผ่าน + logged
- [ ] Response ต้องมีทั้ง id และ code

---

# สถานะ
Task 15.4.2 พร้อมดำเนินการในโค้ด API แล้ว
รอ Phase 3 (JS migration)