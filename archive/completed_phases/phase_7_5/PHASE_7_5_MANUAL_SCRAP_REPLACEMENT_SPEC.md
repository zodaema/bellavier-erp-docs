# PHASE 7.5 – SCRAP & REPLACEMENT (MANUAL MODE ONLY)

**Created:** November 2, 2025  
**Status:** Implementation Spec (Ready for Development)  
**Target:** Manual scrap replacement only (no auto-spawn)

---

## 🎯 เป้าหมาย

รองรับเคส "ซ่อมไม่ไหว / material defect" โดย:

- ✅ กด scrap token ได้อย่างเป็นทางการ
- ✅ Log ประวัติชัดเจน
- ✅ Supervisor สามารถสร้าง "replacement token" ด้วยมือได้จาก UI
- ❌ **ยังไม่ทำ auto_spawn อะไรทั้งสิ้น** (`on_scrap.mode = "manual"` เท่านั้น)

---

## 📋 1) Scope / Non-goals

### ✅ IN Scope (ต้องทำตอนนี้)

1. รองรับสถานะ `scrapped` สำหรับ Atelier token (`flow_token`)
2. บันทึก `token_event` เวลา scrap
3. เพิ่มความสามารถ "scrap token" ผ่าน API + UI
4. เพิ่ม UI ให้ supervisor:
   - ดูว่า token ไหนถูก scrap แล้ว
   - กด "Create Replacement Token" ด้วยมือ
5. ผูกความสัมพันธ์ `scrapped_token → replacement_token` ใน DB

### ❌ OUT of Scope (ห้ามทำตอนนี้)

- ❌ ไม่ทำ `on_scrap.mode = auto_spawn_from_start` / `auto_spawn_from_cut`
- ❌ ไม่ทำ approval flow
- ❌ ไม่ทำ scrap policy ซับซ้อน (by reason mapping ฯลฯ)
- ❌ ไม่แตะ logic Serial Number (reuse ที่มีอยู่)

---

## 🗄️ 2) Database Changes

### 2.1 flow_token Table

```sql
-- Add columns for scrap replacement tracking
ALTER TABLE flow_token
ADD COLUMN parent_scrapped_token_id INT NULL COMMENT 'Reference to scrapped token (if this is a replacement)',
ADD COLUMN scrap_replacement_mode VARCHAR(50) NULL COMMENT 'manual, auto_start, auto_cut (future use)',
ADD COLUMN scrapped_at DATETIME NULL COMMENT 'When token was scrapped',
ADD COLUMN scrapped_by INT NULL COMMENT 'Who scrapped the token (id_member)',
ADD INDEX idx_parent_scrapped (parent_scrapped_token_id);

-- Optional FK (ถ้า schema ปัจจุบันรองรับ)
ALTER TABLE flow_token
ADD CONSTRAINT fk_flow_token_parent_scrapped
  FOREIGN KEY (parent_scrapped_token_id)
  REFERENCES flow_token(id_token)
  ON DELETE SET NULL;
```

**Phase 7.5 จะใช้เฉพาะค่า:**
- `scrap_replacement_mode = 'manual'` สำหรับ replacement token
- `parent_scrapped_token_id` ชี้กลับไปยัง token ที่โดน scrap
- `scrapped_at` และ `scrapped_by` สำหรับ audit trail

### 2.2 token_event Table

**ไม่ต้องเปลี่ยน schema** ถ้า `metadata` เป็น JSON/text อยู่แล้ว

**ใช้ pattern นี้:**

```json
{
  "event_type": "scrap",
  "metadata": {
    "reason": "material_defect | max_rework_exceeded | other",
    "rework_count": 3,
    "limit": 3,
    "comment": "สายหนังมีรอยตำหนิจากการฟอก"
  }
}
```

**Event Types ที่ต้องใช้:**
- `scrap` - Token ถูก scrap
- `replacement_created` - Replacement token ถูกสร้าง (log บน scrapped token)
- `replacement_of` - Token นี้เป็น replacement ของ scrapped token (log บน replacement token)

---

## ⚙️ 3) Runtime Logic – Scrap Flow (Manual)

### 3.1 Invariants

เวลาจะ scrap token ให้ยึดกติกานี้:

1. **เฉพาะ token ที่ `status IN ('active', 'waiting', 'rework')` เท่านั้นที่ scrap ได้**
2. **เมื่อ scrap แล้ว:**
   - `status → 'scrapped'`
   - Token นี้ห้ามถูก reassign / resume / rework อีก
3. **ต้องสร้าง `token_event` เสมอ**
4. **ถ้ามี replacement token ภายหลัง:**
   - `replacement.token.parent_scrapped_token_id = scrapped.id_token`
   - `replacement.scrap_replacement_mode = 'manual'`

### 3.2 Relationship with Rework / QC Limit

**Critical Context:**

1. **Scrap vs Rework:**
   - Scrap **ไม่ใช่** auto-trigger เมื่อ rework limit ถึง
   - Scrap เป็น **manual decision** ของ Supervisor/Manager
   - เมื่อ QC fail แล้วเข้า rework ไม่ได้ (เพราะถึง limit) → Supervisor **เลือก** scrap แทน
   - `reason = max_rework_exceeded` จะถูกใช้เมื่อระบบ/หัวหน้าตัดสินว่า "ซ่อมต่อไม่คุ้ม/ไม่เหมาะสม"

2. **Scrap Behavior:**
   - Scrap **ไม่เปลี่ยน** `rework_count` (ใช้ค่าปัจจุบันเท่านั้น)
   - Scrap **หยุด life-cycle** ของ token ทันที (ไม่สามารถ rework/resume ได้อีก)
   - Scrap **ไม่เพิ่ม** rework_count อีก (ถือว่า "จบ life-cycle ของ token นี้" ทันที)

3. **UI Locations for Scrap Button:**
   - ✅ **Token Detail View** (required)
   - ✅ **QC Result View** (required - กรณี fail แล้วช่าง/หัวหน้ากด scrap แทนที่จะส่ง rework)
   - ✅ **Work Queue** (optional - supervisor view)
   - ✅ **Token Management Dashboard** (optional - supervisor view)

4. **Flow Example:**
   ```
   Token at QC → Fail (rework_count = 2, limit = 3)
   → Supervisor sees: "Can still rework (2/3)"
   → Supervisor chooses: "Scrap instead" (manual decision)
   → reason = "max_rework_exceeded" (even though limit not reached)
   → Token scrapped, rework_count stays at 2
   ```

---

### 3.3 API Endpoint: Scrap Token

**File:** `source/dag_token_api.php`  
**Action:** `scrap`

**Request:**
```json
POST /source/dag_token_api.php?action=scrap
{
  "token_id": 12345,
  "reason": "material_defect" | "max_rework_exceeded" | "other",
  "comment": "สายหนังมีรอยตำหนิจากการฟอก"
}
```

**Response:**
```json
{
  "ok": true,
  "token_id": 12345,
  "status": "scrapped",
  "message": "Token scrapped successfully"
}
```

**Error Cases:**
- `TOKEN_NOT_FOUND` - Token ไม่มีในระบบ
- `TOKEN_CANNOT_BE_SCRAPPED_FROM_THIS_STATUS` - Status ไม่ใช่ active/waiting/rework
- `UNAUTHORIZED` - ไม่มีสิทธิ์ scrap token

### 3.3 Pseudo-code – Scrap Token

```php
function scrapToken(int $idToken, string $reason, ?string $comment, ?int $memberId): array {
    // 1. Load token
    $token = $flowTokenRepo->find($idToken);
    if (!$token) {
        throw new NotFoundException('TOKEN_NOT_FOUND');
    }
    
    // 2. Validate status
    if (!in_array($token->status, ['active', 'waiting', 'rework'], true)) {
        throw new DomainException('TOKEN_CANNOT_BE_SCRAPPED_FROM_THIS_STATUS');
    }
    
    // 3. Validate reason
    $allowedReasons = ['material_defect', 'max_rework_exceeded', 'other'];
    if (!in_array($reason, $allowedReasons, true)) {
        throw new ValidationException('INVALID_SCRAP_REASON');
    }
    
    // 4. Update status
    $token->status = 'scrapped';
    $token->scrapped_at = date('Y-m-d H:i:s');
    $token->scrapped_by = $memberId;
    $flowTokenRepo->save($token);
    
    // 5. Create token_event
    $event = new TokenEvent();
    $event->id_token = $token->id_token;
    $event->event_type = 'scrap';
    $event->created_by = $memberId;
    $event->event_time = date('Y-m-d H:i:s');
    $event->metadata = json_encode([
        'reason' => $reason,
        'comment' => $comment,
        'rework_count' => $token->rework_count ?? null,
        'limit' => $token->rework_limit ?? null,
    ], JSON_UNESCAPED_UNICODE);
    $tokenEventRepo->save($event);
    
    // 6. (Phase 7.5) No auto replacement here
    // Supervisor will create replacement manually via UI
    
    return [
        'ok' => true,
        'token_id' => $token->id_token,
        'status' => 'scrapped',
        'message' => 'Token scrapped successfully'
    ];
}
```

---

## 🔄 4) Replacement Token (Manual Creation)

### 4.1 แนวคิด

Supervisor เปิดดู token ที่โดน scrap → กดปุ่ม  
→ ระบบพาไปสร้าง token ใหม่ (ผ่าน flow spawn เดิมที่มีอยู่แล้ว)  
→ แค่เพิ่มการผูก `parent_scrapped_token_id` + `scrap_replacement_mode`

### 4.2 API Endpoint: Create Replacement Token

**File:** `source/dag_token_api.php`  
**Action:** `create_replacement`

**Request:**
```json
POST /source/dag_token_api.php?action=create_replacement
{
  "scrapped_token_id": 12345,
  "spawn_mode": "from_start",  // หรือ "from_cut" ในอนาคต, ตอนนี้ hard-coded ก็ได้
  "comment": "QC ตัดสินว่าต้องตัดหนังใหม่"
}
```

**Response:**
```json
{
  "ok": true,
  "replacement_token_id": 56789,
  "scrapped_token_id": 12345,
  "spawn_node": "START",
  "message": "Replacement token created successfully"
}
```

**Error Cases:**
- `SCRAPPED_TOKEN_NOT_FOUND` - Scrapped token ไม่มีในระบบ
- `TOKEN_IS_NOT_SCRAPPED` - Token ยังไม่ถูก scrap
- `REPLACEMENT_ALREADY_EXISTS` - มี replacement token อยู่แล้ว
- `START_NODE_NOT_FOUND` - ไม่พบ START node ใน graph

### 4.3 Phase 7.5 Policy: Serial Number for Replacement

**CRITICAL: Lock this policy for Phase 7.5**

**Policy Decision:**
- ✅ **Option A: Reuse serial เดิม** (Selected for Phase 7.5)
  - เพื่อให้ 1 serial ผูกกับ 1 product จริงในมุมมองลูกค้า
  - แต่ history ภายในเห็นว่าเคย scrap + replacement
  - Mapping: `parent_scrapped_token_id` + `scrap_replacement_mode` = 'manual'
  - **ห้ามให้ service ตัดสินใจเองในแต่ละที่**

**NOT for Phase 7.5:**
- ❌ Option B: สร้าง serial ใหม่ แต่ link กลับ
  - เช่น replacement_serial ใหม่, แล้ว show ใน Finished DB ว่าเป็น "replacement of SN XXX"
  - จะทำใน Phase 7.6+ ถ้าต้องการ trace replacement separately

**Implementation Rule:**
```php
// ✅ CORRECT (Phase 7.5):
$replacementSerial = $scrapped->product_serial; // Always reuse

// ❌ WRONG (Phase 7.5):
$replacementSerial = generateNewSerial(); // Don't do this in Phase 7.5
$replacementSerial = $scrapped->product_serial . '-REPLACE'; // Don't do this
```

**Storage:**
- Serial mapping เก็บใน `flow_token.parent_scrapped_token_id`
- ไม่ต้องสร้าง `serial_link` table เพิ่ม (Phase 7.5)
- Finished Production View จะ query `parent_scrapped_token_id` เพื่อ trace history

---

### 4.4 Pseudo-code – Create Replacement Token

```php
function createReplacementToken(
    int $scrappedId, 
    string $spawnMode, 
    ?string $comment, 
    int $memberId
): array {
    // 1. Load scrapped token
    $scrapped = $flowTokenRepo->find($scrappedId);
    if (!$scrapped) {
        throw new NotFoundException('SCRAPPED_TOKEN_NOT_FOUND');
    }
    
    if ($scrapped->status !== 'scrapped') {
        throw new DomainException('TOKEN_IS_NOT_SCRAPPED');
    }
    
    // 2. Check if replacement already exists
    $existingReplacement = $flowTokenRepo->findOne([
        'parent_scrapped_token_id' => $scrappedId
    ]);
    if ($existingReplacement) {
        throw new DomainException('REPLACEMENT_ALREADY_EXISTS', [
            'replacement_token_id' => $existingReplacement->id_token
        ]);
    }
    
    // 3. Determine start node for replacement
    // Phase 7.5: simple rule, e.g. always START node of the same graph/job
    $startNodeId = resolveStartNodeForReplacement($scrapped, $spawnMode);
    if (!$startNodeId) {
        throw new NotFoundException('START_NODE_NOT_FOUND');
    }
    
    // 4. Create new token (reuse existing spawn logic)
    // ⚠️ PHASE 7.5 POLICY: Serial Number for Replacement
    // Option A: Reuse serial เดิม (recommended for Phase 7.5)
    // เพื่อให้ 1 serial ผูกกับ 1 product จริงในมุมมองลูกค้า
    // แต่ history ภายในเห็นว่าเคย scrap + replacement
    $replacementSerial = $scrapped->product_serial; // Reuse original serial
    
    // Option B: Generate new serial (NOT for Phase 7.5)
    // จะทำใน Phase 7.6+ ถ้าต้องการ trace replacement separately
    // $replacementSerial = generateReplacementSerial($scrapped->product_serial);
    
    $replacement = $flowTokenService->spawnTokenFromNode(
        $scrapped->id_job_ticket,
        $startNodeId,
        $replacementSerial // Phase 7.5: Always reuse original serial
    );
    
    // 5. Link back to parent scrapped token
    $replacement->parent_scrapped_token_id = $scrapped->id_token;
    $replacement->scrap_replacement_mode = 'manual';
    $flowTokenRepo->save($replacement);
    
    // 6. Log event on both sides
    $tokenEventRepo->create([
        'id_token' => $scrapped->id_token,
        'event_type' => 'replacement_created',
        'created_by' => $memberId,
        'event_time' => date('Y-m-d H:i:s'),
        'metadata' => json_encode([
            'replacement_token_id' => $replacement->id_token,
            'spawn_mode' => $spawnMode,
            'created_by' => $memberId,
            'comment' => $comment,
        ], JSON_UNESCAPED_UNICODE)
    ]);
    
    $tokenEventRepo->create([
        'id_token' => $replacement->id_token,
        'event_type' => 'replacement_of',
        'created_by' => $memberId,
        'event_time' => date('Y-m-d H:i:s'),
        'metadata' => json_encode([
            'scrapped_token_id' => $scrapped->id_token,
            'spawn_mode' => $spawnMode,
            'created_by' => $memberId,
            'comment' => $comment,
        ], JSON_UNESCAPED_UNICODE)
    ]);
    
    return [
        'ok' => true,
        'replacement_token_id' => $replacement->id_token,
        'scrapped_token_id' => $scrapped->id_token,
        'spawn_node' => 'START',
        'message' => 'Replacement token created successfully'
    ];
}

/**
 * Helper: Resolve start node for replacement token
 * Phase 7.5: Simple implementation - always use START node
 */
function resolveStartNodeForReplacement($scrappedToken, string $spawnMode): ?int {
    // Get graph instance
    $graphInstance = $graphInstanceRepo->find($scrappedToken->id_graph_instance);
    if (!$graphInstance) {
        return null;
    }
    
    // Find START node in graph
    $startNode = $nodeRepo->findOne([
        'id_graph' => $graphInstance->id_graph,
        'node_type' => 'start'
    ]);
    
    if ($spawnMode === 'from_cut') {
        // Future: Find CUT node
        // For Phase 7.5, fallback to START
        $cutNode = $nodeRepo->findOne([
            'id_graph' => $graphInstance->id_graph,
            'node_type' => 'operation',
            'team_category' => 'cutting'
        ]);
        return $cutNode ? $cutNode->id_node : ($startNode ? $startNode->id_node : null);
    }
    
    return $startNode ? $startNode->id_node : null;
}
```

---

## 🎨 5) UI Changes (ขั้นต่ำที่ควรมี)

### 5.1 Token Detail View

**เพิ่ม block ด้านล่าง (เฉพาะ Atelier token):**

#### ถ้า `status != 'scrapped'`:

**ปุ่ม:** 🗑 Scrap Token

**เมื่อกด:**
- Dialog ถาม:
  - **Reason** (select: `max_rework`, `material_defect`, `other`)
  - **Comment** (textarea)
- ส่งไปที่ `action=scrap`

**JavaScript Example:**
```javascript
function showScrapDialog(tokenId) {
    Swal.fire({
        title: t('token.scrap_token', 'Scrap Token'),
        html: `
            <div class="mb-3">
                <label class="form-label">${t('token.scrap_reason', 'Reason')}</label>
                <select class="form-select" id="scrap-reason">
                    <option value="max_rework_exceeded">${t('token.reason_max_rework', 'Max Rework Exceeded')}</option>
                    <option value="material_defect">${t('token.reason_material_defect', 'Material Defect')}</option>
                    <option value="other">${t('token.reason_other', 'Other')}</option>
                </select>
            </div>
            <div class="mb-3">
                <label class="form-label">${t('token.comment', 'Comment')}</label>
                <textarea class="form-control" id="scrap-comment" rows="3"></textarea>
            </div>
        `,
        showCancelButton: true,
        confirmButtonText: t('common.scrap', 'Scrap'),
        confirmButtonColor: '#dc3545',
        cancelButtonText: t('common.cancel', 'Cancel')
    }).then((result) => {
        if (result.isConfirmed) {
            const reason = document.getElementById('scrap-reason').value;
            const comment = document.getElementById('scrap-comment').value;
            scrapToken(tokenId, reason, comment);
        }
    });
}

function scrapToken(tokenId, reason, comment) {
    $.post('source/dag_token_api.php', {
        action: 'scrap',
        token_id: tokenId,
        reason: reason,
        comment: comment
    }, function(resp) {
        if (resp.ok) {
            notifySuccess(t('token.scrapped_success', 'Token scrapped successfully'));
            location.reload();
        } else {
            notifyError(resp.error || t('token.scrap_failed', 'Failed to scrap token'));
        }
    }, 'json');
}
```

#### ถ้า `status = 'scrapped'`:

**แสดง:**
- Badge: `Status: SCRAPPED`
- ปุ่ม: ➕ Create Replacement Token
- ถ้ามี replacement อยู่แล้ว:
  - แสดงลิงก์ไป token ใหม่: `Replacement: #56789`
- ถ้า token นี้เป็นตัว replacement:
  - แสดงลิงก์: `Replacement of: #12345 (scrapped)`

**HTML Example:**
```html
<!-- Scrapped Token View -->
<div class="alert alert-danger">
    <strong>Status:</strong> SCRAPPED
    <br>
    <small>Scrapped at: <?= $token['scrapped_at'] ?></small>
    <?php if ($token['scrapped_by']): ?>
        <br>
        <small>Scrapped by: <?= $token['scrapped_by_name'] ?></small>
    <?php endif; ?>
</div>

<?php if (!$token['has_replacement']): ?>
    <button class="btn btn-primary" onclick="showCreateReplacementDialog(<?= $token['id_token'] ?>)">
        ➕ Create Replacement Token
    </button>
<?php else: ?>
    <div class="alert alert-info">
        <strong>Replacement:</strong> 
        <a href="?p=token_detail&token_id=<?= $token['replacement_token_id'] ?>">
            Token #<?= $token['replacement_token_id'] ?>
        </a>
    </div>
<?php endif; ?>

<!-- Replacement Token View -->
<?php if ($token['parent_scrapped_token_id']): ?>
    <div class="alert alert-warning">
        <strong>Replacement of:</strong> 
        <a href="?p=token_detail&token_id=<?= $token['parent_scrapped_token_id'] ?>">
            Token #<?= $token['parent_scrapped_token_id'] ?> (scrapped)
        </a>
    </div>
<?php endif; ?>
```

**JavaScript Example:**
```javascript
function showCreateReplacementDialog(scrappedTokenId) {
    Swal.fire({
        title: t('token.create_replacement', 'Create Replacement Token'),
        html: `
            <div class="mb-3">
                <label class="form-label">${t('token.spawn_mode', 'Spawn Mode')}</label>
                <select class="form-select" id="spawn-mode">
                    <option value="from_start">${t('token.from_start', 'From START (Remake entire piece)')}</option>
                    <option value="from_cut">${t('token.from_cut', 'From CUT (Recut material only)')}</option>
                </select>
            </div>
            <div class="mb-3">
                <label class="form-label">${t('token.comment', 'Comment')}</label>
                <textarea class="form-control" id="replacement-comment" rows="3"></textarea>
            </div>
        `,
        showCancelButton: true,
        confirmButtonText: t('common.create', 'Create'),
        confirmButtonColor: '#0dcaf0',
        cancelButtonText: t('common.cancel', 'Cancel')
    }).then((result) => {
        if (result.isConfirmed) {
            const spawnMode = document.getElementById('spawn-mode').value;
            const comment = document.getElementById('replacement-comment').value;
            createReplacementToken(scrappedTokenId, spawnMode, comment);
        }
    });
}

function createReplacementToken(scrappedTokenId, spawnMode, comment) {
    $.post('source/dag_token_api.php', {
        action: 'create_replacement',
        scrapped_token_id: scrappedTokenId,
        spawn_mode: spawnMode,
        comment: comment
    }, function(resp) {
        if (resp.ok) {
            notifySuccess(t('token.replacement_created', 'Replacement token created successfully'));
            location.reload();
        } else {
            notifyError(resp.error || t('token.replacement_failed', 'Failed to create replacement token'));
        }
    }, 'json');
}
```

### 5.2 History / Timeline

**แสดง event `scrap` และ `replacement_created` / `replacement_of`**

เพื่อให้เห็น story ของชิ้นนี้แบบโปร่งใส

**Example:**
```html
<div class="token-timeline">
    <div class="timeline-item">
        <span class="badge bg-danger">SCRAP</span>
        <span class="timestamp">2025-11-02 14:30</span>
        <p>Reason: Material Defect</p>
        <p class="text-muted">สายหนังมีรอยตำหนิจากการฟอก</p>
    </div>
    <div class="timeline-item">
        <span class="badge bg-info">REPLACEMENT CREATED</span>
        <span class="timestamp">2025-11-02 14:35</span>
        <p>Replacement Token: <a href="?p=token_detail&token_id=56789">#56789</a></p>
        <p class="text-muted">QC ตัดสินว่าต้องตัดหนังใหม่</p>
    </div>
</div>
```

### 5.3 Work Queue Filter

**เพิ่ม filter:** "Hide Scrapped Tokens" (default: checked)

เพื่อไม่ให้ token ที่ถูก scrap โผล่ใน work queue ของช่าง

---

## ✅ 6) Success Criteria – Phase 7.5

### Checklist:

- [ ] **สามารถเปลี่ยน token → scrapped จาก UI ได้**
  - [ ] Dialog scrap ทำงานถูกต้อง
  - [ ] API endpoint `scrap` ทำงานถูกต้อง
  - [ ] Validation rules ถูกต้อง

- [ ] **Token ที่ถูก scrap จะไม่กลับมาโผล่ใน work queue ของช่างอีก**
  - [ ] Filter "Hide Scrapped Tokens" ทำงานถูกต้อง
  - [ ] Query work queue ไม่รวม `status = 'scrapped'`

- [ ] **Supervisor สามารถสร้าง replacement token ด้วยมือ:**
  - [ ] Dialog create replacement ทำงานถูกต้อง
  - [ ] API endpoint `create_replacement` ทำงานถูกต้อง
  - [ ] Replacement token ผูก `parent_scrapped_token_id` ถูกต้อง
  - [ ] มี event log ทั้งสองฝั่ง (`replacement_created` + `replacement_of`)

- [ ] **หน้า Token Detail:**
  - [ ] แสดงความสัมพันธ์ scrap ↔ replacement
  - [ ] แสดง timeline/history ถูกต้อง

- [ ] **ไม่มีการ auto spawn / auto approval ใดๆ ทั้งสิ้นใน Phase นี้**
  - [ ] ไม่มี logic auto spawn ใน scrap flow
  - [ ] ไม่มี approval flow

---

## 🔍 7) Testing Checklist

### Unit Tests:

- [ ] `scrapToken()` - Validate status before scrap
- [ ] `scrapToken()` - Create token_event correctly
- [ ] `scrapToken()` - **Idempotency: Call scrapToken() twice → Second call must fail with TOKEN_CANNOT_BE_SCRAPPED_FROM_THIS_STATUS**
- [ ] `scrapToken()` - **Permission check: Must fail if user doesn't have atelier.token.scrap**
- [ ] `createReplacementToken()` - Validate scrapped token exists
- [ ] `createReplacementToken()` - **Idempotency: Call createReplacementToken() twice → Second call must fail with REPLACEMENT_ALREADY_EXISTS**
- [ ] `createReplacementToken()` - Prevent duplicate replacement
- [ ] `createReplacementToken()` - Link parent_scrapped_token_id correctly
- [ ] `createReplacementToken()` - Create events on both tokens
- [ ] `createReplacementToken()` - **Permission check: Must fail if user doesn't have atelier.token.create_replacement**
- [ ] `createReplacementToken()` - **Serial policy: Must reuse original serial (not generate new)**

### Integration Tests:

- [ ] Scrap token from UI → Verify status changed
- [ ] Scrap token → Verify event created
- [ ] **Scrap token twice (concurrent) → Second request must fail**
- [ ] Create replacement → Verify replacement token created
- [ ] Create replacement → Verify events created on both tokens
- [ ] **Create replacement twice → Second request must fail with REPLACEMENT_ALREADY_EXISTS**
- [ ] Scrapped token → Verify not shown in work queue
- [ ] Replacement token → Verify linked to scrapped token
- [ ] **Replacement token → Verify serial number matches original (not new)**
- [ ] **Permission check: Operator cannot scrap token**
- [ ] **Permission check: Operator cannot create replacement**

### Manual Testing:

- [ ] Test scrap flow end-to-end
- [ ] Test replacement creation flow end-to-end
- [ ] Test UI dialogs (scrap + replacement)
- [ ] Test token detail view (scrap + replacement display)
- [ ] Test work queue filter (hide scrapped tokens)

---

## 📝 8) Implementation Notes

### 8.1 File Locations

**API:**
- `source/dag_token_api.php` - Add `scrap` and `create_replacement` actions

**UI:**
- `views/token_detail.php` - Add scrap/replacement UI
- `assets/javascripts/dag/token_detail.js` - Add scrap/replacement JS functions

**Database:**
- Migration: `database/tenant_migrations/YYYY_MM_scrap_replacement.php`

### 8.2 Dependencies

- Existing `flow_token` table
- Existing `token_event` table
- Existing token spawn logic (reuse for replacement)
- Existing Serial Number Engine (reuse for replacement serial)

### 8.3 Permissions

**Required Permissions:**
- **Scrap Token:** `atelier.token.scrap` (or reuse existing token management permission)
- **Create Replacement:** `atelier.token.create_replacement` (or supervisor role)

**Critical Rules:**
- ✅ **scrap / create_replacement ต้องไม่เปิดให้ Operator** (default only Supervisor / Manager)
- ✅ **ถ้า Tenant ยังไม่ได้ map role → default ต้อง "ปิด"** ไม่ให้ scrap ผ่าน API โดยตรง (ต้องมี auth check)
- ✅ **API endpoints ต้อง check permission ก่อน execute** (ไม่ใช่แค่ UI)

**Permission Check Example:**
```php
// In scrapToken() function:
must_allow('atelier.token.scrap'); // Throws if not allowed

// In createReplacementToken() function:
must_allow('atelier.token.create_replacement'); // Throws if not allowed

// Fallback (if permission not set):
$member = $objMemberDetail->thisLogin();
if (!$member) {
    throw new UnauthorizedException('UNAUTHORIZED');
}

// Check role (if permission system not available):
$allowedRoles = ['supervisor', 'manager', 'admin'];
if (!in_array($member['role'], $allowedRoles)) {
    throw new ForbiddenException('FORBIDDEN: Only supervisor/manager can scrap tokens');
}
```

---

## 🚀 9) Next Steps (Future Phases)

**Phase 7.6 (Future):**
- Auto spawn replacement (`on_scrap.mode = auto_spawn_from_start`)
- Approval flow for auto spawn
- Scrap policy by reason mapping

**Phase 7.7 (Future):**
- Material cost tracking for replacements
- Analytics dashboard for scrap rate
- Scrap reason analysis

**Phase 7.8 (Future): Finished Production / Traceability**

**Note:** Phase 7.5 ยังไม่ไปแตะ Finished Production DB แต่ต้อง ensure ว่า table/fields ตอนนี้รองรับการ trace ได้

**Future Requirements:**
- ✅ **Finished Production View ต้องแสดง history scrap + replacement**
  - เพื่อให้เห็นว่า product ใบสุดท้ายที่ส่งลูกค้า มาจาก token ไหน
  - เคยมี scrap ก่อนหน้าไหม (via `parent_scrapped_token_id`)
  - ต้อง query `flow_token.parent_scrapped_token_id` เพื่อ trace history

**Current Phase 7.5 Support:**
- ✅ `parent_scrapped_token_id` field exists (ready for traceability)
- ✅ `scrap_replacement_mode` field exists (ready for traceability)
- ✅ `token_event` with `replacement_created` / `replacement_of` events (ready for history)
- ✅ Serial number reuse policy (1 serial = 1 product from customer view)

**Future Implementation:**
- Query replacement chain: `SELECT * FROM flow_token WHERE parent_scrapped_token_id = ?`
- Show in Finished Production: "This product was remade (replacement of token #12345)"
- Analytics: Count replacements per job ticket / product type

---

**Status:** Ready for Implementation  
**Estimated Effort:** 4-6 hours  
**Priority:** Medium (can be done after core DAG features)

