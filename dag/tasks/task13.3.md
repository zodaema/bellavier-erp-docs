

# Task 13.3 – Component System Phase 1 (Foundation)

## 1. Purpose & Context
This task sets the foundational data structures and read-only APIs required for the Component System.  
The objective is to prepare the ground before implementing component serial binding, multi-source component tracking, and manufacturing-time component association.

This is the continuation from Super DAG Task 13.2.

---

## 2. Scope of Work (What this Task Covers)

### 2.1 Component Master Table
Create a central table that defines all component types needed for any product:
- edge pieces  
- body panels  
- straps  
- hardware units  
- reinforcement boards  
- zipper kits  
- decorative components  

### 2.2 Component Type Definition
Component types need to be normalized:
- `component_type_id`
- `component_type_code` (unique)
- `component_type_name`
- `unit_of_measure` (piece, set, roll, sheet)
- `created_at`
- `updated_at`

### 2.3 Component Master Table Structure
Each component entry represents a “design-level” component before serial assignment:
- `id`
- `component_type_id`
- `component_code`
- `component_name`
- `description`
- `default_quantity_per_product`
- `is_active`

### 2.4 BOM → Component Line Mapping
This task prepares read-only BOM-to-component mapping:
- No serial generation yet  
- No allocation logic  
- Only the ability to query: “Product X requires these components”

### 2.5 Component Serial Standard (Documentation Only)
Document the planned serial standard:
- Format proposal: `{COMP}-{YYYYMMDD}-{running}`
- Component-level traceability rail  
- Future integration with cutting-session batch serials  
- Future integration with rework components  

### 2.6 API Layer (Read-Only)
Three new read-only API actions:

#### 1) List Component Types
`GET source/component.php?action=type_list`

#### 2) List Component Master Items
`GET source/component.php?action=component_list`

#### 3) Get BOM → Component Lines
`GET source/component.php?action=bom_component_lines&product_id=XX`

All actions:
- Must be read-only  
- Must use tenant DB  
- Must be 100% safe and backward-compatible  

### 2.7 No UI Work Yet
This task **does not** create UI pages.  
Only database + API + documentation.

---

## 3. Future Tasks (Phase 2, Phase 3)
These are referenced but NOT included in Task 13.3:

### Phase 2 (Serial Operations)
- Component serial generation  
- Batch cutting serial linking  
- Component → Token assignment logic  
- QC-level component validation  

### Phase 3 (Integration)
- PWA support  
- Work Queue component requirements  
- DAG routing enforcing component completeness  
- Pack-out verification  

---

## 4. Database Work Required

### 4.1 Migrations to Create
1. `component_type`  
2. `component_master`  
3. `component_bom_map`

Each migration must:
- be idempotent  
- include indexes  
- include foreign keys  
- include descriptive comments  

---

## 5. Prompt for AI Agent (Cursor)
Use this prompt when instructing the AI Agent:

```
You are to implement Task 13.3.

1. Create database migrations:
   - component_type
   - component_master
   - component_bom_map

2. Create source/component.php with read-only actions:
   - type_list
   - component_list
   - bom_component_lines

3. Do NOT create UI.
4. Do NOT implement serial logic.
5. Do NOT modify existing Behavior, Token Engine, or DAG logic.
6. Code must be tenant-safe and backward-compatible.
7. Follow style conventions of existing API files.
8. Update task_index.md marking Task 13.3 as COMPLETED.
```

---

## 6. Definition of Done
- [ ] All required tables created via migration  
- [ ] API implemented with read-only actions  
- [ ] No breaking changes  
- [ ] No execution logic added  
- [ ] Documentation produced  
- [ ] `task_index.md` updated correctly

---

Task 13.3 lays the foundation for the entire Component System and prepares for the serial & binding layers in upcoming tasks.