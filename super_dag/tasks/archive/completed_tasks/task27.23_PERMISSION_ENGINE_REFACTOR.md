# Task 27.23: Permission Engine Refactor

> **Status:** ✅ PHASE 0 + PHASE 1 COMPLETED (2025-12-08)  
> **Priority:** 🔴 CRITICAL - Blocks QC, Material, RRM, Node Behavior  
> **Created:** 2025-12-08  
> **Estimated Effort:** 3-5 days (Phased approach)

---

## 🎯 Executive Summary

### ปัญหาที่พบ

ระบบ Permission ปัจจุบันเป็นแบบ **Role-based Access Control (RBAC) ตายตัว**:

```
USER → ROLE (Operator, QC, Admin)
ROLE → PERMISSIONS (menu, page access)
```

**ปัญหา:**
- Operator กด QC Pass/Fail ไม่ได้ ถ้า Role ไม่ใช่ QC
- QC Inspector ไม่สามารถ stitch/cut ได้ ถ้า Role ไม่ใช่ Operator
- ช่างคนเดียวทำหลายหน้าที่ (เย็บ + QC ชิ้นเล็ก) ไม่ได้
- Permission ผูกกับ ROLE อย่างเดียว → แข็งติด, ขยายไม่ได้

### ความจริงของโรงงาน Hatthasilpa (และ Hermès)

> **"ไม่มีใครเป็นช่างที่ทำงานเดียวตลอดเวลา"**

- ช่าง A เย็บ + QC ชิ้นเล็กได้
- ช่าง B ตัดหนัง + QC initial inspection
- QC inspector ทำ QC final แต่บางครั้งช่างก็ QC ตัวเองก่อนส่ง
- ช่างเก่งๆ ทำครบทุกขั้นตอน (full-stack artisan)
- งานบางชิ้นต้อง assign QC ให้เฉพาะคนที่ผ่าน certification

→ **Role มาตายตัวแบบ Operator / QC / Admin มันไม่พอ**

---

## 🏗️ สิ่งที่มีอยู่แล้ว (ใช้ได้เลย)

### 1. Role-based Permission (PermissionHelper.php)
```php
// ใช้สำหรับเข้าถึงหน้า/เมนู
PermissionHelper::permissionAllowCode($member, 'hatthasilpa.job.view');
PermissionHelper::mustAllowCode($member, 'hatthasilpa.job.assign');
```

### 2. Operator Role Config (OperatorRoleConfig.php)
```php
// Role families with inheritance
OPERATOR_ROLE_CODES = ['production_operator', 'artisan_operator']
SUPERVISOR_ROLE_CODES = ['production_supervisor', 'quality_manager']
ROLE_INHERITANCE = [
    'production_operator' => ['senior_production_operator', 'apprentice_operator']
]
```

### 3. Token Assignment System (HatthasilpaAssignmentService)
```php
// Manager → Operator assignment
$assignment = $assignmentService->findForToken($tokenId);
$assignment->assignedToId;
$assignment->assignmentMethod; // 'manager', 'auto', 'pin'
$assignment->isStrictAssignment;
```

### 4. Node Behavior System (behavior_code)
```php
// Node มี behavior ที่บอกว่าต้องทำอะไร
$node->behavior_code; // 'CUT', 'STITCH', 'QC_SINGLE', 'QC_MULTI'
```

---

## ❌ สิ่งที่ขาด (Gap Analysis)

### 1. ไม่มี Central Permission Engine

**ปัจจุบัน: Logic กระจายทั่ว**
```javascript
// TokenCardState.js
function canActOnToken(state) {
    return state.isAssignedToMe || state.isMine || state.helpType !== null;
    // ❌ ไม่รู้ว่า node นี้ต้องการ role อะไร
    // ❌ ไม่รู้ว่า user มี permission ทำ action นี้ไหม
}
```

```php
// dag_token_api.php
function handleStartToken($tokenId, $operatorId) {
    // ❌ เช็คแค่ assignment, ไม่เช็ค node requirement
    // ❌ ไม่มี central can() function
}
```

**ต้องการ: Central Permission Engine**
```php
$engine = new PermissionEngine($db, $userId);
$can = $engine->can('qc_pass', [
    'token_id' => $tokenId,
    'node_id' => $nodeId
]);
// ✅ รู้ทุกอย่าง: role, assignment, node config
```

### 2. Node-level Permission Config ไม่มี

**ปัจจุบัน:** Node ไม่มี config ว่า "ใครทำได้"
```sql
-- routing_node ไม่มี field เหล่านี้
-- qc_allowed_roles, required_certification, self_qc_allowed
```

**ต้องการ:** Node-level permission config
```sql
ALTER TABLE routing_node ADD COLUMN permission_config JSON;
-- {
--   "allowed_roles": ["operator", "qc_inspector"],
--   "self_qc_allowed": true,
--   "required_certification": null
-- }
```

### 3. Action Permission Mapping ไม่มี

**ปัจจุบัน:** ไม่มี mapping ว่า action ไหนต้องการ permission อะไร

**ต้องการ:**
```php
const ACTION_PERMISSIONS = [
    'start_token' => ['requires_assignment' => true, 'node_check' => true],
    'pause_token' => ['requires_session' => true],
    'qc_pass' => ['node_type' => 'qc', 'roles' => ['qc_inspector'], 'or_assigned' => true],
    'qc_fail' => ['node_type' => 'qc', 'roles' => ['qc_inspector', 'supervisor'], 'or_assigned' => true],
    'consume_material' => ['roles' => ['operator'], 'node_behavior' => ['CUT', 'STITCH']],
];
```

### 4. Assignment Method Integration ไม่มี (🆕 CRITICAL)

**ปัจจุบัน:** PermissionEngine ไม่รองรับ assignment method ที่หลากหลาย

**ระบบจริงมี 4 แบบ:**
| Method | Description | Permission Rule |
|--------|-------------|-----------------|
| `manager` | Manager assign ให้ operator | **Strict:** เฉพาะคนที่ถูก assign เท่านั้น |
| `auto` | ระบบ assign อัตโนมัติ | First come first serve |
| `pin` | Operator pin งานไว้ | Pinned person มี priority, คนอื่นช่วยได้ |
| `help` | ช่วยเพื่อน | Helper ทำได้เฉพาะบาง action |

**ต้องการ:**
```php
class PermissionEngine {
    public function can($action, $context) {
        $assignment = $this->getAssignment($context['token_id']);
        
        // Check assignment method
        switch ($assignment->method) {
            case 'manager':
                if ($assignment->is_strict) {
                    // STRICT: Only assigned person can work
                    if ($this->userId !== $assignment->assigned_to_id) {
                        return false;
                    }
                }
                break;
                
            case 'pin':
                // Pinned operator has priority
                // Others can help but pinned person's work takes precedence
                $context['is_helper'] = ($this->userId !== $assignment->assigned_to_id);
                break;
                
            case 'auto':
                // First come first serve
                // Anyone with role can start if not already started
                break;
                
            case 'help':
                // Helper can only do specific actions (not complete, not qc_fail)
                if (in_array($action, ['complete_token', 'qc_fail'])) {
                    return false;
                }
                break;
        }
        
        return $this->checkRoleAndNode($action, $context);
    }
}
```

### 5. Token Type Rules ไม่มี (🆕 CRITICAL)

**ปัจจุบัน:** PermissionEngine ไม่รู้จัก token ประเภทต่างๆ

**ระบบจริงมี Token หลายประเภท:**
| Type | Origin | Permission Rule |
|------|--------|-----------------|
| `normal` | MO/Job creation | ตาม assignment ปกติ |
| `split` | Parallel split node | อาจ assign ให้คนละคน |
| `replacement` | QC fail → create new | **Previous operator** หรือ **QC role** เท่านั้น |
| `rework` | RRM rework | ช่างเดิมหรือ specialist |

**ต้องการ:**
```php
class PermissionEngine {
    public function can($action, $context) {
        $token = $this->getToken($context['token_id']);
        
        // Check token type rules
        switch ($token->origin_type) {
            case 'replacement':
                // QC replacement: previous operator OR QC role can act
                $previousOperator = $this->getPreviousOperator($token);
                if ($this->userId !== $previousOperator && !$this->hasRole('qc_inspector')) {
                    return false;
                }
                break;
                
            case 'rework':
                // Rework: usually same operator or specialist
                $originalOperator = $this->getOriginalOperator($token);
                $isSpecialist = $this->hasRole('rework_specialist');
                if ($this->userId !== $originalOperator && !$isSpecialist) {
                    return false;
                }
                break;
                
            case 'split':
                // Component token: check component-specific assignment
                $componentAssignment = $this->getComponentAssignment($token);
                if ($componentAssignment && $this->userId !== $componentAssignment->assigned_to_id) {
                    return false;
                }
                break;
        }
        
        return $this->checkAssignmentMethod($action, $context);
    }
    
    private function getPreviousOperator($token) {
        // Get operator who worked on parent token before QC fail
        return $this->db->fetchValue(
            "SELECT operator_id FROM token_work_session 
             WHERE id_token = ? AND status = 'completed' 
             ORDER BY ended_at DESC LIMIT 1",
            [$token->parent_token_id]
        );
    }
}
```

### 6. QC Node Special Rules ไม่มี (🆕 HIGH)

**ปัจจุบัน:** QC node ใช้ logic เดียวกับ node อื่น

**ปัญหา:**
- QC node มักไม่มี assignment ล่วงหน้า
- ช่าง QC ต้องเริ่มงานได้เลย (self-pick)
- บาง QC ให้ช่างทำเองได้ (self-QC)

**ต้องการ:**
```php
class PermissionEngine {
    public function canActOnQcNode($action, $context) {
        $node = $this->getNode($context['node_id']);
        
        // QC nodes are often "open" - anyone with QC role can pick
        if ($node->behavior_code === 'QC_SINGLE' || $node->behavior_code === 'QC_MULTI') {
            
            // Check if self-QC is allowed
            $config = json_decode($node->permission_config, true) ?? [];
            if ($config['self_qc_allowed'] ?? false) {
                // Previous operator can QC their own work
                $previousOperator = $this->getPreviousOperatorOnToken($context['token_id']);
                if ($this->userId === $previousOperator) {
                    return true;
                }
            }
            
            // Anyone with QC role can pick unassigned QC
            if (!$this->isAssigned($context['token_id']) && $this->hasRole('qc_inspector')) {
                return true;
            }
        }
        
        return false;
    }
}
```

---

## 🎯 Proposed Solution: 3-Layer Permission Model

```
┌─────────────────────────────────────────────────────────────────┐
│                     PERMISSION ENGINE                           │
│                                                                 │
│  can($userId, $action, $tokenContext)                          │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Layer 1: ROLE             Layer 2: ASSIGNMENT                 │
│   ┌─────────────────┐       ┌─────────────────┐                │
│   │ production_op   │       │ token_assignment│                │
│   │ qc_inspector    │       │ assigned_to_id  │                │
│   │ supervisor      │       │ is_strict       │                │
│   └─────────────────┘       └─────────────────┘                │
│            │                        │                          │
│            └────────┬───────────────┘                          │
│                     │                                          │
│            Layer 3: NODE CONFIG                                │
│            ┌─────────────────┐                                 │
│            │ routing_node    │                                 │
│            │ permission_json │                                 │
│            │ behavior_code   │                                 │
│            └─────────────────┘                                 │
│                     │                                          │
│            ┌───────┴───────┐                                   │
│            ▼               ▼                                   │
│       ALLOW ✅         DENY ❌                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Existing RBAC System (USE THIS!)

> **CRITICAL:** ระบบ RBAC ที่มีอยู่แล้วแข็งแรงมาก **ห้ามสร้างใหม่!**

### สิ่งที่มีอยู่แล้ว

| Component | Location | Purpose |
|-----------|----------|---------|
| **PermissionHelper** | `source/BGERP/Security/PermissionHelper.php` | Role-based permission check |
| **RbacHelper** | `source/BGERP/Rbac/RbacHelper.php` | RBAC utilities |
| **permission.php** | `source/permission.php` | Backward compatibility |
| **admin_rbac.php** | `source/admin_rbac.php` | Admin API |

### Key Functions (ใช้ได้เลย)

```php
// Check permission
PermissionHelper::permissionAllowCode($member, 'hatthasilpa.job.ticket');

// Check & exit 403 if denied
PermissionHelper::mustAllowCode($member, 'qc.fail.manage');

// Check platform permission
PermissionHelper::platformHasPermission('platform.accounts.manage');

// Check if owner/admin
PermissionHelper::isPlatformAdministrator($member);
PermissionHelper::isTenantAdministrator($member);
```

### Built-in Bypass Rules

| Condition | Result |
|-----------|--------|
| `platform_super_admin` | Bypass ALL |
| `id_tenant_role = 1` (owner) | Bypass ALL |
| `account_org.id_group = 1` | Bypass ALL |

---

## 📋 Implementation Plan (Phased)

### Phase 1: Soft Refactor (1 day) - Low Risk ✅

**Goal:** สร้าง PermissionEngine ที่ **ใช้ PermissionHelper เป็น base** + เพิ่ม Token-level layers

**New File:** `source/BGERP/Service/PermissionEngine.php`

```php
<?php
namespace BGERP\Service;

use BGERP\Security\PermissionHelper;

/**
 * Token-level Permission Engine
 * 
 * IMPORTANT: Uses PermissionHelper as base (DO NOT duplicate role checking!)
 * This engine adds TOKEN-LEVEL layers on top of existing RBAC.
 * 
 * Layers:
 * 1. Role Permission (via PermissionHelper - existing)
 * 2. Assignment Method (strict, auto, pin, help)
 * 3. Node Config (QC self-pick, self-QC)
 * 4. Token Type (replacement, rework, split)
 */
class PermissionEngine
{
    private \mysqli $db;
    private array $member;
    private HatthasilpaAssignmentService $assignmentService;
    
    public function __construct(\mysqli $db, array $member)
    {
        $this->db = $db;
        $this->member = $member;
        $this->assignmentService = new HatthasilpaAssignmentService($db);
    }
    
    /**
     * Central permission check - ALL action checks go through here
     */
    public function can(string $action, array $context = []): bool
    {
        // LAYER 0: Owner bypass (ใช้ระบบเดิม)
        if ($this->isOwner()) {
            return true;
        }
        
        $tokenId = $context['token_id'] ?? null;
        $nodeId = $context['node_id'] ?? null;
        
        // LAYER 1: Role Permission (ใช้ PermissionHelper ที่มีอยู่)
        $rolePermission = $this->mapActionToPermission($action);
        if ($rolePermission && !PermissionHelper::permissionAllowCode($this->member, $rolePermission)) {
            // Check if action allows bypass via assignment
            if (!$this->allowsBypassRoleCheck($action)) {
                return false;
            }
        }
        
        // Load context data
        $token = $tokenId ? $this->getToken($tokenId) : null;
        $node = $nodeId ? $this->getNode($nodeId) : ($token ? $this->getNode($token->current_node_id) : null);
        $assignment = $tokenId ? $this->assignmentService->findForToken($tokenId) : null;
        
        $ctx = [
            'user_id' => (int)$this->member['id_member'],
            'token' => $token,
            'node' => $node,
            'assignment' => $assignment,
            'is_assigned_to_me' => ($assignment->assignedToId ?? null) === (int)$this->member['id_member'],
        ];
        
        // LAYER 2: Assignment Method
        if (!$this->checkAssignmentMethod($action, $ctx)) {
            return false;
        }
        
        // LAYER 3: Node Config
        if (!$this->checkNodeConfig($action, $ctx)) {
            return false;
        }
        
        // LAYER 4: Token Type
        if (!$this->checkTokenType($action, $ctx)) {
            return false;
        }
        
        return true;
    }
    
    /**
     * Check if current user is owner (bypass all)
     */
    private function isOwner(): bool
    {
        // Use PermissionHelper's built-in bypass
        return PermissionHelper::isPlatformAdministrator($this->member)
            || PermissionHelper::isTenantAdministrator($this->member);
    }
    
    /**
     * Map action to role permission code
     */
    private function mapActionToPermission(string $action): ?string
    {
        $map = [
            'start' => 'hatthasilpa.job.ticket',
            'pause' => 'hatthasilpa.job.ticket',
            'resume' => 'hatthasilpa.job.ticket',
            'complete' => 'hatthasilpa.job.complete',
            'qc_pass' => 'qc.fail.manage',
            'qc_fail' => 'qc.fail.manage',
            'rework' => 'qc.rework.manage',
        ];
        return $map[$action] ?? null;
    }
    
    /**
     * Get all permissions for a token (for API response)
     */
    public function getTokenPermissions(int $tokenId): array
    {
        $actions = ['start', 'pause', 'resume', 'complete', 'qc_pass', 'qc_fail', 'rework'];
        $permissions = [];
        
        foreach ($actions as $action) {
            $permissions["can_{$action}"] = $this->can($action, ['token_id' => $tokenId]);
        }
        
        return $permissions;
    }
    
    // ... Layer check methods below ...
    {
        // Must be assigned or open token
        if ($ctx['is_assigned_to_me']) return true;
        if (!$ctx['assignment']?->assignedToId) return true; // Open token
        return false;
    }
    
    private function canPauseResume(array $ctx): bool
    {
        // Must have active session
        return $ctx['has_active_session'];
    }
    
    private function canQc(array $ctx): bool
    {
        $node = $ctx['node'];
        if (!$node || $node['node_type'] !== 'qc') return false;
        
        // Check node permission config (future)
        $permConfig = json_decode($node['permission_config'] ?? '{}', true);
        $selfQcAllowed = $permConfig['self_qc_allowed'] ?? false;
        
        // Option 1: User is assigned to this token
        if ($ctx['is_assigned_to_me']) return true;
        
        // Option 2: User has QC role
        if ($this->hasRole('qc_inspector') || $this->hasRole('quality_manager')) {
            return true;
        }
        
        // Option 3: Self-QC allowed and user worked on this token
        if ($selfQcAllowed && $this->workedOnToken($ctx['token']['id_token'])) {
            return true;
        }
        
        return false;
    }
    
    // ... more helper methods
}
```

**Changes to dag_token_api.php:**
```php
// Before:
if (!$this->hasActiveSession($tokenId)) {
    json_error('not_your_session');
}

// After:
$engine = new PermissionEngine($db, $operatorId);
if (!$engine->can('pause', ['token_id' => $tokenId])) {
    json_error('permission_denied');
}
```

---

### Phase 2: API Response Enhancement (0.5 day)

**Goal:** API ส่ง permissions มาพร้อม token data

**Change in dag_token_api.php `handleGetWorkQueue`:**
```php
// Add to enriched token data
$engine = new PermissionEngine($db, $operatorId);
$tokenData['permissions'] = $engine->getTokenPermissions($token['id_token']);

// Response:
{
    "id_token": 1234,
    "status": "ready",
    "permissions": {
        "can_start": true,
        "can_pause": false,
        "can_qc_pass": false,
        "can_qc_fail": false
    }
}
```

**Change in TokenCardParts.js:**
```javascript
// Before:
const canAct = TokenCardState.canActOnToken(state);

// After:
const canStart = state._raw.permissions?.can_start ?? false;
const canPause = state._raw.permissions?.can_pause ?? false;
const canQcPass = state._raw.permissions?.can_qc_pass ?? false;
```

---

### Phase 3: Node Permission Config (1 day)

**Goal:** เพิ่ม permission config ที่ node level

**Migration:** `2025_12_node_permission_config.php`
```php
// Add permission_config JSON column to routing_node
migration_add_column_if_missing(
    $db,
    'routing_node',
    'permission_config',
    '`permission_config` JSON NULL COMMENT "Node-level permission config"'
);
```

**Schema:**
```json
{
    "allowed_roles": ["operator", "qc_inspector"],
    "self_qc_allowed": true,
    "required_certification": null,
    "strict_assignment": false
}
```

---

### Phase 4: UI Simplification (0.5 day)

**Goal:** UI ไม่คิดเอง แสดงเฉพาะปุ่มที่มีสิทธิ

```javascript
// TokenCardParts.js - Simplified
function renderActionButtons(state, options = {}) {
    const perms = state._raw.permissions || {};
    let buttons = [];
    
    if (perms.can_start) {
        buttons.push(`<button class="btn btn-primary btn-start">Start</button>`);
    }
    if (perms.can_pause) {
        buttons.push(`<button class="btn btn-warning btn-pause">Pause</button>`);
    }
    if (perms.can_qc_pass) {
        buttons.push(`<button class="btn btn-success btn-qc-pass">Pass</button>`);
    }
    if (perms.can_qc_fail) {
        buttons.push(`<button class="btn btn-danger btn-qc-fail">Fail</button>`);
    }
    
    return buttons.join('');
}
```

---

## 📁 Files to Create/Modify

### New Files:
| File | Purpose |
|------|---------|
| `source/BGERP/Service/PermissionEngine.php` | Central permission engine |
| `database/tenant_migrations/2025_12_node_permission_config.php` | Add permission config to nodes |

### Files to Modify:
| File | Changes |
|------|---------|
| `source/dag_token_api.php` | Use PermissionEngine, add permissions to response |
| `source/BGERP/Service/HatthasilpaAssignmentService.php` | Add method getters for PermissionEngine |
| `source/BGERP/Service/TokenLifecycleService.php` | Add origin_type getter |
| `assets/javascripts/pwa_scan/token_card/TokenCardParts.js` | Use permissions from API |
| `assets/javascripts/pwa_scan/token_card/TokenCardState.js` | Remove canActOnToken(), use permissions |

---

## ✅ Acceptance Criteria

### Phase 1:
- [ ] PermissionEngine class created
- [ ] `can($action, $context)` works for start, pause, resume
- [ ] QC actions check node type + assignment + role
- [ ] **Assignment method integration** (manager, auto, pin, help)
- [ ] **Token type rules** (normal, split, replacement, rework)
- [ ] **QC node special rules** (self-pick, self-QC)
- [ ] All existing tests pass

### Phase 2:
- [ ] API returns `permissions` object with token data
- [ ] UI reads permissions from API response
- [ ] No permission logic in JS (all from server)
- [ ] **canActOnToken() removed from TokenCardState.js**

### Phase 3:
- [ ] routing_node has permission_config column
- [ ] QC nodes can be configured for self-QC
- [ ] Admin can edit node permission config

### Phase 4:
- [ ] UI only shows buttons user has permission for
- [ ] No hardcoded role checks in JS
- [ ] Clean, simple button rendering

---

## 🔗 Related Tasks

- Task 27.22: Token Card Component (blocked by permission logic)
- Task 27.22.1: Token Card Logic Issues (superseded by this)
- Task 27.21.1: Rework Material Reserve (needs permission checks)
- Task 27.20: Work Modal Behavior (needs permission-based UI)

---

## 🎯 Expected Outcome

**Before:**
- "ช่าง A เป็น Operator ทำ QC ไม่ได้"
- "ต้องเปลี่ยน Role เป็น QC ก่อน"
- "Logic permission กระจายใน JS/PHP 10+ ที่"

**After:**
- "ช่าง A ถูก assign ให้ทำ QC node → ทำ QC ได้"
- "QC Inspector ถูก assign ให้ทำ stitch → stitch ได้"
- "Permission logic รวมที่ PermissionEngine ที่เดียว"
- "UI แสดงเฉพาะปุ่มที่มีสิทธิ"

---

## 🚦 Risk Assessment

| Risk | Mitigation |
|------|------------|
| Break existing permission | Phase 1 = additive, ไม่ลบของเก่า |
| Performance (extra queries) | Cache role/assignment per request |
| Complex migration | ทำเป็น Phase, test ทีละ step |
| UI/API mismatch | API เป็น source of truth เดียว |

---

## 📊 Priority Matrix

| Feature | Impact | Effort | Priority |
|---------|--------|--------|----------|
| PermissionEngine class | High | Medium | P1 |
| API returns permissions | High | Low | P1 |
| UI uses API permissions | Medium | Low | P2 |
| Node permission config | Medium | Medium | P3 |

**Recommendation:** ทำ Phase 1-2 ก่อน (1.5 days) แล้ว deploy ดูผล

---

## 📜 AGENT GUIDELINE: Permission System Standards

> **สำหรับ AI Agent และ Developer ทุกคนที่แตะระบบ Permission**

### 1. Design Principles

| หลักการ | คำอธิบาย |
|---------|----------|
| **Permission = Authorization Boundary** | ใช้เช็คว่า "เข้าถึงได้หรือไม่" ไม่ใช่ business logic |
| **Single Point of Check** | เช็ค permission ที่ต้นไฟล์ API ที่เดียว ไม่กระจาย |
| **API Layer Only** | Permission checks ต้องอยู่ที่ API layer เท่านั้น ห้ามอยู่ใน Services |
| **Metadata First** | ทุก API ต้องมี `@permission` docblock |
| **Server as Source of Truth** | UI ไม่ตัดสินใจ permission เอง รอ API บอก |

---

### 2. Mandatory: @permission Docblock

**ทุกไฟล์ที่มี `must_allow_code()` ต้องมี `@permission` ด้านบน:**

```php
<?php
/**
 * Material Adjustment API
 *
 * @permission adjust.view, adjust.manage
 */
```

**กฎ:**
- ❌ ห้ามเพิ่ม permission code ใหม่ โดยไม่แตะ docblock
- ❌ ห้ามมี `must_allow_code()` โดยไม่มี `@permission`
- ✅ ทุก permission code ที่ใช้ต้องอยู่ใน docblock

---

### 3. Mandatory: ACTION_PERMISSIONS Pattern

**❌ อย่าทำแบบนี้ (Scattered checks):**
```php
switch ($action) {
    case 'list':
        must_allow_code($member, 'adjust.view');
        // ...
    case 'create':
        must_allow_code($member, 'adjust.manage');
        // ...
    case 'update':
        must_allow_code($member, 'adjust.manage');
        // ...
}
```

**✅ ให้ทำแบบนี้ (Centralized mapping):**
```php
const ACTION_PERMISSIONS = [
    // Single permission per action
    'list'   => 'adjust.view',
    'get'    => 'adjust.view',
    'create' => 'adjust.manage',
    'update' => 'adjust.manage',
    'delete' => 'adjust.manage',
    
    // OR logic: ต้องมีอันใดอันหนึ่ง (array)
    'type_list' => ['bom.view', 'products.view'],
    
    // AND logic: ต้องมีทั้งสองอัน (prefix +)
    'approve'   => ['qc.manage', '+production.manage'],
];

$action = $_REQUEST['action'] ?? '';
if (isset(ACTION_PERMISSIONS[$action])) {
    $perms = ACTION_PERMISSIONS[$action];
    
    if (is_array($perms)) {
        // Check OR/AND logic
        $hasAnd = false;
        $passed = false;
        
        foreach ($perms as $p) {
            if (str_starts_with($p, '+')) {
                $hasAnd = true;
                if (!permission_allow_code($member, substr($p, 1))) {
                    json_error('forbidden', 403);
                }
            } else {
                if (permission_allow_code($member, $p)) {
                    $passed = true;
                }
            }
        }
        
        if (!$hasAnd && !$passed) {
            json_error('forbidden', 403);
        }
    } else {
        must_allow_code($member, $perms);
    }
}

switch ($action) {
    // Now handle actions without permission checks inside
}
```

---

### 4. Permission Code Naming Convention

**รูปแบบมาตรฐาน:**
```
<domain>.<subdomain>.<action>
```

**กฎ:**
| กฎ | ตัวอย่าง |
|----|----------|
| lowercase ทั้งหมด | ✅ `dag.routing.manage` ❌ `DAG_SUPERVISOR_SESSIONS` |
| ใช้ dot (.) แยก level | ✅ `inventory.stock.view` ❌ `inventory_stock_view` |
| action อยู่ท้าย | ✅ `product.graph.pin_version` |
| underscore ใน action ได้ | ✅ `hatthasilpa.token.create_replacement` |

**ต้องแก้ไข (จาก Audit):**
| เดิม (ผิด) | ใหม่ (ถูก) |
|------------|-----------|
| `DAG_SUPERVISOR_SESSIONS` | `dag.supervisor.sessions` |
| `leather_grn.manage` | `leather.grn.manage` |
| `product_categories.view` | `product.categories.view` |
| `stock_on_hand.view` | `inventory.stock.on_hand.view` |
| `work_centers.view` | `work.center.view` |

---

### 5. Cross-Module Permission Rules

**❌ ห้ามใช้ permission ผิด domain:**

```php
// ❌ component.php ใช้ bom.view
if (!permission_allow_code($member, 'bom.view')) { }

// ✅ ต้องใช้ component.*
if (!permission_allow_code($member, 'component.catalog.view')) { }
```

```php
// ❌ assignment_api.php ใช้ dag.routing.manage สำหรับ log actions
case 'log_list':
    must_allow_code($member, 'dag.routing.manage');

// ✅ ต้องใช้ manager.assignment.*
case 'log_list':
    must_allow_code($member, 'manager.assignment.log.view');
```

**Domain mapping:**
| Feature | Domain |
|---------|--------|
| Graph/Routing design | `dag.routing.*` |
| Assignment management | `manager.assignment.*` |
| Component catalog | `component.catalog.*` |
| Inventory/Stock | `inventory.*` |
| QC operations | `qc.*` |
| Leather operations | `leather.*` |

---

### 6. Services: NO Permission Checks!

**❌ ห้ามเช็ค permission ใน Service:**
```php
class MaterialAllocationService {
    public function allocate($member, $data) {
        must_allow_code($member, 'inventory.allocate'); // ❌ ผิด!
        // ...
    }
}
```

**✅ เช็คที่ API layer เท่านั้น:**
```php
// source/material_api.php
must_allow_code($member, 'inventory.allocate');
$service->allocate($data); // Service ไม่รู้จัก $member หรือ permission
```

**เหตุผล:**
- Services ควร reusable โดยไม่ผูกกับ permission context
- Permission เป็น concern ของ API layer
- Testing Services ง่ายกว่า (ไม่ต้อง mock permission)

---

### 7. Permission Inheritance (Future)

**Planned hierarchy:**
```
*.manage → implies → *.view
admin.* → implies → all permissions under admin domain
owner   → bypasses → most permissions (except NON_BYPASSABLE)
```

**NON_BYPASSABLE permissions (แม้ owner ก็ต้องมี explicit grant):**
```php
const NON_BYPASSABLE = [
    'audit.log.delete',
    'finance.close_period',
    'system.backup.restore',
];
```

---

### 8. Migration Strategy for Rename

**เมื่อต้องเปลี่ยนชื่อ permission code ต้องทำ 4 ที่พร้อมกัน:**

1. **โค้ด PHP** - เปลี่ยนใน `must_allow_code()` และ `@permission`
2. **permission table** - UPDATE code ใน DB
3. **tenant_role_permission** - mappings ยังใช้ id เดิมได้
4. **seed_default_permissions.php** - อัปเดต reference file

**ใช้ Migration script:**
```php
// database/tenant_migrations/2025_12_rename_permission_codes.php
$renames = [
    'DAG_SUPERVISOR_SESSIONS' => 'dag.supervisor.sessions',
    'leather_grn.manage' => 'leather.grn.manage',
];

foreach ($renames as $old => $new) {
    $db->query("UPDATE permission SET code = '$new' WHERE code = '$old'");
}
```

---

### 9. What Agent MUST Do

| เมื่อ | ต้องทำ |
|------|--------|
| สร้าง API ใหม่ | ใส่ `@permission` + ใช้ `ACTION_PERMISSIONS` |
| แก้ไข API เดิม | ตรวจสอบว่ามี `@permission` ครบหรือยัง |
| เพิ่ม permission code ใหม่ | เพิ่มใน seed + migration + docblock |
| เปลี่ยนชื่อ permission | ทำ migration 4 ที่พร้อมกัน |
| แตะไฟล์ที่มี 10+ checks | Refactor เป็น ACTION_PERMISSIONS |

---

### 10. What Agent MUST NOT Do

| ห้าม | เหตุผล |
|------|--------|
| ลบ `must_allow_code()` โดยไม่มี replacement | จะทำให้ API เปิดโล่ง |
| เปลี่ยน permission code โดยไม่แตะ seed/migration | จะทำให้ permission หาย |
| เพิ่ม permission code โดยไม่ระบุใน `@permission` | จะ audit ไม่ได้ |
| สร้าง pattern ใหม่ เช่น `if (!is_admin())` | ต้องใช้ `must_allow_code()` เท่านั้น |
| เช็ค permission ใน Service class | ต้องเช็คที่ API layer |
| ใช้ permission ผิด domain | เช่น `bom.view` ใน component API |

---

### 11. API Template (ใช้เป็น Starting Point)

```php
<?php
/**
 * [Module Name] API
 *
 * @package Bellavier Group ERP
 * @permission [module].view, [module].manage
 */

require_once __DIR__ . '/init.php';

// ============================================================
// PERMISSION MAPPING (Single Source of Truth)
// ============================================================
const ACTION_PERMISSIONS = [
    'list'   => '[module].view',
    'get'    => '[module].view',
    'create' => '[module].manage',
    'update' => '[module].manage',
    'delete' => '[module].manage',
];

// ============================================================
// PERMISSION CHECK (Single Point)
// ============================================================
$action = $_REQUEST['action'] ?? '';

if (isset(ACTION_PERMISSIONS[$action])) {
    must_allow_code($member, ACTION_PERMISSIONS[$action]);
}

// ============================================================
// ACTION HANDLER
// ============================================================
switch ($action) {
    case 'list':
        handleList();
        break;
        
    case 'get':
        handleGet();
        break;
        
    case 'create':
        handleCreate();
        break;
        
    case 'update':
        handleUpdate();
        break;
        
    case 'delete':
        handleDelete();
        break;
        
    default:
        json_error('invalid_action', 400);
}

// ============================================================
// HANDLERS (No permission checks inside!)
// ============================================================
function handleList() {
    // ... implementation
}

function handleGet() {
    // ... implementation
}

function handleCreate() {
    // ... implementation
}

function handleUpdate() {
    // ... implementation
}

function handleDelete() {
    // ... implementation
}
```

---

### 12. Phased Refactor Plan

| Phase | งาน | Files | Effort | Status |
|-------|-----|-------|--------|--------|
| **P0** | เพิ่ม `@permission` ให้ 11 ไฟล์ที่ขาด | 9 files | 1 hour | ✅ DONE |
| **P1** | สร้าง PermissionEngine + API Response Enhancement | 2 files | 4 hours | ✅ DONE |
| **P2** | Refactor Top 5 files ที่มี 20+ checks | 5 files | 4 hours | ✅ DONE |
| **P3** | Rename permission codes (migration) | 1 migration | 2 hours | ✅ DONE |
| **P4** | Refactor remaining files with scattered checks | 7 files | 3 hours | ✅ DONE |
| **P4** | Refactor remaining files | 15 files | 8 hours | 🔜 TODO |
| **P5** | Node permission config | DB + Admin UI | 4 hours | ⏸️ **DEFERRED → FUTURE ENHANCEMENT** |

**Total: ~21 hours (3 days)**

### 12.1 Phase 0 Completion Log (2025-12-08)

Added `@permission` docblock to 9 API files:
- `admin_feature_flags_api.php` - platform.*, admin.*, org.* permissions
- `component_allocation.php` - component.binding.view, component.binding.bind
- `component_binding.php` - component.binding.bind, component.binding.unbind, component.binding.view
- `component_serial.php` - component.serial.generate, component.serial.view
- `dag_approval_api.php` - hatthasilpa.job.manage
- `job_ticket_dag.php` - hatthasilpa.job.ticket
- `mo_assist_api.php` - mo.create
- `mo_eta_api.php` - mo.view
- `mo_load_simulation_api.php` - mo.view

**Remaining 2 files not fixed (N/A):**
- `source/BGERP/Bootstrap/CoreApiBootstrap.php` - Bootstrap class (dynamic permissions)
- `source/permission.php` - Helper file (defines permission functions)

### 12.2 Phase 2 Completion Log (2025-12-08)

Refactored Top 5 files with excessive permission checks (20+ each):

| File | Before | After | Reduction |
|------|--------|-------|-----------|
| `job_ticket.php` | 34 | 1 | -33 (97%) |
| `team_api.php` | 23 | 1 | -22 (96%) |
| `token_management_api.php` | 22 | 1 | -21 (95%) |
| `product_api.php` | 21 | 1 | -20 (95%) |
| `trace_api.php` | 20 | 1 | -19 (95%) |
| **Total** | **120** | **5** | **-115 (96%)** |

**Pattern Applied:**
- Created `ACTION_PERMISSIONS` constant at file top
- Single `must_allow_code()` check before switch statement
- Removed all duplicate permission checks inside switch cases/handlers
- Kept `@permission` docblock for documentation

### 12.3 Phase 3 Completion Log (2025-12-08)

Renamed 8 permission codes to follow naming convention:

| Old Code | New Code | Files Changed |
|----------|----------|---------------|
| `DAG_SUPERVISOR_SESSIONS` | `dag.supervisor.sessions` | 1 |
| `leather_grn.manage` | `leather.grn.manage` | 1 |
| `product_categories.view` | `product.categories.view` | 1 |
| `product_categories.manage` | `product.categories.manage` | 1 |
| `stock_card.view` | `inventory.stock.card.view` | 1 |
| `stock_on_hand.view` | `inventory.stock.on_hand.view` | 1 |
| `work_centers.view` | `work.centers.view` | 2 |
| `work_centers.manage` | `work.centers.manage` | 1 |

**Files Updated:**
- `source/dag_supervisor_sessions.php`
- `source/leather_grn.php`
- `source/product_categories.php`
- `source/stock_card.php`
- `source/stock_on_hand.php`
- `source/work_centers.php`
- `source/routing.php`
- `database/seed_default_permissions.php`
- `database/tenant_migrations/0002_seed_data.php`

**Migration Created:**
- `database/tenant_migrations/2025_12_rename_permission_codes.php`

### 12.4 Phase 4 Completion Log (2025-12-08)

Refactored 7 additional files to use `ACTION_PERMISSIONS` pattern:

| File | Before | After | Reduction |
|------|--------|-------|-----------|
| `mo.php` | 15 | 3* | -12 (80%) |
| `hatthasilpa_jobs_api.php` | 15 | 1 | -14 (93%) |
| `hatthasilpa_schedule.php` | 12 | 1 | -11 (92%) |
| `assignment_plan_api.php` | 12 | 1 | -11 (92%) |
| `assignment_api.php` | 12 | 1 | -11 (92%) |
| `materials.php` | 11 | 1 | -10 (91%) |
| `routing.php` | 10 | 1 | -9 (90%) |
| **Total** | **87** | **9** | **-78 (90%)** |

*mo.php has 2 special case checks that must remain (conditional permission + OR logic)

**Files Skipped (complex permission logic):**
- `admin_org.php` - Uses permission flags for UI authorization
- `dag_routing_api.php` - Uses fallback + OR permission patterns

---

### 13. Permission Sync CLI Tool (Planned)

```bash
# Check diff between @permission docblocks and database
php tools/permission_sync.php --check

# Output:
# ✅ 74 files have @permission
# ❌ 11 files missing @permission
# 🔴 35 codes in code but not in DB
# 🟡 40 codes in DB but not in code

# Generate migration for missing permissions
php tools/permission_sync.php --migrate

# Output:
# Created: database/tenant_migrations/2025_12_sync_permissions.php
```

---

## 🔗 Related Audit Documents

- [Permission System Audit](../00-audit/20251208_PERMISSION_SYSTEM_AUDIT.md) - 451 permission checks ใน code
- [Roles & Permissions Database Audit](../00-audit/20251208_ROLES_PERMISSIONS_DATABASE_AUDIT.md) - Roles/Permissions ใน seed/DB
- [RBAC System Architecture Audit](../00-audit/20251208_RBAC_SYSTEM_ARCHITECTURE_AUDIT.md) - โครงสร้าง Platform/Tenant RBAC ✅ NEW

