# Investigation Reports Summary

**Last Updated:** December 2025  
**Purpose:** Consolidated summary of investigation reports

---

## 📋 Investigation Reports

### INVESTIGATION_REPORT_NODE_PLAN_ASSIGNMENT.md

**Date:** December 2025  
**Issue:** `AssignmentEngine` logs "Assignment created via node_plan" but no `token_assignment` row is inserted into database.

**Root Cause Identified:**
The `insertAssignmentWithMethod()` method (and `insertAssignment()`) are missing the required `id_node` column in their INSERT statements. The `token_assignment` table schema requires `id_node` (NOT NULL), but the INSERT statements omit this column, causing silent SQL failures.

**Additional Issues Found:**
1. No error checking after `prepare()` - if prepare fails, code continues and crashes on `bind_param()`
2. No error checking after `execute()` - if execute fails, code continues silently
3. Nested transaction issue - `assignOne()` starts its own transaction inside `handleTokenSpawn()`'s transaction

**Resolution:**
- Fixed in Task 7: Node Plan Auto-Assignment Integration
- See: [TASK_DAG_7_NODE_PLAN_AUTO_ASSIGN.md](../03-tasks/TASK_DAG_7_NODE_PLAN_AUTO_ASSIGN.md)

**Related Files:**
- `source/BGERP/Service/AssignmentEngine.php` - `insertAssignmentWithMethod()` method
- `source/BGERP/Service/AssignmentEngine.php` - `insertAssignment()` method
- `tests/Integration/HatthasilpaAssignmentIntegrationTest.php` - Integration tests

**Full Report:**
- See: `docs/dag/agent-tasks/INVESTIGATION_REPORT_NODE_PLAN_ASSIGNMENT.md`

---

## 🔗 Related Tasks

- [TASK_DAG_7_NODE_PLAN_AUTO_ASSIGN.md](../03-tasks/TASK_DAG_7_NODE_PLAN_AUTO_ASSIGN.md) - Node Plan Auto-Assignment Integration (resolved investigation issues)

---

**Last Updated:** December 2025

