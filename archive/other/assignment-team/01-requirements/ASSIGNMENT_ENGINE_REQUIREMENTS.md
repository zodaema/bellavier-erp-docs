# Assignment Engine - Requirements & Design

**Created:** November 5, 2025 21:30 ICT  
**Status:** Planned for Week 3 (Optional Enhancement)  
**Prerequisites:** Core Work Queue System (✅ Complete at 98/100)  
**Estimated Time:** 2-3 days implementation

---

## 🎯 **Purpose**

Auto-assign operators to tokens based on skills, availability, and workload balancing.

**Current State:** Manual assignment by manager (node pre-assignment) - Works well! ✅  
**Future State:** Auto-assignment with fallback to manual override

---

## ✅ **What's Ready (Foundation Complete)**

### **Runtime Layer (100% Ready):**
- ✅ Token lifecycle hardened (atomic transactions)
- ✅ Work Queue operational (race-free)
- ✅ `token_assignment` table exists (assigned_to_user_id, status, replaced_from)
- ✅ Transaction safety (FOR UPDATE locks)
- ✅ Unique constraints ready (can prevent duplicate assignments)
- ✅ Integration points identified (spawn + route)
- ✅ Invariant compliance (all endpoints follow rules)

**Assessment:** Runtime foundation is SOLID and ready for Assignment Engine ✅

---

## ❌ **What's Missing (Data Layer)**

### **Critical Missing Components:**

**1. Operator Skills Table** 🔴 REQUIRED
```sql
CREATE TABLE operator_skill (
    id_member INT NOT NULL,
    skill_code VARCHAR(64) NOT NULL,
    level TINYINT NOT NULL DEFAULT 1 COMMENT '1=Basic, 2=Intermediate, 3=Advanced, 4=Expert',
    certified_at DATE NULL COMMENT 'Certification date (if applicable)',
    notes VARCHAR(255),
    PRIMARY KEY (id_member, skill_code),
    KEY idx_skill (skill_code, level),
    KEY idx_member (id_member)
);
```

**Purpose:** Track what skills each operator has  
**Without this:** Can't do skill matching, assignment becomes random

---

**2. Node Skill Requirements Table** 🔴 REQUIRED
```sql
CREATE TABLE node_required_skill (
    id_node INT NOT NULL,
    skill_code VARCHAR(64) NOT NULL,
    min_level TINYINT NOT NULL DEFAULT 1 COMMENT 'Minimum skill level required',
    is_required BOOLEAN DEFAULT 1 COMMENT 'Hard requirement vs nice-to-have',
    PRIMARY KEY (id_node, skill_code),
    KEY idx_node (id_node),
    FOREIGN KEY (id_node) REFERENCES routing_node(id_node) ON DELETE CASCADE
);
```

**Purpose:** Define what skills each node/work station needs  
**Without this:** Can't filter eligible operators, assignment becomes random

---

**3. Operator Availability Table** 🟡 RECOMMENDED
```sql
CREATE TABLE operator_availability (
    id_member INT NOT NULL PRIMARY KEY,
    is_active BOOLEAN NOT NULL DEFAULT 1 COMMENT 'Currently accepting new assignments',
    daily_capacity_tokens INT NULL COMMENT 'Max tokens per day (optional)',
    weekly_hours DECIMAL(5,2) NULL COMMENT 'Available hours per week (optional)',
    notes VARCHAR(255),
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_active (is_active)
);
```

**Purpose:** Track operator availability and capacity  
**Without this:** Can't exclude inactive/busy operators, risk overloading

---

**4. Assignment Log Table** 🟡 RECOMMENDED (Audit Trail)
```sql
CREATE TABLE assignment_log (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_token INT NOT NULL,
    id_node INT NOT NULL,
    assigned_to INT NULL COMMENT 'Selected operator (NULL if no candidate)',
    picked_by ENUM('auto','manual') NOT NULL,
    strategy VARCHAR(50) COMMENT 'skill_match, load_balance, round_robin, etc.',
    candidate_count INT COMMENT 'How many operators were eligible',
    load_snapshot JSON COMMENT 'Workload of all candidates at assignment time',
    reason VARCHAR(255) COMMENT 'Why this operator was chosen OR why no candidate',
    assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_token (id_token),
    KEY idx_assigned_to (assigned_to, assigned_at),
    KEY idx_picked_by (picked_by, assigned_at)
);
```

**Purpose:** Audit trail for auto-assignment decisions  
**Benefits:** Debug assignment logic, improve algorithms, compliance

---

**5. Assignment Rules Table** 🟢 OPTIONAL (Nice-to-have)
```sql
CREATE TABLE assignment_rule (
    id_rule INT AUTO_INCREMENT PRIMARY KEY,
    rule_name VARCHAR(200) NOT NULL,
    node_type VARCHAR(50) COMMENT 'Apply to specific node type (NULL = all)',
    strategy ENUM('fifo','round_robin','least_busy','skill_match') NOT NULL,
    priority INT DEFAULT 10 COMMENT 'Higher = applied first',
    active BOOLEAN DEFAULT 1,
    config JSON COMMENT 'Strategy-specific configuration',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_node_type (node_type, active, priority)
);
```

**Purpose:** Configurable assignment strategies  
**Without this:** Hard-coded strategy only (acceptable for MVP)

---

## 🔧 **Assignment Engine Service Design**

### **Core Methods:**

```php
<?php
/**
 * Assignment Engine Service
 * 
 * Auto-assigns operators to tokens based on:
 * - Skill matching (operator_skill vs node_required_skill)
 * - Workload balancing (active sessions + recent assignments)
 * - Availability (operator_availability.is_active)
 * 
 * Strategies:
 * 1. skill_match - Match required skills first
 * 2. load_balance - Distribute work evenly
 * 3. round_robin - Fair rotation
 * 4. fifo - First available operator
 */

namespace BGERP\Service;

class AssignmentEngineService
{
    private mysqli $db;
    
    public function __construct(mysqli $db) {
        $this->db = $db;
    }
    
    /**
     * Auto-assign tokens after spawn
     * 
     * Called from: handleTokenSpawn() WITHIN transaction
     * 
     * @param array $tokenIds Array of spawned token IDs
     * @param array $context Spawn context (instance_id, job_ticket_id, etc.)
     * @return array Assignment results
     */
    public function autoAssignOnSpawn(array $tokenIds, array $context): array
    {
        $results = [];
        foreach ($tokenIds as $tokenId) {
            $results[$tokenId] = $this->assignOne($tokenId, null, $context);
        }
        return $results;
    }
    
    /**
     * Auto-assign token after routing to new node
     * 
     * Called from: handleCompleteToken() WITHIN transaction
     * 
     * @param int $tokenId Token ID
     * @param int $nodeId New node ID
     * @param array $context Routing context
     * @return int|null Assigned operator ID or NULL
     */
    public function autoAssignOnRoute(int $tokenId, int $nodeId, array $context): ?int
    {
        return $this->assignOne($tokenId, $nodeId, $context);
    }
    
    /**
     * Assign single token to best operator
     * 
     * CRITICAL: Must be called WITHIN transaction with FOR UPDATE lock!
     * 
     * Algorithm:
     * 1. Lock token (FOR UPDATE)
     * 2. Check if already has open assignment → skip
     * 3. Find eligible operators (skill + availability)
     * 4. Pick by lowest load (active sessions + recent assignments)
     * 5. Create assignment record
     * 6. Log decision
     * 
     * @param int $tokenId Token ID
     * @param int|null $nodeId Node ID (NULL = use current_node_id)
     * @param array $context Assignment context
     * @return int|null Assigned operator ID or NULL if no candidate
     */
    private function assignOne(int $tokenId, ?int $nodeId, array $context): ?int
    {
        // 1. Lock token (serialize assignment)
        $lockStmt = $this->db->prepare("SELECT id_token FROM flow_token WHERE id_token = ? FOR UPDATE");
        if ($lockStmt) {
            $lockStmt->bind_param('i', $tokenId);
            $lockStmt->execute();
            $lockStmt->close();
        }
        
        // 2. Check if already has open assignment (idempotency!)
        $existing = db_fetch_one($this->db, "
            SELECT id_assignment 
            FROM token_assignment 
            WHERE id_token = ? 
              AND status IN ('assigned', 'accepted', 'started', 'paused')
            LIMIT 1
        ", [$tokenId]);
        
        if ($existing) {
            // Already assigned, no-op
            return null;
        }
        
        // 3. Resolve node ID if not provided
        if (!$nodeId) {
            $token = db_fetch_one($this->db, "
                SELECT current_node_id FROM flow_token WHERE id_token = ?
            ", [$tokenId]);
            $nodeId = (int)$token['current_node_id'];
        }
        
        // 4. Find eligible operators (skill + availability)
        $candidates = $this->findEligibleOperators($nodeId);
        
        if (empty($candidates)) {
            // No eligible operators!
            $this->logAssignment($tokenId, $nodeId, null, 'auto', 'no_candidate', 0, null, 'No operators with required skills');
            return null;
        }
        
        // 5. Pick by lowest load
        $picked = $this->pickByLowestLoad($candidates);
        
        if (!$picked) {
            // Shouldn't happen, but safety check
            return null;
        }
        
        // 6. Create assignment
        $stmt = $this->db->prepare("
            INSERT INTO token_assignment 
            (id_token, assigned_to_user_id, status, assigned_at, assigned_by_type)
            VALUES (?, ?, 'assigned', NOW(), 'auto')
        ");
        $stmt->bind_param('ii', $tokenId, $picked['id_member']);
        $stmt->execute();
        $stmt->close();
        
        // 7. Log decision
        $this->logAssignment(
            $tokenId, 
            $nodeId, 
            $picked['id_member'], 
            'auto', 
            'skill_match+load_balance', 
            count($candidates),
            $picked['load'],
            "Assigned to {$picked['name']} (load: {$picked['load']})"
        );
        
        return $picked['id_member'];
    }
    
    /**
     * Find eligible operators for node
     * 
     * Criteria:
     * 1. Has all required skills (node_required_skill)
     * 2. Skill level meets minimum (operator_skill.level >= min_level)
     * 3. Is active (operator_availability.is_active = 1)
     * 
     * @param int $nodeId Node ID
     * @return array Array of eligible operators with load info
     */
    private function findEligibleOperators(int $nodeId): array
    {
        // Get required skills for this node
        $requiredSkills = db_fetch_all($this->db, "
            SELECT skill_code, min_level, is_required
            FROM node_required_skill
            WHERE id_node = ?
        ", [$nodeId]);
        
        if (empty($requiredSkills)) {
            // No skill requirements → all active operators eligible
            return $this->getAllActiveOperators();
        }
        
        // Find operators with ALL required skills
        $skillCodes = array_column($requiredSkills, 'skill_code');
        $placeholders = implode(',', array_fill(0, count($skillCodes), '?'));
        
        $stmt = $this->db->prepare("
            SELECT 
                os.id_member,
                COUNT(DISTINCT os.skill_code) as matched_skills
            FROM operator_skill os
            JOIN node_required_skill nrs ON nrs.skill_code = os.skill_code 
                AND nrs.id_node = ?
                AND os.level >= nrs.min_level
            WHERE os.skill_code IN ($placeholders)
            GROUP BY os.id_member
            HAVING matched_skills = ?
        ");
        
        $types = 'i' . str_repeat('s', count($skillCodes)) . 'i';
        $params = array_merge([$nodeId], $skillCodes, [count($skillCodes)]);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
        $eligibleIds = array_column($result->fetch_all(MYSQLI_ASSOC), 'id_member');
        $stmt->close();
        
        if (empty($eligibleIds)) {
            return []; // No one has required skills
        }
        
        // Get operator details with availability check
        $placeholders = implode(',', array_fill(0, count($eligibleIds), '?'));
        $types = str_repeat('i', count($eligibleIds));
        
        $stmt = $this->db->prepare("
            SELECT 
                a.id_member,
                a.name,
                COALESCE(oa.is_active, 1) as is_active,
                COALESCE(oa.daily_capacity_tokens, 999) as daily_capacity
            FROM bgerp.account a
            LEFT JOIN operator_availability oa ON oa.id_member = a.id_member
            WHERE a.id_member IN ($placeholders)
              AND COALESCE(oa.is_active, 1) = 1
        ");
        $stmt->bind_param($types, ...$eligibleIds);
        $stmt->execute();
        $result = $stmt->get_result();
        $operators = $result->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        
        // Add current load for each operator
        foreach ($operators as &$op) {
            $op['load'] = $this->getOperatorLoad($op['id_member']);
        }
        
        return $operators;
    }
    
    /**
     * Get all active operators (when no skill requirements)
     */
    private function getAllActiveOperators(): array
    {
        $stmt = $this->db->query("
            SELECT 
                a.id_member,
                a.name,
                COALESCE(oa.is_active, 1) as is_active,
                COALESCE(oa.daily_capacity_tokens, 999) as daily_capacity
            FROM bgerp.account a
            LEFT JOIN operator_availability oa ON oa.id_member = a.id_member
            WHERE COALESCE(oa.is_active, 1) = 1
        ");
        
        $operators = $stmt->fetch_all(MYSQLI_ASSOC);
        
        foreach ($operators as &$op) {
            $op['load'] = $this->getOperatorLoad($op['id_member']);
        }
        
        return $operators;
    }
    
    /**
     * Pick operator with lowest load
     * 
     * Load calculation:
     * - Active sessions: weight = 1.0 (high priority)
     * - Recent assignments (24h): weight = 0.5 (medium priority)
     * 
     * @param array $candidates Array of eligible operators
     * @return array|null Selected operator or NULL
     */
    private function pickByLowestLoad(array $candidates): ?array
    {
        if (empty($candidates)) {
            return null;
        }
        
        // Sort by load (ascending)
        usort($candidates, fn($a, $b) => $a['load'] <=> $b['load']);
        
        // Return operator with lowest load
        return $candidates[0];
    }
    
    /**
     * Calculate operator current load
     * 
     * Formula: active_sessions * 1.0 + recent_assignments * 0.5
     * 
     * @param int $operatorId Operator ID
     * @return float Load score
     */
    private function getOperatorLoad(int $operatorId): float
    {
        // Active sessions (weight = 1.0)
        $active = db_fetch_one($this->db, "
            SELECT COUNT(*) as count
            FROM token_work_session
            WHERE operator_user_id = ?
              AND status = 'active'
        ", [$operatorId]);
        
        $activeCount = (int)($active['count'] ?? 0);
        
        // Recent assignments (24h, weight = 0.5)
        $recent = db_fetch_one($this->db, "
            SELECT COUNT(*) as count
            FROM token_assignment
            WHERE assigned_to_user_id = ?
              AND assigned_at >= NOW() - INTERVAL 24 HOUR
        ", [$operatorId]);
        
        $recentCount = (int)($recent['count'] ?? 0);
        
        // Calculate weighted load
        $load = ($activeCount * 1.0) + ($recentCount * 0.5);
        
        return $load;
    }
    
    /**
     * Log assignment decision (audit trail)
     */
    private function logAssignment(
        int $tokenId, 
        int $nodeId, 
        ?int $assignedTo, 
        string $pickedBy, 
        string $strategy, 
        int $candidateCount,
        $loadSnapshot,
        string $reason
    ): void
    {
        $stmt = $this->db->prepare("
            INSERT INTO assignment_log 
            (id_token, id_node, assigned_to, picked_by, strategy, candidate_count, load_snapshot, reason)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ");
        
        $loadJson = is_array($loadSnapshot) ? json_encode($loadSnapshot) : null;
        
        $stmt->bind_param('iiississ', 
            $tokenId, 
            $nodeId, 
            $assignedTo, 
            $pickedBy, 
            $strategy, 
            $candidateCount,
            $loadJson,
            $reason
        );
        $stmt->execute();
        $stmt->close();
    }
}
```

---

## 🔌 **Integration Points**

### **Hook 1: After Token Spawn**

**Location:** `source/dag_token_api.php` → `handleTokenSpawn()`

**Before (Current):**
```php
// Spawn tokens
$tokenIds = $tokenService->spawnTokens(...);

// Commit transaction
$db->commit();

json_success([...]);
```

**After (With Assignment Engine):**
```php
// Spawn tokens
$tokenIds = $tokenService->spawnTokens(...);

// ✅ AUTO-ASSIGN (WITHIN same transaction!)
require_once __DIR__ . '/service/AssignmentEngineService.php';
$assignmentEngine = new \BGERP\Service\AssignmentEngineService($db);
$assignmentResults = $assignmentEngine->autoAssignOnSpawn($tokenIds, [
    'instance_id' => $instanceId,
    'ticket_id' => $ticketId
]);

// Commit transaction (includes spawn + assign)
$db->commit();

json_success([
    'token_count' => count($tokenIds),
    'token_ids' => $tokenIds,
    'assignments' => $assignmentResults  // NEW!
]);
```

**Critical:** Must be WITHIN transaction (atomic spawn + assign)

---

### **Hook 2: After Token Routing**

**Location:** `source/dag_token_api.php` → `handleCompleteToken()`

**Before (Current):**
```php
// Auto-route to next node
$nextNodeId = $edges[0]['to_node'];
$tokenService->moveToken($tokenId, $nextNodeId, $operatorId, 'Auto-routed after completion');

$routingResult = [
    'routed' => true,
    'next_node_id' => $nextNodeId
];
```

**After (With Assignment Engine):**
```php
// Auto-route to next node
$nextNodeId = $edges[0]['to_node'];
$tokenService->moveToken($tokenId, $nextNodeId, $operatorId, 'Auto-routed after completion');

// ✅ AUTO-ASSIGN to new node (WITHIN same transaction!)
require_once __DIR__ . '/service/AssignmentEngineService.php';
$assignmentEngine = new \BGERP\Service\AssignmentEngineService($db);
$assignedTo = $assignmentEngine->autoAssignOnRoute($tokenId, $nextNodeId, [
    'previous_operator' => $operatorId
]);

$routingResult = [
    'routed' => true,
    'next_node_id' => $nextNodeId,
    'assigned_to' => $assignedTo  // NEW!
];
```

**Critical:** Must be WITHIN transaction (atomic route + assign)

---

## 🧪 **Testing Strategy**

### **Test 1: Basic Assignment (Skill Match)**
```
Scenario: Spawn 50 tokens → All should be assigned
Given: 3 operators with skills (Cutting, Sewing, QC)
Given: Node requires skill "Cutting" level 2
When: Spawn 50 tokens at "Cutting" node
Then: All 50 tokens assigned to operators with "Cutting" skill >= 2
And: No duplicate assignments (unique constraint prevents)
```

### **Test 2: Load Balancing**
```
Scenario: Distribute work evenly
Given: 3 operators (A, B, C) all have required skill
Given: A has 2 active sessions, B has 0, C has 1
When: Spawn 10 new tokens
Then: B gets most assignments (lowest load)
And: Final distribution is balanced (~3-4 each)
```

### **Test 3: No Candidate Fallback**
```
Scenario: No one has required skill
Given: Node requires "Embroidery" level 3
Given: No operators have "Embroidery" skill
When: Spawn tokens
Then: No assignments created (assignment = NULL)
And: assignment_log shows "no_candidate" reason
And: Manager sees unassigned tokens in Manager Assignment page
```

### **Test 4: Availability Check**
```
Scenario: Skip inactive operators
Given: Operator A is_active = 0 (on leave)
Given: Operator B is_active = 1
When: Spawn tokens
Then: Only B gets assignments, A is skipped
```

### **Test 5: Race Condition Prevention**
```
Scenario: Concurrent spawn calls
Given: 2 managers spawn same job simultaneously (edge case)
When: Both create tokens for same job
Then: Each token assigned only ONCE (unique constraint prevents duplicates)
And: FOR UPDATE lock serializes assignment operations
```

---

## ⚠️ **Critical Safety Requirements**

### **1. Transaction Atomicity** 🔴 MUST HAVE
- Assignment MUST be within spawn/route transaction
- Rollback spawn/route if assignment fails critically
- Never create orphan tokens without assignment capability

### **2. Idempotency** 🔴 MUST HAVE
- Always check existing open assignment before creating new one
- `assignOne()` safe to call multiple times (no duplicates)
- Unique constraint enforces at database level

### **3. Lock Serialization** 🔴 MUST HAVE
- FOR UPDATE lock on token before assignment
- Prevents 2 concurrent assignments to same token
- Already implemented in current system ✅

### **4. Fallback Handling** 🟡 SHOULD HAVE
- If no candidates → log and allow manual assignment
- If assignment fails → don't break spawn/route
- Manager notification for unassigned tokens

### **5. Audit Trail** 🟡 SHOULD HAVE
- Log all assignment decisions (auto vs manual)
- Log candidate count and selection reason
- Load snapshot for future analysis

---

## 📋 **Implementation Checklist (Week 3)**

### **Day 1: Database Schema (4-6 hours)**
- [ ] Create migration `2025_11_assignment_engine_foundation.php`
- [ ] Add tables: operator_skill, node_required_skill, operator_availability, assignment_log
- [ ] Add indexes for performance
- [ ] Add sample data (5 operators, 10 skills, 5 nodes)
- [ ] Test migration on local DB
- [ ] Verify constraints work (unique assignment per token)

### **Day 2: AssignmentEngine Service (6-8 hours)**
- [ ] Create `source/service/AssignmentEngineService.php`
- [ ] Implement `autoAssignOnSpawn()`
- [ ] Implement `autoAssignOnRoute()`
- [ ] Implement `assignOne()` (core algorithm)
- [ ] Implement `findEligibleOperators()` (skill matching)
- [ ] Implement `pickByLowestLoad()` (load balancing)
- [ ] Implement `getOperatorLoad()` (metric calculation)
- [ ] Implement `logAssignment()` (audit trail)
- [ ] Write unit tests (8-10 tests)
- [ ] Test locally

### **Day 3: Integration + Manager UI (4-6 hours)**
- [ ] Add hook in `handleTokenSpawn()` (within transaction)
- [ ] Add hook in `handleCompleteToken()` (within transaction)
- [ ] Create operator skills management page (simple CRUD)
- [ ] Create node skill requirements UI (in graph designer or separate)
- [ ] Add "Auto-assign" toggle in Manager Assignment
- [ ] Browser E2E testing (5 scenarios above)
- [ ] Performance testing (100+ tokens)
- [ ] Fix any bugs found

---

## 🎯 **Success Criteria**

**Assignment Engine is successful if:**
- ✅ 95%+ of spawned tokens auto-assigned correctly
- ✅ No duplicate assignments (unique constraint works)
- ✅ Load balanced within 20% variance (fair distribution)
- ✅ Skill matching 100% accurate (no wrong assignments)
- ✅ Fallback to manual works smoothly (no blocking)
- ✅ Performance: < 50ms per assignment
- ✅ Zero race conditions (FOR UPDATE locks work)
- ✅ Manager can override auto-assignments easily

---

## 🚨 **Risks & Mitigations**

| Risk | Impact | Mitigation |
|------|--------|------------|
| **No skill data** | Random assignment | Seed sample data, allow NULL requirements |
| **Race conditions** | Duplicate assignments | FOR UPDATE + unique index (already have!) |
| **Slow performance** | Delays spawn/route | Optimize queries, add indexes, cache metrics |
| **Wrong assignments** | Operator frustration | Comprehensive testing, manual override UI |
| **Transaction rollback** | No tokens spawned | Make assignment non-blocking (log + continue) |

---

## 💡 **Simplified MVP Approach (Recommended)**

**If you want to start simple:**

**Phase 1: Round-Robin Only (1 day)**
- No skill matching
- No availability check
- Just rotate through all operators
- Can implement in 4 hours!

**Phase 2: Add Skill Matching (1 day)**
- Add operator_skill + node_required_skill tables
- Filter candidates by skill
- Still use round-robin for selection

**Phase 3: Add Load Balancing (1 day)**
- Calculate operator load
- Pick by lowest load
- Complete Assignment Engine!

---

## 📚 **Reference**

**Dependencies:**
- `TokenLifecycleService` - For token operations
- `DAGRoutingService` - For routing operations
- `TokenWorkSessionService` - For load calculation (active sessions)

**Related Documents:**
- `STATUS.md` - Current system status (98/100)
- `ROADMAP_V4.md` - Week 3 plan (optional)
- `docs/DATABASE_SCHEMA_REFERENCE.md` - Schema reference
- `source/dag_token_api.php` - Integration points (spawn + route)

**Testing:**
- Test spawn with auto-assign
- Test route with auto-assign
- Test no candidate fallback
- Test load balancing
- Test race conditions

---

## ✅ **Ready to Implement?**

**Prerequisites Checklist:**
- [x] Core Work Queue tested and stable (98/100)
- [ ] Database schema designed (operator_skill, node_required_skill, etc.)
- [ ] Migration file created
- [ ] AssignmentEngineService designed
- [ ] Integration points identified (spawn + route)
- [ ] Testing strategy defined

**Status:** ⏳ **Conditional Go** - Deploy core system first, test, then decide!

**Recommendation:** 
1. ✅ Deploy production hardening migrations NOW
2. ✅ Browser E2E testing (1-2 days)
3. ✅ Production trial (3-5 days)
4. 🤔 **Then evaluate:** Is manual assignment a bottleneck?
   - **If YES:** Implement Assignment Engine (2-3 days)
   - **If NO:** Skip and focus on other priorities

**Decision Point:** After production trial, we'll know if Assignment Engine is truly needed!

---

**Document Status:** ✅ Assignment Engine requirements documented  
**Next:** Deploy current system → Test → Evaluate need for auto-assignment

