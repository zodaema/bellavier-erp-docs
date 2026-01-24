# 🎯 Graph Versioning Refactor Plan: Published-as-Immutable Snapshot + Binding-by-VersionId

**วันที่สร้าง:** 2025-12-14  
**สถานะ:** Draft - Awaiting Approval  
**ความสำคัญ:** P0 - Critical for Production Safety

---

## 📋 Executive Summary

ปัญหาหลักที่พบ: ระบบ Graph Versioning ปัจจุบันใช้ semantics ของ `version=latest` ที่คลุมเครือ ทำให้เกิด "กราฟผี" (Ghost Graph) ที่แก้กันมาสองวันแล้วยังไม่จบ

**Root Cause:**
- `version=latest` มีความหมายไม่ชัดเจน (อาจเป็น draft หรือ published)
- Product Binding ใช้ `graph_version_pin` (VARCHAR) แทน `graph_version_id` (INT) ทำให้ไม่ deterministic
- Backend มี fallback logic ที่ทำให้ "เดา" version ผิด
- UI auto-switch version selector ตาม response ทำให้เกิด infinite loop

**Solution:**
เปลี่ยนเป็นโมเดล "Published-as-Immutable Snapshot" + "Binding-by-VersionId" ที่ตัดความคลุมเครือไปที่ราก

---

## 🔍 Current State Audit

### 1. API Semantics ปัจจุบัน

#### `dag_graph_api.php` - `graph_get` action

**ปัญหาที่พบ:**
```php
$version = $data['version'] ?? 'latest'; // Default to 'latest'

// Task 28.8: Handle 'draft' version (load active draft)
if ($version === 'draft') {
    $version = 'latest'; // Will load draft if exists
}
```

**ปัญหา:**
- `version=latest` มีความหมายไม่ชัดเจน
- `version=draft` ถูกแปลงเป็น `latest` แล้ว backend "เดา" ว่าจะโหลด draft หรือ published
- ไม่มี deterministic contract

#### `GraphService::getGraph()`

**ปัญหาที่พบ:**
```php
public function getGraph(int $graphId, string $version = 'latest'): ?array
{
    // ...
    if ($version === 'latest' || $version === 'draft') {
        // Check if draft exists
        $hasActiveDraft = $this->metadataRepo->hasActiveDraft($graphId);
        if ($hasActiveDraft) {
            // Load draft
        } else {
            // Load published
        }
    }
}
```

**ปัญหา:**
- `latest` และ `draft` ถูก treat เหมือนกัน
- Backend "เดา" ว่าจะโหลดอะไรจาก `hasActiveDraft`
- ไม่มี explicit contract

#### `loadGraphWithVersion()` in `_helpers.php`

**ปัญหาที่พบ:**
```php
if ($version === 'latest') {
    // Check for active draft first
    $draftStmt = $tenantDb->prepare("SELECT ... FROM routing_graph_draft ...");
    if ($draftData) {
        // Load from draft payload
    } else {
        // Fallback to main table
    }
}
```

**ปัญหา:**
- Fallback logic ทำให้ "เดา" version ผิด
- ไม่มี error เมื่อ request draft แต่ไม่มี draft

---

### 2. Product Binding Schema ปัจจุบัน

#### `product_graph_binding` table

**Schema ปัจจุบัน:**
```sql
CREATE TABLE product_graph_binding (
    id_binding INT PRIMARY KEY AUTO_INCREMENT,
    id_product INT NOT NULL,
    id_graph INT NOT NULL,
    graph_version_pin VARCHAR(10) DEFAULT NULL COMMENT 'Pinned graph version (NULL = use latest published)',
    -- ...
);
```

**ปัญหา:**
- ใช้ `graph_version_pin` (VARCHAR) แทน `graph_version_id` (INT)
- `NULL` = "use latest published" แต่ "latest" ไม่ชัดเจน
- ไม่มี FK constraint ไป `routing_graph_version.id_version`
- ไม่มี immutable guarantee

#### `ProductGraphBindingHelper::getActiveBinding()`

**ปัญหาที่พบ:**
```php
public static function getActiveBinding(\mysqli $db, int $productId, ?string $mode = null): ?array
{
    // Returns binding with graph_version_pin (VARCHAR)
    // No validation that version exists
    // No guarantee that version is published (not draft)
}
```

**ปัญหา:**
- ไม่ validate ว่า `graph_version_pin` ยังมีอยู่
- ไม่ guarantee ว่า version เป็น published (อาจเป็น draft)
- ไม่มี immutable guarantee

#### `GraphVersionResolver::resolveGraphForProduct()`

**ปัญหาที่พบ:**
```php
$versionPin = $pinVersion ?? $binding['graph_version_pin'] ?? null;

if ($versionPin !== null && $versionPin !== '') {
    // Resolve to pinned published version
    $stmt = $tenantDb->prepare("SELECT ... FROM routing_graph_version WHERE version = ?");
    // ...
} else {
    // Auto-resolve to latest published version
    // ...
}
```

**ปัญหา:**
- ใช้ `version` string แทน `id_version` ทำให้ไม่ deterministic
- Auto-resolve "latest" อาจได้ version ผิด
- ไม่มี immutable guarantee

---

### 3. Frontend State Management ปัจจุบัน

#### `graph_designer.js` - Version Selector

**ปัญหาที่พบ:**
- Version selector auto-switch ตาม response ทำให้เกิด infinite loop
- `version=latest` ถูกส่งไป backend แล้ว backend "เดา" ว่าจะโหลดอะไร
- Delayed change events จาก browser/plugins ทำให้เกิด "กราฟผี"

**แก้ไขแล้ว (แต่ยังไม่พอ):**
- เพิ่ม `withVersionSelectorSync()` guard
- เพิ่ม hard squelch window (800ms)
- เพิ่ม numeric fallback matching

**แต่ยังเหลือ:**
- UI ยัง auto-switch version selector ตาม response
- ไม่มี deterministic contract กับ backend

---

### 4. Database Schema ปัจจุบัน

#### `routing_graph_version` table

**Schema ปัจจุบัน:**
```sql
CREATE TABLE routing_graph_version (
    id_version INT PRIMARY KEY AUTO_INCREMENT,
    id_graph INT NOT NULL,
    version VARCHAR(20) NOT NULL,
    payload_json LONGTEXT NOT NULL,
    metadata_json TEXT,
    published_at DATETIME,
    published_by INT,
    status VARCHAR(20) DEFAULT 'published',
    allow_new_jobs TINYINT(1) DEFAULT 1,
    config_json TEXT,
    -- ...
);
```

**ปัญหา:**
- ไม่มี `content_hash` สำหรับ integrity check
- ไม่มี immutable constraint (อาจถูก update/delete)
- `status` อาจเป็น 'draft' (ควรแยก draft ออกไป)

#### `routing_graph` table

**Schema ปัจจุบัน:**
```sql
CREATE TABLE routing_graph (
    id_graph INT PRIMARY KEY AUTO_INCREMENT,
    -- ...
    version VARCHAR(20),
    status VARCHAR(20),
    published_at DATETIME,
    published_by INT,
    -- ...
);
```

**ปัญหา:**
- ไม่มี `published_version_id` pointer ที่ชัดเจน
- `version` field อาจไม่ sync กับ `routing_graph_version`
- ไม่มี immutable guarantee

---

## 🎯 Target Architecture: Published-as-Immutable Snapshot

### Core Principles (Invariants)

1. **Published = Immutable** (ห้ามเปลี่ยนย้อนหลัง)
2. **Draft = Working copy** (เปลี่ยนได้)
3. **Product Binding ต้องชี้ไปที่ Published Version ID ที่แน่นอน** (ไม่ใช่ latest, ไม่ใช่ graph_id ลอยๆ)
4. **Backend ห้าม "เดา" เวอร์ชันจากคำว่า latest** (latest เป็น UX concept ไม่ใช่ storage truth)
5. **ทุก critical path ต้องใช้ `id_version` (INT) เท่านั้น** (version string เป็น display label เท่านั้น)
6. **`routing_graph_version` ห้ามมี status='draft'** (draft อยู่ใน `routing_graph_draft` เท่านั้น)

---

## 📐 Refactor Plan (Prioritized by ROI)

### Phase 1: Lock Product Binding (P0 - Immediate Risk Reduction)

**เป้าหมาย:** ป้องกันระบบอื่น (runtime, job creation, execution) พังทันที

**งานที่ต้องทำ:**

#### 1.1 เพิ่ม `graph_version_id` column ใน `product_graph_binding`

**Migration:**
```php
// database/tenant_migrations/2025_12_product_binding_version_id.php
migration_add_column_if_missing(
    $db,
    'product_graph_binding',
    'graph_version_id',
    '`graph_version_id` INT NULL COMMENT \'FK to routing_graph_version.id_version (NULL = use published_current pointer)\' AFTER `graph_version_pin`'
);

// Add FK constraint
migration_add_foreign_key_if_missing(
    $db,
    'product_graph_binding',
    'fk_binding_version',
    'FOREIGN KEY (`graph_version_id`) REFERENCES `routing_graph_version` (`id_version`) ON DELETE RESTRICT'
);

// Add index
migration_add_index_if_missing(
    $db,
    'product_graph_binding',
    'idx_version_id',
    'INDEX `idx_version_id` (`graph_version_id`)'
);
```

#### 1.2 Migrate existing bindings

**Migration:**
```php
// Migrate graph_version_pin → graph_version_id
$bindings = $db->query("
    SELECT id_binding, id_graph, graph_version_pin 
    FROM product_graph_binding 
    WHERE graph_version_pin IS NOT NULL
");

while ($binding = $bindings->fetch_assoc()) {
    $versionId = null;
    
    if ($binding['graph_version_pin']) {
        $stmt = $db->prepare("
            SELECT id_version 
            FROM routing_graph_version 
            WHERE id_graph = ? AND version = ? AND published_at IS NOT NULL
            LIMIT 1
        ");
        $stmt->bind_param('is', $binding['id_graph'], $binding['graph_version_pin']);
        $stmt->execute();
        $result = $stmt->get_result();
        $version = $result->fetch_assoc();
        $stmt->close();
        
        if ($version) {
            $versionId = $version['id_version'];
        }
    }
    
    if ($versionId) {
        $updateStmt = $db->prepare("
            UPDATE product_graph_binding 
            SET graph_version_id = ? 
            WHERE id_binding = ?
        ");
        $updateStmt->bind_param('ii', $versionId, $binding['id_binding']);
        $updateStmt->execute();
        $updateStmt->close();
    }
}
```

#### 1.3 Update `ProductGraphBindingHelper`

**Changes:**
```php
// source/BGERP/Helper/ProductGraphBindingHelper.php

public static function getActiveBinding(\mysqli $db, int $productId, ?string $mode = null): ?array
{
    $sql = "
        SELECT 
            pgb.*,
            rgv.id_version AS bound_version_id,
            rgv.version AS bound_version_string,
            rgv.published_at AS bound_version_published_at,
            rg.code AS graph_code,
            rg.name AS graph_name,
            rg.status AS graph_status
        FROM product_graph_binding pgb
        JOIN routing_graph rg ON rg.id_graph = pgb.id_graph
        LEFT JOIN routing_graph_version rgv ON rgv.id_version = pgb.graph_version_id
        WHERE pgb.id_product = ?
            AND pgb.is_active = 1
            AND (pgb.effective_from <= NOW() OR pgb.effective_from IS NULL)
            AND (pgb.effective_until IS NULL OR pgb.effective_until >= NOW())
    ";
    // ...
}
```

#### 1.4 Update `GraphVersionResolver`

**Changes:**
```php
// source/dag/Graph/Service/GraphVersionResolver.php

public function resolveGraphForProduct(int $productId, ?string $pinVersion = null): array
{
    $binding = \BGERP\Helper\ProductGraphBindingHelper::getActiveBinding($tenantDb, $productId);
    if (!$binding) {
        throw new \RuntimeException("No active graph binding found for product {$productId}");
    }
    
    // P0 FIX: Use graph_version_id (deterministic) instead of graph_version_pin (ambiguous)
    $versionId = $binding['graph_version_id'] ?? null;
    
    if ($versionId) {
        // Load specific published version by ID (immutable guarantee)
        $stmt = $tenantDb->prepare("
            SELECT * FROM routing_graph_version 
            WHERE id_version = ? AND published_at IS NOT NULL
        ");
        $stmt->bind_param('i', $versionId);
        // ...
    } else {
        // Use published_current pointer (see Phase 2)
        $versionId = $this->getPublishedCurrentVersionId($binding['id_graph']);
        // ...
    }
    
    // CRITICAL: Verify version is published (BELLAVIER-GRADE: reject any non-published)
    // Note: routing_graph_version should NOT have status='draft' (draft is in routing_graph_draft)
    // But we check published_at as final guard
    if (!$versionRecord['published_at']) {
        throw new \RuntimeException("Only published versions can be used for product binding");
    }
}
```

**Estimated Time:** 4-6 hours  
**Risk Level:** Low (backward compatible)  
**ROI:** Very High (ป้องกันระบบอื่นพังทันที)

---

### Phase 2: Eliminate "latest" Semantics (P0 - Core Fix)

**เป้าหมาย:** ยกเลิก semantics ของ `latest` ใน backend (latest เป็น UX concept ไม่ใช่ storage truth)

**งานที่ต้องทำ:**

#### 2.1 เพิ่ม `published_version_id` pointer ใน `routing_graph`

**Migration:**
```php
// database/tenant_migrations/2025_12_routing_graph_published_pointer.php
migration_add_column_if_missing(
    $db,
    'routing_graph',
    'published_version_id',
    '`published_version_id` INT NULL COMMENT \'FK to routing_graph_version.id_version (current published version pointer)\' AFTER `version`'
);

// Add FK constraint
migration_add_foreign_key_if_missing(
    $db,
    'routing_graph',
    'fk_graph_published_version',
    'FOREIGN KEY (`published_version_id`) REFERENCES `routing_graph_version` (`id_version`) ON DELETE RESTRICT'
);

// Add index
migration_add_index_if_missing(
    $db,
    'routing_graph',
    'idx_published_version',
    'INDEX `idx_published_version` (`published_version_id`)'
);
```

#### 2.2 Migrate existing published versions

**CRITICAL: ใช้ id_version เท่านั้น (ไม่ rely กับ version string)**

**Migration:**
```php
// Set published_version_id for all published graphs
// BELLAVIER-GRADE: Use id_version only (not version string) for deterministic migration

$graphs = $db->query("
    SELECT id_graph 
    FROM routing_graph 
    WHERE status = 'published'
");

while ($graph = $graphs->fetch_assoc()) {
    $graphId = (int)$graph['id_graph'];
    
    // Find latest published version by published_at DESC (deterministic)
    // Do NOT use routing_graph.version string - it's only a display label
    $stmt = $db->prepare("
        SELECT id_version 
        FROM routing_graph_version 
        WHERE id_graph = ? 
            AND published_at IS NOT NULL
            AND (status IS NULL OR status = 'published' OR status = 'retired')
        ORDER BY published_at DESC
        LIMIT 1
    ");
    $stmt->bind_param('i', $graphId);
    $stmt->execute();
    $result = $stmt->get_result();
    $version = $result->fetch_assoc();
    $stmt->close();
    
    if ($version) {
        $versionId = (int)$version['id_version'];
        
        // Set pointer using id_version only
        $updateStmt = $db->prepare("
            UPDATE routing_graph 
            SET published_version_id = ? 
            WHERE id_graph = ?
        ");
        $updateStmt->bind_param('ii', $versionId, $graphId);
        $updateStmt->execute();
        $updateStmt->close();
        
        // Update version string (display label) to match
        $versionStrStmt = $db->prepare("
            SELECT version FROM routing_graph_version WHERE id_version = ?
        ");
        $versionStrStmt->bind_param('i', $versionId);
        $versionStrStmt->execute();
        $versionStrResult = $versionStrStmt->get_result();
        $versionRow = $versionStrResult->fetch_assoc();
        $versionStrStmt->close();
        
        if ($versionRow) {
            $updateVersionStrStmt = $db->prepare("
                UPDATE routing_graph 
                SET version = ? 
                WHERE id_graph = ?
            ");
            $updateVersionStrStmt->bind_param('si', $versionRow['version'], $graphId);
            $updateVersionStrStmt->execute();
            $updateVersionStrStmt->close();
        }
    }
}
```

**Rationale:** 
- `version` string เป็น display label เท่านั้น ไม่ใช่ source of truth
- ใช้ `published_at DESC` แทนการ match ด้วย version string
- Migration จะ deterministic แม้ version string ไม่ sync

#### 2.3 Update API Contract

**New API Contract (Deterministic):**

```
GET graph?graph_id=1957&ref=draft
→ Returns: Draft if exists, 404 draft_not_found if not exists (NO fallback)

GET graph?graph_id=1957&ref=published&version_id=123
→ Returns: Published snapshot with id_version=123 (deterministic)

GET graph?graph_id=1957&ref=published&label=current
→ Returns: Published snapshot from published_version_id pointer (deterministic)
```

**Response Format:**
```json
{
    "ok": true,
    "graph": { ... },
    "nodes": [ ... ],
    "edges": [ ... ],
    "metadata": {
        "resolved_ref": "published",
        "resolved_version_id": 123,
        "version_string": "2.0",
        "is_published_current": true,
        "deprecated_param_used": false
    }
}
```

#### 2.3.1 Legacy Compatibility Shim (Temporary)

**BELLAVIER-GRADE: Compat shim สำหรับ legacy `version=latest`**

เพื่อไม่ให้ breaking change ทันที ต้องมี compatibility layer:

**Changes in `dag_graph_api.php`:**
```php
case 'graph_get':
    $validation = RequestValidator::make($_GET, [
        'id' => 'required|integer|min:1',
        'ref' => 'nullable|string|in:draft,published', // NEW: explicit ref
        'version' => 'nullable|string|max:50', // LEGACY: deprecated, use ref instead
        'version_id' => 'nullable|integer|min:1', // NEW: specific version ID
        'label' => 'nullable|string|in:current' // NEW: label for published_current
    ]);
    
    $graphId = (int)$data['id'];
    $ref = $data['ref'] ?? null;
    $legacyVersion = $data['version'] ?? null;
    $versionId = $data['version_id'] ?? null;
    $label = $data['label'] ?? null;
    
    // LEGACY COMPAT: Map version=latest to ref=published&label=current
    $deprecatedParamUsed = false;
    if (!$ref && $legacyVersion) {
        $deprecatedParamUsed = true;
        
        // Log deprecation warning
        error_log(sprintf(
            "[DEPRECATED] graph_get API called with version=%s (graphId=%d). Use ref=published&label=current instead.",
            $legacyVersion,
            $graphId
        ));
        
        if ($legacyVersion === 'latest' || $legacyVersion === 'published') {
            // Map to published_current (NEVER to draft)
            $ref = 'published';
            $label = 'current';
        } elseif ($legacyVersion === 'draft') {
            $ref = 'draft';
        } else {
            // Try to find version_id from version string (one-time lookup)
            $stmt = $tenantDb->prepare("
                SELECT id_version 
                FROM routing_graph_version 
                WHERE id_graph = ? AND version = ? AND published_at IS NOT NULL
                LIMIT 1
            ");
            $stmt->bind_param('is', $graphId, $legacyVersion);
            $stmt->execute();
            $result = $stmt->get_result();
            $versionRow = $result->fetch_assoc();
            $stmt->close();
            
            if ($versionRow) {
                $ref = 'published';
                $versionId = (int)$versionRow['id_version'];
            } else {
                json_error('Version not found', 404, ['app_code' => 'DAG_ROUTING_404_VERSION']);
            }
        }
    }
    
    // Validate new API contract
    if (!$ref) {
        json_error('Invalid request: ref parameter required (draft or published)', 400);
    }
    
    if ($ref === 'draft') {
        // Load draft - NO fallback
        $result = $service->getDraft($graphId);
        if (!$result) {
            json_error('Draft not found', 404, ['app_code' => 'DAG_ROUTING_404_DRAFT']);
        }
        $resolvedRef = 'draft';
        $resolvedVersionId = null;
    } elseif ($ref === 'published') {
        if ($versionId) {
            // Load specific published version by ID
            $result = $service->getPublishedVersion($graphId, $versionId);
            if (!$result) {
                json_error('Published version not found', 404, ['app_code' => 'DAG_ROUTING_404_VERSION']);
            }
            $resolvedRef = 'published';
            $resolvedVersionId = $versionId;
        } elseif ($label === 'current') {
            // Load published_current from pointer
            $result = $service->getPublishedCurrent($graphId);
            if (!$result) {
                json_error('No published version available', 404, ['app_code' => 'DAG_ROUTING_404_NO_PUBLISHED']);
            }
            $resolvedRef = 'published';
            $resolvedVersionId = $result['metadata']['version_id'] ?? null;
        } else {
            json_error('Invalid request: published requires version_id or label=current', 400);
        }
    }
    
    // Add metadata to response
    $result['metadata'] = array_merge($result['metadata'] ?? [], [
        'resolved_ref' => $resolvedRef,
        'resolved_version_id' => $resolvedVersionId,
        'version_string' => $result['graph']['version'] ?? null,
        'is_published_current' => ($ref === 'published' && $label === 'current'),
        'deprecated_param_used' => $deprecatedParamUsed
    ]);
    
    json_success($result);
```

**Rationale:**
- Legacy `version=latest` ถูก map เป็น `ref=published&label=current` (ห้ามพาไป draft)
- Response มี metadata `deprecated_param_used=true` เพื่อให้ frontend log warning
- Frontend สามารถ migrate ไปใช้ new API contract อย่างค่อยเป็นค่อยไป

**Changes in `dag_graph_api.php`:**
```php
case 'graph_get':
    $validation = RequestValidator::make($_GET, [
        'id' => 'required|integer|min:1',
        'ref' => 'required|string|in:draft,published', // NEW: explicit ref
        'version_id' => 'nullable|integer|min:1', // NEW: specific version ID
        'label' => 'nullable|string|in:current' // NEW: label for published_current
    ]);
    
    $graphId = (int)$data['id'];
    $ref = $data['ref']; // 'draft' or 'published'
    $versionId = $data['version_id'] ?? null;
    $label = $data['label'] ?? null;
    
    if ($ref === 'draft') {
        // Load draft - NO fallback
        $result = $service->getDraft($graphId);
        if (!$result) {
            json_error('Draft not found', 404, ['app_code' => 'DAG_ROUTING_404_DRAFT']);
        }
    } elseif ($ref === 'published') {
        if ($versionId) {
            // Load specific published version by ID
            $result = $service->getPublishedVersion($graphId, $versionId);
        } elseif ($label === 'current') {
            // Load published_current from pointer
            $result = $service->getPublishedCurrent($graphId);
        } else {
            json_error('Invalid request: published requires version_id or label=current', 400);
        }
    }
```

**Changes in `GraphService.php`:**
```php
// NEW: Explicit methods (no ambiguity)
public function getDraft(int $graphId): ?array
{
    // Load draft - return null if not exists (NO fallback)
}

public function getPublishedVersion(int $graphId, int $versionId): ?array
{
    // Load specific published version by ID
}

public function getPublishedCurrent(int $graphId): ?array
{
    // Load from published_version_id pointer
}
```

#### 2.4 Update `GraphVersionService::publish()`

**Changes:**
```php
/**
 * Publish graph to immutable snapshot
 * 
 * @param int $graphId Graph ID
 * @param int $userId User ID
 * @param string|null $versionNote Optional version note
 * @param array $options Publish options:
 *   - discard_draft (bool): Discard existing draft after publish (default: true)
 *   - create_fresh_draft (bool): Create new draft from published (default: false)
 * @return array Published version info
 */
public function publish(int $graphId, int $userId, ?string $versionNote = null, array $options = []): array
{
    $tenantDb = $this->dbHelper->getTenantDb();
    
    // Start transaction
    $tenantDb->begin_transaction();
    
    try {
        // 1. Validate graph structure
        $this->validateGraphStructure($graphId);
        
        // 2. Create new version snapshot
        $versionId = $this->createVersionSnapshot($graphId, $userId, $versionNote);
        
        // 3. Update published_version_id pointer (atomic)
        $updateStmt = $tenantDb->prepare("
            UPDATE routing_graph 
            SET published_version_id = ?,
                status = 'published',
                version = (SELECT version FROM routing_graph_version WHERE id_version = ?),
                published_at = NOW(),
                published_by = ?,
                updated_at = NOW()
            WHERE id_graph = ?
        ");
        $updateStmt->bind_param('iiii', $versionId, $versionId, $userId, $graphId);
        $updateStmt->execute();
        $updateStmt->close();
        
        // 4. Publish policy: Discard old draft and optionally create new draft
        // BELLAVIER-GRADE: Make this configurable, not hardcoded
        $discardDraft = $options['discard_draft'] ?? true; // Default: discard old draft (safe)
        $createFreshDraft = $options['create_fresh_draft'] ?? false; // Default: don't auto-create new draft (user chooses)
        
        if ($discardDraft) {
            $this->discardDraft($graphId);
        }
        
        // Only create fresh draft if explicitly requested (editor UI can prompt user)
        // This allows for "publish and stay in published mode" workflow
        if ($createFreshDraft) {
            $this->createDraftFromPublished($graphId);
        }
        
        // 5. Write audit log
        $this->writeAuditLog($graphId, $versionId, $userId, 'publish');
        
        // Commit transaction
        $tenantDb->commit();
        
        return [
            'version_id' => $versionId,
            'version' => $this->getVersionString($versionId),
            'published_at' => date('Y-m-d H:i:s')
        ];
    } catch (\Exception $e) {
        $tenantDb->rollback();
        throw $e;
    }
}
```

**Estimated Time:** 8-12 hours  
**Risk Level:** Medium (breaking change - requires frontend update)  
**ROI:** Very High (แก้ root cause)

---

### Phase 3: Make Published Snapshot Immutable (P1 - Long-term Safety)

**เป้าหมาย:** Guarantee immutable published snapshots

**งานที่ต้องทำ:**

#### 3.1 Add `content_hash` to `routing_graph_version`

**Migration:**
```php
migration_add_column_if_missing(
    $db,
    'routing_graph_version',
    'content_hash',
    '`content_hash` VARCHAR(64) NOT NULL COMMENT \'SHA-256 hash of payload_json for integrity check\' AFTER `payload_json`'
);

migration_add_index_if_missing(
    $db,
    'routing_graph_version',
    'idx_content_hash',
    'INDEX `idx_content_hash` (`content_hash`)'
);
```

#### 3.2 Add Immutable Constraints (Application-level + DB-level with Escape Hatch)

**BELLAVIER-GRADE: Application-level immutability (P0) + DB trigger with controlled escape hatch**

**Migration:**

**Step 1: Application-level immutability (Primary Guard)**
```php
// source/dag/Graph/Service/GraphVersionService.php

/**
 * Check if version is immutable (published)
 */
private function isVersionImmutable(int $versionId): bool
{
    $tenantDb = $this->dbHelper->getTenantDb();
    $stmt = $tenantDb->prepare("
        SELECT published_at 
        FROM routing_graph_version 
        WHERE id_version = ?
    ");
    $stmt->bind_param('i', $versionId);
    $stmt->execute();
    $result = $stmt->get_result();
    $version = $result->fetch_assoc();
    $stmt->close();
    
    return !empty($version['published_at']);
}

/**
 * Update published version (BLOCKED by default)
 */
public function updatePublishedVersion(int $versionId, array $data): void
{
    if ($this->isVersionImmutable($versionId)) {
        throw new \RuntimeException(
            "Published versions are immutable. Use versioning system to create new versions."
        );
    }
    
    // Only allow update for non-published versions
    // ...
}
```

**Step 2: DB-level trigger with controlled escape hatch (Secondary Guard)**
```php
// BELLAVIER-GRADE: Trigger with escape hatch for admin/migration scenarios

// Create session variable for controlled bypass (only for admin scripts)
$db->query("
    CREATE TRIGGER prevent_published_version_update
    BEFORE UPDATE ON routing_graph_version
    FOR EACH ROW
    BEGIN
        -- Allow if escape hatch is enabled (for admin/migration only)
        IF @ALLOW_PUBLISHED_MUTATION = 1 THEN
            -- Log the mutation attempt for audit
            INSERT INTO system_audit_log 
            (action, table_name, record_id, message, created_at)
            VALUES 
            ('mutation_override', 'routing_graph_version', OLD.id_version, 
             CONCAT('Published version mutated with escape hatch: ', USER()), 
             NOW());
        ELSE
            -- Normal case: block mutation
            IF OLD.published_at IS NOT NULL THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Published versions are immutable. Use versioning system to create new versions. To override, set @ALLOW_PUBLISHED_MUTATION = 1 (admin only).';
            END IF;
        END IF;
    END
");

$db->query("
    CREATE TRIGGER prevent_published_version_delete
    BEFORE DELETE ON routing_graph_version
    FOR EACH ROW
    BEGIN
        -- Allow if escape hatch is enabled (for admin/migration only)
        IF @ALLOW_PUBLISHED_MUTATION = 1 THEN
            -- Log the deletion attempt for audit
            INSERT INTO system_audit_log 
            (action, table_name, record_id, message, created_at)
            VALUES 
            ('delete_override', 'routing_graph_version', OLD.id_version, 
             CONCAT('Published version deleted with escape hatch: ', USER()), 
             NOW());
        ELSE
            -- Normal case: block deletion
            IF OLD.published_at IS NOT NULL THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Published versions cannot be deleted. Use retirement system instead. To override, set @ALLOW_PUBLISHED_MUTATION = 1 (admin only).';
            END IF;
        END IF;
    END
");
```

**Usage of escape hatch (admin scripts only):**
```php
// Admin/migration script that needs to modify published version
$tenantDb->query("SET @ALLOW_PUBLISHED_MUTATION = 1");
try {
    // Perform mutation (metadata update, etc.)
    $tenantDb->query("UPDATE routing_graph_version SET ... WHERE id_version = ?");
} finally {
    // Always reset escape hatch
    $tenantDb->query("SET @ALLOW_PUBLISHED_MUTATION = 0");
}
```

**Rationale:**
- Application-level guard เป็น primary (เร็วกว่า trigger)
- DB trigger เป็น secondary guard (ป้องกัน direct SQL access)
- Escape hatch ช่วยรองรับ admin/migration ที่จำเป็นต้องแก้ metadata
- Audit log บันทึกทุก mutation ที่ใช้ escape hatch

#### 3.3 Update `GraphVersionService::publish()` to calculate hash

**BELLAVIER-GRADE: routing_graph_version ห้ามมี status='draft'**

**Changes:**
```php
private function createVersionSnapshot(int $graphId, int $userId, ?string $versionNote): int
{
    // ... create payload ...
    
    $payloadJson = json_encode($payload, JSON_UNESCAPED_UNICODE);
    $contentHash = hash('sha256', $payloadJson);
    
    // BELLAVIER-GRADE: routing_graph_version has status='published' or NULL only
    // Draft versions are in routing_graph_draft table only
    $stmt = $tenantDb->prepare("
        INSERT INTO routing_graph_version 
        (id_graph, version, payload_json, content_hash, metadata_json, published_at, published_by, status, allow_new_jobs, config_json)
        VALUES (?, ?, ?, ?, ?, NOW(), ?, 'published', ?, ?)
    ");
    // status = 'published' (never 'draft')
    // ...
}
```

**Add constraint to prevent draft status:**
```php
// Migration: Add CHECK constraint or application-level validation
// MySQL doesn't support CHECK constraints well, so enforce at application level

// In GraphVersionService::createVersionSnapshot()
if ($status && $status !== 'published' && $status !== 'retired') {
    throw new \InvalidArgumentException(
        "routing_graph_version.status must be 'published' or 'retired'. Draft versions belong in routing_graph_draft."
    );
}
```

**Estimated Time:** 4-6 hours  
**Risk Level:** Low (additive change)  
**ROI:** High (long-term safety)

---

### Phase 4: Clean UI to Remove Auto-switch (P1 - UX Fix)

**เป้าหมาย:** UI ไม่ auto-switch version selector ตาม response

**งานที่ต้องทำ:**

#### 4.1 Remove Auto-switch Logic

**Changes in `graph_designer.js`:**
```javascript
// REMOVE: Auto-switch version selector in handleGraphLoaded()
// UI should only update badge/status, NOT change selection

function handleGraphLoaded(graphData, etag, graphId, draftInfo, requestedVersion) {
    // ... normalize graphData ...
    
    // P0 FIX: Update badge/status only, DO NOT change selector
    const effectiveStatus = graphData.graph.status;
    updateVersionSelectorBadge(effectiveStatus); // NEW: Update badge only
    updateReadOnlyMode(effectiveStatus === 'published' || effectiveStatus === 'retired');
    
    // DO NOT call loadVersionsForSelector() or change selector programmatically
    // User must explicitly select version from dropdown
}
```

#### 4.2 Make Selector Deterministic

**Changes:**
```javascript
// Version selector should only change when user explicitly clicks
// No programmatic updates based on response

function handleVersionSelectorChange(e) {
    // ... existing guard logic ...
    
    // User explicitly selected version - load it
    const canonicalValue = $('#version-selector').val();
    const status = parseCanonical(canonicalValue);
    
    if (status === 'draft') {
        loadGraph(currentGraphId, 'draft', null, { ref: 'draft' });
    } else if (status === 'published') {
        const versionId = getVersionIdFromCanonical(canonicalValue);
        loadGraph(currentGraphId, versionId, null, { ref: 'published', version_id: versionId });
    }
}
```

**Estimated Time:** 2-4 hours  
**Risk Level:** Low (UX improvement)  
**ROI:** Medium (UX fix)

---

## 📊 Implementation Priority Matrix

| Phase | Priority | Risk | ROI | Estimated Time | Dependencies |
|-------|----------|------|-----|----------------|--------------|
| Phase 1: Lock Product Binding | P0 | Low | Very High | 4-6h | None |
| Phase 2: Eliminate "latest" | P0 | Medium | Very High | 8-12h | Phase 1 |
| Phase 3: Immutable Snapshots | P1 | Low | High | 4-6h | Phase 2 |
| Phase 4: Clean UI | P1 | Low | Medium | 2-4h | Phase 2 |

**Total Estimated Time:** 18-28 hours

---

## 🔒 Safety Measures

### 1. Database Constraints / Guards

- ✅ FK constraint: `product_graph_binding.graph_version_id` → `routing_graph_version.id_version`
- ✅ FK constraint: `routing_graph.published_version_id` → `routing_graph_version.id_version`
- ✅ Application-level immutability: Service layer rejects UPDATE/DELETE on published versions
- ✅ DB trigger with escape hatch: Secondary guard with controlled bypass for admin/migration
- ✅ Unique constraint: `routing_graph_draft` - one active draft per graph
- ✅ Status constraint: `routing_graph_version.status` must be 'published' or 'retired' (never 'draft')

### 2. Publish Transaction (Atomic)

```php
BEGIN TRANSACTION;
    -- 1. Validate
    -- 2. Create snapshot
    -- 3. Update pointer
    -- 4. Discard draft
    -- 5. Audit log
COMMIT;
```

### 3. Hash / ETag on Published Snapshot

- `content_hash` (SHA-256) for integrity check
- Runtime systems can verify hash to ensure correctness

### 4. "No fallback" Policy

- API: `ref=draft` → 404 if no draft (NO fallback)
- API: `ref=published&version_id=X` → 404 if version not found (NO fallback)
- API: `ref=published&label=current` → 404 if no published version (NO fallback)

---

## 🧪 Testing Strategy

### Unit Tests

1. **Product Binding Migration**
   - Test: Migrate `graph_version_pin` → `graph_version_id`
   - Test: Handle NULL `graph_version_pin` (use published_current)
   - Test: Handle invalid `graph_version_pin` (skip migration)

2. **API Contract**
   - Test: `ref=draft` returns 404 when no draft
   - Test: `ref=published&version_id=X` returns correct version
   - Test: `ref=published&label=current` returns published_current

3. **Immutable Guarantee**
   - Test: Cannot UPDATE published version (application-level guard)
   - Test: Cannot DELETE published version (application-level guard)
   - Test: DB trigger blocks UPDATE/DELETE on published versions
   - Test: Escape hatch (@ALLOW_PUBLISHED_MUTATION) allows admin mutations
   - Test: Escape hatch mutations are logged in audit log
   - Test: Content hash matches payload

4. **Status Constraints**
   - Test: `routing_graph_version.status` cannot be 'draft' (enforced at application level)
   - Test: Draft versions are only in `routing_graph_draft` table

### Integration Tests

1. **Product Binding Resolution**
   - Test: Resolve product with `graph_version_id`
   - Test: Resolve product with NULL `graph_version_id` (use published_current)
   - Test: Reject non-published versions in binding (published_at IS NULL)
   - Test: Product binding pinned version_id is missing → fail closed (no fallback)

2. **Publish Flow**
   - Test: Publish creates new version snapshot
   - Test: Publish updates `published_version_id` pointer
   - Test: Publish discards old draft (when discard_draft=true)
   - Test: Publish creates new draft from published (when create_fresh_draft=true)
   - Test: Publish does NOT create draft (when create_fresh_draft=false, default)

3. **Race Condition Tests (BELLAVIER-GRADE: Prevent "Ghost Graph")**
   
   **Test 1: Draft exists + user selects published snapshot**
   - Scenario: Active draft exists, user explicitly selects published snapshot
   - Expected: API returns published snapshot deterministically
   - Expected: UI shows published snapshot (read-only mode)
   - Expected: UI does NOT auto-swap back to draft
   - Expected: Response includes `resolved_ref='published'` and `resolved_version_id`
   
   **Test 2: Open graph while draft is created/discarded rapidly**
   - Scenario: User opens graph, draft is created, then discarded rapidly
   - Expected: API responds with `resolved_ref` and `resolved_version_id` clearly
   - Expected: Frontend renders according to "requested" (not auto-resolved)
   - Expected: No infinite loop or version switching
   
   **Test 3: Product binding pinned version_id is missing/retired**
   - Scenario: Product binding points to version_id that no longer exists
   - Expected: Resolution fails with clear error (fail closed)
   - Expected: NO fallback to "latest" or other version
   - Expected: Error message indicates binding needs update

---

## 📝 Migration Checklist

### Pre-Migration

- [ ] Backup database
- [ ] Review all code that uses `version=latest`
- [ ] Review all code that uses `graph_version_pin`
- [ ] Create rollback plan

### Phase 1: Lock Product Binding

- [ ] Create migration: `2025_12_product_binding_version_id.php`
- [ ] Add `graph_version_id` column
- [ ] Add FK constraint
- [ ] Migrate existing bindings
- [ ] Update `ProductGraphBindingHelper`
- [ ] Update `GraphVersionResolver`
- [ ] Test: Verify bindings work correctly
- [ ] Deploy to staging
- [ ] Verify in production

### Phase 2: Eliminate "latest"

- [ ] Create migration: `2025_12_routing_graph_published_pointer.php`
- [ ] Add `published_version_id` column
- [ ] Migrate existing published versions
- [ ] Update API contract (`dag_graph_api.php`)
- [ ] Update `GraphService` (new methods)
- [ ] Update `GraphVersionService::publish()`
- [ ] Update frontend (`graph_designer.js`, `GraphAPI.js`)
- [ ] Test: Verify API contract works
- [ ] Deploy to staging
- [ ] Verify in production

### Phase 3: Immutable Snapshots

- [ ] Create migration: `2025_12_version_content_hash.php`
- [ ] Add `content_hash` column
- [ ] Add triggers for immutable guarantee
- [ ] Update `GraphVersionService::publish()` to calculate hash
- [ ] Test: Verify immutable guarantee
- [ ] Deploy to staging
- [ ] Verify in production

### Phase 4: Clean UI

- [ ] Remove auto-switch logic from `handleGraphLoaded()`
- [ ] Make selector deterministic
- [ ] Test: Verify UI doesn't auto-switch
- [ ] Deploy to staging
- [ ] Verify in production

---

## 🚨 Rollback Plan

### Phase 1 Rollback

```sql
-- Remove graph_version_id column (if needed)
ALTER TABLE product_graph_binding DROP COLUMN graph_version_id;
```

### Phase 2 Rollback

```sql
-- Remove published_version_id column (if needed)
ALTER TABLE routing_graph DROP COLUMN published_version_id;
```

### Phase 3 Rollback

```sql
-- Remove content_hash column (if needed)
ALTER TABLE routing_graph_version DROP COLUMN content_hash;

-- Remove triggers
DROP TRIGGER IF EXISTS prevent_published_version_update;
DROP TRIGGER IF EXISTS prevent_published_version_delete;
```

---

## 📚 References

- [Graph Versioning Concepts](../../01-concepts/GRAPH_VERSIONING_AND_PRODUCT_BINDING.md)
- [Database Schema Reference](../../../developer/05-database/01-schema-reference.md)
- [API Structure Audit](../../../API_STRUCTURE_AUDIT.md)

---

**Status:** Ready for Review  
**Next Steps:** 
1. Review and approve plan
2. Start with Phase 1 (Lock Product Binding)
3. Test thoroughly before proceeding to Phase 2

