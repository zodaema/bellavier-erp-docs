# DAG System Audit Workflow

**Date:** December 2025  
**Status:** ✅ **MANDATORY PROCESS**  
**Purpose:** Prevent issues from accumulating by running comprehensive audits after every implementation phase

---

## 🚨 CRITICAL RULE

**ทุกครั้งที่ทำ implementation เสร็จ ต้องรัน audit ทั้ง 3 เรื่องนี้:**

1. ✅ **NodeType Policy & UI Audit** - ตรวจสอบว่า node_type policy ถูกเคารพหรือไม่
2. ✅ **Flow Status & Transition Audit** - ตรวจสอบ status values และ transitions
3. ✅ **Hatthasilpa Assignment Integration Audit** - ตรวจสอบ flow ของ Manager Assignment

**หากไม่ audit → ปัญหาจะพอกพูนจนแก้ยาก**

---

## 📋 Audit Checklist (Run After Every Phase Completion)

### ✅ Pre-Audit Checklist

- [ ] Implementation phase completed
- [ ] Code changes committed
- [ ] Tests passing (if applicable)
- [ ] Documentation updated

### ✅ Audit Execution

- [ ] **Audit 1:** NodeType Policy & UI Audit
- [ ] **Audit 2:** Flow Status & Transition Audit
- [ ] **Audit 3:** Hatthasilpa Assignment Integration Audit
- [ ] All audit reports reviewed
- [ ] Critical issues fixed before proceeding
- [ ] Moderate issues documented for future fixes

---

## 1️⃣ NodeType Policy & UI Audit

### Purpose
ตรวจสอบว่า node_type policy ถูกเคารพหรือไม่ (ไม่มี Start/Complete โผล่ที่ qc/split/join/start/end/wait/etc.)

### Scope
- Back-end APIs (action validation, query filtering)
- Front-end UIs (button rendering, node filtering)
- Routing behavior (system nodes handling)

### Command
```bash
# AI Agent Command:
# "Run NodeType Policy & UI Audit - Check that all actions/buttons/APIs respect NodeTypePolicy"
# Output: docs/dag/02-implementation-status/FULL_NODETYPE_POLICY_AUDIT.md
```

### What to Check

**Back-end:**
1. Action → node_type validation:
   - `handleStartToken()`, `handlePauseToken()`, `handleResumeToken()` - ต้อง validate node_type
   - `handleCompleteToken()` - ต้อง check node_type สำหรับ QC routing
   - `handleQCResult()` - ต้อง validate token is at QC node

2. Visibility / query filters:
   - `get_work_queue` - ต้อง filter `node_type IN ('operation', 'qc')`
   - `manager_all_tokens` - ต้อง filter `node_type IN ('operation', 'qc')`
   - `assignment_api` - ต้อง filter `node_type IN ('operation', 'qc')`

3. Routing behavior:
   - START/split/join/end/wait/decision/system nodes ไม่ควรเป็น work items
   - DAGRoutingService ต้อง handle system nodes correctly

**Front-end:**
1. Work Queue UI:
   - Render buttons based on node_type (operation vs qc)
   - Hide non-operational node_types

2. Manager Assignment UI:
   - Plans Tab: filter `node_type IN ('operation', 'qc')`
   - Tokens Tab: filter `node_type IN ('operation', 'qc')`

3. PWA UI:
   - Only allow appropriate actions for given node_type

### Expected Output
- Report: `docs/dag/02-implementation-status/FULL_NODETYPE_POLICY_AUDIT.md`
- Sections: Summary, Back-end Actions, Visibility Queries, Front-end UI, Issues & Recommendations

### Critical Issues to Flag
- ❌ Missing node_type validation in action handlers
- ❌ Queries not filtering by node_type
- ❌ UI showing buttons for wrong node_types
- ❌ System nodes exposed as work items

---

## 2️⃣ Flow Status & Transition Audit

### Purpose
ตรวจสอบ state machine ของ job_ticket + flow_token ว่ามี status ไหนซ้ำซ้อน / ขัดกัน / ข้าม step / ใช้ชื่อไม่สม่ำเสมอไหม

### Scope
- Database schema (ENUM definitions, VARCHAR values)
- PHP usage (status assignments, transitions)
- JavaScript usage (status checks, UI rendering)
- Lifecycle consistency

### Command (Copy-Paste Ready)

**สำหรับ AI Agent ให้ใช้คำสั่งนี้:**

```
Run Flow Status & Transition Audit - Check job_ticket and flow_token status consistency.
Ensure that all status values and transitions for job tickets and DAG tokens are consistent,
non-contradictory, and match the intended lifecycle.
Output: docs/dag/02-implementation-status/FLOW_STATUS_TRANSITION_AUDIT.md
```

**Output:** `docs/dag/02-implementation-status/FLOW_STATUS_TRANSITION_AUDIT.md`

### What to Check

1. **Enumerate status values:**
   - Job ticket statuses: `planned`, `in_progress`, `qc`, `rework`, `completed`, `cancelled`
   - Token statuses: `ready`, `active`, `waiting`, `paused`, `completed`, `scrapped`
   - Where defined (schema)
   - Where used (PHP, JS)

2. **Define intended lifecycle:**
   - Job lifecycle: `planned` → `in_progress` → `qc` → `completed` / `rework` / `cancelled`
   - Token lifecycle: `spawn` → `ready` → `active` → `waiting` → `completed` / `scrapped`

3. **Find inconsistencies:**
   - Same meaning, different word (e.g., `'active'` vs `'in_progress'`)
   - Impossible transitions (e.g., `'planned'` → `'completed'` without intermediate)
   - Unused or orphan statuses
   - Status values used in front-end that don't exist in back-end or DB

4. **Check alignment:**
   - Job status transitions align with token spawning
   - Token status transitions align with job status

### Expected Output
- Report: `docs/dag/02-implementation-status/FLOW_STATUS_TRANSITION_AUDIT.md`
- Sections: Overview, Job Statuses, Token Statuses, Lifecycle Diagrams, Inconsistencies, Recommendations

### Critical Issues to Flag
- ❌ Token status ENUM mismatch (code uses values not in ENUM)
- ❌ Job ticket status inconsistency (`'active'` vs `'in_progress'`)
- ❌ Impossible status transitions
- ❌ Front-end uses status values not in schema

---

## 3️⃣ Hatthasilpa Assignment Integration Audit

### Purpose
ตรวจสอบ Flow ที่เพิ่งทำ: Plans Tab → assignment_plan_job → AssignmentResolverService → Tokens → Work Queue/Manager Assignment

### Scope
- Plans Tab behavior (node listing, assignment storage)
- Tokens Tab behavior (token fetching, filtering)
- AssignmentResolverService (PIN > PLAN > AUTO precedence)
- Work Queue integration
- Hatthasilpa-only filtering

### Command (Copy-Paste Ready)

**สำหรับ AI Agent ให้ใช้คำสั่งนี้:**

```
Run Hatthasilpa Assignment Integration Audit - Verify Manager Assignment flow.
Verify that the new Manager Assignment behavior for Hatthasilpa:
- Uses PLAN-level assignment correctly (job_id + node_id + operator_id)
- Does NOT depend on START node tokens anymore
- Integrates correctly with AssignmentResolverService, Work Queue, Manager Assignment UI
Output: docs/dag/02-implementation-status/HATTHASILPA_ASSIGNMENT_INTEGRATION_AUDIT.md
```

**Output:** `docs/dag/02-implementation-status/HATTHASILPA_ASSIGNMENT_INTEGRATION_AUDIT.md`

### What to Check

1. **Hatthasilpa-only filtering:**
   - Assignment APIs filter `production_type = 'hatthasilpa'`
   - OEM/Classic jobs do NOT show up in Manager Assignment

2. **Plans Tab behavior:**
   - Lists only `node_type IN ('operation', 'qc')`
   - Stores in `assignment_plan_job` using `id_job_ticket` (NOT `job_id`)
   - NO dependency on START node

3. **Tokens Tab behavior:**
   - Fetches only `job_ticket.status IN ('in_progress', 'active')` (NOT `'planned'`)
   - Filters `node_type IN ('operation', 'qc')`
   - NO code expecting tokens at START nodes

4. **AssignmentResolverService behavior:**
   - `checkPLAN()` uses `id_job_ticket` correctly
   - `checkPIN()` uses `id_job_ticket` correctly
   - Precedence: PIN > PLAN > AUTO
   - START nodes skipped (no auto-assign at START)

5. **Work Queue integration:**
   - Shows "assigned to" using assignment plan as default
   - Filters "งานของฉัน" use token.operator_id OR plan-based assignment
   - Does not rely on START node assignments

6. **User experience scenarios:**
   - New Hatthasilpa job: `planned` → Plans Tab → Start Job → tokens → Tokens Tab + Work Queue
   - Reassignment: Tokens Tab → NodeAssignmentService → Work Queue update
   - Mixed jobs: OEM jobs do not appear in Manager Assignment

### Expected Output
- Report: `docs/dag/02-implementation-status/HATTHASILPA_ASSIGNMENT_INTEGRATION_AUDIT.md`
- Sections: Overview, Plan-level Assignment, Token-level Assignment, Resolver & Services, Work Queue Behavior, Issues & Recommendations

### Critical Issues to Flag
- ❌ START-based assignment still used
- ❌ Wrong column name (`job_id` instead of `id_job_ticket`)
- ❌ Missing `production_type` filter (OEM jobs showing)
- ❌ Missing `node_type` filter (system nodes showing)
- ❌ Plans Tab showing tokens from `planned` jobs

---

## 🔄 Workflow Integration

### When to Run Audits

**After every implementation phase completion:**
1. ✅ Phase implementation done
2. ✅ Code committed
3. ✅ Tests passing
4. ✅ **RUN ALL 3 AUDITS** ← **MANDATORY**
5. ✅ Review audit reports
6. ✅ Fix critical issues before proceeding
7. ✅ Document moderate issues for future fixes

### Integration with Roadmap

**Add to `DAG_IMPLEMENTATION_ROADMAP.md` (in `01-roadmap/`) after each phase:**

```markdown
## Phase X.X Completion Checklist

- [ ] Implementation complete
- [ ] Tests written and passing
- [ ] Documentation updated
- [ ] **Audit 1: NodeType Policy & UI** ✅
- [ ] **Audit 2: Flow Status & Transition** ✅
- [ ] **Audit 3: Hatthasilpa Assignment Integration** ✅
- [ ] Critical issues fixed
- [ ] Ready for next phase
```

---

## 📊 Audit Report Template

Each audit report should follow this structure:

```markdown
# [Audit Name] - DAG System

**Date:** [Date]
**Status:** ✅ Audit Complete / ⚠️ Issues Found
**Scope:** [Scope description]

## 1. Summary
- Overall compliance status
- Key findings
- Critical issues count

## 2. [Detailed Sections]
- [Section-specific findings]

## 3. Issues & Recommendations
- [CRITICAL] items that must be fixed before production
- [MODERATE] items that should be fixed soon
- [INFO] items that are acceptable but should be documented

## 4. Conclusion
- Overall assessment
- Action items
- Next review date
```

---

## 🚨 Escalation Rules

### Critical Issues
- **Must fix before proceeding to next phase**
- **Must fix before production deployment**
- Examples:
  - Token status ENUM mismatch (will cause DB errors)
  - Missing node_type validation (security risk)
  - START-based assignment still used (breaks workflow)

### Moderate Issues
- **Should fix in current or next phase**
- **Document for tracking**
- Examples:
  - Missing node_type check in action handlers (defense-in-depth)
  - Job ticket status inconsistency (`'active'` vs `'in_progress'`)

### Info Issues
- **Document for future reference**
- **Low priority**
- Examples:
  - Documentation gaps
  - Code comments missing

---

## 📝 Audit History

| Date | Phase | Audit 1 | Audit 2 | Audit 3 | Critical Issues | Status |
|------|-------|---------|---------|---------|-----------------|--------|
| 2025-12 | Initial | ✅ | ✅ | ✅ | 2 | ⚠️ Needs Fixes |

---

## 🎯 Success Criteria

**Audit is successful when:**
- ✅ All 3 audit reports generated
- ✅ All critical issues identified
- ✅ Critical issues fixed or documented with fix plan
- ✅ Moderate issues documented for tracking
- ✅ Reports reviewed and approved

**Do NOT proceed to next phase if:**
- ❌ Critical issues exist and not fixed
- ❌ Audit reports not generated
- ❌ Issues not documented

---

## 📚 Reference Documents

- **Audit Reports:**
  - `docs/dag/02-implementation-status/FULL_NODETYPE_POLICY_AUDIT.md`
  - `docs/dag/02-implementation-status/FLOW_STATUS_TRANSITION_AUDIT.md`
  - `docs/dag/02-implementation-status/HATTHASILPA_ASSIGNMENT_INTEGRATION_AUDIT.md`

- **Implementation Roadmap:**
  - `docs/dag/01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md`

- **Code Review Reports:**
  - `docs/dag/02-implementation-status/FULL_CODE_REVIEW_REPORT.md`
  - `docs/dag/02-implementation-status/PHASE5X_REVIEW.md`

---

**Last Updated:** December 2025  
**Next Review:** After next implementation phase  
**Maintainer:** Development Team

---

## 📝 Quick Reference Card (สำหรับ AI Agent)

**Copy-Paste Commands:**

### Audit 1: NodeType Policy & UI
```
Run NodeType Policy & UI Audit - Check that all actions/buttons/APIs respect NodeTypePolicy.
Find ANY inconsistencies between node_type policy (operation, qc, start, split, join, end, wait, decision, system, subgraph)
AND how APIs and UIs actually behave (actions exposed, buttons shown, transitions allowed).
Output: docs/dag/02-implementation-status/FULL_NODETYPE_POLICY_AUDIT.md
```

### Audit 2: Flow Status & Transition
```
Run Flow Status & Transition Audit - Check job_ticket and flow_token status consistency.
Ensure that all status values and transitions for job tickets and DAG tokens are consistent,
non-contradictory, and match the intended lifecycle.
Output: docs/dag/02-implementation-status/FLOW_STATUS_TRANSITION_AUDIT.md
```

### Audit 3: Hatthasilpa Assignment Integration
```
Run Hatthasilpa Assignment Integration Audit - Verify Manager Assignment flow.
Verify that the new Manager Assignment behavior for Hatthasilpa:
- Uses PLAN-level assignment correctly (job_id + node_id + operator_id)
- Does NOT depend on START node tokens anymore
- Integrates correctly with AssignmentResolverService, Work Queue, Manager Assignment UI
Output: docs/dag/02-implementation-status/HATTHASILPA_ASSIGNMENT_INTEGRATION_AUDIT.md
```

**⚠️ Remember:** All audits are READ-ONLY (no code changes). Only analyze and report.

