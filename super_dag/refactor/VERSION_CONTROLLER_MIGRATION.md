# Graph Version Controller Migration Guide

## Overview

Migration from inline version management logic to `GraphVersionController` - single source of truth pattern.

## Architecture Change

### Before (Current - Problematic)
- Version logic scattered across `graph_designer.js`
- Selector has inference/fallback logic
- Multiple sources of truth (state, DOM, window._*)
- "latest" semantics in frontend

### After (Target - Bellavier-grade)
- `GraphVersionController` = Single source of truth
- Selector = Passive View (reflect only, no decisions)
- Identity-based requests (no inference)
- No "latest" semantics in frontend

## Migration Steps

### Phase 1: Controller Integration (Current)

1. ✅ Created `GraphVersionController.js` module
2. ✅ Added to page definition (before graph_designer.js)
3. 🔄 Integrate controller in graph_designer.js:
   - Initialize controller in document.ready
   - Replace `loadVersionsForSelector()` → `controller.setAvailableVersions()` + `controller.renderSelector()`
   - Replace `syncSelectorFromIdentity()` → `controller.setIdentity()` (auto-renders)
   - Replace `handleVersionSelectorChange()` → `controller.handleSelectorChange()`

### Phase 2: Remove Old Logic

1. Remove functions:
   - `loadVersionsForSelector()` - replaced by controller
   - `syncSelectorFromIdentity()` - replaced by controller  
   - `identityKeyToCanonical()` - replaced by controller
   - All inference/fallback logic in selector

2. Remove state variables:
   - `window._selectedVersionForLoad` - replaced by `controller.getIdentity()`
   - Version resolution logic

### Phase 3: Update Load Flow

1. `handleGraphLoaded()` → Extract identity from response → `controller.setIdentity()`
2. `GraphLoader.onLoadSuccess()` → Build identity from response → `controller.setIdentity()`
3. Selector change → `controller.handleSelectorChange()` → `controller.onLoadRequest()` → `loadGraph()`

## API Contract

### GraphIdentity Structure
```javascript
{
  graphId: number,
  ref: 'draft' | 'published',
  versionId: number | null,  // if ref='published'
  draftId: number | null,     // if ref='draft'
  versionLabel: string | null // e.g., "2.0"
}
```

### Controller Methods

- `setIdentity(identity)` - Set current identity (from backend response)
- `getIdentity()` - Get current identity (read-only copy)
- `setAvailableVersions(versions)` - Set versions list (from API)
- `renderSelector()` - Render selector (passive view)
- `handleSelectorChange(canonicalValue)` - Handle user selection (request load)
- `buildVersionParam(identity)` - Build API parameter

### Callbacks

- `onIdentityChange(newIdentity, previousIdentity)` - Called when identity changes
- `onLoadRequest(identityRequest)` - Called when load is requested

## Rules (Enforced)

1. ❌ NO inference (if hasDraft, etc.)
2. ❌ NO fallback logic
3. ❌ NO auto-correct
4. ❌ NO "latest" in frontend
5. ✅ Identity from backend response ONLY
6. ✅ Selector reflects identity ONLY
7. ✅ onChange = request ONLY

## Testing Checklist

- [ ] Draft opens correctly (no bounce-back)
- [ ] Published opens correctly (read-only)
- [ ] Selector reflects loaded identity
- [ ] Version switch works (draft ↔ published)
- [ ] No ghost graphs (identity mismatch)
- [ ] No delayed change events
- [ ] No infinite loops

