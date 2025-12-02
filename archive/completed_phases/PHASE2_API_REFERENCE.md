# Phase 2: Team Integration - API Reference

**Version:** 1.1  
**Date:** November 7, 2025  
**Updates:** Added Operator Directory Service endpoints with meta response support

---

## 📡 **Endpoints**

### **1. Team Workload Summary**

**Endpoint:** `GET /source/team_api.php?action=workload_summary`

**Purpose:** Get real-time workload for a specific team

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `team_id` | int | ✅ Yes | Team ID |
| `production_type` | string | No | `oem` or `hatthasilpa` (default: `hatthasilpa`) |

**Response:**
```json
{
  "ok": true,
  "workload": {
    "team_id": 1,
    "team_name": "Sewing A",
    "team_code": "TEAM-SEW-A",
    "production_mode": "hybrid",
    "members": [
      {
        "id_member": 42,
        "name": "สมชาย",
        "role": "member",
        "sort_priority": 10,
        "capacity_per_day": 8.00,
        "current_load": 2,
        "current_load_hours": null,
        "is_available": true,
        "unavailable_reason": null,
        "unavailable_until": null,
        "score": 0.200
      }
    ],
    "available_count": 3,
    "total_count": 5,
    "load_balancing_mode": "least_loaded"
  }
}
```

**Error Responses:**
- `400` - Missing `team_id`
- `400` - Invalid `production_type`
- `500` - Team not found or no members

---

### **2. Batch Workload Summary**

**Endpoint:** `GET /source/team_api.php?action=workload_summary_all`

**Purpose:** Get workload for all active teams (optimized batch API)

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `production_type` | string | No | Filter by production type (default: `hatthasilpa`) |

**Response:**
```json
{
  "ok": true,
  "workloads": [
    {
      "team_id": 1,
      "team_code": "TEAM-SEW-A",
      "team_name": "Sewing A",
      "available_count": 3,
      "total_count": 5,
      "avg_load": 1.8
    },
    {
      "team_id": 2,
      "team_code": "TEAM-CUT-B",
      "team_name": "Cutting B",
      "available_count": 0,
      "total_count": 4,
      "avg_load": 4.2
    }
  ]
}
```

**Use Case:** Dashboard widgets, real-time monitoring

---

### **3. Member Current Work**

**Endpoint:** `GET /source/team_api.php?action=current_work`

**Purpose:** Get active tokens/jobs for a specific member

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id_member` | int | ✅ Yes | Member ID |

**Response:**
```json
{
  "ok": true,
  "member": {
    "name": "สมชาย",
    "username": "somchai"
  },
  "tokens": [
    {
      "id_token": 123,
      "assignment_status": "started",
      "assigned_at": "2025-11-06 10:30:00",
      "started_at": "2025-11-06 10:45:00",
      "token_status": "in_progress",
      "quantity": 50,
      "job_code": "JOB-2025-1106-001",
      "production_type": "hatthasilpa",
      "node_name": "Sewing",
      "operation_name": "Flat-bed sewing",
      "id_node_instance": 456
    }
  ],
  "count": 1
}
```

---

### **4. Assignment History**

**Endpoint:** `GET /source/team_api.php?action=assignment_history`

**Purpose:** Get audit trail of team assignments with pagination

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `team_id` | int | No | Filter by team |
| `job_code` | string | No | Filter by job |
| `page` | int | No | Page number (default: 1) |
| `size` | int | No | Page size (default: 50, max: 100) |

**Response:**
```json
{
  "ok": true,
  "logs": [
    {
      "id_log": 789,
      "id_token": 123,
      "job_code": "JOB-2025-1106-001",
      "node_name": "Sewing",
      "assignment_type": "auto_team",
      "assigned_to_user_id": 42,
      "assigned_to_username": "somchai",
      "assigned_to_team_id": 1,
      "assigned_to_team_name": "Sewing A",
      "decision_reason": "Lowest load: 2 tokens (mode: least-loaded, 3 available)",
      "decided_at": "2025-11-06 10:30:00"
    }
  ],
  "pagination": {
    "page": 1,
    "size": 50,
    "total": 150,
    "pages": 3
  }
}
```

---

### **5. Assignment Preview**

**Endpoint:** `GET /source/team_api.php?action=assignment_preview`

**Purpose:** Preview who would be assigned before actually assigning

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `team_id` | int | ✅ Yes | Team ID |
| `production_type` | string | No | Production type (default: `hatthasilpa`) |

**Response:**
```json
{
  "ok": true,
  "top_candidate": {
    "id_member": 42,
    "name": "สมชาย",
    "current_load": 2,
    "score": 0.200,
    "is_available": true
  },
  "alternatives": [
    {
      "id_member": 43,
      "name": "สมหญิง",
      "current_load": 3,
      "score": 0.300,
      "is_available": true
    }
  ],
  "team_name": "Sewing A",
  "available_count": 3
}
```

**Use Case:** Show confirmation dialog before assigning

---

### **6. Assign Tokens (Team-Based)**

**Endpoint:** `POST /source/assignment_api.php?action=assign_tokens`

**Purpose:** Assign tokens to a team (auto-select member) or individual

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `token_ids` | array | ✅ Yes | Array of token IDs |
| `team_id` | int | ⚖️ Either | Team ID (for auto-assignment) |
| `operator_id` | int | ⚖️ Either | Operator ID (for manual) |
| `notes` | string | No | Assignment notes |
| `priority` | string | No | `normal`, `high`, `urgent` (default: `normal`) |

**Note:** Must provide **either** `team_id` OR `operator_id`, not both.

**Request (Team Assignment):**
```json
{
  "action": "assign_tokens",
  "token_ids": [123, 124, 125],
  "team_id": 1,
  "notes": "Urgent batch",
  "priority": "high"
}
```

**Request (Manual Assignment):**
```json
{
  "action": "assign_tokens",
  "token_ids": [123],
  "operator_id": 42,
  "notes": "Special task"
}
```

**Response:**
```json
{
  "ok": true,
  "assigned": 3,
  "total": 3,
  "errors": [],
  "message": "Assigned 3 tokens to Sewing A"
}
```

**Error Responses:**
- `400` - No tokens selected
- `400` - Must provide either `operator_id` or `team_id`
- `400` - Invalid `team_id` or `operator_id`
- `500` - No available members in team

---

## 🔐 **Authentication & Permissions**

All endpoints require:
- Active session (`$_SESSION`)
- Organization context (`resolve_current_org()`)
- Appropriate permission code

**Required Permissions:**
| Endpoint | Permission Code |
|----------|----------------|
| `workload_summary` | `manager.team` |
| `workload_summary_all` | `manager.team` |
| `current_work` | `manager.team` |
| `assignment_history` | `manager.team` |
| `assignment_preview` | `manager.assignment` |
| `assign_tokens` | `hatthasilpa.job.assign` |

---

## 📊 **Data Models**

### **Team Member Object**

```typescript
{
  id_member: number;
  name: string;
  role: 'lead' | 'supervisor' | 'qc' | 'member' | 'trainee';
  sort_priority: number;  // 0-100, lower = higher priority
  capacity_per_day: number;  // Hours
  current_load: number;  // Active token count
  current_load_hours?: number;  // Estimated hours (if calculated)
  is_available: boolean;
  unavailable_reason?: string;
  unavailable_until?: string;  // ISO 8601 datetime
  score: number;  // Lower is better
}
```

### **Assignment Decision Log**

```typescript
{
  id_log: number;
  id_token: number;
  job_code: string;
  node_name: string;
  assignment_type: 'manual' | 'auto_plan' | 'auto_team';
  assigned_to_user_id: number;
  assigned_to_username: string;
  assigned_to_team_id?: number;
  assigned_to_team_name?: string;
  decision_reason: string;
  alternatives_considered?: string;  // JSON
  decided_at: string;  // YYYY-MM-DD HH:MM:SS
}
```

---

## 🧪 **Testing**

### **cURL Examples**

#### **1. Get Team Workload**
```bash
curl -X GET "http://localhost/source/team_api.php?action=workload_summary&team_id=1" \
  --cookie "PHPSESSID=your_session_id"
```

#### **2. Assign Tokens to Team**
```bash
curl -X POST "http://localhost/source/assignment_api.php" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --cookie "PHPSESSID=your_session_id" \
  --data "action=assign_tokens&token_ids[]=123&token_ids[]=124&team_id=1"
```

#### **3. Preview Assignment**
```bash
curl -X GET "http://localhost/source/team_api.php?action=assignment_preview&team_id=1" \
  --cookie "PHPSESSID=your_session_id"
```

---

## 📈 **Rate Limits & Performance**

**Recommendations:**
- **Polling:** Limit to every 30 seconds for workload updates
- **Batch API:** Use `workload_summary_all` instead of multiple `workload_summary` calls
- **Pagination:** Keep assignment history page size ≤ 100

**Query Performance:**
- Workload calculation: < 100ms per team
- Assignment preview: < 150ms
- Batch workload (10 teams): < 300ms

---

## 🔄 **Changelog**

### **v1.0 (2025-11-06)**
- Initial release with 6 endpoints
- Team-based assignment support
- Real-time workload monitoring
- Complete audit trail

---

### **9. Operator Directory - Users for Assignment**

**Endpoint:** `POST /source/hatthasilpa_job_ticket.php?action=users_for_assignment`

**Purpose:** Get list of operator-capable users for job assignment (with meta response)

**Parameters:** None

**Response:**
```json
{
  "ok": true,
  "users": [
    {
      "id_member": 42,
      "username": "operator01",
      "display_name": "สมชาย",
      "email": "somchai@example.com",
      "role_code": "production_operator",
      "source": "tenant_role",
      "resolved_via": "tenant_role"
    }
  ],
  "meta": {
    "count": 1,
    "hint_code": null,
    "hint_detail": null,
    "resolved_via": "tenant_role",
    "sources": ["tenant_role"],
    "options": {
      "include_supervisors": false,
      "mask_usernames": false,
      "allow_team_members_as_operator": false
    }
  }
}
```

**Meta Fields:**
- `hint_code`: Warning/info code (`NO_OPERATOR_ROLE`, `FALLBACK_IN_USE`, `FALLBACK_DISABLED`, or `null`)
- `hint_detail`: Thai message explaining the hint (for UI display)
- `resolved_via`: Source used (`tenant_role`, `account_group_fallback`, `team_member_fallback`, or `none`)
- `sources`: Array of all sources checked
- `options`: Configuration options used for this query

**Hint Codes:**
- `NO_OPERATOR_ROLE`: No operators found (need to configure tenant roles)
- `FALLBACK_IN_USE`: Using fallback from account_group or team_member (temporary)
- `FALLBACK_DISABLED`: Fallback disabled due to TTL expiration

---

### **10. Operator Directory - People Monitor**

**Endpoint:** `GET /source/team_api.php?action=people_monitor_list`

**Purpose:** Get real-time operator status for People Monitor dashboard

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `team_id` | int | No | Filter by team |
| `status` | string | No | Filter by status (`available`, `busy`, `offline`) |
| `q` | string | No | Search by name or username |
| `include_supervisors` | string | No | `"1"` or `"0"` (default: from config) |

**Response:**
```json
{
  "ok": true,
  "data": [
    {
      "id_member": 42,
      "name": "สมชาย",
      "username": "op****01",
      "status": "available",
      "team_name": "Sewing A",
      "current_work": null,
      "workload": 0
    }
  ],
  "count": 1,
  "server_time": "2025-11-07 13:00:00",
  "meta": {
    "count": 1,
    "hint_code": null,
    "hint_detail": null,
    "resolved_via": "tenant_role",
    "sources": ["tenant_role"],
    "options": {
      "include_supervisors": true,
      "mask_usernames": true,
      "allow_team_members_as_operator": false
    }
  }
}
```

**Features:**
- PDPA-compliant username masking (e.g., `op****01`)
- Real-time status updates
- Configurable supervisor inclusion
- Meta hints for zero-result troubleshooting

---

### **11. Operator Directory - Available Operators**

**Endpoint:** `GET /source/team_api.php?action=available_operators`

**Purpose:** Get list of available operators for assignment (Team Management context)

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `team_id` | int | No | Filter by team |

**Response:**
```json
{
  "ok": true,
  "operators": [
    {
      "id_member": 42,
      "name": "สมชาย",
      "username": "operator01",
      "current_team": "Sewing A",
      "is_available": true
    }
  ],
  "meta": {
    "count": 1,
    "hint_code": null,
    "hint_detail": null,
    "resolved_via": "tenant_role",
    "sources": ["tenant_role"],
    "options": {
      "include_supervisors": false,
      "mask_usernames": false,
      "allow_team_members_as_operator": false
    }
  }
}
```

---

## 📊 **Operator Directory Service - Meta Response Reference**

### **Purpose:**
Meta response provides context about operator resolution, helping frontend:
1. Display zero-result hints to users
2. Warn about fallback usage
3. Show data source transparency
4. Debug configuration issues

### **Meta Structure:**
```typescript
{
  count: number;                    // Number of operators found
  hint_code: string | null;         // Warning/info code
  hint_detail: string | null;       // Thai message for UI
  resolved_via: string;             // Primary source used
  sources: string[];                // All sources checked
  options: {
    include_supervisors: boolean;
    mask_usernames: boolean;
    allow_team_members_as_operator: boolean;
  };
}
```

### **Hint Codes & Recommended Actions:**

| Hint Code | Meaning | Recommended UI Action |
|-----------|---------|----------------------|
| `NO_OPERATOR_ROLE` | No operators found | Show alert banner: "ไม่พบผู้ปฏิบัติงานที่มีบทบาท Operator ในองค์กรนี้ โปรดตรวจสอบการตั้งค่า role" |
| `FALLBACK_IN_USE` | Using fallback (team_member or account_group) | Show info banner: "ระบบกำลังใช้ fallback รายชื่อจากทีม/กลุ่ม โปรดอัปเดต tenant role ให้ครบถ้วน (เหลือ X วัน)" |
| `FALLBACK_DISABLED` | Fallback disabled (TTL expired) | Show warning banner: "การใช้ fallback จาก team_member ถูกปิดอัตโนมัติเนื่องจากครบกำหนด TTL" |
| `null` | Normal operation | No banner needed |

### **Source Priority:**
1. `tenant_role` (primary, recommended)
2. `account_group_fallback` (legacy, temporary)
3. `team_member_fallback` (emergency, TTL-limited)
4. `none` (no operators found)

---

**End of API Reference**

