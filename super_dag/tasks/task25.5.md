Task 25.5 — Product Module Hardening & Full Refactor Integration

Objective:
Finalize the Product module so that UI, API, metadata resolver, and legacy helpers work together in one unified, clean, modern flow.
This replaces all remaining legacy behavior and completes the refactor started in Task 25.3–25.4.

⸻

✓ Scope

1) UI → API Integration (products.php / products.js / product_graph_binding.js)

Replace all legacy endpoints with modern ones:
	•	product_graph_binding.php → product_api.php?action=bind_routing
	•	product_graph_binding.php → product_api.php?action=unbind_routing
	•	product_list_api.php → product_api.php?action=list
	•	product_data.php → product_api.php?action=get_metadata
	•	product_update.php → product_api.php?action=update_product_info

Remove all dead logic
	•	Hybrid mode
	•	Default mode selection
	•	Pattern version pinning
	•	Graph version selection
	•	OEM/Atelier wordings

Add new standardized terminology
	•	OEM → Classic
	•	Atelier → Hatthasilpa

Everything visible in UI must be updated accordingly.

⸻

2) Product Metadata Resolver — Full Wiring

Ensure that the UI uses:
	•	production_line
	•	routing_bound (true/false)
	•	routing_graph_id
	•	routing_graph_name

to show exact behavior:
	•	Classic → no graph binding UI
	•	Hatthasilpa → graph binding required and visible

⸻

3) Remove Hidden Legacy Logic in JS

These must be removed completely from products.js and product_graph_binding.js:
	•	isHybridMode
	•	detectGraphVersionForProduct(...)
	•	binding_version
	•	allow_version_pin
	•	UI elements containing “Version”, “Template Version”

⸻

4) Product Duplicate → Draft (new feature)

Because now:

“1 Product = 1 Template = 1 Routing Binding”

We need an easy workflow:

Add button: Duplicate as Draft

API:
	•	product_api.php?action=duplicate
	•	Creates new product:
		•	status = draft
		•	production_line inherited
		•	routing_graph_id inherited (Hatthasilpa only)
		•	SKU auto-generated suffix: -DRAFT-{timestamp}

JS:
	•	In product listing row:
		•	Add grey “Duplicate” icon
		•	After duplicate:
			•	redirect to edit modal of the new draft

⸻

5) Clean Up wording & UI Consistency

Replace globally inside Product module:

Old	New
OEM	Classic
Atelier	Hatthasilpa
Production Template	Routing Binding
Template Version	— remove —
Hybrid	— remove —

⸻

6) Remove unused PHP files (safe deprecation)

Mark these files as deprecated in comments (do not delete yet, just warn):
	•	product_graph_binding.php
	•	product_list_api.php
	•	product_data.php

Add comment at top of each file:

// DEPRECATED — replaced by product_api.php in Task 25.5
// This file will be removed after migration is verified.

⸻

7) Migration of Legacy Product Data

Cursor must:
	•	Set production_line = 'classic' if null
	•	Ensure routing_graph_id cleared for classic
	•	Ensure routing_graph_id preserved for hatthasilpa
	•	Add is_draft column if not exists (tinyint, default 0)

Implement as a tenant migration file under `database/tenant_migrations/` and document the filename in the results.

⸻

8) Add Modern Toast & Modal Error Handling

Replace alert() in product JS with:

	showToastError("message here")

Refactor modals to show inline error blocks when API fails (e.g. `.alert-danger` inside the modal body), instead of using `alert()` or silent failures.

⸻

9) Backend Cleanup in source/products.php (Phase 8 Legacy Hardening)

This task must also clean up remaining legacy graph-binding and helper logic in `source/products.php` so it no longer conflicts with `product_api.php` and does not carry duplicated helpers.

Cursor must:

A) Deduplicate helpers

	•	`ensure_product_assets_and_patterns()` currently exists twice in this file.
		- Keep a single, canonical definition near the top of the file.
		- Remove the duplicate definition block at the bottom.
		- Keep the existing `ensure_product_assets_and_patterns($tenantDb);` call (or equivalent bootstrap) only once.

B) Fix `$org` usage in helper actions

	•	Functions such as:
		- `handleUploadAsset()`
		- `handleDeletePattern()`
		- `handleUploadPatternVersion()`
	  currently use `$org` without declaring it as global.
	•	Add `global $org;` (and other globals already in use such as `$cid`, `$action`) at the top of these functions so `$org` is always defined and correctly reflects the current tenant organization.
	•	Confirm there is no remaining `undefined variable $org` path.

C) Decommission legacy bind_graph entry points

	•	In `source/products.php`, remove (or comment out) the following actions from the main `switch ($action)`:
		- `bind_graph`
		- `update_version_pin`
	•	Remove or comment out the corresponding handler functions:
		- `handleBindGraph()`
		- `handleUpdateVersionPin()`
	•	Add a clear comment in the Phase 8 section (or above the handlers) such as:

		// NOTE: Product graph binding is now handled exclusively by product_api.php
		// (Task 25.3–25.5). The legacy bind_graph / update_version_pin endpoints
		// in this file are deprecated and must not be called by the UI.

	•	Ensure that no UI or JS code still calls `source/products.php?action=bind_graph` or `...=update_version_pin`. All binding/unbinding must go through `product_api.php`.

D) Wording cleanup inside products.php

	•	If any remaining comments or user-facing messages in `source/products.php` still refer to:
		- “OEM” → change to “Classic”
		- “Atelier” → change to “Hatthasilpa”
	  update them to match the new vocabulary introduced in this task.
	•	Do not change database field names; only adjust comments and UI strings.

This keeps `source/products.php` as the legacy-compatible product endpoint for stats/patterns, while making `product_api.php` the canonical API for metadata, list, update, and graph binding.

⸻

Deliverables

Cursor must patch:

PHP
	•	source/product_api.php
	•	source/BGERP/Product/ProductMetadataResolver.php
	•	source/products.php
	•	views/products.php

JS
	•	assets/javascripts/products/products.js
	•	assets/javascripts/products/product_graph_binding.js

DB / Migration
	•	Add a tenant migration for legacy product data cleanup (production_line defaults, routing_graph reset for classic, is_draft column)

Docs
	•	Update docs/super_dag/task_index.md
	•	Add docs/super_dag/tasks/results/task25_5_results.md summarizing all changes

⸻

Acceptance Criteria
	•	UI shows only Classic / Hatthasilpa clearly (no OEM/Atelier wording)
	•	No version pinning logic anywhere
	•	Graph Binding only shown for Hatthasilpa
	•	All product-related APIs used by the UI are unified under product_api.php
	•	Legacy `bind_graph` / `update_version_pin` in source/products.php are no longer used by JS and are clearly marked as deprecated
	•	Duplicate → Draft works perfectly
	•	All wording updated
	•	No hybrid logic
	•	Product module becomes clean, modern, and free of Phase 8 spaghetti