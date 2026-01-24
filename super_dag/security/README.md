# 🔒 Security Documentation

This directory contains security audit reports and security-related patches for the DAG Graph system.

## 📚 Documents

### 1. [Security Audit Report](./SECURITY_AUDIT_REPORT.md)
**Date:** 2025-12-15  
**Purpose:** รายงานผลการตรวจสอบความปลอดภัยของระบบ Graph Write Operations

**Contents:**
- ✅ Audit Results (3 คำถามหลัก)
- ✅ Security Guarantees (Before Patch)
- ⚠️ Vulnerability Found (P0)
- 📝 Files Examined

**Key Findings:**
1. ✅ Draft writes are safe (write only to `routing_graph_draft`)
2. ✅ Published versions are immutable (no UPDATE statements)
3. ✅ Job/runtime reads from pinned versions (not latest)
4. ⚠️ **Vulnerability:** `graph_save` still accepts `save_type=publish`

### 2. [Security Hard Guarantee Patch](./SECURITY_HARD_GUARANTEE_PATCH.md)
**Date:** 2025-12-15  
**Purpose:** รายละเอียดการแก้ไขช่องโหว่ P0 และ Hard Guarantees ที่เพิ่มเข้าไป

**Contents:**
- 🔧 Changes Made (4 layers)
- 🎯 Security Layers (Defense in Depth)
- 📊 Before vs After Comparison
- ✅ Hard Guarantees Achieved
- 🔍 Security Audit Trail
- 🧪 Testing Recommendations

**Changes:**
1. API Layer: Block `save_type=publish` in `graph_save`
2. Resolver Layer: Block `publish` in `GraphSaveModeResolver`
3. New Endpoint: `graph_publish` (architectural separation)
4. Legacy Cleanup: Remove `case 'publish':` from `graph_save` switch

## 🎯 Security Guarantees

### ✅ Draft Write
- **Writes only to `routing_graph_draft`** → Cannot leak to published

### ✅ Published Write
- **Can only write via `graph_publish` endpoint** → Cannot use `graph_save`
- **Requires active draft** → Cannot publish from main tables
- **ETag/If-Match required** → Prevents concurrent conflicts
- **INSERT only** → No UPDATE statements on `routing_graph_version`

### ✅ Job/Runtime Read
- **Reads from pinned version** → New publishes don't affect running jobs
- **Immutable snapshots** → Each job uses same graph version throughout

## 🛡️ Defense in Depth

1. **API Layer Block** - Hard reject `save_type=publish` in `graph_save`
2. **Resolver Layer Block** - Second layer of defense
3. **Endpoint Separation** - Clear architectural separation
4. **Service Layer** - INSERT only (no UPDATE)

## 📊 Status

- ✅ **Audit Complete** - All 3 questions answered
- ✅ **Vulnerability Identified** - P0 severity
- ✅ **Patch Applied** - Hard guarantees in place
- ✅ **Documentation Complete** - Ready for review

## 🔍 Security Audit Trail

All illegal publish attempts through `graph_save` are logged:

```
[SECURITY AUDIT] Illegal write attempt: graph_save with save_type=publish rejected 
(graphId=1952, userId=1, action=graph_save). 
Use graph_publish endpoint instead.
```

## 📝 Related Files

### Backend:
- `source/dag/dag_graph_api.php` - API endpoints
- `source/dag/Graph/Service/GraphSaveModeResolver.php` - Save mode resolver
- `source/dag/Graph/Service/GraphDraftService.php` - Draft service
- `source/dag/Graph/Service/GraphVersionService.php` - Version service

### Job/Runtime:
- `source/job_ticket.php` - Job creation (pins version)
- `source/dag/Graph/Service/GraphVersionResolver.php` - Version resolver

## 🚀 Next Steps

1. ✅ Review documentation
2. ⏳ Update frontend to use `graph_publish` endpoint
3. ⏳ Add integration tests for security guarantees
4. ⏳ Monitor security audit logs

---

**Last Updated:** 2025-12-15  
**Status:** ✅ Complete - Ready for Production

