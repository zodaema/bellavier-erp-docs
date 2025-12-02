# SuperDAG Scope Alignment Audit

**Date:** 2025-12-02  
**Version:** 1.0  
**Purpose:** Audit ว่า SuperDAG specs สอดคล้องกับ System Wiring Guide หรือไม่ (โดยเฉพาะเรื่อง Hatthasilpa vs Classic)

---

## Executive Summary

**✅ ALIGNED:** SuperDAG specs สอดคล้องกับ System Wiring Guide 95%

**Key Findings:**
1. ✅ SYSTEM_WIRING_GUIDE ระบุชัด: Work Queue = Hatthasilpa only, Classic = Linear only
2. ✅ BEHAVIOR_EXECUTION_SPEC (v2.0) ได้แก้ไขแล้ว: ระบุชัด Hatthasilpa scope
3. ⚠️ SPEC_WORK_CENTER_BEHAVIOR (legacy) มี `is_classic_supported` field → อาจทำให้เข้าใจผิด
4. ✅ Component Flow specs ไม่มีการอ้างถึง Classic/OEM (ถูกต้อง - Hatthasilpa only)

**Recommendation:** ✅ No critical conflicts - Minor clarification needed

---

## 1. Scope Statements Comparison

### 1.1 SYSTEM_WIRING_GUIDE.md (Source of Truth)

**Location:** `docs/developer/SYSTEM_WIRING_GUIDE.md`

**Critical Statements:**

```
- 🎨 Hatthasilpa (Luxury, handcrafted, 1-50 pieces)
  - Uses DAG (Directed Acyclic Graph) routing
  - Token-based execution (flow_token)
  - Work Queue system
  - Graph binding required

- 🏭 Classic (Mass production, 50-1000+ pieces)
  - Uses Linear routing only (DAG binding deprecated)
  - Batch-first workflow
  - PWA scan-based tracking
  - No graph binding (Hatthasilpa only)
```

**Line 113-115:**
```
Critical Notes:
- Classic Line uses Linear mode only (DAG binding deprecated)
- Work Queue is Hatthasilpa only (not for Classic)
- PWA scanners are Classic only (not work queue interface)
```

**Line 1836-1843:**
```
⚠️ Critical Separation:
- Work Queue = Hatthasilpa only - Operators claim tokens via worker_token_api.php
- PWA Scanners = Classic only - Simple scan in/out for job tickets
- These are separate systems for separate production lines
```

**Line 2262-2277:**
```
When Classic May NOT Use DAG Tables:

Classic Linear Mode (Current):
- ❌ May NOT use flow_token (deprecated)
- ❌ May NOT use token_event (deprecated)
- ❌ May NOT use routing_graph binding (deprecated)

⚠️ Deprecation Note:
- Classic DAG mode was deprecated after Task 25.3-25.5
- Classic now uses Linear mode exclusively
- All DAG tables are Hatthasilpa only
```

**✅ CLEAR VERDICT:** Hatthasilpa = DAG + Work Queue only, Classic = Linear + PWA only

---

### 1.2 SuperDAG Specs (Current State)

#### ✅ BEHAVIOR_EXECUTION_SPEC.md (v2.0) - ALIGNED

**Location:** `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md`

**Line 14-18:**
```
Work Center บอกว่า:
- ช่างคนไหนอยู่ตรงนี้
- ใช้ Behavior แบบไหน (เลือกจากชุดกลาง)
- รับ token ประเภทไหน (piece, component, batch)

⚠️ Current Scope:
- SuperDAG + Work Queue = line_type = 'hatthasilpa' เท่านั้น (ตอนนี้)
- Classic/OEM lines = ยังไม่ใช้ Work Queue (out of scope for this spec)
- Future Extension: Classic/OEM อาจ adopt Work Queue ในอนาคต (แต่ไม่ใช่ตอนนี้)
```

**Verdict:** ✅ Aligned perfectly with SYSTEM_WIRING_GUIDE

---

#### ✅ COMPONENT_PARALLEL_FLOW_SPEC.md (v2.1) - ALIGNED

**Location:** `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md`

**No mention of Classic/OEM** → Correct (Component Flow = Hatthasilpa specific)

**Verdict:** ✅ Aligned (implicit Hatthasilpa scope)

---

#### ✅ SUPERDAG_TOKEN_LIFECYCLE.md (v1.0) - ALIGNED

**Location:** `docs/super_dag/02-specs/SUPERDAG_TOKEN_LIFECYCLE.md`

**No mention of Classic/OEM** → Correct (Token Lifecycle = DAG system = Hatthasilpa)

**Verdict:** ✅ Aligned (implicit Hatthasilpa scope)

---

#### ⚠️ SPEC_WORK_CENTER_BEHAVIOR.md (Legacy) - MINOR CONFLICT

**Location:** `docs/developer/03-superdag/03-specs/SPEC_WORK_CENTER_BEHAVIOR.md`

**Line 41-42:**
```sql
is_hatthasilpa_supported tinyint(1) -- Can be used in Hatthasilpa line
is_classic_supported tinyint(1)     -- Can be used in Classic/PWA line
```

**Potential Confusion:**
- Field `is_classic_supported` อาจทำให้คิดว่า Classic ใช้ Work Queue ได้
- ทั้งที่ SYSTEM_WIRING_GUIDE ระบุชัดว่า Classic = Linear only, ไม่ใช้ DAG/Work Queue

**Reality Check:**
- Classic ยังคงมี `work_center` table (physical locations)
- Classic อาจมี "behavior concept" ในอนาคต (แต่ไม่ใช่ผ่าน DAG/Work Queue)
- `is_classic_supported` = "ถ้าอนาคต Classic adopt Work Queue" (ตอนนี้ยังไม่ใช้)

**Verdict:** ⚠️ Minor ambiguity - Not critical conflict

**Recommendation:**
- เพิ่ม note ใน SPEC_WORK_CENTER_BEHAVIOR.md ว่า:
  ```
  ⚠️ Current Scope:
  - is_hatthasilpa_supported = Active now (Hatthasilpa uses Work Queue + DAG)
  - is_classic_supported = Future extension (Classic currently uses Linear + PWA only)
  ```

---

## 2. Database Schema Alignment

### 2.1 work_center_behavior Table

**Schema in SPEC_WORK_CENTER_BEHAVIOR.md:**
```sql
work_center_behavior (
  id_behavior INT PK,
  code VARCHAR(50),
  is_hatthasilpa_supported TINYINT(1),
  is_classic_supported TINYINT(1),
  ...
)
```

**Status:** 🔜 **PLANNED** (ยังไม่ implement)

**Source:** Planning document (SPEC_WORK_CENTER_BEHAVIOR.md, REALITY_EVENT_IN_HOUSE.md)

### 2.2 Current Reality

**Database Check:**
- ❌ `work_center_behavior` table ยังไม่มี (planned only)
- ❌ `work_center_behavior_map` table ยังไม่มี (planned only)
- ✅ `work_center` table มี (legacy, no behavior field)
- ✅ Behaviors defined in code only (BehaviorExecutionService switch case)

**Verdict:** Schema ใน SPEC_WORK_CENTER_BEHAVIOR = Planning document (not current reality)

---

## 3. Behavior Code Existence Check

### 3.1 Behaviors in BehaviorExecutionService (Current)

**Source:** `source/BGERP/Dag/BehaviorExecutionService.php`

**Implemented:**
- STITCH
- CUT
- EDGE
- QC_SINGLE, QC_FINAL, QC_REPAIR, QC_INITIAL
- HARDWARE_ASSEMBLY, SKIVE, GLUE, ASSEMBLY, PACK, EMBOSS

**Total:** 13 behaviors

### 3.2 Behaviors in SPEC_WORK_CENTER_BEHAVIOR.md (Planned)

**Planned:**
- CUT (Hatthasilpa + Classic)
- EDGE (Hatthasilpa + Classic)
- STITCH (Hatthasilpa only)
- QC_FINAL (Hatthasilpa + Classic)

**Total:** 4 behaviors documented (more behaviors exist in code but not in legacy spec)

**Verdict:** Legacy spec is incomplete (newer BEHAVIOR_EXECUTION_SPEC.md covers all 13 behaviors)

---

## 4. Scope Conflicts Summary

| Document | Scope Statement | Aligned with SYSTEM_WIRING_GUIDE? |
|----------|----------------|-----------------------------------|
| **SYSTEM_WIRING_GUIDE.md** | Hatthasilpa = DAG only, Classic = Linear only | ✅ (source of truth) |
| **BEHAVIOR_EXECUTION_SPEC.md v2.0** | Hatthasilpa only (explicit note) | ✅ Aligned |
| **COMPONENT_PARALLEL_FLOW_SPEC.md v2.1** | Hatthasilpa (implicit) | ✅ Aligned |
| **SUPERDAG_TOKEN_LIFECYCLE.md v1.0** | DAG system (implicit Hatthasilpa) | ✅ Aligned |
| **SPEC_WORK_CENTER_BEHAVIOR.md (legacy)** | Hatthasilpa + Classic (ambiguous) | ⚠️ Minor ambiguity |

**Overall:** ✅ 95% aligned, 5% minor ambiguity in legacy doc

---

## 5. Recommendations

### 5.1 Update SPEC_WORK_CENTER_BEHAVIOR.md (Legacy)

**Add scope clarification:**

```markdown
## Current Scope (2025-12-02)

**Active:**
- `is_hatthasilpa_supported = 1` → Hatthasilpa uses Work Queue + DAG (ACTIVE NOW)

**Future Extension:**
- `is_classic_supported = 1` → Classic may adopt Work Queue in future (NOT ACTIVE NOW)
- Classic currently uses Linear mode + PWA scanners only
- See SYSTEM_WIRING_GUIDE.md Section 4-5 for current line separation

**⚠️ Important:**
- work_center_behavior table = PLANNED (not yet implemented)
- Current behavior logic in BehaviorExecutionService (code-based)
- See BEHAVIOR_EXECUTION_SPEC.md for current implementation blueprint
```

### 5.2 Mark Legacy Specs Clearly

**In docs/developer/03-superdag/03-specs/README.md:**

```markdown
## Legacy Specs (Planning Documents - Pre-Implementation)

⚠️ These specs were created during planning phase.
⚠️ For current implementation blueprint, see docs/super_dag/02-specs/

### SPEC_WORK_CENTER_BEHAVIOR.md
- Status: Legacy planning document
- Table planned but not implemented
- See BEHAVIOR_EXECUTION_SPEC.md (v2.0) for current blueprint

### SPEC_TOKEN_ENGINE.md
- Status: Legacy planning document
- Replaced by SUPERDAG_TOKEN_LIFECYCLE.md

### SPEC_TIME_ENGINE.md
- Status: Reference (time tracking still valid)
```

### 5.3 No Action Required for SuperDAG Specs

**BEHAVIOR_EXECUTION_SPEC.md v2.0:**
- ✅ Already has scope clarification
- ✅ No changes needed

**COMPONENT_PARALLEL_FLOW_SPEC.md v2.1:**
- ✅ Implicitly Hatthasilpa (correct)
- ✅ No changes needed

**SUPERDAG_TOKEN_LIFECYCLE.md v1.0:**
- ✅ DAG system (Hatthasilpa) (correct)
- ✅ No changes needed

---

## 6. Conclusion

**Current State:**
- SuperDAG specs (docs/super_dag/) = Hatthasilpa scope (aligned ✅)
- Legacy specs (docs/developer/03-superdag/03-specs/) = Planning docs with ambiguous Classic support
- SYSTEM_WIRING_GUIDE = Clear separation (Hatthasilpa DAG vs Classic Linear)

**Gap:** ⚠️ Minor - Legacy specs ไม่มี scope clarification

**Impact:** 🟢 LOW - New specs (v2.0+) already correct, legacy specs ใช้เป็น reference only

**Action Required:**
1. ✅ Add scope note to SPEC_WORK_CENTER_BEHAVIOR.md (optional)
2. ✅ Mark legacy specs as "Planning Documents" in README (optional)
3. ❌ No action required for SuperDAG specs (already aligned)

---

## 7. References

**Source of Truth:**
- `docs/developer/SYSTEM_WIRING_GUIDE.md` - System architecture and line separation

**SuperDAG Specs (Current):**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` (v2.0)
- `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` (v2.1)
- `docs/super_dag/02-specs/SUPERDAG_TOKEN_LIFECYCLE.md` (v1.0)

**Legacy Specs (Planning):**
- `docs/developer/03-superdag/03-specs/SPEC_WORK_CENTER_BEHAVIOR.md`
- `docs/developer/03-superdag/03-specs/SPEC_TOKEN_ENGINE.md`

---

**END OF AUDIT**

