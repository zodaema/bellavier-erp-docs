# ✅ Graph Versioning Refactor - Verification Checklist

**วันที่สร้าง:** 2025-12-14  
**สถานะ:** Pre-Implementation Verification  
**เป้าหมาย:** ตรวจสอบว่าแผน refactor ครอบคลุมทุกจุดและจะจบแบบถาวร

---

## 🎯 Verification Checklist (Bellavier-grade)

**Last Updated:** 2025-12-14  
**Status:** Enhanced with Production-Grade Safety Measures

---

### 1. API Contract ต้อง Deterministic 100%

#### ✅ Checklist

- [ ] **ref=draft → ถ้าไม่มี draft ต้อง 404 draft_not_found (NO fallback)**
  - API: `GET graph?graph_id=1957&ref=draft`
  - Expected: 404 with `app_code: 'DAG_ROUTING_404_DRAFT'`
  - Verification: No fallback to published or main table
  
- [ ] **ref=published&version_id=X → ถ้าไม่เจอ ต้อง 404 version_not_found (NO fallback)**
  - API: `GET graph?graph_id=1957&ref=published&version_id=99999`
  - Expected: 404 with `app_code: 'DAG_ROUTING_404_VERSION'`
  - Verification: No fallback to latest or current
  
- [ ] **ref=published&label=current → ถ้า pointer ไม่มี ต้อง 404 no_published (NO fallback)**
  - API: `GET graph?graph_id=1957&ref=published&label=current`
  - Scenario: Graph has never been published
  - Expected: 404 with `app_code: 'DAG_ROUTING_404_NO_PUBLISHED'`
  - Verification: No fallback to draft
  
- [ ] **Response ต้องส่งกลับ requested_* และ resolved_* ให้ชัดเจน**
  - All successful responses must include:
    ```json
    {
        "metadata": {
            "requested_ref": "published" | "draft" | null,
            "requested_version_id": 123 | null,
            "requested_label": "current" | null,
            "resolved_ref": "published" | "draft",
            "resolved_version_id": 123 | null,
            "version_string": "2.0" | null,
            "is_published_current": true | false,
            "deprecated_param_used": false
        }
    }
    ```
  - **Policy:** Server must honor `requested_*` (no auto-resolve to draft except compat shim)
  - **Purpose:** Catch regressions where server "guesses" version incorrectly

**Implementation Status:**
- ✅ Documented in Section 2.3 (API Contract)
- ✅ Documented in Section 2.3.1 (Legacy Compatibility Shim)
- ⚠️ Requires implementation verification

---

### 1.5 No-fallback ต้องครอบทุก Endpoint ที่ใช้กราฟ

#### ✅ Checklist

- [ ] **ทุก endpoint ที่ resolve graph ต้อง fail closed**
  - Product resolver (`GraphVersionResolver::resolveGraphForProduct()`)
  - Runtime execution endpoints
  - Job creation endpoints
  - Verification: NO lookup "latest" string, NO fallback to draft
  
- [ ] **Error logging ต้องมี context ชัดเจน**
  - Log format: `graph_id={id} version_id={id} caller_context={endpoint_name} error={message}`
  - Verification: All graph resolution failures include full context
  
- [ ] **Binding resolution ต้อง reject missing/retired versions**
  - Error code: `DAG_BINDING_VERSION_RETIRED` for retired versions
  - Error code: `DAG_BINDING_VERSION_NOT_FOUND` for missing versions
  - Verification: NO silent fallback to latest/current

**Implementation Status:**
- ✅ Documented in Section 1.4 (Update GraphVersionResolver)
- ⚠️ Requires audit of all graph resolution endpoints
- ⚠️ Requires implementation verification

---

### 2. Compat Shim ต้อง "ฆ่า latest" แบบปลอดภัย

#### ✅ Checklist

- [ ] **Legacy version=latest ถูก map → ref=published&label=current เท่านั้น (ห้าม draft)**
  - API: `GET graph?graph_id=1957&version=latest`
  - Expected: Maps to `ref=published&label=current`
  - Verification: NEVER maps to draft, even if draft exists
  
- [ ] **Legacy version=draft → ref=draft**
  - API: `GET graph?graph_id=1957&version=draft`
  - Expected: Maps to `ref=draft`
  - Verification: Direct mapping, no conversion
  
- [ ] **ทุกครั้งที่ใช้ legacy ต้องมี deprecated_param_used=true + log เตือน**
  - Response must include: `deprecated_param_used: true`
  - Server log must include: `[DEPRECATED] graph_get API called with version=...`
  - Verification: Log format matches specification

**Implementation Status:**
- ✅ Documented in Section 2.3.1 (Legacy Compatibility Shim)
- ⚠️ Requires implementation verification

---

### 2.5 Access Control Invariants (Critical for Security)

#### ✅ Checklist

- [ ] **Draft APIs ตรวจ permission**
  - Who can read draft? (must be authenticated + authorized)
  - Who can discard draft? (must have edit permission)
  - Who can publish? (must have publish role/permission)
  - Verification: All draft operations check permissions
  
- [ ] **Published APIs: Read vs Mutation**
  - Published read: Public (or per-tenant policy)
  - Published mutation: BLOCKED (immutable by design)
  - Verification: No mutation endpoints for published versions (except admin escape hatch)
  
- [ ] **Publish endpoint ต้อง require role ชัด**
  - Permission check: `must_allow('dag.graph.publish')` or equivalent
  - Verification: Publish operation fails without proper permission

**Implementation Status:**
- ⚠️ Requires permission system integration
- ⚠️ Requires access control specification

---

### 3. Published Pointer ต้องเป็น Source-of-Truth จริง

#### ✅ Checklist

- [ ] **routing_graph.published_version_id มี FK + index**
  - FK: `FOREIGN KEY (published_version_id) REFERENCES routing_graph_version(id_version) ON DELETE RESTRICT`
  - Index: `INDEX idx_published_version (published_version_id)`
  - Verification: Migration creates both
  
- [ ] **Migration ตั้ง pointer ด้วย published_at DESC (ไม่ใช้ version string ตัดสิน)**
  - Migration code uses:
    ```sql
    SELECT id_version FROM routing_graph_version 
    WHERE id_graph = ? AND published_at IS NOT NULL
    ORDER BY published_at DESC LIMIT 1
    ```
  - Verification: NO WHERE clause filtering by version string
  
- [ ] **Product binding ที่ graph_version_id IS NULL → resolve ผ่าน pointer เท่านั้น**
  - `GraphVersionResolver::resolveGraphForProduct()` logic:
    - If `graph_version_id IS NULL` → use `published_version_id` from `routing_graph`
    - Verification: No fallback to "latest" string lookup

**Implementation Status:**
- ✅ Documented in Section 2.2 (Migrate existing published versions)
- ✅ Documented in Section 1.4 (Update GraphVersionResolver)
- ⚠️ Requires implementation verification

---

### 3.5 Retire Semantics ต้องชัด (Binding Fail Closed)

#### ✅ Checklist

- [ ] **Retired version "ยังคงอยู่" แต่ resolver reject**
  - Retired version: `retired_at IS NOT NULL` but row still exists
  - Resolver behavior: Reject retired versions (same as missing)
  - Verification: `GraphVersionResolver` checks `retired_at IS NULL`
  
- [ ] **Error code เฉพาะสำหรับ retired**
  - Error code: `DAG_BINDING_VERSION_RETIRED`
  - Error message: "Binding points to retired version. Please update product binding."
  - Verification: Retired version returns clear error (not 404)

**Implementation Status:**
- ✅ Documented in Test 3 (Product binding pin to missing version)
- ⚠️ Requires implementation verification

---

### 4. Binding ต้อง Pin ด้วย version_id เท่านั้น

#### ✅ Checklist

- [ ] **product_graph_binding.graph_version_id มี FK (ON DELETE RESTRICT)**
  - FK: `FOREIGN KEY (graph_version_id) REFERENCES routing_graph_version(id_version) ON DELETE RESTRICT`
  - Verification: Migration creates FK with RESTRICT (not CASCADE)
  
- [ ] **Resolver โหลดด้วย id_version ไม่ใช้ version VARCHAR แล้ว**
  - `GraphVersionResolver::resolveGraphForProduct()` uses:
    ```php
    SELECT * FROM routing_graph_version WHERE id_version = ?
    ```
  - Verification: NO WHERE clause using `version` VARCHAR field
  
- [ ] **Binding ต้อง reject ถ้า version ไม่ published (published_at IS NULL) — fail closed**
  - Check: `if (!$versionRecord['published_at']) { throw ... }`
  - Verification: Fail with clear error, no fallback to latest

**Implementation Status:**
- ✅ Documented in Section 1.1-1.4 (Phase 1: Lock Product Binding)
- ✅ Documented constraint in Section 1.4 (Update GraphVersionResolver)
- ⚠️ Requires implementation verification

---

### 4.5 Immutability: Field-level (Payload vs Metadata)

#### ✅ Checklist

- [ ] **Payload (nodes/edges) immutable 100%**
  - `payload_json`: NEVER update after publish
  - Verification: Application-level + DB trigger blocks payload updates
  
- [ ] **Metadata บาง field แก้ได้ (controlled)**
  - Allowed: `description`, `notes`, `tags` (if applicable)
  - Required: Audit log for metadata changes
  - Verification: Metadata updates logged with `changed_by`, `changed_at`
  
- [ ] **Escape hatch สำหรับ admin**
  - Admin can update metadata via escape hatch
  - Admin cannot update payload (even with escape hatch)
  - Verification: Escape hatch checks field type

**Implementation Status:**
- ⚠️ Requires field-level immutability implementation
- ⚠️ Requires metadata update audit log

---

### 5. routing_graph_version ต้องไม่มี draft โดย design

#### ✅ Checklist

- [ ] **Snapshot insert ระบุ status='published' หรือ retired เท่านั้น**
  - `GraphVersionService::createVersionSnapshot()` sets:
    ```php
    status = 'published' // never 'draft'
    ```
  - Verification: No code path that sets `status='draft'`
  
- [ ] **ไม่มี code path ใดที่ write status='draft' ลง version table อีก**
  - Audit all INSERT/UPDATE on `routing_graph_version`
  - Verification: All paths set `status='published'` or `'retired'` only
  - Draft versions only in `routing_graph_draft` table

**Implementation Status:**
- ✅ Documented in Section 3.3 (Update GraphVersionService::publish())
- ✅ Documented as Core Principle #6
- ⚠️ Requires code audit and implementation verification

---

### 5.5 Publish ต้อง Atomic + Idempotent

#### ✅ Checklist

- [ ] **Publish ทำใน transaction เดียว**
  - Transaction includes: create snapshot + update pointer + audit log
  - Verification: All-or-nothing (rollback on any failure)
  
- [ ] **Publish endpoint รองรับ idempotency key**
  - Request header: `Idempotency-Key: {uuid}`
  - Behavior: Same key = same result (no duplicate snapshot)
  - Verification: Idempotency key stored and checked
  
- [ ] **Concurrent publish: Lock/Compare-and-Swap**
  - Lock: `SELECT ... FOR UPDATE` on `routing_graph` row
  - Compare-and-swap: Verify `published_version_id` hasn't changed
  - Verification: Only one publish succeeds, others get clear error

**Implementation Status:**
- ✅ Documented in Section 2.4 (Publish Transaction)
- ⚠️ Requires idempotency key implementation
- ⚠️ Requires concurrent publish lock mechanism

---

### 6. Immutability ต้องมี Guard 2 ชั้น

#### ✅ Checklist

- [ ] **Application-level guard: update/delete published version = throw**
  - `GraphVersionService::updatePublishedVersion()` checks:
    ```php
    if ($this->isVersionImmutable($versionId)) {
        throw new RuntimeException("Published versions are immutable...");
    }
    ```
  - Verification: All update/delete methods check immutability
  
- [ ] **DB trigger (ถ้ามี) ต้องมี escape hatch + audit log**
  - Trigger checks: `@ALLOW_PUBLISHED_MUTATION = 1` (escape hatch)
  - Audit log: All mutations with escape hatch are logged
  - Verification: Escape hatch can be used by admin scripts
  - Verification: No mutation without audit log

**Implementation Status:**
- ✅ Documented in Section 3.2 (Add Immutable Constraints)
- ✅ Escape hatch mechanism documented
- ⚠️ Requires implementation verification

---

### 6.5 Cache/ETag Correctness

#### ✅ Checklist

- [ ] **Published snapshot ส่ง ETag = content_hash**
  - Response header: `ETag: "{content_hash}"`
  - Client can use `If-None-Match` for conditional requests
  - Verification: ETag matches `content_hash` column
  
- [ ] **Draft ห้าม cache**
  - Response header: `Cache-Control: no-store, no-cache, must-revalidate`
  - Verification: All draft responses include no-cache headers
  
- [ ] **Compat shim log เมื่อ request มี If-None-Match**
  - Log when legacy `version=latest` request includes `If-None-Match`
  - Helps track cache behavior with legacy API

**Implementation Status:**
- ⚠️ Requires ETag implementation for published versions
- ⚠️ Requires cache control headers for draft responses

---

### 7. UI ต้องไม่ Auto-switch Selector ตาม Response

#### ✅ Checklist

- [ ] **Selector เปลี่ยนเฉพาะ user action**
  - `handleVersionSelectorChange()` only fires on user click
  - Verification: No programmatic `.val()` or `.prop('selected')` that triggers change
  
- [ ] **Response update ได้แค่ badge/read-only mode ไม่ไป "set selected option" ให้ user เอง**
  - `handleGraphLoaded()` updates:
    - Badge/icon (via `updateVersionSelectorBadge()`)
    - Read-only mode (via `updateReadOnlyMode()`)
  - Verification: NO calls to `loadVersionsForSelector()` or selector manipulation in `handleGraphLoaded()`

**Implementation Status:**
- ✅ Documented in Section 4.1 (Remove Auto-switch Logic)
- ✅ Guard mechanisms documented (withVersionSelectorSync, hard squelch window)
- ⚠️ Requires implementation verification (already partially implemented)

---

### 7.5 Observability: Graph Resolution Trace ID

#### ✅ Checklist

- [ ] **ทุก response ใส่ trace_id**
  - Response header: `X-Graph-Trace-Id: {uuid}`
  - Response body: `metadata.trace_id` field
  - Verification: All graph API responses include trace ID
  
- [ ] **Log ทุก hop ด้วย trace_id**
  - Format: `[GRAPH_TRACE:{trace_id}] {operation} graph_id={id} version_id={id}`
  - Verification: All graph operations logged with trace ID
  
- [ ] **Metrics สำหรับ monitoring**
  - Count: `deprecated_param_used`
  - Count: `404_draft_not_found`
  - Count: `404_version_not_found`
  - Count: `binding_version_retired`
  - Verification: Metrics exported (Prometheus/StatsD/etc.)

**Implementation Status:**
- ⚠️ Requires trace ID generation and propagation
- ⚠️ Requires metrics collection

---

### 8. Migration Safety: Backfill + Verify

#### ✅ Checklist

- [ ] **Backfill published_version_id ครบทุก graph**
  - Migration finds all graphs with published versions
  - Sets `published_version_id` using `published_at DESC` (not version string)
  - Verification: All published graphs have non-null pointer
  
- [ ] **Verify step: Count mismatch detection**
  - Query: Count graphs with published versions but NULL pointer
  - Expected: 0 mismatches
  - Verification: Dry-run report shows mismatches before apply
  
- [ ] **Dry-run report (ก่อน apply)**
  - Lists all graphs that will be updated
  - Shows current state vs target state
  - Verification: Report reviewed before migration execution

**Implementation Status:**
- ✅ Documented in Section 2.2 (Migrate existing published versions)
- ⚠️ Requires dry-run and verification queries

---

## 🧪 Integration Tests (Ghost Graph Prevention)

### Test 1: Draft exists แต่ user เลือก published snapshot

**Objective:** ตรวจสอบว่าเมื่อมี draft แต่ user เลือก published → ได้ published แบบนิ่ง ไม่เด้งกลับ draft

**Setup:**
```php
// 1. Create graph with published version 2.0
$graphId = createGraphWithPublishedVersion('2.0');

// 2. Create active draft
createActiveDraft($graphId);

// 3. User explicitly selects published snapshot 2.0
```

**Test Steps:**
1. Frontend: User selects "Published v2.0" from version selector
2. Frontend: Sends `GET graph?graph_id={$graphId}&ref=published&version_id={$versionId}`
3. Backend: Returns published snapshot with `resolved_ref='published'`, `resolved_version_id={$versionId}`
4. Frontend: Renders published snapshot (read-only mode)
5. Frontend: Does NOT auto-switch selector back to draft

**Expected Results:**
- ✅ API returns published snapshot (NOT draft)
- ✅ Response includes `resolved_ref='published'` and `resolved_version_id`
- ✅ UI shows published snapshot in read-only mode
- ✅ Version selector remains on "Published v2.0" (does NOT auto-switch to draft)
- ✅ No infinite loop or version switching

**Assertions:**
```php
// Backend assertion
$this->assertEquals('published', $response['metadata']['resolved_ref']);
$this->assertEquals($publishedVersionId, $response['metadata']['resolved_version_id']);
$this->assertNotEquals('draft', $response['graph']['status']);

// Frontend assertion (browser console)
// Selector value should remain 'published:2.0'
// Should NOT see '[change handler] FIRED' after load
// Should NOT see GraphLoader loading 'draft'
```

---

### Test 2: Draft create/discard ระหว่างกำลัง load

**Objective:** ตรวจสอบว่า draft create/discard ระหว่าง load → ไม่เกิด loop และ response ชัดเจน

**Setup:**
```php
// 1. Create graph with published version
$graphId = createGraphWithPublishedVersion('2.0');

// 2. Start loading published version (async)
$loadPromise = loadGraph($graphId, { ref: 'published', label: 'current' });
```

**Test Steps:**
1. Frontend: Initiates load of published version (request sent)
2. Backend: Request processing...
3. **DURING LOAD:** Draft is created (simulate concurrent action)
4. Backend: Returns response with `resolved_ref='published'`, `resolved_version_id`, `deprecated_param_used=false`
5. Frontend: Renders published snapshot (read-only mode)

**Alternative Scenario:**
1. Frontend: Initiates load with active draft
2. **DURING LOAD:** Draft is discarded
3. Backend: Should still return draft if request was initiated when draft existed (or handle gracefully)
4. Frontend: Should not crash or loop

**Expected Results:**
- ✅ Response includes clear `resolved_ref` and `resolved_version_id`
- ✅ No infinite loop or version switching
- ✅ UI renders according to `resolved_ref` (not auto-resolved)
- ✅ No race condition errors

**Assertions:**
```php
// Backend assertion
$this->assertArrayHasKey('resolved_ref', $response['metadata']);
$this->assertArrayHasKey('resolved_version_id', $response['metadata']);
$this->assertArrayHasKey('requested_ref', $response['metadata']);
// Response should be deterministic based on request time, not current state

// Frontend assertion
// Should NOT see multiple GraphLoader calls
// Should NOT see version selector auto-switching
// Should see single render with correct status
```

---

### Test 4: Publish while draft exists + user selects published_current

**Objective:** ตรวจสอบว่า publish ระหว่างมี draft → published_current ไม่เปลี่ยน และ UI ไม่เด้งกลับ draft

**Setup:**
```php
// 1. Create graph with published version 2.0
$graphId = createGraphWithPublishedVersion('2.0');
$versionId2 = getPublishedVersionId($graphId, '2.0');

// 2. Create active draft
createActiveDraft($graphId);

// 3. Publish new version 3.0 (while draft exists)
publishVersion($graphId, '3.0');
$versionId3 = getPublishedVersionId($graphId, '3.0');
```

**Test Steps:**
1. Frontend: User selects "Published v3.0 (current)"
2. Frontend: Sends `GET graph?graph_id={$graphId}&ref=published&label=current`
3. Backend: Returns published version 3.0 (current)
4. Frontend: Renders published version 3.0 (read-only mode)

**Expected Results:**
- ✅ API returns published version 3.0 (NOT 2.0, NOT draft)
- ✅ Response includes `resolved_ref='published'`, `resolved_version_id={$versionId3}`, `is_published_current=true`
- ✅ UI shows published version 3.0 in read-only mode
- ✅ Version selector remains on "Published v3.0 (current)" (does NOT auto-switch to draft)

**Assertions:**
```php
// Backend assertion
$this->assertEquals('published', $response['metadata']['resolved_ref']);
$this->assertEquals($versionId3, $response['metadata']['resolved_version_id']);
$this->assertTrue($response['metadata']['is_published_current']);
$this->assertNotEquals($versionId2, $response['metadata']['resolved_version_id'], 'Should NOT return old version');
```

---

### Test 5: Discard draft ต้องไม่ทำให้ published pointer เปลี่ยน

**Objective:** ตรวจสอบว่า discard draft ไม่กระทบ published_version_id pointer

**Setup:**
```php
// 1. Create graph with published version
$graphId = createGraphWithPublishedVersion('2.0');
$versionId = getPublishedVersionId($graphId, '2.0');

// 2. Create active draft
createActiveDraft($graphId);

// 3. Record published_version_id before discard
$pointerBefore = getPublishedVersionId($graphId); // from routing_graph.published_version_id
```

**Test Steps:**
1. Backend: Discard draft
2. Backend: Check `routing_graph.published_version_id`

**Expected Results:**
- ✅ `published_version_id` unchanged after discard
- ✅ Published version still accessible via `ref=published&label=current`
- ✅ No side effects on published snapshot

**Assertions:**
```php
// Backend assertion
$pointerAfter = getPublishedVersionId($graphId);
$this->assertEquals($pointerBefore, $pointerAfter, 'Published pointer must not change after draft discard');
$this->assertEquals($versionId, $pointerAfter, 'Published pointer must still point to published version');
```

---

### Test 6: Concurrent publish (สองคนกด publish พร้อมกัน)

**Objective:** ตรวจสอบว่า concurrent publish ได้ 1 snapshot เป็น current, อีกอันได้สถานะ "not_current" หรือ reject พร้อม error code

**Setup:**
```php
// 1. Create graph with published version
$graphId = createGraphWithPublishedVersion('2.0');
```

**Test Steps:**
1. User A: Initiates publish (creates snapshot, updates pointer)
2. User B: Initiates publish concurrently (before User A completes)
3. Backend: Uses lock/compare-and-swap to ensure only one succeeds

**Expected Results:**
- ✅ One publish succeeds (becomes current)
- ✅ Other publish either:
  - Option A: Rejected with clear error (`DAG_PUBLISH_CONCURRENT_CONFLICT`)
  - Option B: Succeeds but marked as `is_current=false` (if allowing multiple versions)
- ✅ No duplicate `published_version_id` pointers
- ✅ Audit log shows both attempts

**Assertions:**
```php
// Backend assertion
$currentVersions = getPublishedVersions($graphId, is_current: true);
$this->assertCount(1, $currentVersions, 'Should have exactly one current published version');

// If both succeed (Option B):
$allVersions = getPublishedVersions($graphId);
$this->assertCount(2, $allVersions, 'Both publishes should create snapshots');
$currentCount = count(array_filter($allVersions, fn($v) => $v['is_current']));
$this->assertEquals(1, $currentCount, 'Only one should be marked current');

// If one rejected (Option A):
// Check error response contains DAG_PUBLISH_CONCURRENT_CONFLICT
```

---

### Test 3: Product binding pin ไป version_id ที่หาย/retired

**Objective:** ตรวจสอบว่า binding ชี้ไป version ที่ไม่มี → fail closed ไม่ fallback

**Setup:**
```php
// 1. Create product
$productId = createProduct();

// 2. Create graph with published version
$graphId = createGraphWithPublishedVersion('2.0');
$versionId = getPublishedVersionId($graphId, '2.0');

// 3. Create binding with version_id
createBinding($productId, $graphId, $versionId);

// 4. Delete or retire the version (simulate version gone)
deleteVersion($versionId); // or retireVersion($versionId);
```

**Test Steps:**
1. Runtime: Product requires routing graph
2. Resolver: Calls `GraphVersionResolver::resolveGraphForProduct($productId)`
3. Resolver: Attempts to load version by `version_id`
4. Resolver: Version not found or retired
5. Resolver: Throws exception (fail closed)

**Expected Results:**
- ✅ Resolver throws `RuntimeException` with clear message
- ✅ NO fallback to "latest" or current published version
- ✅ Error message indicates binding needs update
- ✅ Product operations fail gracefully with clear error

**Assertions:**
```php
// Resolver assertion
$this->expectException(RuntimeException::class);
$this->expectExceptionMessage('Version not found for product binding');

// Should NOT fallback to:
// - Latest published version
// - Current published version
// - Draft version

// Should fail with:
// "Binding points to version_id {$versionId} which no longer exists. Please update product binding."
```

---

## 📝 Implementation Verification Status

| Verification Item | Documented | Implementation Status | Test Status |
|------------------|------------|----------------------|-------------|
| 1. API Contract Deterministic | ✅ | ⚠️ Pending | ⚠️ Pending |
| 2. Compat Shim Safe | ✅ | ⚠️ Pending | ⚠️ Pending |
| 3. Published Pointer Source-of-Truth | ✅ | ⚠️ Pending | ⚠️ Pending |
| 4. Binding Pin by version_id | ✅ | ⚠️ Pending | ⚠️ Pending |
| 5. No draft in version table | ✅ | ⚠️ Pending | ⚠️ Pending |
| 6. Immutability Guard 2-layer | ✅ | ⚠️ Pending | ⚠️ Pending |
| 7. UI No Auto-switch | ✅ | ⚠️ Partial | ⚠️ Pending |
| 1.5. No-fallback all endpoints | ✅ | ⚠️ Pending | ⚠️ Pending |
| 2.5. Access Control Invariants | ✅ | ⚠️ Pending | ⚠️ Pending |
| 3.5. Retire Semantics | ✅ | ⚠️ Pending | ⚠️ Pending |
| 4.5. Field-level Immutability | ✅ | ⚠️ Pending | ⚠️ Pending |
| 5.5. Publish Atomic + Idempotent | ✅ | ⚠️ Pending | ⚠️ Pending |
| 6.5. Cache/ETag Correctness | ✅ | ⚠️ Pending | ⚠️ Pending |
| 7.5. Observability Trace ID | ✅ | ⚠️ Pending | ⚠️ Pending |
| 8. Migration Safety | ✅ | ⚠️ Pending | ⚠️ Pending |
| Test 1: Draft exists + select published | ✅ | ⚠️ Pending | ⚠️ Pending |
| Test 2: Draft create/discard during load | ✅ | ⚠️ Pending | ⚠️ Pending |
| Test 3: Binding pin to missing version | ✅ | ⚠️ Pending | ⚠️ Pending |
| Test 4: Publish while draft + select current | ✅ | ⚠️ Pending | ⚠️ Pending |
| Test 5: Discard draft doesn't change pointer | ✅ | ⚠️ Pending | ⚠️ Pending |
| Test 6: Concurrent publish | ✅ | ⚠️ Pending | ⚠️ Pending |

**Legend:**
- ✅ Complete
- ⚠️ Pending
- ❌ Missing

---

## 🎯 Next Steps

1. **Implement Phase 1: Lock Product Binding**
   - Verify all checklist items for Phase 1
   - Run Test 3 (Binding pin to missing version)

2. **Implement Phase 2: Eliminate "latest" Semantics**
   - Verify all checklist items for Phase 2
   - Run Test 1 (Draft exists + select published)
   - Run Test 2 (Draft create/discard during load)

3. **Update Verification Status**
   - Mark items as ✅ when implemented and tested
   - Document any deviations from plan

---

**Status:** Ready for Implementation  
**Last Updated:** 2025-12-14

