# Graph Save Logic Audit Report
**Date:** 2025-12-09  
**Scope:** เปรียบเทียบ logic ระหว่าง `dag_routing_api_original.php` กับ implementation ใหม่ใน `dag_graph_api.php` + `GraphSaveEngine.php`  
**Purpose:** ตรวจสอบว่ามี logic ใดหายไปหรือเพี้ยนไปจากเดิม

---

## Executive Summary

จากการ audit โค้ดทั้งหมด พบความแตกต่างที่สำคัญ **3 จุด** ซึ่งอาจส่งผลต่อพฤติกรรมของระบบ:

1. **⚠️ PURGE PROTECTION สำหรับ Edges หายไป** - Logic `confirm_purge` และ `protect_purge_edges` feature flag ไม่ถูก migrate
2. **⚠️ Empty Node List Warning หายไป** - การเตือนเมื่อส่ง empty node list ไม่ถูก migrate
3. **⚠️ Breaking Changes Detection หายไป** - Logic `signatureCheck` และ `has_breaking_change` ไม่ถูก migrate (แต่ดูเหมือนจะไม่ได้ถูกใช้จริง)

ส่วนอื่น ๆ ทั้งหมดถูก migrate ครบและทำงานถูกต้องตามเดิม

---

## 1. Purge Protection สำหรับ Edges ⚠️ **หายไป**

### Original (`dag_routing_api_original.php` lines 3088-3120)

```php
// Purge protection: SKIP for autosave (don't modify edges during autosave)
// ALWAYS allow save - convert purge warnings instead of blocking
if (!$isAutosave) {
    $edgeIds = array_filter(array_column($edges, 'id_edge'));
    $confirmPurge = ($_POST['confirm_purge'] ?? '0') === '1';
    $protectPurge = getFeatureFlag('protect_purge_edges', true);
    
    // Check existing edge count
    $existingEdgeCount = $db->fetchOne("SELECT COUNT(*) as cnt FROM routing_edge WHERE id_graph = ?", [$graphId], 'i');
    $hasExistingEdges = ($existingEdgeCount['cnt'] ?? 0) > 0;
    
    // Warn if purging edges but don't block save (prevent data loss)
    if (empty($edgeIds) && $hasExistingEdges && $protectPurge && !$confirmPurge) {
        $structureWarnings[] = sprintf(
            'Warning: Empty edge list detected (existing: %d edges). All edges will be removed. Use confirm_purge=1 to suppress this warning.',
            $existingEdgeCount['cnt']
        );
        // Log warning for audit
        error_log("Graph {$graphId}: Purging all edges without confirmation (count: {$existingEdgeCount['cnt']})");
    }
    
    // Delete edges not in the list
    if (!empty($edgeIds)) {
        // ... delete edges NOT IN list
    } else {
        // Delete all edges if none in list (ALWAYS allow - prevent data loss)
        error_log("Graph {$graphId}: Purging all edges (count: {$existingEdgeCount['cnt']})");
        $db->execute("DELETE FROM routing_edge WHERE id_graph = ?", [$graphId], 'i');
    }
}
```

### New Implementation (`GraphSaveEngine.php` lines 321-332)

```php
// Handle edge operations (SKIP for autosave)
if (!$isAutosave) {
    // Delete edges not in the list
    $edgeIds = array_filter(array_column($edges, 'id_edge'));
    if (!empty($edgeIds)) {
        // ... delete edges NOT IN list
    } else {
        $db->execute("DELETE FROM routing_edge WHERE id_graph = ?", [$graphId], 'i');
    }
    // ... update/insert edges
}
```

### ผลกระทบ

- **Frontend ส่ง `confirm_purge=1` มา แต่ backend ไม่ได้เช็ค** → ไม่มีผล แต่ไม่มี error
- **Feature flag `protect_purge_edges` ไม่มีผล** → ระบบจะลบ edges ทันทีโดยไม่เตือน
- **Warning message หายไป** → User อาจไม่รู้ว่ากำลังลบ edges ทั้งหมด

### แนะนำการแก้ไข

เพิ่ม purge protection logic กลับเข้าไปใน `GraphSaveEngine.php`:

```php
// Handle edge operations (SKIP for autosave)
if (!$isAutosave) {
    $edgeIds = array_filter(array_column($edges, 'id_edge'));
    
    // Purge protection (match original behavior)
    $optionsConfirmPurge = $options['confirmPurge'] ?? null;
    $confirmPurge = ($optionsConfirmPurge === true || $optionsConfirmPurge === '1');
    $protectPurge = \getFeatureFlag('protect_purge_edges', true);
    
    // Check existing edge count
    $existingEdgeCount = $db->fetchOne("SELECT COUNT(*) as cnt FROM routing_edge WHERE id_graph = ?", [$graphId], 'i');
    $hasExistingEdges = ($existingEdgeCount['cnt'] ?? 0) > 0;
    
    // Warn if purging edges but don't block save (prevent data loss)
    if (empty($edgeIds) && $hasExistingEdges && $protectPurge && !$confirmPurge) {
        $structureWarnings[] = sprintf(
            'Warning: Empty edge list detected (existing: %d edges). All edges will be removed. Use confirm_purge=1 to suppress this warning.',
            $existingEdgeCount['cnt']
        );
        error_log("Graph {$graphId}: Purging all edges without confirmation (count: {$existingEdgeCount['cnt']})");
    }
    
    // Delete edges not in the list
    if (!empty($edgeIds)) {
        // ... existing logic
    } else {
        error_log("Graph {$graphId}: Purging all edges (count: {$existingEdgeCount['cnt'] ?? 0})");
        $db->execute("DELETE FROM routing_edge WHERE id_graph = ?", [$graphId], 'i');
    }
}
```

และต้องส่ง `confirmPurge` ผ่าน options ใน `dag_graph_api.php`:

```php
$result = $saveEngine->save($nodes, $edges, [
    'graphId' => $graphId,
    'isAutosave' => $isAutosave,
    'userId' => $userId,
    'ifMatch' => $ifMatch,
    'confirmPurge' => $_POST['confirm_purge'] ?? '0' // เพิ่มบรรทัดนี้
]);
```

---

## 2. Empty Node List Warning ⚠️ **หายไป**

### Original (`dag_routing_api_original.php` lines 2367-2382)

```php
} else {
    // No existing nodes in payload (only new nodes without id_node)
    // Check if there are existing nodes in database that should be deleted
    $existingNodeCount = $db->fetchOne("SELECT COUNT(*) as cnt FROM routing_node WHERE id_graph = ?", [$graphId], 'i');
    $hasExistingNodes = ($existingNodeCount['cnt'] ?? 0) > 0;
    if ($hasExistingNodes) {
        // Warn but don't block (prevent data loss)
        $structureWarnings[] = sprintf(
            'Warning: Empty node list detected (existing: %d nodes). All nodes will be removed.',
            $existingNodeCount['cnt']
        );
        error_log("Graph {$graphId}: Purging all nodes (count: {$existingNodeCount['cnt']})");
    }
    // Delete all nodes if none in list (edges will be cascade deleted automatically)
    $db->execute("DELETE FROM routing_node WHERE id_graph = ?", [$graphId], 'i');
}
```

### New Implementation (`GraphSaveEngine.php` lines 260-263)

```php
} else {
    // Delete all nodes if none in list
    $db->execute("DELETE FROM routing_node WHERE id_graph = ?", [$graphId], 'i');
}
```

### ผลกระทบ

- **Warning message หายไป** → User อาจไม่รู้ว่ากำลังลบ nodes ทั้งหมด
- **Audit log message หายไป** → ทำให้ debug ยากขึ้น

### แนะนำการแก้ไข

เพิ่ม warning logic กลับเข้าไป:

```php
} else {
    // No existing nodes in payload (only new nodes without id_node)
    // Check if there are existing nodes in database that should be deleted
    $existingNodeCount = $db->fetchOne("SELECT COUNT(*) as cnt FROM routing_node WHERE id_graph = ?", [$graphId], 'i');
    $hasExistingNodes = ($existingNodeCount['cnt'] ?? 0) > 0;
    if ($hasExistingNodes) {
        // Warn but don't block (prevent data loss)
        $structureWarnings[] = sprintf(
            'Warning: Empty node list detected (existing: %d nodes). All nodes will be removed.',
            $existingNodeCount['cnt']
        );
        error_log("Graph {$graphId}: Purging all nodes (count: {$existingNodeCount['cnt']})");
    }
    // Delete all nodes if none in list (edges will be cascade deleted automatically)
    $db->execute("DELETE FROM routing_node WHERE id_graph = ?", [$graphId], 'i');
}
```

---

## 3. Breaking Changes Detection ⚠️ **หายไป (แต่ดูเหมือนไม่ได้ถูกใช้)**

### Original (`dag_routing_api_original.php` lines 3586-3590)

```php
// Phase 5.8.4: Add breaking changes info if detected
if (isset($signatureCheck) && $signatureCheck['has_breaking_change']) {
    $response['has_breaking_changes'] = true;
    $response['breaking_changes'] = $signatureCheck['breaking_changes'];
}
```

### New Implementation

**ไม่มี logic นี้** - ไม่มี `signatureCheck` ใน `GraphSaveEngine`

### ผลกระทบ

- **Breaking changes detection ไม่ทำงาน** - แต่จากการตรวจสอบ original code ไม่พบว่า `$signatureCheck` ถูก define ที่ไหนใน `graph_save` case → น่าจะเป็น code ที่เตรียมไว้แต่ยังไม่ได้ implement จริง
- **ไม่ส่งผลต่อ production** แต่ถ้า frontend คาดหวัง field นี้จะไม่มี

---

## 4. ✅ Logic ที่ถูก migrate ครบถ้วน

### 4.1 Validation Logic ✅

| Item | Original | New | Status |
|------|----------|-----|--------|
| Request validation | ✅ `RequestValidator::make()` | ✅ `RequestValidator::make()` | ✅ ตรงกัน |
| JSON decode | ✅ `JsonNormalizer::safeJsonEncode()` | ✅ `JsonNormalizer::safeJsonEncode()` | ✅ ตรงกัน |
| Graph validation | ✅ `GraphValidationEngine::validate()` | ✅ `GraphValidationEngine::validate()` | ✅ ตรงกัน |
| Node code validation | ✅ `validateNodeCodes()` | ✅ `\validateNodeCodes()` | ✅ ตรงกัน |
| Autosave validation mode | ✅ `mode: 'draft'` for autosave | ✅ `mode: 'draft'` for autosave | ✅ ตรงกัน |
| Strict validation | ✅ `strict_graph_validation` flag | ✅ `strict_graph_validation` flag | ✅ ตรงกัน |
| isOldGraph detection | ✅ `db_fetch_one()` then check `published_at`/`created_at` | ✅ Use `findById()` result (มี `published_at`/`created_at` อยู่แล้ว) | ✅ ตรงกัน |

### 4.2 Transaction Handling ✅

| Item | Original | New | Status |
|------|----------|-----|--------|
| Begin transaction | ✅ `$db->beginTransaction()` | ✅ `$db->beginTransaction()` | ✅ ตรงกัน |
| Commit | ✅ `$db->commit()` | ✅ `$db->commit()` | ✅ ตรงกัน |
| Rollback on error | ✅ `$db->rollback()` in catch | ✅ `$db->rollback()` in catch | ✅ ตรงกัน |
| Transaction boundary | ✅ ทั้ง save operation | ✅ ทั้ง save operation | ✅ ตรงกัน |

### 4.3 Autosave vs Manual Save ✅

| Item | Original | New | Status |
|------|----------|-----|--------|
| Autosave detection | ✅ `save_type === 'autosave'` | ✅ `save_type === 'autosave'` OR legacy (no nodes/edges) | ✅ ดีกว่าเดิม (รองรับ legacy) |
| Autosave node update | ✅ Only `position_x`, `position_y`, `node_name` | ✅ Only `position_x`, `position_y`, `node_name` | ✅ ตรงกัน |
| Autosave skip edges | ✅ Skip edge operations | ✅ Skip edge operations | ✅ ตรงกัน |
| Autosave skip sequence | ✅ Skip `recalculateNodeSequence()` | ✅ Skip `recalculateNodeSequence()` | ✅ ตรงกัน |
| Autosave merge logic | ❌ ไม่มี (validate กับ partial data) | ✅ **มี** (merge กับ existing nodes จาก DB) | ✅ **ดีกว่าเดิม** |

### 4.4 Node/Edge Operations ✅

| Item | Original | New | Status |
|------|----------|-----|--------|
| Node normalization | ✅ Full logic (node_type mapping, JSON fields) | ✅ Full logic (delegated to `saveNodesManual()`) | ✅ ตรงกัน |
| QC Policy normalization | ✅ Complex logic (lines 2616-2704) | ✅ Complex logic (lines 709-770) | ✅ ตรงกัน |
| Node INSERT | ✅ Full fields + error handling | ✅ Full fields + error handling | ✅ ตรงกัน |
| Node UPDATE | ✅ Full fields | ✅ Full fields | ✅ ตรงกัน |
| Edge INSERT/UPDATE | ✅ Full fields | ✅ Full fields | ✅ ตรงกัน |
| Node code duplicate check | ✅ Double-check before insert | ✅ Double-check before insert | ✅ ตรงกัน |

### 4.5 ETag/Optimistic Locking ✅

| Item | Original | New | Status |
|------|----------|-----|--------|
| ETag calculation | ✅ `md5($graphId . '|' . $row_version)` | ✅ `md5($graphId . '|' . $row_version)` | ✅ ตรงกัน |
| If-Match parsing | ✅ Complex regex cleanup | ✅ Complex regex cleanup | ✅ ตรงกัน |
| Version conflict check | ✅ Check before transaction | ✅ Check before transaction | ✅ ตรงกัน |
| Row version increment | ✅ Atomic `UPDATE ... WHERE row_version = ?` | ✅ Atomic `UPDATE ... WHERE row_version = ?` | ✅ ตรงกัน |
| Conflict detection | ✅ Check `affected !== 1` | ✅ Check `affected !== 1` | ✅ ตรงกัน |

### 4.6 Subgraph Binding ✅

| Item | Original | New | Status |
|------|----------|-----|--------|
| Delete existing bindings | ✅ `DELETE FROM graph_subgraph_binding` | ✅ `DELETE FROM graph_subgraph_binding` | ✅ ตรงกัน |
| Detect subgraph nodes | ✅ Check `node_type === 'subgraph'` OR `original_node_type === 'subgraph'` | ✅ Check `node_type === 'subgraph'` OR `original_node_type === 'subgraph'` | ✅ ตรงกัน |
| Extract subgraph_ref | ✅ Support JSON field + legacy columns | ✅ Support JSON field + legacy columns | ✅ ตรงกัน |
| Validate subgraph exists | ✅ Check `routing_graph` | ✅ Check `routing_graph` | ✅ ตรงกัน |
| Validate version exists | ✅ Check `routing_graph_version` | ✅ Check `routing_graph_version` | ✅ ตรงกัน |
| Insert binding | ✅ `ON DUPLICATE KEY UPDATE` | ✅ `ON DUPLICATE KEY UPDATE` | ✅ ตรงกัน |

### 4.7 Audit Logging ✅

| Item | Original | New | Status |
|------|----------|-----|--------|
| Before state hash | ✅ Only for manual save | ✅ Only for manual save | ✅ ตรงกัน |
| After state hash | ✅ After commit | ✅ After commit | ✅ ตรงกัน |
| Changes summary | ✅ `nodes_added`, `edges_added`, etc. | ✅ `nodes_added`, `edges_added`, etc. | ✅ ตรงกัน |
| Audit log call | ✅ `logRoutingAudit()` | ✅ `\logRoutingAudit()` | ✅ ตรงกัน |

### 4.8 Error Handling ✅

| Item | Original | New | Status |
|------|----------|-----|--------|
| Error logging | ✅ Enhanced logging with trace | ✅ `\RuntimeException` (handled by API layer) | ✅ ดีกว่า (separation of concerns) |
| Error response format | ✅ Structured errors with `app_code` | ✅ Structured errors with `app_code` | ✅ ตรงกัน |
| Metrics tracking | ✅ `Metrics::increment()` for errors | ✅ API layer handles | ✅ ดีกว่า (separation) |

### 4.9 Response Format ✅

| Item | Original | New | Status |
|------|----------|-----|--------|
| Success message | ✅ `['message' => 'Graph saved successfully']` | ✅ `['message' => 'Graph saved successfully']` | ✅ ตรงกัน |
| Warnings | ✅ `$response['warnings']` | ✅ `$response['warnings']` | ✅ ตรงกัน |
| Subgraph warnings | ✅ `$response['subgraph_warning']`, `requires_new_version` | ✅ `$response['subgraph_warning']`, `requires_new_version` | ✅ ตรงกัน |
| ETag header | ✅ `setETagHeader($newEtag)` | ✅ `setETagHeader($result->etag)` | ✅ ตรงกัน |

---

## สรุปและคำแนะนำ

### Critical Issues (ต้องแก้ทันที)

1. **Purge Protection สำหรับ Edges หายไป**
   - **ความเสี่ยง:** Medium - User อาจลบ edges โดยไม่ตั้งใจ
   - **การแก้ไข:** เพิ่ม logic `confirm_purge` และ `protect_purge_edges` กลับเข้าไปใน `GraphSaveEngine::save()`
   - **Priority:** High

2. **Empty Node List Warning หายไป**
   - **ความเสี่ยง:** Low - ไม่ block save แต่ไม่มี warning
   - **การแก้ไข:** เพิ่ม warning message เมื่อ empty node list
   - **Priority:** Medium

### Non-Critical (optional)

3. **Breaking Changes Detection หายไป**
   - **ความเสี่ยง:** Low - ดูเหมือนยังไม่ได้ implement จริงใน original
   - **การแก้ไข:** ถ้า frontend ใช้ field นี้ ให้เพิ่ม logic กลับมา (แต่ต้อง implement `signatureCheck` logic ก่อน)
   - **Priority:** Low

### Positive Changes ✅

1. **Autosave Merge Logic เพิ่มเข้ามา** - ดีกว่าเดิม เพราะ validate กับ full graph แทน partial data
2. **Separation of Concerns** - Error handling และ metrics tracking ถูกย้ายไป API layer ตาม architecture
3. **Transaction Management** - ยังคงถูกต้อง ครอบคลุมทั้ง save operation

---

## Test Coverage

Golden Tests ครอบคลุม:
- ✅ New graph creation
- ✅ Node update
- ✅ Node deletion
- ✅ Version conflict
- ✅ Invalid structure
- ✅ Autosave positions

**สิ่งที่ควรเพิ่ม:**
- ⚠️ Test purge protection (empty edges with `confirm_purge`)
- ⚠️ Test empty node list warning

---

## Next Steps

1. **เพิ่ม Purge Protection Logic** กลับเข้าไปใน `GraphSaveEngine::save()`
2. **เพิ่ม Empty Node List Warning** กลับเข้าไป
3. **รัน Golden Tests อีกครั้ง** เพื่อยืนยันว่าไม่มี regression
4. **Manual QA** สำหรับ edge cases ที่เกี่ยวข้อง

---

## ✅ สถานะการแก้ไข (Status: COMPLETED - 2025-12-10)

### แก้ไขเสร็จสมบูรณ์

1. **✅ Purge Protection for Edges** (High Priority) - **FIXED**
   - เพิ่ม logic ตรวจสอบ `confirm_purge` และ `protect_purge_edges` feature flag
   - เพิ่ม warning message เมื่อจะ purge edges โดยไม่มีการยืนยัน
   - เพิ่ม error_log สำหรับ audit trail
   - **ไฟล์ที่แก้ไข**: `source/dag/Graph/Service/GraphSaveEngine.php` (lines 334-367)
   - **ไฟล์ที่แก้ไข**: `source/dag/dag_graph_api.php` (line 717-722) - เพิ่มการส่ง `confirmPurge` parameter

2. **✅ Empty Node List Warning** (Medium Priority) - **FIXED**
   - เพิ่ม logic ตรวจสอบว่ามี nodes เก่าในฐานข้อมูลหรือไม่เมื่อ payload ไม่มี nodes
   - เพิ่ม warning message เมื่อจะ purge nodes ทั้งหมด
   - เพิ่ม error_log สำหรับ audit trail
   - **ไฟล์ที่แก้ไข**: `source/dag/Graph/Service/GraphSaveEngine.php` (lines 261-276)

### รายละเอียดการแก้ไข

#### 1. Empty Node List Warning
```php
// เพิ่ม logic ใน GraphSaveEngine::save() ที่ lines 261-276
if (!empty($nodeIds)) {
    // ... delete nodes not in list ...
} else {
    // ตรวจสอบว่ามี nodes เก่าหรือไม่
    $existingNodeCount = $db->fetchOne("SELECT COUNT(*) as cnt FROM routing_node WHERE id_graph = ?", [$graphId], 'i');
    $hasExistingNodes = ($existingNodeCount['cnt'] ?? 0) > 0;
    if ($hasExistingNodes) {
        $structureWarnings[] = sprintf(
            'Warning: Empty node list detected (existing: %d nodes). All nodes will be removed.',
            $existingNodeCount['cnt']
        );
        error_log("Graph {$graphId}: Purging all nodes (count: {$existingNodeCount['cnt']})");
    }
    $db->execute("DELETE FROM routing_node WHERE id_graph = ?", [$graphId], 'i');
}
```

#### 2. Purge Protection for Edges
```php
// เพิ่ม logic ใน GraphSaveEngine::save() ที่ lines 334-367
$edgeIds = array_filter(array_column($edges, 'id_edge'));
$protectPurge = function_exists('getFeatureFlag') ? getFeatureFlag('protect_purge_edges', true) : true;
$existingEdgeCount = $db->fetchOne("SELECT COUNT(*) as cnt FROM routing_edge WHERE id_graph = ?", [$graphId], 'i');
$hasExistingEdges = ($existingEdgeCount['cnt'] ?? 0) > 0;

if (empty($edgeIds) && $hasExistingEdges && $protectPurge && !$confirmPurge) {
    $structureWarnings[] = sprintf(
        'Warning: Empty edge list detected (existing: %d edges). All edges will be removed. Use confirm_purge=1 to suppress this warning.',
        $existingEdgeCount['cnt']
    );
    error_log("Graph {$graphId}: Purging all edges without confirmation (count: {$existingEdgeCount['cnt']})");
}
```

#### 3. API Layer Update
```php
// เพิ่มการส่ง confirmPurge parameter ใน dag_graph_api.php
$confirmPurge = ($_POST['confirm_purge'] ?? '0') === '1';
$result = $saveEngine->save($nodes, $edges, [
    'graphId' => $graphId,
    'isAutosave' => $isAutosave,
    'userId' => $userId,
    'ifMatch' => $ifMatch,
    'confirmPurge' => $confirmPurge  // เพิ่มพารามิเตอร์นี้
]);
```

### การทดสอบที่แนะนำ

1. **Manual Test Case 1: Empty Node List**
   - สร้างกราฟที่มี nodes 2-3 ตัว
   - Save กราฟโดยส่ง nodes array ว่าง
   - **Expected**: ได้ warning message ว่า "Empty node list detected" และ nodes ถูกลบ

2. **Manual Test Case 2: Empty Edge List without Confirm**
   - สร้างกราฟที่มี edges 2-3 เส้น
   - Save กราฟโดยส่ง edges array ว่างโดยไม่ส่ง `confirm_purge=1`
   - **Expected**: ได้ warning message ว่า "Empty edge list detected" และ edges ถูกลบ

3. **Manual Test Case 3: Empty Edge List with Confirm**
   - สร้างกราฟที่มี edges 2-3 เส้น
   - Save กราฟโดยส่ง edges array ว่างพร้อม `confirm_purge=1`
   - **Expected**: ไม่มี warning และ edges ถูกลบ

### สรุป

ทั้ง 2 จุดที่หายไปจากโค้ดเดิมได้ถูกเพิ่มกลับมาแล้ว และมี behavior ตรงกับ `dag_routing_api_original.php` ครบถ้วน

**หมายเหตุ**: Logic นี้จะทำงานเฉพาะ manual save เท่านั้น (ไม่ทำงานกับ autosave) ซึ่งตรงกับ behavior เดิม

