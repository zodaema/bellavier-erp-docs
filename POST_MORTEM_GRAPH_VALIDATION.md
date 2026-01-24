# Post-Mortem: Graph Validation Architecture Issues

**วันที่:** 2025-12-12  
**สถานะ:** ✅ เอกสาร Post-mortem สำหรับ Agent/AI Context  
**วัตถุประสงค์:** ระบุปัญหาสถาปัตยกรรมตั้งแต่ต้นแบบ และแนวทางแก้ไข

---

## 🎯 Executive Summary

**ปัญหาหลัก:** Graph Validation System มีปัญหาตั้งแต่สถาปัตยกรรมเริ่มต้น (Original Design) ไม่ใช่จาก Refactoring

**ผลกระทบ:**
- Validation ผ่านทุกอย่างแม้กราฟผิด
- Autosave ลบ nodes/edges โดยไม่ตั้งใจ
- Draft/Publish state ไม่ isolate
- Graph structure ผิดถูกบันทึกได้

**สาเหตุรากฐาน:** 10 จุดผิดตั้งแต่ต้นแบบ (ดูรายละเอียดด้านล่าง)

---

## 📋 1. God Object API - ไฟล์เดียวทำทุกอย่าง

### ปัญหา

**Original File:** `dag_routing_api_original.php` (~7,794 บรรทัด)

**รับผิดชอบทั้งหมด:**
- Graph CRUD (create, read, update, delete)
- Node CRUD
- Edge CRUD
- Draft Management
- Publish/Versioning
- Validation (หลาย layers)
- Thumbnail Generation
- Favorite Management
- Audit Logging
- Graph List Pagination
- Runtime Support
- Version History
- ETag/Optimistic Locking
- Autosave
- Idempotency
- Permission Mapping
- Cross-domain DB Selector
- Schema Validation

### ผลกระทบ

1. **Spaghetti Side-Effects:**
   - Autosave ไปชน full validation
   - Draft logic ไปชน published logic
   - Node update ไปลบ edge โดยไม่ตั้งใจ

2. **Refactoring เป็นไปแทบไม่ได้:**
   - Logic ทับซ้อนกันมาก
   - Cross-dependencies ระหว่าง concerns
   - ไม่สามารถแยก service ได้ง่าย

### เปรียบเทียบ: Original vs Refactored

| Aspect | Original | Refactored |
|--------|----------|------------|
| **File Size** | ~7,794 lines | ~4,704 lines (main API) + Services |
| **Graph Save** | Inline in API | `GraphSaveEngine` + Sub-Engines |
| **Validation** | Multiple layers inline | `GraphValidationEngine` (single source) |
| **Draft** | Inline logic | `GraphDraftService` |
| **Autosave** | Mixed with save | `GraphAutosaveHandler` (separate) |

**✅ Refactored ดีขึ้น:** แยก services แต่ยังมี legacy code อยู่

---

## 📋 2. Validation Model ผิด - ไม่มี Single Source of Truth

### ปัญหา

**Original File มีหลาย Validation Layers:**

1. **Legacy `validateGraphStructure()`** (ถูกลบไปแล้ว)
2. **DAGValidationService** (ยังใช้ในบางจุด)
3. **GraphValidationEngine** (ใช้ในบาง action)
4. **Frontend Validation (JS)** (ไม่ sync กับ backend)

### ผลกระทบ

```php
// Original: บาง action ใช้ legacy
case 'graph_save_draft':
    // ใช้ GraphValidationEngine แต่ convert errors → warnings
    $validationResult = $validationEngine->validate(...);
    $structureWarnings = array_merge(
        $validationResult['errors'] ?? [], // Convert errors to warnings
        $validationResult['warnings'] ?? []
    );
    // Draft save never fails → กราฟผิดถูกบันทึกได้

case 'graph_save':
    // ใช้ GraphValidationEngine แต่บางครั้ง skip validation
    if ($isAutosave) {
        // Skip validation → กราฟผิดถูกบันทึกได้
    }

case 'graph_validate':
    // ใช้ GraphValidationEngine แต่ format response ผิด
    $finalValid = empty($errors) && ($validationResult['valid'] ?? true);
    // Bug: ถ้า errors ไม่ว่าง แต่ valid=true → ยังผ่าน
```

### เปรียบเทียบ: Original vs Refactored

| Aspect | Original | Refactored |
|--------|----------|------------|
| **Validation Engine** | Multiple (DAGValidationService + GraphValidationEngine) | Single (GraphValidationEngine) |
| **Draft Mode** | Convert errors → warnings | Convert errors → warnings (ยังคงอยู่) |
| **Autosave** | Skip validation | Separate handler (ดีขึ้น) |
| **Frontend Check** | เช็ค `validation.valid` อย่างเดียว | เช็ค `valid` + `error_count` + `errors` array |

**✅ Refactored ดีขึ้น:** ใช้ GraphValidationEngine เป็นหลัก แต่ยังมี logic ผิด

**❌ ยังมีปัญหา:**
- Frontend เช็ค `validation.valid` อย่างเดียว (แก้ไขแล้ว)
- Draft convert errors → warnings (ยังคงอยู่ - อาจถูกต้องสำหรับ draft)

---

## 📋 3. Node/Edge JSON Model ไม่ Normalize

### ปัญหา

**Original File พึ่งข้อมูล raw จาก DB:**

```php
// Original: ไม่ normalize
$node = db_fetch_one(...);
$nodeParams = $node['node_params']; // อาจเป็น JSON string, array, null, "0", invalid JSON

// ใช้โดยตรง → พัง
if ($nodeParams['key']) { ... } // Error: string ไม่มี key
```

### ผลกระทบ

1. **graph_save, graph_get, draft_save คาดหวัง structure ต่างกัน**
2. **validation engine พังเพราะ format ไม่แน่นอน**
3. **autosave ส่ง partial data → engine เข้าใจว่าต้องลบทิ้ง**

### เปรียบเทียบ: Original vs Refactored

| Aspect | Original | Refactored |
|--------|----------|------------|
| **JSON Normalization** | ไม่มี | `JsonNormalizer::safeJsonEncode()` (บางจุด) |
| **loadGraphWithVersion()** | ไม่ normalize | Normalize JSON fields (ดีขึ้น) |
| **Autosave Payload** | Raw JSON | Validate JSON array (ดีขึ้น) |

**✅ Refactored ดีขึ้น:** มี normalization บางจุด แต่ยังไม่ครอบคลุมทั้งหมด

---

## 📋 4. Autosave Logic ผิดตั้งแต่ต้น

### ปัญหา

**Original File Behavior:**

```php
// Original: autosave ไม่รู้จักตัวเอง
case 'graph_save':
    $isAutosave = isset($_POST['is_autosave']) && $_POST['is_autosave'] === 'true';
    
    if ($isAutosave) {
        // Skip validation → กราฟผิดถูกบันทึกได้
        // ไม่รู้ว่าควร ignore empty nodes/edges
        // Replace state ทั้งหมด → ลบ nodes/edges ที่ไม่อยู่ใน payload
    }
```

**ผลกระทบ:**

1. **Autosave มาพร้อม `nodes=""` หรือ `nodes=[]`**
   - Graph ถูกตีความว่า "ลบทิ้งหมด"
   - Validation error
   - Graph meta อัปเดตแต่ node/edge หาย

2. **Autosave ไม่มี mode ฟื้น graph เก่า**
   - Replace state ทั้งหมด
   - ไม่ merge กับ existing state

### เปรียบเทียบ: Original vs Refactored

| Aspect | Original | Refactored |
|--------|----------|------------|
| **Autosave Action** | Mixed with `graph_save` | Separate `graph_autosave_positions` |
| **Validation** | Skip validation | No validation (positions only) |
| **Payload** | Full graph state | Positions only (ดีขึ้น) |
| **State Management** | Replace all | Partial update (ดีขึ้น) |

**✅ Refactored ดีขึ้นมาก:** แยก autosave เป็น action เดียว รับเฉพาะ positions

**❌ ยังมีปัญหา:**
- ถ้า frontend ส่ง full graph state ใน autosave → ยังลบ nodes/edges ได้

---

## 📋 5. node_code ไม่ Enforce Uniqueness

### ปัญหา

**Original Design:**

```php
// Original: มี unique index แต่ logic API อนุญาต duplicate
CREATE UNIQUE INDEX idx_node_code ON routing_node(id_graph, node_code);

// แต่ API:
case 'graph_save':
    // ไม่ validate node_code uniqueness ก่อน save
    // อนุญาต duplicate จนกระทั่ง save final → DB error
```

### ผลกระทบ

1. **Duplicate node_code → edges ชี้ผิด → runtime แตก**
2. **Draft restore → graph ไม่แม็พกลับถูก**

### เปรียบเทียบ: Original vs Refactored

| Aspect | Original | Refactored |
|--------|----------|------------|
| **Uniqueness Check** | DB constraint only | `validateNodeCodes()` helper (ดีขึ้น) |
| **Before Save** | ไม่ check | Check in `GraphSaveEngine` (ดีขึ้น) |

**✅ Refactored ดีขึ้น:** มี validation ก่อน save

---

## 📋 6. Runtime Model ผูกกับ Token แต่ Graph Model ผูกกับ Node

### ปัญหา

**Original Design:**

```
Token Lifecycle = Job Runtime (instance)
Node Lifecycle = Graph Definition (template)
```

**แต่ Original API ไม่ได้แยก domain:**

```php
// Original: บางจุดเอา token logic มา validate graph
case 'graph_save':
    // ตรวจสอบ token state → ไม่ควรทำ
    // Graph = Design-time structure
    // Token = Runtime instance
```

### ผลกระทบ

- **Hatthasilpa / Classic Line แยกกันไม่ได้**
- **Graph validation ไปผูกกับ production detail**

### เปรียบเทียบ: Original vs Refactored

| Aspect | Original | Refactored |
|--------|----------|------------|
| **Domain Separation** | Mixed | ยังคง mixed (ยังไม่แยก) |
| **Graph Service** | Inline | `GraphSaveEngine` (ดีขึ้น) |
| **Runtime Service** | Inline | ยังคง inline (ยังไม่แยก) |

**⚠️ Refactored:** ยังไม่แยก domain ชัดเจน

---

## 📋 7. ไม่มี Transpiler ระหว่าง Graph JSON และ Database State

### ปัญหา

**Original Design:**

```
Graph Designer → JSON: {nodes: [...], edges: [...]}
Database → Tables: routing_node, routing_edge, routing_graph, ...
```

**Original API:**
- Save JSON → เขียน DB แบบ partial update
- ไม่ clean orphan nodes
- ไม่ sync missing edges
- ไม่ fix node_code collision
- ไม่ reorder sequence_no อย่างสมบูรณ์

### ผลกระทบ

- **Graph state ไม่ sync กับ DB**
- **Orphan nodes/edges ค้างใน DB**

### เปรียบเทียบ: Original vs Refactored

| Aspect | Original | Refactored |
|--------|----------|------------|
| **Diff Engine** | ไม่มี | `GraphNodeDiffEngine`, `GraphEdgeDiffEngine` (ดีขึ้น) |
| **Orphan Cleanup** | ไม่มี | มีใน `GraphSaveEngine` (ดีขึ้น) |
| **Sequence Recalc** | ไม่มี | `recalculateNodeSequence()` helper (ดีขึ้น) |

**✅ Refactored ดีขึ้นมาก:** มี diff engines และ cleanup logic

---

## 📋 8. ไม่มี Isolation ระหว่าง Draft, Autosave, Published

### ปัญหา

**Original File Behavior:**

```php
// Original: autosave → เขียนทับ draft
case 'graph_save_draft':
    // เขียน draft
case 'graph_autosave_positions':
    // เขียนทับ draft (ไม่ isolate)

// Original: draft save → อาจเขียนทับ published
case 'graph_save_draft':
    // ไม่ check published state
    // อาจเขียนทับ published version
```

### ผลกระทบ

1. **Graph ที่ publish แล้วถูก autosave ทับโดยไม่ตั้งใจ**
2. **Draft ไม่ match structure DB**
3. **Graph version history ไม่ถูกต้อง**

### เปรียบเทียบ: Original vs Refactored

| Aspect | Original | Refactored |
|--------|----------|------------|
| **Draft Service** | Inline | `GraphDraftService` (ดีขึ้น) |
| **Autosave Isolation** | ไม่มี | Separate action (ดีขึ้น) |
| **Published Isolation** | ไม่มี | Version service (ดีขึ้น) |

**✅ Refactored ดีขึ้น:** แยก services แต่ยังต้องตรวจสอบ isolation logic

---

## 📋 9. Graph Designer ไม่มี Built-in Constraints

### ปัญหา

**Original Validation ไม่มี Rules เหล่านี้:**

- START node = 1 เท่านั้น
- END node ≥ 1
- Node unreachable ห้าม
- Node floating position ห้าม
- Split/Join consistency
- Parallel merge quorum validation
- Subgraph ref existence
- Node behavior compatibility

**ผลกระทบ:**

- **Graph ผิดถูกบันทึกได้จริง**
- **Runtime crash แต่ graph_save มองว่า "valid"**

### เปรียบเทียบ: Original vs Refactored

| Aspect | Original | Refactored |
|--------|----------|------------|
| **Validation Rules** | Basic (START/END only) | Comprehensive (GraphValidationEngine) |
| **START/END Check** | มี | มี (ดีขึ้น) |
| **Edge Integrity** | ไม่มี | มี (ดีขึ้น) |
| **QC Routing** | ไม่มี | มี (ดีขึ้น) |
| **Join Requirements** | ไม่มี | มี (ดีขึ้น) |

**✅ Refactored ดีขึ้นมาก:** GraphValidationEngine มี rules ครบถ้วน

---

## 📋 10. Node Lifecycle เป็น Side-Effect ใน graph_save

### ปัญหา

**Original File:**

```php
// Original: graph_save → อัปเดต node
case 'graph_save':
    // อัปเดต node ที่อยู่ใน payload
    // ลบ node ที่ไม่อยู่ใน payload
    // ลบ edges ที่ไม่อยู่ใน payload
```

**ผลกระทบ:**

1. **Autosave ที่ส่ง node/edge ไม่ครบ → ลบของจริง**
2. **Frontend ส่ง partial Δ (delta) → backend ลบทั้ง graph**

### เปรียบเทียบ: Original vs Refactored

| Aspect | Original | Refactored |
|--------|----------|------------|
| **Diff Computation** | ไม่มี | `GraphNodeDiffEngine`, `GraphEdgeDiffEngine` (ดีขึ้น) |
| **Delete Logic** | ลบทุกอย่างที่ไม่อยู่ใน payload | ลบเฉพาะที่อยู่ใน diff (ดีขึ้น) |
| **Partial Update** | ไม่รองรับ | รองรับ (ดีขึ้น) |

**✅ Refactored ดีขึ้นมาก:** มี diff engines แยก create/update/delete

---

## 🎯 สรุป: Original vs Refactored

### ✅ สิ่งที่ Refactored ดีขึ้น

1. **แยก Services:** GraphSaveEngine, GraphDraftService, GraphVersionService
2. **Single Validation Engine:** GraphValidationEngine (แทนหลาย layers)
3. **Diff Engines:** GraphNodeDiffEngine, GraphEdgeDiffEngine
4. **Autosave Isolation:** แยก action `graph_autosave_positions`
5. **JSON Normalization:** มีบางจุด (ยังไม่ครบ)
6. **Node Code Validation:** มี `validateNodeCodes()` helper
7. **Orphan Cleanup:** มีใน GraphSaveEngine

### ❌ สิ่งที่ยังมีปัญหา

1. **Frontend Validation Logic:** เช็ค `validation.valid` อย่างเดียว (แก้ไขแล้ว)
2. **Draft Convert Errors → Warnings:** ยังคงอยู่ (อาจถูกต้องสำหรับ draft)
3. **Domain Separation:** ยังไม่แยก Graph/Runtime domain ชัดเจน
4. **JSON Normalization:** ยังไม่ครอบคลุมทั้งหมด

---

## 🔧 แนวทางแก้ไขที่แนะนำ

### Phase 1: Fix Immediate Issues (✅ ทำแล้ว)

1. ✅ **Fix Frontend Validation Logic**
   - เช็ค `valid` + `error_count` + `errors` array
   - ไม่เชื่อ `validation.valid` อย่างเดียว

2. ✅ **Remove Feature Flags**
   - ลบ feature flag checks ออกจาก validation
   - Validation ทำงานเสมอ

3. ✅ **Auto-Generate anchor_slot**
   - Component nodes มี `anchor_slot` อัตโนมัติ

### Phase 2: Service Separation (แนะนำ)

1. **แยก Graph Service:**
   ```
   GraphService (Design-time)
   ├── GraphCRUDService
   ├── GraphValidationService (wrapper)
   ├── GraphDraftService (existing)
   └── GraphVersionService (existing)
   
   RuntimeService (Runtime instance)
   ├── TokenService
   ├── JobService
   └── ExecutionService
   ```

2. **แยก API Endpoints:**
   ```
   dag_graph_api.php (Design-time)
   ├── graph_create
   ├── graph_save
   ├── graph_validate
   └── graph_draft_*
   
   dag_runtime_api.php (Runtime)
   ├── token_create
   ├── token_execute
   └── job_*
   ```

### Phase 3: Complete Normalization

1. **JSON Normalization Layer:**
   ```php
   class GraphDataNormalizer {
       public static function normalizeNode($node): array
       public static function normalizeEdge($edge): array
       public static function normalizeGraph($graph): array
   }
   ```

2. **Transpiler Layer:**
   ```php
   class GraphTranspiler {
       public function jsonToDb(array $json): DbState
       public function dbToJson(DbState $db): array
   }
   ```

### Phase 4: Complete Isolation

1. **Draft Isolation:**
   - Draft ไม่เขียนทับ published
   - Autosave ไม่เขียนทับ draft

2. **Version Isolation:**
   - Published version immutable
   - Version history complete

---

## 📝 Service Map หลังการแยก

### Design-Time Services

```
GraphService
├── GraphCRUDService
│   ├── create()
│   ├── read()
│   ├── update()
│   └── delete()
├── GraphValidationService
│   └── validate() → GraphValidationEngine
├── GraphDraftService (existing)
│   ├── saveDraft()
│   ├── loadDraft()
│   └── discardDraft()
└── GraphVersionService (existing)
    ├── publish()
    ├── getVersion()
    └── compareVersions()
```

### Runtime Services

```
RuntimeService
├── TokenService
│   ├── createToken()
│   ├── executeToken()
│   └── getTokenState()
├── JobService
│   ├── createJob()
│   ├── updateJob()
│   └── getJobStatus()
└── ExecutionService
    ├── startExecution()
    ├── pauseExecution()
    └── resumeExecution()
```

---

## 🎯 สรุปสำหรับ Agent/AI

### Key Takeaways

1. **ปัญหาตั้งแต่ต้นแบบ:** ไม่ใช่จาก Refactoring
2. **Refactored ดีขึ้น:** แต่ยังมี legacy issues
3. **ต้องแยก Services:** Design-time vs Runtime
4. **ต้อง Normalize:** JSON data structure
5. **ต้อง Isolate:** Draft/Autosave/Published

### Files to Check

1. **Original:** `dag_routing_api_original.php` (7,794 lines)
2. **Refactored:** `dag_routing_api.php` (4,704 lines) + Services
3. **Validation:** `GraphValidationEngine.php`
4. **Save:** `GraphSaveEngine.php`
5. **Frontend:** `graph_designer.js`

### Critical Fixes Applied

1. ✅ Frontend validation logic (เช็ค `error_count` + `errors` array)
2. ✅ Remove feature flags
3. ✅ Auto-generate anchor_slot
4. ✅ API response `finalValid` calculation

### Remaining Issues

1. ⚠️ Draft convert errors → warnings (อาจถูกต้อง)
2. ⚠️ Domain separation (Graph vs Runtime)
3. ⚠️ JSON normalization (ยังไม่ครบ)
4. ⚠️ Isolation logic (ต้องตรวจสอบ)

---

**เอกสารนี้ใช้สำหรับ Agent/AI Context เพื่อเข้าใจปัญหาตั้งแต่ต้นแบบและแนวทางแก้ไข**
