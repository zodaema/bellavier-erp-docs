# Task 21.4 – Internal Behavior Registry + Feature Flag Migration

**Status:** PLANNING  
**Category:** SuperDAG / Node Behavior Engine / Feature Flags  
**Date:** 2025-01-XX  

**Depends on:**
- Task 21.1 – Node Behavior Engine (Skeleton)
- Task 21.2 – Node Behavior Execution (Canonical Events Only)
- Task 21.3 – Persist Canonical Events to `token_event`
- `Node_Behavier.md` (Axioms + Canonical Events 3.9)
- `node_behavior_model.md` (Execution Context + Internal Registry, non-plugin)
- `core_principles_of_flexible_factory_erp.md` (ข้อ 13–15: Closed Logic, Canonical Events, Golden Rule)
- `SuperDAG_Execution_Model.md`, `time_model.md`, `component_binding_model.md`

---

## 1. Objective

1. สร้าง **Internal Behavior Registry** สำหรับ Node Behavior Engine  
   - เพื่อ map `node_mode` / `execution_mode` → handler ภายในที่ชัดเจน  
   - ป้องกันการเติบโตแบบ plugin/extension ที่หลุดจากแนวคิด Close System

2. สร้าง **Migration สำหรับ Feature Flag**  
   - ให้ `NODE_BEHAVIOR_EXPERIMENTAL` กลายเป็น feature flag ที่ถูกประกาศอย่างเป็นทางการใน core DB  
   - ตั้งค่า default เป็นปิด (OFF) สำหรับทุก tenant / ทุก environment  
   - ใช้โครงสร้างเดียวกับ feature flag เดิมในระบบ (อย่าคิด schema ใหม่เอง)

> เป้าหมาย Task 21.4 = ทำให้ Behavior Engine มี “ทะเบียนภายใน” ที่ควบคุมได้  
> และทำให้ Flag ที่คุมพฤติกรรมนี้ถูกประกาศและบริหารผ่าน DB ตามมาตรฐานของระบบ

---

## 2. Scope

### 2.1 In-Scope

1. **Internal Behavior Registry**

   - เพิ่ม class / เมธอดสำหรับ behavior registry ภายใน Node Behavior Engine เช่น:
     - `NodeBehaviorRegistry`
     - หรือ static map ภายใน `NodeBehaviorEngine`

   - Registry ต้องทำอย่างใดอย่างหนึ่ง:
     - map `execution_mode` → handler method name (`executeHatSingle`, `executeHatBatchQuantity`, `executeClassicScan`, `executeQcSingle`, …)  
     - หรือ map `node_mode` → handler class/strategy ภายใน

   - คุณสมบัติ:
     - ไม่เปิด API สำหรับภายนอก (Close System)  
     - Behavior ใหม่เพิ่มได้เฉพาะผ่าน code ใน core repo เท่านั้น  
     - สามารถใช้ใน unit test เพื่อ assert ว่า behavior ที่ประกาศใน `Node_Behavier.md` มี handler ครบทุกตัว

2. **Refactor `NodeBehaviorEngine::executeBehavior()` ให้ใช้ Registry**

   - แทนการ `switch` execution_mode ตรง ๆ ให้เรียกผ่าน registry:
     ```php
     $handler = $this->registry->getHandler($executionMode);
     if ($handler) {
         $canonicalEvents = $handler->handle($context);
     }
     ```
     หรือรูปแบบ method map เช่น:
     ```php
     $handler = $this->registry->getHandlerMethod($executionMode);
     if ($handler && method_exists($this, $handler)) {
         $canonicalEvents = $this->{$handler}($context);
     }
     ```

   - ใส่ guard:
     - ถ้า execution_mode ไม่เจอใน registry → log warning + return events ว่าง ๆ  
     - ห้าม throw exception ที่จะทำให้ token completion ล่ม (ยังอยู่ในโหมด experimental)

3. **Feature Flag Migration – NODE_BEHAVIOR_EXPERIMENTAL**

   - ค้นหา schema/table ที่ใช้เก็บ feature flag อยู่แล้วในระบบ:
     - อาจเป็น table เช่น: `feature_flag`, `core_feature_flag`, หรือชื่ออื่น  
     - ดูตัวอย่างจาก migration เดิมในโฟลเดอร์ migrations / core db

   - สร้าง migration ใหม่ใน core DB:
     - ชื่อไฟล์ให้สื่อถึง Task 21.4 และ flag นี้ เช่น:
       - `2025_XX_XX_2104_add_node_behavior_experimental_flag.php`
     - ใช้ helper/migration base class เดียวกับ migration เดิมของระบบ

   - เนื้อหา migration (Pseudo):
     ```php
     public function up(PDO $db): void
     {
         // ชื่อ table และ column ให้ดูจากระบบจริง ห้ามเดาเอง
         $sql = "INSERT INTO feature_flag (flag_key, description, is_enabled, created_at)
                 VALUES (:flag_key, :description, :is_enabled, NOW())";

         $stmt = $db->prepare($sql);
         $stmt->execute([
             ':flag_key'    => 'NODE_BEHAVIOR_EXPERIMENTAL',
             ':description' => 'Enable experimental Node Behavior Engine + Canonical Events pipeline',
             ':is_enabled'  => 0, // default OFF
         ]);
     }

     public function down(PDO $db): void
     {
         $sql = "DELETE FROM feature_flag WHERE flag_key = :flag_key";
         $stmt = $db->prepare($sql);
         $stmt->execute([':flag_key' => 'NODE_BEHAVIOR_EXPERIMENTAL']);
     }
     ```

   - ถ้าระบบมี concept tenant / cid:
     - ให้ migration ใส่ flag สำหรับทุก tenant ที่มีอยู่แล้ว (iterate จากตาราง tenant/core_company ตาม pattern ของ migration เดิม)
     - หรือใช้ pattern เดิมที่ระบบใช้เวลา insert feature flag ใหม่

4. **ปรับ `FeatureFlagService` ให้รองรับ flag นี้แบบ type-safe**

   - เพิ่ม constant / helper:
     ```php
     const FLAG_NODE_BEHAVIOR_EXPERIMENTAL = 'NODE_BEHAVIOR_EXPERIMENTAL';
     ```
   - สร้างเมธอด convenience:
     ```php
     public function isNodeBehaviorExperimentalEnabled(?string $scope = null): bool
     {
         return $this->getFlag(self::FLAG_NODE_BEHAVIOR_EXPERIMENTAL, false, $scope);
     }
     ```

   - อัปเดตจุดเรียกใน `TokenLifecycleService` ให้ใช้เมธอดนี้แทน string literal ตรง ๆ

5. **Documentation**

   - สร้างไฟล์ `docs/super_dag/tasks/results/task21_4_results.md`
     - อธิบาย:
       - โครง Behavior Registry
       - การ integrate กับ executeBehavior()
       - รายละเอียด migration (SQL/โครงสร้าง)
       - วิธีตรวจสอบว่ามี flag ใน DB แล้ว
       - จุดที่ใช้ FeatureFlagService ใหม่

---

### 2.2 Out-of-Scope

- ยังไม่บังคับให้ระบบอื่น (Time Engine / Reporting) อ่าน canonical events แทนข้อมูลเดิมทั้งหมด  
- ยังไม่ลบหรือเปลี่ยน behavior เดิมที่ใช้ `effects` โดยตรง  
- ยังไม่เปิด flag ใน production โดย default  
- ยังไม่เพิ่ม behavior mode ใหม่ (นอกเหนือจากที่มีอยู่ใน 21.2–21.3) ถ้าไม่จำเป็น

---

## 3. Design Notes

### 3.1 Internal Behavior Registry – Close System

เป้าหมายไม่ใช่ทำ “plugin system” แต่ทำ “ทะเบียนภายในที่อ่านง่ายและ test ได้”:

- Registry สามารถเป็น:
  - Array map ภายใน class:
    ```php
    protected array $behaviorMap = [
        'hat_single'        => 'executeHatSingle',
        'hat_batch_quantity'=> 'executeHatBatchQuantity',
        'classic_scan'      => 'executeClassicScan',
        'qc_single'         => 'executeQcSingle',
    ];
    ```
  - หรือ class แยก `NodeBehaviorRegistry` ที่อ่าน config ภายใน

- ไม่ควร:
  - อ่าน config จากไฟล์ภายนอก/ฐานข้อมูลเพื่อเพิ่ม behavior
  - ให้ 3rd-party เพิ่ม behavior ผ่าน hook

> สรุป: Behavior ชุดนี้ = “Hard Law” ของระบบ ไม่ใช่ extension point

### 3.2 Feature Flag – Safety First

- หลัง migration:
  - Flag `NODE_BEHAVIOR_EXPERIMENTAL` จะอยู่ใน DB  
  - แต่ค่าต้องเป็น `OFF` ทุก environment โดย default
- เปิดใช้:
  - ผ่าน UI/console/SQL ที่ระบบใช้จัดการ feature flag อยู่แล้ว (เช่น back-office tool หรือ manual SQL ใน dev/staging)
- ถ้า flag หาย / table ไม่มี:
  - FeatureFlagService ต้อง fallback เป็น false  
  - ระบบต้องไม่ล่ม

---

## 4. Implementation Checklist

1. **Behavior Registry**
   - [ ] สร้าง registry ภายใน NodeBehaviorEngine
   - [ ] ใช้ registry ใน `executeBehavior()` แทน switch logic
   - [ ] ใส่ log warning เมื่อ execution_mode ไม่อยู่ใน registry

2. **Feature Flag Migration**
   - [ ] ค้นหา schema/tables ที่ใช้เก็บ feature flag จริง ๆ
   - [ ] สร้าง migration `*_2104_add_node_behavior_experimental_flag.php`
   - [ ] ใส่ INSERT สำหรับ flag ใหม่ (default OFF)
   - [ ] ใส่ down() เพื่อลบ flag หาก rollback
   - [ ] ทดสอบ migration ใน dev (migrate up/down)

3. **FeatureFlagService Integration**
   - [ ] เพิ่ม constant + helper method
   - [ ] แทนที่จุดเรียก string `'NODE_BEHAVIOR_EXPERIMENTAL'` ให้ใช้ constant/helper
   - [ ] ทดสอบว่า flag ปิด → Node Behavior Engine + TokenEventService ไม่ถูกเรียก

4. **Documentation**
   - [ ] เขียน `task21_4_results.md`
   - [ ] ระบุ known limitations / next steps (เช่น 21.5 อ่าน canonical events ใน Time Engine)

---

## 5. Done Criteria

- มี Behavior Registry ภายใน NodeBehaviorEngine ที่ map execution_mode → handler method/class อย่างชัดเจน
- `executeBehavior()` ใช้ registry แทนการ switch ตรง ๆ
- migration สำหรับ `NODE_BEHAVIOR_EXPERIMENTAL` ทำงานได้:
  - migrate up → flag ถูกสร้างใน table feature flag
  - migrate down → flag ถูกลบออก
- FeatureFlagService มี API แบบ type-safe สำหรับตรวจสอบ flag นี้
- `TokenLifecycleService` ยังมีพฤติกรรมเดิมเมื่อ flag ปิด
- มีเอกสาร `task21_4_results.md` อธิบายสิ่งที่ทำและผลกระทบต่อระบบ

---

## 6. Next Steps (สำหรับ Task ถัดไป)

- **Task 21.5** (เสนอ):
  - ให้ Time Engine / Reporting เริ่มอ่าน canonical events (token_event) เป็นหลักในบาง use case (เช่น Hatthasilpa time tracking dev-only)
  - เตรียม deprecate การใช้ field เวลา legacy บางส่วนโดยค่อย ๆ ย้ายไป canonical-first
