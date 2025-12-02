📘 Task 25.4 — Deprecate Classic DAG / Cleanup Graph Binding UI & Backend

Phase: Products Module — Finalization Round
Objective: ทำให้ระบบ Product/Graph Binding สอดคล้อง 100% กับแนวคิดใหม่:

Note: Task 25.3 ได้วางโครง ProductMetadataResolver + product_api แล้ว แต่ UI/behavior ยังใช้ของเดิม Task 25.4 นี้มีหน้าที่ “ตบให้เข้าที่” ทั้งฝั่ง API guard + UI wiring ให้ Classic/Hatthasilpa แยกกันชัดเจน.

Classic Line = ไม่ต้องใช้ DAG
Hatthasilpa Line = ต้องมี DAG Binding เท่านั้น

⸻

🎯 Objectives
	1.	ตัด DAG/Graph Binding ออกจาก Classic ให้หมด
	•	UI ไม่ต้องแสดง Graph Binding tab เมื่อ product.production_line = classic
	•	backend ไม่ต้อง validate routing สำหรับ Classic
	•	API ไม่ต้องส่ง routing metadata สำหรับ Classic
	2.	Graph Binding = Hatthasilpa only
	•	product.production_line = hatthasilpa → ต้องมี routing_graph_id
	•	Classic → ห้าม bind graph และแสดง error ถ้ามีการ bind มาแบบผิด
	3.	Clean UI / JS
	•	ซ่อนปุ่ม/เมนูเกี่ยวกับ Graph Binding เมื่อ classic
	•	โมดัล binding ต้องซ่อนทั้ง tab และ inputs เมื่อ classic
	4.	Product API Cleanup
	•	simplify logic: if classic → skip routing validation
	•	if hatthasilpa → enforce routing binding
	5.	Routing Graph Binding Modal Rewrite
	•	ปรับโครง modal เพื่อแสดงเฉพาะข้อมูลที่จำเป็นสำหรับ line นั้น ๆ
	•	Classic → แสดง Classic Dashboard (output/day, lead time)
	•	Hatthasilpa → แสดง Graph Binding UI
	6.	Backward Safety
	•	ถ้า product classic ที่เคยมี routing_graph_id → ลบค่าออกอัตโนมัติ
	•	เขียน migration script ปรับฐานข้อมูล

⸻

⚙️ Implementation Checklist

1. Product API (product_api.php)

A. แก้ get_metadata
	•	ถ้า production_line = classic
ส่งกลับ:

{ "production_line": "classic", "supports_graph": false }


	•	ถ้า hatthasilpa
ส่งกลับ:

{ "production_line": "hatthasilpa", "supports_graph": true, "routing": {...} }



B. ปรับ Validation
	•	Classic → skip routing validation
	•	Hatthasilpa → enforce routing binding

C. Add new warnings
	•	ถ้า classic + routing_graph_id ≠ null → warn + auto-clear

⸻

2. ProductMetadataResolver.php

Rewrite resolver:

if classic:
    supports_graph = false
    routing_graph_id = null
else:
    supports_graph = true
    validate graph binding...


⸻

3. Graph Binding Modal (products.php)

A. Tab Control
	•	ซ่อน tab Graph Binding ทั้ง block ถ้า product = classic
	•	แสดงเฉพาะ tab Classic Dashboard

B. Binding Form
	•	disable ทุก input เมื่อ production_line = classic

⸻

4. JavaScript — product_graph_binding.js

A. Load metadata logic
	•	ถ้า supports_graph = false
→ hide binding tab
→ hide save buttons
→ show “Classic product — no routing required”

B. Cleanup Legacy Paths
	•	remove references to “OEM/Atelier”
	•	remove routing auto-load when classic

⸻

5. Database Migration

เขียน migration:

UPDATE product SET routing_graph_id = NULL
WHERE production_line = 'classic';


⸻

6. Safety: Prevent Inconsistent Binding

Add backend guard:
	•	ถ้า product classic แล้ว user พยายาม bind graph
→ return error: "Classic line cannot bind DAG routing"

⸻

🔧 Prompt for Cursor (Appendix A)

สำคัญ: ออกแบบให้ cursor ทำงาน “แบบไม่แตก” และไม่แตะไฟล์อื่นนอกเหนือจากที่กำหนด

Action: Deprecate DAG for Classic line & cleanup product binding UI

Modify the following files:
1. source/product_api.php
2. source/BGERP/Product/ProductMetadataResolver.php
3. views/products.php
4. assets/javascripts/products/product_graph_binding.js
5. database/migrations (create new migration)

Requirements:
- If product.production_line = 'classic':
    * supports_graph = false
    * routing_graph_id must always be NULL
    * skip routing validation
    * hide graph binding UI
    * replace binding tab content with a message: "Classic products do not use DAG routing"

- If product.production_line = 'hatthasilpa':
    * supports_graph = true
    * enforce routing_graph_id
    * show binding UI exactly as before

- Add backend guard: if classic + bind request → return error

- Modify products.php:
    * hide the entire Graph Binding tab for classic
    * auto-select Classic Dashboard tab
    * disable save buttons for binding

- Modify JS:
    * on loadMetadata(), if supports_graph = false:
        - hide binding tab
        - hide binding-related buttons
        - show fallback message

- Create migration:
    UPDATE product SET routing_graph_id = NULL WHERE production_line='classic';

Keep code style, formatting, and function boundaries identical. DO NOT break Hatthasilpa behavior.


⸻