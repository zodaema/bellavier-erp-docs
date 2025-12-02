

# Task 19.22 — Folder & Namespace Normalization (SuperDAG Core)

## เป้าหมาย

ทำให้โครงสร้างไฟล์และ namespace ของ SuperDAG อยู่ในสภาพที่ “สะอาดและคาดเดาได้” พร้อมสำหรับ Lean-Up Phase ถัดไปและ Task 20 (ETA Engine) โดย:

- ย้าย/จัดระเบียบไฟล์ SuperDAG ไปยังโฟลเดอร์ที่ถูกต้องตาม PSR-4
- ลด/ลบไฟล์ legacy ที่ซ้ำซ้อนหรือไม่ถูกเรียกใช้งานแล้ว
- ทำให้การ autoload และการอ้างอิง class ชัดเจน ไม่ต้องพึ่งพา require_once แบบกระจัดกระจาย
- ไม่แตะต้อง business logic ที่ทำงานดีอยู่แล้ว (focus แค่ folder / namespace / include path)

---

## ขอบเขตงาน (Scope)

### อยู่ใน Scope

1. **โครงสร้างโฟลเดอร์ SuperDAG**
   - ทุก class ภายใต้ namespace `BGERP\Dag\...` ต้องอยู่ใต้:
     - `source/BGERP/Dag/*`
   - ทุก helper ภายใต้ namespace `BGERP\Helper\...` ต้องอยู่ใต้:
     - `source/BGERP/Helper/*`

2. **ไฟล์ที่เกี่ยวข้องโดยตรง**
   - SuperDAG Core:
     - `source/BGERP/Dag/*.php`
     - `source/dag_routing_api.php`
   - Helpers ที่เกี่ยวข้อง:
     - `source/BGERP/Helper/TempIdHelper.php`
     - `source/BGERP/Helper/JsonNormalizer.php`
   - Tests:
     - `tests/super_dag/*.php`
   - Docs (สำหรับอ้างอิง, ไม่ต้องแก้โค้ด):
     - `docs/super_dag/**/*.md`

3. **Namespace & Use Statements**
   - ปรับ `namespace` และ `use` ให้ตรงโครงสร้างไฟล์
   - ลบ `require_once` ที่ไม่จำเป็น (กรณีที่ autoload รับผิดชอบแล้ว)
   - กรณีที่ test runner ยังไม่ได้ใช้ autoload เต็มรูปแบบ:
     - อนุญาตให้มี `require_once` ใน test harness เท่านั้น (ไม่ใช่ใน core engine)

### นอก Scope (อย่าทำใน Task 19.22)

- ไม่ refactor method / logic ภายใน class
- ไม่เปลี่ยน signature ของ public methods
- ไม่เปลี่ยนโครงสร้าง data ของ graph (nodes/edges format)
- ไม่แตะ ETA, SLA, หรือ Time Engine
- ไม่แก้ routing execution engine / token lifecycle

---

## แนวทางการทำงาน (Guidelines สำหรับ AI Agent)

### 1. Mapping โครงสร้างไฟล์ → Namespace

ให้ AI Agent สร้าง mapping ตารางแบบนี้ (ในหัวของมัน แต่ผลลัพธ์ต้องสอดคล้อง):

- `source/BGERP/Dag/GraphValidationEngine.php`
  - `namespace BGERP\Dag;`
- `source/BGERP/Dag/SemanticIntentEngine.php`
  - `namespace BGERP\Dag;`
- `source/BGERP/Dag/ReachabilityAnalyzer.php`
  - `namespace BGERP\Dag;`
- `source/BGERP/Dag/GraphHelper.php`
  - `namespace BGERP\Dag;`
- `source/BGERP/Dag/GraphAutoFixEngine.php`
  - `namespace BGERP\Dag;`
- `source/BGERP/Dag/ApplyFixEngine.php`
  - `namespace BGERP\Dag;`

- `source/BGERP/Helper/TempIdHelper.php`
  - `namespace BGERP\Helper;`
- `source/BGERP/Helper/JsonNormalizer.php`
  - `namespace BGERP\Helper;`

**Rule:**  
ถ้าไฟล์อยู่ใต้ `source/BGERP/Dag/` → ต้องใช้ `namespace BGERP\Dag;`  
ถ้าไฟล์อยู่ใต้ `source/BGERP/Helper/` → ต้องใช้ `namespace BGERP\Helper;`

ถ้าเจอไฟล์ที่ยังอยู่ใน `source/helper/*.php` (legacy) และมี class/namespace ตรงกับ `source/BGERP/Helper/*.php` ให้ถือว่า:

- ไฟล์ใต้ `source/BGERP/Helper/` คือ **canonical version**
- ไฟล์ใต้ `source/helper/` เป็น legacy / duplicate:
  - ห้ามลบใน Task นี้อัตโนมัติ
  - แต่ให้เขียนคอมเมนต์ไว้ในไฟล์ผลลัพธ์ (เช่นใน docs หรือใน task results) ว่า: *“ไฟล์ legacy/helper ตัวนี้สามารถลบได้ใน Lean-Up Task ถัดไป หลังจากยืนยันว่าไม่มีใคร include โดยตรง”*

---

### 2. การจัดการ require_once vs autoload

#### 2.1 ใน Core Engine (`source/BGERP/Dag/*.php`)

- เป้าหมาย: ใช้ `namespace` + `use` + autoload เป็นหลัก
- ถ้าไฟล์ปัจจุบันเรียกใช้ helper ที่อยู่ใน `BGERP\Helper\...` ให้ใช้:
  ```php
  use BGERP\Helper\TempIdHelper;
  use BGERP\Helper\JsonNormalizer;
  ```
- หากตอนนี้มี `require_once __DIR__ . '/../Helper/TempIdHelper.php';`:
  - **อนุญาตให้คงไว้ชั่วคราว** ถ้าทราบแน่ชัดว่า autoload ยังไม่ครอบคลุม test runner ทั้งระบบ
  - แต่ต้องใส่คอมเมนต์:
    ```php
    // TODO(SuperDAG-LeanUp): remove this require_once when global autoloader is wired into test harness.
    ```
- ห้ามเพิ่ม require_once กระจัดกระจายเพิ่ม นอกจาก:
  - จุด “รวมโหลด” เช่น test harness
  - กรณีจำเป็นจริง ๆ ใน CLI test scripts

#### 2.2 ใน Test Harness (`tests/super_dag/*.php`)

- สามารถใช้ `require_once` ตรง ๆ เพื่อโหลด:
  - `GraphValidationEngine.php`
  - `SemanticIntentEngine.php`
  - `ReachabilityAnalyzer.php`
  - `GraphAutoFixEngine.php`
  - `ApplyFixEngine.php`
- หากซ้ำซ้อนหรือโหลดหลายรอบ ให้รวมเป็น block เดียวด้านบนไฟล์

---

### 3. ขั้นตอนการทำงานเป็นลำดับ (สำหรับ AI Agent)

1. **Scan โฟลเดอร์**
   - ดูโครงสร้างไฟล์จริงใน:
     - `source/BGERP/Dag/`
     - `source/BGERP/Helper/`
     - `source/helper/`
     - `tests/super_dag/`

2. **Normalize namespace ทุกไฟล์ใน BGERP/Dag และ BGERP/Helper**
   - ให้เป็น `namespace BGERP\Dag;` และ `namespace BGERP\Helper;` ตามตำแหน่งไฟล์
   - แก้ `use` ให้ถูกต้อง (e.g. `use BGERP\Helper\TempIdHelper;`)

3. **ตรวจจับ duplicate class ระหว่าง helper เก่า/ใหม่**
   - เช่น `source/helper/TempIdHelper.php` vs `source/BGERP/Helper/TempIdHelper.php`
   - ให้ถือว่า version ใหม่ใน `BGERP/Helper` คือ canonical
   - อย่าลบไฟล์ legacy ใน Task นี้ แต่ให้ระบุในผลลัพธ์ว่า “ควรลบใน Task Lean-Up ถัดไป”

4. **ปรับ require_once ใน engine ให้ minimal**
   - คงไว้เฉพาะที่จำเป็น (เช่นที่ถูกใช้ใน runtime นอก composer autoload)
   - ใส่ TODO comment ชัดเจนสำหรับ future clean-up

5. **ปรับ require_once ใน test harness**
   - ให้รวมอยู่ด้านบนไฟล์ ไม่กระจายไปใน method
   - อย่าใช้ include/require แบบ dynamic

6. **รัน test ทั้งสามชุด**
   ```bash
   php tests/super_dag/ValidateGraphTest.php
   php tests/super_dag/SemanticSnapshotTest.php
   php tests/super_dag/AutoFixPipelineTest.php
   ```
   - ถ้ามี snapshot เปลี่ยนเพราะ path เปลี่ยน → ใช้ `--update` เฉพาะกรณีที่จำเป็นและระบุในผลลัพธ์

---

## สิ่งที่ต้องระวังเป็นพิเศษ

1. **ห้าม break Semantic Snapshot**
   - ถ้าเปลี่ยนอะไรที่กระทบ output ของ SemanticIntentEngine:
     - ต้องบันทึกว่าทำอะไร และทำไม snapshot จึงต้อง update
   - ใน Task 19.22 เป้าหมายหลักคือ folder/namespace → ไม่ควรทำให้ semantics เปลี่ยน

2. **ห้ามลบ legacy helper โดยพลการ**
   - แค่ระบุในผลลัพธ์ว่าสามารถลบได้ในการ Lean-Up Task ถัดไป

3. **ห้ามแก้ signatures / business logic**
   - ทุกการเปลี่ยนต้องอยู่ในหมวด:
     - namespace
     - use
     - require_once placement
     - path / include structure
     - test harness require

---

## Acceptance Criteria

Task 19.22 จะถือว่าสำเร็จ เมื่อ:

1. ทุกไฟล์ใน `source/BGERP/Dag/` ใช้ `namespace BGERP\Dag;` อย่างถูกต้อง
2. ทุกไฟล์ใน `source/BGERP/Helper/` ใช้ `namespace BGERP\Helper;` อย่างถูกต้อง
3. ไม่มี class ซ้ำ namespace/ชื่อระหว่าง helper ใหม่/เก่าที่ถูกเรียกใช้ผ่าน autoload
4. Test ทั้งสามชุดรันผ่าน:
   - `ValidateGraphTest` → ผ่าน 15/15
   - `AutoFixPipelineTest` → ผ่าน 15/15
   - `SemanticSnapshotTest` → ผ่าน (ถ้า snapshot มีการ update ต้องระบุในผลลัพธ์)
5. ไม่เกิด fatal error จาก class not found อีก (TempIdHelper, JsonNormalizer, GraphHelper, ReachabilityAnalyzer, SemanticIntentEngine ฯลฯ)
6. มีเอกสารสรุปผลลัพธ์ใน `task19.22_results.md` (หรือเพิ่ม section ในไฟล์นี้) ว่าทำอะไรไปบ้าง

---

## เชิงสรุป

Task 19.22 เป็นการ “ตั้งกระดูก” ของ SuperDAG ให้ถูกตำแหน่ง ถูก namespace และถูก autoload  
เพื่อให้ Lean-Up Tasks ถัดไป (19.23–19.30) สามารถ refactor logic เพิ่มเติมได้อย่างปลอดภัย และเพื่อรองรับ Task 20 (ETA Engine) โดยไม่ต้องกังวลเรื่องไฟล์กระจัดกระจายหรือ class หาไม่เจออีกต่อไป