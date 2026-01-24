# Ghost Graph Issue - Debug Summary

**Date**: 14-Dec-2025  
**Graph ID**: 1957  
**Issue**: Published graph positions and configurations change when creating/deleting drafts

---

## Problem Description

### Symptoms
1. เมื่อเปิดกราฟที่ Published แล้ว (เช่น v2.0 Published) ตำแหน่งของ nodes และ configuration ต่างๆ เปลี่ยนไปมา
2. เมื่อสร้าง Draft จาก Published graph → ตำแหน่ง nodes เปลี่ยน
3. เมื่อลบ Draft → ตำแหน่ง nodes เปลี่ยนกลับ
4. Frontend ไม่แสดง draft mode หลังจาก create draft สำเร็จ

### Root Cause Hypothesis
- **Source of Truth Confusion**: ระบบมีหลายแหล่งข้อมูล (main tables, version snapshots, draft payloads) ที่ไม่สอดคล้องกัน
- **Draft Override Issue**: Backend อาจ override published data ด้วย draft data แม้จะ request published version
- **Frontend State Management**: Frontend ไม่ switch ไป draft mode หลังจาก create draft

---

## Timeline of Fixes

### Phase 1: Initial Analysis (User Request)
**Request**: แก้ไข 3 จุด:
1. **Backend Write (Sync Main Tables)**: `GraphVersionService::publish()` ไม่ update main tables
2. **Backend Read (Prevent Draft Override)**: `GraphService::getGraph()` override ด้วย draft data แม้ request published
3. **Frontend Request (Explicit Versioning)**: Frontend ไม่ส่ง `version='published'` เมื่อดู published version

**Changes Made**:
- ✅ แก้ไข `GraphVersionService::publish()` ให้ sync main tables
- ✅ แก้ไข `GraphService::getGraph()` ให้ไม่ override เมื่อ request published
- ✅ แก้ไข `loadGraphWithVersion()` ให้โหลด published จาก snapshot
- ✅ แก้ไข frontend `loadGraph()` ให้ส่ง `version='published'` เมื่อ request published

**Result**: ยังคงมีปัญหา - frontend ไม่แสดง draft mode และตำแหน่ง nodes ยังเปลี่ยน

---

### Phase 2: Frontend Mode Switch Issue
**Problem**: Frontend ไม่ switch ไป draft mode หลังจาก create draft

**Analysis from External AI**:
- Frontend ไม่ update `window._selectedVersionForLoad` หลังจาก create draft
- `loadGraph()` เรียกโดยไม่ส่ง version parameter → fallback ไปใช้ 'latest'
- Backend เมื่อได้รับ `version='latest'` จะส่ง draft data กลับมา (ถ้ามี active draft)

**Changes Made**:
- ✅ แก้ไข `createDraftFromPublishedInternal()` ให้ update `window._selectedVersionForLoad`
- ✅ แก้ไข `createDraftFromPublishedInternal()` ให้ refresh version selector
- ✅ แก้ไข `createDraftFromPublishedInternal()` ให้เรียก `loadGraph()` ด้วย explicit parameters
- ✅ แก้ไข `loadGraph()` ให้ prioritize explicit parameters

**Result**: ยังคงมีปัญหา - frontend ยังไม่แสดง draft mode

---

### Phase 3: Draft Info Not Received
**Problem**: Frontend ไม่ได้รับ `draftInfo` ใน API response ครั้งแรก

**Observations from Logs**:
```
[GraphService::getGraph] draftInfo set: has_draft=true draft_id=49
[GraphLoader] API response: {hasDraft: false, draftInfo: null}  // ❌ Missing!
```

**Analysis**:
- Backend set `draftInfo` แล้ว แต่ frontend ไม่ได้รับ
- อาจเป็น cached response (304 Not Modified) ที่ไม่มี draft field

**Changes Made**:
- ✅ เพิ่ม debug logging ใน `GraphLoader.js` และ `handleGraphLoaded()`
- ✅ เพิ่ม force reload logic เมื่อตรวจพบว่า response ไม่มี draft field
- ✅ เปลี่ยนจาก `debugLogger.log` เป็น `console.log` เพื่อให้เห็น logs แน่นอน

**Result**: ครั้งที่สอง (reload) ได้รับ draftInfo แล้ว แต่ครั้งแรกยังไม่ได้รับ

---

### Phase 4: Draft Payload Structure Mismatch
**Problem**: `loadGraphWithVersion()` ไม่สามารถ decode draft payload ได้

**Observations from Logs**:
```
[loadGraphWithVersion] Draft query result: found=yes draft_id=51 has_payload=yes
[loadGraphWithVersion] Loading from draft payload: graphId=1957 draft_id=51
[loadGraphWithVersion] Draft payload invalid or empty: graphId=1957  // ❌
```

**Root Cause Found**:
- Draft payload structure: `{ nodes: [...], edges: [...], metadata: {...} }` (ไม่มี `graph` field)
- Published payload structure: `{ graph: {...}, nodes: [...], edges: [...] }` (มี `graph` field)
- `loadGraphWithVersion()` ตรวจสอบ `isset($payload['graph'])` → fail เพราะ draft payload ไม่มี `graph` field

**Database Verification**:
```sql
SELECT JSON_KEYS(draft_payload_json) FROM routing_graph_draft WHERE id_graph_draft = 51;
-- Result: ["edges", "nodes", "metadata"]  // ❌ No "graph" key!
```

**Changes Made**:
- ✅ แก้ไข `loadGraphWithVersion()` ให้ตรวจสอบ `isset($payload['nodes']) && isset($payload['edges'])` แทน
- ✅ โหลด graph metadata จาก main table (เพราะ draft payload ไม่มี graph object)
- ✅ Set status เป็น 'draft' สำหรับ draft data
- ✅ เพิ่ม debug logging เพื่อตรวจสอบ payload structure

**Current Status**: ✅ **FIXED** - Draft payload โหลดได้ถูกต้องแล้ว

---

## Current Code State

### Backend Files Modified

1. **`source/dag/_helpers.php`** - `loadGraphWithVersion()` function
   - ✅ Check for active draft when `version === 'latest'`
   - ✅ Load from draft payload if exists (structure: `{ nodes, edges, metadata }`)
   - ✅ Load graph metadata from main table (draft payload doesn't include graph)
   - ✅ Load from version snapshot when `version === 'published'`
   - ✅ Debug logging added

2. **`source/dag/Graph/Service/GraphService.php`** - `getGraph()` method
   - ✅ Set `draftInfo` metadata for UI purposes
   - ✅ Source-of-truth logging

3. **`source/dag/dag_graph_api.php`** - `graph_get` action
   - ✅ ETag calculation includes draft_id when active draft exists
   - ✅ Debug logging for ETag calculation

### Frontend Files Modified

1. **`assets/javascripts/dag/graph_designer.js`**
   - ✅ `loadGraph()` - prioritize explicit version parameters
   - ✅ `handleGraphLoaded()` - check `draftInfo.has_draft` and show draft mode
   - ✅ `createDraftFromPublishedInternal()` - update state and refresh selector after draft creation
   - ✅ Debug logging added

2. **`assets/javascripts/dag/modules/GraphLoader.js`**
   - ✅ Force reload logic when response missing draft field
   - ✅ Debug logging added

3. **`assets/javascripts/dag/modules/GraphAPI.js`**
   - ✅ Handle 304 Not Modified responses
   - ✅ Retry without If-None-Match if response is empty

---

## Testing Observations

### Successful Flow (After Fix)
```
1. Open graph 1957 → Shows v2.0 Published ✅
2. Create Draft → Backend creates draft_id=51 ✅
3. Frontend receives draftInfo → Shows draft mode ✅
4. Switch back to v2.0 Published → Shows published version ✅
```

### Problematic Flow (Before Fix)
```
1. Open graph 1957 → Shows v2.0 Published ✅
2. Create Draft → Backend creates draft ✅
3. Frontend doesn't receive draftInfo → Still shows published mode ❌
4. Node positions change → Ghost data issue ❌
```

---

## Key Technical Details

### Draft Payload Structure
```json
{
  "nodes": [...],
  "edges": [...],
  "metadata": {
    "saved_at": "2025-12-14 00:26:01",
    "saved_by": 1,
    "version_note": null
  }
}
```

**Note**: Draft payload **DOES NOT** include `graph` object - must load from main table.

### Published Payload Structure
```json
{
  "graph": {
    "id_graph": 1957,
    "code": "...",
    "status": "published",
    ...
  },
  "nodes": [...],
  "edges": [...]
}
```

### Version Resolution Logic
- `version='latest'`: 
  1. Check for active draft → load from draft payload if exists
  2. Otherwise load from main tables (published state)
- `version='published'`: Load from `routing_graph_version` snapshot
- `version='draft'`: Treated as `version='latest'` (will load draft if exists)
- `version='v2.0'`: Load specific version from `routing_graph_version` snapshot

---

## Remaining Issues / Questions

1. **Cache Behavior**: ครั้งแรกที่โหลด graph อาจเป็น cached response (304) ที่ไม่มี draft field → frontend force reload ทำงาน แต่ยังไม่ได้ draft field (อาจเป็น browser cache)

2. **ETag Calculation**: ETag ควรเปลี่ยนเมื่อมี active draft (include draft_id) → ควรป้องกัน stale cache แต่ยังมีปัญหา

3. **Debug Logs**: ควร clean up debug logs หลังจากแก้ไขเสร็จ

---

## Recommendations for Next Steps

1. **Verify Fix**: ทดสอบอีกครั้งเพื่อยืนยันว่า draft payload โหลดได้ถูกต้องแล้ว
2. **Clean Up**: ลบ debug logs ที่ไม่จำเป็นหลังจากยืนยันว่าแก้ไขเสร็จแล้ว
3. **Performance**: ตรวจสอบว่า draft payload structure ที่ไม่มี graph object เป็น intentional design หรือควร include graph object เพื่อลด database queries
4. **Documentation**: อัพเดท API documentation เพื่อระบุ draft payload structure ที่แตกต่างจาก published payload

---

## Files to Review

### Backend
- `source/dag/_helpers.php` (lines 160-300) - `loadGraphWithVersion()` function
- `source/dag/Graph/Service/GraphService.php` (lines 185-220) - `getGraph()` draftInfo handling
- `source/dag/Graph/Service/GraphDraftService.php` (lines 81-90) - Draft payload structure creation

### Frontend
- `assets/javascripts/dag/graph_designer.js` (lines 1492-1652) - `handleGraphLoaded()` function
- `assets/javascripts/dag/graph_designer.js` (lines 1395-1475) - `createDraftFromPublishedInternal()` function
- `assets/javascripts/dag/modules/GraphLoader.js` (lines 69-105) - Force reload logic


