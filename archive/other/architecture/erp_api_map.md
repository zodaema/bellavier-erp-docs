# ERP API Map (Bellavier Group ERP)

**Generated:** 2025-11-22  
**Last Updated:** 2025-12-17  
**Total APIs:** 28 files  
**Purpose:** Comprehensive mapping of all `*_api.php` endpoints in `/source`

**Recent Updates:**
- **Task 17.2 (2025-12-17):** Added validation layer to `dag_routing_api.php` for parallel split intent and merge node topology
- **Task 18 (2025-12-17):** Added machine cycle awareness and throughput constraints to `dag_routing_api.php`
- **Task 16 (2025-12-16):** Added execution mode binding (`execution_mode`, `derived_node_type`) to `dag_routing_api.php`
- **Task 15 (2025-12-15):** Added behavior binding (`behavior_code`, `behavior_version`) to `dag_routing_api.php`

---

## 1. Summary Table

| File | Module | Domain | Permission | Status |
|------|--------|--------|------------|--------|
| `source/admin_feature_flags_api.php` | Feature Flags | meta, admin | `platform.tenants.manage` / `admin.settings.manage` | CANONICAL |
| `source/assignment_api.php` | Token Assignment | hatthasilpa, dag-token | `hatthasilpa.job.assign` | CANONICAL |
| `source/assignment_plan_api.php` | Assignment Plans | hatthasilpa, assignment | `manager.assignment` | CANONICAL |
| `source/classic_api.php` | Classic Production | classic | `classic.job.ticket` | LEGACY_BUT_ACTIVE |
| `source/dag_approval_api.php` | DAG Approvals | dag-token | (implicit) | CANONICAL |
| `source/dag_routing_api.php` | DAG Routing | dag-routing | `dag.routing.manage` | CANONICAL |
| `source/dag_token_api.php` | DAG Tokens | dag-token, hatthasilpa | (implicit) | CANONICAL |
| `source/dashboard_api.php` | Production Dashboard | dashboard, production | `dashboard.production.view` | CANONICAL |
| `source/exceptions_api.php` | Exceptions Board | production, monitoring | `production.view` | CANONICAL |
| `source/hatthasilpa_component_api.php` | Component Binding | hatthasilpa, component | `hatthasilpa.job.ticket` | CANONICAL |
| `source/hatthasilpa_jobs_api.php` | Hatthasilpa Jobs | hatthasilpa, dag-job | `hatthasilpa.job.ticket` | CANONICAL |
| `source/hatthasilpa_operator_api.php` | Operator Availability | hatthasilpa, operator | `hatthasilpa.job.ticket` | CANONICAL |
| `source/leather_cut_bom_api.php` | Leather CUT BOM | leather, specialized | `leather.cut.bom.view`, `leather.cut.bom.manage` | CANONICAL |
| `source/leather_sheet_api.php` | Leather Sheets | leather, specialized | `leather.sheet.view`, `leather.sheet.use` | CANONICAL |
| `source/people_api.php` | People System | people, integration | `people.read` | CANONICAL |
| `source/platform_dashboard_api.php` | Platform Dashboard | meta, platform | `platform.admin` | CANONICAL |
| `source/platform_health_api.php` | Platform Health | meta, platform | `platform.admin` | CANONICAL |
| `source/platform_migration_api.php` | Platform Migrations | meta, platform | `platform.admin` | CANONICAL |
| `source/platform_roles_api.php` | Platform Roles | meta, platform | `platform.admin` | CANONICAL |
| `source/platform_serial_metrics_api.php` | Serial Metrics | meta, platform | `platform.view.metrics` | CANONICAL |
| `source/platform_serial_salt_api.php` | Serial Salt | meta, platform | `platform.admin` | CANONICAL |
| `source/platform_tenant_owners_api.php` | Tenant Owners | meta, platform | `platform.admin` | CANONICAL |
| `source/pwa_scan_api.php` | PWA Scan Station | hatthasilpa, pwa | `hatthasilpa.job.ticket` | CANONICAL |
| `source/routing.php` | Routing V1 (Legacy) | routing-v1 | (implicit) | LEGACY_READ_ONLY |
| `source/team_api.php` | Team Management | team, assignment | `manager.team`, `manager.team.members` | CANONICAL |
| `source/tenant_users_api.php` | Tenant Users | meta, tenant-admin | `org.user.manage` | CANONICAL |
| `source/token_management_api.php` | Token Management | dag-token, hatthasilpa | `hatthasilpa.job.manage` | CANONICAL |
| `source/trace_api.php` | Product Traceability | trace, serial | `trace.view`, `trace.manage` | CANONICAL |
| `source/api/public/serial_verify_api.php` | Serial Verification | public, customer | (public, no auth) | CANONICAL |

> **Status Legend:**
> - **CANONICAL** = Main entrypoint, use for future features
> - **LEGACY_BUT_ACTIVE** = Still used, but no new features should be built here
> - **LEGACY_READ_ONLY** = Read-only, kept for historical data only
> - **DEPRECATED** = Should be removed once callers are migrated
> - **EXPERIMENTAL** = Only used in experiments/dev, not stable

---

## 2. API Files

### source/admin_feature_flags_api.php

- **module:** Feature Flags Admin
- **domain:** [meta] [admin]
- **permission:** `platform.tenants.manage` / `admin.settings.manage` / `admin.user.manage` / `admin.role.manage`
- **status:** CANONICAL

**Summary**
- Platform/Tenant Admin management of feature flags
- CRUD operations for feature flags (list, upsert, delete)
- Tenant-scoped flag definitions
- Protected flags (e.g., `FF_SERIAL_STD_HAT` cannot be deleted)

**Key actions**
- `list` - List feature flags for organization
- `upsert_tenant` - Create/update tenant feature flag
- `define_flag` - Define new feature flag
- `delete_flag` - Delete feature flag (with protection)

---

### source/assignment_api.php

- **module:** Token Assignment
- **domain:** [hatthasilpa] [dag-token] [assignment]
- **permission:** `hatthasilpa.job.assign`
- **status:** CANONICAL

**Summary**
- Manager-Operator assignment workflow
- View active jobs and unassigned tokens
- Assign tokens to operators or teams
- Operator assignment acceptance/rejection
- Assignment notifications

**Key actions**
- `get_active_jobs` - List active jobs for assignment
- `get_unassigned_tokens` - Get tokens needing assignment
- `assign_nodes` - Assign nodes to operators/teams
- `assign_tokens` - Direct token assignment
- `get_my_assignments` - Operator view of assigned work
- `accept_assignment` - Accept token assignment
- `reject_assignment` - Reject token assignment
- `get_notifications` - Assignment notifications

---

### source/assignment_plan_api.php

- **module:** Assignment Plans
- **domain:** [hatthasilpa] [assignment] [planning]
- **permission:** `manager.assignment`
- **status:** CANONICAL

**Summary**
- Manage assignment plans for automatic token assignment
- Node-level and Job-level plan CRUD
- Pin/Unpin assignments (override automatic assignment)
- Plan preview (simulate assignments)
- Bulk operations

**Key actions**
- `plan_node_list` - List node-level plans
- `plan_node_save` - Create/update node plan
- `plan_node_delete` - Delete node plan
- `plan_job_list` - List job-level plans
- `plan_job_save` - Create/update job plan
- `plan_preview` - Preview assignment simulation
- `pin` - Pin assignment (override plan)
- `unpin` - Unpin assignment
- `bulk_pin` - Bulk pin operations

---

### source/classic_api.php

- **module:** Classic Production API
- **domain:** [classic] [batch] [scan-based]
- **permission:** `classic.job.ticket`
- **status:** LEGACY_BUT_ACTIVE

**Summary**
- Classic batch job ticket management (batch-first, scan-based workflow)
- Create Classic job tickets from routing graph
- Scan in/out events for station tracking
- Sequence validation and WIP limits
- Reporting and metrics

**Key actions**
- `ticket_create_from_graph` - Create Classic job ticket from DAG graph
- `ticket_scan` - Scan in/out events (station tracking)
- `ticket_get` - Get ticket details
- `ticket_list` - List tickets (Server-side DataTable)
- `ticket_status` - Get ticket status and ready nodes
- `ticket_report` - SLA/Aging/Throughput metrics

**Notes:** Uses `production_type='classic'`, `process_mode='batch'`. Still active but no new features should be built here.

---

### source/dag_approval_api.php

- **module:** DAG Approval
- **domain:** [dag-token] [approval]
- **permission:** (implicit, based on token access)
- **status:** CANONICAL

**Summary**
- Handle approval requests for wait nodes
- Grant approvals to move tokens past wait nodes
- Phase 1.5: Wait Node Logic implementation

**Key actions**
- `grant` - Grant approval for wait node

---

### source/dag_routing_api.php

- **module:** DAG Routing
- **domain:** [dag-routing] [graph-management] [machine-allocation]
- **permission:** `dag.routing.manage`
- **status:** CANONICAL

**Summary**
- Manage routing graphs, nodes, edges for DAG-based production workflows
- Graph CRUD (create, list, publish, validate, delete)
- Node CRUD (create, update, delete) with behavior binding, execution mode, parallel/merge flags, machine binding
- Edge CRUD (create, update, delete)
- Graph status and bottleneck analysis
- **Task 17.2:** Validation layer for parallel split intent and merge node topology
- **Task 18:** Machine cycle awareness and throughput constraints

**Key actions**
- `graph_create` - Create new routing graph
- `graph_list` - List graphs (Server-side DataTable)
- `graph_get` - Get graph details
- `graph_publish` - Publish graph (make active)
- `graph_validate` - Validate graph structure
- `graph_save` - Save graph (manual save with validation)
- `graph_save_draft` - Save draft (autosave, warnings only)
- `graph_delete` - Delete graph
- `node_create` - Create graph node (with behavior_code, execution_mode, parallel/merge flags, machine binding)
- `node_update` - Update node (with validation for legacy node types)
- `node_delete` - Delete node
- `edge_create` - Create edge between nodes
- `edge_update` - Update edge
- `edge_delete` - Delete edge

**Node Configuration Fields (Task 15, 16, 17, 18):**
- `behavior_code` (Task 15) - Canonical behavior binding
- `execution_mode` (Task 16) - Execution mode (BATCH, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE)
- `derived_node_type` (Task 16) - Derived as `{behavior_code}:{execution_mode}`
- `is_parallel_split` (Task 17) - Flag: node starts parallel branches
- `is_merge_node` (Task 17) - Flag: node merges parallel branches
- `merge_mode` (Task 17) - Merge semantics (ALL, ANY, N_OF_M)
- `machine_binding_mode` (Task 18) - Machine binding (NONE, BY_WORK_CENTER, EXPLICIT)
- `machine_codes` (Task 18) - JSON array of machine codes (for EXPLICIT mode)

**Validation Rules (Task 17.2):**
- Rejects legacy node types: `split`, `join`, `wait` (error: `DAG_INVALID_NODE_TYPE`)
- Multi outgoing edge validation: Nodes with multiple outgoing edges must specify intent (Parallel Split or Decision/Conditional)
- Merge node validation: Merge nodes must have at least 2 incoming edges (error: `DAG_INVALID_MERGE_NODE`)
- Parallel split validation: Parallel split nodes must have at least 2 outgoing edges

**Machine Binding (Task 18):**
- `machine_binding_mode = NONE` - No machine binding (default)
- `machine_binding_mode = BY_WORK_CENTER` - Auto-select from work center machines
- `machine_binding_mode = EXPLICIT` - Use explicit machine_codes list
- Validates machine codes exist when using EXPLICIT mode (error: `DAG_INVALID_MACHINE_CONFIG`)

**Critical Invariants:**
- Graph must have exactly ONE START node
- Graph must have at least ONE END node
- All nodes must be reachable from START
- No circular dependencies allowed
- Legacy node types (`split`, `join`, `wait`) cannot be created (Task 17.2)
- Nodes with multiple outgoing edges must specify intent (Task 17.2)

---

### source/dag_token_api.php

- **module:** DAG Token Lifecycle
- **domain:** [dag-token] [hatthasilpa] [execution]
- **permission:** (implicit, based on job/token access)
- **status:** CANONICAL

**Summary**
- Core DAG token lifecycle management
- Token spawning, movement, completion, scrapping
- Work queue management
- Token execution (start, pause, resume, complete)
- QC result handling
- Self-check operations

**Key actions**
- `token_spawn` - Spawn tokens for job ticket
- `token_move` - Move token to next node
- `token_complete` - Complete token (reach end node)
- `token_scrap` / `scrap` - Scrap token
- `create_replacement` - Create replacement token
- `token_status` - Get token status
- `token_list` - List tokens
- `node_tokens` - Get tokens at specific node
- `get_work_queue` - Get operator work queue
- `start_token` - Start token execution
- `pause_token` - Pause token
- `resume_token` - Resume token
- `complete_token` - Complete token execution
- `qc_result` - Submit QC result
- `self_check` - Self-check operation
- `manager_all_tokens` - Manager view of all tokens

**Critical Notes:**
- This is the **core token execution engine**
- All token state changes go through this API
- Uses TokenLifecycleService, TokenWorkSessionService
- Enforces component completeness before routing

---

### source/dashboard_api.php

- **module:** Production Dashboard
- **domain:** [dashboard] [production] [metrics]
- **permission:** `dashboard.production.view`
- **status:** CANONICAL

**Summary**
- Real-time WIP/Throughput/Blockers dashboard endpoints
- Summary metrics (overall WIP, throughput, completion rate)
- Bottlenecks detection (top nodes/teams with highest WIP)
- Trends analysis (lead time, throughput over time)

**Key actions**
- `summary` - Overall production summary metrics
- `bottlenecks` - Detect production bottlenecks
- `trends` - Trends analysis over time
- `wip_by_node` - WIP breakdown by DAG node
- `wip_by_team` - WIP breakdown by team

---

### source/exceptions_api.php

- **module:** Exceptions Board
- **domain:** [production] [monitoring] [exceptions]
- **permission:** `production.view`
- **status:** CANONICAL

**Summary**
- Production problem detection and monitoring
- Stuck jobs detection (> 3 days without progress)
- Rework loop detection (> 2 QC failures)
- QC fail spike detection (> 2x 7-day average)
- Material shortage detection

**Key actions**
- (Read-only API - detection endpoints)
- Stuck jobs, rework loops, QC spikes, material shortages

**Notes:** All endpoints are read-only (no state changes). Uses cache headers for performance.

---

### source/hatthasilpa_component_api.php

- **module:** Component Serial Binding
- **domain:** [hatthasilpa] [component] [serial]
- **permission:** `hatthasilpa.job.ticket`
- **status:** CANONICAL

**Summary**
- Component Serial Binding API for Hatthasilpa Line
- Bind component serials to tokens
- Get component serials for token
- Component panel view

**Key actions**
- `bind_component_serial` - Bind component serial to token
- `get_component_serials` - Get component serials for token
- `get_component_panel` - Component panel view

---

### source/hatthasilpa_jobs_api.php

- **module:** Hatthasilpa Jobs
- **domain:** [hatthasilpa] [dag-job] [production]
- **permission:** `hatthasilpa.job.ticket`
- **status:** CANONICAL

**Summary**
- 1-click workflow for Atelier (luxury, flexible) production
- Creates job → spawns tokens → auto-assigns → ready!
- List Hatthasilpa Jobs (Server-side DataTable)
- Get Products for Atelier
- Get Templates for Product
- Create and Start Hatthasilpa Job (1-Click Workflow)

**Key actions**
- `list` - List Hatthasilpa jobs (Server-side DataTable)
- `get_products_atelier` - Get products for Atelier
- `get_templates_for_product` - Get DAG templates for product
- `get_bindings_for_product` - Get product-graph bindings
- `create` - Create Hatthasilpa job ticket
- `create_and_start` - Create and start job (1-click)
- `start_job` - Start job (spawn tokens)
- `get` - Get job details
- `update` - Update job
- `delete` - Delete job
- `start_production` - Start production
- `pause_job` - Pause job
- `cancel_job` - Cancel job
- `restore_to_planned` - Restore cancelled job

**Critical Notes:**
- This is the **main entrypoint** for Hatthasilpa job creation
- Calls `dag_token_api.php` for token spawning (via helper)
- Never touches `flow_token` directly

---

### source/hatthasilpa_operator_api.php

- **module:** Operator Availability
- **domain:** [hatthasilpa] [operator] [availability]
- **permission:** `hatthasilpa.job.ticket` / `hatthasilpa.operator.manage`
- **status:** CANONICAL

**Summary**
- Manage operator availability for Hatthasilpa workflow
- Get operator availability calendar
- Update operator availability

**Key actions**
- `get_operator_availability` - Get availability calendar
- `update_operator_availability` - Update availability

---

### source/leather_cut_bom_api.php

- **module:** Leather CUT BOM
- **domain:** [leather] [specialized] [cut]
- **permission:** `leather.cut.bom.view`, `leather.cut.bom.manage`
- **status:** CANONICAL

**Summary**
- API for BOM-based CUT input and overcut classification
- Load CUT BOM for token
- Save actual cut quantities
- Overcut classification

**Key actions**
- `load_cut_bom_for_token` - Load CUT BOM data
- `save_cut_actual_qty` - Save actual cut quantities
- `save_overcut_classification` - Classify overcut

---

### source/leather_sheet_api.php

- **module:** Leather Sheet Usage
- **domain:** [leather] [specialized] [sheet]
- **permission:** `leather.sheet.view`, `leather.sheet.use`
- **status:** CANONICAL

**Summary**
- API for leather sheet usage binding in CUT behavior
- List available sheets
- Bind sheet usage to token
- List sheet usage by token
- Unbind sheet usage

**Key actions**
- `list_available_sheets` - List available leather sheets
- `bind_sheet_usage` - Bind sheet to token
- `list_sheet_usage_by_token` - Get sheet usage for token
- `unbind_sheet_usage` - Unbind sheet

---

### source/people_api.php

- **module:** People System Integration
- **domain:** [people] [integration] [sync]
- **permission:** `people.read`
- **status:** CANONICAL

**Summary**
- API endpoints for People System integration (read-only sync)
- Manual sync trigger (admin only)
- Operator lookup with masking
- Team lookup
- Availability lookup

**Key actions**
- `sync_pull` - Manual sync trigger (admin)
- `lookup` - Operator lookup with masking
- `lookup_team` - Team lookup
- `lookup_availability` - Availability lookup

---

### source/platform_dashboard_api.php

- **module:** Platform Dashboard
- **domain:** [meta] [platform] [admin]
- **permission:** `platform.admin` (Platform Super Admin only)
- **status:** CANONICAL

**Summary**
- Platform Super Admin dashboard statistics
- Tenant statistics
- System-wide metrics

**Key actions**
- `get_stats` - Get platform statistics
- `get_tenants` - Get tenant list with stats

---

### source/platform_health_api.php

- **module:** Platform Health Check
- **domain:** [meta] [platform] [admin] [diagnostics]
- **permission:** `platform.admin` (Platform Super Admin only)
- **status:** CANONICAL

**Summary**
- Platform Super Admin system health diagnostics
- Comprehensive system health tests
- Database connectivity checks
- Migration status verification
- Performance metrics

**Key actions**
- `run_all_tests` - Run all health check tests

**Notes:** All endpoints are read-only (no state changes). Platform-level API (no tenant scope).

---

### source/platform_migration_api.php

- **module:** Platform Migrations
- **domain:** [meta] [platform] [admin] [migrations]
- **permission:** `platform.admin` (Platform Super Admin only)
- **status:** CANONICAL

**Summary**
- Platform Super Admin migration management
- List tenants
- List migrations
- Test migrations
- Deploy migrations
- Migration status
- Get migration logs

**Key actions**
- `list_tenants` - List all tenants
- `list_migrations` - List available migrations
- `test_migration` - Test migration (dry-run)
- `deploy_migration` - Deploy migration to tenant(s)
- `migration_status` - Get migration status
- `get_logs` - Get migration logs

---

### source/platform_roles_api.php

- **module:** Platform Roles
- **domain:** [meta] [platform] [admin] [rbac]
- **permission:** `platform.admin` (Platform Super Admin only)
- **status:** CANONICAL

**Summary**
- Platform Super Admin management of platform roles and permissions
- Role CRUD
- Permission assignment
- Role-permission mapping

**Key actions**
- `list_roles` - List platform roles
- `list_permissions` - List all permissions
- `get_role_permissions` - Get permissions for role
- `save_permissions` - Save role permissions
- `create_role` - Create new role
- `update_role` - Update role
- `delete_role` - Delete role

---

### source/platform_serial_metrics_api.php

- **module:** Serial Metrics
- **domain:** [meta] [platform] [serial] [metrics]
- **permission:** `platform.view.metrics`
- **status:** CANONICAL

**Summary**
- Provide metrics and monitoring data for serial number system
- Serial generation summary
- Generation rate
- Link health
- Error tracking

**Key actions**
- `summary` - Serial generation summary
- `generation_rate` - Generation rate metrics
- `link_health` - Link health status
- `errors` - Error tracking

---

### source/platform_serial_salt_api.php

- **module:** Serial Salt Management
- **domain:** [meta] [platform] [admin] [security]
- **permission:** `platform.admin` (Platform Super Admin only)
- **status:** CANONICAL

**Summary**
- Secure UI for generating and rotating serial number salts
- Salt status
- CSRF token generation
- Salt generation
- Salt rotation

**Key actions**
- `status` - Get salt status
- `csrf_token` - Get CSRF token
- `generate` - Generate new salt
- `rotate` - Rotate salt

---

### source/platform_tenant_owners_api.php

- **module:** Tenant Owners
- **domain:** [meta] [platform] [admin] [tenants]
- **permission:** `platform.admin` (Platform Super Admin only)
- **status:** CANONICAL

**Summary**
- Platform Super Admin management of tenant owners
- List tenant owners
- Get tenants for owner
- Create/update/delete tenant owners
- Manage tenant assignments

**Key actions**
- `list` - List tenant owners
- `get_tenants` - Get tenants for owner
- `create` - Create tenant owner
- `get` - Get owner details
- `update` - Update owner
- `manage_tenants` - Manage tenant assignments
- `delete` - Delete owner

---

### source/pwa_scan_api.php

- **module:** PWA Scan Station
- **domain:** [hatthasilpa] [pwa] [scan]
- **permission:** `hatthasilpa.job.ticket`
- **status:** CANONICAL

**Summary**
- PWA Scan Station for Quick Mode and Detail Mode
- Entity lookup (GET)
- Fetch active tickets for offline (GET)
- Check remaining quantity (GET)
- Action submission (POST - Quick/Detail Mode)
- Undo log API

**Key actions**
- (Entity lookup, ticket fetch, quantity check, action submission, undo)

---

### source/routing.php

- **module:** Routing V1 (Legacy)
- **domain:** [routing-v1] [legacy]
- **permission:** (implicit)
- **status:** LEGACY_READ_ONLY

**Summary**
- Legacy Routing V1 API (routing, routing_step tables)
- **Status:** READ-ONLY MODE
- All CREATE/UPDATE/DELETE operations are DISABLED
- Only READ operations allowed for historical records
- New routing creation should use DAG Designer (dag_routing_api.php)

**Key actions**
- (Read-only: list routings, list steps, list products, list work centers)

**Migration:** Task 14.1.3 - Routing V1 → V2 Migration. Use `dag_routing_api.php` for new routing management.

---

### source/team_api.php

- **module:** Team Management
- **domain:** [team] [assignment] [hybrid]
- **permission:** `manager.team`, `manager.team.members`, `team.lead.view`
- **status:** CANONICAL

**Summary**
- Team system for hybrid production model (Classic/Atelier/Hybrid)
- Team CRUD (create, list, update, delete)
- Team member management (add, remove, set role)
- Team workload calculation
- People monitor (real-time operator status)
- Available operators listing

**Key actions**
- (Team CRUD, member management, workload, availability)

---

### source/tenant_users_api.php

- **module:** Tenant Users
- **domain:** [meta] [tenant-admin] [users]
- **permission:** `org.user.manage` (Tenant Admin only)
- **status:** CANONICAL

**Summary**
- Tenant Admin management of users within their organization
- List/create/update/deactivate tenant users
- User role management
- Password reset
- Invitation system (future)

**Key actions**
- `list` - List tenant users
- `get` - Get user details
- `create` - Create tenant user
- `update` - Update user
- `update_status` - Activate/deactivate user
- `reset_password` - Reset user password
- `get_roles` - Get available roles
- `list_invites` - List pending invites
- `invite` - Invite user
- `resend_invite` - Resend invitation
- `cancel_invite` - Cancel invitation

---

### source/token_management_api.php

- **module:** Token Management
- **domain:** [dag-token] [hatthasilpa] [management]
- **permission:** `hatthasilpa.job.manage`
- **status:** CANONICAL

**Summary**
- Flexible token editing and management
- Reassign tokens to different operators
- Move tokens between nodes (manual routing)
- Edit token properties (serial, status)
- Cancel/scrap tokens
- View token history
- Bulk operations

**Key actions**
- `list_tokens` - List tokens
- `get_token` - Get token details
- `reassign_token` - Reassign token to operator
- `move_token` - Manual token routing
- `edit_serial` - Edit token serial
- `cancel_token` - Cancel token
- `resolve_redesign` - Resolve redesign requirement
- `list_redesign_queue` - List redesign queue
- `bulk_reassign` - Bulk reassign operations
- `get_available_nodes` - Get available nodes for routing
- `get_operators` - Get available operators
- `validate_serial` - Validate serial number

---

### source/trace_api.php

- **module:** Product Traceability
- **domain:** [trace] [serial] [history]
- **permission:** `trace.view`, `trace.manage`
- **status:** CANONICAL

**Summary**
- Product History / Serial Traceability endpoints
- Serial view (complete traceability data)
- Timeline (DAG-aware, split/join support)
- Components & Materials tracking
- QC & Rework history
- Share links (public access with scope control)
- Export (PDF/CSV)
- Reconciliation tools

**Key actions**
- `serial_view` - Complete serial traceability view
- `serial_timeline` - DAG-aware timeline
- `serial_components` - Component tracking
- `add_note` - Add traceability note
- `share_link_create` - Create public share link
- `share_link_revoke` - Revoke share link
- `reconcile` - Reconciliation tools
- `export` - Export traceability data (PDF/CSV)
- `finished_components` - Get finished components
- `serial_tree` - Serial tree view
- `trace_list` - List traceability records
- `trace_count` - Count traceability records

---

### source/api/public/serial_verify_api.php

- **module:** Serial Verification (Public)
- **domain:** [public] [customer] [verification]
- **permission:** (public, no authentication required)
- **status:** CANONICAL

**Summary**
- Customer-facing serial number verification endpoint
- Public access (no authentication required)
- Privacy modes: minimal, standard, internal
- Rate limiting per IP
- No PII exposure
- CORS support

**Key actions**
- (Public serial verification with privacy modes)

---

## 3. Domain Classification

### Production Domains

- **hatthasilpa** - Luxury/flexible production workflow (CANONICAL)
  - `hatthasilpa_jobs_api.php`
  - `hatthasilpa_component_api.php`
  - `hatthasilpa_operator_api.php`
  - `pwa_scan_api.php`

- **classic** - Batch-first, scan-based workflow (LEGACY_BUT_ACTIVE)
  - `classic_api.php`

- **dag-token** - DAG token lifecycle and execution (CANONICAL)
  - `dag_token_api.php`
  - `dag_approval_api.php`
  - `token_management_api.php`

- **dag-routing** - DAG graph/node/edge management (CANONICAL)
  - `dag_routing_api.php`
    - **Task 15:** Behavior binding (`behavior_code`, `behavior_version`)
    - **Task 16:** Execution mode binding (`execution_mode`, `derived_node_type`)
    - **Task 17:** Parallel/merge support (`is_parallel_split`, `is_merge_node`, `merge_mode`)
    - **Task 17.2:** Validation layer (legacy node rejection, multi outgoing edge validation, merge node validation)
    - **Task 18:** Machine cycle awareness (`machine_binding_mode`, `machine_codes`)

- **assignment** - Token assignment and planning (CANONICAL)
  - `assignment_api.php`
  - `assignment_plan_api.php`
  - `team_api.php`

### Specialized Domains

- **leather** - Leather-specific workflows (CANONICAL)
  - `leather_cut_bom_api.php`
  - `leather_sheet_api.php`

- **trace** - Product traceability (CANONICAL)
  - `trace_api.php`
  - `api/public/serial_verify_api.php`

- **dashboard** - Production monitoring (CANONICAL)
  - `dashboard_api.php`
  - `exceptions_api.php`

### Meta/Platform Domains

- **meta** - Platform administration (CANONICAL)
  - `platform_health_api.php`
  - `platform_dashboard_api.php`
  - `platform_migration_api.php`
  - `platform_roles_api.php`
  - `platform_serial_metrics_api.php`
  - `platform_serial_salt_api.php`
  - `platform_tenant_owners_api.php`
  - `admin_feature_flags_api.php`
  - `tenant_users_api.php`

- **integration** - External system integration (CANONICAL)
  - `people_api.php`

### Legacy Domains

- **routing-v1** - Legacy routing system (LEGACY_READ_ONLY)
  - `routing.php`

---

## 4. Status Distribution

- **CANONICAL:** 26 APIs
- **LEGACY_BUT_ACTIVE:** 1 API (`classic_api.php`)
- **LEGACY_READ_ONLY:** 1 API (`routing.php`)
- **DEPRECATED:** 0 APIs
- **EXPERIMENTAL:** 0 APIs

---

## 5. Permission Summary

### Production Permissions
- `hatthasilpa.job.ticket` - Main Hatthasilpa production permission
- `hatthasilpa.job.assign` - Token assignment
- `hatthasilpa.job.manage` - Token management
- `classic.job.ticket` - Classic production (legacy)
- `dag.routing.manage` - DAG graph management
- `manager.assignment` - Assignment planning
- `manager.team` - Team management
- `dashboard.production.view` - Production dashboard
- `production.view` - Production monitoring

### Specialized Permissions
- `leather.cut.bom.view`, `leather.cut.bom.manage` - Leather CUT
- `leather.sheet.view`, `leather.sheet.use` - Leather sheets
- `trace.view`, `trace.manage` - Traceability

### Platform Permissions
- `platform.admin` - Platform Super Admin
- `platform.view.metrics` - Platform metrics
- `platform.tenants.manage` - Tenant management
- `org.user.manage` - Tenant user management
- `admin.settings.manage` - Admin settings

### Integration Permissions
- `people.read` - People system integration

---

## 6. Notes for Developers

### When to Use Which API

1. **Creating Jobs:**
   - Use `hatthasilpa_jobs_api.php` for Hatthasilpa jobs (CANONICAL)
   - Use `classic_api.php` for Classic jobs (LEGACY_BUT_ACTIVE - avoid for new features)

2. **Token Operations:**
   - Use `dag_token_api.php` for token lifecycle (spawn, move, complete)
   - Use `token_management_api.php` for token editing/management
   - Use `assignment_api.php` for token assignment

3. **Graph Management:**
   - Use `dag_routing_api.php` for DAG graphs (CANONICAL)
   - Use `routing.php` only for reading legacy data (LEGACY_READ_ONLY)

4. **Monitoring:**
   - Use `dashboard_api.php` for production dashboard
   - Use `exceptions_api.php` for problem detection

5. **Platform Operations:**
   - Use `platform_*_api.php` files for platform admin
   - Use `tenant_users_api.php` for tenant user management

---

## 7. Migration Paths

### Routing V1 → DAG Routing
- **From:** `routing.php` (LEGACY_READ_ONLY)
- **To:** `dag_routing_api.php` (CANONICAL)
- **Status:** Migration complete (Task 14.1.3)

### Classic → Hatthasilpa
- **From:** `classic_api.php` (LEGACY_BUT_ACTIVE)
- **To:** `hatthasilpa_jobs_api.php` (CANONICAL)
- **Status:** Classic still active, but new features should use Hatthasilpa

---

## 8. API Dependencies

### Core Dependencies
- `dag_token_api.php` is called by:
  - `hatthasilpa_jobs_api.php` (for token spawning)
  - `assignment_api.php` (for token assignment)
  - `pwa_scan_api.php` (for token operations)

- `dag_routing_api.php` is used by:
  - `hatthasilpa_jobs_api.php` (for graph templates)
  - `classic_api.php` (for graph loading)

### Service Dependencies
- Most APIs use `TenantApiBootstrap` for tenant context
- Platform APIs use `CoreApiBootstrap` for platform context
- All APIs use standardized helpers: `RateLimiter`, `RequestValidator`, `Idempotency`

---

**Last Updated:** 2025-12-17  
**Maintained By:** Bellavier Group ERP Engineering Team

---

## 9. Recent Task Updates (Super DAG)

### Task 15: DAG Node Behavior Binding & Graph Standardization
**Date:** 2025-12-15  
**Impact:** `dag_routing_api.php`

**Changes:**
- Added `behavior_code` and `behavior_version` to node configuration
- Nodes now have explicit behavior binding (no implicit inference)
- Graph standardization ensures every node has canonical behavior

**API Updates:**
- `node_create` / `node_update`: Accept `behavior_code` (nullable, auto-resolved from work_center_behavior_map)
- `loadGraphWithVersion`: Includes `behavior_code` and `behavior_version` in node JSON

---

### Task 16: Execution Mode Binding (Behavior + Mode = NodeType)
**Date:** 2025-12-16  
**Impact:** `dag_routing_api.php`

**Changes:**
- Added `execution_mode` (BATCH, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE) to node configuration
- Added `derived_node_type` (format: `{behavior_code}:{execution_mode}`)
- NodeType Model: `NodeType = Behavior + ExecutionMode`

**API Updates:**
- `node_create` / `node_update`: Accept `execution_mode` (required for operation nodes, auto-resolved from canonical mapping)
- `loadGraphWithVersion`: Includes `execution_mode` and `derived_node_type` in node JSON
- Validation: Behavior + mode combination must be allowed (via `NodeTypeRegistry`)

**Related Services:**
- `BGERP\Dag\NodeTypeRegistry` - Validation and derivation logic for node types

---

### Task 17: Parallel Node Execution & Merge Semantics
**Date:** 2025-12-17  
**Impact:** `dag_routing_api.php`, `dag_token_api.php`, `DAGRoutingService`

**Changes:**
- Added parallel split and merge node support
- Token synchronization with `parallel_group_id` and `parallel_branch_key`
- Merge semantics: ALL (wait for all branches), ANY (first branch proceeds), N_OF_M (quorum-based)

**API Updates:**
- `node_create` / `node_update`: Accept `is_parallel_split`, `is_merge_node`, `merge_mode`
- `loadGraphWithVersion`: Includes parallel/merge flags in node JSON
- Token routing now handles parallel split (spawns multiple tokens) and merge (waits for branches)

**Related Services:**
- `BGERP\Service\TokenLifecycleService` - Token creation with parallel group tracking
- `BGERP\Service\DAGRoutingService` - Parallel split and merge execution logic

---

### Task 17.2: Parallel Split Validation & Legacy Control Node UI Cleanup
**Date:** 2025-12-17  
**Impact:** `dag_routing_api.php`, `graph_designer.js`, `GraphSaver.js`

**Changes:**
- Added validation layer to prevent ambiguous graphs
- Rejects legacy node types (`split`, `join`, `wait`)
- Enforces explicit intent for branching nodes (Parallel Split or Decision/Conditional)
- Validates merge node topology (must have ≥2 incoming edges)

**API Updates:**
- `node_create` / `node_update`: Reject legacy node types (error: `DAG_INVALID_NODE_TYPE`)
- `graph_save` / `graph_validate`: Validate multi outgoing edge intent and merge node topology
- Error codes: `DAG_INVALID_NODE_TYPE`, `DAG_INVALID_PARALLEL_INTENT`, `DAG_INVALID_MERGE_NODE`

**Frontend Updates:**
- `graph_designer.js`: Rejects legacy node types in `addNode()`
- `GraphSaver.js`: Validates graph structure before save (multi outgoing edge, merge node)

---

### Task 18: Machine Cycles & Throughput-Aware Execution
**Date:** 2025-12-17  
**Impact:** `dag_routing_api.php`, `DAGRoutingService`, `MachineRegistry`, `MachineAllocationService`

**Changes:**
- Added machine/equipment registry and allocation
- Node-level machine binding configuration (NONE, BY_WORK_CENTER, EXPLICIT)
- Machine-aware token routing with concurrency limits
- Machine cycle time tracking (started_at, completed_at)

**API Updates:**
- `node_create` / `node_update`: Accept `machine_binding_mode` and `machine_codes` (JSON array)
- `loadGraphWithVersion`: Includes machine binding fields in node JSON
- Validation: `machine_codes` required when `machine_binding_mode = EXPLICIT` (error: `DAG_INVALID_MACHINE_CONFIG`)

**Related Services:**
- `BGERP\Dag\MachineRegistry` - Machine discovery and properties
- `BGERP\Dag\MachineAllocationService` - Machine allocation and release logic
- `BGERP\Service\DAGRoutingService` - Machine-aware token routing (allocates machines on node entry, releases on completion)

**Database Schema:**
- `machine` table: Machine registry with `cycle_time_seconds`, `batch_capacity`, `concurrency_limit`
- `flow_token`: Added `machine_code`, `machine_cycle_started_at`, `machine_cycle_completed_at`
- `routing_node`: Added `machine_binding_mode`, `machine_codes`

---

### Task 15.1: Add PRESS Work Center & EMBOSS Behavior
**Date:** 2025-12-17  
**Impact:** `0002_seed_data.php`, `NodeTypeRegistry`

**Changes:**
- Added PRESS work center (Logo Press / Hot Stamp / Emboss operations)
- Added EMBOSS behavior (execution_mode: HAT_SINGLE)
- Added PRESS → EMBOSS mapping

**API Impact:**
- No direct API changes
- PRESS work center and EMBOSS behavior available for node configuration in `dag_routing_api.php`

**Related Services:**
- `BGERP\Dag\NodeTypeRegistry` - Added EMBOSS → HAT_SINGLE canonical mapping

---

