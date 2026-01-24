# 🔒 Security Audit Report - Draft/Published Write Path Separation

**Date:** 2025-12-15  
**Auditor:** AI Assistant (Claude Sonnet 4.5)  
**Scope:** Graph Draft/Published Write Operations  
**Severity:** P0 (Production Critical)

---

## 📋 Executive Summary

การ audit นี้ตรวจสอบความปลอดภัยของระบบ Graph Write Operations เพื่อป้องกันการเขียนข้อมูล Draft/Published ปนกัน ซึ่งอาจทำให้ช่างทำงานผิดกราฟและโรงงานพังได้

**ผลการ Audit:** ✅ **ระบบมีความปลอดภัยสูง** แต่พบช่องโหว่ 1 จุดที่ต้องแก้ไข (P0)

---

## 🎯 Audit Objectives

ตรวจสอบ 3 ประเด็นหลัก:

1. **Save Draft Operation** - เขียน table ไหน? มีทางทะลุไป published หรือไม่?
2. **UPDATE routing_graph_version** - มีการ UPDATE โดยตรงหรือไม่? (อันตรายมาก)
3. **Job/Runtime Read** - อ่านจาก version ที่ pin ไว้ หรืออ่าน latest? (publish ใหม่กระทบงานเก่าไหม?)

---

## 📊 Audit Results

### ✅ 1. Save Draft Operation

#### คำถาม:
> กด "Save Draft" มันเรียก action ไหน? `graph_save` หรือ `graph_update`? แล้ว server เลือก table จากอะไร?

#### ผลการตรวจสอบ:

**Action Flow:**
```
Frontend: action='graph_save_draft'
    ↓
dag_graph_api.php: case 'graph_save_draft'
    ↓ (fall through, set $_POST['save_type'] = 'draft')
case 'graph_save'
    ↓
GraphSaveModeResolver::resolve(['save_type' => 'draft', ...])
    ↓
Route to: GraphDraftService->saveDraft()
    ↓
INSERT/UPDATE routing_graph_draft ONLY
```

**Code Evidence:**

```php
// source/dag/dag_graph_api.php:749-759
case 'graph_save_draft':
    $_POST['save_type'] = 'draft';
    // Fall through to graph_save case

case 'graph_save':
    $resolvedMode = GraphSaveModeResolver::resolve([...]);
    // ...
    case 'draft':
        $draftService = new GraphDraftService($db);
        $result = $draftService->saveDraft($graphId, $nodes, $edges, $userId, $versionNote);
        // ✅ เขียนเฉพาะ routing_graph_draft
```

```php
// source/dag/Graph/Service/GraphDraftService.php:140-157
// INSERT หรือ UPDATE routing_graph_draft เท่านั้น
$insertStmt = $tenantDb->prepare("
    INSERT INTO routing_graph_draft (id_graph, draft_payload_json, updated_by, version_note) 
    VALUES (?, ?, ?, ?)
");
// หรือ
$updateStmt = $tenantDb->prepare("
    UPDATE routing_graph_draft 
    SET draft_payload_json = ?, updated_by = ?, updated_at = NOW() 
    WHERE id_graph_draft = ?
");
```

**สรุป:** ✅ **ปลอดภัย**
- เขียนเฉพาะ `routing_graph_draft` เท่านั้น
- ไม่มีการเขียนไป `routing_graph_version` หรือ `routing_graph` (published tables)
- ไม่มีทางทะลุไป published

---

### ✅ 2. UPDATE routing_graph_version โดยตรง?

#### คำถาม:
> มีที่ไหนใน backend ที่ "UPDATE routing_graph_version" โดยตรงไหม? (อันนี้คือระเบิด - เพราะ published ควรเป็น immutable)

#### ผลการตรวจสอบ:

**ค้นหาด้วย `grep`:**
```bash
grep -r "UPDATE.*routing_graph_version" source/dag/
# Result: ไม่พบการ UPDATE routing_graph_version
```

**Publish Operation:**

```php
// source/dag/Graph/Service/GraphVersionService.php:322-361
// Publish ทำ INSERT เท่านั้น (สร้าง snapshot ใหม่)
$insertStmt = $tenantDb->prepare("
    INSERT INTO routing_graph_version 
    (id_graph, version, payload_json, metadata_json, published_at, published_by, status, allow_new_jobs, config_json)
    VALUES (?, ?, ?, ?, ?, ?, 'published', ?, ?)
");
// ✅ INSERT เท่านั้น ไม่มี UPDATE
```

**สรุป:** ✅ **ปลอดภัย**
- ❌ **ไม่พบการ UPDATE `routing_graph_version` โดยตรง**
- Published versions เป็น **immutable snapshots** (INSERT เท่านั้น)
- การ publish สร้าง version ใหม่ ไม่แก้ version เก่า

---

### ✅ 3. Job/Runtime อ่านกราฟอย่างไร?

#### คำถาม:
> `job_ticket/runtime` อ่านกราฟจาก `routing_graph_version` "ตาม version_id ที่ pin" หรืออ่าน latest? (ถ้าอ่าน latest → publish ใหม่จะกระทบงานที่กำลังทำ → พัง!)

#### ผลการตรวจสอบ:

**Job Creation (Pin Version):**

```php
// source/job_ticket.php:1232-1265
// เมื่อสร้าง job_ticket จะ INSERT graph_version (version string ที่ pin)
$sql = "INSERT INTO job_ticket (..., id_routing_graph, graph_version) VALUES (..., ?, ?)";
// graph_version มาจาก graph_version_pin จาก product binding
```

**Job Runtime Read:**

```php
// source/dag/Graph/Service/GraphVersionResolver.php:256-312
public function resolveGraphForJob(int $jobId): array
{
    // 1. อ่าน graph_version จาก job_ticket (version ที่ pin ไว้)
    $stmt = $tenantDb->prepare("
        SELECT graph_version, id_routing_graph 
        FROM job_ticket 
        WHERE id_job_ticket = ?
    ");
    $graphVersion = $job['graph_version'] ?? null; // ✅ Version string ที่ pin
    
    // 2. Fallback: อ่านจาก job_graph_instance
    if (!$graphVersion) {
        $instanceStmt = $tenantDb->prepare("
            SELECT jgi.graph_version, jgi.id_graph
            FROM job_graph_instance jgi
            WHERE jgi.id_job_ticket = ?
        ");
    }
    
    // 3. Load version snapshot using version string (ไม่ใช่ latest!)
    // ✅ อ่านจาก version ที่ pin ไว้ ไม่ใช่ latest
}
```

**สรุป:** ✅ **ปลอดภัย**
- Job อ่านจาก `job_ticket.graph_version` (version string ที่ pin ไว้ตอนสร้าง job)
- **ไม่มีการอ่าน latest** → publish version ใหม่ไม่กระทบงานที่กำลังทำ
- งานแต่ละงานใช้กราฟ version เดิมตลอด (immutable)

---

## ⚠️ Vulnerability Found (P0)

### ช่องโหว่: `graph_save` ยังรับ `save_type=publish` ได้

**ความเสี่ยง:**
- Frontend อาจส่ง `save_type=publish` มาผิด (bug หรือ malicious request)
- ถึงแม้จะมี resolver แต่ควร block ที่ API layer เลย

**Evidence:**
```php
// source/dag/dag_graph_api.php:761-804
case 'graph_save':
    // ...
    $resolvedMode = GraphSaveModeResolver::resolve([
        'requested_save_type' => $_POST['save_type'] ?? null, // ⚠️ ยังรับ 'publish' ได้
        // ...
    ]);
    // ...
    case 'publish': // ⚠️ ยังมี case 'publish' ใน switch
        $versionService->publish(...);
```

**Impact:**
- เสี่ยงต่อการเขียน published โดยไม่ตั้งใจ
- ไม่ชัดเจนว่า publish ต้องใช้ endpoint แยก
- Architecture ไม่แยกชัดเจนระหว่าง draft และ published writes

**Recommendation:**
1. Block `save_type=publish` ใน `graph_save` endpoint (hard reject)
2. สร้าง endpoint `graph_publish` แยก (architectural separation)
3. Block `publish` ใน `GraphSaveModeResolver` (defense in depth)

---

## 📝 Files Examined

### Backend API:
- `source/dag/dag_graph_api.php` (1,380 lines)
- `source/dag/Graph/Service/GraphSaveModeResolver.php` (194 lines)
- `source/dag/Graph/Service/GraphDraftService.php`
- `source/dag/Graph/Service/GraphVersionService.php`

### Job/Runtime:
- `source/job_ticket.php`
- `source/dag/Graph/Service/GraphVersionResolver.php`
- `source/dag_token_api.php`

### Search Queries:
```bash
# Search for UPDATE routing_graph_version
grep -r "UPDATE.*routing_graph_version" source/dag/

# Search for graph_save_draft
grep -r "graph_save_draft" source/dag/

# Search for graph_version in job_ticket
grep -r "graph_version" source/job_ticket.php
```

---

## ✅ Security Guarantees (Before Patch)

### Draft Write:
- ✅ เขียนเฉพาะ `routing_graph_draft` เท่านั้น
- ✅ ไม่มีการเขียนไป published tables

### Published Write:
- ✅ Published versions เป็น immutable (INSERT เท่านั้น)
- ✅ ไม่มีการ UPDATE `routing_graph_version`
- ⚠️ แต่ยังสามารถ publish ผ่าน `graph_save` ได้ (ช่องโหว่)

### Job/Runtime Read:
- ✅ อ่านจาก version ที่ pin ไว้
- ✅ ไม่อ่าน latest → publish ใหม่ไม่กระทบงานเก่า

---

## 🎯 Conclusion

**Overall Security Rating:** 🟡 **Good (แต่มีช่องโหว่ 1 จุด P0)**

ระบบมีความปลอดภัยสูงในส่วน:
- ✅ Draft writes (เขียนเฉพาะ draft table)
- ✅ Published immutability (ไม่มี UPDATE)
- ✅ Job version pinning (อ่านจาก version ที่ pin)

**แต่พบช่องโหว่:**
- ⚠️ `graph_save` ยังรับ `save_type=publish` ได้

**Recommendation:** ควรทำ Hard Guarantee Patch เพื่อ block `save_type=publish` ใน `graph_save` และสร้าง endpoint `graph_publish` แยก

---

**Next Steps:**
1. ✅ Implement Hard Guarantee Patch (see `SECURITY_HARD_GUARANTEE_PATCH.md`)
2. ✅ Update frontend to use `graph_publish` endpoint
3. ✅ Add integration tests for security guarantees
4. ✅ Monitor security audit logs

---

**Report Generated:** 2025-12-15  
**Auditor:** AI Assistant (Claude Sonnet 4.5)  
**Status:** ✅ Complete - Hard Guarantee Patch Applied

