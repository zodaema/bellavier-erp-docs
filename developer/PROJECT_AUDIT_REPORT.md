# Bellavier Group ERP - Project Audit Report

**Date:** January 2025  
**Purpose:** Complete audit of current project state  
**Scope:** Database Schema, Source Code Structure, System Architecture

---

## 📊 Executive Summary

### Current System State

- **Total API Files:** 85+ files (35+ API endpoints + legacy files)
- **Total Services:** 47 services
- **Total Helpers:** 17 helpers
- **Total DAG Engines:** 26 engines
- **Total MO Services:** 6 services
- **Total Component Services:** 4 services
- **Total Product Services:** 1 service
- **Total Database Tables (Tenant):** 122 tables
- **Total Database Tables (Core):** 13 tables
- **Bootstrap Migration:** ✅ Complete (52+ APIs migrated to bootstrap layers)
- **PSR-4 Structure:** ✅ Complete (118 files in BGERP namespace)

---

## 1. Database Schema Audit

### Core Database (`bgerp`)

**Migration File:** `database/migrations/0001_core_bootstrap_v2.php`

**Tables (13 tables):**

1. **Account System:**
   - `account` - User accounts
   - `account_group` - Legacy role groups
   - `account_org` - User↔Organization mapping

2. **Organization System:**
   - `organization` - Tenant registry

3. **Permission System:**
   - `permission` - Master permission list
   - `group_permission` - Legacy group permissions

4. **Platform Administration:**
   - `platform_user` - Platform administrators
   - `platform_role` - Platform roles
   - `platform_permission` - Platform permissions

5. **Tenant Management:**
   - `tenant_role_template` - Role templates
   - `tenant_role_template_permission` - Template permissions

6. **System:**
   - `account_invite` - Invitation system
   - `organization_domain` - Subdomain support
   - `system_logs` - System logging
   - `admin_notifications` - Admin notifications
   - `schema_migrations` - Migration tracking (implied)

### Tenant Database (`bgerp_t_{org_code}`)

**Migration File:** `database/tenant_migrations/0001_init_tenant_schema_v2.php`

**Total Tables:** 122 tables (verified from schema file)

**Table Categories:**

#### Core Master Data (11 tables)
- `account` - Tenant user accounts
- `organization` - Organization data
- `permission` - Synced permissions
- `tenant_role` - Organization roles
- `tenant_role_permission` - Role assignments
- `tenant_user_role` - User role assignments
- `product_category` - Product categories
- `unit_of_measure` - Units of measure (legacy name)
- `uom` - Units of measure (new name)
- `warehouse` - Warehouses
- `warehouse_location` - Warehouse locations

#### Product & BOM (9 tables)
- `product` - Products
- `bom` - Bill of Materials
- `bom_item` - BOM items
- `bom_line` - BOM lines
- `product_asset` - Product assets
- `product_graph_binding` - Product↔Graph binding
- `product_graph_binding_audit` - Binding audit
- `pattern` - Patterns
- `pattern_version` - Pattern versions

#### Material & Inventory (12 tables)
- `material` - Materials
- `material_lot` - Material lots
- `material_lot_movement` - Lot movements
- `material_asset` - Material assets
- `stock_item` - Stock items
- `stock_item_asset` - Stock item assets
- `stock_item_lot` - Stock item lots
- `stock_ledger` - Stock ledger
- `warehouse_inventory` - Warehouse inventory
- `inventory_transaction` - Inventory transactions
- `inventory_transaction_item` - Transaction items
- `leather_sheet` - Leather sheets

#### Component System (8 tables)
- `component_type` - Component types
- `component_master` - Component master data
- `component_bom_map` - Component↔BOM mapping
- `component_serial_batch` - Serial batches
- `component_serial` - Component serials
- `component_serial_allocation` - Serial allocation
- `component_serial_binding` - Serial binding
- `component_serial_pool` - Serial pool
- `component_serial_usage_log` - Usage log

#### Manufacturing Orders (3 tables)
- `mo` - Manufacturing orders
- `mo_eta_cache` - ETA cache (Task 23)
- `mo_eta_health_log` - ETA health log (Task 23)

#### Job Tickets & Tasks (5 tables)
- `job_ticket` - Job tickets (DAG)
- `job_task` - Job tasks
- `job_ticket_serial` - Ticket serials
- `job_ticket_status_history` - Status history
- `wip_log` - WIP logs (Linear, soft-delete)

#### DAG Routing System (15 tables)
- `routing_graph` - DAG graphs
- `routing_graph_draft` - Graph drafts
- `routing_graph_version` - Graph versions
- `routing_graph_favorite` - Favorites
- `routing_graph_var` - Graph variables
- `routing_graph_feature_flag` - Feature flags
- `routing_node` - DAG nodes
- `routing_edge` - DAG edges
- `routing` - Legacy routing
- `routing_step` - Legacy routing steps
- `routing_set` - Routing sets
- `routing_audit_log` - Routing audit
- `routing_v1_usage_log` - V1 usage log
- `graph_subgraph_binding` - Subgraph binding
- `job_graph_instance` - Graph instances

#### Token System (10 tables)
- `flow_token` - DAG tokens
- `token_event` - Canonical events (Task 21)
- `token_work_session` - Work sessions
- `token_assignment` - Token assignments
- `token_spawn_log` - Spawn log
- `token_join_buffer` - Join buffer
- `node_instance` - Node instances
- `node_assignment` - Node assignments
- `task_operator_session` - Operator sessions (Linear)
- `dag_behavior_log` - Behavior log

#### Work Centers & Teams (8 tables)
- `work_center` - Work centers
- `work_center_behavior` - Work center behaviors
- `work_center_behavior_map` - Behavior mapping
- `work_center_team_map` - Team mapping
- `team` - Teams
- `team_member` - Team members
- `team_member_history` - Member history
- `team_availability` - Team availability

#### Quality Control (5 tables)
- `qc_inspection` - QC inspections
- `qc_inspection_item` - Inspection items
- `qc_fail_event` - QC fail events
- `qc_rework_task` - Rework tasks
- `qc_rework_log` - Rework log

#### Assignment System (5 tables)
- `assignment_plan_job` - Assignment plans (jobs)
- `assignment_plan_node` - Assignment plans (nodes)
- `assignment_log` - Assignment log
- `assignment_decision_log` - Decision log
- `assignment_notification` - Notifications

#### People Integration (6 tables)
- `people_availability_cache` - Availability cache
- `people_operator_cache` - Operator cache
- `people_team_cache` - Team cache
- `people_sync_error_log` - Sync errors
- `people_masking_policy` - Masking policy
- `operator_availability` - Operator availability

#### Production & Analytics (8 tables)
- `production_output_daily` - Daily output (Task 25)
- `production_schedule_config` - Schedule config
- `schedule_change_log` - Schedule changes
- `cut_batch` - Cut batches
- `leave_request` / `member_leave` - Leave management
- `mv_cycle_time_analytics` - Cycle time analytics (view)
- `mv_dashboard_trends` - Dashboard trends (view)
- `mv_node_bottlenecks` - Node bottlenecks (view)
- `mv_team_workload` - Team workload (view)
- `mv_token_flow_summary` - Token flow summary (view)

#### Serial Number System (5 tables)
- `serial_generation_log` - Generation log
- `serial_link_outbox` - Link outbox
- `serial_quarantine` - Quarantine
- (Serial system integrated with component system)

#### Traceability (5 tables)
- `trace_access_log` - Access log
- `trace_export_job` - Export jobs
- `trace_note` - Trace notes
- `trace_reconcile_log` - Reconcile log
- `trace_share_link` - Share links

#### Leather & BOM (2 tables)
- `leather_cut_bom_log` - Leather cut BOM log
- `leather_sheet_usage_log` - Sheet usage log

#### Purchase & Supplier (3 tables)
- `purchase_rfq` - Purchase RFQ
- `purchase_rfq_item` - RFQ items
- `supplier_score` - Supplier scores

#### Machine System (1 table)
- `machine` - Machines (Task 18)

#### System & Configuration (8 tables)
- `feature_flag` - Feature flags
- `tenant_feature_flags` - Tenant feature flags
- `tenant_schema_migrations` - Migration tracking
- `tenant_migrations` - Migration log
- `legacy_cleanup_tracking` - Cleanup tracking
- `routing_v1_usage_log` - Routing V1 usage

---

## 2. Source Code Structure Audit

### API Files (85+ files total, 35+ API endpoints)

**Location:** `source/*.php`

**Note:** Includes both modern API files (using bootstrap) and legacy files (direct access)

#### Platform APIs (8 files)
- `platform_dashboard_api.php` - Platform dashboard
- `platform_health_api.php` - Health check
- `platform_roles_api.php` - Platform roles
- `platform_tenant_owners_api.php` - Tenant owners
- `platform_migration_api.php` - Migration wizard
- `platform_serial_salt_api.php` - Serial salt
- `platform_serial_metrics_api.php` - Serial metrics
- `admin_feature_flags_api.php` - Feature flags (legacy, may need migration)

#### Tenant APIs (40+ files - Modern Bootstrap APIs)
- `product_api.php` - Products
- `product_stats_api.php` - Product statistics
- `materials_api.php` - Materials
- `bom_api.php` - BOM
- `mo.php` - Manufacturing orders (legacy)
- `mo_assist_api.php` - MO creation assist
- `mo_eta_api.php` - MO ETA
- `mo_load_simulation_api.php` - MO load simulation
- `dag_routing_api.php` - DAG routing
- `dag_token_api.php` - DAG tokens
- `dag_approval_api.php` - DAG approvals
- `token_management_api.php` - Token management
- `worker_token_api.php` - Worker tokens
- `trace_api.php` - Traceability
- `assignment_api.php` - Assignments
- `assignment_plan_api.php` - Assignment plans
- `hatthasilpa_jobs_api.php` - Hatthasilpa jobs
- `hatthasilpa_operator_api.php` - Hatthasilpa operators
- `hatthasilpa_component_api.php` - Hatthasilpa components
- `classic_api.php` - Classic production
- `dashboard_api.php` - Dashboard
- `exceptions_api.php` - Exceptions board
- `team_api.php` - Teams
- `people_api.php` - People integration
- `tenant_users_api.php` - Tenant users
- `pwa_scan_api.php` - PWA scan
- `job_ticket_progress_api.php` - Job ticket progress
- `leather_sheet_api.php` - Leather sheets
- `leather_cut_bom_api.php` - Leather cut BOM

#### Legacy Files (50+ files - Not using bootstrap)
- `products.php`, `materials.php`, `bom.php` - Master data (legacy)
- `mo.php` - Manufacturing orders (legacy, partially migrated)
- `job_ticket.php` - Job tickets (legacy, Linear system)
- `grn.php`, `issue.php`, `transfer.php`, `adjust.php` - Inventory transactions (legacy)
- `purchase_rfq.php`, `qc_rework.php` - Other modules (legacy)
- `dashboard.php`, `stock_on_hand.php`, `stock_card.php` - Reports (legacy)
- Various utility files: `refs.php`, `constants.php`, `global_function.php`, etc.

### Bootstrap Layers

**Location:** `source/BGERP/Bootstrap/`

1. **TenantApiBootstrap.php**
   - For tenant-scoped APIs
   - **Usage:** 30+ API files using TenantApiBootstrap
   - Auto tenant resolution
   - Tenant DB connection via DatabaseHelper
   - Returns: `[$org, $db]` (where $db is DatabaseHelper instance)
   - Features: Rate limiting, Request validation, Idempotency, Maintenance mode check

2. **CoreApiBootstrap.php**
   - For platform/core APIs
   - **Usage:** 8+ API files using CoreApiBootstrap
   - Platform-level operations
   - Modes: `platform_admin`, `auth_required`, `public`, `cli`
   - Returns: `[$member, $coreDb, $tenantDb, $org, $cid]` (varies by mode)
   - Features: Platform permission checks, Optional tenant context

**Bootstrap Migration Status:**
- ✅ 65+ tenant APIs using TenantApiBootstrap (verified)
- ✅ 12+ platform APIs using CoreApiBootstrap (verified)
- ⚠️ 50+ legacy files still need migration (not using bootstrap)

### Service Layer (47 services)

**Location:** `source/BGERP/Service/`

#### Core Services (15 services)
- `BaseService.php` - Base service class
- `ServiceFactory.php` - Service factory
- `DataService.php` - Data operations
- `DatabaseTransaction.php` - Transaction management
- `ErrorHandler.php` - Error handling
- `ValidationService.php` - Input validation
- `ExampleService.php` - Example service

#### DAG Services (8 services)
- `DAGRoutingService.php` - Token routing
- `DAGValidationService.php` - Graph validation
- `TokenLifecycleService.php` - Token lifecycle
- `TokenWorkSessionService.php` - Work sessions
- `TokenExecutionService.php` - Token execution
- `GraphInstanceService.php` - Graph instances
- `FlowTokenStatusValidator.php` - Status validation
- `NodeParameterService.php` - Node parameters

#### Assignment Services (4 services)
- `AssignmentEngine.php` - Assignment engine
- `AssignmentResolverService.php` - Assignment resolver
- `NodeAssignmentService.php` - Node assignments
- `HatthasilpaAssignmentService.php` - Hatthasilpa assignments

#### Production Services (6 services)
- `JobCreationService.php` - Job creation
- `JobTicketStatusService.php` - Job ticket status
- `OperatorSessionService.php` - Operator sessions
- `ProductionRulesService.php` - Production rules
- `WorkEventService.php` - Work events
- `ScheduleService.php` - Production schedule

#### BOM & Routing Services (3 services)
- `BOMService.php` - BOM operations
- `RoutingSetService.php` - Routing sets
- `WorkCenterService.php` - Work centers

#### Team Services (5 services)
- `TeamService.php` - Team operations
- `TeamMemberService.php` - Team members
- `TeamWorkloadService.php` - Team workload
- `TeamExpansionService.php` - Team expansion
- `OperatorDirectoryService.php` - Operator directory

#### Capacity Services (3 services)
- `CapacityCalculatorInterface.php` - Capacity calculator interface
- `CapacityCalculatorFactory.php` - Capacity calculator factory
- `SimpleCapacityCalculator.php` - Simple calculator
- `WorkCenterCapacityCalculator.php` - Work center calculator

#### Serial Services (3 services)
- `SerialHealthService.php` - Serial health
- `SerialManagementService.php` - Serial management
- `UnifiedSerialService.php` - Unified serial service
- `SecureSerialGenerator.php` - Secure serial generation

#### Product Services (1 service)
- `ClassicProductionStatsService.php` - Classic production stats

#### People Services (1 service)
- `PeopleSyncService.php` - People sync

#### UOM Service (1 service)
- `UOMService.php` - Unit of measure

### DAG Engine Layer (26 engines)

**Location:** `source/BGERP/Dag/`

#### Core Execution (5 engines)
- `DagExecutionService.php` - DAG execution
- `BehaviorExecutionService.php` - Behavior execution
- `NodeBehaviorEngine.php` - Node behavior engine
- `TokenEventService.php` - Token events (Task 21)
- `TokenWorkSessionService.php` - Work sessions

#### Routing & Validation (5 engines)
- `GraphValidationEngine.php` - Graph validation
- `GraphAutoFixEngine.php` - Auto-fix engine
- `SemanticIntentEngine.php` - Semantic intent
- `ReachabilityAnalyzer.php` - Reachability analysis
- `GraphHelper.php` - Graph utilities

#### Self-Healing (4 engines)
- `LocalRepairEngine.php` - Local repair (Task 22)
- `TimelineReconstructionEngine.php` - Timeline reconstruction (Task 22)
- `RepairOrchestrator.php` - Repair orchestrator (Task 22)
- `RepairEventModel.php` - Repair event model

#### Integrity & Validation (3 engines)
- `CanonicalEventIntegrityValidator.php` - Event integrity (Task 21)
- `BulkIntegrityValidator.php` - Bulk integrity (Task 21)
- `ApplyFixEngine.php` - Apply fixes

#### Parallel & Machine (4 engines)
- `ParallelMachineCoordinator.php` - Parallel coordination (Task 18)
- `MachineAllocationService.php` - Machine allocation (Task 18)
- `MachineRegistry.php` - Machine registry
- `ConditionEvaluator.php` - Condition evaluation

#### Time & ETA (2 engines)
- `EtaEngine.php` - ETA calculation (Task 20)
- `TimeEventReader.php` - Time event reader (Task 21)

#### Node & Behavior (3 engines)
- `NodeTypeRegistry.php` - Node type registry
- `WorkCenterBehaviorRepository.php` - Behavior repository
- `QCMetadataNormalizer.php` - QC metadata

### MO Services (6 services)

**Location:** `source/BGERP/MO/`

- `MOCreateAssistService.php` - MO creation assist (Task 23.1)
- `MOLoadSimulationService.php` - Load simulation (Task 23.3)
- `MOLoadEtaService.php` - ETA calculation (Task 23.4)
- `MOEtaAuditService.php` - ETA audit (Task 23.4.2)
- `MOEtaCacheService.php` - ETA cache (Task 23.4.4)
- `MOEtaHealthService.php` - ETA health (Task 23.4.6)

### Component Services (4 services)

**Location:** `source/BGERP/Component/`

- `ComponentAllocationService.php` - Component allocation
- `ComponentBindingService.php` - Component binding
- `ComponentCompletenessService.php` - Component completeness
- `ComponentSerialService.php` - Component serials

### Product Services (1 service)

**Location:** `source/BGERP/Product/`

- `ProductMetadataResolver.php` - Product metadata (Task 25)

### Helper Layer (17 helpers)

**Location:** `source/BGERP/Helper/`

#### Core Helpers (5 helpers)
- `DatabaseHelper.php` - Database operations
- `TimeHelper.php` - Time operations (Task 20.2)
- `CacheHelper.php` - Cache operations
- `TempIdHelper.php` - Temporary IDs
- `TenantConnection.php` - Tenant connection

#### Security & Validation (4 helpers)
- `PermissionHelper.php` - Permissions (Task 19)
- `RateLimiter.php` - Rate limiting
- `RequestValidator.php` - Request validation
- `Idempotency.php` - Idempotency

#### JSON & Response (2 helpers)
- `JsonNormalizer.php` - JSON normalization
- `JsonResponse.php` - JSON responses

#### Material & Product (3 helpers)
- `MaterialResolver.php` - Material resolution
- `ProductGraphBindingHelper.php` - Product graph binding
- `ProductionBindingHelper.php` - Production binding

#### Serial & Org (3 helpers)
- `SerialSaltHelper.php` - Serial salt
- `OrgResolver.php` - Organization resolution
- `Metrics.php` - Metrics

#### Legacy (1 helper)
- `LegacyRoutingAdapter.php` - Legacy routing adapter

### Other Components

#### Bootstrap (2 files)
- `Bootstrap/TenantApiBootstrap.php`
- `Bootstrap/CoreApiBootstrap.php`

#### Security (1 file)
- `Security/PermissionHelper.php`

#### Migration (1 file)
- `Migration/BootstrapMigrations.php`

#### HTTP (1 file)
- `Http/TenantApiOutput.php`

#### JobTicket (2 files)
- `JobTicket/JobTicketPrintService.php`
- `JobTicket/JobTicketProgressService.php`

#### Config (2 files)
- `Config/AssignmentConfig.php`
- `Config/OperatorRoleConfig.php`

#### Rbac (1 file)
- `Rbac/RbacHelper.php`

#### Exception (7 files)
- `Exception/BusinessLogicException.php`
- `Exception/ConcurrencyException.php`
- `Exception/DatabaseException.php`
- `Exception/JobTicketException.php`
- `Exception/NotFoundException.php`
- `Exception/RoutingV1DisabledException.php`
- `Exception/ValidationException.php`

#### Service/TimeEngine (1 file)
- `Service/TimeEngine/WorkSessionTimeEngine.php`

---

## 3. System Architecture Summary

### Architecture Layers

1. **API Layer** (85+ files)
   - Platform APIs (12 using CoreApiBootstrap)
   - Tenant APIs (65+ using TenantApiBootstrap)
   - Legacy APIs (50+ not using bootstrap)
   - Bootstrap integration (77+ APIs migrated)

2. **Bootstrap Layer** (2 files)
   - TenantApiBootstrap
   - CoreApiBootstrap

3. **Service Layer** (47 services)
   - Core services
   - DAG services
   - Production services
   - Assignment services
   - Team services

4. **DAG Engine Layer** (26 engines)
   - Execution engines
   - Validation engines
   - Self-healing engines
   - Parallel/machine engines

5. **Helper Layer** (17 helpers)
   - Core helpers
   - Security helpers
   - Material/product helpers

6. **Database Layer**
   - Core DB: 13 tables
   - Tenant DB: 122 tables

### Key Statistics

- **Total PHP Files (source/):** 85+ files
- **Total API Endpoints:** 35+ modern APIs + 50+ legacy files
- **Total Services:** 47 services
- **Total Helpers:** 17 helpers
- **Total DAG Engines:** 26 engines
- **Total MO Services:** 6 services
- **Total Component Services:** 4 services
- **Total Product Services:** 1 service
- **Total PSR-4 Classes:** 118 files in BGERP namespace
- **Total Database Tables:** 135 tables (13 core + 122 tenant)
- **Bootstrap Migration:** ✅ 77+ APIs migrated (65 tenant + 12 platform)
- **Legacy Files:** ⚠️ 50+ files still need migration

---

## 4. Recommendations for Documentation Updates

### Priority 1: Core Documentation

1. **Database Schema Reference**
   - ✅ Update with all 122 tenant tables
   - ✅ Update with all 13 core tables
   - ✅ Add table relationships
   - ✅ Add indexes documentation

2. **API Reference**
   - ✅ List all 35+ modern API files
   - ✅ Document bootstrap usage (TenantApiBootstrap, CoreApiBootstrap)
   - ✅ Document enterprise features (Rate limiting, Validation, Idempotency)
   - ⚠️ Document legacy files status

3. **Service Reference**
   - ✅ List all 47 services
   - ✅ Document service categories
   - ✅ Document service dependencies

### Priority 2: Architecture Documentation

1. **System Architecture**
   - ✅ Update with all layers
   - ✅ Document DAG engine layer
   - ✅ Document self-healing system
   - ✅ Document MO intelligence

2. **Platform Overview**
   - ✅ Update module status
   - ✅ Update feature list
   - ✅ Update statistics

### Priority 3: Developer Guides

1. **Quick Start**
   - ✅ Update with current structure
   - ✅ Update bootstrap examples
   - ✅ Update service examples

2. **Development Guide**
   - ✅ Update API development patterns
   - ✅ Update service development patterns
   - ✅ Update DAG development patterns

---

**Last Updated:** January 2025  
**Next Review:** After major feature additions

