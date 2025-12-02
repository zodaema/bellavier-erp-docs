# Task 13.15 Results — Schema Mapping & Material Pipeline Blueprint

**Status:** ✅ **COMPLETED**  
**Date:** December 2025  
**Task:** [13.15.md](13.15.md)

---

## Summary

Task 13.15 successfully created a comprehensive Material Pipeline Schema Blueprint V1 that provides complete documentation of the material flow system from GRN intake through production to finish. The blueprint includes schema extraction, ER diagrams, lifecycle documentation, master data ownership definitions, and gap analysis reports. This documentation serves as the foundation for understanding the Material Pipeline and enables safe implementation of Tasks 13.16–13.20.

---

## Deliverables

### D1. Schema Dump File ✅

**File:** `docs/architecture/03-material/schema_raw_dump.md`

**Content:**
- Complete schema extraction for all Material Pipeline tables
- Includes `SHOW CREATE TABLE` and `DESCRIBE` results
- Documents foreign keys, indexes, and comments
- Covers 7 major table groups:
  1. Material Master Data (`material`, `stock_item`)
  2. GRN & Lot Management (`material_lot`)
  3. Leather Sheet Inventory (`leather_sheet`, `leather_sheet_usage_log`)
  4. BOM Structure (`bom`, `bom_line`)
  5. CUT Operations (`leather_cut_bom_log`, `cut_batch`)
  6. Component Allocation (`component_serial_allocation`)
  7. DAG Integration (`flow_token`, `job_graph_instance`, `job_ticket`)

**Key Features:**
- ✅ Complete field definitions with data types
- ✅ Foreign key relationships documented
- ✅ Index definitions included
- ✅ Table purposes and usage patterns explained
- ✅ Summary sections for FK relationships and indexes

**Usage:**
- Reference for developers understanding table structures
- Foundation for ER diagram generation
- Source for gap analysis

---

### D2. ER Diagram ✅

**File:** `docs/architecture/03-material/material_pipeline_er.md`

**Content:**
- Mermaid ER diagram showing all relationships
- Visual representation of Material Pipeline schema
- Key relationships documented:
  1. Material Master Data Flow
  2. BOM to CUT Flow
  3. Leather Sheet Usage Flow
  4. CUT Batch Flow
  5. DAG Integration Flow

**Diagram Coverage:**
- ✅ All major tables included
- ✅ Foreign key relationships visualized
- ✅ String references documented (no FK constraints)
- ✅ Direct FK constraints listed separately

**Key Relationships:**
- `STOCK_ITEM` → `MATERIAL_LOT` (GRN flow)
- `MATERIAL_LOT` → `LEATHER_SHEET` (sheet creation)
- `LEATHER_SHEET` → `LEATHER_SHEET_USAGE_LOG` (usage tracking)
- `BOM` → `BOM_LINE` → `STOCK_ITEM` (material reference)
- `FLOW_TOKEN` → `JOB_GRAPH_INSTANCE` → `JOB_TICKET` (DAG integration)

**Usage:**
- Visual reference for system architecture
- Understanding data flow paths
- Identifying relationship gaps

---

### D3. Material Flow Lifecycle ✅

**File:** `docs/architecture/03-material/material_flow_lifecycle.md`

**Content:**
- Complete lifecycle documentation from GRN to finish
- 7 lifecycle stages documented:
  1. **GRN Intake** — Leather GRN flow, material selection, lot creation
  2. **Material Registration** — Master data setup, SKU generation
  3. **Lot Creation** — GRN header, lot code generation
  4. **Leather Sheet Creation** — Physical inventory tracking
  5. **Sheet Usage → CUT BOM → CUT Behavior** — Production usage
  6. **Component Allocation** — Serial number assignment (Task 13.8)
  7. **WIP → QC → Finish** — Production completion

**Key Features:**
- ✅ Step-by-step flow documentation
- ✅ Actor identification (who performs each step)
- ✅ Data flow between stages
- ✅ Complete flow diagram (Mermaid)
- ✅ Data flow summary sections:
  - Material SKU Flow
  - BOM to CUT Flow
  - Sheet Usage Flow
  - Component Allocation Flow

**Usage:**
- Understanding end-to-end material flow
- Identifying integration points
- Planning new features
- Training documentation

---

### D4. Master Data Ownership Definition ✅

**File:** `docs/architecture/03-material/material_master_ownership.md`

**Content:**
- Source of truth definitions for all master data
- Answers critical questions:
  1. **SKU Source of Truth:** `stock_item.sku` (primary), `material.sku` (legacy)
  2. **Stock Item Role:** Inventory master for all stock-kept items
  3. **Material Role:** Legacy master catalog (maintained for compatibility)
  4. **Leather Sheet References:** `material.sku` (legacy FK), should reference `stock_item.sku`
  5. **SKU Generation:** System auto-generates, user can override

**Master Data Ownership Model:**
- ✅ `stock_item` — Primary source of truth for material SKU
- ✅ `material` — Legacy table (maintained for compatibility)
- ✅ `material_lot` — GRN lot ownership (references `stock_item`)
- ✅ `leather_sheet` — Physical inventory (references `material.sku` legacy)
- ✅ `bom_line` — BOM component (references `stock_item.sku` via string)

**Data Consistency Rules:**
- ✅ Rule 1: SKU Synchronization (stock_item.sku = material.sku)
- ✅ Rule 2: Material Lot Consistency
- ✅ Rule 3: Leather Sheet Consistency
- ✅ Rule 4: BOM Line Consistency

**Recommendations:**
- Consolidate Material Master (migrate to stock_item)
- Add FK constraint to BOM Line
- Remove legacy FK from Leather Sheet

**Usage:**
- Understanding which table is source of truth
- Planning data migration
- Resolving FK mismatch issues
- Making architectural decisions

---

### D5. Gap & Conflict Report ✅

**File:** `docs/architecture/03-material/material_schema_gap_report.md`

**Content:**
- Comprehensive gap analysis and conflict identification
- 7 critical gaps identified:
  1. **Dual Material Master** (High Priority) — `material` vs `stock_item` overlap
  2. **FK Mismatch in Leather Sheet** (High Priority) — References `material.sku` instead of `stock_item.sku`
  3. **String FK in BOM Line** (Medium Priority) — No FK constraint on `material_sku`
  4. **Leather Sheet Creation Failure** (High Priority) — Fails if `material` record missing
  5. **CUT Pipeline Material Master Access** (Medium Priority) — No direct access to material attributes
  6. **DAG Behavior Material SKU Mapping** (Low Priority) — No direct mapping in flow_token
  7. **QC Policy JSON Artifact** (Resolved) — Legacy '0' value issue

**Conflicts:**
- ✅ Conflict 1: Material SKU Ownership (stock_item vs material)
- ✅ Conflict 2: Leather Sheet FK Path (material.sku vs stock_item.sku)

**Risk Points:**
- ✅ Risk 1: Data Inconsistency (SKU mismatch between tables)
- ✅ Risk 2: GRN Flow Failure (missing material records)
- ✅ Risk 3: Orphaned BOM Lines (string FK without constraint)
- ✅ Risk 4: Performance Issues (missing indexes, inefficient queries)

**Recommendations Summary:**
- ✅ Immediate Actions (Before Task 13.16)
- ✅ Short-Term Actions (Task 13.16–13.17)
- ✅ Long-Term Actions (Task 13.18–13.20)

**Priority Matrix:**
- High Priority: 3 gaps (Dual Material Master, FK Mismatch, Sheet Creation Failure)
- Medium Priority: 2 gaps (String FK, CUT Pipeline Access)
- Low Priority: 1 gap (DAG Behavior Mapping)

**Usage:**
- Identifying issues before implementation
- Prioritizing fixes
- Risk assessment
- Planning migration paths

---

## Technical Implementation

### Documentation Structure

All deliverables follow consistent structure:
- **Header:** Title, generation date, purpose, task reference
- **Overview:** High-level summary
- **Detailed Sections:** Step-by-step documentation
- **Summary/Conclusion:** Key takeaways

### Documentation Standards

- ✅ Mermaid diagrams for visual representation
- ✅ Code blocks for SQL schemas
- ✅ Tables for structured data
- ✅ Clear section hierarchy
- ✅ Cross-references between documents

### File Organization

All deliverables stored in:
```
docs/architecture/03-material/
├── schema_raw_dump.md
├── material_pipeline_er.md
├── material_flow_lifecycle.md
├── material_master_ownership.md
└── material_schema_gap_report.md
```

---

## Key Findings

### 1. Dual Material Master Issue

**Finding:** Both `material` and `stock_item` exist with overlapping purposes.

**Impact:**
- Data inconsistency risk (SKU values may differ)
- Developer confusion (which table to use?)
- Maintenance burden (must maintain both)

**Recommendation:**
- Use `stock_item` as source of truth
- Migrate references from `material` to `stock_item`
- Deprecate `material` table (long-term)

### 2. FK Mismatch in Leather Sheet

**Finding:** `leather_sheet.sku_material` references `material.sku` but should reference `stock_item.sku`.

**Impact:**
- Sheet creation fails if `material` record missing
- Inconsistent with GRN flow (uses `stock_item`)

**Recommendation:**
- Add `id_stock_item` FK to `leather_sheet`
- Migrate existing data
- Remove legacy `sku_material` FK (long-term)

### 3. String FK in BOM Line

**Finding:** `bom_line.material_sku` is string reference without FK constraint.

**Impact:**
- Orphaned BOM lines possible
- No referential integrity
- Data quality issues

**Recommendation:**
- Add FK constraint to `stock_item.sku`
- Validate all existing BOM lines
- Add validation in API layer

### 4. Material Flow Lifecycle Clarity

**Finding:** Complete lifecycle documented from GRN to finish.

**Impact:**
- Clear understanding of material flow
- Identified integration points
- Foundation for future features

**Benefit:**
- Agents can understand system without confusion
- Safe implementation of Tasks 13.16–13.20

---

## Acceptance Criteria Status

### Functional Requirements:
- ✅ Schema dump complete for all relevant tables
- ✅ ER diagram comprehensive and readable
- ✅ Master data ownership clearly defined
- ✅ Lifecycle shows complete flow
- ✅ Gap report identifies root causes clearly
- ✅ Agent can read documentation and proceed with next tasks
- ✅ Big picture of Material Pipeline visible

### Non-Functional Requirements:
- ✅ All documentation files created
- ✅ Consistent structure and formatting
- ✅ Mermaid diagrams render correctly
- ✅ Cross-references between documents
- ✅ Clear recommendations provided

---

## Files Created

### Documentation Files:
1. `docs/architecture/03-material/schema_raw_dump.md`
   - Complete schema extraction (575+ lines)
   - All tables documented with CREATE TABLE statements
   - FK relationships and indexes summarized

2. `docs/architecture/03-material/material_pipeline_er.md`
   - Mermaid ER diagram (289+ lines)
   - Visual representation of all relationships
   - Key relationships documented

3. `docs/architecture/03-material/material_flow_lifecycle.md`
   - Complete lifecycle documentation (463+ lines)
   - 7 lifecycle stages documented
   - Flow diagrams and data flow summaries

4. `docs/architecture/03-material/material_master_ownership.md`
   - Master data ownership definitions (398+ lines)
   - Source of truth definitions
   - Data consistency rules and recommendations

5. `docs/architecture/03-material/material_schema_gap_report.md`
   - Gap analysis report (358+ lines)
   - 7 critical gaps identified
   - Risk assessment and recommendations

6. `docs/dag/tasks/task13.15_results.md`
   - This file

---

## Known Limitations

1. **Schema Evolution:**
   - Documentation reflects current state (December 2025)
   - Future schema changes may require updates
   - Gap report recommendations need implementation

2. **Data Migration:**
   - Gap report identifies issues but doesn't implement fixes
   - Migration scripts need to be created separately
   - Data validation required before migration

3. **Performance Analysis:**
   - Schema dump includes indexes but no performance analysis
   - Query optimization recommendations not included
   - Performance testing needed separately

---

## Future Enhancements

1. **Schema Migration:**
   - Implement recommendations from gap report
   - Migrate `leather_sheet` FK from `material.sku` to `stock_item.sku`
   - Add FK constraint to `bom_line.material_sku`
   - Consolidate material master (deprecate `material` table)

2. **Enhanced Documentation:**
   - Add query examples for common operations
   - Add performance optimization guide
   - Add data migration scripts
   - Add API endpoint documentation

3. **Validation Tools:**
   - Create data consistency validation scripts
   - Create FK integrity checkers
   - Create SKU synchronization validators

4. **Integration Testing:**
   - Test complete material flow end-to-end
   - Validate FK relationships
   - Test data migration paths

---

## Notes

- **Foundation Document:** Task 13.15 creates the foundation for understanding Material Pipeline. All future tasks (13.16–13.20) should reference these documents.

- **Gap Report Priority:** High-priority gaps (Dual Material Master, FK Mismatch, Sheet Creation Failure) should be addressed before Task 13.16.

- **Documentation Maintenance:** These documents should be updated when schema changes occur. Keep them in sync with actual implementation.

- **Agent Guidance:** These documents enable AI agents to understand the system without confusion and implement features safely.

---

**Task 13.15 Complete** ✅

**Material Pipeline Blueprint: Schema → ER → Lifecycle → Ownership → Gap Analysis**

**Foundation Ready for Tasks 13.16–13.20**

