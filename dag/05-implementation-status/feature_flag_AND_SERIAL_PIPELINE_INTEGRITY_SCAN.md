### 1) HIGH-LEVEL SUMMARY  

**ภาพรวม:**  
- ระบบ Feature Flag v2 ใช้ `feature_flag_catalog` + `feature_flag_tenant` ใน Core DB ผ่าน `BGERP\Service\FeatureFlagService` ได้ถูกต้องในบางส่วน (เช่น `TokenLifecycleService`, `admin_feature_flags_api`, `dag_token_api`), แต่ยังมีจุดที่เรียก `FeatureFlagService` ผิด DB (ส่ง tenant DB แทน core DB) และ/หรือใช้ signature เก่า/ผิดประเภทค่า flag อยู่หลายไฟล์  
- Pipeline serial สำหรับ Hatthasilpa piece‑mode ปัจจุบันมี 2 เส้นหลักที่ “ชนกัน”:  
  - เส้น **JobCreationService → UnifiedSerialService → spawnTokens** (canonical DAG path)  
  - เส้น **hatthasilpa_job_ticket / SerialManagementService → job_ticket_serial → dag_token_api** (auto pre‑gen สำหรับ Work Queue)  
- จุด spawn จริง (`TokenLifecycleService::spawnTokens()` ที่ถูกเรียกจาก `dag_token_api` และจาก `JobCreationService`) ใช้ **hard gating** ด้วย `FF_SERIAL_STD_HAT` (ถ้าไม่ ON ⇒ `DAG_400_SERIAL_FLAG_REQUIRED`), ขณะที่ `dag_token_api` เองมี **soft gating** ของ standardized serial (ถ้า flag off หรือ error ⇒ TEMP‑* serial + log แต่ยัง spawn) → ตรงนี้เป็นแหล่งหลักของ behavior แปลก ๆ ที่คุณเห็น (TEMP‑*, error code, log ว่า flag disabled ทั้ง ๆ ที่เปิด).  

---

### 2) FEATURE FLAG USAGE MAP  

#### 2.1 `BGERP\Service\FeatureFlagService` (canonical service)

ไฟล์: `source/BGERP/Service/FeatureFlagService.php`  
- เมธอดหลัก:  
  - `getFlagValue(string $featureKey, string $tenantScope): int`  
    - ใช้ Core DB (`$this->coreDb`) JOIN `feature_flag_catalog` + `feature_flag_tenant` โดย `tenant_scope` = org.code  
  - `getFlag(string $featureKey, ?string $tenantScope = null): int`  
    - ถ้าไม่ส่ง scope ⇒ ใช้ `resolve_current_org()` แล้ว set `tenantScope = $org['code'] ?? 'GLOBAL'`  
  - `isSerialStandardizationEnabled(?string $tenantScope = null): int`  
    - ใช้ `getFlagValue('FF_SERIAL_STD_HAT', $tenantScope)` แล้วคืน `1/0` (strict int)  

**สังเกตสำคัญ:** service นี้ออกแบบให้รับ **Core DB เท่านั้น** (constructor `$coreDb`), และ `tenantScope` คือ **org code (string)** ไม่ใช่ tenant id (int).  

---

#### 2.2 Call sites ที่ใช้ **ถูกต้อง** กับ Core DB

- **`source/dag_token_api.php`**  
  - ใช้ใน `handleTokenSpawn()` (บล็อกราว ๆ L524–L533):  
    - `new FeatureFlagService(core_db())`  
    - `getFlagValue('FF_SERIAL_STD_HAT', $tenantScope)` โดย `tenantScope = $org['code'] ?? 'GLOBAL'`  
    - ใช้ผล boolean (`=== 1`) เพื่อเลือก path standardized serial vs TEMP‑*  
- **`source/BGERP/Service/TokenLifecycleService.php`**  
  - ใน `spawnTokens(...)` ช่วงต้น (L91–L105):  
    - หาก `process_mode === 'piece'`:
      - resolve tenantScope จาก `$this->tenantCode` หรือ `$_SESSION['current_org_code']` → fallback `'GLOBAL'`  
      - สร้าง `$ffs = new FeatureFlagService(core_db());`  
      - `getFlagValue('FF_SERIAL_STD_HAT', $tenantScope)` แล้วถ้าไม่เท่ากับ 1 ⇒ `throw new \RuntimeException('DAG_400_SERIAL_FLAG_REQUIRED');`  
    - **นี่คือ hard gate หลัก** สำหรับ Hatthasilpa piece‑mode  
- **`source/admin_feature_flags_api.php`**  
  - ใน action `upsert_tenant`:
    - หลัง upsert `feature_flag_tenant` จะสร้าง `$ffs = new FeatureFlagService($coreDb);`  
    - เรียก `$ffs->getFlagValue($featureKey, $scope)` เพื่อตอบ `effective_value`  
- **`tests/Integration/FeatureFlagAdminTest.php`**  
  - ใช้ `FeatureFlagService($this->core)`  
  - ทดสอบ `getFlagValue('FF_CUSTOM_TEST', 'maison_atelier')` และ tenant อื่น ๆ  

---

#### 2.3 Call sites ที่เกี่ยวข้องกับ **Hatthasilpa / serial** และมีความเสี่ยง  

- **`source/hatthasilpa_job_ticket.php`**  
  1) ตอนสร้าง/อัปเดต job ticket (auto pre‑gen serial เมื่อ `process_mode === 'piece'`):  
     - ใช้ `$featureFlagService = new FeatureFlagService($tenantDb);`  
       - **ผิด**: ส่ง tenant DB เข้า `FeatureFlagService` ซึ่งคาดหวัง Core DB  
     - เรียก `$featureFlagService->isSerialStandardizationEnabled('hatthasilpa', $tenantId);`  
       - **ผิด signature**: ตัว service รับแค่ `tenantScope` (string), ที่นี่ส่ง 2 พารามิเตอร์ (`production_type`, `tenantId`)  
     - ถ้า flag ON ⇒ ใช้ `SerialManagementService::generateSerialsForJob(...)` เพื่อสร้าง standardized serial แล้วเก็บใน `job_ticket_serial`  
  2) action generate serial เพิ่มเติม (ช่วง L1580+):  
     - ใช้ `$featureFlagService = new FeatureFlagService($tenantDb);`  
     - `isSerialStandardizationEnabled('hatthasilpa', $tenantId)`  
     - ถ้า flag OFF ⇒ `json_error('Serial standardization is disabled...', 403)`  
     - ถ้า ON ⇒ `SerialManagementService::generateAdditionalSerials(...)`  

- **`source/BGERP/Service/JobCreationService.php`**  
  - เมธอด `generateSerials(...)` (L151+):  
    - `$featureFlagService = new FeatureFlagService($this->db);`  
      - **ผิด DB**: `$this->db` เป็น tenant DB  
    - ถ้ามี `$tenantId`:
      - map productionType และเรียก `$featureFlagService->isSerialStandardizationEnabled($flagProductionType, $tenantId);`  
      - **ผิด signature** เช่นเดียวกับด้านบน  
    - ถึงแม้ flag จะ OFF ก็ยังใช้ `UnifiedSerialService` อยู่ดี (แค่ log warning) → นี่เป็น **soft flag** เฉพาะสำหรับ logging  

- **`source/dag_token_api.php`** (อีกครั้ง)  
  - ใน `handleTokenSpawn()`:
    - ใช้ `FeatureFlagService(core_db())` → `getFlagValue('FF_SERIAL_STD_HAT', $tenantScope)` เพื่อเลือก standardized path  
    - ถ้า standardized path fail หรือ flag OFF:  
      - log `'FF_SERIAL_STD_HAT disabled for tenant ... using soft-mode TEMP serials'`  
      - สร้าง `TEMP-{orgCode}-{skuOrJobName}-{ticketId}-{i}` แล้วส่งไป spawn  
  - หลัง spawn:
    - ใช้ `UnifiedSerialService` + `SerialManagementService` เพื่อ dual‑link `job_ticket_serial` กับ `serial_registry`  

**ผลรวม:** Hatthasilpa serial logic ใช้ FeatureFlagService 3 แบบต่างกัน:  
- `TokenLifecycleService::spawnTokens` → hard gate จาก Core DB (ถูกต้อง)  
- `dag_token_api` → soft gating ผ่าน Core DB (ถูกต้องด้าน DB แต่ behavior ซ้อนกับข้อบน)  
- `hatthasilpa_job_ticket` + `JobCreationService` → soft/hard gating แต่เรียก FeatureFlagService ด้วย tenant DB + signature เก่า (ผิดทั้ง DB และ signature)  

---

#### 2.4 Call sites อื่น ๆ (ไม่ใช่ SERIAL แต่สำคัญต่อ consistency)

- **`source/classic_api.php`**  
  - `$featureFlagService = new FeatureFlagService($tenantDb);`  
  - เรียก `$featureFlagService->isEnabled('FF_CLASSIC_MODE', $tenantId)` และ `isEnabled('FF_CLASSIC_SHADOW_RUN', $tenantId)`  
  - **ปัญหา:**  
    - ใช้ tenant DB แทน Core DB  
    - เมธอด `isEnabled()` ไม่มีใน `FeatureFlagService` ปัจจุบัน  
    - ส่ง `tenantId` (int) เป็น scope แทน org.code (string)  
- **`source/dashboard_api.php` / `source/trace_api.php`**  
  - ทั้งคู่ใช้ `FeatureFlagService($tenantDb)` และ `getFlag('FF_DASHBOARD_ENABLED', $tenantId)` / `getFlag('FF_TRACE_ENABLED', $tenantId)`  
  - DB และ scope type ผิด pattern เดียวกับ classic_api  
- **`page/*` / public API / tools**  
  - `page/trace_overview.php`, `page/product_traceability.php`, `page/production_dashboard.php` แค่ใช้ front‑end / UI calling admin API หรือ trace API (ไม่เรียก `FeatureFlagService` ตรง)  
  - `source/api/public/serial_verify_api.php` และ `tools/enable_feature_flags_test.php` ใช้เพื่อ verify serial/feature flag ในบริบท test/admin (ไม่ได้มีผลกับ Hatthasilpa spawn โดยตรง)  

---

#### 2.5 Direct DB access ไปที่ตาราง feature_flag*

- **v2 canonical (Core DB):**  
  - `FeatureFlagService` → `feature_flag_catalog`, `feature_flag_tenant`  
  - `admin_feature_flags_api.php` → ทำ JOIN / UPSERT ใน 2 ตารางนี้โดยตรง  
- **legacy `feature_flag` table:**  
  - `tests/Integration/HatthasilpaE2E_SerialStdEnforcementTest.php`  
    - `ensureFeatureFlagTable()` → `CREATE TABLE IF NOT EXISTS feature_flag (...)` ใน Core DB  
    - `seedFeatureFlag(int $val)` → DELETE/INSERT ใน `feature_flag` (`feature_key='FF_SERIAL_STD_HAT'`, `tenant_scope='maison_atelier'`)  
    - `tearDown()` ลบ `feature_flag` record  
  - เอกสารเก่าใน `docs/status-implementation/archive/*` พูดถึงการ drop legacy table ผ่าน migration `0005_drop_legacy_feature_flag.php`  
  - **ไม่มี code runtime ใหม่ (นอกจาก test) ที่ใช้ `feature_flag` แต่ test ยังสร้าง/ใช้มันอยู่** → risk เรื่อง divergence ระหว่าง spec v2 กับ behavior test.  

---

### 3) SERIAL PIPELINE MAP (Job → SerialRegistry → Tokens → WorkQueue)  

#### 3.1 Job creation (Hatthasilpa piece‑mode)

**Entry points:**

- `source/hatthasilpa_jobs_api.php`  
  - `case 'create_and_start'` (Phase 2B.5):  
    - validate, resolve org/tenant, ใช้ `DatabaseTransaction`  
    - เรียก `JobCreationService::createDAGJob([...])` โดยกำหนด:  
      - `production_type` = `'hatthasilpa'`  
      - `process_mode` มักเป็น `'piece'` (สำหรับ Hatthasilpa)  
      - `target_qty` ตาม input  
      - `tenant_id` = `org['id_org']`  
    - หลังจากนั้นจะ update `job_ticket.status = 'in_progress'` (ถือว่าตอนนี้ spawn แล้ว)  
- `source/hatthasilpa_job_ticket.php`  
  - สาย “classic Hatthasilpa job_ticket UI” (สร้าง/แก้ไข job_ticket):  
    - เมื่อสร้าง job ใหม่ใน Hatthasilpa + `process_mode = 'piece'` ระบบ auto‑generate serials:  
      - เช็ค `FF_SERIAL_STD_HAT` (ผ่าน FeatureFlagService ที่ผูก tenantDb — ปัจจุบันผิด DB)  
      - ถ้า flag ON ⇒ ใช้ `SerialManagementService::generateSerialsForJob(...)`  
        - สร้าง serials + INSERT ลง `job_ticket_serial(id_job_ticket, serial_number, sequence_no, generated_at)`  
      - ถ้า flag OFF ⇒ log ว่า disabled / หรือไม่สร้าง serial  
- `source/mo.php`  
  - OEM / classic MO → ใช้ `JobCreationService::createDAGJob` เพื่อสร้าง DAG‑job (ส่วนใหญ่ production_type = `'classic'`, process_mode `'piece'`):  
    - ใช้เส้นทางเดียวกับ `create_and_start` แต่ต่าง production_type  

**ภายใน `JobCreationService::createDAGJob`:**

1. สร้าง `job_graph_instance` (ผ่าน `RoutingSetService` / `graphService`)  
2. สร้าง `node_instances` สำหรับทุก node ใน graph  
3. ถ้ามี `job_ticket_id` ⇒ update `job_ticket.graph_instance_id` และ `routing_mode='dag'`  
4. หา START node  
5. **Serial generation (piece‑mode only):**  
   - ถ้า `process_mode === 'piece'` และ `$params['serials']` ว่าง:  
   - เรียก `generateSerials(productionType, sku, targetQty, moId, jobTicketId, tenantId)`  
     - ปัจจุบันใช้ `FeatureFlagService($this->db /*tenant*/) -> isSerialStandardizationEnabled(...)` แต่ flag ใช้เฉพาะ log warning  
     - ใช้ `UnifiedSerialService::generateSerial(...)` loop ตามจำนวน `targetQty`  
       - สร้าง standardized serial (pattern ประมาณ `MAIS-HAT-...`)  
       - ลงทะเบียนใน `serial_registry` (Core DB) ทันที (`serial_scope='piece'`, linked_source='job_ticket' / 'auto_job')  
6. เรียก `TokenLifecycleService::spawnTokens($instanceId, $targetQty, $processMode, $serials)`  
   - ถ้า `process_mode === 'piece'` → spawnTokens จะ:  
     - canonical check `process_mode` จาก `job_ticket` อีกครั้ง  
     - ตรวจ `FF_SERIAL_STD_HAT` จาก Core DB ผ่าน `FeatureFlagService(core_db())->getFlagValue('FF_SERIAL_STD_HAT', $tenantScope)`  
       - ถ้าไม่ 1 ⇒ `DAG_400_SERIAL_FLAG_REQUIRED`  
     - ใช้ `$serials[$i]` ใส่ใน `flow_token.serial_number`  
     - เรียก `markSerialAsSpawned()` → UPDATE `job_ticket_serial.spawned_at`, `spawned_token_id`  
     - สร้าง token event `spawn` + `enter`  
7. `createDAGJob` คืน `{ job_ticket_id, graph_instance_id, token_count, token_ids }`  

---

#### 3.2 Serial registry & format  

- **`BGERP\Service\UnifiedSerialService`**  
  - ใช้ Core DB ผ่าน `DatabaseHelper` (`coreDbHelper`)  
  - เมธอดสำคัญ:  
    - `generateSerial(...)`  
      - encode tenant id, production type, sku, mo/job ID ฯลฯ → สร้าง serial (เช่น `MAIS-HAT-TESTP822-20251114-00123-1YLJ-2`)  
      - คำนวณ hash + checksum, validate pattern (regex strict)  
      - เรียก `registerSerial(...)` เพื่อ insert เข้า `serial_registry`  
    - `registerSerial(...)`  
      - `INSERT INTO serial_registry (serial_code, tenant_id, org_code, production_type, sku, mo_id, job_ticket_id, dag_token_id, ... )`  
      - ถ้าซ้ำ ⇒ error / log race condition  
    - `linkDagToken($serial, $tokenId)`  
      - UPDATE `serial_registry.dag_token_id` สำหรับ serial นั้น  
- ตาราง `serial_registry` ทำหน้าที่เป็น canonical registry ทุก serial ที่ standardized (ทั้ง classic & Hatthasilpa), และใช้ใน feature อื่น เช่น traceability / component serials  

---

#### 3.3 Token spawn (DAG + Hatthasilpa)

**Orchestration:** `source/dag_token_api.php` → `handleTokenSpawn($db, $userId)`  

1. โหลด `job_ticket`, `job_graph_instance` ฯลฯ จาก tenant DB (`$db->getTenantDb()`)  
2. **Serial selection (piece‑mode only):**  
   - ถ้า `ticket['process_mode'] === 'piece'`:  
     - resolve `$tenantScope = $org['code'] ?? 'GLOBAL'`  
     - สร้าง `FeatureFlagService(core_db())`  
     - `getFlagValue('FF_SERIAL_STD_HAT', $tenantScope)` → set `$useStandardizedSerial`  
     - ถ้า `$useStandardizedSerial === true`:  
       - ใช้ `SerialManagementService($tenantDb, core_db())`:  
         - `getUnspawnedSerials($ticketId)` จาก `job_ticket_serial` (pre‑gen)  
         - ถ้ามีไม่พอ ⇒ `generateAdditionalSerials(...)`  
         - รวมแล้ว slice ตาม `target_qty` → `$serials` array  
       - ถ้า serial path fail (exception) ⇒ log error แล้ว set `$useStandardizedSerial = false`  
     - ถ้า `$useStandardizedSerial === false`:  
       - สร้าง TEMP serial: `TEMP-{orgCode}-{skuOrJobName}-{ticketId}-{i}`  
       - log `'FF_SERIAL_STD_HAT disabled ... using soft-mode TEMP serials ...'`  
3. เรียก `TokenLifecycleService::spawnTokens($instanceId, target_qty, process_mode, $serials)`  
   - จุดนี้เองที่จะโยน `DAG_400_SERIAL_FLAG_REQUIRED` ถ้า `FF_SERIAL_STD_HAT` ถูกมองว่า OFF ใน Core DB  
4. หลัง spawn (piece‑mode):  
   - สำหรับทุก token/serial:  
     - `SerialManagementService::markAsSpawned($serial, $tokenId)` → UPDATE `job_ticket_serial`  
     - `UnifiedSerialService::linkDagToken($serial, $tokenId)` → UPDATE `serial_registry.dag_token_id`  
     - ถ้า Core DB ล่ม/ผิดพลาด ⇒ เขียนลง `serial_link_outbox` ใน tenant DB เพื่อ retry ตาม outbox pattern  

---

#### 3.4 Work queue (ดู serial ใน UI)

- `dag_token_api.php` → action `get_work_queue` (และ actions start/pause/resume/complete)  
  - ใช้ `flow_token`, `job_graph_instance`, `routing_node` ฯลฯ filter เฉพาะ:  
    - instance status = `active`  
    - token status = `ready`/`active` ตามนโยบาย  
  - serial ที่แสดงใน work queue มาจาก `flow_token.serial_number` ไม่ได้ขึ้นอยู่กับ `serial_registry` โดยตรง  
  - ดังนั้น:  
    - หาก standardized serial generated + linked ถูกต้อง ⇒ work queue แสดงมาตรฐานเช่น `MAIS-HAT-...`  
    - หาก serial path fallback TEMP‑* ⇒ work queue จะเห็น TEMP‑* แต่ token ยัง spawn ทำงานได้  

---

### 4) MISMATCHES / RISKS  

1. **DB mismatch สำหรับ FeatureFlagService**  
   - หลายไฟล์ (โดยเฉพาะ Hatthasilpa/serial) ส่ง **tenant DB** เข้า `FeatureFlagService` ทั้งที่ออกแบบให้ใช้ Core DB:  
     - `hatthasilpa_job_ticket.php`  
     - `JobCreationService.php`  
     - `classic_api.php`, `dashboard_api.php`, `trace_api.php`  
   - ผลคือการอ่านค่า flag อาจ:  
     - ล้มเหลวเงียบ ๆ (prepare/query fail) แล้ว fallback เป็น 0 หรือค่า default  
     - หรือใช้ตาราง/สคีมาที่ไม่มีอยู่จริงใน tenant → flag ถูกมองว่า OFF เสมอ  

2. **Signature/semantic mismatch ของ `FeatureFlagService`**  
   - โค้ดบางส่วนเรียก `isSerialStandardizationEnabled($productionType, $tenantId)` / `isEnabled($key, $tenantId)` ทั้งที่ service ปัจจุบันรับแค่ `$tenantScope (string)` และไม่มีเมธอด `isEnabled()`  
   - ตรงนี้บ่งชี้ว่ามีการ refactor service แต่ call‑sites บางส่วนยังเป็นเวอร์ชันเก่า → อาจเกิด fatal error หรือ behavior ผิดพลาดในบาง environment  

3. **Hard gate vs soft gate ซ้อนกันสำหรับ `FF_SERIAL_STD_HAT`**  
   - `TokenLifecycleService::spawnTokens` ใช้ **hard gating**: ถ้า flag ไม่เท่ากับ 1 ⇒ `DAG_400_SERIAL_FLAG_REQUIRED` (ไม่ spawn)  
   - `dag_token_api` ใช้ **soft gating**: ถ้า flag off หรือ path standardized fail ⇒ TEMP‑* serial + log แต่ยังเรียก `spawnTokens` อยู่ดี  
   - ถ้า flag ถูกอ่านว่า OFF ที่ระดับ TokenLifecycleService แต่ `dag_token_api` ยังพยายามไปต่อ ⇒ จะเจอ error code ที่คุณเห็น (`DAG_400_SERIAL_FLAG_REQUIRED`) แม้ path ข้างบนดูเหมือนรองรับ TEMP‑*  

4. **Pre‑gen logic vs spawn‑time enforcement ไม่ align**  
   - `hatthasilpa_job_ticket` และ `JobCreationService` ใช้ FeatureFlagService ผูก tenant DB + signature เก่า เพื่อควบคุม pre‑gen / generate additional serials  
   - แต่ gating ที่มีผลจริงว่าจะ spawn ได้หรือไม่ อยู่ที่ `TokenLifecycleService`, ซึ่งใช้ **Core DB** และไม่สน gating แบบ soft เหล่านั้น  
   - ทำให้เกิดเคส:  
     - Pre‑gen serial สำเร็จและคิดว่า flag ON (จาก tenant DB / legacy table)  
     - แต่ตอน spawn `TokenLifecycleService` มองว่าระดับ Core DB flag OFF ⇒ ขึ้น `DAG_400_SERIAL_FLAG_REQUIRED` ทั้ง ๆ ที่ serial พร้อมแล้ว  

5. **Legacy `feature_flag` table vs v2 tables**  
   - Test `HatthasilpaE2E_SerialStdEnforcementTest` ยังใช้ `feature_flag` ที่ Core DB (สร้าง table เอง, insert per‑tenant row)  
   - Spec ล่าสุด (docs + migrations) บอกว่า canonical คือ `feature_flag_catalog` + `feature_flag_tenant` และ legacy table ถูก drop แล้ว  
   - หากใน environment จริงไม่มี `feature_flag` แต่มี `feature_flag_catalog`/`feature_flag_tenant` → test กับ production จะ diverge (และอาจเกิดข้อความ log “FF_SERIAL_STD_HAT disabled...” ใน prod ทั้งที่แอดมินปรับใน UI แล้ว)  

6. **Scope mismatch: tenantScope vs tenantId vs orgCode**  
   - `FeatureFlagService` v2 ออกแบบ tenant_scope = `organization.code` (string)  
   - หลาย call‑sites ส่ง `tenantId` (เช่น `org['id_org']`) เข้าไป, หรือส่ง productionType + tenantId รวมกัน  
   - ทำให้ค่าที่อ่านจาก Core DB อาจไม่ตรงกับที่ admin flag panel ตั้งไว้ (เพราะ row ใน `feature_flag_tenant.tenant_scope` ใช้ org.code)  

7. **TEMP‑* path ไม่ sync กับ pre‑gen path**  
   - ถ้า `dag_token_api` fallback TEMP‑* แต่ `JobCreationService` หรือ `hatthasilpa_job_ticket` pre‑gen standardized serial ไว้แล้วใน `job_ticket_serial` → จะเกิด **สองชุด serial** (standardized ที่ไม่ถูกใช้ + TEMP‑*) และ linking ใน `serial_registry` อาจไม่ครบ (เพราะ TEMP‑* ไม่ได้ไป register)  

---

### 5) PATCH PLAN (PHASE 2 – TO BE EXECUTED LATER, NOT NOW)  

> เป้าหมายหลัก:  
> - มี **แหล่งอ่าน feature flag เดียว** (Core DB ผ่าน FeatureFlagService)  
> - มี **กฎ gating เดียว** สำหรับ `FF_SERIAL_STD_HAT` ระหว่าง pre‑gen vs spawn‑time  
> - ลบ behavior ซ้อนกัน (hard + soft) ที่ขัดกัน  

#### A) Normalize tenantScope + DB ให้ `FeatureFlagService` ทั่วระบบ  

**A1 – บังคับใช้ Core DB constructor ที่เดียวกัน**  
- **ไฟล์ที่ต้องแก้:**  
  - `hatthasilpa_job_ticket.php`  
  - `source/BGERP/Service/JobCreationService.php`  
  - `source/classic_api.php`  
  - `source/dashboard_api.php`  
  - `source/trace_api.php`  
- **การเปลี่ยนแปลง:**  
  - แทนที่ `new FeatureFlagService($tenantDb)` หรือ `$this->db` ด้วย `new FeatureFlagService(core_db())` เสมอ  
- **จัดกลุ่ม:**  
  - **SAFE & LOCAL:** hatthasilpa_jobs/hatthasilpa_job_ticket/job_creation (เพราะ logic อ้างอิง Core DB อยู่แล้วในส่วนอื่น)  
  - **SYSTEMIC:** classic_api, dashboard_api, trace_api (กระทบ users ขาอื่น → ต้องมี regression test เพิ่มเติม)  

**A2 – ทำให้ scope เป็น org.code ทุกที่**  
- เพิ่ม helper function ภายใน call‑site (หรือใช้ `getFlag()` ที่ resolve เอง):  
  - ดึง `$org = resolve_current_org();`  
  - `$tenantScope = $org['code'] ?? 'GLOBAL';`  
- **ไฟล์ที่จะปรับ:**  
  - `JobCreationService::generateSerials` (ตอนเช็ค FF_SERIAL_STD_HAT เฉพาะ logging)  
  - `hatthasilpa_job_ticket` (ตอนเช็ค FF_SERIAL_STD_HAT เพื่อ pre‑gen / generateAdditionalSerials)  
  - classic/dashboard/trace API (flag อื่น ๆ)  

---

#### B) ทำให้การใช้ `FeatureFlagService` สำหรับ SERIAL เป็นแบบเดียวกัน  

**B1 – ปรับ signature การใช้งาน `isSerialStandardizationEnabled`**  
- **ไฟล์:**  
  - `JobCreationService.php`  
  - `hatthasilpa_job_ticket.php`  
- **ก่อน:** `isSerialStandardizationEnabled($productionType, $tenantId)`  
- **หลัง:**  
  - เปลี่ยนเป็น `isSerialStandardizationEnabled($tenantScope)` หรือใช้ `getFlagValue('FF_SERIAL_STD_HAT', $tenantScope)` ตรง ๆ  
  - ถ้าต้องการ behavior แยกตาม productionType ให้ใช้ชื่อ feature key แยก (`FF_SERIAL_STD_HAT`, `FF_SERIAL_STD_CLASSIC` ฯลฯ) แทนการยัด productionType เข้า scope  

**B2 – ตัด hard gating ออกจาก `TokenLifecycleService` หรือ sync กับ `dag_token_api`**  
มี 2 แนวทาง (ควรเลือก 1):

- **Option 1 (แนะนำ): gating ทั้งหมดอยู่ที่ `dag_token_api` เท่านั้น (soft)**  
  - **ไฟล์:** `BGERP/Service/TokenLifecycleService.php`  
  - ลบ/ลด logic ที่โยน `DAG_400_SERIAL_FLAG_REQUIRED` เมื่อ flag OFF  
  - ให้ `spawnTokens` ถือว่าถ้า caller ส่ง `serials` มาแล้ว ⇒ spawn ตามนั้น ไม่สน flag  
  - ผลลัพธ์:  
    - `dag_token_api` รับผิดชอบตัดสิน standardized vs TEMP‑* แค่ที่เดียว  
    - JobCreationService/hatthasilpa_job_ticket สามารถ pre‑gen ได้ตาม flag แต่ไม่ทำให้ spawn fail เอง  
- **Option 2: gating ที่ระดับ service เท่านั้น (hard)**  
  - **ไฟล์:**  
    - `dag_token_api.php`  
    - `JobCreationService.php`  
    - `hatthasilpa_job_ticket.php`  
  - ตัดการเช็ค `FF_SERIAL_STD_HAT` ใน `dag_token_api` ออก (ไม่สร้าง TEMP‑* ตาม flag)  
  - บังคับว่า pre‑generation ต้องไม่เรียกเมื่อ flag OFF และ TokenLifecycleService เป็น gate เดียว  
  - ต้องปรับ tests (`HatthasilpaE2E_SerialStdEnforcementTest`) ให้สะท้อน behavior ใหม่นี้  

> จากอาการที่คุณ report (บางครั้ง TEMP‑*, บางครั้ง `DAG_400_SERIAL_FLAG_REQUIRED`), **Option 1** จะลด conflict ระหว่าง soft vs hard gating ได้ชัดกว่า  

---

#### C) Align pre‑generation logic กับ spawn‑time behavior  

**C1 – hatthasilpa_job_ticket pre‑gen path**  
- **ไฟล์:** `hatthasilpa_job_ticket.php`  
- **เป้าหมาย:**  
  - ใช้ FeatureFlagService(CoreDB, tenantScope=org.code) เหมือน `dag_token_api`  
  - ถ้า flag OFF:  
    - ไม่ต้อง pre‑gen standardized serial → ปล่อยให้ `dag_token_api` ใช้ TEMP‑* หรือ standardized ตาม flag เหมือนกันทุกที่  
  - ถ้า flag ON:  
    - ต้องแน่ใจว่า serial ถูก register ใน `serial_registry` ด้วย (ผ่าน `SerialManagementService` หรือ `UnifiedSerialService`)  
  - ไม่ควรเช็ค flag **อีกครั้ง** หลัง pre‑gen ตอนขอ generateAdditionalSerials; ให้ reuse path เดียวกับ `dag_token_api` หรือ JobCreationService  

**C2 – JobCreationService path**  
- **ไฟล์:** `JobCreationService.php`  
- **การเปลี่ยน:**  
  - เปลี่ยน FeatureFlagService call ให้เป็น logging only โดยใช้ Core DB + tenantScope  
  - ถ้ตั้งใจให้ `FF_SERIAL_STD_HAT` เป็น “requirement” ที่นี่ → ต้อง align กับ `dag_token_api`/`TokenLifecycleService` ว่าจะ block หรือไม่ block แบบเดียวกัน  
  - พิจารณาให้ `generateSerials` ไม่ตัดสินใจ gating แต่รับ serial ที่เตรียมมา (จาก hattha/job_ticket) ก็ได้ → ลด duplication  

---

#### D) Cleanup legacy feature_flag table + Tests  

**D1 – ปรับ tests ให้ใช้ v2 tables**  
- **ไฟล์:**  
  - `tests/Integration/HatthasilpaE2E_SerialStdEnforcementTest.php`  
- **การเปลี่ยน:**  
  - แทน `ensureFeatureFlagTable()` + insert `feature_flag` ด้วยการใช้ `feature_flag_catalog` + `feature_flag_tenant` ผ่าน helper หรือ query ตรงใน Core DB  
  - ใช้ `FeatureFlagService::getFlagValue()` ใน test เพื่อ assert ว่า config ถูกต้องแล้วก่อน spawn  
  - อัปเดต tearDown ให้ clean v2 tables (เฉพาะ key ที่ใช้ใน test) แทนลบจาก `feature_flag`  

**D2 – ความเสี่ยง / Scope**  
- ถือเป็นการเปลี่ยนแปลง **SYSTEMIC** เพราะกระทบ infra feature flag ทั้งระบบ (ไม่เฉพาะ Hatthasilpa) แต่จำเป็นถ้าต้องการให้ behavior ตรงกับ spec/migration v2  

---

#### E) Work Queue & TEMP‑* alignment  

**E1 – เมื่อใช้ TEMP‑* serials ให้ handle registry/outbox อย่าง explicit**  
- **ไฟล์:** `dag_token_api.php`  
- **การปรับ (หลังตัดสินใจ Option 1 หรือ 2):**  
  - ถ้าต้อง support TEMP‑* เป็น soft mode:  
    - นิยามชัดเจนว่าควรหรือไม่ควร register TEMP‑* ใน `serial_registry`  
    - ถ้าควร: ให้ `UnifiedSerialService` มี path พิเศษหรือ flag บ่งบอกว่าเป็น TEMP serial และจัดการ checksum/format ให้ผ่าน (หรือ skip validation แต่ mark status='temporary')  
    - ถ้าไม่ควร: ทำให้ชัดเจนว่า TEMP‑* คือ “non‑traceable fallback” และ work queue / trace API แสดง/ซ่อนไปตามนั้น  

**E2 – ensure work_queue filter ไม่พังจาก serial flag**  
- **ไฟล์:**  
  - `dag_token_api.php` (handleGetWorkQueue)  
  - `tests/Integration/HatthasilpaE2E_WorkQueueFilterTest.php`  
- **การตรวจ:**  
  - ยืนยันว่า filtering ของ work queue พิจารณาเฉพาะ token status + instance status ไม่ผูกกับ `FF_SERIAL_STD_HAT`  
  - ถ้าจำเป็น: add integration test ใหม่ที่ตั้งค่า flag OFF/ON และตรวจว่า work queue ยังเห็น tokens (แม้ใช้ TEMP‑*).  

---

โดยรวม แผน patch นี้จะแบ่งเป็น 3 กลุ่ม:  
- **SAFE & LOCAL:** แก้ constructor DB/scope ของ `FeatureFlagService` ใน Hatthasilpa/serial path, sync signature `isSerialStandardizationEnabled`  
- **SYSTEMIC:** ปรับ gating model (hard vs soft) ระหว่าง `TokenLifecycleService` กับ `dag_token_api`, unify flag source สำหรับ classic/dashboard/trace, และย้าย tests ไปใช้ v2 schema  
- **Follow‑up:** ตัดสินใจเชิง product ว่า TEMP‑* จะถือเป็น fallback ชั่วคราว (non‑traceable) หรือจะ integrate เข้ากับ `serial_registry` อย่างเป็นทางการ แล้วปรับ `UnifiedSerialService`/trace API ให้รองรับ.