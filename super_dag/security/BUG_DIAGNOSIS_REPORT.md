# 🐛 Bug Diagnosis Report - Selector Bounce Back After Draft Switch

**Date:** 2025-12-15  
**Severity:** P0 (Production Critical)  
**Status:** 🔍 Diagnosis Complete - Ready for Fix

---

## 📋 PHASE 2 — DIAGNOSIS

### 1. Source of Truth ของ "current version" ตอนนี้คืออะไร?

**คำตอบ: ไม่มี Single Source of Truth ที่ชัดเจน**

มีหลายแหล่งที่พยายามควบคุม state:

- **`GraphVersionController.currentIdentity`** (ควรเป็น SSOT)
  - ถูก set จาก `handleGraphLoaded` → `setIdentity()`
  - แต่ยังถูก override ได้จาก `selectGraph()` → `onLoadRequest()`
  - **ปัญหา:** Controller ยังไม่มี authority จริง ๆ เพราะ sidebar สามารถ override ได้

- **`lastLoadIntent`** (intent tracking, ไม่ใช่ state)
  - Track intent ของ load request (`{ graphId, versionParam, ts }`)
  - ใช้สำหรับ stale response guard
  - **ไม่ใช่ state** - เป็นแค่ intent tracking

- **Selector DOM element** (passive view ควรเป็น)
  - ถูก render จาก `GraphVersionController.renderSelector()`
  - แต่ยังถูก control จากหลายที่ (change handler, select2)
  - **ปัญหา:** DOM ยังเป็น "authority" ในบางกรณี

- **Global flags** (`window.__dagCurrentGraphId`, `window.__dagCurrentRequestedVersion`)
  - ใช้สำหรับ sidebar guard check
  - **ไม่ใช่ SSOT** - เป็นแค่ helper flags

**สรุป:** ไม่มี canonical version state - มี multiple authorities ที่แย่งกันควบคุม

---

### 2. ใครคือผู้เรียก `selectGraph()` หลังจาก user action?

**คำตอบ: `GraphSidebar.loadGraphs()` success callback → `selectGraph()` with `source='sidebar_autoselect'`**

**Sequence:**

```
1. User switches to Draft (v4.0)
   → handleVersionSelectorChange() → loadGraph('draft')
   → handleGraphLoaded() → setIdentity({ ref: 'draft' })

2. Sidebar may reload (async, from refresh/filter change)
   → GraphSidebar.loadGraphs() → success callback
   → Check: shouldAutoSelect = check guards...
   → this.selectGraph(selectedGraphId, 'sidebar_autoselect')
   → versionController.selectGraph(graphId, 'sidebar_autoselect')
   → onLoadRequest({ ref: 'published' }) ← OVERRIDE!
```

**หลักฐานจาก code:**

```javascript
// graph_sidebar.js:168-280
success: (response, textStatus, xhr) => {
    // ...
    if (this.selectedGraphId) {
        const shouldAutoSelect = (() => {
            // Guard check...
            return true; // Default: allow auto-select
        })();
        
        if (shouldAutoSelect) {
            setTimeout(() => {
                this.selectGraph(this.selectedGraphId, 'sidebar_autoselect'); // ← ตัวการ!
            }, 100);
        }
    }
}
```

**ปัญหาหลัก:**
- Sidebar reload (async) เกิดขึ้นหลังจาก draft load success
- `shouldAutoSelect` guard ไม่แข็งแรงพอ - ผ่าน guard แล้วยัง trigger autoselect
- Autoselect จะ load `published` เสมอ (default ใน `selectGraph()`)

---

### 3. ทำไม log ถึงแสดงลำดับนี้?

**Sequence จาก log:**

```
1. handleGraphLoaded → Showing draft mode (✅ draft load success)
2. Selector state ถูก revert กลับ published (❌ override)
```

**สาเหตุ:**

```
Timeline:
T0: User switches to Draft
    → loadGraph(graphId, 'draft')
    → setLastLoadIntent({ versionParam: 'draft' })

T1: Draft load success (backend)
    → handleGraphLoaded() → effectiveStatus = 'draft'
    → setIdentity({ ref: 'draft' }) ✅
    → renderSelector() → selector shows 'draft' ✅

T2: Sidebar async reload (may happen anytime)
    → loadGraphs() success callback
    → shouldAutoSelect check (may pass guards)
    → selectGraph(graphId, 'sidebar_autoselect')
    → versionController.selectGraph() → onLoadRequest({ ref: 'published' })
    → loadGraph(graphId, 'published') ❌ OVERRIDE!
    
T3: Published load success
    → handleGraphLoaded() → effectiveStatus = 'published'
    → setIdentity({ ref: 'published' }) ❌
    → renderSelector() → selector shows 'published' ❌
```

**ปัญหาคือ:**
- Sidebar reload เป็น async event ที่เกิดขึ้น "เมื่อไหร่ก็ได้"
- Guards ไม่แข็งแรงพอ - `shouldAutoSelect` ยัง return `true` ในบางกรณี
- `selectGraph()` default เป็น `published` เสมอ → ไม่สนใจ current identity

---

### 4. ปัญหานี้คืออะไร?

**คำตอบ: Multiple Authorities + State Overwrite**

**A) Multiple Authorities:**
- `GraphVersionController` พยายามเป็น SSOT แต่ไม่มี authority
- `GraphSidebar` ยังมี authority ผ่าน `selectGraph()` autoselect
- DOM selector ยังเป็น authority ในบางกรณี (change handler)

**B) State Overwrite:**
- Sidebar autoselect **เขียนทับ** current identity โดยไม่สนใจ
- `selectGraph()` default เป็น `published` → ไม่ preserve current identity
- Guards อ่อนเกินไป - ผ่าน guard แล้วยัง override ได้

**C) Race Condition:**
- Sidebar reload (async) race กับ draft load success
- ไม่มี synchronization - draft load success แล้ว แต่ sidebar อาจ reload ทีหลัง
- Guards ใช้เวลา-based (draftLockUntil, recentUserDraftPick) → อาจหมดเวลา

**สรุป:** **ไม่มี Single Source of Truth** + **Multiple Authorities** → State overwrite

---

## 📊 Sequence Diagram (Text)

```
User Action: Switch to Draft (v4.0)
    ↓
handleVersionSelectorChange()
    ↓
loadGraph(graphId, 'draft')
    ↓
setLastLoadIntent({ versionParam: 'draft' })
    ↓
[ASYNC: Backend request]
    ↓
[ASYNC: Sidebar may reload here]
    ↓
handleGraphLoaded() [Draft Success]
    ↓
setIdentity({ ref: 'draft' }) ✅
    ↓
renderSelector() → shows 'draft' ✅
    ↓
[ASYNC: Sidebar reload success callback fires]
    ↓
shouldAutoSelect check (may pass)
    ↓
selectGraph(graphId, 'sidebar_autoselect') ❌
    ↓
versionController.selectGraph()
    ↓
onLoadRequest({ ref: 'published' }) ❌ OVERRIDE!
    ↓
loadGraph(graphId, 'published')
    ↓
handleGraphLoaded() [Published Success]
    ↓
setIdentity({ ref: 'published' }) ❌
    ↓
renderSelector() → shows 'published' ❌
    ↓
RESULT: Selector bounced back to published
```

---

## 🎯 PHASE 3 — ROOT CAUSE

**เลือก: D) ไม่มี canonical version state**

### ทำไมไม่ใช่ข้ออื่น?

**A) Draft lock window สั้นเกิน:**
- ❌ ไม่ใช่ - Lock window 15s แล้วยังเด้ง → ไม่ใช่ปัญหาเวลา
- ปัญหาคือ **sidebar autoselect ยังสามารถ override ได้** แม้ lock active

**B) Selector state ถูกควบคุมจากหลาย controller:**
- ⚠️ ใช่ส่วนหนึ่ง แต่ไม่ใช่ root cause
- ปัญหาคือ **ไม่มี canonical state** → ทำให้หลาย controller แย่งกัน control

**C) Published-first design flaw:**
- ❌ ไม่ใช่ - boot fix แก้แล้ว
- ปัญหานี้เกิดตอน **switch ระหว่าง version** ไม่ใช่ boot

**D) ไม่มี canonical version state:**
- ✅ **ใช่ - นี่คือ root cause**
- ไม่มี single source of truth → multiple authorities → state overwrite
- `GraphVersionController.currentIdentity` ควรเป็น SSOT แต่ไม่มี authority จริง
- Sidebar autoselect ยัง override ได้เพราะไม่มี canonical state check

**E) อื่น ๆ:**
- ❌ ไม่ใช่ - ปัญหาอื่นเป็น symptom ของ "ไม่มี canonical state"

---

## 💡 PHASE 4 — FIX STRATEGY

### แนวทาง: **Make GraphVersionController.currentIdentity the ONLY Authority**

**หลักการ:**
1. **GraphVersionController.currentIdentity = Single Source of Truth**
   - ใครก็ตามที่ต้องการรู้ "current version" ต้องอ่านจาก `currentIdentity` เท่านั้น
   - ห้ามอ่านจาก selector DOM, ห้าม infer จาก guard flags

2. **Sidebar Autoselect ห้าม Override เมื่อ currentIdentity มีค่า**
   - ถ้า `currentIdentity` มีค่าแล้ว → ห้าม autoselect ทับเด็ดขาด
   - Autoselect ได้เฉพาะเมื่อ `currentIdentity === null` (initial boot)

3. **selectGraph() ต้อง Preserve currentIdentity**
   - ถ้า `currentIdentity` มีค่า และเป็น graph เดียวกัน → ห้าม override
   - ถ้า `currentIdentity.ref === 'draft'` → ห้าม autoselect load published

**ใครเป็น owner:**
- **GraphVersionController.currentIdentity** = Owner ของ version state
- **GraphSidebar** = ห้ามเขียน state (อ่านได้อย่างเดียว)
- **Selector DOM** = Passive view (reflect เท่านั้น, ไม่ decide)

**ใครห้ามเขียน:**
- Sidebar autoselect → ห้ามเรียก `selectGraph()` ถ้า `currentIdentity !== null`
- Async callbacks → ห้าม override `currentIdentity` โดยไม่ผ่าน `handleGraphLoaded()`

**Event ไหนต้อง ignore:**
- `selectGraph(graphId, 'sidebar_autoselect')` → ignore ถ้า `currentIdentity !== null`
- Sidebar reload autoselect → ignore ถ้า graph ยัง load อยู่ (`isLoadingGraph === true`)

---

## 🔧 PHASE 5 — MINIMAL PATCH PLAN

### Patch 1: Block Sidebar Autoselect When currentIdentity Exists

**File:** `assets/javascripts/dag/graph_sidebar.js`  
**Function:** `loadGraphs()` success callback  
**Location:** Before `shouldAutoSelect` check

**Logic ที่ถูกลบออก:**
- ลบ `shouldAutoSelect` guard check (ซับซ้อนและไม่ reliable)
- ลบ `setTimeout` autoselect logic

**Logic ที่เพิ่ม:**
```javascript
// BEFORE autoselect check:
if (versionController && versionController.getIdentity()) {
    const currentIdentity = versionController.getIdentity();
    // If currentIdentity exists, NEVER autoselect (preserve user selection)
    if (currentIdentity.graphId === this.selectedGraphId) {
        console.log('[Sidebar] Skipping autoselect - graph already loaded with identity:', currentIdentity);
        return; // Exit - don't autoselect
    }
}
```

**Expected log หลังแก้:**
```
[Sidebar] Skipping autoselect - graph already loaded with identity: { ref: 'draft', ... }
```
**Published request จะไม่ถูกยิงอีก** - autoselect ถูก block

---

### Patch 2: Make selectGraph() Respect currentIdentity

**File:** `assets/javascripts/dag/modules/GraphVersionController.js`  
**Function:** `selectGraph()`  
**Location:** Before default `ref: 'published'` assignment

**Logic ที่ถูกลบออก:**
- ลบ pre-identity guards (ซับซ้อนและไม่ reliable)
- ลบ draft lock checks (ไม่จำเป็นถ้าใช้ canonical state)

**Logic ที่เพิ่ม:**
```javascript
// BEFORE default ref: 'published':
if (this.currentIdentity && this.currentIdentity.graphId === graphId) {
    // Graph already loaded - preserve current identity
    if (source !== 'user' && source !== 'init') {
        console.warn('[GraphVersionController] Ignoring autoselect - preserving current identity:', this.currentIdentity);
        return; // Don't override current identity
    }
    // User/init can override (explicit action)
}
```

**Expected log หลังแก้:**
```
[GraphVersionController] Ignoring autoselect - preserving current identity: { ref: 'draft', ... }
```
**Published request จะไม่ถูกยิงอีก** - `selectGraph()` return ก่อน load

---

## ✅ PHASE 6 — SAFETY CHECK

### หลัง fix นี้ มีโอกาสไหมที่:

**A) Draft save ไปเขียน published?**
- ✅ **ไม่** - Backend hard guarantee แล้ว (security patch)
- Frontend fix ไม่กระทบ backend write path

**B) Publish ถูก trigger โดย UI bug?**
- ✅ **ไม่** - Publish ต้องผ่าน `graph_publish` endpoint (security patch)
- Frontend fix ไม่กระทบ publish flow

**C) Job runtime อ่าน graph ผิด version?**
- ✅ **ไม่** - Job runtime อ่านจาก pinned version (ไม่ใช่ latest)
- Frontend fix ไม่กระทบ backend read path

**สรุป:** ✅ **ปลอดภัย 100%** - Frontend fix ไม่กระทบ backend security guarantees

---

## 📝 Summary

**Diagnosis:**
- ไม่มี Single Source of Truth
- Multiple authorities แย่งกันควบคุม state
- Sidebar autoselect override user selection

**Root Cause:**
- **D) ไม่มี canonical version state**

**Fix Strategy:**
- Make `GraphVersionController.currentIdentity` the ONLY authority
- Block sidebar autoselect when `currentIdentity` exists
- Preserve current identity in `selectGraph()`

**Minimal Patch:**
- 2 จุด: Sidebar autoselect guard + `selectGraph()` preserve logic
- ไม่เพิ่ม guard ซ้อน, ไม่เพิ่ม timeout, ไม่เพิ่ม flag

**Safety:**
- ✅ ปลอดภัย 100% - ไม่กระทบ backend security guarantees

---

**Status:** ✅ Ready for Implementation  
**Next Step:** Apply minimal patches (2 points only)

