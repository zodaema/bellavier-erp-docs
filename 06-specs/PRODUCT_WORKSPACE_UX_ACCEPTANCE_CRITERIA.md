# Product Workspace: UX Acceptance Criteria
## Measurable Quality Gates for Implementation

**Version:** 1.0  
**Date:** 2026-01-05  
**Status:** READY FOR VALIDATION  
**Related:** [PRODUCT_WORKSPACE_UX_REFACTOR_PLAN.md](./PRODUCT_WORKSPACE_UX_REFACTOR_PLAN.md)

---

## Purpose

This document defines **measurable acceptance criteria** for the Product Workspace UX.  
Every criterion must be validated before each phase is considered complete.

**Philosophy:**
> If we can't measure it, we can't ship it.  
> If a user fails, the UX fails — not the user.

---

## 1. First-Time User Criteria (Zero Training Required)

### 1.1 Core Task Completion

| Task | Target Time | Success Rate | Notes |
|------|-------------|--------------|-------|
| **Create product + publish first revision** | ≤ 3 minutes | 100% | Without documentation or help |
| **Edit component and publish new revision** | ≤ 2 minutes | 100% | From existing product |
| **Understand why revision is locked** | ≤ 10 seconds | 100% | Visual + text explanation |
| **Find revision history** | ≤ 5 seconds | 100% | Single navigation action |

### 1.2 Zero-Confusion Tests

| Scenario | Expected Outcome | Failure Indicator |
|----------|------------------|-------------------|
| User makes breaking change | Sees warning banner within 1 second | User saves without seeing warning |
| User tries to edit locked revision | Sees lock reason immediately | User clicks disabled button repeatedly |
| User has unpublished changes | Status bar shows draft state | User closes without publishing, unaware |
| User opens product with no revision | Sees clear guidance + action button | User doesn't know what to do next |

### 1.3 Language Clarity Test

**Test method:** Show UI text to non-technical user. Ask "What does this mean?"

| UI Element | Must Be Understood As |
|------------|----------------------|
| "Draft Changes Detected" | "I changed something, it's not live yet" |
| "Publish Revision" | "Make my changes affect production" |
| "Revision is locked" | "I can't change this because it's being used" |
| "Active Revision" | "This is what production is using right now" |

---

## 2. Power User Criteria (Faster Than Before)

### 2.1 Speed Benchmarks

| Task | Current System | New Workspace | Improvement |
|------|----------------|---------------|-------------|
| Edit product + change graph + publish | 8+ clicks, 3 modals | 4 clicks, 1 workspace | ≥ 50% faster |
| Check revision lock reason | Hidden, requires investigation | Visible in 1 click | Instant |
| Compare current vs draft changes | Not possible | Preview diff available | New capability |
| Navigate between product config areas | Close/reopen modals | Tab switch | Zero context loss |

### 2.2 Keyboard Navigation (Optional Phase)

| Action | Shortcut | Phase |
|--------|----------|-------|
| Switch tabs | `Ctrl+1/2/3/4` | Future |
| Save draft | `Ctrl+S` | Phase 1 |
| Publish revision | `Ctrl+Shift+P` | Phase 4 |
| Close workspace | `Esc` | Phase 1 |

---

## 3. Error Prevention Criteria

### 3.1 Impossible to Make These Mistakes

| Mistake | Prevention Method | Validation |
|---------|-------------------|------------|
| Edit immutable revision | Fields disabled + lock icon | Try clicking — nothing happens |
| Delete referenced revision | Button disabled + tooltip | Button shows explanation |
| Publish without required data | Validation gate | Clear error with fix action |
| Skip revision creation | Status bar persistent warning | Cannot dismiss without action |
| Overwrite concurrent edit | ETag/row_version check | 409 error with refresh option |

### 3.2 Every Error Has Next Action

| Error Type | Required Response Elements |
|------------|---------------------------|
| Validation failure | ✓ What failed + ✓ How to fix + ✓ Button to fix |
| Conflict (409) | ✓ What happened + ✓ Current state + ✓ Retry/Refresh |
| Permission denied | ✓ Why + ✓ Who can help |
| System error | ✓ Apology + ✓ Retry + ✓ Support contact |

---

## 4. Visual Hierarchy Criteria

### 4.1 Information Priority (Eye-Track Order)

When user opens Product Workspace, they should see in this order:

```
1. Product name + SKU (identity)
2. Revision status bar (governance state)
3. Tab navigation (current context)
4. Tab content (details)
5. Action footer (what to do)
```

### 4.2 Status Visibility

| State | Visual Treatment | Visibility |
|-------|------------------|------------|
| Clean (no changes) | Subtle green indicator | Low prominence |
| Draft changes | Yellow/amber warning bar | High prominence |
| No revision | Red/orange alert | Highest prominence |
| Locked revision | Lock icon + gray overlay | Clear but not alarming |

### 4.3 Action Button States

| Button | Enabled State | Disabled State |
|--------|---------------|----------------|
| Save Draft | Blue, clickable | Gray, tooltip explains why |
| Publish | Green/Primary, prominent | Gray, tooltip: "No changes to publish" |
| Delete Draft | Red outline, secondary | Hidden if no draft |
| Discard Changes | Text link, tertiary | Hidden if no changes |

---

## 5. State Persistence Criteria

### 5.1 Data Safety

| Scenario | Expected Behavior |
|----------|-------------------|
| User closes browser mid-edit | Draft changes preserved (if saved) |
| User switches tabs | No data loss |
| User refreshes page | Returns to same state |
| Network disconnection | Offline indicator + local buffer |

### 5.2 Navigation Safety

| Action | System Response |
|--------|-----------------|
| Close workspace with unsaved changes | Confirmation dialog |
| Navigate away with draft | Warning: "Unpublished changes will remain as draft" |
| Browser back button | Returns to product list, workspace state preserved |

---

## 6. Accessibility Criteria

### 6.1 Minimum Requirements

| Criterion | Standard | Validation |
|-----------|----------|------------|
| Color contrast | WCAG AA (4.5:1) | Automated tool check |
| Keyboard navigable | All actions reachable | Tab through entire workspace |
| Screen reader | Semantic HTML | VoiceOver/NVDA test |
| Focus indicators | Visible focus ring | Visual inspection |

### 6.2 Responsive Behavior

| Viewport | Layout Adaptation |
|----------|-------------------|
| Desktop (≥1200px) | Full workspace, side-by-side elements |
| Tablet (768-1199px) | Stacked layout, tabs remain |
| Mobile (≤767px) | Drawer/full-screen, simplified tabs |

---

## 7. Performance Criteria

### 7.1 Load Time

| Metric | Target | Measurement |
|--------|--------|-------------|
| Workspace open (cold) | ≤ 500ms | Time to interactive |
| Tab switch | ≤ 100ms | Content visible |
| Save draft | ≤ 300ms | Confirmation shown |
| Publish revision | ≤ 1s | Status bar updated |

### 7.2 Data Freshness

| Data Type | Refresh Strategy |
|-----------|------------------|
| Revision status | Poll every 30s or on focus |
| Lock reason | Fetch on demand |
| Component list | Cache until edit |
| Divergence check | Compute on tab switch |

---

## 8. Phase-Specific Acceptance Criteria

### Phase 1: Foundation ✓

**Must pass before Phase 2:**

- [ ] Workspace opens in ≤ 500ms
- [ ] Tab navigation works (4 tabs visible)
- [ ] General tab displays all product fields
- [ ] Save works (product master data)
- [ ] Sticky status bar visible at all times
- [ ] Status bar shows correct revision state
- [ ] Close button works with confirmation if unsaved

### Phase 2: Structure ✓

**Must pass before Phase 3:**

- [ ] Components table renders in Structure tab
- [ ] Components editable inline
- [ ] Constraints editor embedded (no separate modal)
- [ ] Divergence detection shows warning within 1s of change
- [ ] "Discard Changes" removes all draft changes
- [ ] Draft changes persist across tab switches

### Phase 3: Production ✓

**Must pass before Phase 4:**

- [ ] Graph version selector shows all available versions
- [ ] Current vs selected comparison visible
- [ ] Changing graph triggers divergence warning
- [ ] Graph version appears in revision snapshot

### Phase 4: Revisions ✓

**Must pass before Phase 5:**

- [ ] All revisions listed chronologically
- [ ] Active revision clearly marked
- [ ] Lock reason expandable with details
- [ ] Publish button creates new revision
- [ ] Retire button works (with confirmation)
- [ ] Delete draft button works (draft only)
- [ ] Snapshot viewable in modal/drawer

### Phase 5: Polish ✓

**Must pass before deprecating old modals:**

- [ ] All Phase 1-4 criteria still passing
- [ ] No regression in existing functionality
- [ ] Power user completes workflow 50% faster
- [ ] First-time user test: 3-minute publish target met
- [ ] Zero dead-end states found in testing
- [ ] Old modals can be removed without breaking anything

---

## 9. User Testing Protocol

### 9.1 Test Participants

| Role | Count | Purpose |
|------|-------|---------|
| First-time user (non-technical) | 3 | Zero-training validation |
| Power user (production admin) | 2 | Speed + efficiency validation |
| Developer (QA role) | 1 | Edge case discovery |

### 9.2 Test Tasks

1. **Task A:** "Create a new product called 'Test Bag' and make it ready for production"
   - Success: Revision published within 3 minutes
   - Failure: User asks for help OR gives up

2. **Task B:** "Change the main component material and update production"
   - Success: New revision published, old jobs unaffected
   - Failure: User doesn't create revision OR overwrites existing

3. **Task C:** "Find out why you can't edit Revision 2.0"
   - Success: User reads lock reason within 10 seconds
   - Failure: User can't find or understand lock reason

4. **Task D:** "Switch the production flow to the new version"
   - Success: Graph changed + revision published
   - Failure: User changes graph but forgets to publish

### 9.3 Success Threshold

| Metric | Minimum | Target |
|--------|---------|--------|
| Task completion rate | 90% | 100% |
| Time on task | ≤ 150% of target | ≤ 100% of target |
| User satisfaction (1-5) | ≥ 4 | 5 |
| Help requests | ≤ 1 per session | 0 |

---

## 10. Definition of Done

### For Each Phase:

- [ ] All phase-specific criteria passing
- [ ] No new accessibility violations
- [ ] Performance targets met
- [ ] User test conducted with ≥ 90% success rate
- [ ] Code reviewed and merged
- [ ] Documentation updated

### For Full Workspace Release:

- [ ] All 5 phases complete
- [ ] Power user validation: "faster than before"
- [ ] First-time user validation: "no training needed"
- [ ] Zero dead-end states in any flow
- [ ] Old modals deprecated and removed
- [ ] Production deployment successful

---

## Appendix: Quick Validation Checklist

**Print this and check during testing:**

### 🔴 Critical (Must Pass)

- [ ] User always knows current revision state
- [ ] User cannot accidentally skip publishing
- [ ] User cannot edit locked revision
- [ ] Every error shows next action
- [ ] No modal ping-pong required

### 🟡 Important (Should Pass)

- [ ] Workflow faster than current system
- [ ] No hidden critical actions
- [ ] Keyboard navigation works
- [ ] Responsive on tablet

### 🟢 Nice to Have (Can Defer)

- [ ] Keyboard shortcuts for all actions
- [ ] Offline draft support
- [ ] Animation polish

---

**Document End**

*Use this document to validate each implementation phase. No phase ships without passing its criteria.*
