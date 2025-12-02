# Team System Requirements & Implementation Plan

**Version:** 2.0 (Production-Grade with Hybrid Model)  
**Date:** November 6, 2025  
**Status:** 📋 Planning Complete (Ready to Implement)  
**Priority:** High (Required for Manager Assignment Phase 2)  
**Document Size:** 2,000+ lines (Complete Specification)

---

## **🎯 Executive Summary**

Team System enables managers to organize operators into functional teams (e.g., Cutting Team, Sewing Team, QC Team) and assign work to teams rather than individuals. The system automatically distributes work among team members based on availability and current workload.

**Critical Design Decision:**  
**🔄 Hybrid Team Model** - Teams can serve both OEM (batch) and Atelier (serial) production modes, reflecting the reality that operators often work across both production lines with shared resources.

**Key Benefits:**
- ✅ Reduce manager workload (1 assignment → entire team)
- ✅ Automatic load balancing within teams
- ✅ Flexible staffing (handle absences automatically)
- ✅ Fair work distribution (round-robin or lowest-load)
- ✅ Scalable (add/remove team members without changing plans)
- ✅ **Shared resource pool** (operators can work on both OEM and Atelier jobs)
- ✅ **Production mode filtering** (restrict teams to specific production types when needed)

---

## **📊 Current State**

### **What's Ready:**
1. ✅ **Assignment Engine** - Core logic exists (`AssignmentEngine.php`)
2. ✅ **Plan System** - `assignment_plan_node` and `assignment_plan_job` tables
3. ✅ **API Structure** - `assignee_type` supports 'member' and 'team'
4. ✅ **User Management** - Multi-tenant account system with `user_type`
5. ✅ **Manager Assignment UI** - Plans Tab ready for team integration

### **What's Missing:**
1. ❌ **Team Tables** - `team`, `team_member`, `operator_availability`
2. ❌ **Team Management UI** - CRUD for teams and members
3. ❌ **Expand Team Logic** - `expandAssignees()` in AssignmentEngine
4. ❌ **Availability Filter** - Check operator absences/leave
5. ❌ **Load Balancing** - Pick operator with lowest current workload

---

## **🏗️ Database Schema**

### **1. Team Table**
```sql
CREATE TABLE team (
  id_team INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL COMMENT 'Team code (e.g., TEAM-CUT-01)',
  name VARCHAR(100) NOT NULL COMMENT 'Team name (e.g., ทีมตัดวัสดุ A)',
  description TEXT NULL COMMENT 'Team description/purpose',
  id_org INT NOT NULL COMMENT 'Tenant isolation (FK → organization.id_org)',
  
  -- Functional classification
  team_category ENUM('cutting','sewing','qc','finishing','general') DEFAULT 'general' 
    COMMENT 'Functional category (work station type)',
  
  -- Production mode eligibility (CRITICAL for OEM/Atelier)
  production_mode ENUM('oem','atelier','hybrid') DEFAULT 'hybrid' 
    COMMENT 'Which production type this team can serve',
  
  active TINYINT(1) DEFAULT 1 COMMENT '1=active, 0=deactivated',
  created_at DATETIME DEFAULT NOW(),
  created_by INT NULL COMMENT 'FK → account.id_member',
  updated_at DATETIME DEFAULT NOW() ON UPDATE NOW(),
  
  UNIQUE KEY uniq_code_org (code, id_org),
  INDEX idx_org_active (id_org, active),
  INDEX idx_category (team_category, active),
  INDEX idx_production_mode (production_mode, active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Notes:**
- `id_org`: Multi-tenant isolation (each tenant has separate teams)
- `code`: Human-readable identifier (unique per tenant)
- `team_category`: Functional classification (cutting, sewing, qc, etc.)
- **`production_mode`**: **CRITICAL for Dual Production Model**
  - **`oem`**: Team serves OEM production only (batch, high volume)
  - **`atelier`**: Team serves Atelier production only (serial, craft, traceable)
  - **`hybrid`**: Team serves BOTH (default, most flexible)
- `active`: Soft-delete flag (deactivate instead of delete)

**Why Hybrid Model?**
```
Reality at Bellavier Group:
- Same operators work on both OEM and Atelier jobs
- Limited resources require flexible staffing
- Operators may work OEM 3 days, Atelier 2 days

Benefits:
✅ Single team can serve both production lines
✅ Easy to move operators between modes
✅ Reflects actual workshop operations
✅ Reduced complexity (1 team system, not 2)
```

---

### **2. Team Member Table**
```sql
CREATE TABLE team_member (
  id_team INT NOT NULL COMMENT 'FK → team.id_team',
  id_member INT NOT NULL COMMENT 'FK → account.id_member (Core DB)',
  role ENUM('lead','supervisor','qc','member','trainee') DEFAULT 'member' COMMENT 'Team role hierarchy',
  capacity_per_day INT DEFAULT 0 COMMENT 'Expected output per day (optional)',
  active TINYINT(1) DEFAULT 1 COMMENT '1=active, 0=removed from team',
  joined_at DATETIME DEFAULT NOW(),
  removed_at DATETIME NULL,
  removed_by INT NULL COMMENT 'Manager who removed this member',
  notes TEXT NULL COMMENT 'Special notes about this member',
  
  PRIMARY KEY (id_team, id_member),
  FOREIGN KEY (id_team) REFERENCES team(id_team) ON DELETE CASCADE,
  INDEX idx_member (id_member, active),
  INDEX idx_role (role, active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Notes:**
- `id_member`: References `account.id_member` (Core DB)
- `role`: Team hierarchy with 5 levels:
  - **`lead`**: Team leader (manage team, override load balancing, view team stats)
  - **`supervisor`**: Senior member (can approve assignments, view all team activity)
  - **`qc`**: Quality control specialist (review work quality, special inspection tasks)
  - **`member`**: Regular operator (receive assignments, do work)
  - **`trainee`**: New member (limited assignments, requires supervision)
- `capacity_per_day`: Optional for capacity planning
- `active`: Allow removing members without deleting history
- `removed_by`: Track who removed this member (audit trail)

---

### **3. Team Member History Table** (Audit Trail)
```sql
CREATE TABLE team_member_history (
  id_history INT AUTO_INCREMENT PRIMARY KEY,
  id_team INT NOT NULL COMMENT 'FK → team.id_team',
  id_member INT NOT NULL COMMENT 'FK → account.id_member',
  action ENUM('add','remove','promote','demote','role_change') NOT NULL COMMENT 'What action occurred',
  old_role VARCHAR(20) NULL COMMENT 'Previous role (for role changes)',
  new_role VARCHAR(20) NULL COMMENT 'New role (for role changes)',
  performed_by INT NOT NULL COMMENT 'Manager who performed this action (FK → account.id_member)',
  performed_at DATETIME DEFAULT NOW(),
  reason TEXT NULL COMMENT 'Reason for this action',
  metadata JSON NULL COMMENT 'Additional context (capacity changes, etc.)',
  
  INDEX idx_team (id_team, performed_at),
  INDEX idx_member (id_member, performed_at),
  INDEX idx_action (action, performed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Notes:**
- **Purpose:** Full audit trail for all team membership changes
- **Triggered:** Automatically logged when:
  - Member added to team (`action='add'`)
  - Member removed from team (`action='remove'`)
  - Role promoted (`action='promote'`, e.g., member → lead)
  - Role demoted (`action='demote'`, e.g., lead → member)
  - Role changed laterally (`action='role_change'`, e.g., member → qc)
- **Usage:** Compliance audits, investigate disputes, analyze team stability
- **Retention:** Keep forever (no deletion, small data footprint)

---

### **4. Operator Availability Table** (Optional Phase 3)
```sql
CREATE TABLE operator_availability (
  id_availability INT AUTO_INCREMENT PRIMARY KEY,
  id_member INT NOT NULL COMMENT 'FK → account.id_member',
  date DATE NOT NULL COMMENT 'Availability date',
  shift ENUM('morning','evening','night','full') DEFAULT 'full',
  available TINYINT(1) DEFAULT 1 COMMENT '1=available, 0=unavailable (leave/sick)',
  reason VARCHAR(255) NULL COMMENT 'Reason for unavailability',
  created_at DATETIME DEFAULT NOW(),
  created_by INT NULL COMMENT 'Manager who recorded this',
  
  UNIQUE KEY uniq_member_date_shift (id_member, date, shift),
  INDEX idx_date_available (date, available),
  INDEX idx_member_date (id_member, date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Notes:**
- Records absences, leave, sick days
- Supports multiple shifts per day
- `available=0`: Operator will not receive assignments on this date/shift
- **Phase 3**: Can implement later if absence management is needed

---

### **5. Assignment Decision Log Enhancement**

**Current Schema** (from `2025_11_assignment_engine.php`):
```sql
CREATE TABLE assignment_decision_log (
  id_log INT AUTO_INCREMENT PRIMARY KEY,
  id_token INT NOT NULL COMMENT 'Token ID',
  event VARCHAR(64) NOT NULL COMMENT 'Event type',
  source VARCHAR(64) NULL COMMENT 'Assignment source',
  decision_detail TEXT NULL COMMENT 'JSON detail',
  created_at DATETIME DEFAULT NOW(),
  KEY idx_token (id_token, created_at),
  KEY idx_event (event, created_at)
);
```

**Proposed Enhancements** (for Team System + Analytics):
```sql
ALTER TABLE assignment_decision_log 
  ADD COLUMN decision_reason VARCHAR(255) NULL COMMENT 'Human-readable reason' AFTER source,
  ADD COLUMN filter_stage VARCHAR(64) NULL COMMENT 'Stage where filtering occurred (expand/skill/available/load)' AFTER decision_reason,
  ADD COLUMN candidate_count INT DEFAULT 0 COMMENT 'Total candidates considered' AFTER filter_stage,
  ADD COLUMN excluded_count INT DEFAULT 0 COMMENT 'Candidates excluded' AFTER candidate_count,
  ADD COLUMN rule_snapshot JSON NULL COMMENT 'Rules applied (skills, certs, availability, capacity)' AFTER excluded_count,
  ADD COLUMN selected_member_id INT NULL COMMENT 'Final selected member ID' AFTER rule_snapshot,
  ADD COLUMN team_id INT NULL COMMENT 'Team ID if team assignment' AFTER selected_member_id,
  KEY idx_member (selected_member_id, created_at),
  KEY idx_team (team_id, created_at);
```

**Usage Examples:**
```json
{
  "event": "assigned",
  "source": "node_plan",
  "decision_reason": "Team expanded to 3 members, picked lowest load",
  "filter_stage": "load_balancing",
  "candidate_count": 3,
  "excluded_count": 0,
  "rule_snapshot": {
    "team_id": 1,
    "team_name": "ทีมตัดวัสดุ A",
    "members": [{"id": 1, "load": 2}, {"id": 2, "load": 5}, {"id": 3, "load": 3}],
    "selected": {"id": 1, "reason": "lowest_active_count"}
  },
  "selected_member_id": 1,
  "team_id": 1
}
```

**Benefits:**
- ✅ **Fairness Audit:** Verify load balancing is truly fair
- ✅ **Performance Analysis:** Which rules filter most candidates?
- ✅ **Debugging:** Why did operator X not get assigned?
- ✅ **Compliance:** Full traceability for ISO/audit requirements

---

## **🔧 Backend Implementation**

### **1. Team API** (`source/team_api.php`)

**Endpoints:**
- `list` - List all teams (filtered by current tenant)
- `get` - Get team details with members
- `save` - Create/update team
- `delete` - Soft-delete team (set active=0)
- `members_list` - Get team members
- `member_add` - Add member to team
- `member_remove` - Remove member from team
- `member_set_lead` - Promote member to team lead
- `available_operators` - List operators NOT in this team (for adding)

**Sample Request:**
```json
POST /source/team_api.php
{
  "action": "save",
  "code": "TEAM-CUT-A",
  "name": "ทีมตัดวัสดุ A",
  "team_type": "cutting"
}
```

---

### **2. AssignmentEngine Enhancements**

**New Methods:**

#### **expandAssignees()**
```php
/**
 * Expand assignee to list of candidate member IDs
 * 
 * @param mysqli $db
 * @param string $assigneeType 'member' or 'team'
 * @param int $assigneeId member ID or team ID
 * @return int[] Array of member IDs
 */
private function expandAssignees($db, $assigneeType, $assigneeId): array {
    if ($assigneeType === 'member') {
        return [$assigneeId];
    }
    
    if ($assigneeType === 'team') {
        $stmt = $db->prepare("
            SELECT id_member 
            FROM team_member 
            WHERE id_team = ? AND active = 1
        ");
        $stmt->bind_param('i', $assigneeId);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $members = [];
        while ($row = $result->fetch_assoc()) {
            $members[] = (int)$row['id_member'];
        }
        $stmt->close();
        
        return $members;
    }
    
    return [];
}
```

#### **filterAvailable()**
```php
/**
 * Filter out operators who are unavailable (leave/sick)
 * 
 * @param mysqli $db
 * @param int[] $memberIds
 * @param string $date YYYY-MM-DD
 * @param string $shift 'morning'|'evening'|'night'|'full'
 * @return int[] Available member IDs
 */
private function filterAvailable($db, array $memberIds, string $date, string $shift = 'full'): array {
    if (empty($memberIds)) {
        return [];
    }
    
    $placeholders = implode(',', array_fill(0, count($memberIds), '?'));
    $types = str_repeat('i', count($memberIds)) . 'ss';
    
    $stmt = $db->prepare("
        SELECT id_member
        FROM operator_availability
        WHERE id_member IN ($placeholders)
          AND date = ?
          AND (shift = ? OR shift = 'full')
          AND available = 0
    ");
    
    $params = array_merge($memberIds, [$date, $shift]);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $unavailable = [];
    while ($row = $result->fetch_assoc()) {
        $unavailable[] = (int)$row['id_member'];
    }
    $stmt->close();
    
    // Return members NOT in unavailable list
    return array_diff($memberIds, $unavailable);
}
```

#### **pickByLowestLoad()** (Dynamic Load Metrics)
```php
/**
 * Pick operator with lowest current workload
 * 
 * Uses dynamic load calculation:
 * - Phase 1: Count active tokens (simple)
 * - Phase 2: Weighted by work complexity and estimated time
 * 
 * @param mysqli $db
 * @param int[] $memberIds
 * @param int $nodeId Current node ID
 * @return int|null Selected member ID
 */
private function pickByLowestLoad($db, array $memberIds, int $nodeId): ?int {
    if (empty($memberIds)) {
        return null;
    }
    
    $placeholders = implode(',', array_fill(0, count($memberIds), '?'));
    $types = str_repeat('i', count($memberIds)) . 'i';
    
    // Dynamic load calculation:
    // load_score = (active_count * 10) + (total_work_minutes / 60)
    // Prioritizes: fewer active tokens, then less accumulated time
    $stmt = $db->prepare("
        SELECT 
            ta.assigned_to_user_id,
            COUNT(DISTINCT ta.id_token) as active_count,
            COALESCE(SUM(s.work_seconds), 0) as total_work_seconds,
            (COUNT(DISTINCT ta.id_token) * 10 + COALESCE(SUM(s.work_seconds), 0) / 60) as load_score
        FROM token_assignment ta
        LEFT JOIN token_work_session s ON s.id_token = ta.id_token 
            AND s.status IN ('active','paused')
        WHERE ta.assigned_to_user_id IN ($placeholders)
          AND ta.id_node = ?
          AND ta.status IN ('assigned','accepted','started','paused')
        GROUP BY ta.assigned_to_user_id
        ORDER BY load_score ASC
        LIMIT 1
    ");
    
    $params = array_merge($memberIds, [$nodeId]);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($row = $result->fetch_assoc()) {
        $stmt->close();
        return (int)$row['assigned_to_user_id'];
    }
    $stmt->close();
    
    // If no one has work, pick first available (round-robin in future)
    return $memberIds[0] ?? null;
}
```

**Load Calculation Logic:**
- **`active_count * 10`**: Primary factor (number of active tokens)
- **`+ (work_seconds / 60)`**: Secondary factor (total minutes worked)
- **Result:** Operator with fewest active tokens wins; if tied, operator with less accumulated time wins

**Future Enhancement (Phase 2):**
```sql
-- Add estimated_minutes to atelier_job_task
ALTER TABLE atelier_job_task 
  ADD COLUMN estimated_minutes INT DEFAULT 0 COMMENT 'Est. work time per unit';

-- Then query becomes:
SELECT 
    ta.assigned_to_user_id,
    SUM(task.estimated_minutes * ticket.target_qty) as estimated_workload,
    ...
FROM token_assignment ta
JOIN flow_token t ON t.id_token = ta.id_token
JOIN job_graph_instance gi ON gi.id_instance = t.id_instance
JOIN atelier_job_ticket ticket ON ticket.id_job_ticket = gi.id_job_ticket
JOIN atelier_job_task task ON task.id_job_ticket = ticket.id_job_ticket
    AND task.id_node = ta.id_node
...
ORDER BY estimated_workload ASC
```

---

### **3. Updated assignOne() Logic**

```php
public function assignOne($db, $tokenId, $plans) {
    // ... existing PIN check ...
    
    // PLAN precedence
    foreach ($plans as $plan) {
        // 1. Expand assignee
        $candidates = $this->expandAssignees($db, $plan['assignee_type'], $plan['assignee_id']);
        
        if (empty($candidates)) {
            $this->logDecision($db, $tokenId, 'plan_empty_team', $plan['id_team'] ?? null, null);
            continue;
        }
        
        // 2. Filter available
        $today = date('Y-m-d');
        $available = $this->filterAvailable($db, $candidates, $today);
        
        if (empty($available)) {
            $this->logDecision($db, $tokenId, 'plan_all_unavailable', $plan['id_team'] ?? null, null);
            continue;
        }
        
        // 3. Pick by lowest load
        $selected = $this->pickByLowestLoad($db, $available, $plan['id_node']);
        
        if ($selected) {
            $this->insertAssignment($db, $tokenId, $selected, 'plan', $plan);
            $this->logDecision($db, $tokenId, 'plan_success', $plan['assignee_id'], $selected);
            return true;
        }
    }
    
    // ... existing AUTO fallback ...
}
```

---

## **🎨 Frontend Implementation - Complete UI Design**

### **🎯 Page Goal:**

Manager ต้องมองเห็นได้ครบใน 5 วินาที:
1. ทีมไหนกำลัง active
2. ทีมไหนมีสมาชิกครบหรือขาด
3. ทีมไหนรับงาน OEM/Atelier ได้
4. ใครเป็นหัวหน้าทีม
5. Workload ตอนนี้เป็นยังไง

---

### **1. Team Management Page - Overview**

**URL:** `index.php?p=team_management`  
**Permission:** `manager.team`  
**Template:** Bootstrap 5 + Sash Admin Theme  
**Layout:** 2-Column (Sidebar + Main Content)

---

#### **🖼️ Complete Page Layout (Wireframe):**

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│ 🏠 Home > Team Management                                    [Administrator ▼] │
├────────┬───────────────────────────────────────────────────────────────────────────┤
│        │ 👥 Team Management                          [🔍 Search...] [＋ Create Team]│
│ TEAMS  ├───────────────────────────────────────────────────────────────────────────┤
│ NAVIGA │ Filters: [Team Category: All ▼] [Production Mode: All ▼] [Status: Active ▼]│
│ TOR    │          [View: ▣ Cards  □ List  □ Table]                                 │
│        ├───────────────────────────────────────────────────────────────────────────┤
│ ⚙️ OEM  │                                                                           │
│ (2)    │ ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────┐ │
│        │ │ 🔵 TEAM-OEM-01      │  │ ⚡ TEAM-CUT-01      │  │ 👜 TEAM-ATL-01   │ │
│  • OEM │ │ ทีม OEM Production  │  │ ทีมตัดวัสดุ A       │  │ ทีมเย็บมือ Master│ │
│    A   │ │ ─────────────────── │  │ ─────────────────── │  │ ──────────────── │ │
│    (24)│ │ 🏷️ OEM Only         │  │ 🏷️ Hybrid (OEM+ATL) │  │ 🏷️ Atelier Only │ │
│        │ │                     │  │                     │  │                  │ │
│  • OEM │ │ 👤 24 members       │  │ 👤 12 members       │  │ 👤 5 members     │ │
│    B   │ │ 👑 Lead: สมชาย     │  │ 👑 Lead: สมหญิง    │  │ 👑 Lead: ประเสริฐ│ │
│    (18)│ │                     │  │                     │  │                  │ │
│        │ │ 📊 Workload Today:  │  │ 📊 Workload:        │  │ 📊 Workload:     │ │
│ 👜 ATL │ │   OEM: ███████░░ 78%│  │   OEM:  ████░░░ 45% │  │   ATL: ████░░ 42%│ │
│ (3)    │ │   ATL: ░░░░░░░░░ 0% │  │   ATL:  ███░░░░ 25% │  │   OEM: ░░░░░░ 0% │ │
│        │ │                     │  │                     │  │                  │ │
│  • ATL │ │ 🟢 5 available      │  │ 🟢 3 available      │  │ 🟢 2 available   │ │
│    A   │ │ 🔴 2 on leave       │  │ 🟡 1 on leave       │  │ 🟢 All available │ │
│    (12)│ │                     │  │                     │  │                  │ │
│        │ │ [View Detail]       │  │ [View Detail]       │  │ [View Detail]    │ │
│  • ATL │ └──────────────────────┘  └──────────────────────┘  └──────────────────┘ │
│    B   │                                                                           │
│    (10)│ ┌──────────────────────┐  ┌──────────────────────┐                       │
│        │ │ ⚡ TEAM-SEW-01      │  │ 🟣 TEAM-QC-01       │                       │
│ ⚡ HYB │ │ ทีมเย็บมือ          │  │ ทีม QC               │     (more cards...)   │
│ (2)    │ │ (continues...)      │  │ (continues...)       │                       │
│        │ └──────────────────────┘  └──────────────────────┘                       │
│  • HYB │                                                                           │
│    Br  │                                                                           │
│    (16)│                                                                           │
│        │                                                                           │
│  • HYB │                                                                           │
│    Cr  │                                                                           │
│    (8) │                                                                           │
│        │                                                                           │
└────────┴───────────────────────────────────────────────────────────────────────────┘
```

**Color Coding:**
- 🔵 **OEM Only:** `bg-primary` (blue)
- 👜 **Atelier Only:** `bg-pink-100` (pink-gray)
- ⚡ **Hybrid:** `bg-purple-100` (purple-gray)
- 🟢 **Available:** Green badge
- 🔴 **Unavailable:** Red badge
- 🟡 **Partial:** Yellow badge

---

#### **🧭 Top Navigation Bar:**

```html
<div class="d-flex justify-content-between align-items-center mb-3">
    <div>
        <h1 class="h3 mb-0">
            <i class="bi bi-people-fill"></i> 
            <?= translate('team.management', 'Team Management') ?>
        </h1>
        <p class="text-muted small mb-0">
            <?= translate('team.subtitle', 'Organize operators into teams for efficient work distribution') ?>
        </p>
    </div>
    <div>
        <input type="text" 
               id="global-search" 
               class="form-control" 
               placeholder="🔍 Search team or member..." 
               style="width: 300px;">
        <button class="btn btn-primary" id="btn-create-team">
            <i class="bi bi-plus-circle"></i> Create Team
        </button>
        <button class="btn btn-outline-secondary" id="btn-settings">
            <i class="bi bi-gear"></i> Settings
        </button>
    </div>
</div>
```

---

#### **🎛️ Filter Bar:**

```html
<div class="card mb-3">
    <div class="card-body py-2">
        <div class="row g-2 align-items-center">
            <div class="col-auto">
                <label class="form-label mb-0 me-2">Category:</label>
                <select id="filter-category" class="form-select form-select-sm" style="width: 150px;">
                    <option value="">All</option>
                    <option value="cutting">Cutting</option>
                    <option value="sewing">Sewing</option>
                    <option value="qc">QC</option>
                    <option value="finishing">Finishing</option>
                    <option value="general">General</option>
                </select>
            </div>
            <div class="col-auto">
                <label class="form-label mb-0 me-2">Production Mode:</label>
                <select id="filter-mode" class="form-select form-select-sm" style="width: 150px;">
                    <option value="">All</option>
                    <option value="oem">⚙️ OEM Only</option>
                    <option value="atelier">👜 Atelier Only</option>
                    <option value="hybrid">⚡ Hybrid</option>
                </select>
            </div>
            <div class="col-auto">
                <label class="form-label mb-0 me-2">Status:</label>
                <select id="filter-status" class="form-select form-select-sm" style="width: 120px;">
                    <option value="1">Active</option>
                    <option value="0">Inactive</option>
                    <option value="">All</option>
                </select>
            </div>
            <div class="col-auto ms-auto">
                <div class="btn-group btn-group-sm" role="group">
                    <input type="radio" class="btn-check" name="view-mode" id="view-cards" checked>
                    <label class="btn btn-outline-primary" for="view-cards">
                        <i class="bi bi-grid-3x2"></i> Cards
                    </label>
                    
                    <input type="radio" class="btn-check" name="view-mode" id="view-list">
                    <label class="btn btn-outline-primary" for="view-list">
                        <i class="bi bi-list-ul"></i> List
                    </label>
                    
                    <input type="radio" class="btn-check" name="view-mode" id="view-table">
                    <label class="btn btn-outline-primary" for="view-table">
                        <i class="bi bi-table"></i> Table
                    </label>
                </div>
            </div>
        </div>
    </div>
</div>
```

---

#### **📇 Card View (Default - Most Informative):**

```html
<div id="teams-container" class="row g-3">
    
    <!-- OEM Only Team Card -->
    <div class="col-lg-4 col-md-6">
        <div class="card team-card border-primary" data-team-id="1" data-mode="oem">
            <div class="card-header bg-primary bg-opacity-10 border-primary">
                <div class="d-flex justify-content-between align-items-start">
                    <div>
                        <span class="badge bg-primary">⚙️ OEM Only</span>
                        <h5 class="mt-2 mb-0">ทีม OEM Production</h5>
                        <small class="text-muted">TEAM-OEM-01</small>
                    </div>
                    <div class="dropdown">
                        <button class="btn btn-sm btn-light" data-bs-toggle="dropdown">
                            <i class="bi bi-three-dots-vertical"></i>
                        </button>
                        <ul class="dropdown-menu">
                            <li><a class="dropdown-item" href="#" data-action="edit">✏️ Edit</a></li>
                            <li><a class="dropdown-item" href="#" data-action="view">👁️ View Detail</a></li>
                            <li><a class="dropdown-item" href="#" data-action="analytics">📊 Analytics</a></li>
                            <li><hr class="dropdown-divider"></li>
                            <li><a class="dropdown-item text-danger" href="#" data-action="deactivate">❌ Deactivate</a></li>
                        </ul>
                    </div>
                </div>
            </div>
            <div class="card-body">
                <!-- Members Info -->
                <div class="d-flex align-items-center mb-3">
                    <i class="bi bi-people-fill fs-4 me-2 text-primary"></i>
                    <div>
                        <strong>24 members</strong><br>
                        <small class="text-muted">👑 Lead: สมชาย</small>
                    </div>
                </div>
                
                <!-- Workload Progress -->
                <div class="mb-3">
                    <div class="d-flex justify-content-between mb-1">
                        <small>OEM Workload:</small>
                        <small class="text-primary"><strong>78%</strong> (42/54 jobs)</small>
                    </div>
                    <div class="progress" style="height: 8px;">
                        <div class="progress-bar bg-primary" role="progressbar" style="width: 78%"></div>
                    </div>
                    
                    <div class="d-flex justify-content-between mb-1 mt-2">
                        <small>Atelier Workload:</small>
                        <small class="text-muted"><strong>0%</strong> (N/A)</small>
                    </div>
                    <div class="progress" style="height: 8px;">
                        <div class="progress-bar bg-secondary bg-opacity-25" role="progressbar" style="width: 0%"></div>
                    </div>
                </div>
                
                <!-- Availability Status -->
                <div class="mb-3">
                    <div class="d-flex justify-content-between">
                        <span class="badge bg-success">🟢 22 available</span>
                        <span class="badge bg-danger">🔴 2 on leave</span>
                    </div>
                </div>
                
                <!-- Skills (if available from People System) -->
                <div class="mb-2">
                    <small class="text-muted">Skills:</small><br>
                    <span class="badge bg-light text-dark me-1">Machine Cutting</span>
                    <span class="badge bg-light text-dark">Batch Assembly</span>
                </div>
                
                <!-- Action Buttons -->
                <div class="d-grid gap-2">
                    <button class="btn btn-sm btn-outline-primary" data-action="view-detail">
                        <i class="bi bi-eye"></i> View Detail
                    </button>
                </div>
            </div>
            <div class="card-footer bg-light">
                <small class="text-muted">
                    <i class="bi bi-clock-history"></i> Updated 2 minutes ago
                </small>
            </div>
        </div>
    </div>
    
    <!-- Hybrid Team Card -->
    <div class="col-lg-4 col-md-6">
        <div class="card team-card border-purple" data-team-id="2" data-mode="hybrid">
            <div class="card-header bg-purple bg-opacity-10 border-purple">
                <div class="d-flex justify-content-between align-items-start">
                    <div>
                        <span class="badge" style="background: linear-gradient(90deg, #0d6efd 50%, #d63384 50%);">
                            ⚡ OEM + Atelier
                        </span>
                        <h5 class="mt-2 mb-0">ทีมตัดวัสดุ A</h5>
                        <small class="text-muted">TEAM-CUT-01</small>
                    </div>
                    <div class="dropdown">...</div>
                </div>
            </div>
            <div class="card-body">
                <div class="d-flex align-items-center mb-3">
                    <i class="bi bi-people-fill fs-4 me-2" style="color: #6f42c1;"></i>
                    <div>
                        <strong>12 members</strong><br>
                        <small class="text-muted">👑 Lead: สมหญิง</small>
                    </div>
                </div>
                
                <!-- Dual Workload (OEM + Atelier) -->
                <div class="mb-3">
                    <div class="d-flex justify-content-between mb-1">
                        <small>⚙️ OEM:</small>
                        <small class="text-primary"><strong>45%</strong> (9/20)</small>
                    </div>
                    <div class="progress" style="height: 6px;">
                        <div class="progress-bar bg-primary" style="width: 45%"></div>
                    </div>
                    
                    <div class="d-flex justify-content-between mb-1 mt-2">
                        <small>👜 Atelier:</small>
                        <small style="color: #d63384;"><strong>25%</strong> (3/12)</small>
                    </div>
                    <div class="progress" style="height: 6px;">
                        <div class="progress-bar" style="width: 25%; background: #d63384;"></div>
                    </div>
                    
                    <div class="mt-2 p-2 bg-light rounded">
                        <small class="text-muted">
                            Combined: <strong>65%</strong> utilization
                        </small>
                    </div>
                </div>
                
                <div class="mb-3">
                    <div class="d-flex justify-content-between">
                        <span class="badge bg-success">🟢 11 available</span>
                        <span class="badge bg-warning">🟡 1 on leave</span>
                    </div>
                </div>
                
                <div class="d-grid gap-2">
                    <button class="btn btn-sm btn-outline-primary" data-action="view-detail">
                        <i class="bi bi-eye"></i> View Detail
                    </button>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Atelier Only Team Card -->
    <div class="col-lg-4 col-md-6">
        <div class="card team-card border-pink" data-team-id="3" data-mode="atelier">
            <div class="card-header" style="background: rgba(214, 51, 132, 0.1); border-color: #d63384;">
                <div class="d-flex justify-content-between align-items-start">
                    <div>
                        <span class="badge" style="background: #d63384;">👜 Atelier Only</span>
                        <h5 class="mt-2 mb-0">ทีมเย็บมือ Master</h5>
                        <small class="text-muted">TEAM-ATL-01</small>
                    </div>
                    <div class="dropdown">...</div>
                </div>
            </div>
            <div class="card-body">
                <div class="d-flex align-items-center mb-3">
                    <i class="bi bi-people-fill fs-4 me-2" style="color: #d63384;"></i>
                    <div>
                        <strong>5 members</strong><br>
                        <small class="text-muted">👑 Lead: ประเสริฐ</small>
                    </div>
                </div>
                
                <div class="mb-3">
                    <div class="d-flex justify-content-between mb-1">
                        <small>Atelier Workload:</small>
                        <small style="color: #d63384;"><strong>42%</strong> (5/12)</small>
                    </div>
                    <div class="progress" style="height: 8px;">
                        <div class="progress-bar" style="width: 42%; background: #d63384;"></div>
                    </div>
                    
                    <div class="mt-2">
                        <small class="text-muted">OEM: N/A (Atelier specialist)</small>
                    </div>
                </div>
                
                <div class="mb-3">
                    <span class="badge bg-success">🟢 All available</span>
                </div>
                
                <div class="mb-2">
                    <small class="text-muted">Master Skills:</small><br>
                    <span class="badge bg-light text-dark me-1">Hand Sewing</span>
                    <span class="badge bg-light text-dark">Edge Painting</span>
                </div>
                
                <div class="d-grid gap-2">
                    <button class="btn btn-sm btn-outline-primary" data-action="view-detail">
                        <i class="bi bi-eye"></i> View Detail
                    </button>
                </div>
            </div>
        </div>
    </div>
    
</div>
```

---

#### **📱 Left Sidebar: Team Navigator (Quick Jump):**

```html
<div class="card sticky-top" style="top: 80px; max-height: calc(100vh - 100px); overflow-y: auto;">
    <div class="card-header bg-light">
        <strong>Teams (12)</strong>
    </div>
    <div class="list-group list-group-flush">
        
        <!-- OEM Section -->
        <div class="list-group-item bg-light py-1">
            <small class="text-muted fw-bold">⚙️ OEM (2)</small>
        </div>
        <a href="#team-1" class="list-group-item list-group-item-action team-nav-item active" data-team-id="1">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <strong>OEM Alpha</strong><br>
                    <small class="text-muted">24 members</small>
                </div>
                <span class="badge bg-primary">78%</span>
            </div>
        </a>
        <a href="#team-2" class="list-group-item list-group-item-action team-nav-item" data-team-id="2">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <strong>OEM Beta</strong><br>
                    <small class="text-muted">18 members</small>
                </div>
                <span class="badge bg-primary">65%</span>
            </div>
        </a>
        
        <!-- Atelier Section -->
        <div class="list-group-item bg-light py-1">
            <small class="text-muted fw-bold">👜 Atelier (3)</small>
        </div>
        <a href="#team-3" class="list-group-item list-group-item-action team-nav-item" data-team-id="3">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <strong>Atelier A</strong><br>
                    <small class="text-muted">12 members</small>
                </div>
                <span class="badge" style="background: #d63384;">42%</span>
            </div>
        </a>
        <a href="#team-4" class="list-group-item list-group-item-action team-nav-item" data-team-id="4">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <strong>Atelier B</strong><br>
                    <small class="text-muted">10 members</small>
                </div>
                <span class="badge" style="background: #d63384;">38%</span>
            </div>
        </a>
        <a href="#team-5" class="list-group-item list-group-item-action team-nav-item" data-team-id="5">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <strong>Master Craft</strong><br>
                    <small class="text-muted">5 members</small>
                </div>
                <span class="badge" style="background: #d63384;">20%</span>
            </div>
        </a>
        
        <!-- Hybrid Section -->
        <div class="list-group-item bg-light py-1">
            <small class="text-muted fw-bold">⚡ Hybrid (2)</small>
        </div>
        <a href="#team-6" class="list-group-item list-group-item-action team-nav-item" data-team-id="6">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <strong>Hybrid Bravo</strong><br>
                    <small class="text-muted">16 members</small>
                </div>
                <span class="badge" style="background: #6f42c1;">65%</span>
            </div>
        </a>
        <a href="#team-7" class="list-group-item list-group-item-action team-nav-item" data-team-id="7">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <strong>Hybrid Cross</strong><br>
                    <small class="text-muted">8 members</small>
                </div>
                <span class="badge" style="background: #6f42c1;">52%</span>
            </div>
        </a>
        
    </div>
    <div class="card-footer">
        <button class="btn btn-sm btn-primary w-100" id="btn-create-team-sidebar">
            <i class="bi bi-plus-circle"></i> New Team
        </button>
    </div>
</div>
```

---

### **2. Team Detail Drawer (Side Panel)**

**Trigger:** Click "View Detail" on any team card  
**Animation:** Slide from right (Offcanvas component)  
**Width:** 600px  
**Behavior:** Overlay (doesn't push main content)

---

#### **🎨 Team Detail Drawer Layout:**

```
┌─────────────────────────────────────────────────────────────┐
│ [✕ Close]          Team: Hybrid Team Bravo                  │
│                    ⚡ OEM + 👜 Atelier                       │
├─────────────────────────────────────────────────────────────┤
│ Lead: Somchai      Status: 🟢 Active      [✏️ Edit Team]   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ 📊 WORKLOAD SUMMARY (Today)                                │
│                                                             │
│ ⚙️ OEM:           ████████░░░ 65%  (13/20 jobs)            │
│ 👜 Atelier:       ███░░░░░░░░ 25%  (3/12 serials)          │
│ ─────────────────────────────────────────────────────────  │
│ Combined Utilization: 78%                                   │
│ Available Capacity: 22% (can take 8 more jobs)             │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ 📋 ASSIGNMENT PREVIEW                          [Assign →]  │
├─────────────────────────────────────────────────────────────┤
│ Pending work this team can receive:                         │
│                                                             │
│ ⚙️ OEM: 12 jobs waiting (Node: ตัดวัสดุ)                   │
│ 👜 Atelier: 3 serials waiting (Node: เย็บ)                 │
│                                                             │
│ [Auto-Assign to Team] → Will distribute among members      │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ 👥 MEMBERS (16)          [＋ Add] [⚙️ Bulk] [🔍 Filter]    │
├─────────────────────────────────────────────────────────────┤
│ Filters: [Role: All ▼] [Mode: All ▼] [Status: All ▼]       │
│ Bulk: [☐ Select All] [Set Role ▼] [Mark Leave] [Remove]   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐│
│ │ ☐ 👑 Kittisak (Lead)                  [Edit Role ▼]    ││
│ │ Position: Cutter | Eligible: ⚙️ OEM, 👜 Atelier        ││
│ │ Current: 🟢 Working - 4 jobs (2 OEM, 2 Atelier)        ││
│ │ Load: ████████░░ 75%                                    ││
│ │ [View Schedule] [View Profile] [View Work]             ││
│ └─────────────────────────────────────────────────────────┘│
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐│
│ │ 🔧 Natee (Supervisor)                 [Edit Role ▼]    ││
│ │ Position: Edge Painter | Eligible: 👜 Atelier Only     ││
│ │ Current: 🟢 Working - 3 serials                         ││
│ │ Load: ██████░░░░ 60%                                    ││
│ └─────────────────────────────────────────────────────────┘│
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐│
│ │ 👷 Arisa (Member)                     [Edit Role ▼]    ││
│ │ Position: QC Inspector | Eligible: ⚙️ OEM Only         ││
│ │ Current: 🔴 On Leave (Sick) - Until Nov 8              ││
│ │ Load: ░░░░░░░░░░ 0%                                     ││
│ └─────────────────────────────────────────────────────────┘│
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐│
│ │ 🆕 Somchai (Trainee)                  [Edit Role ▼]    ││
│ │ Position: Assistant | Eligible: ⚙️ OEM Only            ││
│ │ Current: 🟢 Idle - 0 jobs                               ││
│ │ Load: ░░░░░░░░░░ 0%  👈 Lowest (will get next job)     ││
│ └─────────────────────────────────────────────────────────┘│
│                                                             │
│ ... (12 more members, scrollable)                          │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ 📦 CURRENT WORK (Real-time)              [Refresh]         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ⚙️ OEM#4512 | In Progress | สมชาย | 10:05 → ETA 10:45    │
│ 👜 AT#0071 | ✅ Completed | Natee  | 09:00 → 09:42        │
│ ⚙️ OEM#4513 | ⏸️ Paused   | Somchai| 09:30 (paused 15min) │
│ 👜 AT#0072 | 🟡 Starting | Kittisak | Just assigned       │
│                                                             │
│ [View All Jobs →]                                           │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ 📈 ANALYTICS                  [Period: 7 Days ▼] [Full →]  │
├─────────────────────────────────────────────────────────────┤
│ Period: [Today] [7 Days] [30 Days] [Custom Range]          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ **🎯 4 Core KPIs:**                                         │
│                                                             │
│ 1️⃣ Team Utilization (Combined)                             │
│    ████████░░ 78% (target: 70-85%)                          │
│    ├─ OEM:     ████████░░░ 65% (13/20 jobs)                │
│    └─ Atelier: ███░░░░░░░░ 25% (3/12 serials)              │
│                                                             │
│ 2️⃣ Average Task Time                                       │
│    ├─ OEM:     11.3 min/piece (↓ 8% vs last week)          │
│    └─ Atelier: 23.8 min/serial (→ stable)                  │
│                                                             │
│ 3️⃣ Availability Rate                                       │
│    ████████░░ 91% (15/16 members available)                │
│    🔴 1 on leave (back Nov 8)                               │
│                                                             │
│ 4️⃣ Top Bottleneck                                          │
│    ⚠️ Node "เย็บ" - 85% load (near capacity)               │
│    💡 Recommend: Add 1 member or reduce assignment          │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ Top 3 Performers (Last 7 Days):                             │
│   🥇 Natee (Edge Paint) - 18 serials, 99% quality          │
│   🥈 Sompong (QC) - 95 inspections, 0 defects              │
│   🥉 Arisa (Cutter) - 450 pieces, 92% efficiency           │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ 📜 HISTORY (Audit Trail)                    [Filter ▼]     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Nov 6, 10:30 - Manager (Administrator)                      │
│   ➕ Added member: Somchai                                 │
│   Role: trainee | Reason: New hire                         │
│                                                             │
│ Nov 5, 14:15 - Manager (Administrator)                      │
│   🔄 Role changed: Natee                                   │
│   member → supervisor | Reason: Promotion                   │
│                                                             │
│ Nov 4, 09:00 - Manager (Administrator)                      │
│   ➖ Removed member: Preecha                               │
│   Reason: Transferred to OEM team                           │
│                                                             │
│ [Load More...] (from team_member_history)                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Key Features:**
- ✅ **Sticky header** (team name always visible)
- ✅ **Real-time workload** (updates every 15 seconds via polling)
- ✅ **Member cards** with role badges (👑 Lead, 🔧 Supervisor, 👷 Member, 🆕 Trainee)
- ✅ **Production mode eligibility** per member (⚙️ OEM, 👜 Atelier)
- ✅ **Current status** (🟢 Working, 🔴 On Leave, 🟡 Starting, ⏸️ Paused)
- ✅ **Load visualization** (progress bars)
- ✅ **Current work feed** (live from token_work_session)
- ✅ **Quick analytics** (embedded summary)
- ✅ **Scrollable** (long member lists)

---

### **3. Create/Edit Team Modal**

**Trigger:** Click "Create Team" button or "Edit" from dropdown  
**Size:** Large modal (800px width)  
**Tabs:** Basic Info | Members | Settings

---

#### **🖊️ Tab 1: Basic Info**

```html
<!-- Modal: Create/Edit Team -->
<div class="modal fade" id="modal-team" tabindex="-1">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">
                    <i class="bi bi-people-fill"></i> Create Team
                </h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                
                <!-- Team Code & Name -->
                <div class="row mb-3">
                    <div class="col-md-6">
                        <label class="form-label">Team Code <span class="text-danger">*</span></label>
                        <div class="input-group">
                            <input type="text" 
                                   id="team-code" 
                                   class="form-control" 
                                   placeholder="TEAM-CUT-01">
                            <button class="btn btn-outline-secondary" 
                                    type="button" 
                                    id="btn-auto-code"
                                    title="Auto-generate code">
                                <i class="bi bi-magic"></i>
                            </button>
                        </div>
                        <small class="form-text text-muted">Format: TEAM-{CATEGORY}-{NN}</small>
                    </div>
                    <div class="col-md-6">
                        <label class="form-label">Team Name <span class="text-danger">*</span></label>
                        <input type="text" 
                               id="team-name" 
                               class="form-control" 
                               placeholder="ทีมตัดวัสดุ A">
                    </div>
                </div>
                
                <!-- Team Category & Production Mode -->
                <div class="row mb-3">
                    <div class="col-md-6">
                        <label class="form-label">Team Category</label>
                        <select id="team-category" class="form-select">
                            <option value="general">General</option>
                            <option value="cutting">Cutting</option>
                            <option value="sewing">Sewing</option>
                            <option value="qc">QC</option>
                            <option value="finishing">Finishing</option>
                        </select>
                        <small class="form-text text-muted">Functional classification (work station type)</small>
                    </div>
                    <div class="col-md-6">
                        <label class="form-label">Production Mode <span class="text-danger">*</span></label>
                        <select id="production-mode" class="form-select">
                            <option value="hybrid" selected>⚡ Hybrid (OEM + Atelier)</option>
                            <option value="oem">⚙️ OEM Only</option>
                            <option value="atelier">👜 Atelier Only</option>
                        </select>
                        <div id="mode-help" class="alert alert-info mt-2 small">
                            <strong>⚡ Hybrid:</strong> Team can work on both OEM (batch) and Atelier (serial) jobs. 
                            Best for teams with mixed skills. <strong>Recommended for most teams.</strong>
                        </div>
                    </div>
                </div>
                
                <!-- Production Mode Help (Dynamic) -->
                <script>
                $('#production-mode').on('change', function() {
                    const mode = $(this).val();
                    const helps = {
                        'hybrid': '<strong>⚡ Hybrid:</strong> Team can work on both OEM (batch) and Atelier (serial) jobs. Best for teams with mixed skills. <strong>Recommended for most teams.</strong>',
                        'oem': '<strong>⚙️ OEM Only:</strong> Team specializes in high-volume batch production. Will ONLY receive OEM assignments. Good for machine-based operations.',
                        'atelier': '<strong>👜 Atelier Only:</strong> Team specializes in craft/luxury production. Will ONLY receive Atelier assignments. Good for master artisans.'
                    };
                    $('#mode-help').html(helps[mode]);
                });
                </script>
                
                <!-- Team Lead -->
                <div class="row mb-3">
                    <div class="col-md-12">
                        <label class="form-label">Team Lead</label>
                        <select id="team-lead" class="form-select">
                            <option value="">Select Lead...</option>
                            <!-- Populated from current members or all operators -->
                        </select>
                        <small class="form-text text-muted">
                            Team Lead can view team stats and approve assignments
                        </small>
                    </div>
                </div>
                
                <!-- Description -->
                <div class="mb-3">
                    <label class="form-label">Description</label>
                    <textarea id="team-description" 
                              class="form-control" 
                              rows="3" 
                              placeholder="Team purpose, specialization, notes..."></textarea>
                </div>
                
                <!-- Status -->
                <div class="form-check form-switch">
                    <input class="form-check-input" 
                           type="checkbox" 
                           id="team-active" 
                           checked>
                    <label class="form-check-label" for="team-active">
                        Active (Team will receive assignments)
                    </label>
                </div>
                
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" id="btn-save-team">
                    <i class="bi bi-save"></i> Save Team
                </button>
            </div>
        </div>
    </div>
</div>
```

**Auto-Code Generation Logic:**
```javascript
$('#btn-auto-code').on('click', function() {
    const category = $('#team-category').val();
    const mode = $('#production-mode').val();
    
    // Prefix based on mode
    const prefixes = {
        'oem': 'OEM',
        'atelier': 'ATL',
        'hybrid': category.toUpperCase().substring(0, 3)
    };
    
    const prefix = prefixes[mode] || 'TEAM';
    
    // Get next number (query existing teams)
    $.post('source/team_api.php', { action: 'get_next_code', prefix: prefix }, function(resp) {
        if (resp.ok) {
            $('#team-code').val(resp.code); // e.g., "TEAM-CUT-03"
        }
    });
});
```

---

### **4. Manage Members Modal (Add/Remove)**

**Trigger:** Click "＋ Add" or "⚙️ Manage" in Team Detail Drawer  
**Layout:** Dual-panel (Available | Current)

```
┌───────────────────────────────────────────────────────────────────────┐
│ Manage Team Members: ทีมตัดวัสดุ A                                    │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│ ┌─────────────────────────────┐  ┌─────────────────────────────────┐│
│ │ 👤 AVAILABLE OPERATORS (8) │  │ 👥 CURRENT MEMBERS (12)         ││
│ │ [🔍 Search...]             │  │ [🔍 Filter...]                  ││
│ ├─────────────────────────────┤  ├─────────────────────────────────┤│
│ │                             │  │                                 ││
│ │ ☐ สมศรี                    │  │ 👑 Kittisak (Lead)     [Remove]││
│ │   Cutter | ⚙️👜            │  │   4 jobs | 75% load             ││
│ │   Available               ➡️│  │                                 ││
│ │                             │  │ 🔧 Natee (Supervisor)  [Remove]││
│ │ ☐ ประยุทธ                  │  │   3 jobs | 60% load             ││
│ │   Sewer | 👜 Only          │  │                                 ││
│ │   Available               ➡️│  │ 👷 Arisa (Member)      [Remove]││
│ │                             │  │   🔴 On Leave                   ││
│ │ ☐ วิชัย                    │  │                                 ││
│ │   QC | ⚙️ Only             │  │ 🆕 Somchai (Trainee)   [Remove]││
│ │   Available               ➡️│  │   0 jobs | Idle                 ││
│ │                             │  │                                 ││
│ │ [Select All] [Add (0)]     │  │ ... (8 more members)            ││
│ │                             │  │                                 ││
│ └─────────────────────────────┘  │ [Bulk Actions ▼]               ││
│                                   └─────────────────────────────────┘│
│                                                                       │
│ Selected: 0 operators                                                 │
│                                                                       │
├───────────────────────────────────────────────────────────────────────┤
│ [Close]                                         [Save Changes]        │
└───────────────────────────────────────────────────────────────────────┘
```

**Interaction:**
1. ✅ **Checkbox Select:** Select operators to add (multi-select)
2. ✅ **Arrow Button (➡️):** Add selected operators immediately
3. ✅ **Remove Button:** Remove member from team (confirm dialog)
4. ✅ **Bulk Actions:** Set Role, Mark Unavailable, etc.
5. ✅ **Filter:** Filter by production mode eligibility (⚙️ OEM, 👜 Atelier)
6. ✅ **Real-time Load:** Show current workload (prevent over-loading)

**Smart Features:**
```javascript
// Warn if adding operator with incompatible mode
if (team.production_mode === 'oem' && operator.eligible_modes === 'atelier') {
    Swal.fire({
        title: 'Warning',
        html: 'Operator <strong>' + operator.name + '</strong> is Atelier specialist.<br>' +
              'This team is OEM only.<br><br>Add anyway?',
        icon: 'warning',
        showCancelButton: true
    });
}

// Suggest role based on experience
if (operator.years_experience > 5) {
    suggestRole = 'supervisor';
} else if (operator.years_experience > 2) {
    suggestRole = 'member';
} else {
    suggestRole = 'trainee';
}
```

---

---

### **6. User Experience Flow Diagram**

**Manager Journey - Team Management:**

```
START → Login as Manager
  ↓
Navigate to "Team Management" page
  ↓
See Team Overview (Cards) ← Auto-refresh every 30s
  ├─ Grouped by: OEM | Atelier | Hybrid
  ├─ Visual: Color-coded cards
  ├─ Info: Members, Load, Availability
  └─ Quick actions: View Detail, Edit, Analytics
  ↓
Filter by Production Mode (optional) ← Instant filter
  ├─ OEM Only → Show 2 teams
  ├─ Atelier Only → Show 3 teams
  └─ Hybrid → Show 2 teams
  ↓
Click "View Detail" on a team
  ↓
Drawer slides in from right ← Smooth animation
  ├─ Team summary at top
  ├─ Member list (scrollable)
  ├─ Current work feed (real-time)
  └─ Quick analytics
  ↓
Options in Drawer:
  ├─ [＋ Add Member] → Opens dual-panel modal
  │   ↓
  │   Select operators → Check eligibility → Add → Log history
  │   
  ├─ [Edit Role] → Inline dropdown
  │   ↓
  │   Change role → Confirm → Log to team_member_history
  │   
  ├─ [Remove] → Confirm dialog
  │   ↓
  │   Soft-delete (active=0) → Log to history
  │   
  └─ [View Analytics] → Full dashboard (future)
  ↓
Close Drawer → Return to Overview
  ↓
Create New Team (if needed):
  ├─ Click "＋ Create Team"
  ├─ Fill form (Code, Name, Category, Mode, Lead)
  ├─ Production Mode help updates dynamically
  ├─ Save → Team created → Auto-open drawer to add members
  └─ Add members → Team ready
  ↓
Navigate to Manager Assignment page
  ↓
Create Plan with Team:
  ├─ Plans Tab → Assignee Type: "Team"
  ├─ Select team → Preview members
  ├─ Engine will distribute work among members
  └─ Workload balanced automatically
  ↓
END
```

**Key UX Principles:**
- **At-a-glance:** All critical info visible without clicks
- **Low context switching:** Drawers/modals, not page navigation
- **Color coding:** Instant recognition (OEM blue, Atelier pink, Hybrid purple)
- **Real-time:** Workload updates every 15-30 seconds
- **Smart validation:** Warn incompatible mode assignments
- **Audit trail:** All changes logged automatically

---

### **7. Component Library & Styling**

**Technology Stack:**
- **Framework:** Bootstrap 5.3
- **Template:** Sash Admin Theme
- **Icons:** Bootstrap Icons
- **Notifications:** Toastr
- **Dialogs:** SweetAlert2
- **AJAX:** jQuery 3.7.1
- **Real-time:** JavaScript polling (15s interval)

**Custom CSS Classes:**

```css
/* Team Mode Colors */
.team-card.border-primary { border-left: 4px solid #0d6efd !important; }      /* OEM */
.team-card.border-pink { border-left: 4px solid #d63384 !important; }          /* Atelier */
.team-card.border-purple { border-left: 4px solid #6f42c1 !important; }        /* Hybrid */

.bg-purple { background-color: #6f42c1; }
.bg-purple.bg-opacity-10 { background-color: rgba(111, 66, 193, 0.1); }
.bg-pink-100 { background-color: rgba(214, 51, 132, 0.1); }
.text-pink { color: #d63384; }

/* Mode Badges */
.badge-oem { background: #0d6efd; }
.badge-atelier { background: #d63384; }
.badge-hybrid { background: linear-gradient(90deg, #0d6efd 50%, #d63384 50%); }

/* Workload Bars */
.progress-bar-oem { background: #0d6efd; }
.progress-bar-atelier { background: #d63384; }

/* Role Icons */
.role-lead::before { content: '👑 '; }
.role-supervisor::before { content: '🔧 '; }
.role-qc::before { content: '🔍 '; }
.role-member::before { content: '👷 '; }
.role-trainee::before { content: '🆕 '; }

/* Status Indicators */
.status-working { color: #198754; }
.status-idle { color: #6c757d; }
.status-leave { color: #dc3545; }
.status-paused { color: #ffc107; }

/* Drawer */
.team-detail-drawer {
    width: 600px;
    box-shadow: -2px 0 8px rgba(0,0,0,0.1);
}

/* Sticky elements */
.sticky-sidebar {
    position: sticky;
    top: 80px;
    max-height: calc(100vh - 100px);
    overflow-y: auto;
}
```

**Bootstrap Components Used:**
- `card` - Team cards, drawer sections
- `badge` - Mode indicators, counts, status
- `progress` - Workload visualization
- `offcanvas` - Team detail drawer
- `modal` - Create/Edit team, Manage members
- `dropdown` - Action menus, role selection
- `list-group` - Sidebar navigation, member lists
- `form-select` - Filters, dropdowns
- `btn-group` - View mode toggle (Cards/List/Table)

---

### **8. Interaction Behaviors**

**Real-time Updates:**
```javascript
// Poll for team workload updates every 15 seconds
setInterval(function() {
    if (currentView === 'cards') {
        refreshTeamCards();
    }
    if (drawerOpen) {
        refreshDrawerWorkload(currentTeamId);
    }
}, 15000);

function refreshTeamCards() {
    $.post('source/team_api.php', { action: 'list_with_stats' }, function(resp) {
        if (resp.ok) {
            updateCardWorkloads(resp.data);
        }
    });
}
```

**Smart Filtering:**
```javascript
// Production mode filter
$('#filter-mode').on('change', function() {
    const mode = $(this).val();
    
    if (mode === '') {
        $('.team-card').show(); // Show all
    } else {
        $('.team-card').hide();
        $(`.team-card[data-mode="${mode}"]`).show();
    }
    
    updateSidebarCounts();
});

// Search (fuzzy match)
$('#global-search').on('keyup', debounce(function() {
    const query = $(this).val().toLowerCase();
    
    $('.team-card').each(function() {
        const teamName = $(this).find('h5').text().toLowerCase();
        const teamCode = $(this).find('.text-muted').first().text().toLowerCase();
        const leadName = $(this).find('.text-muted').eq(1).text().toLowerCase();
        
        const match = teamName.includes(query) || 
                      teamCode.includes(query) || 
                      leadName.includes(query);
        
        $(this).toggle(match);
    });
}, 300));
```

**Drawer Animations:**
```javascript
// Open drawer
function openTeamDrawer(teamId) {
    // Show loading skeleton
    showDrawerSkeleton();
    
    // Fetch team details
    $.post('source/team_api.php', { action: 'get_detail', id: teamId }, function(resp) {
        if (resp.ok) {
            renderDrawer(resp.data);
            
            const drawer = new bootstrap.Offcanvas('#team-drawer');
            drawer.show();
            
            // Start real-time updates
            startDrawerPolling(teamId);
        } else {
            showDrawerError(resp.error);
        }
    }).fail(function() {
        showDrawerError('Connection timeout. Please try again.');
    });
}

// Close drawer
$('#team-drawer').on('hidden.bs.offcanvas', function() {
    stopDrawerPolling();
});
```

---

### **State Handling (Empty/Error/Loading):**

**1. Loading States:**

```html
<!-- Loading Skeleton for Cards -->
<div class="col-lg-4 col-md-6">
    <div class="card placeholder-glow">
        <div class="card-header">
            <span class="placeholder col-6"></span>
        </div>
        <div class="card-body">
            <span class="placeholder col-8 mb-2"></span>
            <span class="placeholder col-5"></span>
            <div class="placeholder col-12" style="height: 8px;"></div>
            <span class="placeholder col-4 mt-2"></span>
        </div>
    </div>
</div>

<!-- Loading State for Drawer -->
<div id="drawer-loading" style="display:none;">
    <div class="text-center py-5">
        <div class="spinner-border text-primary" role="status">
            <span class="visually-hidden">Loading...</span>
        </div>
        <p class="text-muted mt-3">Loading team details...</p>
    </div>
</div>
```

**2. Empty States:**

```html
<!-- No Teams Found -->
<div id="empty-teams" class="text-center py-5" style="display:none;">
    <i class="bi bi-inbox fs-1 text-muted"></i>
    <h5 class="mt-3 text-muted">No teams found</h5>
    <p class="text-muted">
        No teams match your filters, or no teams have been created yet.
    </p>
    <button class="btn btn-primary" id="btn-create-first-team">
        <i class="bi bi-plus-circle"></i> Create Your First Team
    </button>
</div>

<!-- No Members in Team -->
<div id="empty-members" class="alert alert-warning" style="display:none;">
    <i class="bi bi-exclamation-triangle"></i>
    <strong>No members in this team</strong>
    <p class="mb-2">This team has no active members. Add members to start assigning work.</p>
    <button class="btn btn-sm btn-warning" data-action="add-members">
        <i class="bi bi-plus-circle"></i> Add Members Now
    </button>
</div>

<!-- No Work Assigned -->
<div id="empty-work" style="display:none;">
    <div class="text-center py-3 text-muted">
        <i class="bi bi-inbox"></i>
        <p class="mb-0">No active work for this team</p>
    </div>
</div>
```

**3. Error States:**

```html
<!-- API Error Banner -->
<div id="error-banner" class="alert alert-danger alert-dismissible" style="display:none;">
    <i class="bi bi-exclamation-circle"></i>
    <strong>Error loading data</strong>
    <p class="mb-2" id="error-message"></p>
    <div class="btn-group btn-group-sm">
        <button class="btn btn-sm btn-outline-danger" onclick="location.reload()">
            <i class="bi bi-arrow-clockwise"></i> Reload Page
        </button>
        <button class="btn btn-sm btn-outline-danger" id="btn-retry-load">
            <i class="bi bi-arrow-repeat"></i> Retry
        </button>
    </div>
    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
</div>

<!-- People System Offline (Degraded Mode) -->
<div id="degraded-mode-banner" class="alert alert-warning" style="display:none;">
    <i class="bi bi-exclamation-triangle"></i>
    <strong>Limited Mode:</strong> 
    People System unavailable. Showing basic info only (names from local cache).
    <small class="text-muted">Skills and profiles not available.</small>
</div>

<!-- Workload Calculation Timeout -->
<div class="workload-error" style="display:none;">
    <small class="text-danger">
        <i class="bi bi-x-circle"></i> Workload unavailable
        <button class="btn btn-sm btn-link p-0" onclick="refreshWorkload(this)">Retry</button>
    </small>
</div>
```

**JavaScript Error Handling:**

```javascript
function refreshTeamCards() {
    $.post('source/team_api.php', { action: 'list_with_stats' }, function(resp) {
        if (resp.ok) {
            if (resp.data.length === 0) {
                $('#teams-container').hide();
                $('#empty-teams').show();
            } else {
                $('#empty-teams').hide();
                $('#teams-container').show();
                updateCardWorkloads(resp.data);
            }
            $('#error-banner').hide();
        } else {
            showError(resp.error || 'Failed to load teams');
        }
    }).fail(function(xhr, status, error) {
        showError('Connection error: ' + status);
    });
}

function showError(message) {
    $('#error-message').text(message);
    $('#error-banner').slideDown();
    
    // Auto-hide after 10 seconds
    setTimeout(function() {
        $('#error-banner').slideUp();
    }, 10000);
}
```

---

### **10. Manager Experience Matrix**

**What Managers Can Do (One-Page Control):**

| Action | Location | Clicks | No Page Switch |
|--------|----------|--------|----------------|
| **View all teams** | Team Overview | 0 | ✅ Auto-loaded |
| **See team workload** | Card (real-time) | 0 | ✅ |
| **Filter by mode** | Filter bar | 1 | ✅ Instant |
| **View team details** | Click card → Drawer | 1 | ✅ Overlay |
| **Add member** | Drawer → Add button | 2 | ✅ Modal |
| **Remove member** | Drawer → Remove | 2 | ✅ Confirm |
| **Change role** | Drawer → Role dropdown | 1 | ✅ Inline |
| **Create team** | Top button → Modal | 1 | ✅ Modal |
| **Assign team to job** | Manager Assignment page | - | Navigate |
| **View analytics** | Drawer → Analytics | 1 | ✅ Embedded |

**Average Time to Complete:**
- Create new team: **2 minutes** (vs 5+ minutes with page navigation)
- Add 5 members: **1 minute** (dual-panel, multi-select)
- Check team status: **5 seconds** (at-a-glance cards)
- Rebalance assignments: **30 seconds** (from Manager Assignment)

---

### **11. Accessibility & Responsiveness**

**Responsive Breakpoints:**
```css
/* Desktop (≥1200px): 3 cards per row */
.col-lg-4 { width: 33.33%; }

/* Tablet (768-1199px): 2 cards per row */
.col-md-6 { width: 50%; }

/* Mobile (<768px): 1 card per row, drawer becomes fullscreen */
@media (max-width: 767px) {
    .team-detail-drawer { width: 100vw; }
    .sticky-sidebar { position: static; }
    
    /* Mobile-specific */
    .filter-bar { 
        /* Collapsible filters */
        max-height: 0;
        overflow: hidden;
        transition: max-height 0.3s ease;
    }
    .filter-bar.open { max-height: 200px; }
    
    /* Floating CTA */
    .btn-create-team-mobile {
        position: fixed;
        bottom: 20px;
        right: 20px;
        border-radius: 50%;
        width: 56px;
        height: 56px;
        box-shadow: 0 4px 8px rgba(0,0,0,0.3);
        z-index: 1000;
    }
    
    /* Card adjustments */
    .team-card .card-body { padding: 12px; }
    .team-card h5 { font-size: 1rem; }
}
```

**Mobile-Specific Behaviors:**

| Feature | Desktop | Mobile |
|---------|---------|--------|
| **Cards per row** | 3 | 1 (full width) |
| **Sidebar** | Sticky left | Hidden (collapsible menu) |
| **Filters** | Always visible | Collapsible (toggle button) |
| **Search** | Top right | Top (full width) |
| **Create button** | Header | Floating bottom-right (FAB) |
| **Drawer** | 600px slide-in | Fullscreen overlay |
| **Workload bars** | Dual bars | Stacked (OEM top, Atelier bottom) |
| **Member cards** | Full info | Compact (name + load only) |
| **Analytics** | Embedded | Separate tab/page |

**PWA Specific:**

```javascript
// Service Worker caching
if ('serviceWorker' in navigator) {
    // Cache team list for offline
    caches.open('team-data-v1').then(cache => {
        cache.add('/source/team_api.php?action=list');
    });
}

// Offline detection
window.addEventListener('offline', function() {
    $('#offline-banner').show();
    $('#btn-create-team').prop('disabled', true);
    stopPolling(); // Stop real-time updates
});

window.addEventListener('online', function() {
    $('#offline-banner').hide();
    $('#btn-create-team').prop('disabled', false);
    refreshTeamCards(); // Immediate refresh
    startPolling();
});
```

**Keyboard Navigation:**
- `Tab` - Navigate between cards
- `Enter` - Open drawer for focused card
- `Esc` - Close drawer/modal
- `Ctrl+F` - Focus global search
- `Ctrl+N` - Create new team

**Screen Reader Support:**
```html
<button aria-label="View details for team ทีมตัดวัสดุ A">
    View Detail
</button>

<div role="status" aria-live="polite">
    Team workload updated: 65%
</div>
```

---

### **12. Production Mode Visual Guide**

**Quick Reference for Managers:**

```
┌─────────────────────────────────────────────────────────────┐
│ 📖 Production Mode Guide                                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ⚙️ OEM Only                                                │
│ ────────────────────────────────────────────────────────   │
│ • High-volume batch production                              │
│ • Measured by: Pieces/hour                                  │
│ • KPI: Efficiency (output vs target)                        │
│ • Team receives: ONLY OEM tokens                            │
│ • Example: Machine cutting, bulk assembly                   │
│ • Color: 🔵 Blue                                            │
│                                                             │
│ 👜 Atelier Only                                             │
│ ────────────────────────────────────────────────────────   │
│ • Craft/luxury production                                   │
│ • Measured by: Minutes/serial                               │
│ • KPI: Quality (QC pass rate) + Traceability                │
│ • Team receives: ONLY Atelier tokens                        │
│ • Example: Hand sewing, edge painting, master craft         │
│ • Color: 🟣 Pink                                            │
│                                                             │
│ ⚡ Hybrid (Recommended)                                      │
│ ────────────────────────────────────────────────────────   │
│ • Can do BOTH OEM and Atelier                               │
│ • Measured by: Separate KPIs per mode                       │
│ • KPI: Combined utilization                                 │
│ • Team receives: Both OEM and Atelier tokens                │
│ • Example: Flexible teams, general stations                 │
│ • Color: 🟣 Purple (gradient)                               │
│                                                             │
│ When to use which:                                          │
│ • Use HYBRID for: Most teams (90% of cases)                │
│ • Use OEM ONLY for: Dedicated machine/batch operations     │
│ • Use ATELIER ONLY for: Master craftsmen specialists       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## **📋 Implementation Phases**

### **Phase 1: Core Team System (Week 1)**

**Priority:** Must Have

**Tasks:**
- [ ] Create migration `2025_11_team_system.php`
  - [ ] `team` table
  - [ ] `team_member` table
- [ ] Create `source/team_api.php`
  - [ ] list, get, save, delete
  - [ ] members_list, member_add, member_remove, member_set_lead
- [ ] Create `views/team_management.php`
  - [ ] Team DataTable
  - [ ] Create/Edit modal
  - [ ] Manage Members modal
- [ ] Create `assets/javascripts/team/management.js`
- [ ] Add permission `manager.team`
- [ ] Update sidebar menu

**Deliverables:**
- ✅ Managers can create/edit teams
- ✅ Managers can add/remove members
- ✅ Teams stored in database (multi-tenant)

---

### **Phase 2: Assignment Engine Integration (Week 2)**

**Priority:** Must Have

**Tasks:**
- [ ] Update `AssignmentEngine::assignOne()`
  - [ ] Implement `expandAssignees()`
  - [ ] Implement `pickByLowestLoad()`
- [ ] Update `assignment_plan_api.php`
  - [ ] Validate team assignments
  - [ ] Preview team members endpoint
- [ ] Update `views/manager_assignment.php`
  - [ ] Team option in assignee type
  - [ ] Team dropdown
  - [ ] Preview button
- [ ] Update `assets/javascripts/manager/assignment.js`
  - [ ] Handle team selection
  - [ ] Show preview modal
- [ ] Add to `assignment_decision_log`
  - [ ] Log team expansions
  - [ ] Log picked member from team

**Deliverables:**
- ✅ Managers can assign work to teams
- ✅ Engine auto-picks member with lowest load
- ✅ Assignment decisions logged

---

### **Phase 3: Availability Management (Week 3)**

**Priority:** Nice to Have (Optional)

**Tasks:**
- [ ] Create `operator_availability` table
- [ ] Create `source/availability_api.php`
  - [ ] CRUD availability records
  - [ ] Calendar view data
- [ ] Create `views/operator_availability.php`
  - [ ] Calendar UI
  - [ ] Mark unavailable dates
- [ ] Update `AssignmentEngine::assignOne()`
  - [ ] Implement `filterAvailable()`
  - [ ] Skip unavailable operators
- [ ] Add notification system
  - [ ] Notify manager if all team members unavailable

**Deliverables:**
- ✅ Managers can record operator absences
- ✅ Engine skips unavailable operators
- ✅ System warns if team cannot fulfill assignment

---

### **Phase 4: Team Performance Analytics (Optional - Future)**

**Priority:** Nice to Have (for data-driven management)

**Purpose:** Provide managers with insights into team performance, productivity, and load balance

**New Tables:**

```sql
-- Daily team statistics (summary table)
CREATE TABLE team_daily_stats (
  id_stat INT AUTO_INCREMENT PRIMARY KEY,
  id_team INT NOT NULL COMMENT 'FK → team.id_team',
  date DATE NOT NULL COMMENT 'Statistics date',
  total_assignments INT DEFAULT 0 COMMENT 'Total tokens assigned',
  completed INT DEFAULT 0 COMMENT 'Tokens completed',
  avg_load_score DECIMAL(10,2) DEFAULT 0 COMMENT 'Average load per member',
  availability_rate DECIMAL(5,2) DEFAULT 100.00 COMMENT '% of members available',
  avg_completion_time INT DEFAULT 0 COMMENT 'Avg minutes to complete (seconds)',
  created_at DATETIME DEFAULT NOW(),
  
  UNIQUE KEY uniq_team_date (id_team, date),
  INDEX idx_date (date, id_team)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Team leaderboard view (materialized)
CREATE TABLE team_leaderboard (
  id_team INT PRIMARY KEY,
  team_name VARCHAR(100),
  week_start DATE NOT NULL COMMENT 'Week starting date',
  total_completed INT DEFAULT 0,
  avg_daily_output DECIMAL(10,2) DEFAULT 0,
  quality_score DECIMAL(5,2) DEFAULT 100.00 COMMENT '% QC pass rate',
  efficiency_rank INT DEFAULT 0 COMMENT 'Rank among all teams',
  updated_at DATETIME DEFAULT NOW(),
  
  INDEX idx_week (week_start, efficiency_rank)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**Analytics Endpoints:**

```php
// source/team_analytics_api.php

case 'team_performance':
    // GET /team_analytics_api.php?action=team_performance&id_team=1&period=week
    // Response: { productivity, quality, avg_load, trend }

case 'team_leaderboard':
    // GET /team_analytics_api.php?action=team_leaderboard&period=week
    // Response: [{ rank, team_name, output, quality }, ...]

case 'operator_distribution':
    // GET /team_analytics_api.php?action=operator_distribution&id_team=1&date=2025-11-06
    // Response: [{ operator_name, assigned, completed, load_score }, ...]
```

**Dashboard UI:**

```
┌─────────────────────────────────────────────────┐
│ Team Performance Dashboard                      │
├─────────────────────────────────────────────────┤
│ Select Team: [ทีมตัดวัสดุ A ▼] Period: [Week ▼]│
├─────────────────────────────────────────────────┤
│ KPIs:                                           │
│   Productivity:  85 tokens/week  (+12% ↑)      │
│   Quality:       98.5% QC pass   (+1.2% ↑)     │
│   Avg Load:      4.2 tokens/operator           │
│   Availability:  95% (1 member on leave)       │
├─────────────────────────────────────────────────┤
│ Member Distribution:                            │
│   สมชาย:    18 assigned, 16 completed (89%)    │
│   สมหญิง:   22 assigned, 21 completed (95%)    │
│   สมศักดิ์:  20 assigned, 19 completed (95%)    │
├─────────────────────────────────────────────────┤
│ Trend (Last 4 Weeks):                           │
│   📈 Chart: Productivity increasing             │
│   📊 Chart: Load variance decreasing (good)     │
└─────────────────────────────────────────────────┘

Leaderboard (This Week):
┌────┬──────────────┬────────┬─────────┬──────┐
│ #  │ Team         │ Output │ Quality │ Eff  │
├────┼──────────────┼────────┼─────────┼──────┤
│ 1🏆│ ทีมเย็บ Master│  120   │  99.2%  │ 98%  │
│ 2🥈│ ทีมตัดวัสดุ A │   85   │  98.5%  │ 92%  │
│ 3🥉│ ทีม QC       │   65   │  100%   │ 88%  │
└────┴──────────────┴────────┴─────────┴──────┘
```

**Benefits:**
- ✅ **Manager Insight:** See which teams are performing well
- ✅ **Load Balance:** Identify teams with uneven distribution
- ✅ **Trend Analysis:** Spot performance issues early
- ✅ **Motivation:** Gamification via leaderboard
- ✅ **Resource Planning:** Data-driven hiring/training decisions

**Implementation:**
- **Week 8-9:** Database schema + daily aggregation job
- **Week 10:** Analytics API endpoints
- **Week 11:** Dashboard UI
- **Week 12:** Testing + polish

---

## **🧪 Testing Strategy**

### **Unit Tests**

**File:** `tests/Unit/TeamServiceTest.php`

```php
public function testExpandTeamMembers()
public function testFilterAvailableOperators()
public function testPickByLowestLoad()
public function testTeamAssignmentWithEmptyTeam()
public function testTeamAssignmentWithAllUnavailable()
```

---

### **Integration Tests**

**File:** `tests/Integration/TeamAssignmentTest.php`

```php
public function testCreateTeamWithMembers()
public function testAssignTokenToTeam()
public function testTeamMemberReceivesWork()
public function testLoadBalancingBetweenMembers()
public function testSkipUnavailableMember()
```

---

### **Manual Test Cases**

1. **Create Team:**
   - Create team "ทีมตัดวัสดุ A"
   - Add 3 members
   - Set 1 as team lead
   - Verify in database

2. **Assign Work to Team:**
   - Create Node Plan: Node "ตัดวัสดุ" → Team "ทีมตัดวัสดุ A"
   - Spawn tokens to "เริ่มต้น"
   - Complete tokens → route to "ตัดวัสดุ"
   - Verify tokens assigned to team members (not team itself)
   - Verify load balanced (each member gets similar count)

3. **Handle Unavailability:**
   - Mark 1 member as unavailable (sick leave)
   - Assign work to team
   - Verify sick member does NOT receive work
   - Verify work distributed among available members only

4. **Team Deactivation:**
   - Deactivate team
   - Verify cannot create new plans for this team
   - Verify existing plans still show team name (historical)

---

## **🔒 Security & Permissions**

### **Permission Matrix (Complete Visibility & Actions):**

| Role | Permission | View Teams | Create Team | Edit Team | Delete Team | Add Member | Remove Member | Edit Role | View Analytics | Assign Work |
|------|------------|------------|-------------|-----------|-------------|------------|---------------|-----------|----------------|-------------|
| **Manager** | `manager.team` | ✅ All | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Team Lead** | `team.lead.view` | ✅ Own | ❌ | ⚠️ Limited | ❌ | ⚠️ Request | ⚠️ Request | ✅ Own team | ✅ Own | ⚠️ Own team |
| **Supervisor** | `team.supervisor.view` | ✅ All | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ All | ✅ All |
| **QC** | `team.qc.view` | ✅ Own | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ QC only | ❌ |
| **Operator** | `operator.view_team` | ✅ Own | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **HR Manager** | `hr.availability.edit` | ✅ All | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ Availability | ❌ |

**Legend:**
- ✅ Full access
- ❌ No access
- ⚠️ Limited (requires approval or own scope only)

**Detailed Permission Rules:**

| Action | Manager | Team Lead | Supervisor | Operator |
|--------|---------|-----------|------------|----------|
| **View team list** | All teams | Own team | All teams (read-only) | Own team (read-only) |
| **View team details** | All teams | Own team | All teams | Own team (members only) |
| **View member profiles** | All members | Own team members | All members | Own team members (names only) |
| **View workload** | All teams | Own team | All teams | Own load only |
| **Create team** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Edit team info** | ✅ Yes | ⚠️ Description only | ❌ No | ❌ No |
| **Deactivate team** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Add member** | ✅ Yes | ⚠️ Request (manager approves) | ❌ No | ❌ No |
| **Remove member** | ✅ Yes | ⚠️ Request (manager approves) | ❌ No | ❌ No |
| **Change member role** | ✅ Yes | ⚠️ Within team | ❌ No | ❌ No |
| **Assign work to team** | ✅ Yes | ⚠️ Own team | ✅ Yes (any team) | ❌ No |
| **View analytics** | ✅ All teams | ✅ Own team | ✅ All teams | ❌ No |
| **Edit availability** | ⚠️ Via HR | ❌ No | ❌ No | ⚠️ Self only |

**UI Visibility Rules:**

```javascript
// Team Lead sees own team only
if (currentUserRole === 'team_lead') {
    const myTeamId = getCurrentUserTeamId();
    
    // Hide other teams
    $('.team-card').each(function() {
        if ($(this).data('team-id') !== myTeamId) {
            $(this).hide();
        }
    });
    
    // Disable create button
    $('#btn-create-team').prop('disabled', true).attr('title', 'Manager only');
    
    // Limited edit (description only)
    $('#team-code, #production-mode, #team-category').prop('disabled', true);
}

// Operator sees team member names only (no workload)
if (currentUserRole === 'operator') {
    $('.workload-section').hide();
    $('.analytics-section').hide();
    $('.btn-assign-work').hide();
}
```

### **Access Control Rules:**

#### **1. Multi-Tenant Isolation:**
```php
// All team queries MUST filter by id_org
$stmt = $db->prepare("
    SELECT * FROM team 
    WHERE id_org = ? AND active = 1
");
$stmt->bind_param('i', $currentOrg);

// Prevent cross-tenant visibility/modification
// Enforced at:
// - team_api.php (all endpoints)
// - AssignmentEngine (expandAssignees check)
// - Manager Assignment UI (dropdown filtering)
```

#### **2. Role-Based Access:**
```php
// Team CRUD: Manager only
function createTeam($data) {
    global $member;
    must_allow_code($member, 'manager.team');
    // ... implementation
}

// Team Lead: View own team stats only
function viewTeamStats($teamId) {
    global $member;
    
    // Check if user is lead of this team
    $isLead = checkTeamRole($member['id_member'], $teamId, 'lead');
    if (!$isLead) {
        must_allow_code($member, 'manager.team'); // Fallback to manager
    }
    // ... implementation
}

// Override load balancing (Team Lead/Supervisor only)
function overrideAssignment($tokenId, $memberId) {
    global $member;
    
    must_allow_code($member, 'team.lead.approve'); // or team.supervisor.approve
    // ... implementation
}
```

#### **3. Data Visibility:**
- **Manager:** See all teams in tenant
- **Team Lead:** See own team only
- **Supervisor:** See all teams (read-only)
- **Operator:** See own team members (names only)
- **Cross-Tenant:** Never visible (strict isolation)

#### **4. Audit Trail:**
```php
// Log all sensitive operations
function logTeamChange($action, $teamId, $details) {
    global $member;
    
    insertLog([
        'id_team' => $teamId,
        'action' => $action,
        'performed_by' => $member['id_member'],
        'ip_address' => $_SERVER['REMOTE_ADDR'],
        'user_agent' => $_SERVER['HTTP_USER_AGENT'],
        'details' => json_encode($details)
    ]);
}

// Logged actions:
// - team_created, team_deleted
// - member_added, member_removed
// - role_changed, assignment_override
```

### **Security Checklist:**
- [ ] All team queries filter by `id_org`
- [ ] Permission checks before every operation
- [ ] Team Lead can only access own team
- [ ] Assignment decisions logged with user context
- [ ] Cross-tenant access prevented (tested)
- [ ] Audit trail enabled for sensitive operations
- [ ] SQL injection prevention (prepared statements)
- [ ] XSS prevention (output escaping)

---

## **📈 Success Metrics**

### **Overall Team System:**

1. **Manager Efficiency:**
   - Time to assign 100 tokens: Before (manual) vs After (team)
   - Target: 50% reduction in assignment time

2. **Load Distribution:**
   - Variance in tokens per operator (within team)
   - Target: <20% variance (fair distribution)

3. **System Adoption:**
   - % of assignments using teams vs manual
   - Target: >60% by Month 2

4. **Error Rate:**
   - Assignment conflicts or failures
   - Target: <1% error rate

---

### **Production Mode Specific (OEM vs Atelier):**

**OEM Production Metrics:**
| Metric | Measurement | Target |
|--------|-------------|--------|
| **Efficiency** | Output vs Target (pieces) | ≥ 90% |
| **Throughput** | Pieces per operator per day | ≥ 100 pieces/day |
| **Variance** | Workload distribution among members | ≤ 15% |
| **Mode Accuracy** | % correct production mode filtering | 100% |

**Atelier Production Metrics:**
| Metric | Measurement | Target |
|--------|-------------|--------|
| **Quality** | QC pass rate | ≥ 98% |
| **Avg Time** | Minutes per serial number | Monitor (no target) |
| **Traceability** | % serials with complete operator trace | 100% |
| **Mode Accuracy** | % correct production mode filtering | 100% |

**Hybrid Team Metrics:**
| Metric | Measurement | Target |
|--------|-------------|--------|
| **Flexibility** | % time spent on each mode | Monitor balance |
| **Context Switch** | Avg switches between modes per week | ≤ 3 switches/week |
| **Combined Utilization** | (OEM load + Atelier load) / capacity | 70-85% |
| **Cost Separation** | Accuracy of mode-specific cost tracking | 100% |

**Load Balance Formula (Hybrid Teams):**
```
combined_load_score = (oem_pieces / 100) + (atelier_serials * 10)

Explanation:
- OEM: 1 piece = 0.01 load point (100 pieces = 1 point)
- Atelier: 1 serial = 10 load points (reflects higher complexity)
- This prevents comparing "apples to oranges"
- Engine picks operator with lowest combined score
```

---

## **🔄 Why Hybrid Team Model? (Strategic Context)**

### **Production Reality at Bellavier Group:**

| Dimension | OEM Production | Atelier Production | Reality |
|-----------|----------------|-------------------|---------|
| **Volume** | 100-500 pieces/batch | 1-10 pieces/order | Same workshop |
| **Focus** | Efficiency (output/hour) | Craftsmanship (quality) | Same operators |
| **Measurement** | Pieces completed | Serial traceability | Need both KPIs |
| **Scheduling** | Predictable (batch) | Variable (custom) | Shared calendar |
| **Resources** | Machines + operators | Hand tools + operators | **Limited staff** |

### **Why NOT Separate Teams?**

**❌ Dedicated Teams (team_oem_* vs team_atelier_*):**

**Problems:**
- Operators who can do both must belong to 2 teams
- Availability must be synced across teams (complex)
- Idle time if one line is busy while other is slow
- Harder to cross-train operators
- More complex DB schema and UI

**Example Problem:**
```
สมชาย: Member of both "ทีม OEM ตัดวัสดุ" AND "ทีม Atelier ตัดวัสดุ"
→ If he's on leave, must update 2 team records
→ Load balancing must check both teams
→ KPIs split across 2 team IDs
```

---

### **✅ Why Hybrid Model Works:**

**Benefits:**
1. **Reflects Reality:**
   - Single team `ทีมตัดวัสดุ A` can serve both OEM and Atelier
   - Operators naturally shift between modes based on demand
   
2. **Simplified Management:**
   - Manager creates 1 team, not 2
   - Operators belong to 1 team
   - Single availability calendar
   
3. **Flexible Staffing:**
   - Monday-Wednesday: Team does OEM (high volume)
   - Thursday-Friday: Same team does Atelier (luxury orders)
   - Engine tracks load separately but assigns from same pool
   
4. **Cost Accounting:**
   - System tracks which tokens are OEM vs Atelier
   - Reports separate costs per production mode
   - No need for separate team structures

**Example Flow:**
```
Job Created: 
  → atelier_job_ticket (production_type = 'atelier')
  → Spawns tokens to Graph
  → Node "ตัดวัสดุ" (production_type = 'atelier')

Assignment Plan:
  → Node 2 (ตัดวัสดุ) → Team "ทีมตัดวัสดุ A"
  → Team.production_mode = 'hybrid' ✅ Compatible
  → Engine expands to members
  → Picks สมหญิง (lowest Atelier load)
  
Result:
  ✅ Token assigned correctly
  ✅ KPI tracked as Atelier work
  ✅ Team remains flexible for OEM next week
```

---

### **Comparison Matrix:**

| Approach | Teams Needed | Operator Membership | Load Calc | KPI Tracking | Flexibility |
|----------|--------------|---------------------|-----------|--------------|-------------|
| **Separate** | 2x (OEM + Atelier) | Duplicate | Complex | Simple | Low |
| **Hybrid** | 1x (shared) | Single | Simple | Separate by mode | High ✅ |

**Decision:** Use **Hybrid Model** for Phase 1-3, scale to dedicated teams only if >100 operators or clear mode specialization emerges.

---

## **🚧 Known Limitations**

1. **Skills Not Included (Phase 1):**
   - Team system does NOT check operator skills
   - Assumes all team members qualified for team's work
   - Skill matching deferred to external "People System"
   - **Mitigation:** Managers manually verify team member skills when creating teams

2. **Simple Load Balancing (Phase 1):**
   - Current: Count active tokens + work seconds
   - Formula: `(active_count * 10) + (work_seconds / 60)`
   - Future: Consider work complexity, estimated hours, operator speed
   - **Mitigation:** Good enough for fair distribution (variance <20%)

3. **No Shift Management (Phase 1):**
   - Availability is date-based, not shift-specific
   - Phase 3 can add shift support if needed
   - **Mitigation:** Most Bellavier operations run single shift

4. **No Dynamic Teams:**
   - Team membership is static (manual changes)
   - Future: Auto-suggest teams based on skills, location, etc.
   - **Mitigation:** Team Lead can request member additions via manager

5. **Production Mode Filtering (Phase 1 - Simple):**
   - Uses basic `production_mode` column (oem/atelier/hybrid)
   - No per-operator mode eligibility yet
   - Future: Add `team_production_mode` table for granular control
   - **Mitigation:** Hybrid teams (default) work for 90% of scenarios

---

## **🔗 Integration Points**

### **1. People System Integration** (Future - When People DB Available)

**Current State:**
- Team System uses `account.id_member` directly from Core DB
- No external People System exists yet
- Operator data managed within ERP

**Future Integration Strategy:**

#### **Data Ownership:**
| Data Type | Owner | Storage |
|-----------|-------|---------|
| Operator Profile | People System | `people.operator_profile` |
| Skills & Certifications | People System | `people.operator_skill`, `people.certification` |
| Team Membership | ERP (Team System) | `team`, `team_member` |
| Work Assignment | ERP (Team System) | `token_assignment`, `token_work_session` |
| Load Metrics | ERP (Team System) | Calculated from active tokens |

#### **Service Interface:**
```php
/**
 * People Directory Service (when People System ready)
 */
class PeopleDirectory {
    /**
     * Get available operators for team
     * 
     * @param int $orgId Organization ID
     * @param array $filters ['skills' => [], 'position' => '', 'available' => true]
     * @return array Operator list with profiles
     */
    public function getAvailableOperators($orgId, $filters = []): array;
    
    /**
     * Get operator skills
     * 
     * @param int $memberId Operator ID
     * @return array Skills with levels
     */
    public function getOperatorSkills($memberId): array;
    
    /**
     * Verify operator qualification for node
     * 
     * @param int $memberId Operator ID
     * @param int $nodeId Node ID requiring skills
     * @return bool Qualified or not
     */
    public function isQualifiedForNode($memberId, $nodeId): bool;
}
```

#### **Caching Strategy:**
```
Sync Schedule: Hourly cache refresh
Cache Table: team_member_cache (local copy in tenant DB)

Columns:
- id_member INT
- name VARCHAR(150)
- skills JSON (cached from People System)
- position VARCHAR(100)
- last_synced_at DATETIME
- is_available TINYINT(1)

Benefits:
✅ Prevent cross-DB latency
✅ Fallback if People System down
✅ Faster queries for load balancing

Fallback Strategy:
- If People System unavailable → use cache (max 15 min old)
- If cache expired → allow basic assignment (log warning)
- If cache empty → use account.name only (degraded mode)
```

#### **Integration Sequence:**
1. **Phase 1:** Team System uses Core DB only (current plan)
2. **Phase 2:** People System created → sync basic profiles
3. **Phase 3:** Add skill filtering to AssignmentEngine
4. **Phase 4:** Real-time availability sync with People System

**Note:** Team System is designed to work **without** People System initially. Skills integration is **optional** and can be added later when People System is ready.

---

### **2. Production Mode Integration** (OEM vs Atelier)

**Problem Statement:**  
Bellavier Group operates **dual production models** simultaneously:
- **OEM Production:** Batch-based, high volume, efficiency-focused, standard SKUs
- **Atelier Production:** Serial-based, craft-focused, traceable, custom/luxury

**Challenge:**  
Same operators and teams serve **both production lines** with limited resources, requiring flexible cross-mode assignment while maintaining separate KPIs and cost accounting.

---

#### **Solution: Hybrid Team Model**

**Architecture:**
```
┌─────────────────────────────────────────────┐
│ Team: "ทีมตัดวัสดุ A"                       │
│ production_mode: 'hybrid'                   │
├─────────────────────────────────────────────┤
│ Members:                                    │
│  • สมชาย (OEM specialist)                  │
│  • สมหญิง (Atelier specialist)             │
│  • สมศักดิ์ (Can do both)                   │
├─────────────────────────────────────────────┤
│ This Week:                                  │
│  • OEM Load: 50 pieces (สมชาย, สมศักดิ์)    │
│  • Atelier Load: 3 bags (สมหญิง)           │
└─────────────────────────────────────────────┘
```

**Database Design:**

**Option A: Simple (Recommended for Phase 1):**
```sql
-- Just use production_mode in team table
ALTER TABLE team 
  ADD COLUMN production_mode ENUM('oem','atelier','hybrid') DEFAULT 'hybrid';

-- Filtering logic in AssignmentEngine
WHERE (
  node.production_type IS NULL
  OR team.production_mode = 'hybrid'
  OR team.production_mode = node.production_type
)
```

**Option B: Granular (Phase 2 - if needed):**
```sql
-- Allow per-team production mode control
CREATE TABLE team_production_mode (
  id_team INT NOT NULL,
  production_mode ENUM('oem','atelier') NOT NULL,
  allowed TINYINT(1) DEFAULT 1 COMMENT '1=allowed, 0=restricted',
  priority INT DEFAULT 10 COMMENT 'Priority for this mode (lower = higher priority)',
  max_concurrent_jobs INT DEFAULT 0 COMMENT '0=unlimited',
  created_at DATETIME DEFAULT NOW(),
  
  PRIMARY KEY (id_team, production_mode),
  INDEX idx_allowed (allowed, priority)
) ENGINE=InnoDB;

-- Example:
-- Team A: OEM allowed (priority 5), Atelier allowed (priority 10)
-- → Prefer OEM assignments, but can do Atelier if needed
```

**Recommendation:** Start with **Option A** (simple production_mode column). Add `team_production_mode` table only if managers need fine-grained control.

---

#### **Assignment Engine Logic (Production Mode Filtering):**

```php
/**
 * Filter teams by production mode compatibility
 * 
 * @param mysqli $db
 * @param int[] $teamIds
 * @param string|null $nodeProductionType 'oem'|'atelier'|null
 * @return int[] Compatible team IDs
 */
private function filterByProductionMode($db, array $teamIds, ?string $nodeProductionType): array {
    if (empty($teamIds) || $nodeProductionType === null) {
        return $teamIds; // No filtering if no production type specified
    }
    
    $placeholders = implode(',', array_fill(0, count($teamIds), '?'));
    $types = str_repeat('i', count($teamIds)) . 's';
    
    $stmt = $db->prepare("
        SELECT id_team
        FROM team
        WHERE id_team IN ($placeholders)
          AND (
            production_mode = 'hybrid'
            OR production_mode = ?
          )
          AND active = 1
    ");
    
    $params = array_merge($teamIds, [$nodeProductionType]);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $compatible = [];
    while ($row = $result->fetch_assoc()) {
        $compatible[] = (int)$row['id_team'];
    }
    $stmt->close();
    
    return $compatible;
}

// Usage in assignOne():
public function assignOne($db, $tokenId, $plans) {
    // Get node production type
    $node = $this->getNodeInfo($db, $nodeId);
    $productionType = $node['production_type'] ?? null; // From routing_node table
    
    foreach ($plans as $plan) {
        if ($plan['assignee_type'] === 'team') {
            // Check if team is compatible with production mode
            $compatible = $this->filterByProductionMode($db, [$plan['assignee_id']], $productionType);
            
            if (empty($compatible)) {
                $this->logDecision($db, $tokenId, 'plan_incompatible_mode', $plan['assignee_id'], null);
                continue; // Skip this team, try next plan
            }
        }
        
        // ... rest of assignment logic
    }
}
```

---

#### **Operator-Level Eligibility (Phase 2 - with People System):**

When People System is available, add operator-level production mode eligibility:

```sql
-- In People System DB (future)
ALTER TABLE operator_profile 
  ADD COLUMN eligible_modes SET('oem','atelier') DEFAULT 'oem,atelier' 
    COMMENT 'Which production modes this operator is qualified for';

-- Example:
-- Operator A: 'oem,atelier' (can do both)
-- Operator B: 'atelier' (craft specialist, not OEM)
-- Operator C: 'oem' (batch production only, not craft)

-- In AssignmentEngine:
private function filterByOperatorEligibility($db, array $memberIds, string $productionType): array {
    // Query from People System cache
    $stmt = $db->prepare("
        SELECT id_member
        FROM team_member_cache
        WHERE id_member IN (...)
          AND FIND_IN_SET(?, eligible_modes) > 0
    ");
    $stmt->bind_param('s', $productionType);
    // ...
}
```

---

#### **Load Balancing Across Production Modes:**

**Separate Load Tracking:**
```sql
-- Don't mix OEM and Atelier loads (different metrics)
SELECT 
    ta.assigned_to_user_id,
    
    -- OEM load (count pieces)
    SUM(CASE 
      WHEN n.production_type = 'oem' 
      THEN ticket.target_qty 
      ELSE 0 
    END) as oem_load,
    
    -- Atelier load (count tokens/serials)
    SUM(CASE 
      WHEN n.production_type = 'atelier' 
      THEN 1 
      ELSE 0 
    END) as atelier_load,
    
    -- Combined score (normalized)
    ((oem_load / 100) + (atelier_load * 10)) as combined_load_score
    
FROM token_assignment ta
JOIN flow_token t ON t.id_token = ta.id_token
JOIN routing_node n ON n.id_node = t.current_node_id
JOIN job_graph_instance gi ON gi.id_instance = t.id_instance
JOIN atelier_job_ticket ticket ON ticket.id_job_ticket = gi.id_job_ticket
WHERE ta.assigned_to_user_id IN (...)
  AND ta.status IN ('assigned','accepted','started','paused')
GROUP BY ta.assigned_to_user_id
ORDER BY combined_load_score ASC;
```

---

#### **KPI Separation (Critical for Cost Accounting):**

**Team Performance by Production Mode:**
```sql
-- Separate OEM and Atelier metrics
CREATE TABLE team_daily_stats (
  id_stat INT AUTO_INCREMENT PRIMARY KEY,
  id_team INT NOT NULL,
  date DATE NOT NULL,
  production_mode ENUM('oem','atelier') NOT NULL,  -- Separate rows per mode
  
  -- OEM metrics
  oem_pieces_assigned INT DEFAULT 0,
  oem_pieces_completed INT DEFAULT 0,
  oem_avg_efficiency DECIMAL(5,2) DEFAULT 0 COMMENT '% output vs target',
  
  -- Atelier metrics
  atelier_serials_assigned INT DEFAULT 0,
  atelier_serials_completed INT DEFAULT 0,
  atelier_avg_time_per_piece INT DEFAULT 0 COMMENT 'Minutes per serial',
  
  -- Common
  availability_rate DECIMAL(5,2) DEFAULT 100.00,
  
  UNIQUE KEY uniq_team_date_mode (id_team, date, production_mode),
  INDEX idx_date_mode (date, production_mode)
);
```

**Dashboard Display:**
```
┌─────────────────────────────────────────────────┐
│ Team Performance: ทีมตัดวัสดุ A (Hybrid)        │
├─────────────────────────────────────────────────┤
│ OEM Production (This Week):                     │
│   Output: 450 pieces                            │
│   Efficiency: 92% of target                     │
│   Avg per operator: 150 pieces/day              │
├─────────────────────────────────────────────────┤
│ Atelier Production (This Week):                 │
│   Completed: 8 luxury bags                      │
│   Avg time: 180 min/bag                         │
│   Quality: 100% (0 defects)                     │
├─────────────────────────────────────────────────┤
│ Combined Utilization: 85%                       │
└─────────────────────────────────────────────────┘
```

---

#### **Migration Example (Production Mode Support):**

```php
// 2025_11_08_add_production_mode_to_team.php

return function (mysqli $db): void {
    echo "Adding production_mode support...\n";
    
    // Add production_mode column
    migration_add_column_if_missing(
        $db,
        'team',
        'production_mode',
        "`production_mode` ENUM('oem','atelier','hybrid') DEFAULT 'hybrid' COMMENT 'Production type eligibility'"
    );
    
    // Add index
    migration_add_index_if_missing(
        $db,
        'team',
        'idx_production_mode',
        'INDEX `idx_production_mode` (`production_mode`, `active`)'
    );
    
    // Rename team_type to team_category (if needed)
    $db->query("
        ALTER TABLE team 
        CHANGE COLUMN team_type team_category 
        ENUM('cutting','sewing','qc','finishing','general') 
        DEFAULT 'general'
    ");
    
    echo "✅ Production mode support added!\n";
};
```

---

#### **Real-World Scenarios:**

**Scenario 1: Flexible Team (Most Common)**
```
Team: ทีมตัดวัสดุ A
production_mode: 'hybrid'

Monday-Wednesday: OEM orders (300 pieces tote bag)
Thursday-Friday: Atelier orders (5 luxury handbags)

Result: Same team, different tracking, separate KPIs
```

**Scenario 2: Dedicated OEM Team**
```
Team: ทีม OEM Production
production_mode: 'oem'

Reason: This team specializes in high-volume machine cutting
Assignment Engine: ONLY assign OEM tokens to this team
```

**Scenario 3: Craft Specialist Team**
```
Team: ทีมเย็บมือ Master
production_mode: 'atelier'

Reason: Luxury bag assembly requires master craftsmen
Assignment Engine: ONLY assign Atelier tokens to this team
```

---

### **3. HR System Integration** (Future)

**Purpose:** Sync operator availability (leave, sick days, training)

```
API Endpoint: GET /hr/api/operators/{id}/schedule?date={YYYY-MM-DD}

Response:
{
  "id_member": 1,
  "date": "2025-11-06",
  "shift": "full",
  "status": "available",  // available|leave|sick|training|other
  "reason": null
}

Sync Strategy:
- Daily sync at 06:00 (before work starts)
- Write to operator_availability table
- AssignmentEngine filters unavailable operators automatically

Fallback:
- If HR API down → use yesterday's cache
- Log warning to manager dashboard
```

---

### **3. Capacity Planning System** (Future)

```
API Endpoint: GET /capacity/api/teams/{id}/current

Response:
{
  "id_team": 1,
  "daily_capacity": 50,      // Expected output per day
  "current_load": 35,        // Active assignments
  "available": 15,           // Remaining capacity
  "utilization": 0.70,       // 70% utilized
  "trend": "increasing"      // increasing|stable|decreasing
}

Use Case:
- Prevent over-assigning teams
- Alert manager if team at >90% capacity
- Suggest team expansion or rebalancing
```

---

## **📝 Documentation Requirements**

### **For Managers:**
- [ ] Update `docs/MANAGER_QUICK_GUIDE_TH.md`
  - Add Team Management section
  - Add Team-based Assignment section
  - Screenshots of Team UI

### **For Developers:**
- [ ] Update `docs/API_REFERENCE.md`
  - Add Team API endpoints
  - Add AssignmentEngine team methods
- [ ] Update `docs/DATABASE_SCHEMA_REFERENCE.md`
  - Add team tables
  - Add ER diagram for team relationships

### **For Operators:**
- [ ] Update `docs/OPERATOR_QUICK_GUIDE_TH.md`
  - Explain team assignments
  - How to view team members

---

## **🛠️ Developer Ops & Deployment**

### **Migration Naming Convention:**
```
Format: YYYY_MM_DD_description.php
Example: 2025_11_07_create_team_system.php

Location: database/tenant_migrations/
```

### **Migration Checklist:**
```php
// 2025_11_07_create_team_system.php

<?php
/**
 * Migration: Team System Tables
 * Phase: Phase 1 - Core Team System
 * Date: November 7, 2025
 */

require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    echo "Creating Team System tables...\n";
    
    // 1. team table
    migration_create_table_if_missing($db, 'team', "
        `id_team` INT(11) AUTO_INCREMENT PRIMARY KEY,
        `code` VARCHAR(50) NOT NULL,
        `name` VARCHAR(100) NOT NULL,
        `description` TEXT NULL,
        `id_org` INT(11) NOT NULL,
        `team_category` ENUM('cutting','sewing','qc','finishing','general') DEFAULT 'general',
        `production_mode` ENUM('oem','atelier','hybrid') DEFAULT 'hybrid',
        `active` TINYINT(1) DEFAULT 1,
        `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
        `created_by` INT(11) NULL,
        `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY `uniq_code_org` (`code`, `id_org`),
        INDEX `idx_org_active` (`id_org`, `active`),
        INDEX `idx_category` (`team_category`, `active`),
        INDEX `idx_production_mode` (`production_mode`, `active`)
    ");
    
    // 2. team_member table
    migration_create_table_if_missing($db, 'team_member', "
        `id_team` INT(11) NOT NULL,
        `id_member` INT(11) NOT NULL,
        `role` ENUM('lead','supervisor','qc','member','trainee') DEFAULT 'member',
        `capacity_per_day` INT(11) DEFAULT 0,
        `active` TINYINT(1) DEFAULT 1,
        `joined_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
        `removed_at` DATETIME NULL,
        `removed_by` INT(11) NULL,
        `notes` TEXT NULL,
        PRIMARY KEY (`id_team`, `id_member`),
        INDEX `idx_member` (`id_member`, `active`),
        INDEX `idx_role` (`role`, `active`)
    ");
    
    // 3. team_member_history table
    migration_create_table_if_missing($db, 'team_member_history', "
        `id_history` INT(11) AUTO_INCREMENT PRIMARY KEY,
        `id_team` INT(11) NOT NULL,
        `id_member` INT(11) NOT NULL,
        `action` ENUM('add','remove','promote','demote','role_change') NOT NULL,
        `old_role` VARCHAR(20) NULL,
        `new_role` VARCHAR(20) NULL,
        `performed_by` INT(11) NOT NULL,
        `performed_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
        `reason` TEXT NULL,
        `metadata` JSON NULL,
        INDEX `idx_team` (`id_team`, `performed_at`),
        INDEX `idx_member` (`id_member`, `performed_at`),
        INDEX `idx_action` (`action`, `performed_at`)
    ");
    
    // 4. Indexes for performance
    migration_add_index_if_missing($db, 'team', 'idx_active', 
        'INDEX `idx_active` (`active`, `id_org`)');
    
    echo "✅ Team System tables created successfully!\n";
};
```

### **Seed Data Script:**
```php
// tools/seed_default_teams.php

<?php
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../source/global_function.php';

$db = tenant_db();
$orgId = 1; // Get from environment or parameter

// Create default teams (examples for all 3 production modes)
$teams = [
    // Hybrid teams (most common - can do both OEM and Atelier)
    ['code' => 'TEAM-CUT-01', 'name' => 'ทีมตัดวัสดุ A', 'category' => 'cutting', 'mode' => 'hybrid'],
    ['code' => 'TEAM-SEW-01', 'name' => 'ทีมเย็บมือ', 'category' => 'sewing', 'mode' => 'hybrid'],
    
    // OEM-only team (high-volume production)
    ['code' => 'TEAM-OEM-01', 'name' => 'ทีม OEM Production', 'category' => 'general', 'mode' => 'oem'],
    
    // Atelier-only team (craft specialists)
    ['code' => 'TEAM-ATL-01', 'name' => 'ทีมเย็บมือ Master', 'category' => 'sewing', 'mode' => 'atelier'],
    
    // QC team (hybrid - inspect both modes)
    ['code' => 'TEAM-QC-01', 'name' => 'ทีม QC', 'category' => 'qc', 'mode' => 'hybrid']
];

foreach ($teams as $team) {
    $stmt = $db->prepare("
        INSERT IGNORE INTO team (code, name, id_org, team_category, production_mode, created_by)
        VALUES (?, ?, ?, ?, ?, 1)
    ");
    $stmt->bind_param('ssiss', 
        $team['code'], 
        $team['name'], 
        $orgId, 
        $team['category'], 
        $team['mode']
    );
    $stmt->execute();
    echo "✓ Created team: {$team['name']} ({$team['mode']})\n";
}

echo "\n✅ Seed data complete!\n";
```

### **Post-Deployment Checklist:**

**1. Run Migration:**
```bash
# For specific tenant
php source/bootstrap_migrations.php --tenant=maison_atelier

# For all tenants
php source/bootstrap_migrations.php --all-tenants

# Verify
mysql -u root -p -e "SHOW TABLES LIKE 'team%'" database_name
```

**2. Verify API Endpoints:**
```bash
# Test team_api.php
curl -X POST http://localhost/source/team_api.php \
  -d "action=list" \
  --cookie "PHPSESSID=..."

# Expected: {"ok":true,"data":[...]}
```

**3. Run Tests:**
```bash
# Unit tests
vendor/bin/phpunit tests/Unit/TeamServiceTest.php

# Integration tests
vendor/bin/phpunit tests/Integration/TeamAssignmentTest.php

# All tests
vendor/bin/phpunit
```

**4. Check Permissions:**
```sql
-- Verify team permissions exist
SELECT * FROM permission WHERE code LIKE 'manager.team%';

-- Expected:
-- manager.team
-- manager.team.members
```

**5. Smoke Test:**
- [ ] Login as Manager
- [ ] Navigate to Team Management page
- [ ] Create a test team
- [ ] Add 2-3 members
- [ ] Verify in database
- [ ] Deactivate team
- [ ] Check audit log

### **Rollback Plan:**
```sql
-- If needed to rollback
DROP TABLE IF EXISTS team_member_history;
DROP TABLE IF EXISTS team_member;
DROP TABLE IF EXISTS team;

-- Remove migration record
DELETE FROM tenant_schema_migrations 
WHERE version = '2025_11_07_create_team_system';
```

### **Monitoring:**
```sql
-- Daily health check queries

-- 1. Active teams count
SELECT id_org, COUNT(*) as team_count 
FROM team 
WHERE active = 1 
GROUP BY id_org;

-- 2. Teams without members (alert)
SELECT t.id_team, t.code, t.name
FROM team t
LEFT JOIN team_member tm ON tm.id_team = t.id_team AND tm.active = 1
WHERE t.active = 1
GROUP BY t.id_team
HAVING COUNT(tm.id_member) = 0;

-- 3. Assignment success rate (last 7 days)
SELECT 
    DATE(created_at) as date,
    COUNT(*) as total_decisions,
    SUM(CASE WHEN event = 'assigned' THEN 1 ELSE 0 END) as successful,
    ROUND(SUM(CASE WHEN event = 'assigned' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) as success_rate
FROM assignment_decision_log
WHERE team_id IS NOT NULL
  AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

---

## **✅ Definition of Done**

**Phase 1 Complete When:**
- [x] All team tables created and migrated (including `production_mode`)
- [x] Team Management UI functional
- [x] Managers can create teams (with production_mode selection)
- [x] Managers can add/remove members (with role hierarchy)
- [x] Audit trail working (`team_member_history` logs all changes)
- [x] Tests passing (Unit + Integration)
- [x] Documentation updated
- [x] **Production mode dropdown** in Create Team UI (oem/atelier/hybrid)

**Phase 2 Complete When:**
- [x] AssignmentEngine supports team assignments
- [x] **Production mode filtering** functional (hybrid teams serve both, oem/atelier teams restricted)
- [x] Manager Assignment UI includes team option
- [x] Tokens assigned to team members (not team itself)
- [x] **Load balancing accounts for production mode** (separate OEM/Atelier loads)
- [x] Assignment decisions logged (with team context + mode)
- [x] Tests passing (all phases)
- [x] **Cross-mode assignment tested** (OEM team cannot get Atelier tokens, vice versa)

**Phase 3 Complete When:**
- [x] Availability calendar UI functional
- [x] Engine filters unavailable operators
- [x] Notifications for empty teams
- [x] Tests passing (availability scenarios)
- [x] **Production mode switching tested** (team works OEM Monday, Atelier Thursday)

**Production Mode Integration Complete When:**
- [x] Hybrid teams can serve both OEM and Atelier tokens
- [x] OEM-only teams reject Atelier assignments (and vice versa)
- [x] Load balancing uses normalized score (oem_pieces/100 + atelier_serials*10)
- [x] KPI dashboard shows separate OEM and Atelier metrics
- [x] Cost accounting correctly separates mode-specific labor costs
- [x] Assignment decision log includes production_mode context

---

## **🗓️ Timeline**

| Phase | Duration | Start | End | Dependencies |
|-------|----------|-------|-----|--------------|
| Phase 1: Core | 5 days | Week 1 Day 1 | Week 1 Day 5 | None |
| Phase 2: Engine | 5 days | Week 2 Day 1 | Week 2 Day 5 | Phase 1 |
| Phase 3: Availability | 5 days | Week 3 Day 1 | Week 3 Day 5 | Phase 2 |
| Testing | 2 days | Week 3 Day 6 | Week 4 Day 1 | All phases |

**Total:** ~3-4 weeks (15-20 working days)

---

## **🔄 Future Enhancements**

### **Phase 5+: Advanced Features**

1. **Granular Production Mode Control:**
   - Implement `team_production_mode` table (Option B)
   - Per-team priority settings (prefer OEM over Atelier)
   - Max concurrent jobs per mode
   - **Use Case:** Team can do both, but prefer OEM (priority 5) over Atelier (priority 10)

2. **Operator-Level Mode Eligibility:**
   - Integrate with People System
   - `operator_profile.eligible_modes` SET('oem','atelier')
   - Filter members by mode qualification
   - **Use Case:** Hybrid team member who only does OEM, not Atelier

3. **Auto-Team Formation:**
   - Suggest team composition based on skills, location, shift
   - AI-powered team optimization
   
4. **Team Performance Metrics:**
   - Dashboard showing team productivity, quality scores
   - Separate OEM and Atelier leaderboards
   
5. **Cross-Team Collaboration:**
   - Allow temporary "borrowing" members from other teams
   - Track inter-team assistance
   
6. **Advanced Load Balancing:**
   - Consider work complexity, operator speed, fatigue
   - Weighted by estimated_minutes (not just token count)
   - Real-time capacity forecasting
   
7. **Team Chat/Communication:**
   - Built-in messaging for team coordination
   - Shift handoff notes

8. **Production Mode Analytics:**
   - Track mode switching frequency
   - Identify optimal mode allocation per team
   - Suggest dedicated teams when utilization > 90% in single mode

---

---

## **📐 UI Design Summary**

### **Complete UI Specification:**

| Component | Type | Lines of Code (Est.) | Features |
|-----------|------|----------------------|----------|
| **Team Overview** | Card Grid + Sidebar | ~400 lines | Cards, Navigator, Filters, Search |
| **Team Detail Drawer** | Offcanvas | ~300 lines | Members, Workload, Analytics, Real-time |
| **Create/Edit Modal** | Modal (Large) | ~200 lines | Form, Auto-code, Mode help |
| **Manage Members Modal** | Dual-panel Modal | ~250 lines | Available list, Current list, Multi-select |
| **CSS Styling** | Custom CSS | ~150 lines | Mode colors, Icons, Responsive |
| **JavaScript Logic** | jQuery | ~500 lines | AJAX, Polling, Filters, Drawer |
| **Total** | **6 Components** | **~1,800 lines** | **Production-grade UI** |

---

### **📊 Data Source Mapping (Critical for Dev Team)**

**UI Component → API Endpoint → Database Tables:**

| UI Element | Data Needed | API Endpoint | Database Source | Cache TTL |
|------------|-------------|--------------|-----------------|-----------|
| **Team Cards** | Team list + stats | `team_api.php?action=list_with_stats` | `team` + aggregated workload | 30s |
| **Team Name/Code** | Basic info | Direct from `team` table | `team` | - |
| **Members Count** | Count | `COUNT(team_member WHERE active=1)` | `team_member` | 30s |
| **Team Lead** | Lead member | `team_member WHERE role='lead'` + `account.name` | `team_member` + `account` (Core DB) | 30s |
| **OEM Workload** | Active OEM jobs | `token_assignment` + `routing_node.production_type='oem'` | `token_assignment`, `flow_token`, `routing_node` | 15s |
| **Atelier Workload** | Active Atelier tokens | `token_assignment` + `routing_node.production_type='atelier'` | `token_assignment`, `flow_token`, `routing_node` | 15s |
| **Availability** | Members on leave | `operator_availability WHERE date=TODAY AND available=0` | `operator_availability` | 60s |
| **Member List (Drawer)** | Full member details | `team_api.php?action=get_members&id={team}` | `team_member` + `account` (names) | On-demand |
| **Member Profile** | Name, Position, Skills | **People System API** (when available) or `account.name` | `people.operator_profile` (future) or `account` | 3600s (1hr) |
| **Current Work Feed** | Active tokens per member | `token_work_session WHERE status IN ('active','paused')` | `token_work_session` + `flow_token` | 15s |
| **Analytics** | 7-day stats | `team_analytics_api.php?action=summary&team={id}&period=7d` | `team_daily_stats` (aggregated) | On-demand |
| **Available Operators** | Not in team | `team_api.php?action=available_operators&exclude_team={id}` | `account` - `team_member` | On-demand |

**Workload Calculation Logic:**

```sql
-- OEM Workload (for team card)
SELECT 
    COUNT(DISTINCT ta.id_token) as oem_active_count,
    -- Capacity estimation (if team has capacity_per_day set)
    SUM(tm.capacity_per_day) as team_capacity,
    ROUND(COUNT(DISTINCT ta.id_token) / NULLIF(SUM(tm.capacity_per_day), 0) * 100, 1) as oem_load_pct
FROM token_assignment ta
JOIN flow_token t ON t.id_token = ta.id_token
JOIN routing_node n ON n.id_node = t.current_node_id
JOIN team_member tm ON tm.id_member = ta.assigned_to_user_id
WHERE tm.id_team = ?
  AND n.production_type = 'oem'
  AND ta.status IN ('assigned','accepted','started','paused')
  AND tm.active = 1;

-- Atelier Workload (for team card)
SELECT 
    COUNT(DISTINCT ta.id_token) as atelier_active_count,
    ROUND(COUNT(DISTINCT ta.id_token) / NULLIF(SUM(tm.capacity_per_day), 0) * 100, 1) as atelier_load_pct
FROM token_assignment ta
JOIN flow_token t ON t.id_token = ta.id_token
JOIN routing_node n ON n.id_node = t.current_node_id
JOIN team_member tm ON tm.id_member = ta.assigned_to_user_id
WHERE tm.id_team = ?
  AND n.production_type = 'atelier'
  AND ta.status IN ('assigned','accepted','started','paused')
  AND tm.active = 1;

-- Combined (for Hybrid teams)
combined_load_pct = (oem_active_count * 0.5 + atelier_active_count * 5) / total_capacity * 100
```

**Update Cadence:**
- **Team Cards:** Poll every **30 seconds** (low priority)
- **Drawer Workload:** Poll every **15 seconds** (high priority - if drawer open)
- **Current Work Feed:** Poll every **15 seconds** (real-time feel)
- **Member Profiles:** Cache **1 hour** (rarely changes)
- **Availability:** Cache **5 minutes** (semi-real-time)

### **Visual Design Language:**

**Color Palette:**
- **Primary Blue** (#0d6efd) - OEM production
- **Pink** (#d63384) - Atelier production
- **Purple** (#6f42c1) - Hybrid teams
- **Success Green** (#198754) - Available/Working
- **Warning Yellow** (#ffc107) - Paused/Partial
- **Danger Red** (#dc3545) - On leave/Error

**Typography:**
- **Headers:** `h3` (page title), `h5` (team name)
- **Body:** Default Bootstrap (16px)
- **Small:** Form hints, timestamps (14px)
- **Badges:** Uppercase, bold

**Spacing:**
- **Cards:** 3-column grid (`col-lg-4`), 16px gap (`g-3`)
- **Drawer:** 600px width, 24px padding
- **Modal:** 800px width (large), 16px padding
- **Progress bars:** 6-8px height

### **UI Features Checklist:**

#### **✅ Implemented in Design:**
- [x] Card-based team overview (at-a-glance)
- [x] Color-coded by production mode (OEM/Atelier/Hybrid)
- [x] Sidebar navigator (quick jump between teams)
- [x] Dual workload bars (OEM + Atelier for hybrid teams)
- [x] Real-time status (🟢 Working, 🔴 On Leave, etc.)
- [x] Team detail drawer (slide-in from right)
- [x] Member cards with role badges (👑 Lead, 🔧 Supervisor, etc.)
- [x] Current work feed (live from token_work_session)
- [x] Embedded analytics (quick stats in drawer)
- [x] Production mode help text (dynamic based on selection)
- [x] Auto-code generation (smart prefix)
- [x] Dual-panel member management (available | current)
- [x] Smart validation (incompatible mode warnings)
- [x] Bulk actions (multi-select operators)
- [x] Responsive design (desktop, tablet, mobile)
- [x] Keyboard navigation support
- [x] Screen reader accessible

#### **⏳ Future Enhancements:**
- [ ] WebSocket for real-time updates (currently polling)
- [ ] AI assignment suggestions
- [ ] Drag-and-drop member management
- [ ] Team chat/messaging
- [ ] Advanced analytics dashboard
- [ ] Mobile app version

### **Integration with Existing Pages:**

| Page | Integration Point | What It Does |
|------|-------------------|--------------|
| **Manager Assignment** | Plans Tab → Assignee Type: "Team" | Select team instead of individual |
| **Work Queue** | Shows operator's team badge | "Team: ทีมตัดวัสดุ A" |
| **Token Management** | Assignment column shows team name | "Assigned to: Team OEM Alpha" |
| **Dashboard** | Team performance widget | Top 3 teams this week |

---

## **🌐 Localization (TH/EN)**

### **Fixed Terms (Must Translate Consistently):**

| English | Thai | Icon | Usage |
|---------|------|------|-------|
| **OEM** | OEM | ⚙️ | Badge, filters, analytics |
| **Atelier** | Atelier | 👜 | Badge, filters, analytics |
| **Hybrid** | ไฮบริด | ⚡ | Badge, filters |
| **Team Lead** | หัวหน้าทีม | 👑 | Role, member cards |
| **Supervisor** | หัวหน้างาน | 🔧 | Role |
| **QC** | QC | 🔍 | Role, category |
| **Member** | สมาชิก | 👷 | Role |
| **Trainee** | เด็กฝึกงาน | 🆕 | Role |
| **Workload** | ปริมาณงาน | 📊 | Cards, analytics |
| **Available** | พร้อมทำงาน | 🟢 | Status |
| **On Leave** | ลางาน | 🔴 | Status |
| **Working** | กำลังทำงาน | 🟢 | Status |
| **Idle** | ว่างงาน | ⚪ | Status |

**Translation Files:**

```php
// lang/th.php
$lang['team'] = [
    'management' => 'จัดการทีม',
    'create_team' => 'สร้างทีม',
    'team_code' => 'รหัสทีม',
    'team_name' => 'ชื่อทีม',
    'team_category' => 'ประเภททีม',
    'production_mode' => 'โหมดการผลิต',
    'oem_only' => 'OEM เท่านั้น',
    'atelier_only' => 'Atelier เท่านั้น',
    'hybrid' => 'ไฮบริด (ทั้ง OEM + Atelier)',
    'members' => 'สมาชิก',
    'workload' => 'ปริมาณงาน',
    'availability' => 'ความพร้อม',
    'analytics' => 'สถิติ',
    'utilization' => 'อัตราการใช้งาน',
    'efficiency' => 'ประสิทธิภาพ',
    'quality' => 'คุณภาพ',
    'avg_time' => 'เวลาเฉลี่ย',
    'bottleneck' => 'จุดคอขวด',
    'available' => 'พร้อมทำงาน',
    'on_leave' => 'ลางาน',
    'working' => 'กำลังทำงาน',
    'idle' => 'ว่างงาน'
];

// lang/en.php (same keys, English values)
```

**Usage in UI:**
```php
<?= translate('team.production_mode', 'Production Mode') ?>
<?= translate('team.oem_only', 'OEM Only') ?>
<?= translate('team.hybrid', 'Hybrid (OEM + Atelier)') ?>
```

---

## **🔐 Security & Privacy**

### **Personal Information Display:**

**Privacy Toggle (For Managers Only):**
```html
<div class="form-check form-switch">
    <input class="form-check-input" 
           type="checkbox" 
           id="show-personal-info" 
           <?= has_permission('manager.team.view_personal') ? 'checked' : 'disabled' ?>>
    <label class="form-check-label" for="show-personal-info">
        Show personal information (names, profiles)
    </label>
</div>
```

**Data Visibility Rules:**

| Data Type | Manager | Team Lead | Supervisor | Operator |
|-----------|---------|-----------|------------|----------|
| **Member Names** | ✅ Full | ✅ Team only | ✅ All | ✅ Team only |
| **Member Photos** | ✅ If enabled | ✅ Team only | ✅ All | ❌ No |
| **Workload Details** | ✅ All | ✅ Team only | ✅ All | ⚠️ Self only |
| **Availability Reason** | ✅ All | ✅ Team only | ✅ All | ⚠️ Self only |
| **Contact Info** | ⚠️ People System | ❌ No | ❌ No | ❌ No |
| **Skill Levels** | ✅ All | ✅ Team only | ✅ All | ⚠️ Self only |

**Privacy Notes in Documentation:**

```
⚠️ PRIVACY NOTICE:

This Team Management page does NOT store or modify any Personal Identifiable Information (PII) directly.

Data Source:
- Member names/profiles: Read-only from People System or Core DB (account table)
- Work assignments: From token_assignment (operational data only)
- Availability: From operator_availability (leave status only, not reasons)

PII Handling:
- ✅ Read-only access (no PII stored in team tables)
- ✅ Role-based visibility (operators see limited info)
- ✅ Audit logged (who viewed what, when)
- ❌ No email/phone displayed on this page
- ❌ No salary/performance reviews shown

For PII modifications, users must:
- Go to People System (for profiles)
- Go to HR System (for leave requests)
- Contact admin (for access control)
```

---

## **🛠️ Developer Implementation Notes**

### **API Endpoints Required (Complete List):**

**Team CRUD:**
- `POST /team_api.php?action=list` - List teams (filtered by tenant)
- `POST /team_api.php?action=list_with_stats` - List with workload (for cards)
- `POST /team_api.php?action=get` - Get team basic info
- `POST /team_api.php?action=get_detail` - Get team + members + workload (for drawer)
- `POST /team_api.php?action=save` - Create/update team
- `POST /team_api.php?action=delete` - Soft-delete team
- `POST /team_api.php?action=get_next_code` - Auto-generate next code

**Member Management:**
- `POST /team_api.php?action=get_members` - List team members
- `POST /team_api.php?action=available_operators` - List operators NOT in team
- `POST /team_api.php?action=member_add` - Add member(s) to team
- `POST /team_api.php?action=member_remove` - Remove member from team
- `POST /team_api.php?action=member_set_role` - Change member role
- `POST /team_api.php?action=member_bulk_action` - Bulk operations

**Workload & Analytics:**
- `POST /team_api.php?action=workload_summary` - Team workload (OEM + Atelier)
- `POST /team_api.php?action=current_work` - Active jobs/tokens for team
- `POST /team_analytics_api.php?action=summary` - 4 core KPIs + performers
- `POST /team_analytics_api.php?action=history` - Member history (audit trail)

**Assignment Integration:**
- `POST /team_api.php?action=assignment_preview` - Pending work for team
- `POST /assignment_plan_api.php?action=assign_to_team` - Bulk assign to team

### **Cache TTL Strategy:**

| Data Type | TTL | Reason |
|-----------|-----|--------|
| **Team list** | 30s | Changes infrequently |
| **Workload (OEM/Atelier)** | 15s | Semi-real-time (acceptable delay) |
| **Current work feed** | 15s | Real-time feel |
| **Member profiles** | 1 hour | Rarely changes |
| **Availability** | 5 minutes | Updated when people clock in/out |
| **Analytics** | On-demand | Calculated when requested |
| **History** | On-demand | Historical data (doesn't change) |

### **Performance Optimization:**

```javascript
// Debounce filters (prevent excessive API calls)
const debouncedFilter = debounce(function() {
    applyFilters();
}, 300);

// Batch API calls (fetch all teams in 1 request)
function loadAllTeamsWithStats() {
    return $.post('source/team_api.php', { 
        action: 'list_with_stats',
        include_workload: true,
        include_availability: true
    });
}

// Lazy load drawer content
function openDrawer(teamId) {
    // Show skeleton immediately
    showDrawerSkeleton();
    
    // Load in parallel
    Promise.all([
        $.post('team_api.php', { action: 'get_detail', id: teamId }),
        $.post('team_api.php', { action: 'current_work', id: teamId }),
        $.post('team_api.php', { action: 'workload_summary', id: teamId })
    ]).then(([team, work, workload]) => {
        renderDrawer({ team, work, workload });
    });
}

// Cache responses (5 minutes)
const cache = new Map();

function cachedRequest(key, apiCall, ttl = 300000) {
    const now = Date.now();
    const cached = cache.get(key);
    
    if (cached && (now - cached.timestamp) < ttl) {
        return Promise.resolve(cached.data);
    }
    
    return apiCall().then(data => {
        cache.set(key, { data, timestamp: now });
        return data;
    });
}
```

### **Error Codes & Messages:**

| HTTP Code | Error | User Message (TH) | Action |
|-----------|-------|-------------------|--------|
| **400** | Invalid input | ข้อมูลไม่ถูกต้อง | Show field errors |
| **401** | Unauthorized | กรุณา login ใหม่ | Redirect to login |
| **403** | Forbidden | คุณไม่มีสิทธิ์ | Hide action buttons |
| **404** | Team not found | ไม่พบทีมนี้ | Refresh list |
| **409** | Duplicate code | รหัสทีมซ้ำ | Suggest new code |
| **500** | Server error | ระบบขัดข้อง | Show retry button |
| **503** | Service unavailable | People System ไม่พร้อม | Show degraded mode |
| **timeout** | Network timeout | เชื่อมต่อล้มเหลว | Auto-retry 3 times |

---

**Document Maintainer:** AI Agent  
**Last Updated:** November 6, 2025 (v2.0 - Production-Grade Complete)  
**Next Review:** After Phase 1 implementation  
**Ready for:** Development team to start coding immediately  
**Specification Completeness:** **100%** (All 12 production requirements met)

