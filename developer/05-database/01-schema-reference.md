# 🗄️ Database Schema Quick Reference

**Purpose:** Quick lookup for table structures (avoid SHOW COLUMNS every time)  
**Last Updated:** January 2025  
**Databases:** Core (`bgerp`) + Tenant (`bgerp_t_{org_code}`)  
**Latest Migration:** 0001_init_tenant_schema_v2.php (122 tables), 0001_core_bootstrap_v2.php (13 tables)

**Current State:**
- **Core Database:** 13 tables
- **Tenant Database:** 122 tables
- **Total:** 135 tables

---

## 🎯 **Quick Lookup Guide**

**Need to know:**
- Table structure → Jump to section
- Soft-delete tables → See "Critical Notes"
- Indexes → See each table's index section
- Relationships → See "Table Relationships"

---

## 📊 **Core Database (bgerp)**

### **account** (Users)

```sql
CREATE TABLE account (
    id_member INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(200) NOT NULL,
    email VARCHAR(200),
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP
);
```

**Indexes:**
- PRIMARY KEY (id_member)
- UNIQUE (username)

---

### **organization** (Tenants)

```sql
CREATE TABLE organization (
    id_org INT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

**Indexes:**
- PRIMARY KEY (id_org)
- UNIQUE (code)

---

### **account_org** (User-Org Membership)

**⚠️ NOTE: Schema will change on November 4, 2025**

**Current (Before Refactor):**
```sql
CREATE TABLE account_org (
    id INT PRIMARY KEY AUTO_INCREMENT,
    id_member INT NOT NULL,
    id_org INT NOT NULL,
    id_group INT NOT NULL,  -- ← Will be removed
    UNIQUE KEY (id_member, id_org),
    FOREIGN KEY (id_member) REFERENCES account(id_member),
    FOREIGN KEY (id_org) REFERENCES organization(id_org),
    FOREIGN KEY (id_group) REFERENCES account_group(id_group)
);
```

**After Refactor (November 4, 2025):**
```sql
CREATE TABLE account_org (
    id INT PRIMARY KEY AUTO_INCREMENT,
    id_member INT NOT NULL,
    id_org INT NOT NULL,
    role_code VARCHAR(50) DEFAULT 'member',  -- ← NEW: 'owner', 'admin', 'member'
    UNIQUE KEY (id_member, id_org),
    INDEX idx_account_org_role (role_code),  -- ← NEW: Performance index
    FOREIGN KEY (id_member) REFERENCES account(id_member),
    FOREIGN KEY (id_org) REFERENCES organization(id_org)
    -- ← id_group FK removed
);
```

**Migration:**
- `id_group` (INT) → `role_code` (VARCHAR) 
- Values: `'owner'`, `'admin'`, `'member'` (migrated from `account_group.group_name`)
- **Owner bypass:** Check `role_code = 'owner'` (no JOIN needed)

**Related Tables:**
- ✅ `account_group` - Kept (used for UI labels and permission bypass)
- ✅ `account.id_group` - Used by permission system
- ✅ `account_org.id_group` - 1=owner, 2=admin, 3=member

---

### **tenant_user** (Tenant Users - ALL TENANTS)

**Location:** Core DB (`bgerp`) - **Updated November 4, 2025**

```sql
CREATE TABLE tenant_user (
    id_tenant_user INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(100) UNIQUE NOT NULL COMMENT 'Unique across ALL tenants',
    email VARCHAR(150) NULL,
    password VARCHAR(255) NOT NULL COMMENT 'PBKDF2 hash',
    id_org INT NOT NULL COMMENT 'Which tenant',
    org_code VARCHAR(50) NOT NULL COMMENT 'Organization code',
    id_tenant_role INT NULL COMMENT 'Role ID (references tenant_role in tenant DB)',
    name VARCHAR(150) NULL,
    phone VARCHAR(20) NULL,
    status TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_by INT NULL,
    updated_at DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
    last_login_at DATETIME NULL,
    failed_login_count INT DEFAULT 0,
    locked_until DATETIME NULL,
    
    INDEX idx_username (username),
    INDEX idx_org (id_org, org_code),
    INDEX idx_status (status),
    INDEX idx_last_login (last_login_at),
    
    FOREIGN KEY (id_org) REFERENCES organization(id_org) ON DELETE CASCADE
);
```

**Purpose:**
- Store ALL tenant users from ALL tenants
- Prevent username collisions (UNIQUE constraint)
- Enable single URL login (no subdomain needed)

**Migration:** Moved from Tenant DBs to Core DB (November 4, 2025)

---

## 🏭 **Tenant Database (bgerp_t_{org_code})**

### **atelier_job_ticket** (Main Work Order)

```sql
CREATE TABLE atelier_job_ticket (
    id_job_ticket INT PRIMARY KEY AUTO_INCREMENT,
    ticket_code VARCHAR(50) UNIQUE NOT NULL,
    job_name VARCHAR(200) NOT NULL,
    target_qty DECIMAL(10,2) NOT NULL,
    status ENUM('planned', 'in_progress', 'on_hold', 'qc', 'rework', 'completed', 'cancelled') DEFAULT 'planned',
    process_mode ENUM('batch', 'piece') DEFAULT 'batch',
    id_mo INT NULL,
    work_center_id INT NULL,
    sku VARCHAR(100) NULL,
    due_date DATE NULL,
    started_at DATETIME NULL,
    completed_at DATETIME NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP,
    created_by INT,
    
    -- Future columns (for DAG - not yet implemented):
    -- routing_mode ENUM('linear', 'dag') DEFAULT 'linear',
    -- graph_instance_id INT NULL,
    
    INDEX idx_status (status),
    INDEX idx_due_date (due_date),
    INDEX idx_mo (id_mo)
) ENGINE=InnoDB;
```

**Key Fields:**
- `process_mode`: `batch` (ผลิตเป็นล็อต) | `piece` (ทำทีละชิ้น - ต้องมี serial)
- `status`: Reflects overall job status (aggregated from tasks)

**❌ NO soft-delete** (no deleted_at column)

---

### **atelier_job_task** (Work Steps)

```sql
CREATE TABLE atelier_job_task (
    id_job_task INT PRIMARY KEY AUTO_INCREMENT,
    id_job_ticket INT NOT NULL,
    step_name VARCHAR(200) NOT NULL,
    sequence_no INT NOT NULL,
    status ENUM('pending', 'in_progress', 'on_hold', 'paused', 'qc', 'rework', 'done', 'cancelled') DEFAULT 'pending',
    assigned_to INT NULL COMMENT 'User ID from core DB',
    predecessor_task_id INT NULL,
    work_center_id INT NULL,
    estimated_hours DECIMAL(10,2) DEFAULT 0,
    started_at DATETIME NULL,
    completed_at DATETIME NULL,
    paused_at DATETIME NULL,
    total_pause_minutes INT DEFAULT 0,
    qc_pass_qty DECIMAL(10,2) DEFAULT 0,
    qc_fail_qty DECIMAL(10,2) DEFAULT 0,
    
    -- Future columns (for DAG - not yet implemented):
    -- node_id INT NULL,
    
    INDEX idx_ticket (id_job_ticket),
    INDEX idx_status (status, id_job_ticket),
    INDEX idx_sequence (id_job_ticket, sequence_no),
    FOREIGN KEY (id_job_ticket) REFERENCES atelier_job_ticket(id_job_ticket) ON DELETE CASCADE
) ENGINE=InnoDB;
```

**Key Fields:**
- `sequence_no`: Linear order (1, 2, 3...)
- `status`: Auto-updated by JobTicketStatusService
- **Progress:** Calculated from `atelier_task_operator_session` (NOT stored!)

**❌ NO soft-delete** (no deleted_at column)  
**❌ NO progress_pct column** (deprecated - calculate from sessions)

---

### **atelier_wip_log** (Event Logs - SOFT DELETE!)

```sql
CREATE TABLE atelier_wip_log (
    id_wip_log INT PRIMARY KEY AUTO_INCREMENT,
    id_job_ticket INT NOT NULL,
    id_job_task INT NOT NULL,
    event_type ENUM('start', 'hold', 'resume', 'complete', 'fail', 'qc_start', 'qc_pass', 'qc_fail', 'note') NOT NULL,
    event_time DATETIME NOT NULL,
    operator_name VARCHAR(100),
    operator_user_id INT NULL,
    qty DECIMAL(10,2) DEFAULT 0,
    serial_number VARCHAR(100) NULL COMMENT 'Serial/Lot number for piece tracking (DAG-compatible)', -- ✅ Migration 0005
    notes TEXT NULL,
    process_mode VARCHAR(20) NULL,
    status_snapshot VARCHAR(50) NULL,
    idempotency_key VARCHAR(100) NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- ⭐ SOFT DELETE COLUMNS (ONLY THIS TABLE!)
    deleted_at DATETIME NULL,
    deleted_by INT NULL,
    
    INDEX idx_wip_log_ticket_deleted (id_job_ticket, deleted_at),
    INDEX idx_wip_log_task_deleted (id_job_task, deleted_at),
    INDEX idx_wip_log_task_operator (id_job_task, operator_user_id, deleted_at),
    INDEX idx_wip_log_event_type (event_type, deleted_at),
    INDEX idx_wip_log_event_time (event_time, deleted_at),
    INDEX idx_serial (serial_number), -- ✅ Migration 0005
    INDEX idx_task_serial (id_job_task, serial_number, deleted_at), -- ✅ Migration 0005 (duplicate check)
    UNIQUE INDEX idx_idempotency (idempotency_key),
    FOREIGN KEY (id_job_ticket) REFERENCES atelier_job_ticket(id_job_ticket) ON DELETE CASCADE,
    FOREIGN KEY (id_job_task) REFERENCES atelier_job_task(id_job_task) ON DELETE CASCADE
) ENGINE=InnoDB;
```

**⚠️ CRITICAL:**
- **ONLY table with soft-delete** (deleted_at, deleted_by)
- **ALWAYS filter:** `WHERE deleted_at IS NULL` in ALL queries
- **NEVER hard-delete:** Use `UPDATE SET deleted_at = NOW(), deleted_by = ?`

**Event Types:**
- `start`, `hold`, `resume` - Work lifecycle
- `complete`, `fail` - Work result
- `qc_start`, `qc_pass`, `qc_fail` - QC events
- `note` - Comments

---

### **atelier_task_operator_session** (Operator Work Sessions)

```sql
CREATE TABLE atelier_task_operator_session (
    id_session INT PRIMARY KEY AUTO_INCREMENT,
    id_job_task INT NOT NULL,
    operator_user_id INT NOT NULL,
    operator_name VARCHAR(100),
    status ENUM('active', 'paused', 'completed', 'cancelled') DEFAULT 'active',
    total_qty DECIMAL(10,2) DEFAULT 0,
    total_pause_minutes INT DEFAULT 0,
    started_at DATETIME NULL,
    paused_at DATETIME NULL,
    completed_at DATETIME NULL,
    cancelled_at DATETIME NULL,
    
    INDEX idx_session_task_status (id_job_task, status),
    INDEX idx_session_operator (operator_user_id),
    INDEX idx_session_status (status),
    FOREIGN KEY (id_job_task) REFERENCES atelier_job_task(id_job_task) ON DELETE CASCADE
) ENGINE=InnoDB;
```

**Purpose:**
- Track individual operator work (support concurrent operators)
- Calculate progress (SUM completed sessions)
- Rebuilt from WIP logs automatically

**❌ NO soft-delete**

---

### **work_center** (Work Stations)

```sql
CREATE TABLE work_center (
    work_center_id INT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    status ENUM('active', 'inactive', 'maintenance') DEFAULT 'active',
    capacity_per_day DECIMAL(10,2) DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
```

---

## 👥 **Team Management Tables** ⭐ **(NEW - Phase 1 Complete)**

### **team** (Team Master Data)

**Purpose:** Organize operators into teams with Hybrid Model (OEM/Hatthasilpa/Hybrid)

```sql
CREATE TABLE team (
    id_team INT PRIMARY KEY AUTO_INCREMENT COMMENT 'Team ID',
    code VARCHAR(50) NOT NULL COMMENT 'Team code (e.g., TEAM-CUT-01)',
    name VARCHAR(100) NOT NULL COMMENT 'Team name (e.g., ทีมตัดวัสดุ A)',
    description TEXT NULL COMMENT 'Team description/purpose',
    id_org INT NOT NULL COMMENT 'Tenant isolation (FK → organization.id_org)',
    team_category ENUM('cutting','sewing','qc','finishing','general') DEFAULT 'general' 
        COMMENT 'Functional category (work station type)',
    production_mode ENUM('oem','hatthasilpa','hybrid') DEFAULT 'hybrid' 
        COMMENT 'Which production type this team can serve',
    active TINYINT(1) DEFAULT 1 COMMENT '1=active, 0=deactivated',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_by INT NULL COMMENT 'FK → account.id_member',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uniq_code_org (code, id_org),
    INDEX idx_org_active (id_org, active),
    INDEX idx_category (team_category, active),
    INDEX idx_production_mode (production_mode, active),
    INDEX idx_active (active, id_org)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Key Fields:**
- `production_mode`: `oem` (OEM only) | `hatthasilpa` (Hatthasilpa only) | `hybrid` (both)
- `team_category`: Functional classification (cutting, sewing, qc, finishing, general)
- `active`: Soft-delete flag (deactivate instead of delete)

**Usage:**
```php
// Get all active hybrid teams
$teams = db_fetch_all($db, "
    SELECT * FROM team 
    WHERE id_org = ? AND active = 1 AND production_mode = 'hybrid'
    ORDER BY team_category, code
", [$orgId]);
```

---

### **team_member** (Team Membership)

**Purpose:** Track which operators belong to which teams with role hierarchy

```sql
CREATE TABLE team_member (
    id_team INT NOT NULL COMMENT 'FK → team.id_team',
    id_member INT NOT NULL COMMENT 'FK → account.id_member (Core DB)',
    role ENUM('lead','supervisor','qc','member','trainee') DEFAULT 'member' 
        COMMENT 'Team role hierarchy',
    capacity_per_day INT DEFAULT 0 COMMENT 'Expected output per day (optional)',
    active TINYINT(1) DEFAULT 1 COMMENT '1=active, 0=removed from team',
    joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    removed_at DATETIME NULL,
    removed_by INT NULL COMMENT 'Manager who removed this member',
    notes TEXT NULL COMMENT 'Special notes about this member',
    
    PRIMARY KEY (id_team, id_member),
    INDEX idx_member (id_member, active),
    INDEX idx_role (role, active),
    INDEX idx_team_active (id_team, active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Role Hierarchy:**
1. `lead` - Team leader (highest authority)
2. `supervisor` - Shift supervisor
3. `qc` - Quality control specialist
4. `member` - Regular team member
5. `trainee` - New member (learning)

**Usage:**
```php
// Get active members of a team with names (2-step cross-DB query)
$members = db_fetch_all($tenantDb, "
    SELECT id_member, role, capacity_per_day, joined_at
    FROM team_member 
    WHERE id_team = ? AND active = 1
    ORDER BY 
        CASE role 
            WHEN 'lead' THEN 1 
            WHEN 'supervisor' THEN 2 
            WHEN 'qc' THEN 3 
            WHEN 'member' THEN 4 
            WHEN 'trainee' THEN 5 
        END
", [$teamId]);

// Fetch names from Core DB
$memberIds = array_column($members, 'id_member');
// ... (see team_api.php get_detail for full pattern)
```

---

### **team_member_history** (Audit Trail)

**Purpose:** Complete audit log of all team member changes

```sql
CREATE TABLE team_member_history (
    id_history INT PRIMARY KEY AUTO_INCREMENT,
    id_team INT NOT NULL COMMENT 'FK → team.id_team',
    id_member INT NOT NULL COMMENT 'FK → account.id_member',
    action ENUM('add','remove','promote','demote','role_change') NOT NULL 
        COMMENT 'What action occurred',
    old_role VARCHAR(20) NULL COMMENT 'Previous role (for role changes)',
    new_role VARCHAR(20) NULL COMMENT 'New role (for role changes)',
    performed_by INT NOT NULL COMMENT 'Manager who performed this action',
    performed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    reason TEXT NULL COMMENT 'Reason for this action',
    metadata JSON NULL COMMENT 'Additional context (capacity changes, etc.)',
    
    INDEX idx_team (id_team, performed_at),
    INDEX idx_member (id_member, performed_at),
    INDEX idx_action (action, performed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Actions:**
- `add` - Member added to team
- `remove` - Member removed from team
- `promote` - Role increased (e.g., member → supervisor)
- `demote` - Role decreased (e.g., lead → member)
- `role_change` - Role changed (same level)

**Usage:**
```php
// Get team history (last 30 days)
$history = db_fetch_all($db, "
    SELECT * FROM team_member_history 
    WHERE id_team = ? AND performed_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
    ORDER BY performed_at DESC
", [$teamId]);
```

---

### **stock_item** (Materials/Products)

```sql
CREATE TABLE stock_item (
    sku VARCHAR(100) PRIMARY KEY,
    description VARCHAR(500),
    id_uom INT,
    id_category INT,
    is_lot_tracked BOOLEAN DEFAULT false,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_category (id_category),
    FOREIGN KEY (id_uom) REFERENCES unit_of_measure(id_uom)
) ENGINE=InnoDB;
```

---

### **stock_ledger** (Inventory Transactions)

```sql
CREATE TABLE stock_ledger (
    id_ledger INT PRIMARY KEY AUTO_INCREMENT,
    txn_type ENUM('GRN', 'ISSUE', 'TRANSFER', 'ADJUST') NOT NULL,
    sku VARCHAR(100) NOT NULL,
    qty DECIMAL(15,4) NOT NULL,
    id_uom INT NOT NULL,
    id_location INT NOT NULL,
    lot_code VARCHAR(100) NULL,
    ref_id VARCHAR(100) NULL,
    txn_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_by INT,
    
    INDEX idx_sku_date (sku, txn_date),
    INDEX idx_location (id_location),
    INDEX idx_lot (lot_code),
    FOREIGN KEY (sku) REFERENCES stock_item(sku)
) ENGINE=InnoDB;
```

---

## 📊 **DAG Production System Tables** ⭐ **(NEW - Migration 0008)**

### **routing_graph** (Workflow Templates)

**Purpose:** Reusable production workflow graphs (like "TOTE Production V1")

```sql
CREATE TABLE routing_graph (
    id_graph INT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(50) UNIQUE NOT NULL COMMENT 'Graph code (e.g., TOTE_PRODUCTION_V1)',
    name VARCHAR(200) NOT NULL COMMENT 'Display name',
    description TEXT NULL COMMENT 'Graph purpose and notes',
    graph_type ENUM('sequential', 'parallel', 'assembly') NOT NULL DEFAULT 'sequential',
    is_published BOOLEAN DEFAULT false,
    created_by INT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_published (is_published, created_at),
    INDEX idx_type (graph_type)
) ENGINE=InnoDB;
```

**Key Fields:**
- `code`: Unique identifier (e.g., TOTE_PRODUCTION_V1)
- `graph_type`: sequential (linear), parallel (concurrent), assembly (multi-component)
- `is_published`: Only published graphs can be used for jobs

---

### **routing_node** (Graph Operations)

**Purpose:** Operations/stations within a workflow graph

```sql
CREATE TABLE routing_node (
    id_node INT PRIMARY KEY AUTO_INCREMENT,
    id_graph INT NOT NULL COMMENT 'Parent graph',
    node_code VARCHAR(50) NOT NULL COMMENT 'Node code within graph (e.g., CUT, SEW_BODY)',
    node_name VARCHAR(200) NOT NULL COMMENT 'Display name',
    node_type ENUM('start','operation','split','join','decision','end') NOT NULL COMMENT 'start=entry point, operation=work, split=parallel spawn, join=assembly, decision=conditional routing, end=exit',
    id_work_center INT NULL COMMENT 'Work center if operation type',
    estimated_minutes INT NULL COMMENT 'Standard operation time',
    node_config JSON NULL COMMENT 'Node-specific configuration (e.g., join requirements, split ratio)',
    position_x INT NULL COMMENT 'UI canvas X position',
    position_y INT NULL COMMENT 'UI canvas Y position',
    sequence_no INT DEFAULT 0 COMMENT 'Display order',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    node_params JSON NULL COMMENT 'Type-specific parameters for node behavior',
    
    UNIQUE KEY uniq_graph_node_code (id_graph, node_code),
    INDEX idx_graph (id_graph),
    INDEX idx_type (node_type),
    INDEX idx_work_center (id_work_center),
    FOREIGN KEY (id_graph) REFERENCES routing_graph(id_graph) ON DELETE CASCADE,
    FOREIGN KEY (id_work_center) REFERENCES work_center(id_work_center) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Graph nodes (operations, splits, joins, decisions)';
```

**⚠️ IMPORTANT:** 
- `join_requirement` is NOT a separate column. Join requirements are stored in `node_params` JSON field.
- Additional columns added in Phase 1: `team_category`, `production_mode`, `wip_limit`, `assignment_policy`, `preferred_team_id`, `allowed_team_ids`, `forbidden_team_ids` (see migration `2025_11_routing_graph_phase1.php`).

**Node Types:**
- `start`: Entry point (single)
- `operation`: Standard work step
- `split`: Parallel branches (1 token → N tokens)
- `join`: Converge branches (N tokens → 1 token)
- `decision`: Conditional routing (QC pass/fail)
- `end`: Exit point (single)

---

### **routing_edge** (Graph Connections)

**Purpose:** Arrows connecting nodes (workflow paths)

```sql
CREATE TABLE routing_edge (
    id_edge INT PRIMARY KEY AUTO_INCREMENT,
    id_graph INT NOT NULL COMMENT 'Parent graph',
    from_node_id INT NOT NULL COMMENT 'Source node',
    to_node_id INT NOT NULL COMMENT 'Target node',
    edge_type ENUM('normal','rework','conditional') NOT NULL DEFAULT 'normal' COMMENT 'normal=standard flow, rework=QC fail loop, conditional=decision-based',
    edge_condition JSON NULL COMMENT 'Condition for routing (if edge_type=conditional)',
    edge_label VARCHAR(100) NULL COMMENT 'Display label (e.g., "QC Pass", "Defect: Stitch")',
    priority INT DEFAULT 0 COMMENT 'Evaluation order for decision nodes',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (id_edge),
    INDEX idx_graph (id_graph),
    INDEX idx_from (from_node_id),
    INDEX idx_to (to_node_id),
    INDEX idx_type (edge_type),
    FOREIGN KEY (id_graph) REFERENCES routing_graph(id_graph) ON DELETE CASCADE,
    FOREIGN KEY (from_node_id) REFERENCES routing_node(id_node) ON DELETE CASCADE,
    FOREIGN KEY (to_node_id) REFERENCES routing_node(id_node) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Directed edges (connections) between nodes';
```

**⚠️ IMPORTANT:**
- `condition_field` and `condition_value` are legacy fields (deprecated). Use `edge_condition` JSON instead.
- `routing_edge` does NOT have `deleted_at` column (no soft-delete support).
- `sequence_no` column exists but is not commonly used (priority is preferred for conditional edges).

**Edge Types:**
- `normal`: Standard flow
- `rework`: Loop back (excluded from cycle detection)
- `conditional`: Routing based on condition (e.g., qc_result = 'pass')

---

### **routing_graph_feature_flag** (Per-Graph Feature Flags)

**Purpose:** Feature flags for individual graphs (e.g., RUNTIME_ENABLED)

```sql
CREATE TABLE routing_graph_feature_flag (
    id_flag INT PRIMARY KEY AUTO_INCREMENT,
    id_graph INT NOT NULL COMMENT 'Graph ID',
    flag_key VARCHAR(100) NOT NULL COMMENT 'Flag key (e.g., RUNTIME_ENABLED)',
    flag_value ENUM('on','off') NOT NULL DEFAULT 'off' COMMENT 'Flag value',
    description TEXT NULL COMMENT 'Flag description',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uniq_graph_flag (id_graph, flag_key),
    INDEX idx_graph (id_graph),
    INDEX idx_flag_key (flag_key),
    FOREIGN KEY (id_graph) REFERENCES routing_graph(id_graph) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Per-graph feature flags';
```

**⚠️ IMPORTANT:** 
- Schema does NOT include `enabled_at`, `enabled_by`, or `notes` columns.
- Use `description` column instead of `notes`.
- Common flag keys: `RUNTIME_ENABLED` (controls if graph can be used in runtime)

---

### **routing_graph_version** (Graph Version Snapshots) ⭐ **(Task 28.4 - Updated)**

**Purpose:** Immutable snapshots of published graph versions for versioning, audit, and rollback

```sql
CREATE TABLE routing_graph_version (
    id_version INT PRIMARY KEY AUTO_INCREMENT,
    id_graph INT NOT NULL COMMENT 'Parent graph (FK to routing_graph)',
    version VARCHAR(20) NOT NULL COMMENT 'Version string (e.g., "1.0", "2.0")',
    payload_json LONGTEXT NOT NULL COMMENT 'Full graph snapshot (JSON: graph, nodes, edges)',
    metadata_json JSON NULL COMMENT 'Additional metadata (published_by, notes, etc.)',
    config_json JSON NULL COMMENT 'Graph-level configuration (qc_policy, assignment rules, etc.) - Task 28.4',
    published_at DATETIME NOT NULL COMMENT 'When this version was published',
    published_by INT NULL COMMENT 'User who published (FK to account.id_member)',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_stable TINYINT(1) DEFAULT 1 COMMENT 'Is this version stable (for auto-selection)',
    status VARCHAR(20) NULL DEFAULT NULL COMMENT 'Version status: published (active), retired (deprecated but viewable) - Task 28.4',
    allow_new_jobs TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Allow creating new jobs with this version (1=enabled, 0=disabled) - Task 28.4',
    
    PRIMARY KEY (id_version),
    UNIQUE KEY uniq_graph_version (id_graph, version),
    INDEX idx_graph (id_graph),
    INDEX idx_published (published_at),
    INDEX idx_graph_stable_published (id_graph, is_stable, published_at),
    INDEX idx_status (status) COMMENT 'Task 28.4 - For filtering Published/Retired versions',
    INDEX idx_graph_status (id_graph, status) COMMENT 'Task 28.4 - Common query pattern',
    INDEX idx_allow_new_jobs (allow_new_jobs) COMMENT 'Task 28.4 - Filter versions available for new jobs',
    FOREIGN KEY (id_graph) REFERENCES routing_graph(id_graph) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Immutable snapshots of published graph versions';
```

**Key Fields (Task 28.4 Updates):**
- `version`: Version string (VARCHAR) - kept for backward compatibility
- `status`: Version-level status (`published` or `retired`) - NULL for backward compatibility
- `allow_new_jobs`: Control whether new jobs can be created with this version (replaces `RUNTIME_ENABLED` flag)
- `config_json`: Graph-level configuration (JSON)

**Status Values:**
- `published`: Active version (can be used for new jobs if `allow_new_jobs=1`)
- `retired`: Deprecated version (viewable but not for new jobs)
- `NULL`: Backward compatibility (treated as `published` if `published_at IS NOT NULL`)

**Important Notes:**
- **Immutable:** Once published, version snapshots should never be modified
- **Backward Compatible:** Existing code using `version` (VARCHAR) continues to work
- **Version Resolution:** Product bindings use `status='published'` versions only (Task 28.3)
- **Migration:** Task 28.4 added `status`, `allow_new_jobs`, and `config_json` fields (additive approach)

---

### **job_graph_instance** (Active Job Graph)

**Purpose:** Live instance of a graph for a specific job

```sql
CREATE TABLE job_graph_instance (
    id_instance INT PRIMARY KEY AUTO_INCREMENT,
    id_job_ticket INT NOT NULL COMMENT 'Job ticket this graph is running for',
    id_graph INT NOT NULL COMMENT 'Template graph',
    status ENUM('active', 'paused', 'completed', 'cancelled') NOT NULL DEFAULT 'active',
    started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,
    
    INDEX idx_ticket (id_job_ticket),
    INDEX idx_graph (id_graph),
    FOREIGN KEY (id_job_ticket) REFERENCES atelier_job_ticket(id_job_ticket),
    FOREIGN KEY (id_graph) REFERENCES routing_graph(id_graph)
) ENGINE=InnoDB;
```

**Purpose:** One instance per DAG job ticket

---

### **node_instance** (Node Execution State)

**Purpose:** Runtime state of each node in the graph

```sql
CREATE TABLE node_instance (
    id_node_instance INT PRIMARY KEY AUTO_INCREMENT,
    id_instance INT NOT NULL,
    id_node INT NOT NULL COMMENT 'Template node',
    status ENUM('pending', 'active', 'paused', 'completed', 'blocked') NOT NULL DEFAULT 'pending',
    tokens_waiting INT NOT NULL DEFAULT 0 COMMENT 'For join nodes: count waiting tokens',
    started_at DATETIME NULL,
    completed_at DATETIME NULL,
    
    UNIQUE KEY uniq_instance_node (id_instance, id_node),
    INDEX idx_instance (id_instance),
    INDEX idx_status (status),
    FOREIGN KEY (id_instance) REFERENCES job_graph_instance(id_instance) ON DELETE CASCADE,
    FOREIGN KEY (id_node) REFERENCES routing_node(id_node)
) ENGINE=InnoDB;
```

**Status:**
- `pending`: Not started
- `active`: Work in progress
- `paused`: Temporarily stopped
- `completed`: Finished
- `blocked`: Waiting for dependencies (join nodes)

---

### **flow_token** (Work Units)

**Purpose:** Trackable work units flowing through the graph

```sql
CREATE TABLE flow_token (
    id_token INT PRIMARY KEY AUTO_INCREMENT,
    id_instance INT NOT NULL,
    token_type ENUM('batch', 'piece', 'component') NOT NULL DEFAULT 'piece',
    serial_number VARCHAR(100) NULL COMMENT 'For piece-level tracking',
    parent_token_id INT NULL COMMENT 'For split tokens',
    current_node_id INT NULL COMMENT 'Current location (NULL if completed/scrapped)',
    status ENUM('spawned', 'in_transit', 'at_node', 'completed', 'scrapped') NOT NULL DEFAULT 'spawned',
    qty DECIMAL(10,2) NOT NULL DEFAULT 1.00,
    spawned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,
    
    -- Phase 7.5: Scrap & Replacement (Manual Mode)
    parent_scrapped_token_id INT NULL COMMENT 'Reference to scrapped token (if this is a replacement)',
    scrap_replacement_mode VARCHAR(50) NULL COMMENT 'manual, auto_start, auto_cut (future use)',
    scrapped_at DATETIME NULL COMMENT 'When token was scrapped',
    scrapped_by INT NULL COMMENT 'Who scrapped the token (id_member)',
    
    INDEX idx_instance (id_instance),
    INDEX idx_serial (serial_number),
    INDEX idx_current_node (current_node_id),
    INDEX idx_status (status),
    INDEX idx_parent_scrapped (parent_scrapped_token_id),
    FOREIGN KEY (id_instance) REFERENCES job_graph_instance(id_instance) ON DELETE CASCADE,
    FOREIGN KEY (parent_token_id) REFERENCES flow_token(id_token),
    FOREIGN KEY (current_node_id) REFERENCES node_instance(id_node_instance),
    FOREIGN KEY (parent_scrapped_token_id) REFERENCES flow_token(id_token) ON DELETE SET NULL
) ENGINE=InnoDB;
```

**Token Types:**
- `batch`: Quantity-based (no serial)
- `piece`: Individual item (with serial)
- `component`: Assembly part (tracked separately)

**Phase 7.5: Scrap & Replacement Fields:**
- `parent_scrapped_token_id`: If this token is a replacement, references the scrapped token
- `scrap_replacement_mode`: 'manual' (Phase 7.5), 'auto_start', 'auto_cut' (future)
- `scrapped_at`: Timestamp when token was scrapped
- `scrapped_by`: User ID who scrapped the token

---

### **token_event** (Token Lifecycle Log)

**Purpose:** Audit trail for token movements and state changes

```sql
CREATE TABLE token_event (
    id_event INT PRIMARY KEY AUTO_INCREMENT,
    id_token INT NOT NULL,
    event_type ENUM('spawn', 'enter_node', 'start_work', 'pause_work', 'resume_work', 
                    'complete_work', 'exit_node', 'split', 'join', 'qc_pass', 'qc_fail', 
                    'complete_token', 'scrap', 'replacement_created', 'replacement_of') NOT NULL,
    from_node_id INT NULL,
    to_node_id INT NULL,
    operator_user_id INT NULL,
    operator_name VARCHAR(200) NULL,
    event_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    notes TEXT NULL,
    event_data JSON NULL COMMENT 'Additional event-specific data (Phase 7.5: scrap metadata, replacement info)',
    
    INDEX idx_token (id_token),
    INDEX idx_event_type (event_type),
    INDEX idx_event_time (event_time),
    FOREIGN KEY (id_token) REFERENCES flow_token(id_token) ON DELETE CASCADE
) ENGINE=InnoDB;
```

**Event Types:**
- `spawn`: Token created
- `enter_node`: Arrived at node
- `start_work`: Operator started
- `complete_work`: Operator finished
- `exit_node`: Left node
- `split`: Token divided (parallel work)
- `join`: Tokens merged
- `qc_pass` / `qc_fail`: Quality check result
- `complete_token`: Finished production
- `scrap`: Defective/discarded (Phase 7.5: includes reason, comment, rework_count in event_data)
- `replacement_created`: Replacement token created (log on scrapped token) - Phase 7.5
- `replacement_of`: This token is replacement of scrapped token (log on replacement token) - Phase 7.5

---

### **atelier_job_ticket** (Updated for DAG)

**Added Columns (Migration 0008):**

```sql
ALTER TABLE atelier_job_ticket ADD COLUMN
    routing_mode ENUM('linear', 'dag') NOT NULL DEFAULT 'linear' AFTER process_mode;

ALTER TABLE atelier_job_ticket ADD COLUMN
    graph_instance_id INT NULL AFTER routing_mode;

ALTER TABLE atelier_job_ticket ADD CONSTRAINT fk_graph_instance
    FOREIGN KEY (graph_instance_id) REFERENCES job_graph_instance(id_instance);
```

**Key Fields:**
- `routing_mode`: 'linear' (traditional tasks) or 'dag' (graph-based)
- `graph_instance_id`: Link to active graph instance (NULL for linear jobs)

**Dual-Mode Support:** System can run both linear and DAG jobs simultaneously!

---

## 🔗 **Table Relationships**

### **Job Ticket Flow:**

```
atelier_job_ticket (1)
    ↓ has many
atelier_job_task (N)
    ↓ has many
atelier_wip_log (N)
    ↓ generates
atelier_task_operator_session (N)
```

### **Cross-Database Relationships:**

```
Tenant: atelier_job_task.assigned_to
    ↓ references (but can't JOIN in prepared statements!)
Core: account.id_member

Solution: Two-step fetch + merge
```

---

## ⚠️ **Critical Notes**

### **Soft-Delete:**

**ONLY `atelier_wip_log` has soft-delete:**
```sql
✅ CORRECT:
SELECT * FROM atelier_wip_log 
WHERE id_job_task = ? AND deleted_at IS NULL

❌ WRONG:
SELECT * FROM atelier_job_ticket WHERE deleted_at IS NULL
-- Error: Unknown column 'deleted_at'!
```

**Tables WITHOUT soft-delete:**
- atelier_job_ticket
- atelier_job_task
- atelier_task_operator_session
- All other tables

---

### **Progress Calculation:**

**Source:** `atelier_task_operator_session` (NOT wip_log!)

```sql
✅ CORRECT:
SELECT 
    COALESCE(SUM(total_qty), 0) as completed_qty
FROM atelier_task_operator_session
WHERE id_job_task = ? AND status = 'completed'

❌ WRONG:
SELECT SUM(qty) FROM atelier_wip_log 
WHERE id_job_task = ? AND event_type = 'complete'
-- Doesn't handle concurrent operators correctly!
```

---

### **Cross-Database Queries:**

**Problem:** Can't JOIN bgerp.account in prepared statements

**Solution:**
```php
// Step 1: Fetch from tenant
$tasks = db_fetch_all($tenantDb, "
    SELECT * FROM atelier_job_task WHERE id_job_ticket = ?
", [$ticketId]);

// Step 2: Extract user IDs
$userIds = array_filter(array_column($tasks, 'assigned_to'));

// Step 3: Fetch from core (if any)
if (!empty($userIds)) {
    $coreDb = core_db();
    $placeholders = implode(',', array_fill(0, count($userIds), '?'));
    $stmt = $coreDb->prepare("
        SELECT id_member, name FROM account 
        WHERE id_member IN ($placeholders)
    ");
    $stmt->bind_param(str_repeat('i', count($userIds)), ...$userIds);
    $stmt->execute();
    $users = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $userMap = array_column($users, 'name', 'id_member');
}

// Step 4: Merge
foreach ($tasks as &$task) {
    $task['assigned_name'] = $userMap[$task['assigned_to']] ?? null;
}
```

---

## 📋 **Migration History**

**Tenant Migrations:**
- `0001_init_tenant_schema.php` - Complete schema (all tables)
- `0002_seed_sample_data.php` - Optional test data
- `0003_performance_indexes.php` - 15+ indexes for speed
- `0004_*` - (if any additional migrations)
- `0005_serial_tracking.php` - ✅ **NEW (Nov 1):** Serial number tracking (piece-level traceability)

**Check applied migrations:**
```sql
SELECT * FROM tenant_schema_migrations ORDER BY applied_at DESC;
```

---

## 🔍 **Common Query Patterns**

### **1. Fetch WIP Logs (with soft-delete filter):**

```sql
SELECT * FROM atelier_wip_log 
WHERE id_job_task = ? 
AND deleted_at IS NULL
ORDER BY event_time DESC
```

### **2. Calculate Task Progress:**

```sql
SELECT 
    task.id_job_task,
    task.step_name,
    ticket.target_qty,
    COALESCE(SUM(sess.total_qty), 0) as completed_qty,
    ROUND(COALESCE(SUM(sess.total_qty), 0) / ticket.target_qty * 100, 1) as progress_pct
FROM atelier_job_task task
JOIN atelier_job_ticket ticket ON ticket.id_job_ticket = task.id_job_ticket
LEFT JOIN atelier_task_operator_session sess ON sess.id_job_task = task.id_job_task 
    AND sess.status = 'completed'
WHERE task.id_job_ticket = ?
GROUP BY task.id_job_task
```

### **3. Get Active Tickets:**

```sql
SELECT 
    t.id_job_ticket,
    t.ticket_code,
    t.job_name,
    t.target_qty,
    t.status,
    t.process_mode,
    COALESCE(SUM(s.total_qty), 0) AS completed_qty
FROM atelier_job_ticket t
LEFT JOIN atelier_job_task task ON task.id_job_ticket = t.id_job_ticket
LEFT JOIN atelier_task_operator_session s ON s.id_job_task = task.id_job_task 
    AND s.status = 'completed'
WHERE t.status IN ('in_progress', 'on_hold', 'qc')
GROUP BY t.id_job_ticket
ORDER BY t.created_at DESC
LIMIT 100
```

---

## 🎯 **Helper Functions**

### **db_fetch_one() - Fetch single row**

```php
function db_fetch_one(mysqli $db, $sql, array $params = []) {
    $stmt = $db->prepare($sql);
    if (!$stmt) return null;
    
    if (!empty($params)) {
        $types = str_repeat('s', count($params));
        $stmt->bind_param($types, ...$params);
    }
    
    $stmt->execute();
    $result = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    
    return $result ?: null;
}
```

### **db_fetch_all() - Fetch multiple rows**

```php
function db_fetch_all(mysqli $db, $sql, array $params = []) {
    $stmt = $db->prepare($sql);
    if (!$stmt) return [];
    
    if (!empty($params)) {
        $types = '';
        foreach ($params as $p) {
            $types .= is_int($p) ? 'i' : (is_float($p) ? 'd' : 's');
        }
        $stmt->bind_param($types, ...$params);
    }
    
    $stmt->execute();
    $result = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    
    return $result;
}
```

---

## 📊 **Performance Indexes (Migration 0003)**

**Most Important Indexes:**

| Table | Index Name | Columns | Purpose |
|-------|-----------|---------|---------|
| atelier_wip_log | idx_wip_log_task_deleted | (id_job_task, deleted_at) | Task WIP queries |
| atelier_wip_log | idx_wip_log_ticket_deleted | (id_job_ticket, deleted_at) | Ticket WIP queries |
| atelier_task_operator_session | idx_session_task_status | (id_job_task, status) | Progress calculation |
| atelier_job_task | idx_task_status | (status, id_job_ticket) | Status filtering |

**Query Speed:**
- Before indexes: 200-500ms
- After indexes: 10-50ms
- **Improvement: 90-98% faster!**

---

## 🔧 **Schema Verification Commands**

```sql
-- Show table structure
SHOW CREATE TABLE atelier_wip_log;

-- Show columns
SHOW COLUMNS FROM atelier_wip_log;

-- Show indexes
SHOW INDEX FROM atelier_wip_log;

-- Check if column exists
SELECT COLUMN_NAME 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() 
AND TABLE_NAME = 'atelier_wip_log' 
AND COLUMN_NAME = 'serial_number';
```

---

## 🎯 **Quick Answers**

| Question | Answer |
|----------|--------|
| Which tables have soft-delete? | **ONLY atelier_wip_log** |
| Where is progress stored? | **Calculated from atelier_task_operator_session** |
| Can I JOIN bgerp.account? | **NO in prepared statements - use two-step** |
| Which table has serial_number? | **atelier_wip_log (will be added in 0005)** |
| How to check schema? | **SHOW CREATE TABLE {name}** |
| Where are indexes? | **See migration 0003** |

---

**See Also:**
- `database/tenant_migrations/0001_init_tenant_schema.php` - Complete schema
- `database/tenant_migrations/0003_performance_indexes.php` - All indexes
- `docs/guide/MEMORY_GUIDE.md` - Database best practices

---

**Status:** Reference complete, use before ANY database operation

