# Routing Graph Versioning & Immutability

_Last updated: {{DATE}}_

This document describes how routing graphs are **versioned**, how they interact with production instances (DAG tokens), and what is allowed or forbidden once production has started.

Goal:
- Protect traceability
- Prevent breaking active production flows
- Support evolution of patterns over time

---

## 1. Core Concepts

- **Graph** = a routing recipe for producing a product pattern.
- **Graph Version** = logical version of that recipe (v1, v2, v3, ...).
- **DAG Instance** = a running production instance based on a graph version.
- **Token** = a unit of work moving through nodes.
- **row_version** = integer incremented every time a graph is updated (optimistic locking).
- **ETag** = checksum/hash of the graph content at a point in time.

---

## 2. Versioning Rules

1. Each row in `routing_graph` represents a logical graph.
2. `row_version` increases on every structural/content change.
3. ETag is computed from nodes + edges + key metadata.
4. The UI uses **ETag + row_version** to prevent concurrent edits.

Example:
- User A loads graph → gets `row_version = 5`, `ETag = abc`.
- User B edits and saves → row_version becomes 6, ETag changes to `def`.
- User A tries to save with old ETag → API rejects with version conflict.

---

## 3. Immutability Policy

Once a graph is used for actual production (DAG instances created), we must:

- **Protect** historical instances from being invalidated.
- **Allow** new improvements via new versions.

Policy:

1. For graphs with **no** production instances:
   - Structural edits are allowed.
   - Nodes and edges can be added/removed.
   - Node types can change.

2. For graphs with **existing** production instances:
   - The original graph content must be treated as **immutable** for those instances.
   - Structural destructive changes should be **blocked** or performed by creating a **new graph version**.

3. Allowed minimal edits on an “in-use” graph (optional, to be defined):
   - Cosmetic label changes (node_name)
   - Non-breaking metadata (e.g., colors, UI positions)

4. Forbidden edits on an “in-use” graph:
   - Removing nodes that have active tokens
   - Changing node_type of nodes with historical tokens
   - Removing edges used by existing tokens

---

## 4. New Version vs In-place Edit

**Recommended Bellavier Standard:**

- For significant production changes, prefer **creating a new graph version** over editing in place.

Example flow:

1. Graph v1 is in use for product `P-001`.
2. A new work step is added (extra QC).
3. Instead of editing v1, create v2:
   - Copy nodes/edges
   - Apply modifications
   - Publish v2
4. New MOs / Job Tickets link to v2.
5. Existing instances on v1 continue and finish as v1.

---

## 5. ETag & Row Version in API

The API contract for saving a graph should:

- Require the client to send `If-Match` header (or equivalent) containing the last known ETag.
- Verify that the ETag matches the current stored one.
- If not matching → respond with **409 Conflict** (Version conflict).

Pseudocode:

```pseudo
function saveGraph(graphId, payload, ifMatchEtag): Result {
    current = loadGraphMeta(graphId)

    if not etagMatches(current.etag, ifMatchEtag):
        return error(409, 'Graph was modified by another user')

    # apply changes
    updateNodesAndEdges(graphId, payload)

    # recompute etag + row_version
    newEtag = computeEtag(graphId)
    newRowVersion = current.row_version + 1

    persistMeta(graphId, newEtag, newRowVersion)

    return success(etag=newEtag, row_version=newRowVersion)
}
```

---

## 6. Interaction with DAG Instances

When creating a DAG instance (e.g. from a Hatthasilpa Job Ticket):

- The instance must **bind** to a specific graph id + row_version (or etag).
- That binding must be stored and never changed.

Example:

- `dag_instance`
  - id_instance: 1001
  - id_graph: 7
  - graph_row_version: 6

This ensures that later analysis can always reconstruct **which recipe** was used.

---

## 7. Graph Designer UI Behavior

The UI must:

1. Always display:
   - Current row_version
   - ETag (or a shortened representation)
2. Handle conflict responses by:
   - Showing a clear message: "Graph was modified by another user. Please reload."
   - Offering to reload the latest version.
3. Remove stale warnings / notices on reopen.

---

## 8. Future Extensions

Potential future enhancements:

1. **Branching model**
   - Support branches (drafts) for experimental flows.
2. **Audit log**
   - Store who changed what, when, and why.
3. **Compare versions**
   - Visual diff between v1, v2, v3.

---

## 9. Notes for AI Agent

- Do not change the meaning of row_version or ETag.
- When modifying save logic, ensure:
  - Version conflict detection remains strict.
  - Instances always bind to a specific graph version.
- Any change that affects production compatibility must be documented here.

---

End of file.
