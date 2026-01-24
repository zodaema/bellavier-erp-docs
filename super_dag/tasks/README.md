# Tasks Directory - AI Agent Guidelines

**Version:** 1.0  
**Last Updated:** January 2026  
**Purpose:** มาตรฐานการเขียน Task Files สำหรับ AI Agents ทุกตัว

---

## 📁 Directory Structure

```
tasks/
├── README.md                          # ← ไฟล์นี้ (Guidelines)
├── task{N}_{NAME}.md                  # Task หลัก
├── task{N}.{X}_{NAME}.md              # Sub-task (ถ้าจำเป็น)
├── results/
│   └── task{N}.{X}.results.md         # ผลลัพธ์หลัง implement
├── checklist/
│   └── task{N}.{X}_checklist.md       # Checklist (optional)
└── archive/
    ├── completed_tasks/               # Tasks ที่เสร็จแล้ว
    └── results/                       # Results ที่เสร็จแล้ว
```

---

## 📝 Task Numbering Convention

### Main Tasks

| Pattern | Example | Description |
|---------|---------|-------------|
| `task{N}` | `task29` | หมายเลข task หลัก (ต่อจากเดิม) |
| `task{N}_{NAME}` | `task29_PRODUCT_REVISION_SYSTEM` | ชื่อ task ใช้ SCREAMING_SNAKE_CASE |

### Sub-Tasks (ถ้าจำเป็น)

| Pattern | Example | Description |
|---------|---------|-------------|
| `task{N}.{X}` | `task29.1` | Sub-task ที่ 1 ของ task 29 |
| `task{N}.{X}_{NAME}` | `task29.1_REVISION_FOUNDATION` | ชื่อ sub-task |

**หลักการ:** ยุบรวม tasks ถ้าไม่เกิน Memory Limit ของ AI Agent (ประมาณ 10-15 operations per task)

---

## 📄 Task File Template

### Main Task File (`task{N}_{NAME}.md`)

```markdown
# Task {N}: {Title}

**Status:** 📋 **TODO** | 🔄 **IN PROGRESS** | ✅ **COMPLETE**  
**Priority:** 🔴 **CRITICAL** | 🟡 **HIGH** | 🟢 **MEDIUM**  
**Category:** {Category}  
**Date:** {Month Year}

---

## Executive Summary

**Goal:** {One sentence goal}

**Why Important:** {Why this matters}

**Reference Documents:**
- `{path/to/spec.md}` ({Description})
- `{path/to/reference.php}` ({Description})

---

## Scope

{Description of what's included and excluded}

---

## Task Breakdown

| Task | Title | Estimate |
|------|-------|----------|
| {N}.1 | {Title} | {X} days |
| {N}.2 | {Title} | {X} days |

---

## Task {N}.1: {Title}

**Status:** 📋 **TODO**  
**Estimate:** {X} days

### Scope
{What this task covers}

### Deliverables
- [ ] {File/Component 1}
- [ ] {File/Component 2}
- [ ] Unit tests

### Acceptance Criteria
- [ ] {Criterion 1}
- [ ] {Criterion 2}

---

## Agent Instructions

1. {Instruction 1}
2. {Instruction 2}

---

**Next Task:** {N}.{X} ({Title})
```

---

## 📊 Result File Template

### Result File (`results/task{N}.{X}.results.md`)

**เมื่อไหร่ต้องเขียน:** หลัง implement task เสร็จแล้ว

```markdown
# Task {N}.{X} Results: {Title}

**Task:** {Title}  
**Status:** ✅ **COMPLETE**  
**Date:** {Date}  
**Duration:** {X} hours/days

---

## 🎯 Objectives Achieved

### Primary Goals
- [x] {Goal 1}
- [x] {Goal 2}
- [ ] {Goal not achieved - with reason}

---

## 📋 Files Modified

### 1. {Filename}

**File:** `{path/to/file}`  
**Changes:** +{N} lines / -{N} lines

{Description of changes}

```php
// Key code snippet (if helpful)
```

---

## 🧪 Tests

### Tests Added
- `{TestFile}` - {X} tests
  - `test{Name}` - {Description}

### Test Results
```
✅ All {N} tests passing
```

---

## ⚠️ Issues Encountered

### Issue 1: {Title}
- **Problem:** {Description}
- **Solution:** {How it was solved}

---

## 📝 Notes for Future

- {Note 1}
- {Note 2}

---

## ✅ Acceptance Criteria Status

| Criterion | Status |
|-----------|--------|
| {Criterion 1} | ✅ |
| {Criterion 2} | ✅ |

---

**Next Task:** {N}.{X+1} ({Title})
```

---

## 🔄 Task Lifecycle

```
1. PLANNING
   └── Task file created with 📋 TODO status

2. IN PROGRESS
   └── Agent working on implementation 🔄

3. COMPLETE
   └── Implementation done
   └── Result file written ✅
   └── Tests passing

4. ARCHIVED (after major release)
   └── Moved to archive/completed_tasks/
```

---

## 📏 Guidelines for AI Agents

### ✅ DO

1. **Read Reference Docs First**
   - Always read SPEC and Implementation Plan before starting
   - Reference existing code patterns (e.g., GraphVersionService)

2. **Follow Existing Patterns**
   - Use same coding style as existing codebase
   - Use existing services and helpers

3. **Write Tests**
   - Every task must include tests
   - Use PHPUnit for PHP tests

4. **Document Results**
   - Write result file after completion
   - Include all files modified
   - Note any issues encountered

5. **Update Task Status**
   - Change status in task file when starting/completing

### ❌ DON'T

1. **Don't Create Too Many Sub-Tasks**
   - Consolidate if possible
   - One task per session is ideal

2. **Don't Skip Validation**
   - Always validate inputs
   - Use prepared statements for SQL

3. **Don't Forget Dependencies**
   - Check what other tasks depend on
   - Don't break existing functionality

4. **Don't Leave Incomplete States**
   - Use transactions for multi-step operations
   - Rollback on failure

---

## 📚 Reference Files

### SPEC Documents
- `docs/super_dag/06-specs/` - Specifications
- `docs/super_dag/plans/` - Implementation Plans
- `docs/super_dag/01-concepts/` - Core Concepts

### Code Templates
- `source/dag/Graph/Service/GraphVersionService.php` - Versioning pattern
- `source/service/ValidationService.php` - Validation pattern
- `source/service/DatabaseTransaction.php` - Transaction pattern

### Existing Results (Reference)
- `tasks/results/task28.*.results.md` - Graph Versioning results

---

## 🏷️ Status Icons

| Icon | Status | Meaning |
|------|--------|---------|
| 📋 | TODO | ยังไม่เริ่ม |
| 🔄 | IN PROGRESS | กำลังทำ |
| ✅ | COMPLETE | เสร็จแล้ว |
| ⏸️ | ON HOLD | รอ dependencies |
| ❌ | CANCELLED | ยกเลิก |
| 🔴 | CRITICAL | ความสำคัญสูงสุด |
| 🟡 | HIGH | ความสำคัญสูง |
| 🟢 | MEDIUM | ความสำคัญปานกลาง |

---

## 📦 Archiving

**เมื่อไหร่ต้อง Archive:**
- หลัง major release
- หลัง task ทั้งหมดใน series เสร็จ

**วิธี Archive:**
1. Move task file to `archive/completed_tasks/`
2. Move result files to `archive/results/`
3. Update index if needed

---

## 🔗 Quick Links

| Document | Path |
|----------|------|
| Current Tasks | `tasks/*.md` |
| Results | `tasks/results/*.md` |
| SPEC Documents | `docs/super_dag/06-specs/` |
| Implementation Plans | `docs/super_dag/plans/` |
| Completed Archives | `tasks/archive/completed_tasks/` |

---

**Maintained By:** AI Agent System  
**Questions:** Consult SPEC documents or existing task/result files for patterns
