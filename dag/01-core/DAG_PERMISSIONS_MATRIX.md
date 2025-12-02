# DAG System Permissions Matrix

**Date:** November 4, 2025  
**Purpose:** Define role-based access for DAG features

---

## 📋 **Permission Codes:**

```
atelier.job.ticket      - View/manage job tickets & work queue
atelier.job.wip.scan    - Record WIP via mobile (Start/Pause/Complete)
atelier.job.assign      - Assign tokens to operators (Manager only)
```

---

## 🔐 **Role Permission Matrix:**

| Role | View Work Queue | Start/Pause/Complete | Assign Tokens | Notes |
|------|----------------|---------------------|---------------|-------|
| **Owner** | ✅ Yes | ✅ Yes | ✅ Yes | Full access |
| **Production Manager** | ✅ Yes | ✅ Yes | ✅ Yes | Can assign + work |
| **Quality Manager** | ✅ Yes | ✅ Yes | ✅ Yes | Can assign + QC work |
| **Production Operator** | ✅ Yes | ✅ Yes | ❌ No | Work only, can't assign |
| **Artisan Operator** | ✅ Yes | ✅ Yes | ❌ No | Work only, can't assign |
| **QC Lead** | ⚠️ Partial | ✅ Yes (QC only) | ❌ No | QC tasks only |
| **Planner** | ✅ Yes | ❌ No | ❌ No | View only |
| **Auditor** | ✅ Yes | ❌ No | ❌ No | View only |

---

## 🎯 **Permission Details:**

### **1. atelier.job.ticket (View & Work)**
```
Allows:
- View Work Queue page
- See assigned tokens
- See token details
- View work history

Granted to:
✅ Owner
✅ Production Manager
✅ Quality Manager
✅ Production Operator
✅ Artisan Operator
```

### **2. atelier.job.wip.scan (Execute Work)**
```
Allows:
- Start token
- Pause work
- Resume work
- Complete token
- Record WIP events

Granted to:
✅ Production Operator (all work)
✅ Artisan Operator (all work)
✅ Production Manager (all work)
✅ Quality Manager (QC work)
```

### **3. atelier.job.assign (Manager Only)**
```
Allows:
- View unassigned tokens
- Assign tokens to operators
- Reassign tokens
- View operator workload
- Bulk assignment

Granted to:
✅ Owner
✅ Production Manager
✅ Quality Manager
❌ NOT granted to operators (prevent self-assignment chaos)
```

---

## 📱 **UI Access Control:**

### **Work Queue Page (`?p=work_queue`)**
```
Permission required: atelier.job.ticket

If user has atelier.job.assign:
- Show "Manager View" tab
- Show assignment controls
- Show all unassigned tokens

If user has only atelier.job.ticket:
- Show "My Work" only
- Show assigned tokens
- Hide assignment controls
```

### **PWA Scan Station (`?p=pwa_scan`)**
```
Permission required: atelier.job.wip.scan

Features:
- Scan QR → Start/Complete (all operators)
- View assigned work (if assignments exist)
- Offline mode (all operators)
```

### **Manager Dashboard (Future)**
```
Permission required: atelier.job.assign

Features:
- Drag & drop token assignment
- View operator workload
- Reassign tokens
- Performance analytics
```

---

## 🧪 **Testing Permissions:**

### **Test as Operator:**
```bash
# Login as test_operator (role: artisan_operator)
# Should be able to:
✅ Access Work Queue page
✅ See assigned tokens
✅ Start/Pause/Complete work
❌ Access Manager Dashboard
❌ Assign tokens to others
```

### **Test as Manager:**
```bash
# Login as production_manager
# Should be able to:
✅ Access Work Queue page
✅ Access Manager Dashboard
✅ See all tokens (assigned + unassigned)
✅ Assign tokens to operators
✅ Start/Complete own work (optional)
```

### **Test as Owner:**
```bash
# Login as owner
# Should bypass all checks:
✅ Full access to everything
✅ No permission errors
✅ Can perform all actions
```

---

## 🔧 **Migration Script:**

Already applied to `bgerp_t_default`:

```sql
-- Permission created
INSERT INTO permission (code, description) 
VALUES ('atelier.job.assign', 'Assign work tokens to operators (Manager only)');

-- Granted to:
- owner (id=1)
- production_manager (id=8)
- quality_manager (id=20)

-- NOT granted to:
- production_operator (id=19)
- artisan_operator (id=17)
```

---

## ✅ **Verification:**

```
✅ Permission code exists: atelier.job.assign
✅ Granted to 3 manager roles
✅ Operators have work permissions
✅ Owner bypasses all (hardcoded)
✅ assignment_api.php uses must_allow_code()
```

**Status:** ✅ PERMISSIONS CONFIGURED CORRECTLY

---

## 📝 **API Permission Mapping:**

| API Endpoint | Permission Required | Who Can Access |
|-------------|-------------------|---------------|
| `dag_token_api.php?action=get_work_queue` | atelier.job.ticket | All operators + managers |
| `dag_token_api.php?action=start_token` | atelier.job.wip.scan | All operators + managers |
| `dag_token_api.php?action=complete_token` | atelier.job.wip.scan | All operators + managers |
| `assignment_api.php?action=get_unassigned_tokens` | atelier.job.assign | Managers only |
| `assignment_api.php?action=assign_tokens` | atelier.job.assign | Managers only |
| `assignment_api.php?action=get_my_assignments` | atelier.job.ticket | All operators + managers |

---

**See also:**
- `source/assignment_api.php` - Permission implementation
- `source/permission.php` - Permission checking logic
- `database/tenant_migrations/2025_11_token_assignment.php` - Schema

