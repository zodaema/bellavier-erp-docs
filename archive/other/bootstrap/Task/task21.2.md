ตอนนี้ผมปรับ Utils.js ให้หน้า Products ทำงานปกติได้แล้ว
แต่ยังมีอีกหลากหลายหน้าที่มีปัญหาเดียวกัน(หลายหน้าที่ไม่ได้ใช้ utils.js แล้วอาการเดียวกัน) อยาก refactor ใหม่ให้ใช้ Utils.js



🧠 Prompt: Normalize DataTables to use BG.initServerTable + Fix JSON wrapper

You are working on the `bellavier-group-erp` repository.

## Goal

1. Find **all DataTables initializations** that:
   - Do NOT use `window.BG.initServerTable(...)`, or
   - Have their own custom `dataSrc` that assumes a different JSON shape.

2. Normalize them to:
   - Use the shared helper `BG.initServerTable` from:
     - `assets/javascripts/datatables/utils.js`
   - Or, if that is not possible, make sure their `dataSrc` logic is compatible with the new API response:
     ```json
     {
       "ok": true,
       "data": {
         "draw": 1,
         "recordsTotal": 8,
         "recordsFiltered": 8,
         "data": [ ... rows ... ]
       }
     }
     ```

## Current Standard (MUST FOLLOW)

Open `assets/javascripts/datatables/utils.js` and study:

```js
window.BG.initServerTable = function(selector, options){
  ...
  if (!merged.ajax.dataSrc) {
    merged.ajax.dataSrc = function(json) {
      if (!json) return [];

      // Case 1: New wrapper format { ok:true, data:{ draw, recordsTotal, recordsFiltered, data:[...] } }
      if (json && typeof json === 'object' && json.ok === true && json.data && typeof json.data === 'object') {
        var inner = json.data;
        if ('data' in inner && Array.isArray(inner.data)) {
          if (typeof inner.draw !== 'undefined') { json.draw = inner.draw; }
          if (typeof inner.recordsTotal !== 'undefined') { json.recordsTotal = inner.recordsTotal; }
          if (typeof inner.recordsFiltered !== 'undefined') { json.recordsFiltered = inner.recordsFiltered; }
          return inner.data;
        }
        if (Array.isArray(inner)) {
          return inner;
        }
      }

      // Case 2: Legacy DataTables shape { draw, recordsTotal, recordsFiltered, data:[...] }
      if (json && typeof json === 'object' && Array.isArray(json.data)) {
        return json.data;
      }

      // Case 3: Plain array [...]
      if (Array.isArray(json)) {
        return json;
      }

      console.warn('BG.initServerTable: Unexpected JSON shape for DataTables', json);
      return [];
    };
  }
  ...
};

This is the canonical adapter for server-side DataTables.

Tasks

Task A – Scan for DataTables usage
	1.	Search the entire repo (especially under assets/javascripts/ and views/) for:
	•	.DataTable(
	•	DataTable({
	•	initServerTable(
	•	dataSrc:
	2.	Build a short list of JS files / views that:
	•	Initialize DataTables directly via $(selector).DataTable({ ... }), and
	•	Do NOT go through BG.initServerTable.

Examples of typical patterns to refactor:

$('#products-table').DataTable({
  processing: true,
  serverSide: true,
  ajax: {
    url: 'source/products.php',
    type: 'POST',
    dataSrc: function(json) {
      return json.data; // legacy, now broken
    }
  },
  ...
});

or:

$('#something').DataTable({
  ajax: 'source/xyz.php',
  ...
});

Task B – For each DataTable init, decide:

For each DataTable initialization you found:
	1.	If it is a normal server-side table (standard CRUD listing)
Example: products, materials, bom, qc_rework, users, people, etc.
→ Refactor to use BG.initServerTable:

window.BG.initServerTable('#products-table', {
  url: 'source/products.php',
  method: 'POST',
  // keep existing "columns", "order", etc.
  columns: [ ... ],
  order: [ ... ],
  // If there was extra ajax.data, keep it:
  ajax: {
    data: function(d) {
      // merge filters/search params
    }
  }
});

Rules:
	•	Remove any custom dataSrc if it was just return json.data.
	•	Let BG.initServerTable handle the wrapper { ok:true, data:{...} }.

	2.	If it has truly custom behavior
For example:
	•	The API returns { ok:true, data:[ ... ] } without server-side pagination meta.
	•	Or the table is client-side only (no serverSide).
Options:
	1.	Still try to use BG.initServerTable if possible (it already supports:
	•	inner.data for server-side
	•	or inner if it’s a plain array).
	2.	If you must keep a local .DataTable({ ... }):
	•	Implement a local dataSrc that is compatible with the new standard:

dataSrc: function(json) {
  if (!json) return [];

  // new wrapper
  if (json.ok === true && json.data) {
    // array payload
    if (Array.isArray(json.data)) {
      return json.data;
    }
    // inner { data: [...] }
    if (json.data && Array.isArray(json.data.data)) {
      return json.data.data;
    }
  }

  // legacy { data: [...] }
  if (Array.isArray(json.data)) {
    return json.data;
  }

  if (Array.isArray(json)) {
    return json;
  }

  console.warn('Custom DataTable: unexpected JSON shape', json);
  return [];
}



Task C – Pages currently broken (high priority)

Specifically check these screens first (examples, adjust to real file names):
	•	Products list
	•	Materials list
	•	BOM list
	•	QC Rework list
	•	Any other manager pages that:
	•	Call source/products.php, source/materials.php, source/bom.php, source/qc_rework.php
	•	Or call APIs already migrated to use TenantApiOutput with { ok:true, data:{...} }

For each of them:
	1.	Confirm the JSON response in Network tab (should be the wrapped shape).
	2.	Ensure the corresponding JS:
	•	Uses BG.initServerTable OR
	•	Has a dataSrc that understands the wrapped shape.

Constraints / Safety Rails
	•	DO NOT change the backend JSON payload shape again.
	•	Keep { ok:true/false, data:{ ... } } as is.
	•	DO NOT change business logic on the server (SQL, filters, etc.).
	•	DO NOT touch unrelated modules (time-engine, WIP engine, bootstrap, etc.).
	•	Focus only on:
	•	DataTables initialization JS
	•	Their ajax + dataSrc behavior
	•	Prefer refactoring into BG.initServerTable to keep future work simpler.

Acceptance Criteria
	•	All pages that previously showed an empty table while Network shows valid JSON:
	•	Now render the rows correctly.
	•	For server-side DataTables:
	•	Pagination, search, and lengthMenu work as before.
	•	No console errors related to:
	•	DataTables warning: table id=... - Invalid JSON response
	•	Or json.data being undefined.
	•	assets/javascripts/datatables/utils.js remains the only canonical location for shared DataTables dataSrc logic.

---


⸻

0. วิธีให้ Agent ไล่หา DataTables ทั้งระบบ

ก่อนเข้าเช็กลิสต์ ให้ Agent เริ่มจาก:
	1.	ค้นทั้ง repo หา:
	•	.DataTable(
	•	DataTable({
	•	dataSrc:
	•	initServerTable(
	2.	โฟกัสโฟลเดอร์:
	•	assets/javascripts/
	•	views/ (ถ้ามี inline script)
	•	อาจจะมี assets/javascripts/tenant/, manager/, platform/ อะไรพวกนี้

⸻

1. Priority P0 – หน้าที่ “น่าชัวร์ว่าเกี่ยว” และมีผลใช้จริง

✅ P0.1 Products List
	•	API: source/products.php (ใช้ TenantApiOutput แล้ว)
	•	JS ที่น่าจะเกี่ยว:
	•	assets/javascripts/tenant/products.js
	•	หรือไฟล์ JS อะไรก็ได้ที่มีคำว่า products + .DataTable(
	•	inline script ใน view/page products

ให้ Agent ทำ:
	•	ตรวจว่า init DataTables หน้านี้:
	•	ใช้ BG.initServerTable('#products-table', {...}) หรือไม่
	•	ถ้าไม่ → refactor ให้ใช้ BG.initServerTable
	•	ห้ามเขียน dataSrc: json => json.data อีก
	•	ให้เชื่อมกับ API ที่ส่ง { ok:true, data:{ draw, recordsTotal, recordsFiltered, data:[...] } }

⸻

✅ P0.2 Materials List
	•	API: source/materials.php (ใช้ TenantApiOutput แล้ว)
	•	JS ที่น่าจะเกี่ยว:
	•	assets/javascripts/tenant/materials.js
	•	หรือ script ที่มี selector ประมาณ #materials-table

ให้ Agent ทำ:
	•	เหมือน Products:
refactor ไปใช้ BG.initServerTable + ลบ dataSrc custom ที่ assume json.data

⸻

✅ P0.3 BOM List
	•	API: source/bom.php
	•	JS:
	•	assets/javascripts/tenant/bom.js
	•	selector น่าจะประมาณ #bom-table หรือใกล้เคียง

ให้ Agent ทำ:
	•	เช็กว่า DataTable init ของ BOM:
	•	ถ้าใช้ .DataTable({ ajax: ..., dataSrc: ... }) ตรง ๆ → migrate มาใช้ BG.initServerTable
	•	ให้แน่ใจว่า response ที่ห่อ { ok:true, data:{...} } ถูกปลด wrapper แล้วผ่าน dataSrc ของ utils.js

⸻

✅ P0.4 QC Rework List
	•	API: source/qc_rework.php
	•	JS:
	•	assets/javascripts/tenant/qc_rework.js
	•	หรือ script ไหนที่ใช้คำว่า qc_rework + .DataTable(

ให้ Agent ทำ:
	•	Refactor เหมือนสามหน้าบนให้ใช้ BG.initServerTable
	•	เช็กว่า filter/search ยังทำงานหลังแก้

⸻

✅ P0.5 People / Employees List

(โดยเฉพาะที่ใช้ใน Manager Assignment)
	•	API ที่น่าจะเกี่ยว:
	•	source/people_api.php
	•	อาจมี source/employees.php / users.php แล้วแต่โครงสร้างจริง
	•	JS:
	•	assets/javascripts/tenant/people.js
	•	assets/javascripts/manager/assignment_people.js หรือชื่อคล้าย ๆ

ให้ Agent ทำ:
	•	ถ้ามี DataTable ที่แสดงรายชื่อช่าง / พนักงาน:
	•	ดูว่ารูป JSON ที่ส่งกลับตอนนี้เป็นแบบไหน (มี ok:true หรือไม่)
	•	ถ้าเป็น server-side table → ย้ายมาใช้ BG.initServerTable
	•	ถ้าเป็น client-side/array-only → อาจใช้ BG.initServerTable ได้เหมือนกัน (รองรับ plain array)

⸻

2. Priority P1 – หน้าจอ Master / Setup อื่น ๆ

กลุ่มนี้ “มีโอกาสใช้ pattern เดียวกัน” กับ Products/Materials:

✅ P1.1 Product Categories
	•	API (คาดเดา): source/product_categories.php หรือคล้าย ๆ
	•	JS: ไฟล์ที่ชื่อมี categories + .DataTable(

✅ P1.2 UOM (หน่วยนับ)
	•	API: source/uom.php หรือชื่อใกล้เคียง
	•	JS: ไฟล์ที่มี uom + .DataTable(

✅ P1.3 Routing Graphs / DAG Routing List
	•	API:
	•	source/dag_routing_api.php (อาจใช้เป็น data source ใน Datatable)
	•	JS:
	•	assets/javascripts/tenant/dag_routing.js
	•	หรือไฟล์ไหนที่เปิดหน้าจอ routing graph list

ให้ Agent ทำสำหรับ P1:
	•	ไล่หาทุก DataTable init ที่ load master data (categories/uom/routing/ฯลฯ)
	•	พยายาม unify รูปแบบให้ใช้:

BG.initServerTable('#some-table', {
  url: 'source/xxx.php',
  method: 'POST', // หรือ GET ตามเดิม
  columns: [...],
  order: [...]
});



⸻

3. Priority P2 – WIP / Time Engine / Production Monitoring

แม้บางตัวอาจใช้ pattern คนละแบบ แต่ให้ Agent inspect:

✅ P2.1 Work Queue

คุณใช้งานอยู่บ่อยแล้ว
	•	API ที่น่าจะใช้: source/work_queue_api.php หรือคล้าย ๆ
	•	JS:
	•	assets/javascripts/tenant/work_queue.js
	•	หรือไฟล์เกี่ยวกับ time-engine/work-queue

ให้ Agent ทำ:
	•	ถ้ามี DataTable แสดงรายการ token / งานในคิว:
	•	ดูว่าใช้ DataTables แบบไหน
	•	ถ้า response รูปแบบ { ok:true, data:{ data:[...] } } → สามารถใช้ BG.initServerTable ได้
	•	ถ้า table นี้ใช้ refresh แบบ custom (reload เฉพาะบาง column) → ต้องพิจารณา case-by-case แต่เป้าหมายคือ ลด custom dataSrc ทิ้งให้เยอะที่สุด

✅ P2.2 Trace / WIP Logs / Token Status
	•	API:
	•	source/trace_api.php
	•	source/dag_token_api.php
	•	JS:
	•	ไฟล์ที่มี trace_list, dag_token_status, ฯลฯ

ถ้ามี DataTable ที่ดึงข้อมูลจากสอง API นี้:
	•	ถ้าใช้ server-side DataTables → ควรย้ายมาใช้ BG.initServerTable
	•	ถ้าใช้ purely client-side (เอาข้อมูลมาปั่น row เอง) → ไม่ต้องยุ่งก็ได้

⸻

4. Priority P3 – Platform / Admin Screens

พวกจอ platform admin ที่อาจมี DataTables:

✅ P3.1 Platform Roles / Tenant Owners
	•	API:
	•	source/platform_roles_api.php
	•	source/platform_tenant_owners_api.php
	•	JS:
	•	Files ที่มี platform_roles, tenant_owners + .DataTable(

✅ P3.2 Feature Flags / Migrations / Health

บางอันอาจไม่ได้ใช้ DataTables แต่ให้ Agent scan:
	•	admin_feature_flags.php (view)
	•	platform_migration.php (view)
	•	ฯลฯ

⸻