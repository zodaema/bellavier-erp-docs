# ERP API Inventory

**Generated:** 2025-12-09  
**Last Updated:** 2025-12-17  
**Purpose:** Complete map of all ERP API endpoints, actions, permissions, and database tables

**Recent Updates:**
- **Task 17.2 (2025-12-17):** Added validation layer to `dag_routing_api.php` (rejects legacy node types, validates parallel/merge topology)
- **Task 18 (2025-12-17):** Added machine binding fields (`machine_binding_mode`, `machine_codes`) to `dag_routing_api.php`
- **Task 16 (2025-12-16):** Added execution mode fields (`execution_mode`, `derived_node_type`) to `dag_routing_api.php`
- **Task 15 (2025-12-15):** Added behavior binding fields (`behavior_code`, `behavior_version`) to `dag_routing_api.php`

---

## Central Entry Points

### source/classic_api.php
- **Module:** Classic Job Ticket API (Batch-First Workflow)
- **Permission:** `classic.job.ticket`
- **Status:** CANONICAL_V2 (Classic production mode)
- **Actions:**
  - `ticket_create_from_graph`: Create Classic job ticket from routing graph
  - `ticket_scan`: Scan in/out events for station tracking
  - `ticket_get`: Get single ticket details
  - `ticket_list`: List tickets (Server-side DataTable)
  - `ticket_status`: Get ticket status summary
  - `ticket_report`: Generate ticket report
- **Tables (READ):** `job_ticket`, `job_task`, `routing_graph`, `routing_node`, `routing_edge`, `product`, `wip_log`
- **Tables (WRITE):** `job_ticket`, `job_task`, `wip_log`, `job_graph_instance`, `node_instance`, `flow_token`
- **Notes:**
  - Uses canonical tables (`job_ticket`, `job_task`, `wip_log`)
  - `production_type = 'classic'` for Classic tickets
  - `process_mode = 'batch'` for Classic tickets
  - Feature flag: `FF_CLASSIC_MODE`, `FF_CLASSIC_SHADOW_RUN`

---

### source/dag_token_api.php
- **Module:** DAG Token Lifecycle API
- **Permission:** `dag.routing.manage`, `hatthasilpa.routing.manage`, `hatthasilpa.job.ticket`, `dag.routing.view`
- **Status:** CANONICAL_V2 (Token management for DAG flow)
- **Actions:**
  - `token_spawn`: Spawn tokens for job instance
  - `token_move`: Move token to next node
  - `token_complete`: Complete token work at node
  - `token_scrap` / `scrap`: Scrap defective token
  - `create_replacement`: Create replacement token manually
  - `token_status`: Get token status
  - `token_list`: List tokens for job
  - `node_tokens`: Get tokens at specific node
  - `get_work_queue`: Get work queue for operator
  - `start_token`: Start token work (operator action)
  - `pause_token`: Pause token work
  - `resume_token`: Resume paused token
  - `complete_token`: Complete token work (operator action)
  - `qc_result`: Record QC pass/fail result
  - `self_check`: Self-check endpoint
  - `manager_all_tokens`: Manager view of all tokens
  - `token_help_start`: Help/replace operator (start)
  - `token_takeover`: Takeover token from another operator
- **Tables (READ):** `flow_token`, `routing_node`, `routing_edge`, `job_graph_instance`, `node_instance`, `token_event`, `token_work_session`, `token_assignment`, `routing_graph`
- **Tables (WRITE):** `flow_token`, `token_event`, `token_work_session`, `token_assignment`, `job_ticket_serial`, `serial_registry`
- **Notes:**
  - **CRITICAL INVARIANT:** `flow_token.current_node_id` references `routing_node.id_node` (NOT `node_instance.id_node_instance`)
  - Uses `TokenLifecycleService`, `TokenExecutionService`, `TokenWorkSessionService`
  - All token state changes through services (no direct SQL)
  - Idempotency required for all state changes
  - Internal API calls require `X-Internal-Request` header

---

### source/hatthasilpa_jobs_api.php
- **Module:** Hatthasilpa Jobs API (DAG-based Atelier Production)
- **Permission:** `hatthasilpa.job.ticket`
- **Status:** CANONICAL_V2 (Binding-first workflow)
- **Actions:**
  - `list`: List Hatthasilpa jobs (Server-side DataTable)
  - `get_products_atelier`: Get products supporting 'hatthasilpa' production
  - `get_templates_for_product`: Get templates for product (LEGACY - deprecated for DAG)
  - `get_bindings_for_product`: Get bindings for product (Binding-First - canonical)
  - `create`: Create job (planned - no tokens spawned)
  - `create_and_start`: Create and start job (1-click workflow - spawns tokens)
  - `start_job`: Start planned job (spawn tokens via `dag_token_api.php?action=token_spawn`)
  - `get`: Get single job details
  - `update`: Update job (job_name, target_qty, due_date, notes, status)
  - `delete`: Delete job (only if status='planned' or 'cancelled')
  - `start_production`: Alias for `start_job` (backward compatible)
  - `pause_job`: Pause job
  - `cancel_job`: Cancel job (soft-cancel tokens, archive instances)
  - `restore_to_planned`: Restore cancelled job to planned status
  - `complete_job`: Complete job
- **Tables (READ):** `job_ticket`, `product`, `routing_graph`, `job_graph_instance`, `product_graph_binding`, `flow_token`
- **Tables (WRITE):** `job_ticket`, `job_graph_instance`, `node_instance`
- **Notes:**
  - **Job/Token Boundary:** Job-level operations here, token operations via `dag_token_api.php`
  - Uses `JobCreationService::createFromBinding()` for binding-first workflow
  - Template-based workflow DISABLED (preserved for future use)
  - Internal calls to `dag_token_api.php` require headers: `X-Internal-Request`, `Idempotency-Key`
  - Never calls `TokenLifecycleService` directly (always via API helper)

---

### source/hatthasilpa_job_ticket.php
- **Module:** Hatthasilpa Job Ticket API (Complete CRUD + Workflow)
- **Permission:** `hatthasilpa.job.ticket`
- **Status:** CANONICAL_V2 (Legacy Linear workflow - coexists with DAG)
- **Actions:**
  - `delete`: Delete job ticket
  - `options`: Get options (MO, products, users)
  - (Additional actions: see file for complete list)
- **Tables (READ):** `job_ticket`, `job_task`, `wip_log`, `atelier_task_operator_session`, `product`, `mo`
- **Tables (WRITE):** `job_ticket`, `job_task`, `wip_log`, `atelier_task_operator_session`
- **Notes:**
  - **CRITICAL:** All WIP logs use soft-delete (`deleted_at IS NULL` filter required)
  - Status cascade: WIP log → Task status → Ticket status
  - Uses `LegacyRoutingAdapter` for V1 routing compatibility
  - Serial numbers via `SecureSerialGenerator` service

---

### source/job_ticket_dag.php
- **Module:** Job Ticket DAG Execution API
- **Permission:** `hatthasilpa.job.ticket`
- **Status:** CANONICAL_V2 (Node execution for DAG jobs)
- **Actions:**
  - `start`: Start node execution
  - `complete`: Complete node execution
  - `pause`: Pause node execution
  - `resume`: Resume node execution
  - `fail`: Fail node execution (trigger rework)
- **Tables (READ):** `job_ticket`, `routing_node`, `wip_log`
- **Tables (WRITE):** `job_ticket`, `wip_log`
- **Notes:**
  - Uses `JobTicketDagEngine` for token advancement
  - Marks job as rework on fail

---

### source/work_centers.php
- **Module:** Work Centers API
- **Permission:** `work_centers.view`, `work_centers.manage`
- **Status:** CANONICAL_V2
- **Actions:**
  - `list`: List work centers (with filters)
  - `get`: Get single work center
  - `create`: Create work center
  - `update`: Update work center
  - `delete`: Delete work center (if not referenced)
- **Tables (READ):** `work_center`, `routing_step` (for dependency check)
- **Tables (WRITE):** `work_center`
- **Notes:**
  - Schema migration runs automatically on first access
  - Deletion prevented if work center referenced in `routing_step`
  - Supports `is_active`, `sort_order`, `headcount`, `work_hours_per_day` columns

---

### source/uom.php
- **Module:** Units of Measure API
- **Permission:** `uom.view`, `uom.manage`
- **Status:** CANONICAL_V2
- **Actions:**
  - `list`: List UoM (Server-side DataTable)
  - `create`: Create UoM
  - `update`: Update UoM
  - `delete`: Delete UoM (if not in use)
- **Tables (READ):** `unit_of_measure`, `product`, `stock_transaction`
- **Tables (WRITE):** `unit_of_measure`
- **Notes:**
  - UOM code MUST be unique per tenant
  - Cannot delete if assigned to products or stock transactions
  - All operations wrapped in transactions

---

## API Files by Category

### DAG Routing & Design

#### source/dag_routing_api.php
- **Module:** DAG Routing Graph Designer API
- **Permission:** `dag.routing.manage`, `dag.routing.view`, `dag.routing.design.view`, `dag.routing.runtime.view`, `hatthasilpa.routing.manage`
- **Status:** CANONICAL_V2 (Graph design and management)
- **Actions:**
  - `graph_create`: Create new routing graph
  - `graph_list`: List routing graphs (Server-side DataTable)
  - `graph_favorite_toggle`: Toggle favorite status
  - `graph_get`: Get single graph with nodes/edges
  - `graph_save_draft`: Save graph draft
  - `graph_discard_draft`: Discard graph draft
  - `graph_save`: Save published graph (with versioning + validation)
  - `graph_autosave_positions`: Autosave node positions
  - `graph_validate`: Validate graph structure
  - `graph_simulate`: Simulate graph execution
  - `graph_publish`: Publish graph (create version)
  - `graph_delete`: Delete graph (soft delete)
  - `node_create`: Create node (with behavior_code, execution_mode, parallel/merge flags, machine binding)
  - `node_update`: Update node (with validation for legacy node types)
  - `node_delete`: Delete node
  - `edge_create`: Create edge
  - `edge_delete`: Delete edge
  - `get_graph_status`: Get graph status summary
  - `get_graph_structure`: Get graph structure (nodes + edges)
  - `graph_viewer`: Graph viewer endpoint
  - `get_bottlenecks`: Get bottleneck analysis
  - `graph_flag_get`: Get graph feature flags
  - `graph_flag_set`: Set graph feature flags
  - `graph_view`: View graph (runtime/design modes)
  - `graph_by_code`: Get graph by code
  - `graph_versions`: List graph versions
  - `graph_rollback`: Rollback to previous version
  - `graph_version_compare`: Compare graph versions
  - `graph_runtime`: Get runtime graph data
  - `routing_schema_check`: Check routing schema
  - `get_subgraph_usage`: Get subgraph usage
  - `graph_monitoring`: Graph monitoring data
  - `compare_versions`: Compare graph versions
- **Tables (READ):** `routing_graph`, `routing_graph_version`, `routing_node`, `routing_edge`, `routing_graph_favorite`, `routing_graph_var`, `routing_audit_log`, `work_center_behavior`, `work_center_behavior_map`, `machine`
- **Tables (WRITE):** `routing_graph`, `routing_graph_version`, `routing_node`, `routing_edge`, `routing_graph_favorite`, `routing_graph_var`, `routing_audit_log`
- **Node Configuration Fields (Task 15, 16, 17, 18):**
  - **Task 15:** `behavior_code` (VARCHAR(50)), `behavior_version` (INT)
  - **Task 16:** `execution_mode` (VARCHAR(50)), `derived_node_type` (VARCHAR(100))
  - **Task 17:** `is_parallel_split` (TINYINT(1)), `is_merge_node` (TINYINT(1)), `merge_mode` (ENUM: ALL, ANY, N_OF_M)
  - **Task 18:** `machine_binding_mode` (ENUM: NONE, BY_WORK_CENTER, EXPLICIT), `machine_codes` (TEXT, JSON array)
- **Validation Rules (Task 17.2):**
  - Rejects legacy node types: `split`, `join`, `wait` (error: `DAG_INVALID_NODE_TYPE`)
  - Validates multi outgoing edge intent (must specify Parallel Split or Decision/Conditional)
  - Validates merge node topology (must have ≥2 incoming edges, error: `DAG_INVALID_MERGE_NODE`)
  - Validates machine binding configuration (error: `DAG_INVALID_MACHINE_CONFIG`)
- **Notes:**
  - Supports draft layer (unpublished changes)
  - Versioning system for graph changes
  - Subgraph governance (parent-child relationships)
  - ETag/If-Match for concurrent edit protection
  - Supports both legacy (`hatthasilpa.routing.*`) and new (`dag.routing.*`) permissions
  - **Task 15:** Behavior binding ensures every node has canonical behavior
  - **Task 16:** Execution mode binding ensures NodeType = Behavior + ExecutionMode
  - **Task 17:** Parallel/merge support enables true parallel execution
  - **Task 17.2:** Validation layer prevents ambiguous graphs
  - **Task 18:** Machine cycle awareness enables throughput-constrained execution

---

### Assignment & Work Queue

#### source/assignment_api.php
- **Module:** Manager Assignment API
- **Permission:** `hatthasilpa.job.assign`, `manager.team`, `manager.assignment`
- **Status:** CANONICAL_V2 (Assignment management)
- **Actions:**
  - `get_active_jobs`: Get jobs with active tokens
  - `get_job_status`: Get job status summary
  - `get_unassigned_tokens`: Get unassigned tokens
  - `assign_nodes`: Assign nodes to operators
  - `get_node_assignments`: Get node assignments
  - `get_available_operators`: Get available operators
  - `assign_tokens`: Assign tokens to operators
  - `get_my_assignments`: Get operator's own assignments
  - `accept_assignment`: Accept assignment
  - `reject_assignment`: Reject assignment
  - `get_notifications`: Get assignment notifications
  - `mark_notification_read`: Mark notification as read
  - `preview`: Preview assignment
  - `override`: Override assignment
  - `pin`: Pin token to operator
  - `log_list`: List assignment logs
  - `log_export`: Export assignment logs
- **Tables (READ):** `job_ticket`, `flow_token`, `token_assignment`, `job_graph_instance`, `routing_node`, `assignment_plan_job`, `assignment_plan_node`, `assignment_log`
- **Tables (WRITE):** `token_assignment`, `assignment_plan_job`, `assignment_plan_node`, `assignment_log`
- **Notes:**
  - Uses `HatthasilpaAssignmentService` for assignment logic
  - Supports soft mode (respects existing manager assignments)

---

#### source/assignment_plan_api.php
- **Module:** Assignment Planning API
- **Permission:** `hatthasilpa.job.assign`, `work.queue.plan`
- **Status:** CANONICAL_V2
- **Actions:**
  - `plan_nodes_options`: Get node options for planning
  - `list_candidates`: List operator candidates
  - `plan_node_list`: List node plans
  - `plan_node_save`: Save node plan
  - `plan_node_delete`: Delete node plan
  - `plan_preview`: Preview plan
  - `plan_job_list`: List job plans
  - `plan_job_save`: Save job plan
  - `plan_job_delete`: Delete job plan
  - `pin`: Pin plan
  - `unpin`: Unpin plan
  - `bulk_pin`: Bulk pin plans
- **Tables (READ):** `assignment_plan_node`, `assignment_plan_job`, `routing_node`, `job_ticket`, `flow_token`
- **Tables (WRITE):** `assignment_plan_node`, `assignment_plan_job`

---

### Token Management

#### source/token_management_api.php
- **Module:** Token Management API (Admin/Manager Tools)
- **Permission:** `hatthasilpa.job.manage`
- **Status:** CANONICAL_V2
- **Actions:**
  - `list_tokens`: List tokens (Server-side DataTable)
  - `get_token`: Get single token details
  - `reassign_token`: Reassign token to operator
  - `move_token`: Move token to different node
  - `edit_serial`: Edit token serial number
  - `cancel_token`: Cancel token
  - `resolve_redesign`: Resolve redesign queue item
  - `list_redesign_queue`: List redesign queue
  - `bulk_reassign`: Bulk reassign tokens
  - `get_available_nodes`: Get available nodes for token
  - `get_operators`: Get available operators
  - `validate_serial`: Validate serial number
- **Tables (READ):** `flow_token`, `token_event`, `token_work_session`, `token_assignment`, `routing_node`, `job_ticket`, `job_ticket_serial`
- **Tables (WRITE):** `flow_token`, `token_assignment`, `token_event`, `job_ticket_serial`

---

### Traceability & Serial Numbers

#### source/trace_api.php
- **Module:** Product Traceability API
- **Permission:** `trace.view`, `trace.manage`
- **Status:** CANONICAL_V2
- **Actions:**
  - `serial_view`: View serial number details
  - `serial_timeline`: Get serial timeline
  - `serial_components`: Get serial components
  - `add_note`: Add note to serial
  - `share_link_create`: Create share link
  - `share_link_revoke`: Revoke share link
  - `reconcile`: Reconcile serial data
  - `export`: Export trace data
  - `finished_components`: Get finished components
  - `serial_tree`: Get serial tree
  - `trace_list`: List trace records
  - `trace_count`: Count trace records
- **Tables (READ):** `serial_registry`, `serial_link`, `product_trace`, `job_ticket_serial`, `flow_token`, `token_event`
- **Tables (WRITE):** `serial_link`, `product_trace`, `serial_share_link`

---

#### source/platform_serial_salt_api.php
- **Module:** Serial Number Salt Management API
- **Permission:** Admin only
- **Status:** CANONICAL_V2
- **Actions:**
  - `status`: Get salt status
  - `csrf_token`: Get CSRF token
  - `generate`: Generate new salt
  - `rotate`: Rotate salt
- **Tables (READ):** `serial_salt` (core DB)
- **Tables (WRITE):** `serial_salt` (core DB)

---

#### source/platform_serial_metrics_api.php
- **Module:** Serial Number Metrics API
- **Permission:** Admin only
- **Status:** CANONICAL_V2
- **Actions:**
  - `summary`: Get metrics summary
  - `generation_rate`: Get generation rate
  - `link_health`: Get link health
  - `errors`: Get serial errors
- **Tables (READ):** `serial_registry` (core DB), `serial_link` (core DB), `serial_link_outbox` (core DB)

---

### PWA & Mobile

#### source/pwa_scan_api.php
- **Module:** PWA Scan Station API
- **Permission:** `hatthasilpa.job.ticket`
- **Status:** CANONICAL_V2 (Mobile/PWA workflow)
- **Actions:**
  - `lookup`: Lookup job/token by code
  - `fetch_active_tickets`: Get active tickets
  - `check_remaining`: Check remaining work
  - `submit_quick`: Submit quick mode scan
  - `submit_detail`: Submit detail mode scan
  - `undo_log`: Undo last log entry
- **Tables (READ):** `job_ticket`, `flow_token`, `routing_node`, `wip_log`
- **Tables (WRITE):** `wip_log`, `flow_token`, `token_event`

---

### Leather & Material Management

#### source/leather_cut_bom_api.php
- **Module:** Leather Cut BOM API
- **Permission:** `leather.cut.bom.view`, `leather.cut.bom.manage`
- **Status:** CANONICAL_V2
- **Actions:**
  - `load_cut_bom_for_token`: Load cut BOM for token
  - `save_cut_actual_qty`: Save actual cut quantity
  - `save_overcut_classification`: Save overcut classification
- **Tables (READ):** `cut_bom`, `flow_token`, `material_lot`, `leather_sheet_usage`
- **Tables (WRITE):** `cut_bom`, `leather_sheet_usage`

---

#### source/leather_sheet_api.php
- **Module:** Leather Sheet Usage API
- **Permission:** `leather.sheet.view`, `leather.sheet.use`
- **Status:** CANONICAL_V2
- **Actions:**
  - `list_available_sheets`: List available leather sheets
  - `bind_sheet_usage`: Bind sheet to token
  - `list_sheet_usage_by_token`: Get sheet usage for token
  - `unbind_sheet_usage`: Unbind sheet from token
- **Tables (READ):** `leather_sheet`, `leather_sheet_usage`, `flow_token`, `material_lot`
- **Tables (WRITE):** `leather_sheet_usage`

---

#### source/hatthasilpa_component_api.php
- **Module:** Hatthasilpa Component Serial API
- **Permission:** `hatthasilpa.job.ticket`
- **Status:** CANONICAL_V2
- **Actions:**
  - `bind_component_serial`: Bind component serial to token
  - `get_component_serials`: Get component serials for token
  - `get_component_panel`: Get component panel data
- **Tables (READ):** `component_serial_binding`, `flow_token`, `job_ticket_serial`
- **Tables (WRITE):** `component_serial_binding`

---

### Team & People Management

#### source/team_api.php
- **Module:** Team Management API
- **Permission:** `manager.team`, `manager.team.members`, `people.view_detail`
- **Status:** CANONICAL_V2
- **Actions:**
  - `list`: List teams
  - `list_with_stats`: List teams with statistics
  - `get`: Get single team
  - `get_detail`: Get team detail
  - `save`: Create/update team
  - `delete`: Delete team
  - `get_next_code`: Get next team code
  - `get_members`: Get team members
  - `member_add` / `add_member`: Add member to team
  - `member_remove` / `remove_member`: Remove member from team
  - `member_set_role` / `change_member_role`: Change member role
  - `available_operators`: Get available operators
  - `workload_summary`: Get workload summary
  - `workload_summary_all`: Get workload summary for all teams
  - `current_work`: Get current work
  - `assignment_history`: Get assignment history
  - `assignment_preview`: Preview assignment
  - `people_monitor_list`: List people monitor data
  - `member_leave_create`: Create member leave
  - `member_leave_delete`: Delete member leave
  - `member_leave_list`: List member leaves
  - `people_monitor_set_availability`: Set operator availability
- **Tables (READ):** `team`, `team_member`, `account` (core DB), `operator_availability`, `flow_token`, `token_assignment`
- **Tables (WRITE):** `team`, `team_member`, `operator_availability`, `operator_leave`

---

#### source/hatthasilpa_operator_api.php
- **Module:** Hatthasilpa Operator Availability API
- **Permission:** `hatthasilpa.job.ticket`
- **Status:** CANONICAL_V2
- **Actions:**
  - `get_operator_availability`: Get operator availability
  - `update_operator_availability`: Update operator availability
- **Tables (READ):** `operator_availability`, `account` (core DB)
- **Tables (WRITE):** `operator_availability`

---

#### source/people_api.php
- **Module:** People Sync API
- **Permission:** Various
- **Status:** CANONICAL_V2
- **Actions:**
  - `sync_pull`: Pull people data from core
  - `lookup`: Lookup person
  - `lookup_team`: Lookup team
  - `lookup_availability`: Lookup availability
- **Tables (READ):** `account` (core DB), `team_member`, `operator_availability`

---

### Dashboard & Monitoring

#### source/dashboard_api.php
- **Module:** Production Dashboard API
- **Permission:** `dashboard.production.view`
- **Status:** CANONICAL_V2
- **Actions:**
  - `summary`: Get dashboard summary
  - `bottlenecks`: Get bottleneck analysis
  - `trends`: Get trends data
  - `wip_by_node`: Get WIP by node
  - `wip_by_team`: Get WIP by team
- **Tables (READ):** `flow_token`, `token_event`, `routing_node`, `job_ticket`, `team`, `token_assignment`
- **Tables (WRITE):** None

---

#### source/exceptions_api.php
- **Module:** Exceptions Board API
- **Permission:** `dashboard.production.view`
- **Status:** CANONICAL_V2
- **Actions:**
  - `all`: Get all exceptions
  - `stuck_jobs`: Get stuck jobs
  - `rework_loops`: Get rework loops
  - `fail_spikes`: Get failure spikes
  - `shortages`: Get material shortages
- **Tables (READ):** `flow_token`, `token_event`, `job_ticket`, `material_shortage`
- **Tables (WRITE):** None

---

#### source/platform_health_api.php
- **Module:** Platform Health Check API
- **Permission:** Admin only
- **Status:** CANONICAL_V2
- **Actions:**
  - `run_all_tests`: Run all health checks
- **Tables (READ):** All (diagnostics)
- **Tables (WRITE):** None

---

#### source/platform_dashboard_api.php
- **Module:** Platform Dashboard API
- **Permission:** Admin only
- **Status:** CANONICAL_V2
- **Actions:**
  - `get_stats`: Get platform statistics
  - `get_tenants`: Get tenant list
- **Tables (READ):** `organization` (core DB), tenant DBs (aggregated stats)

---

### Platform Administration

#### source/platform_roles_api.php
- **Module:** Platform Roles API
- **Permission:** Admin only
- **Status:** CANONICAL_V2
- **Actions:**
  - `list_roles`: List platform roles
  - `list_permissions`: List permissions
  - `get_role_permissions`: Get role permissions
  - `save_permissions`: Save role permissions
  - `create_role`: Create role
  - `update_role`: Update role
  - `delete_role`: Delete role
- **Tables (READ):** `platform_role`, `permission`, `role_permission` (core DB)
- **Tables (WRITE):** `platform_role`, `role_permission` (core DB)

---

#### source/platform_tenant_owners_api.php
- **Module:** Platform Tenant Owners API
- **Permission:** Admin only
- **Status:** CANONICAL_V2
- **Actions:**
  - `list`: List tenant owners
  - `get_tenants`: Get tenants for owner
  - `create`: Create tenant owner
  - `get`: Get single tenant owner
  - `update`: Update tenant owner
  - `manage_tenants`: Manage tenant associations
  - `delete`: Delete tenant owner
- **Tables (READ):** `tenant_owner`, `organization` (core DB)
- **Tables (WRITE):** `tenant_owner`, `tenant_owner_org` (core DB)

---

#### source/platform_migration_api.php
- **Module:** Platform Migration Wizard API
- **Permission:** Admin only
- **Status:** CANONICAL_V2
- **Actions:**
  - `list_tenants`: List tenants
  - `list_migrations`: List migrations
  - `test_migration`: Test migration
  - `deploy_migration`: Deploy migration
  - `migration_status`: Get migration status
  - `get_logs`: Get migration logs
- **Tables (READ):** `tenant_schema_migrations`, `organization` (core DB)
- **Tables (WRITE):** `tenant_schema_migrations` (core DB)

---

#### source/tenant_users_api.php
- **Module:** Tenant Users API
- **Permission:** `org.user.manage`
- **Status:** CANONICAL_V2
- **Actions:**
  - `list`: List tenant users
  - `get`: Get single user
  - `create`: Create user
  - `update`: Update user
  - `update_status`: Update user status
  - `reset_password`: Reset password
  - `get_roles`: Get user roles
  - `list_invites`: List user invites
  - `invite`: Invite user
  - `resend_invite`: Resend invite
  - `cancel_invite`: Cancel invite
- **Tables (READ):** `account` (core DB), `account_org`, `tenant_role`, `tenant_role_permission`
- **Tables (WRITE):** `account` (core DB), `account_org`, `user_invite` (core DB)

---

#### source/admin_feature_flags_api.php
- **Module:** Feature Flags API
- **Permission:** `admin.settings.manage`, `admin.user.manage`, `admin.role.manage`, `org.settings.manage`
- **Status:** CANONICAL_V2
- **Actions:**
  - `list`: List feature flags
  - `upsert_tenant`: Upsert tenant flag
  - `define_flag`: Define new flag
  - `delete_flag`: Delete flag
- **Tables (READ):** `feature_flag`, `feature_flag_scope`
- **Tables (WRITE):** `feature_flag`, `feature_flag_scope`

---

### DAG Approval

#### source/dag_approval_api.php
- **Module:** DAG Approval API
- **Permission:** `hatthasilpa.job.manage`
- **Status:** CANONICAL_V2
- **Actions:**
  - `grant`: Grant approval
- **Tables (READ):** `flow_token`, `routing_node`, `approval_request`
- **Tables (WRITE):** `approval_request`, `approval_grant`

---

## Legacy/Deprecated APIs

### source/routing.php
- **Module:** Legacy Routing V1 API
- **Permission:** `routing.view`, `routing.manage`
- **Status:** **READ_ONLY** (Deprecated - use DAG Designer instead)
- **Actions:**
  - `products`: List products (READ)
  - `list`: List routings (READ)
  - `create`: **DISABLED** (returns 410 error - use DAG Designer)
  - `delete`: **DISABLED** (returns 410 error)
  - `work_centers`: List work centers (READ)
  - `steps`: List steps (READ)
  - `add_step`: **DISABLED** (returns 410 error - use DAG Designer)
  - `get_step`: Get step (READ)
  - `update_step`: **DISABLED** (returns 410 error)
- **Tables (READ):** `routing` (V1 legacy), `routing_step` (V1 legacy), `product`, `work_center`
- **Tables (WRITE):** None (all writes disabled)
- **Notes:**
  - ⚠️ **DEPRECATED:** All CREATE/UPDATE/DELETE operations disabled
  - Only READ operations allowed for historical records
  - New routing creation must use DAG Designer (`dag_routing_api.php`)
  - Migration path: V1 (`routing`, `routing_step`) → V2 (`routing_graph`, `routing_node`, `routing_edge`)
  - `LegacyRoutingAdapter` provides backward compatibility layer

---

## Service Dependencies

### Core Services Used Across APIs

- **JobCreationService**: Creates DAG jobs from bindings (used by `hatthasilpa_jobs_api.php`)
- **TokenLifecycleService**: Manages token spawn, move, complete (used by `dag_token_api.php`)
- **TokenExecutionService**: Executes token work with locking (used by `dag_token_api.php`)
- **TokenWorkSessionService**: Manages operator work sessions (used by `dag_token_api.php`)
- **DAGRoutingService**: Manages DAG routing logic (used by `dag_routing_api.php`)
  - **Task 17:** Handles parallel split and merge node execution
  - **Task 18:** Integrates machine allocation service for machine-aware routing
- **MachineRegistry** (Task 18): Manages machine discovery and properties (used by `DAGRoutingService`)
- **MachineAllocationService** (Task 18): Manages machine allocation and release (used by `DAGRoutingService`)
- **NodeTypeRegistry** (Task 16): Validates execution modes and derives node types (used by `dag_routing_api.php`)
- **HatthasilpaAssignmentService**: Manages token assignments (used by `assignment_api.php`)
- **UnifiedSerialService**: Manages serial number generation (used by multiple APIs)
- **ProductionRulesService**: Validates production rules (used by `hatthasilpa_jobs_api.php`)
- **DatabaseTransaction**: Provides transaction wrapper (used by multiple APIs)

---

## API Response Format

All APIs use standardized JSON response format:

```json
{
  "ok": true,
  "data": {...},
  "message": "..."
}
```

or

```json
{
  "ok": false,
  "error": "...",
  "app_code": "MODULE_400_ERROR_CODE"
}
```

---

## Common Headers

- `X-Correlation-Id`: Request correlation ID (auto-generated if missing)
- `X-AI-Trace`: Execution trace metadata (auto-added)
- `Idempotency-Key`: Idempotency key for state-changing operations (optional)
- `X-Internal-Request`: Marks internal API-to-API calls
- `If-Match`: ETag for optimistic concurrency control

---

## Rate Limiting

All APIs implement rate limiting via `RateLimiter::check()`:
- Default: 120 requests per 60 seconds per user
- Rate limit identifier: Module name (e.g., 'hatthasilpa_jobs', 'dag_token')

---

## Maintenance Mode

All APIs check for maintenance mode:
- File: `storage/maintenance.flag`
- Response: 503 Service Unavailable with `Retry-After: 60` header

---

## Multi-Tenant Architecture

- **Core DB:** `bgerp` (shared across tenants)
  - Tables: `organization`, `account`, `permission`, `platform_role`, `serial_registry`, `serial_link`
- **Tenant DB:** `bgerp_t_{org_code}` (per-tenant)
  - Tables: All production tables (`job_ticket`, `flow_token`, `routing_graph`, etc.)
- **Tenant Resolution:** Via `TenantApiBootstrap::init()` or `tenant_db()` helper

---

## Feature Flags

Feature flags control system behavior per tenant:
- `FF_CLASSIC_MODE`: Enable Classic production mode
- `FF_CLASSIC_SHADOW_RUN`: Shadow run mode for Classic
- Managed via `FeatureFlagService` and `admin_feature_flags_api.php`

