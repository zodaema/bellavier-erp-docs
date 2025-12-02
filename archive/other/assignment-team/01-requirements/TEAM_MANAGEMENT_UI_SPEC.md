# Team Management UI — Final Specification

**Version:** 1.0 (Executive Summary)  
**Date:** November 6, 2025  
**Full Spec:** `docs/TEAM_SYSTEM_REQUIREMENTS.md` (3,681 lines)  
**Status:** ✅ Ready for Implementation

---

## **🎯 Goals (3 Core Objectives)**

1. **5-Second Overview:** Manager sees all teams + workload + availability at a glance
2. **One-Page Control:** All operations (CRUD teams, manage members, assign work) without page navigation
3. **Hybrid Model Support:** Teams serve OEM (batch) + Atelier (serial) + Hybrid production modes

---

## **📱 Screens (4 Main Components)**

### **A. Team Overview (Card Grid + Filters)**

**Layout:** 2-column (Sidebar Navigator + Main Content)

**Filter Bar:**
- Team Category: `cutting | sewing | qc | finishing | general`
- Production Mode: `⚙️ OEM | 👜 Atelier | ⚡ Hybrid`
- Status: `Active | Inactive`
- View: `Cards (default) | List | Table`
- Search: Team name, code, or lead name

**Team Card Contents:**
```
┌──────────────────────────┐
│ [⚙️ OEM Only]            │ ← Badge (color-coded)
│ ทีม OEM Production       │ ← Team name
│ TEAM-OEM-01              │ ← Code
├──────────────────────────┤
│ 👤 24 members            │ ← Member count
│ 👑 Lead: สมชาย          │ ← Team lead
│                          │
│ OEM:  ███████░░ 78%     │ ← OEM workload bar
│ ATL:  ░░░░░░░░░ 0%      │ ← Atelier workload bar
│                          │
│ 🟢 22 available          │ ← Availability status
│ 🔴 2 on leave            │
│                          │
│ [View Detail]            │ ← Action button
└──────────────────────────┘
```

**Sidebar Navigator (Quick Jump):**
- Grouped by mode: OEM (2) | Atelier (3) | Hybrid (2)
- Click team name → scroll to card + highlight
- Badge shows utilization %

---

### **B. Team Detail Drawer (600px, slide from right)**

**5 Tabs:**

**Tab 1: Members**
```
👥 MEMBERS (16)     [＋ Add] [⚙️ Bulk] [🔍 Filter]

Filters: [Role ▼] [Mode ▼] [Status ▼]
Bulk: [☐ Select All] [Set Role] [Mark Leave] [Remove]

┌────────────────────────────────────────────┐
│ ☐ 👑 Kittisak (Lead)      [Edit Role ▼]  │
│ Position: Cutter | Eligible: ⚙️👜        │
│ Current: 🟢 Working - 4 jobs (2 OEM, 2 ATL)│
│ Load: ████████░░ 75%                       │
│ [View Schedule] [View Profile] [View Work]│
└────────────────────────────────────────────┘
... (more members)
```

**Tab 2: Workload**
```
⚙️ OEM:     ████████░░░ 65%  (13/20 jobs)
👜 Atelier: ███░░░░░░░░ 25%  (3/12 serials)
Combined:   ████████░░ 78% utilization

Top Active: Kittisak (4), Natee (3)
Idle: Somchai (0) ← Next assignment
```

**Tab 3: Assignment Preview**
```
Pending work this team can receive:
⚙️ OEM: 12 jobs waiting (Node: ตัดวัสดุ)
👜 Atelier: 3 serials waiting (Node: เย็บ)

[Auto-Assign to Team] → Distribute to lowest-load members
```

**Tab 4: Analytics (4 Core KPIs)**
```
Period: [Today | 7 Days | 30 Days | Custom]

1️⃣ Team Utilization: 78% (target: 70-85%)
2️⃣ Avg Task Time: OEM 11.3 min | Atelier 23.8 min
3️⃣ Availability Rate: 91% (15/16 available)
4️⃣ Top Bottleneck: Node "เย็บ" 85% (⚠️ near capacity)

Top 3 Performers: ...
```

**Tab 5: History (Audit Trail)**
```
Nov 6, 10:30 - Administrator
  ➕ Added: Somchai (trainee) | Reason: New hire

Nov 5, 14:15 - Administrator
  🔄 Role changed: Natee (member → supervisor)

[Load More...] (from team_member_history)
```

---

### **C. Create/Edit Team Modal**

**Fields:**
- Team Code (auto-generate button: 🪄)
- Team Name
- Team Category: `cutting | sewing | qc | finishing | general`
- **Production Mode:** `⚙️ OEM | 👜 Atelier | ⚡ Hybrid (default)`
  - Dynamic help text (explains each mode)
- Team Lead (dropdown)
- Description (textarea)
- Active (toggle)

**Auto-Code Logic:**
- OEM → `TEAM-OEM-01`
- Atelier → `TEAM-ATL-01`
- Hybrid → `TEAM-{CATEGORY}-01` (e.g., `TEAM-CUT-01`)

---

### **D. Manage Members Modal (Dual-Panel)**

**Left Panel:** Available Operators (NOT in team)
**Right Panel:** Current Members

**Features:**
- Multi-select (checkboxes)
- Add button (➡️)
- Remove button (with confirmation)
- Bulk actions (set role, mark leave)
- Search/filter both panels
- Production mode eligibility warning

---

## **🎨 Visual Design (Quick Reference)**

### **Color Coding:**
| Mode | Color | Badge | Card Border |
|------|-------|-------|-------------|
| **OEM** | Blue #0d6efd | `⚙️ OEM Only` | `border-primary` |
| **Atelier** | Pink #d63384 | `👜 Atelier Only` | `border-pink` |
| **Hybrid** | Purple #6f42c1 | `⚡ OEM + Atelier` | `border-purple` (gradient) |

### **Role Icons:**
- 👑 Lead
- 🔧 Supervisor
- 🔍 QC
- 👷 Member
- 🆕 Trainee

### **Status Colors:**
- 🟢 Available/Working (green #198754)
- 🔴 On Leave (red #dc3545)
- 🟡 Paused/Partial (yellow #ffc107)
- ⚪ Idle (gray #6c757d)

---

## **🔌 Data Contracts (API Endpoints)**

### **Team CRUD:**
```
GET  /team_api.php?action=list&mode=&status=&category=&q=
→ { ok: true, data: [{ id_team, code, name, production_mode, members_count, lead_name, oem_load_pct, atelier_load_pct, available_count, leave_count }] }

GET  /team_api.php?action=get_detail&id={team_id}
→ { ok: true, team: {...}, members: [...], workload: {...}, current_work: [...] }

POST /team_api.php?action=save
Body: { id_team (for update), code, name, category, production_mode, lead_id, description, active }
→ { ok: true, id: team_id }

POST /team_api.php?action=delete&id={team_id}
→ { ok: true, message: 'Team deactivated' }
```

### **Member Management:**
```
GET  /team_api.php?action=available_operators&exclude_team={id}
→ { ok: true, data: [{ id_member, name, position, eligible_modes, current_load }] }

POST /team_api.php?action=member_add
Body: { id_team, member_ids: [1,2,3], role: 'member' }
→ { ok: true, added: 3 } (+ logs to team_member_history)

POST /team_api.php?action=member_remove
Body: { id_team, id_member, reason }
→ { ok: true } (soft-delete, logs to history)

POST /team_api.php?action=member_set_role
Body: { id_team, id_member, new_role, reason }
→ { ok: true } (logs to history)
```

### **Workload & Analytics:**
```
GET  /team_api.php?action=workload_summary&id={team_id}
→ { ok: true, oem_active: 13, oem_capacity: 20, oem_pct: 65, atelier_active: 3, atelier_capacity: 12, atelier_pct: 25, combined_pct: 78 }

GET  /team_api.php?action=current_work&id={team_id}
→ { ok: true, data: [{ job_code, production_type, status, operator_name, started_at, eta }] }

GET  /team_analytics_api.php?action=summary&id={team_id}&period={7d|30d}
→ { ok: true, kpis: { utilization, avg_time_oem, avg_time_atelier, availability_rate, bottleneck }, top_performers: [...] }

GET  /team_api.php?action=history&id={team_id}&limit=20
→ { ok: true, data: [{ action, id_member, old_role, new_role, performed_by, performed_at, reason }] }
```

### **Assignment Integration:**
```
GET  /team_api.php?action=assignment_preview&id={team_id}
→ { ok: true, oem_pending: 12, oem_nodes: ['ตัดวัสดุ'], atelier_pending: 3, atelier_nodes: ['เย็บ'] }

POST /assignment_plan_api.php?action=assign_to_team
Body: { id_team, work_items: [{id_token, id_node}] }
→ { ok: true, assigned: 15 } (Engine distributes to members)
```

### **Update Cadence:**
- **Team Cards:** Poll every **30 seconds** (low priority)
- **Drawer Workload:** Poll every **15 seconds** (when drawer open)
- **Current Work:** Poll every **15 seconds** (real-time feel)
- **Member Profiles:** Cache **1 hour**
- **Availability:** Cache **5 minutes**

---

## **📊 States (UI Must Handle All)**

| State | Trigger | UI Display | Action |
|-------|---------|------------|--------|
| **Loading** | Initial load / API call | Skeleton cards/rows | Show spinner |
| **Empty (No Teams)** | `data.length === 0` | 📦 "No teams" + CTA "Create Team" | Enable create button |
| **Empty (No Members)** | `team.members.length === 0` | ⚠️ "No members" + CTA "Add Members" | Open add modal |
| **Empty (No Work)** | `current_work.length === 0` | 📭 "No active work" | No action needed |
| **Error (API)** | `resp.ok === false` | 🔴 Error banner + error message + Retry button | Enable retry |
| **Error (Timeout)** | `xhr.timeout` | 🔴 "Connection timeout" + Retry button | Auto-retry 3x |
| **Degraded (People System Down)** | `503 from People API` | ⚠️ "Limited mode: showing cached names only" | Continue with fallback |
| **Inactive Team** | `team.active === 0` | 🔴 Badge "Inactive" + disabled assign button | Hide assign actions |

---

## **🔐 Permissions (Visibility Matrix)**

| Role | View Overview | View Drawer | Add/Remove Member | Edit Role | Assign to Team | Analytics |
|------|---------------|-------------|-------------------|-----------|----------------|-----------|
| **Manager** | ✅ All | ✅ All | ✅ | ✅ | ✅ | ✅ All |
| **Team Lead** | ✅ Own team | ✅ Own team | ✅ Own team | ✅ Own team | ✅ Own team | ✅ Own team |
| **Supervisor** | ✅ All (read-only) | ✅ All | ❌ | ✅ Approve override | ✅ All | ✅ All |
| **Member** | ✅ Own team (name only) | ✅ Own team members | ❌ | ❌ | ❌ | ❌ |

**PII Display:**
- Names/Photos: Only if `has_permission('manager.team.view_personal')`
- Toggle: "Show personal info" (checkbox, manager only)
- Default: Show initials only for operators

---

## **📐 Visual Design (Implementation Guide)**

### **Technology Stack:**
- Bootstrap 5.3 + Sash Admin Theme
- Bootstrap Icons (`bi-*`)
- SweetAlert2 (dialogs)
- Toastr (notifications)
- jQuery 3.7.1 (AJAX)

### **Color Palette:**
```css
/* Production Mode Colors */
.badge-oem { background: #0d6efd; }        /* Blue */
.badge-atelier { background: #d63384; }    /* Pink */
.badge-hybrid { 
    background: linear-gradient(90deg, #0d6efd 50%, #d63384 50%); 
}

.border-primary { border-left: 4px solid #0d6efd !important; }
.border-pink { border-left: 4px solid #d63384 !important; }
.border-purple { border-left: 4px solid #6f42c1 !important; }

/* Status Colors */
.status-working { color: #198754; }   /* Green */
.status-leave { color: #dc3545; }     /* Red */
.status-idle { color: #6c757d; }      /* Gray */
.status-paused { color: #ffc107; }    /* Yellow */
```

### **Icons (Bootstrap Icons):**
- `bi-gear` - OEM
- `bi-bag-fill` - Atelier
- `bi-lightning-fill` - Hybrid
- `bi-people-fill` - Members
- `bi-graph-up` - Analytics
- `bi-clock-history` - History

---

## **📱 Mobile/PWA Rules**

| Feature | Desktop (≥1200px) | Tablet (768-1199px) | Mobile (<768px) |
|---------|-------------------|---------------------|-----------------|
| **Cards per row** | 3 | 2 | 1 (full width) |
| **Sidebar** | Sticky left | Hidden (collapsible) | Bottom sheet |
| **Filters** | Always visible | Collapsible | Collapsible (toggle) |
| **Create button** | Top right | Top right | Floating FAB (bottom-right) |
| **Drawer** | 600px slide-in | 500px slide-in | Fullscreen overlay |
| **Member table** | All columns | 4 columns | 3 columns (Name, Role, Load) |
| **Analytics** | Embedded in drawer | Embedded | Separate page |

**PWA Specific:**
- Offline mode: Show cached teams (read-only)
- Disable create/edit when offline
- Auto-sync when back online

---

## **🌐 Localization (TH/EN)**

### **Fixed Terms:**

| English | Thai | Icon | Context |
|---------|------|------|---------|
| OEM | OEM | ⚙️ | Production mode badge |
| Atelier | Atelier | 👜 | Production mode badge |
| Hybrid | ไฮบริด | ⚡ | Production mode badge |
| Team Lead | หัวหน้าทีม | 👑 | Role |
| Supervisor | หัวหน้างาน | 🔧 | Role |
| Member | สมาชิก | 👷 | Role |
| Trainee | เด็กฝึกงาน | 🆕 | Role |
| Workload | ปริมาณงาน | 📊 | Metrics |
| Available | พร้อมทำงาน | 🟢 | Status |
| On Leave | ลางาน | 🔴 | Status |
| Utilization | อัตราการใช้งาน | - | KPI |

**Usage:**
```php
<?= translate('team.production_mode', 'Production Mode') ?>
<?= translate('team.oem_only', 'OEM Only') ?>
<?= translate('team.hybrid', 'Hybrid (OEM + Atelier)') ?>
```

---

## **✅ Definition of Done (UI)**

### **Performance:**
- [x] Overview loads in **≤ 1.0s** (cached summaries)
- [x] Drawer opens in **≤ 300ms** (smooth animation)
- [x] Filter response **instant** (client-side)
- [x] Real-time updates every **15s** (workload)

### **Functionality:**
- [x] All states handled (loading/empty/error/inactive)
- [x] Permissions enforced on every button
- [x] Assign to Team integrates with AssignmentEngine
- [x] Success notifications (toast)
- [x] Preview refreshes after assignment

### **Responsive:**
- [x] Works on **360px+** screens
- [x] Cards stack properly (3 → 2 → 1)
- [x] Drawer becomes fullscreen on mobile
- [x] FAB appears on mobile only

### **Accessibility:**
- [x] Keyboard navigation (Tab, Enter, Esc)
- [x] Screen reader labels (aria-label)
- [x] Color contrast ≥ 4.5:1
- [x] Touch targets ≥ 44px

---

## **🔗 Integration Points**

### **With Manager Assignment:**
```
Plans Tab → Assignee Type dropdown:
  [Member | Team] ← Add "Team" option

When "Team" selected:
  → Load teams from team_api.php?action=list&production_mode={node_mode}
  → Preview button shows team members + load
  → Save as assignee_type='team', assignee_id={id_team}
```

### **With Work Queue:**
```
Token card shows:
  Assigned to: Team ทีมตัดวัสดุ A (Somchai)
               ↑ team name      ↑ actual operator
```

### **With Dashboard:**
```
Widget: "Team Performance This Week"
  🥇 ทีมเย็บมือ Master - 120 completed
  🥈 ทีมตัดวัสดุ A - 85 completed
  🥉 ทีม QC - 65 completed
```

---

## **🛠️ Implementation Checklist**

### **Phase 1: Core UI (5 days)**

**Day 1-2: HTML + CSS**
- [ ] `views/team_management.php` (~400 lines)
  - Main layout (2-column: sidebar + content)
  - Filter bar
  - Card grid (3 mode variations)
- [ ] `assets/stylesheets/team_management.css` (~150 lines)
  - Custom mode colors
  - Card styling
  - Drawer styling

**Day 3-4: JavaScript**
- [ ] `assets/javascripts/team/management.js` (~500 lines)
  - Load teams with stats
  - Filter/search logic
  - Open drawer (lazy load)
  - Manage members modal
  - Real-time polling (15s)
  - Error handling

**Day 5: Testing**
- [ ] Browser testing (Chrome, Safari, Firefox)
- [ ] Mobile responsive (360px, 768px, 1200px)
- [ ] Accessibility (keyboard, screen reader)
- [ ] Performance (load time <1s)

### **Phase 2: Backend API (3 days)**

**Day 1: Team API**
- [ ] `source/team_api.php` (~400 lines)
  - list, list_with_stats, get, get_detail
  - save, delete
  - get_next_code

**Day 2: Member API**
- [ ] Continue `team_api.php`
  - get_members, available_operators
  - member_add, member_remove
  - member_set_role, member_bulk_action
  - Log to `team_member_history`

**Day 3: Workload API**
- [ ] Continue `team_api.php`
  - workload_summary (OEM + Atelier calculation)
  - current_work (live feed)
  - assignment_preview

### **Phase 3: Integration (2 days)**

**Day 1: Manager Assignment**
- [ ] Update `views/manager_assignment.php`
  - Add "Team" option to assignee type
  - Team dropdown (filtered by production mode)
  - Preview modal
- [ ] Update `assignment.js`
  - Handle team selection
  - Preview team members

**Day 2: AssignmentEngine**
- [ ] Update `AssignmentEngine::assignOne()`
  - Implement `expandAssignees()` (team → members)
  - Implement `filterByProductionMode()`
  - Implement `pickByLowestLoad()` (with formula)

### **Phase 4: Analytics + Polish (3 days)**

**Day 1: Analytics**
- [ ] `source/team_analytics_api.php` (~200 lines)
  - summary (4 core KPIs)
  - history (audit trail)
- [ ] Update drawer Analytics tab

**Day 2: Testing**
- [ ] Unit tests: TeamServiceTest.php
- [ ] Integration tests: TeamAssignmentTest.php
- [ ] E2E browser testing

**Day 3: Documentation + Training**
- [ ] Update `MANAGER_QUICK_GUIDE_TH.md`
- [ ] Create demo teams + seed data
- [ ] Manager training session

**Total: 13 days (3 weeks)**

---

## **📋 Task Breakdown (Tickets)**

### **Backend (BE) - 8 Tickets**

**BE-1: Database Migration** (Priority: Critical, Est: 4h)
```
Create: database/tenant_migrations/2025_11_07_create_team_system.php
Tables: team, team_member, team_member_history
Columns: All with production_mode support
Indexes: org, active, production_mode, role
```

**BE-2: Team API - CRUD** (Priority: High, Est: 8h)
```
File: source/team_api.php
Endpoints: list, list_with_stats, get, get_detail, save, delete, get_next_code
Permission: manager.team
Multi-tenant: Filter by id_org
```

**BE-3: Team API - Members** (Priority: High, Est: 8h)
```
File: source/team_api.php (continue)
Endpoints: get_members, available_operators, member_add, member_remove, member_set_role
Audit: Log all changes to team_member_history
```

**BE-4: Team API - Workload** (Priority: High, Est: 6h)
```
File: source/team_api.php (continue)
Endpoints: workload_summary, current_work, assignment_preview
Logic: Separate OEM/Atelier calculations
Formula: (oem_count * 0.5 + atelier_count * 5) / capacity * 100
```

**BE-5: Team Analytics API** (Priority: Medium, Est: 6h)
```
File: source/team_analytics_api.php
Endpoints: summary (4 KPIs), history (audit)
KPIs: utilization, avg_time, availability_rate, bottleneck
Period: today | 7d | 30d
```

**BE-6: AssignmentEngine - Team Support** (Priority: Critical, Est: 8h)
```
File: source/service/AssignmentEngine.php
Methods: 
  - expandAssignees() - team → members
  - filterByProductionMode() - check team.production_mode vs node.production_type
  - pickByLowestLoad() - formula: (active_count * 10) + (work_seconds / 60)
Integration: autoAssignOnSpawn(), autoAssignOnRoute()
```

**BE-7: Assignment Plan API - Team Preview** (Priority: Medium, Est: 4h)
```
File: source/assignment_plan_api.php
Endpoint: assign_to_team
Logic: Validate team mode, call Engine, log decision
```

**BE-8: Helper Functions** (Priority: Low, Est: 2h)
```
File: source/global_function.php
Functions: getCurrentUserTeamId(), checkTeamRole(), logTeamChange()
```

**Backend Total: 46 hours (~6 days)**

---

### **Frontend (FE) - 7 Tickets**

**FE-1: Page Structure** (Priority: Critical, Est: 6h)
```
File: views/team_management.php, page/team_management.php
Layout: 2-column (sidebar 250px + main)
Components: Header, filter bar, cards container
Includes: SweetAlert2, Toastr, Bootstrap 5
```

**FE-2: Team Cards (Overview)** (Priority: High, Est: 8h)
```
File: views/team_management.php (continue)
Components: Team card (3 variations: OEM, Atelier, Hybrid)
Features: Color-coded borders, dual workload bars, availability badges
Actions: View Detail, Edit, Analytics, Deactivate
```

**FE-3: Sidebar Navigator** (Priority: Medium, Est: 4h)
```
File: views/team_management.php (continue)
Component: Sticky sidebar list
Grouped by: OEM | Atelier | Hybrid
Features: Click to scroll + highlight, utilization badges
```

**FE-4: Team Detail Drawer** (Priority: Critical, Est: 10h)
```
File: views/team_management.php (continue)
Component: Bootstrap Offcanvas (600px width)
Tabs: Members, Workload, Assignment Preview, Analytics, History
Features: Real-time updates, member cards, workload summary
Actions: Add member, Edit role, Remove, Assign
```

**FE-5: Create/Edit Team Modal** (Priority: High, Est: 6h)
```
File: views/team_management.php (continue)
Component: Bootstrap Modal (large, 800px)
Fields: Code, Name, Category, Production Mode, Lead, Description, Active
Features: Auto-code generation, dynamic help text
```

**FE-6: Manage Members Modal** (Priority: High, Est: 8h)
```
File: views/team_management.php (continue)
Component: Dual-panel modal
Left: Available operators (search, filter, multi-select)
Right: Current members (bulk actions)
Features: Production mode eligibility warning
```

**FE-7: JavaScript Logic** (Priority: Critical, Est: 12h)
```
File: assets/javascripts/team/management.js
Functions:
  - loadTeamsWithStats() - API call + render cards
  - applyFilters() - client-side filtering
  - openDrawer() - lazy load + polling
  - manageMembersModal() - dual-panel logic
  - saveTeam() - validation + API call
  - refreshWorkload() - real-time updates
Error handling: Loading/empty/error states
Polling: 15s for workload, 30s for cards
```

**Frontend Total: 54 hours (~7 days)**

---

### **QA Testing (QA) - 5 Tickets**

**QA-1: Unit Tests** (Priority: High, Est: 6h)
```
File: tests/Unit/TeamServiceTest.php
Tests:
  - testCreateTeam()
  - testAddMember()
  - testExpandTeamMembers()
  - testFilterByProductionMode()
  - testPickByLowestLoad()
Coverage: >80%
```

**QA-2: Integration Tests** (Priority: High, Est: 8h)
```
File: tests/Integration/TeamAssignmentTest.php
Scenarios:
  - Create team → Add members → Assign work → Verify distribution
  - OEM team rejects Atelier tokens
  - Hybrid team serves both modes
  - Load balancing (3 members, 10 tokens → 3-4-3 distribution)
```

**QA-3: Browser E2E Testing** (Priority: Critical, Est: 8h)
```
Manual Testing Checklist:
  ✅ Create OEM team
  ✅ Add 3 members (different roles)
  ✅ View detail drawer
  ✅ Edit member role
  ✅ Remove member
  ✅ Filter by production mode
  ✅ Search team/member
  ✅ Assign work to team
  ✅ Verify workload updates
  ✅ Check analytics (4 KPIs)
  ✅ View history (audit trail)
  ✅ Mobile responsive (360px, 768px, 1200px)
  ✅ Offline mode (PWA)
```

**QA-4: Permission Testing** (Priority: High, Est: 4h)
```
Test each role:
  - Manager: Full access
  - Team Lead: Own team only
  - Supervisor: Read-only all teams
  - Operator: Limited view

Verify:
  - Buttons disabled correctly
  - API returns 403 for unauthorized
  - PII toggle works
```

**QA-5: Performance Testing** (Priority: Medium, Est: 4h)
```
Load Testing:
  - 50 teams → Page load <1s
  - 100 members in team → Drawer <500ms
  - Real-time updates don't degrade UI
  
Memory:
  - No memory leaks from polling
  - Cache clears properly
```

**QA Total: 30 hours (~4 days)**

---

## **📊 Total Effort Estimate**

| Phase | Backend | Frontend | QA | Total |
|-------|---------|----------|-----|-------|
| **Core Team System** | 20h (BE-1,2,3) | 28h (FE-1,2,3,4) | 10h (QA-1,2) | **58h (7 days)** |
| **Assignment Integration** | 18h (BE-6,7) | 12h (FE-7, Manager UI) | 12h (QA-3,4) | **42h (5 days)** |
| **Analytics + Polish** | 8h (BE-5,8) | 14h (Analytics tab) | 8h (QA-5) | **30h (4 days)** |
| **Total** | **46h** | **54h** | **30h** | **130h (16 days)** |

**Timeline:** 3-4 weeks (with buffer)

---

## **🚀 Implementation Priority**

### **Critical Path (Must Have for Phase 1):**
1. ✅ Database migration (BE-1)
2. ✅ Team API - CRUD (BE-2)
3. ✅ Team API - Members (BE-3)
4. ✅ Page structure + Cards (FE-1, FE-2)
5. ✅ Team Detail Drawer (FE-4)
6. ✅ JavaScript logic (FE-7)
7. ✅ Browser E2E testing (QA-3)

### **Important (Phase 1.5):**
8. ✅ Workload API (BE-4)
9. ✅ Create/Edit modal (FE-5)
10. ✅ Manage Members modal (FE-6)
11. ✅ Unit tests (QA-1)

### **Nice to Have (Phase 2):**
12. ⏳ AssignmentEngine integration (BE-6, BE-7)
13. ⏳ Analytics API (BE-5)
14. ⏳ Sidebar navigator (FE-3)
15. ⏳ Integration tests (QA-2)

### **Polish (Phase 3):**
16. ⏳ Analytics tab in drawer
17. ⏳ History tab (audit trail)
18. ⏳ Permission testing (QA-4)
19. ⏳ Performance testing (QA-5)
20. ⏳ Mobile responsive

---

## **🔧 Quick Start for Developers**

### **1. Run Migration:**
```bash
cd /Applications/MAMP/htdocs/bellavier-group-erp
php source/bootstrap_migrations.php --tenant=maison_atelier

# Verify
mysql -u root -proot bgerp_t_maison_atelier -e "SHOW TABLES LIKE 'team%'"
```

### **2. Create Team API:**
```bash
# Copy structure from assignment_plan_api.php
cp source/assignment_plan_api.php source/team_api.php

# Implement endpoints (see BE tickets)
```

### **3. Create Page Files:**
```bash
# Page definition
cp page/manager_assignment.php page/team_management.php

# View
cp views/manager_assignment.php views/team_management.php

# JavaScript
mkdir -p assets/javascripts/team
touch assets/javascripts/team/management.js

# CSS
touch assets/stylesheets/team_management.css
```

### **4. Test Locally:**
```
URL: http://localhost:8888/bellavier-group-erp/index.php?p=team_management
Login: admin / iydgtv
Tenant: Switch to "Bellavier Atelier (DEFAULT)"
```

---

## **📞 Support Resources**

- **Full Spec:** `docs/TEAM_SYSTEM_REQUIREMENTS.md` (3,681 lines)
- **Database Schema:** § Database Schema (lines 45-220)
- **Backend Logic:** § Backend Implementation (lines 225-490)
- **UI Mockups:** § Frontend Implementation (lines 495-1,650)
- **Testing:** § Testing Strategy (lines 2,250-2,450)

---

**Document Owner:** AI Agent  
**For Questions:** Check full spec or ask in team channel  
**Status:** ✅ Ready to Start Coding


