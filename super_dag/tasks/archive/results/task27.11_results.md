# Task 27.11 Results — get_context API Created

**Completed:** 2025-12-04  
**Duration:** ~30 minutes  
**Status:** ✅ Complete

---

## Files Modified

### `source/dag_token_api.php`

**Changes (+~200 lines):**

1. **Added case 'get_context'** to switch statement (line ~375)
   ```php
   case 'get_context':
       handleGetContext($db);
       break;
   ```

2. **Added `handleGetContext()` function** (~100 lines)
   - Validates token_id input
   - Fetches token from flow_token
   - Gets current node with work_center and behavior_code
   - For component tokens: gets parent, siblings, tray
   - For piece tokens at merge: gets child components
   - Returns structured JSON context

3. **Added `fetchSiblingComponents()` helper** (~20 lines)
   - Queries components by parallel_group_id
   - Returns id_token, status, component_code, worker_name

4. **Added `fetchChildComponents()` helper** (~20 lines)
   - Queries components by parent_token_id
   - Same return structure as siblings

---

## API Specification

### Request

```
POST/GET source/dag_token_api.php
action=get_context&token_id=123
```

### Response Structure

```json
{
  "ok": true,
  "context": {
    "token": { /* full flow_token record */ },
    "node": { /* current routing_node + work_center info */ },
    "parent": { /* parent token (for component) */ },
    "tray": { "tray_code": "T-XXX", "final_serial": "XXX" },
    "siblings": [ /* array of sibling/child components */ ]
  }
}
```

### Error Codes

| Code | HTTP | Description |
|------|------|-------------|
| `DAG_400_MISSING_TOKEN_ID` | 400 | token_id not provided |
| `DAG_404_TOKEN_NOT_FOUND` | 404 | Token doesn't exist |

---

## Testing Checklist

- [x] PHP syntax check passes (`php -l`)
- [x] No linter errors
- [x] Case added to switch statement
- [x] Function follows existing code patterns
- [x] Uses prepared statements (security)
- [x] Graceful fallbacks (null/empty array for missing data)
- [x] i18n: Uses translate() for error messages
- [x] Logging: Logs request with token_id, type, status

---

## Manual Testing (To Be Done by Developer)

### Test Scenario 1: Component Token
```bash
curl -X POST "http://localhost:8888/bellavier-group-erp/source/dag_token_api.php" \
  -H "Cookie: PHPSESSID=xxx" \
  -d "action=get_context&token_id=123"
```
Expected: token + node + parent + siblings + tray

### Test Scenario 2: Simple Piece Token
Expected: token + node + tray + siblings=[]

### Test Scenario 3: Token at Merge (status=waiting)
Expected: token + node + siblings (child components) + tray

### Test Scenario 4: Invalid Token ID
Expected: `{ok: false, error: "Token not found", app_code: "DAG_404_TOKEN_NOT_FOUND"}`

---

## Integration Notes

### Frontend Usage

```javascript
// Work Queue UI can now call:
const response = await fetch('/source/dag_token_api.php', {
    method: 'POST',
    body: new URLSearchParams({
        action: 'get_context',
        token_id: tokenId
    })
});
const data = await response.json();

if (data.ok) {
    const { token, node, parent, tray, siblings } = data.context;
    // Render UI with context data
}
```

### Data Contract

- `token`: Always present (full record)
- `node`: Present if token has current_node_id
- `parent`: Present for component tokens with parent_token_id
- `tray`: Present if serial_number exists
- `siblings`: Array (empty if no siblings/children)

---

## Phase 5 Status

- [x] Task 27.11: get_context API ✅ COMPLETE

---

## Related Documents

- Task specification: `docs/super_dag/tasks/task27.11.md`
- Phase 1-4 (dependencies): Tasks 27.2-27.10 complete

---

**END OF RESULTS**

