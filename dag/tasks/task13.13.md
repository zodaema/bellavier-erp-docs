Task 13.13 — Auto Material SKU Detection for CUT Behavior

Status: PLANNED
Date: December 2025
Related: Task 13.12 (Leather Sheet Usage Binding), super_dag roadmap

⸻

1. เป้าหมาย (Objective)

ให้ระบบสามารถ หา Material SKU อัตโนมัติจาก Token (ผ่าน Product / MO / BOM)
เพื่อลด Human Error และทำให้ Leather Sheet Usage + Traceability ไหลผ่านได้เองโดยไม่ต้องถามช่าง
	•	เมื่อเปิด CUT Behavior Panel → ระบบรู้เองว่า Token นี้ควรใช้หนัง SKU อะไร
	•	เมื่อกด “เลือก Leather Sheet” → ไม่ต้องพิมพ์ Material SKU เอง (auto-fill / auto-filter ให้เลย)
	•	รองรับกรณีที่หนึ่ง Token ใช้วัสดุหลักเพียงตัวเดียว (Primary Leather Material สำหรับ CUT)

⸻

2. Scope

IN SCOPE
	1.	สร้าง Material Resolver Layer สำหรับหา material_sku จาก token_id
	2.	เพิ่มความสามารถใน API leather_sheet_api.php ให้รับ token_id เพื่อตี Material SKU ให้อัตโนมัติ
	3.	ปรับ CUT Behavior UI (behavior_execution.js):
	•	ไม่ถาม Material SKU ด้วย prompt() อีกต่อไป (กรณีปกติ)
	•	ดึง list available sheets จาก token_id โดยตรง
	•	แสดง Material SKU ที่ระบบ detect ได้บน UI
	4.	Logging + error handling กรณีหา Material ไม่เจอ

OUT OF SCOPE
	•	การบังคับ Hard Enforcement ว่าต้องมี usage ก่อน complete (จะไปทำใน Task 13.15)
	•	Supervisor Dashboard (ไปอยู่ Task 13.16)
	•	Multi-material / Multi-layer (ถ้า 1 token ใช้วัสดุหลายตัว จะเก็บไว้สำหรับ Phase ถัดไป)

⸻

3. Business Rules — Auto Material Detection

ระบบจะ พยายามหา Material SKU ตามลำดับต่อไปนี้:
	1.	Token-level direct mapping (ถ้ามี)
	•	ถ้าใน flow_token หรือ table ที่เกี่ยวข้อง มี column เช่น material_sku หรือ primary_material_sku
	•	ให้ใช้ค่านี้เป็นอันดับแรก
	2.	Mapping จาก MO / Work Order
	•	Token → MO (Manufacturing Order)
	•	ถ้า MO มีการกำหนด “Main Leather Material” ไว้ ให้ใช้ตัวนั้น
	3.	Mapping จาก Product BOM
	•	Token → Product → BOM
	•	ใน BOM ให้เลือก material บรรทัดที่:
	•	เป็น leather principal (เช่น flag is_primary_leather = 1)
	•	หรือเป็น BOM line ที่ mapping กับ CUT ขั้นตอนนั้น (ถ้ามี relation)
	4.	Fallback / Error Case
	•	ถ้าหาไม่ได้จากทุกช่องทาง:
	•	API ส่ง error code พิเศษ เช่น LEATHER_SHEET_404_MATERIAL_NOT_FOUND
	•	UI แสดงข้อความเตือน และ fallback ไปเป็น manual input (ให้ช่างใส่ SKU เอง)

หมายเหตุ: Implementation จริงสามารถ map กับโครงสร้าง table ที่มีอยู่จริงได้
Logic ด้านบนเป็น ลำดับความสำคัญและกติกาเชิง Business ที่ต้องยึดไว้

⸻

4. Backend Design

4.1 สร้าง Material Resolver Helper

File ใหม่:
source/BGERP/Helper/MaterialResolver.php

Namespace:
BGERP\Helper

Class: MaterialResolver

Responsibility:
รวม logic สำหรับหา Material SKU จาก token_id ไว้ที่เดียว (ไม่ให้กระจายอยู่มั่วในหลายไฟล์)

Method หลัก (ขั้นต่ำ):

namespace BGERP\Helper;

class MaterialResolver
{
    /**
     * Resolve primary leather material SKU for a given token.
     *
     * @return string|null  material_sku หรือ null ถ้าหาไม่ได้
     */
    public static function resolvePrimaryLeatherSkuForToken(\mysqli $tenantDb, int $tokenId): ?string
    {
        // 1) ลองจาก token-level mapping
        // 2) ลองจาก MO / Work Order
        // 3) ลองจาก Product BOM
        // 4) ถ้าไม่พบ return null
    }
}

Implementation รายละเอียด mapping ให้ผูกกับ schema จริงของ BGERP (MO, Product, BOM) ภายหลัง
แต่โครงสร้าง class + method ต้องมีตามนี้

⸻

4.2 ปรับ API: source/leather_sheet_api.php

4.2.1 list_available_sheets — รองรับการใช้ token_id
ปัจจุบัน:
	•	รับ material_sku (required) + search (optional)

ต้องการปรับเป็น:
	•	รองรับ 2 mode
	1.	material_sku (เหมือนเดิม)
	2.	token_id (ใหม่) → ระบบ resolve material_sku ภายใน

Input ที่รองรับ
	•	action = list_available_sheets
	•	material_sku (optional)
	•	token_id (optional)
	•	search (optional)

กติกา:
	1.	ถ้า client ส่ง material_sku มา → ใช้ตามนั้น (priority สูงสุด)
	2.	ถ้าไม่ส่ง material_sku แต่ส่ง token_id →
	•	ใช้ MaterialResolver::resolvePrimaryLeatherSkuForToken()
	•	ถ้าเจอ → นำไปใช้ query leather sheets
	•	ถ้าไม่เจอ → ส่ง error
	3.	ถ้าไม่ส่งทั้ง material_sku และ token_id → ส่ง error LEATHER_SHEET_400_MISSING_CRITERIA

Error Codes ใหม่ที่ต้องเพิ่ม:
	•	LEATHER_SHEET_400_MISSING_CRITERIA
→ ไม่มีทั้ง material_sku และ token_id
	•	LEATHER_SHEET_404_MATERIAL_NOT_FOUND
→ resolve material จาก token_id ไม่เจอ

ตัวอย่างโครง Response เพิ่มเติม (เมื่อใช้ token_id):

{
  "ok": true,
  "app_code": "LEATHER_SHEET_LIST",
  "material_sku": "MAT-SAFF-001",
  "sheets": [
    {
      "id_sheet": 1,
      "sheet_code": "MAT-SAFF-20251120-001",
      "grn_number": "GRN-2025-001",
      "area_original": 20.0,
      "area_used": 5.5,
      "area_remaining": 14.5
    }
  ]
}


⸻

5. Frontend / UI Design

5.1 ปรับ CUT Behavior JS — assets/javascripts/dag/behavior_execution.js

เราโฟกัสที่ฟังก์ชันที่ใช้อยู่แล้วจาก Task 13.12:
	•	openSheetSelectionModal(tokenId) (ปัจจุบันใช้ prompt ถาม Material SKU)
	•	loadSheetUsages(tokenId)
	•	renderSheetUsageList(...)
	•	deleteUsage(...)

ของใหม่ที่ต้องทำ:

5.1.1 เปลี่ยนจาก prompt ถาม Material SKU → ใช้ token_id
	•	เมื่อช่างกด “เลือก Leather Sheet”:
	•	เรียก API: leather_sheet_api.php?action=list_available_sheets&token_id=...
	•	ถ้า success:
	•	แสดงแผ่นหนังใน modal (ตอนนี้ MVP อาจยังใช้ prompt/select แบบง่าย แต่ไม่มี prompt SKU แล้ว)
	•	แสดง material_sku ที่ detect ได้ใน UI (เช่นในหัว modal หรือใต้มุม “Material”)
	•	ถ้า error LEATHER_SHEET_404_MATERIAL_NOT_FOUND:
	•	แจ้งเตือนข้อความ เช่น
“ไม่พบ Material สำหรับ Token นี้ กรุณาใส่ Material SKU ด้วยตนเอง”
	•	แล้วเปิด prompt ให้กรอก Material SKU ตาม behavior เดิม (fallback mode)

5.1.2 แสดง Material SKU ที่ระบบหาได้บน Panel
ใน CUT behavior panel (template ที่มี “Leather Sheets Used” section):
	•	เพิ่ม text หรือ small badge เช่น:

Material: MAT-SAFF-001 (auto-detected)

หรือ

<div class="text-muted small">
  Material SKU: <span id="cut-material-sku-label">MAT-SAFF-001</span>
</div>

แล้วใน JS เมื่อเรียก list_available_sheets (ใช้ token_id) แล้วได้ material_sku กลับมา →
update DOM นี้ทุกครั้ง

⸻

6. Logging & Safety

6.1 Logging
	•	ถ้า resolve material จาก token ไม่ได้:
	•	Log ระดับ warning ระบุ token_id, user, node, behavior
	•	ถ้าเกิด exception ภายใน MaterialResolver:
	•	Log error พร้อม stack trace (แต่ response กลับไปเป็น standard JSON error)

6.2 Backward Compatibility
	•	ถ้าคนเรียก API แบบเดิมโดยส่ง material_sku → behavior ต้องเหมือนเดิม 100%
	•	ถ้า JS ใน behavior อื่น (นอก CUT) ยังไม่ได้ปรับให้ใช้ token_id → ยังสามารถใช้ material_sku ได้ในอนาคต

⸻

7. Acceptance Criteria

7.1 Functional
	1.	เมื่อเปิด CUT behavior panel สำหรับ token ที่มี Product/BOM ครบ:
	•	ระบบสามารถเรียก list_available_sheets ด้วย token_id ได้สำเร็จ
	•	Response มี material_sku ที่ถูกต้อง
	•	UI แสดง Material SKU ที่ detect ได้
	2.	เมื่อกด “เลือก Leather Sheet”:
	•	ไม่ปรากฏ prompt() ให้กรอก Material SKU ในกรณีปกติ
	•	List ของ Leather Sheets ที่แสดงต้องตรงกับ Material SKU ที่ resolve ได้
	3.	กรณี token ที่ไม่มีข้อมูล material (เช่น token test, incomplete setup):
	•	API คืน LEATHER_SHEET_404_MATERIAL_NOT_FOUND
	•	UI แจ้งเตือน และ fallback ไป prompt สำหรับกรอก Material SKU manual
	4.	Behavior เดิมจาก Task 13.12 ยังทำงานได้:
	•	Bind usage
	•	Delete usage
	•	Load usage list
	•	Soft warning ตอน complete

⸻

7.2 Non-Functional
	•	Response time ของ list_available_sheets หลังเพิ่ม logic resolve material:
	•	ไม่ช้ากว่าเดิมอย่างมีนัยสำคัญ (ควรยังต่ำกว่า ~300ms ในเงื่อนไขปกติบน tenant DB)
	•	ไม่มีการเพิ่ม migration ใหม่ใน task นี้ (No DB schema change)
	•	Code ผ่าน php -l ทุกไฟล์ที่แก้ไข / เพิ่ม
	•	ไม่ทำให้ behavior อื่นที่ใช้ leather_sheet_api.php พัง

⸻

8. Files ที่ต้องสร้าง/แก้ไข

สร้างใหม่
	1.	source/BGERP/Helper/MaterialResolver.php
	•	Static method สำหรับ resolve primary leather material จาก token_id

แก้ไข
	1.	source/leather_sheet_api.php
	•	เพิ่มการรองรับ token_id ใน list_available_sheets
	•	ใช้ MaterialResolver ในการหา material_sku
	•	เพิ่ม error codes ใหม่
	2.	assets/javascripts/dag/behavior_execution.js
	•	ปรับ openSheetSelectionModal() ให้ใช้ token_id แทน prompt material_sku
	•	อัปเดต UI แสดง material_sku ที่ detect ได้
	•	รองรับ fallback manual SKU เมื่อ API หาไม่เจอ
	3.	(ถ้าจำเป็น) assets/javascripts/dag/behavior_ui_templates.js
	•	เพิ่ม placeholder แสดง Material SKU ใน CUT panel (เช่น <span id="cut-material-sku-label"></span>)

⸻

9. หมายเหตุ / Design Notes
	•	Task 13.13 นี้ถือเป็น สะพานสำคัญ ระหว่าง:
	•	Token ↔ Product / BOM ↔ Material ↔ Leather Sheet ↔ CUT Behavior
	•	เมื่อจบ Task นี้:
	•	Token ทุกตัวที่วิ่งเข้า CUT จะ “ผูก” กับ Material SKU โดยอัตโนมัติ
	•	ทำให้ Task ถัดไป (Enforcement, Dashboard, Costing, super_dag) ใช้ข้อมูลนี้ได้ทันที
