# Task 20.2.3 — Migrate DAG Routing & Graph Operations to TimeHelper (Official)

## 🎯 Objective
Refactor **all DAG Routing, Graph Operations, and related API layers** to use the **centralized TimeHelper** instead of:
- `strtotime()`
- `time()`
- `date()`
- hardcoded `"Y-m-d H:i:s"`
- SQL `NOW()`
- manually subtracting timestamps
- timezone-implicit comparisons

This task enforces **full system-wide timezone normalization** and prepares the routing layer for accurate SLA/ETA computation.

---

## ✅ Scope (Exact Files to Modify)

### 1. DAG Routing Core
- `source/BGERP/Service/DAGRoutingService.php`
- `source/BGERP/Service/DAGGraphService.php`
- `source/BGERP/Service/DAGNodeService.php`
- `source/BGERP/Service/DAGEdgeService.php`

### 2. DAG Token API
- `source/dag_routing_api.php`
- `source/dag_token_api.php` (read-only verification)
- `source/dag_graph_api.php`

### 3. Helper/Utility Layers
- `source/BGERP/Helper/DagHelper.php`
- `source/BGERP/Helper/GraphDataHelper.php`

### 4. DB Access Layers
- `source/BGERP/Repository/TokenRepository.php`
- `source/BGERP/Repository/GraphRepository.php`

---

## 📌 Required Transformations

### Replace the following patterns:

| Old | New |
|-----|------|
| `strtotime($x)` | `TimeHelper::parse($x)` |
| `time()` | `TimeHelper::now()` |
| `date('Y-m-d H:i:s')` | `TimeHelper::toMysql(TimeHelper::now())` |
| SQL `NOW()` | bind param → `TimeHelper::toMysql(TimeHelper::now())` |
| `$end - $start` | `TimeHelper::durationMs($start, $end)` |
| Comparing raw timestamps | Use `TimeHelper::parse()` before comparison |

---

## 🛠️ Migration Rules

1. **Never use PHP native time functions** inside DAG Routing after this task.
2. **All comparisons must be normalized via TimeHelper first** (consistent timezone).
3. **Do not modify DB schema** and **do not modify business logic flow**.
4. **Token ETA / Node ETA must call TimeHelper exclusively**.
5. **All services must `use BGERP\Helper\TimeHelper;` at the top**.

---

## ✔️ Output Requirements

### The AI Agent must:
- Update each file above.
- Apply replacements EXACTLY as specified.
- Add missing `use BGERP\Helper\TimeHelper;`
- Replace SQL `NOW()` properly via param binding.
- Ensure no behavioral changes except timezone normalization.
- Ensure no syntax errors.

---

## 🔒 Safety Guard
Before modifying each file, the agent must:
1. Scan for existing TimeHelper usage.
2. Confirm no duplicate imports.
3. Ensure no partial migrations that break consistency.

---

## 🧪 Acceptance Criteria
- All time-based operations in these files routed through TimeHelper.
- dag_routing_api.php returns consistent timestamps.
- Token lifecycle unaffected.
- All SuperDAG tests pass (45/45).
- No regressions in Graph Designer.
- No “mixed timezone” warnings appear.

---

## 🚀 Final Note
This task is **pure migration + normalization**, not refactoring.
Do NOT rewrite logic.
Do NOT optimize.
Do NOT restructure.

Apply ONLY the modifications described above.

