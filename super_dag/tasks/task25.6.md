

# Task 25.6 — Product API Enterprise Refactor (product_api.php)

**Status:** Planned  
**Owner:** N/A (AI Agent via Cursor)  
**Domain:** Product Module / API Layer  
**Target Files:**
- `source/product_api.php` (หลัก)
- (อ่านอย่างเดียว / อ้างอิงเท่านั้น) `source/api_template.php`, `docs/BELLAVIER_CODING_CHARTER.md`, `docs/AI_Quick_Start.md`, `docs/Global_Helpers.md`

---

## 1. เป้าหมายหลัก (Goals)

1. เปลี่ยน `product_api.php` ให้เป็น **Enterprise-grade API** ที่สอดคล้องกับ:
   - `api_template.php`
   - `BELLAVIER_CODING_CHARTER.md`
   - Global helpers / AI quick start
2. ทำให้โค้ด:
   - อ่านง่าย / maintain ได้ในระยะยาว
   - ปลอดภัย (no header redirect, no die/exit ดิบ ๆ)
   - มีมาตรฐานเดียวกับ API อื่น ๆ ของ Bellavier Group ERP
3. รักษาพฤติกรรมเดิม (**Backward Compatible**) ของ endpoint เดิมให้มากที่สุด:
   - Action names เหมือนเดิม
   - Response shape *หลัก ๆ* เหมือนเดิม (fields, semantics)
   - ไม่มี breaking changes ต่อ UI ปัจจุบัน

---

## 2. ขอบเขตงาน (Scope)

### อยู่ใน Scope

- Refactor และ hardening เฉพาะไฟล์:  
  `source/product_api.php`
- ปรับโครงสร้าง API ให้ align กับ `source/api_template.php`:
  - Bootstrap ลำดับเดียวกัน
  - Error handling เหมือนกัน
  - Logging / correlation ID / X-AI-Trace เหมือนกัน
- ปรับ query SQL ใน `product_api.php`:
  - ห้าม `SELECT *`
  - ใช้ column list และ named semantics ให้ชัดเจน
- เพิ่ม i18n และมาตรฐาน message:
  - ใช้ `translate()` เสมอสำหรับข้อความที่แสดงต่อผู้ใช้
  - Default string เป็นภาษาอังกฤษ
- ปรับปรุง error model:
  - มี `app_code` ตาม convention
  - แยก 4xx / 5xx override ผ่าน HTTP status code ถ้าจำเป็น (ไม่ breaking response body)
- Optional/Lightweight performance improvement:
  - เพิ่ม ETag / cache control สำหรับ read-only endpoint (`get_metadata`, `get_classic_dashboard`) **หากทำได้โดยไม่ซับซ้อนเกินไป**

### นอก Scope (ห้ามทำใน Task นี้)

- ไม่แก้ไข schema database (no new migrations)
- ไม่แก้ `source/products.php`, `views/products.php`, `product_graph_binding.js` ยกเว้นจำเป็นอย่างยิ่งเพื่อไม่ให้พัง (เช่น URL เปลี่ยน)
- ไม่เปลี่ยน semantics ทางธุรกิจ:
  - Product routing binding behavior
  - Classic dashboard behavior (อ่าน stats เฉย ๆ)
- ไม่เพิ่ม endpoint ใหม่ (เช่น analytics อื่น ๆ) นอกเหนือจากที่มีอยู่ใน `product_api.php` แล้ว

---

## 3. ภาพรวมปัจจุบัน (จาก Audit)

จากการ audit ก่อนหน้า พบปัญหาหลัก ๆ ใน `product_api.php` ดังนี้:

1. **Bootstrap / Template ไม่ตรงมาตรฐาน**
   - ยังไม่ใช้ `TenantApiOutput::startOutputBuffer()` / `finalize()`
   - ยังไม่มี `X-Correlation-Id`, `X-AI-Trace`, timing header
   - ยังไม่มี maintenance mode guard ตามมาตรฐาน

2. **Error Handling / Logging**
   - ไม่มี top-level `try/catch` ที่ wrap ทุก action
   - Error response ไม่ได้ใส่ `app_code` อย่างเป็นระบบ
   - Logging ยังไม่ align กับ Charter (รวม context, correlation id, org, action)

3. **SQL Standards**
   - ยังมี query ที่ใช้ `SELECT *`
   - Column list ไม่ชัดเจน
   - การทำงานกับ transaction (ถ้ามี) ยังไม่ใช้ helper มาตรฐาน

4. **i18n / Messages**
   - ข้อความบางส่วนเป็น literal / hard-coded
   - ไม่มี `translate('api.product.xxx', 'English message...')` ตาม charter
   - ไม่มี namespace ที่คงที่สำหรับ product module

5. **Response Structure / Caching**
   - รูปแบบ JSON response ยังไม่ align กับ `api_template.php`
   - ยังไม่มี ETag / cache control สำหรับ endpoint ที่เหมาะกับ caching (`get_metadata`, `get_classic_dashboard`)

---

## 4. สิ่งที่ต้องทำอย่างละเอียด (Implementation Checklist)

> ให้ใช้ `source/api_template.php` + `docs/BELLAVIER_CODING_CHARTER.md` เป็น **Single Source of Truth**  
> ทุกข้อด้านล่างให้ถือว่าเป็น *Minimum Requirement* ของงานนี้

### 4.1 API Bootstrap & Skeleton

1. ปรับ `product_api.php` ให้มีโครงสร้างตามนี้ (โดยสรุป):

   - `require_once` bootstrap + helpers ตามลำดับมาตรฐาน
   - `TenantApiOutput::startOutputBuffer();`
   - จับเวลาเริ่มต้น `$__t0 = microtime(true);`
   - Resolve org / tenant
   - Maintenance mode check (ถ้ามี helper standard)
   - สร้าง correlation ID และใส่ header
   - `try { ... switch(action) ... } catch (\Throwable $e) { ... }`
   - `TenantApiOutput::finalize($response, $__t0);`

2. อย่าใช้ `die()`, `exit()`, หรือ `echo json_encode(...)` ตรง ๆ  
   ให้ใช้ helper เดียวกับที่ `api_template.php` ใช้เท่านั้น

3. เปลี่ยนจาก pattern `if (!isset($_GET['action'])) { ... }` ไปใช้ patternเดียวกับ API ใหม่:
   - ดึง action ที่อนุญาตจาก allowlist
   - ถ้าไม่พบ → คืน error ด้วย `app_code` เช่น `PROD_400_UNKNOWN_ACTION`

### 4.2 Action Handlers & Structure

1. แยกแต่ละ action ออกเป็น **private function** ภายในไฟล์:

   ตัวอย่างเช่น:
   - `handleGetMetadata(...)`
   - `handleBindRouting(...)`
   - `handleUnbindRouting(...)`
   - `handleDuplicateProduct(...)`
   - `handleGetClassicDashboard(...)`

2. ใน `switch ($action)` ให้ทำหน้าที่ routing เท่านั้น:
   - ไม่เขียน logic ยาว ๆ ในนั้น
   - แต่ละ case → เรียก handler ที่ชัดเจน

3. ในแต่ละ handler:
   - ป้องกัน input ที่ไม่ครบด้วย validation ที่ชัดเจน
   - ใช้ error helper มาตรฐาน: `ApiError::badRequest(...)`, `ApiError::notFound(...)` ฯลฯ (ถ้ามีในระบบ)
   - ทุกจุดที่ error ให้มีทั้ง:
     - `app_code` ที่ unique
     - message ผ่าน `translate()`

### 4.3 SQL & Data Access

1. ตรวจทุก query ใน `product_api.php` และ:

   - เลิกใช้ `SELECT *`
   - ระบุ column list ชัดเจน (อิง schema จริง)
   - ถ้าต้อง join หรือมี where ที่ซับซ้อน ให้เขียนชัดเจนและปลอดภัย (no string concat สำหรับ user input)

2. สำหรับ action `duplicate`:
   - ถ้าต้องทำหลาย query → ให้ใช้ transaction helper มาตรฐาน (เช่น `DatabaseTransaction` หรือ helper ที่มีใน project)
   - แทรก comment อธิบาย idempotency: ถ้า user ยิงซ้ำ (double-click) → ไม่ควรทำให้ข้อมูลเละ

3. ใส่ comment level professional:
   - หลีกเลี่ยงคำแบบ casual
   - เขียนชัดเจน เช่น `// Ensure that classic products cannot bind DAG routing graphs.`

### 4.4 i18n & Error Messages

1. ทุกข้อความที่มีโอกาสถูกแสดงหน้า UI ให้ใช้รูปแบบ:

   ```php
   translate('api.product.error_invalid_product', 'Invalid product ID.')
   ```

   - key: ใช้ namespace `api.product.*`
   - default message: ภาษาอังกฤษ ล้วน ไม่มี emoji, ไม่มีตัวอักษรพิเศษ

2. Error model แนะนำ:

   ```json
   {
     "ok": false,
     "error": "Human readable English message",
     "app_code": "PROD_4xx_SOMETHING",
     "details": { ...optional... }
   }
   ```

3. สำหรับกรณีสำเร็จ:
   - `ok: true`
   - ถ้ามี message → ใช้ `translate('api.product.success_xxx', 'Some success message...')`

### 4.5 Caching / ETag (เฉพาะ read-only endpoint)

1. สำหรับ action เช่น `get_metadata`, `get_classic_dashboard`:
   - ถ้า response structure stable และเหมาะกับ caching → เพิ่ม:
     - ETag generation (เช่น hash จาก product_id + updated_at + org + action)
     - ตรวจ `If-None-Match` header แล้วคืน `304 Not Modified` เมื่อเหมาะสม

2. ใช้ helper กลางถ้ามี (เช่น `ApiCacheHelper`)  
   ถ้าไม่มี ให้เขียนเป็นฟังก์ชันเล็ก ๆ ในไฟล์ แต่ต้อง:
   - ไม่ซ้ำ logic กับไฟล์อื่น
   - เขียนคอมเมนต์ระบุว่า “temporary/local helper until we centralize caching”

> หมายเหตุ: ถ้าพบว่าการใส่ ETag ทำให้โค้ดอ่านยาก / ซับซ้อนเกินไป ให้เลือก solution ที่ *simple & safe* ไว้ก่อน แต่ควรเตรียม hook ไว้ในโครงสร้างเผื่ออนาคต

### 4.6 Logging & Observability

1. ทุก exception ที่หลุดถึง top-level catch:
   - Log ผ่าน `LogHelper` / logger กลาง
   - ใส่ context:
     - org / tenant
     - action
     - input หลัก ๆ (ไม่ log sensitive data)
     - correlation_id / ai_trace_key (ถ้ามี)

2. ไม่โยน stack trace ออกไปหน้า UI: frontend ควรเห็นแค่ message ที่ sanitize แล้ว

---

## 5. Non-Functional Requirements (Quality Gates)

ก่อนจบงาน Task 25.6 ให้ตรวจตาม checklist นี้:

1. **Syntax & Static Check**
   - `php -l source/product_api.php` ผ่าน
   - ไม่มี `use` ที่ไม่ได้ใช้
   - ไม่มี dead code segment ที่เหลือจาก refactor

2. **Coding Charter Compliance**
   - ผ่านมาตรฐาน:
     - ไม่มี `SELECT *`
     - ไม่มี `die/exit`
     - ไม่มี `header('Location: ...')`
     - ใช้ `translate()` สำหรับ user-facing messages
     - ไม่มีข้อความภาษาไทยในโค้ด / comment (ยกเว้นใน docs)

3. **Backward Compatibility**
   - ทดลองยิงแต่ละ action ด้วย payload เดิม:
     - `get_metadata`
     - `bind_routing`
     - `unbind_routing`
     - `duplicate`
     - `get_classic_dashboard`
   - ตรวจว่า:
     - ฟิลด์สำคัญใน JSON ยังมีเหมือนเดิม
     - ความหมายยังตรงกับ behavior เดิม

4. **Error Semantics**
   - กรณี product ไม่พบ → 404 + `PROD_404_NOT_FOUND`
   - กรณี action ไม่รู้จัก → 400 + `PROD_400_UNKNOWN_ACTION`
   - กรณี server error → 500 + `PROD_500_INTERNAL_ERROR`

---

## 6. Deliverables

เมื่อทำ Task 25.6 เสร็จ ให้ได้ผลลัพธ์ดังนี้:

1. ไฟล์ `source/product_api.php` ที่:
   - Align กับ `api_template.php`
   - ปลอดภัย, มีโครงสร้างชัดเจน
   - ผ่าน coding charter

2. อัพเดตเอกสาร:
   - เพิ่มสรุปผลใน `docs/super_dag/tasks/results/task25_6_results.md`
     - สรุปว่าแก้อะไรบ้าง
     - แนบรายการ action ที่มีอยู่ใน API
     - บอกข้อจำกัด/known issues (ถ้ามี)

3. (Optional แต่ควรทำ)  
   - แก้ `docs/super_dag/task_index.md` เพิ่ม Task 25.6 ในรายการ tasks

---

## 7. หมายเหตุสำคัญสำหรับ AI Agent

- ทำงานแบบ **incremental refactor**:  
  อย่า rewrite ทั้งไฟล์ทีเดียวจน scope หลุด ควร:
  1. จัด bootstrap + skeleton ให้เรียบร้อย
  2. แยก handler ตาม action
  3. ค่อย ๆ แก้ SQL, i18n, error model
- อย่าเพิ่ม feature ใหม่เองนอกเหนือจากที่ระบุในเอกสารนี้
- ทุกจุดที่ “ไม่แน่ใจ” → เลือกทางที่ **conservative, simple, และไม่ breaking** ก่อนเสมอ
- ถ้าต้องเลือก between “โค้ดสวย” vs “โค้ดอ่านง่ายและปลอดภัย” ให้เลือกอย่างหลัง

> เป้าหมายคือให้ `product_api.php` กลายเป็นตัวอย่าง API ที่ “ถ้า dev ใหม่เข้ามาในทีม ให้ดูไฟล์นี้เพื่อรู้มาตรฐานของ Bellavier Group ERP ทั้งหมด”