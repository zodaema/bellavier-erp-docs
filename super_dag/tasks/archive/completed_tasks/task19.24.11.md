

# Task 19.24.11 – History Engine Finalization (AI Agent Prompt)

## Objective
Stabilize and finalize the Graph History Engine by implementing _event‑level grouping_ and _micro‑deduplication_ so that Undo/Redo always moves exactly **one user action per step** — never skipping and never merging incorrectly.

## Agent Execution Notes
This prompt MUST be interpreted strictly as an implementation plan.  
All grouping rules, deduplication rules, commit boundaries, and snapshot normalization MUST be implemented exactly as specified — no additional heuristics, no AI “auto-reasoning”, and no restructuring of unrelated code.  
If an existing mechanism already fulfills a rule, KEEP IT; do not rewrite functional code.  
If any ambiguity exists (e.g., overlapping events, mixed drag/input, double event dispatch), ALWAYS choose:  
**“group into one semantic user action unless explicitly told otherwise.”**
This file is authoritative; do NOT inject assumptions.

---

## Requirements

### 1. **Action Grouping Layer**
Implement grouping rules so the history engine stores one entry per *semantic* action:

#### 1.1 Node actions
- Create Node → one snapshot
- Delete Node → one snapshot
- Move Node (drag) → one snapshot at dragend only
- Multi-select Move → one snapshot

#### 1.2 Edge actions
- Create Edge → one snapshot
- Delete Edge → one snapshot
- Update Condition → one snapshot

#### 1.3 Property changes
- For text fields (name, label, work_center_code):  
  → group edits until input blur or press Enter  
- For dropdowns:  
  → one snapshot per change  
- For condition editor:  
  → one snapshot per confirmed edit

#### 1.4 Template actions
- Applying QC / Non-QC Templates → one snapshot  
- AutoFix applied → one snapshot

---

### 2. **Micro‑Deduplication**
If a snapshot has **identical nodes + edges** to previous snapshot (after deep‑stable‑sort):
- Do not push to history  
- Needed for: drag jitter, double dispatch, keyrepeat

---

### 3. **Deterministic Snapshot Builder**
Ensure snapshot builder produces deterministic order:
- Sort nodes by id  
- Sort edges by id  
- Strip all transient fields  
- Include `__hash` (sha1 over nodes+edges)

---

### 4. **HistoryManager Updates**
Add:
- `beginGroup(actionType)`  
- `endGroup()`  
- `isGrouping` flag  
- Internal buffer before commit  
- Auto‑commit at safe boundaries

Grouping rules:
- Dragstart → `beginGroup('move')`  
- Dragend → `endGroup()`  
- Text input keydown → buffer  
- Blur/Enter → commit

---

### 5. **Debugging Aids**
Add temporarily:
- `console.debug('[HIST]', action, snapshot.__hash)`
- Can be disabled by global toggle

---

### 6. **Backward Compatibility**
- Maintain restore for old snapshots
- No change to snapshot structure except sorting + dedupe

---

## Delivery Checklist
- Modify: `GraphHistoryManager.js`
- Modify: `graph_designer.js`
- Modify: `conditional_edge_editor.js` (for commit-boundaries)
- Update: `task19.24.11_results.md`
- All SuperDAG tests must pass unchanged

---

## Acceptance
- Undo removes exactly one user action  
- Redo reapplies exactly one action  
- No double skips  
- No double commits  