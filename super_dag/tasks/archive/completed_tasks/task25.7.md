

# Task 25.7 — Product Line Model Consolidation (Classic vs Hatthasilpa)

> **Goal**: Lock Bellavier Group ERP to a **single production line per product** model, with a clean, explicit, and easy‑to‑understand UX: each product is either **Classic** or **Hatthasilpa** (and can be duplicated / edited to change line), but never both at the same time.
>
> This task **removes multi‑select production lines**, normalizes the backend model, and hardens all guards so Classic vs Hatthasilpa behavior is deterministic and simple.

---

## 1. Scope

This task covers **Product module only** (no MO, no Job Ticket behavior changes here):

- Data model & PHP domain model
- Product create/edit UI
- Product duplicate flow
- Product metadata / binding behavior
- Backward‑compatibility shims for old data

Out of scope:
- Changing MO logic, Job Ticket logic, or Graph Designer behavior (those already rely on `production_line` semantics and will benefit automatically).

---

## 2. Target Behaviour (Business Rules)

The target rules after this task:

1. **Single production line per product**
   - DB and PHP domain model must have **exactly one** `production_line` field.
   - Allowed values (string):
     - `classic`
     - `hatthasilpa`
   - No arrays, no JSON multi‑select, no multiple lines per product.

2. **Creation semantics**
   - When creating a product, user can choose:
     - **Classic line** or **Hatthasilpa line** directly.
   - Default may be `classic`, but user **can change before save**.
   - There is **no forced workflow** like “must create Classic first then duplicate to Hatthasilpa”.

3. **Duplicate semantics**
   - When duplicating a product:
     - New product copies `production_line` from source product.
     - After duplicate, user may change `production_line` to another line in the edit form.

4. **Graph binding semantics**
   - `production_line = 'classic'`
     - **Cannot** bind DAG / routing graph.
     - Product metadata resolver must return `supports_graph = false`.
   - `production_line = 'hatthasilpa'`
     - **Can** bind DAG / routing graph (per existing Hatthasilpa logic).
     - Product metadata resolver must return `supports_graph = true` (if binding exists).

5. **UI semantics**
   - Product screen must:
     - Show line type clearly: `Classic` or `Hatthasilpa` (i18n labels).
     - Prevent any UX where user can tick multiple lines for a single product.
     - Show **Graph Binding tab only** for `hatthasilpa` products.
     - Show **Classic Dashboard tab only** for `classic` products.

6. **Backward compatibility**
   - If legacy schema/data exist (e.g. `production_lines` multi‑value, or old OEM/Atelier labels), system must:
     - Migrate or normalize them on read.
     - Never expose multi‑line choice in new UI.

---

## 3. Files to touch (expected)

> **Note:** Adjust the exact paths/names if they differ, but keep work localized to Product module.

- `database/tenant_migrations/` (new migration for model normalization)
- `source/BGERP/Product/ProductMetadataResolver.php`
- `source/product_api.php`
- `source/products.php` (legacy product API / helpers)
- `views/products.php`
- `assets/javascripts/products/products.js`
- `assets/javascripts/products/product_graph_binding.js`
- `docs/super_dag/tasks/results/task25_7_results.md` (new)

Do **not** modify:
- MO APIs, Job Ticket APIs, Graph Designer core classes, Node Behavior Engine (out of scope for this task).

---

## 4. Implementation Plan

### 4.1 Data Model Normalization

1. **Add migration** (e.g. `2025_12_product_line_single_column.php`):
   - If a column `production_line` already exists and is correct, use migration only for data cleanup; otherwise:
     - Ensure table (likely `products` or equivalent) has a **single** column:
       - `production_line` `VARCHAR(32)` NOT NULL, default `'classic'`.
     - If there is a legacy column like `production_lines` (JSON/CSV/multi‑select):
       - Migrate it to `production_line` using rule:
         - If it contains `'hatthasilpa'` → `production_line = 'hatthasilpa'`
         - Else → `production_line = 'classic'`
     - If there are legacy values like `oem`, `atelier`:
       - Map `oem` → `classic`
       - Map `atelier` → `hatthasilpa`.
   - Add an index on `production_line` if not already present.

2. **Do not keep multi‑select state**
   - After migration, app code **must not** read/write any `production_lines` multi‑select field.
   - If such a column exists, treat it as deprecated and ignore in PHP.


### 4.2 ProductMetadataResolver Cleanup

File: `source/BGERP/Product/ProductMetadataResolver.php`

1. Ensure resolver exposes a **single** `production_line` in metadata:
   - `production_line`: `'classic' | 'hatthasilpa'`

2. Ensure `supports_graph` is computed as:
   - If `production_line === 'hatthasilpa'` → `supports_graph = true` (as long as product is eligible for routing binding).
   - If `production_line === 'classic'` → `supports_graph = false`.
   - Do **not** rely on any legacy `production_lines` array in this class anymore.

3. Ensure any routing metadata returned in `routing` (or similar key) is **only populated** when `production_line === 'hatthasilpa'`.

4. If there are code paths that still infer “OEM vs Atelier”: update naming to `classic` / `hatthasilpa`, but keep i18n‑ready strings in UI only (no hardcoded Thai/emoji in PHP).


### 4.3 product_api.php — Single Line & Guards

File: `source/product_api.php`

1. **`get_metadata` action:**
   - Must return a metadata payload that includes:
     - `production_line`
     - `supports_graph`
     - any existing routing metadata used by frontend.

2. **`bind_routing` / `unbind_routing` actions:**
   - Before performing any routing binding mutations:
     - Fetch product metadata.
     - If `production_line !== 'hatthasilpa'`:
       - Return error JSON:
         - `ok: false`
         - `error_code: 'PRODUCT_NOT_HATTHASILPA'`
         - `error: 'Routing graph can only be bound for Hatthasilpa products.'`
       - HTTP status 400 is acceptable.

3. **`duplicate` action:**
   - Ensure it copies `production_line` from source product.
   - Do **not** reset line to `classic` automatically.
   - After duplicate, the new product may be edited to change line; no extra logic required here.

4. Ensure error handling follows existing project standards (structured JSON, no raw `die()` / `echo` without JSON wrapper).


### 4.4 Product PHP Endpoint Cleanup (source/products.php)

File: `source/products.php`

1. Remove/stop using any legacy multi‑line logic:
   - If helper functions still refer to `production_lines` or `["classic", "hatthasilpa"]` arrays per product, collapse to single `production_line` everywhere.

2. For list/get operations that feed the products screen:
   - Ensure each product row includes `production_line` as a scalar string.

3. For create/update operations:
   - Accept **only one** production line value, from request field (e.g. `production_line`).
   - Validate allowed values (`classic` / `hatthasilpa`), and default to `classic` if empty.


### 4.5 Product Screen UI (views/products.php)

File: `views/products.php`

1. **Create/Edit form**
   - Replace any multi‑select or checkbox group for production lines with **single‑choice** control:
     - Prefer radio buttons, e.g.:
       - `Classic line`
       - `Hatthasilpa line`
   - Use project i18n helper (e.g. `translate('products.form.production_line.classic', 'Classic line')`).
   - Default selection may be `Classic line`, but user can change before saving.

2. **Product listing table**
   - Ensure the column that shows production line:
     - Uses the new `production_line` field.
     - Shows i18n labels: `Classic` / `Hatthasilpa`.

3. **Do NOT show any UI that suggests a product can belong to multiple lines simultaneously.**


### 4.6 Graph Binding Modal & JS

Files:
- `views/products.php` (modal markup)
- `assets/javascripts/products/product_graph_binding.js`
- `assets/javascripts/products/products.js` (if it controls tab visibility)

1. **Tab visibility rules** (reuse logic from 25.4 but harden it):
   - If `production_line === 'hatthasilpa'`:
     - Show **Graph Binding tab**.
     - Hide or de‑emphasize Classic dashboard tab for that product.
   - If `production_line === 'classic'`:
     - Hide **Graph Binding tab** entirely.
     - Show **Classic Production Overview** tab instead.

2. **Metadata loading**
   - When opening Product modal:
     - Call `product_api.php?action=get_metadata&id=...`.
     - Use `metadata.production_line` and `metadata.supports_graph` to decide which tabs to show.
   - Avoid implicit “fallback” where Hatthasilpa is inferred without checking actual `production_line`.

3. **JS assumptions**
   - Remove any logic that assumes a product can support both graph and classic dashboard at the same time.
   - `supports_graph` should effectively be `production_line === 'hatthasilpa'`.


### 4.7 i18n & Code Quality Guardrails

While editing the above files, **respect existing Bellavier Group coding standards**:

- Use `translate()` helpers for all user‑facing strings in PHP views.
- Default text in English; avoid hardcoding Thai or emoji in code.
- JS:
  - No `alert()` or `confirm()` for final UX (use existing notification/toast mechanism if available).
  - Avoid in‑line HTML string concatenation where templates/partials exist.
- Comments:
  - Write concise, professional English comments.
  - Explain *why*, not just *what*.

---

## 5. Acceptance Criteria

For this task to be considered **DONE**:

1. **Data model**
   - There is exactly **one** effective production line field per product (`production_line`).
   - Legacy `production_lines` (if still present in DB) are no longer read/used by PHP.

2. **Product create/edit**
   - Form clearly presents a **single choice** between Classic vs Hatthasilpa.
   - Saving a product persists exactly one line type (`classic` or `hatthasilpa`).

3. **Duplicate**
   - Duplicating a product copies `production_line` as‑is.
   - After duplicate, editing the new product can change `production_line`.

4. **Graph binding behavior**
   - For `classic` products:
     - Graph Binding tab is hidden.
     - backend `bind_routing` / `unbind_routing` returns a clear error.
   - For `hatthasilpa` products:
     - Graph Binding tab is visible and functional.

5. **No UI suggesting multi‑line membership**
   - Nowhere in Product UI can user tick/select both Classic and Hatthasilpa for the same product.

6. **No regressions**
   - Existing Hatthasilpa products with routing binding continue to behave as before.
   - Classic products continue to work with Classic dashboard (from Task 25.2).

7. **Documentation**
   - `docs/super_dag/tasks/results/task25_7_results.md` created.
   - Briefly describes the new single‑line model and any migration behavior.

---

## 6. Notes for Future Tasks

- Future tasks may add **per‑line constraints** (e.g. certain materials only valid for Hatthasilpa), but the **single‑line per product** model from this task should remain stable.
- Node Behavior, Work Queue, and MO/Job Ticket flows should always derive line semantics via `ProductMetadataResolver` to avoid drift.