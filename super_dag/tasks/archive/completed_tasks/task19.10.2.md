

# Task 19.10.2 — Integrate SemanticIntentEngine → AutoFixEngine v3

**Status:** IMPLEMENTATION TASK  
**Depends on:**
- SemanticIntentEngine.php (from Task 19.10.1)
- GraphAutoFixEngine.php (v2/v3 skeleton)
- semantic_intent_rules.md
- autofix_risk_scoring.md
- task19.10.md (AutoFix v3 master spec)

---
## 1. Objective

เชื่อมผลลัพธ์จาก `SemanticIntentEngine::analyzeIntent()` เข้ากับ AutoFixEngine v3 ให้สามารถ:

1. ปรับระดับความเสี่ยงของแต่ละ fix โดยใช้ `risk_base` + evidence
2. เปิด/ปิดการ apply ของแต่ละ fix แบบ dynamic ตาม policy
3. Suggest-only vs Auto-Apply ตาม risk band (Low/Medium/High/Critical)
4. เพิ่มคุณสมบัติ AutoFix ใหม่แบบ “Intent-aware”

หลัง Task นี้ AutoFixEngine จะ:
- อ่าน intent ทั้งหมด
- ใช้ risk scoring ตัดสินว่าจะเสนอ fix แบบไหน
- ให้ UI แสดง Risk Badge ต่อรายการ
- ป้องกันการ apply fix ที่เสี่ยงสูงเกินไป

---
## 2. Scope

### In-Scope
- Patch `GraphAutoFixEngine.php`
- Implement Intent-Aware Fix Selection
- Implement Risk Scoring ใช้ intent-based risk
- Create new fix types (v3) เช่น:
  - `FIX_QC_TWOWAY_TO_DEFAULT_REWORK`
  - `FIX_REMOVE_UNREACHABLE_ORPHAN`
  - `FIX_ADD_ELSE_ROUTE`
  - `FIX_ENSURE_TRUE_END`
- Integrate intent metadata เข้า Operation Rule
- Update `dag_routing_api.php` → graph_autofix action
- Update UI → graph_designer.js ให้แสดง risk score ของแต่ละ fix

### Out-of-Scope
- ไม่แก้ Validation Engine (เป็นงานของ Task 19.11)
- ไม่สร้าง UI ใหม่ (ใช้ panel เดิมใน 19.10)
- ไม่แก้หรือ restructure การ apply fix (Task 19.12)

---
## 3. Backend Integration (GraphAutoFixEngine.php)

### 3.1 Add Intent Loading

ใน `GraphAutoFixEngine::suggestFixes()` ให้เพิ่ม:

```php
$intentEngine = new SemanticIntentEngine();
$intentResult = $intentEngine->analyzeIntent($nodes, $edges);
$intents = $intentResult['intents'] ?? [];
```

เก็บเป็น `$this->intents` สำหรับใช้งานใน rule ทั้งหมด

---
### 3.2 Intent Lookup Helper

เพิ่ม method:

```php
private function findIntent(string $type, ?int $nodeId = null): ?array
{
    foreach ($this->intents as $intent) {
        if ($intent['type'] === $type) {
            if ($nodeId === null || ($intent['node_id'] ?? null) === $nodeId) {
                return $intent;
            }
        }
    }
    return null;
}
```

ใช้ lookup intent เฉพาะ node ได้

---
## 4. Intent-Aware Fix Rules

### 4.1 QC Fixes

#### Case A: qc.two_way
หากมี QC node ที่ intent = `qc.two_way`:
- ควรเสนอ fix: `FIX_QC_TWOWAY_TO_DEFAULT_REWORK`
- Risk base = intent.risk_base
- Evidence = intent.evidence

ตัวอย่างการสร้าง fix:
```php
$fixes[] = [
  'fix_type' => 'FIX_QC_TWOWAY_TO_DEFAULT_REWORK',
  'node_id'  => $nodeId,
  'risk'     => $intent['risk_base'],
  'description' => 'Convert QC two-way routing into Pass→Next / Else→Rework.',
  'operations' => [
        ['action' => 'set_edge_as_else', 'edge_id' => $edgeId],
  ],
  'evidence' => $intent['evidence'],
];
```

#### Case B: qc.pass_only
เสนอ fix แบบ suggest-only → add default rework
- Set `apply_mode` = `suggest_only`

#### Case C: qc.three_way
- ไม่ auto-fix default (risk สูง → disabled)

---
### 4.2 Parallel / Multi-Exit Fixes

#### Intent: operation.multi_exit
เสนอ fix:
- `FIX_ADD_ELSE_ROUTE`
- Risk = 30–45

#### Intent: parallel.semantic_split
- เสี่ยงสูง → suggest-only

#### Intent: parallel.true_split
- ไม่เสนอ fixใด ๆ → ถูกต้องอยู่แล้ว

---
### 4.3 Endpoint Fixes

#### Intent: endpoint.missing
เสนอ fix: `FIX_ENSURE_TRUE_END`
- สร้าง END node
- ต่อเส้นจาก terminal node
- Risk = 10

#### Intent: endpoint.unintentional_multi
เสนอ fix:
- Merge ENDs (suggest-only, risk=60)

---
### 4.4 Reachability Fixes

#### Intent: unreachable.unintentional
เสนอ fix: `FIX_REMOVE_UNREACHABLE_ORPHAN`
- action: `remove_node`
- apply_mode = `suggest_only`
- risk = 65

#### Intent: unreachable.intentional_subflow
- ไม่ทำอะไร

---
## 5. Risk Integration

ให้ AutoFixEngine ทำ risk score จริงโดย:

```
fix.final_risk = fix.risk_base
                + (intent.confidence_penalty)
                + size_penalty
                + edge_complexity_penalty
```

> หมายเหตุ  
> ไม่คำนวณใน SemanticIntentEngine → ทำเฉพาะใน AutoFixEngine เท่านั้น

---
## 6. API Integration (dag_routing_api.php)

แก้ graph_autofix action:
- เรียก AutoFixEngine v3 (intent-aware)
- Response:
```json
{
  "ok": true,
  "fixes": [
     {
        "fix_type": "FIX_QC_TWOWAY_TO_DEFAULT_REWORK",
        "risk": 20,
        "apply_mode": "auto" | "suggest_only" | "disabled",
        "node_id": 123,
        "description": "...",
        "operations": [...],
        "evidence": {...}
     }
  ]
}
```

---
## 7. UI Integration (graph_designer.js)

- For each fix, display:
  - Risk Badge (Low / Medium / High / Critical)
  - Evidence (tooltips)
  - Apply checkbox (only if apply_mode != disabled)

- Auto-disable items with:
  - risk ≥ 55
  - apply_mode = disabled

---
## 8. Acceptance Criteria

- [ ] AutoFixEngine โหลด intents จาก SemanticIntentEngine ได้
- [ ] Fix rules ทั้งหมดใช้ intent.risk_base + evidence
- [ ] Fix ที่เสี่ยงสูงเป็น suggest-only หรือ disabled
- [ ] graph_autofix API return risk score + evidence
- [ ] UI แสดง risk badge ต่อ fix
- [ ] Full backward compatible
- [ ] task19_10_2_results.md ถูกสร้างและสรุปงาน