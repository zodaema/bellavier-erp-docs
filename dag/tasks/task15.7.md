You are an ERP migration engineer for Bellavier Group.

Your job now is to **stop guessing** and **sync the real world**:

- The canonical tenant template is: `bgerp_t_maison_atelier`
- The current tenant schema (and migrations) must be brought in line with that template.
- After that, canonical **static** seed migrations must be created.

---

## PHASE 0 — NON-NEGOTIABLE RULES

1. You MUST read and compare **real database schemas**:
   - `bgerp_t_maison_atelier` (template tenant DB)
   - A real tenant schema (e.g. current ERP tenant DB)
2. You MUST read existing migration files:
   - `0001_init_tenant_schema_v2.php`
   - `0002_seed_data.php`
   - Any migration that defines `unit_of_measure`, `work_center`, `permission`, `tenant_role`, `feature_flag`, etc.
3. You MUST NOT:
   - invent new columns
   - invent new codes/keys for UOM, work centers, permissions, roles, feature flags
   - rename existing columns
   - drop existing columns or tables unless this is already defined by a previous, accepted migration
4. You MUST NOT:
   - open new mysqli / PDO connections to `bgerp_t_maison_atelier` **inside migration files**
   - rely on “live” template DB during migration execution
   - make migrations dependent on localhost/ports/credentials
5. All migrations must be:
   - **append-only** (never renumber or edit existing numbered migrations)
   - **idempotent** (safe to run multiple times)
   - safe on production


If a table or column you expect is not present:
- STOP and treat it as an error in your assumptions.
- Do NOT guess. Adjust to the real schema.

If at any point you are unsure how to structure schema definitions or seed data, use the existing files `0001_init_tenant_schema_v2.php` and `0002_seed_data.php` as concrete examples for style, structure, helper usage, and coding patterns. Imitate their approach and only adapt it to match the updated schema and static data requirements described in this task.

---

## PHASE 1 — SCHEMA ALIGNMENT (INCLUDES init_tenant_schema)

### GOAL

Make sure that:

1. The **runtime tenant schema** (after running all migrations) matches the schema of `bgerp_t_maison_atelier` (for the tables in scope).
2. The **init script** `0001_init_tenant_schema_v2.php` reflects the same final schema:
   - A newly created tenant using `0001_init_tenant_schema_v2.php` + active migrations
     ends up with the same structure as `bgerp_t_maison_atelier`.

### TABLES IN SCOPE

At minimum, include:

- `unit_of_measure`
- `work_center`
- `permission`
- `tenant_role` (or `platform_role` if that is the actual name)
- `tenant_role_permission` (or equivalent mapping table)
- `feature_flag` (if present in template)
- Any other master/reference tables that are required by `0002_seed_data.php`

### PROCESS

1. **Inspect template schema**

   For each table in scope, run on the template DB:

   - `DESCRIBE bgerp_t_maison_atelier.<table>;`
   - `SHOW CREATE TABLE bgerp_t_maison_atelier.<table>;`

   Use this as the canonical definition.

2. **Inspect current tenant schema**

   On the current tenant DB, run:

   - `DESCRIBE <table>;`
   - `SHOW CREATE TABLE <table>;`

   Compare column by column:
   - data types
   - nullability
   - default values
   - indexes and unique keys

3. **Define the diff**

   For any difference between tenant schema and template schema:
   - Identify whether this has already been handled by existing migrations.
   - If not, you MUST create a **new migration** (e.g. `00XX_alter_schema_to_maison_atelier.php`) that:
     - uses standard ALTER TABLE statements
     - only changes what is necessary
     - is safe to run on existing tenants

4. **Update `0001_init_tenant_schema_v2.php`**

   After you know the final, correct schema (template DB + all migrations):

   - Update `0001_init_tenant_schema_v2.php` so that:
     - It defines tables exactly as they should exist **after all migrations**.
     - It includes any new columns, indexes, and constraints required.
   - Do NOT change its migration number. It is an init script, not a runtime migration.
   - Do NOT remove any table that still exists and is in use.

5. **DO NOT move or rename old migrations again**

   - Previous re-organization into `active` has already been done.
   - Respect existing directory layout.
   - Only add new migration files with the next free number.

---

## PHASE 2 — CANONICAL STATIC SEED (NO LIVE TEMPLATE DB QUERIES)

### GOAL

Replace the dynamic, cross-DB seeding logic from `0002_seed_data.php` with **static, deterministic** seed migrations that:

- Do NOT connect to `bgerp_t_maison_atelier` at runtime.
- Do NOT depend on localhost or external DB connections.
- Use **fixed arrays** of seed data that were derived from the template once, at development time.

You will create new seed migrations, for example:

- `00XY_seed_core_uom_workcenter.php`
- `00XZ_seed_core_permissions_roles.php`
- `00XA_seed_core_feature_flags_and_statuses.php`

(Use actual numbers that come after the latest existing migration.)

### GENERAL RULES FOR SEED MIGRATIONS

1. Each migration file MUST:
   - use the existing `$db` / migration helper functions only
   - NOT open new DB connections
   - implement upsert logic using **business keys**:
     - `uom_code` for UOM
     - `code` for work_center
     - `code` for permission
     - `code` for tenant_role
     - `code` or `key` for feature_flag
2. Data source:
   - Read actual values from:
     - `bgerp_t_maison_atelier` (via manual inspection during development)
     - current `0002_seed_data.php`
   - Then hard-code these values into arrays in the new migration files.
3. After the new seed migrations are correct, the old dynamic logic in `0002_seed_data.php` can be treated as legacy:
   - Do NOT delete it immediately.
   - But **do not call or rely on it anymore** in new tenants.

---

### 2.1 SEED: `unit_of_measure`

1. Inspect `bgerp_t_maison_atelier.unit_of_measure`:

   - `DESCRIBE bgerp_t_maison_atelier.unit_of_measure;`
   - `SELECT * FROM bgerp_t_maison_atelier.unit_of_measure ORDER BY id_unit_of_measure;`

2. Build a static PHP array from the real rows:

   ```php
   $uoms = [
       [
           'uom_code'    => 'PCS',
           'name'        => 'Piece',
           'uom_type'    => 'quantity',
           'base_ratio'  => 1,
           'is_base'     => 1,
           'status'      => 1,
       ],
       // ... EXACTLY as in template
   ];

	•	Do NOT invent new codes.
	•	Do NOT drop codes that exist in the template.
	•	Only add extra UOMs if they are already present in the template or in current production tenants and are clearly required.

	3.	For each element in $uoms:
	•	Use migration_insert_if_not_exists or INSERT ... ON DUPLICATE KEY UPDATE
keyed by uom_code.

⸻

2.2 SEED: work_center
	1.	Inspect bgerp_t_maison_atelier.work_center:
	•	DESCRIBE bgerp_t_maison_atelier.work_center;
	•	SELECT * FROM bgerp_t_maison_atelier.work_center ORDER BY id_work_center;
	2.	Build a static array of work centers:

$workCenters = [
    [
        'code'        => 'CUT',
        'name'        => 'Cutting',
        'id_uom_time' => <id from template or null if using code only>,
        // ... other fields exactly matching template
    ],
    // ...
];

	•	If the template uses uom_code instead of id_uom_time, match that.
	•	Do NOT invent new work centers that do not exist in the template.

	3.	Upsert using code as the natural key.

⸻

2.3 SEED: PERMISSIONS & ROLES
	1.	Inspect from template DB:
	•	SELECT * FROM bgerp_t_maison_atelier.permission ORDER BY id_permission;
	•	SELECT * FROM bgerp_t_maison_atelier.tenant_role ORDER BY id_tenant_role;
	•	SELECT tr.code AS role_code, p.code AS perm_code FROM bgerp_t_maison_atelier.tenant_role_permission trp JOIN bgerp_t_maison_atelier.tenant_role tr ON tr.id_tenant_role = trp.id_tenant_role JOIN bgerp_t_maison_atelier.permission p ON p.id_permission = trp.id_permission WHERE trp.allow = 1; 
	2.	Create static arrays:

$permissions = [
    ['code' => 'erp.stock.read',  'description' => '...'],
    ['code' => 'erp.stock.write', 'description' => '...'],
    // EXACTLY from template
];

$roles = [
    ['code' => 'super_admin', 'name' => 'Super Admin', 'description' => '...', 'is_system' => 1],
    // EXACTLY from template
];

$rolePermissions = [
    ['role_code' => 'super_admin', 'perm_code' => 'erp.stock.read'],
    ['role_code' => 'super_admin', 'perm_code' => 'erp.stock.write'],
    // EXACTLY from template tenant_role_permission
];

	•	Do NOT introduce new permission codes that are not in template or 0002_seed_data.php.
	•	Do NOT introduce new roles beyond what is in the template (unless they already exist in production and are required).

	3.	Seed logic:
	•	Insert/update permissions using code as key.
	•	Insert/update roles using code as key.
	•	For mappings:
	•	resolve role_code → id_tenant_role
	•	resolve perm_code → id_permission
	•	insert into tenant_role_permission only if the pair does not already exist.
	4.	Important:
	•	The new migration must be fully static:
	•	no new mysqli(...)
	•	no queries to bgerp_t_maison_atelier inside the migration.
	•	All codes and mappings come from the arrays above.

⸻

2.4 SEED: feature_flag (IF PRESENT)
	1.	Inspect template:
	•	SELECT * FROM bgerp_t_maison_atelier.feature_flag ORDER BY id_feature_flag;
	2.	Build static array:

$featureFlags = [
    ['code' => 'erp.routing.v1.enabled', 'description' => '...', 'is_enabled' => 1],
    // EXACTLY from template
];


	3.	Upsert using code as key.

⸻

2.5 OTHER REFERENCE TABLES FROM 0002_seed_data.php
	1.	Read 0002_seed_data.php and identify any other reference tables it seeds that:
	•	still exist in the tenant schema
	•	are still required for the application to operate
	2.	For each such table:
	•	Confirm the schema in both template DB and current tenant DB.
	•	Extract the real rows from template DB.
	•	Convert them into static arrays in a new seed migration.
	•	Upsert using natural code keys (e.g. status_code, slug, key).
	3.	Do NOT seed into tables that are clearly legacy or no longer part of the Maison Atelier core.

⸻

FINAL EXPECTATIONS

When you are done, you must provide:
	1.	A list of new migration files you created, with filenames.
	2.	The full contents of those migration files.
	3.	A short explanation for each migration:
	•	which tables it touches
	•	what it seeds or alters
	4.	Confirmation that:
	•	0001_init_tenant_schema_v2.php reflects the final schema
	•	The new seed migrations are static and do not communicate with bgerp_t_maison_atelier at runtime
	•	No fake / invented permissions, roles, UOMs, work centers, or feature flags have been introduced

If at any point the real schema or data does not match your expectation:
	•	STOP, explain the discrepancy, and adjust to the real world.
	•	Do NOT guess.

DO NOT IMAGINE ANYTHING.
