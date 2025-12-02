# 🔄 Service Reuse Guide

**Purpose:** ระบุ Service classes ที่มีอยู่แล้วและสามารถ reuse ได้ เพื่อหลีกเลี่ยงการสร้าง Service ซ้ำซ้อน

**Last Updated:** November 8, 2025

---

## ✅ Service Classes ที่มีอยู่แล้ว (Reusable)

### 1. **DatabaseHelper** (`BGERP\Helper\DatabaseHelper`)
**Purpose:** Database operations ทั่วไป (prepared statements, transactions)

**Usage:**
```php
use BGERP\Helper\DatabaseHelper;

$dbHelper = new DatabaseHelper($tenantDb, $coreDb);

// Fetch all rows
$rows = $dbHelper->fetchAll("SELECT * FROM table WHERE id = ?", [$id], 'i');

// Fetch one row
$row = $dbHelper->fetchOne("SELECT * FROM table WHERE id = ?", [$id], 'i');

// Execute INSERT/UPDATE/DELETE
$affected = $dbHelper->execute("UPDATE table SET name = ? WHERE id = ?", [$name, $id], 'si');

// Insert and get ID
$newId = $dbHelper->insert("INSERT INTO table (name) VALUES (?)", [$name], 's');

// Transactions
$dbHelper->beginTransaction();
// ... operations ...
$dbHelper->commit(); // or rollback()
```

**When to use:**
- ✅ ทุก API ที่ต้องการ database operations
- ✅ แทนที่ direct SQL queries
- ✅ เมื่อต้องการ transaction support

---

### 2. **DataService** (`BGERP\Service\DataService`)
**Purpose:** Common data fetching operations (teams, members, assignments)

**Available Methods:**
- `getTeamMembers($teamId)` - Get team members
- `getTeamMemberNames($memberIds)` - Get member names from core DB
- `getCurrentWork($memberId)` - Get current assignments
- `getMemberInfo($memberId)` - Get member info from core DB
- `getActiveTeams($orgId)` - Get active teams
- `getAssignmentHistory(...)` - Get assignment history

**Usage:**
```php
use BGERP\Service\DataService;
use BGERP\Helper\DatabaseHelper;

$dbHelper = new DatabaseHelper($tenantDb, $coreDb);
$dataService = new DataService($dbHelper);

$members = $dataService->getTeamMembers($teamId);
$memberNames = $dataService->getTeamMemberNames([1, 2, 3]);
```

**When to use:**
- ✅ API ที่ต้องการ team/member data
- ✅ API ที่ต้องการ assignment history
- ✅ API ที่ต้องการ cross-DB lookups (tenant → core)

---

### 3. **ValidationService** (`BGERP\Service\ValidationService`)
**Purpose:** Input validation และ sanitization

**Usage:**
```php
use BGERP\Service\ValidationService;

$validator = new ValidationService($tenantDb);

// Validate product SKU
if (!$validator->validateProductSku($sku)) {
    json_error('Invalid SKU format', 400);
}

// Validate quantity
if (!$validator->validateQuantity($qty, $min = 1, $max = 1000)) {
    json_error('Quantity out of range', 400);
}
```

**When to use:**
- ✅ ทุก API ที่รับ user input
- ✅ Validation logic ที่ซับซ้อน

---

### 4. **ErrorHandler** (`BGERP\Service\ErrorHandler`)
**Purpose:** Centralized error handling และ logging

**Usage:**
```php
use BGERP\Service\ErrorHandler;

$errorHandler = ErrorHandler::getInstance();

try {
    // ... operations ...
} catch (\Throwable $e) {
    $errorHandler->handle($e, true); // true = send HTTP response
}
```

**When to use:**
- ✅ Top-level try-catch ใน API files
- ✅ เมื่อต้องการ standardized error responses

---

### 5. **OperatorDirectoryService** (`BGERP\Service\OperatorDirectoryService`)
**Purpose:** Operator profile resolution (with caching, PDPA masking)

**Usage:**
```php
use BGERP\Service\OperatorDirectoryService;

$opService = new OperatorDirectoryService($tenantDb, $coreDb);
$operators = $opService->getOperatorProfiles($tenantId, $orgId, [
    'include_inactive' => false,
    'roles' => ['operator', 'supervisor']
]);
```

**When to use:**
- ✅ API ที่ต้องการ list operators
- ✅ API ที่ต้องการ operator lookup
- ✅ เมื่อต้องการ PDPA-compliant operator data

---

### 6. **DatabaseTransaction** (`BGERP\Service\DatabaseTransaction`)
**Purpose:** Transaction wrapper with automatic rollback on error

**Usage:**
```php
use BGERP\Service\DatabaseTransaction;

DatabaseTransaction::execute($tenantDb, function($db) {
    // All operations here are in a transaction
    $stmt1 = $db->prepare("INSERT INTO table1 ...");
    $stmt1->execute();
    
    $stmt2 = $db->prepare("INSERT INTO table2 ...");
    $stmt2->execute();
    
    // If any exception occurs, transaction is rolled back automatically
});
```

**When to use:**
- ✅ Multi-step operations ที่ต้อง atomic
- ✅ เมื่อต้องการ automatic rollback

---

## 🆕 Service Classes ที่ควรสร้างใหม่ (Domain-Specific)

### หลักการตัดสินใจ:

**สร้าง Service ใหม่เมื่อ:**
- ❌ Business logic เฉพาะ domain (เช่น BOM, Materials, Dashboard)
- ❌ มี complex calculations หรือ algorithms
- ❌ มี state management หรือ caching requirements
- ❌ มี domain-specific validations

**ใช้ Service ที่มีอยู่แล้วเมื่อ:**
- ✅ เป็น common operations (CRUD, data fetching)
- ✅ เป็น utility functions (validation, error handling)
- ✅ เป็น database operations ทั่วไป

---

### ตัวอย่าง Domain-Specific Services:

#### ✅ **BOMService** (สร้างแล้ว)
**Why:** BOM มี business logic เฉพาะ (circular reference detection, multi-level flattening, cost rollup)

#### ✅ **DashboardService** (ควรสร้าง)
**Why:** Dashboard มี complex aggregations และ calculations

#### ✅ **MaterialsService** (ควรสร้าง)
**Why:** Materials มี business logic เฉพาะ (stock tracking, availability, costing)

#### ✅ **WorkCentersService** (ควรสร้าง)
**Why:** Work centers มี capacity calculations และ scheduling logic

---

## 📋 Decision Matrix

| Operation Type | Use Existing Service | Create New Service |
|----------------|---------------------|-------------------|
| Simple CRUD | ✅ DatabaseHelper | ❌ |
| Data fetching (teams, members) | ✅ DataService | ❌ |
| Input validation | ✅ ValidationService | ❌ |
| Error handling | ✅ ErrorHandler | ❌ |
| Operator lookup | ✅ OperatorDirectoryService | ❌ |
| Domain-specific logic (BOM, Materials) | ❌ | ✅ Create new |
| Complex calculations | ❌ | ✅ Create new |
| Multi-step workflows | ❌ | ✅ Create new |

---

## 🎯 Best Practices

### 1. **Always check existing Services first**
```php
// ❌ Don't create new service for simple CRUD
// ✅ Use DatabaseHelper instead
$dbHelper = new DatabaseHelper($tenantDb);
$rows = $dbHelper->fetchAll("SELECT * FROM products WHERE id_org = ?", [$orgId], 'i');
```

### 2. **Compose Services when needed**
```php
// ✅ Use multiple services together
$dbHelper = new DatabaseHelper($tenantDb, $coreDb);
$dataService = new DataService($dbHelper);
$validator = new ValidationService($tenantDb);

// Validate input
if (!$validator->validateProductSku($sku)) {
    json_error('Invalid SKU', 400);
}

// Fetch data
$product = $dataService->getProduct($productId);
```

### 3. **Create Domain Service only when needed**
```php
// ✅ Create BOMService for BOM-specific logic
// ❌ Don't create ProductService just for simple SELECT queries
//    Use DatabaseHelper instead
```

---

## 📊 Current Service Inventory

### ✅ **Reusable Services** (20 classes)
1. `DatabaseHelper` - Database operations
2. `DataService` - Common data fetching
3. `ValidationService` - Input validation
4. `ErrorHandler` - Error handling
5. `OperatorDirectoryService` - Operator profiles
6. `DatabaseTransaction` - Transaction wrapper
7. `WorkEventService` - Work event abstraction
8. `OperatorSessionService` - Operator session management
9. `TokenLifecycleService` - Token operations
10. `DAGRoutingService` - DAG routing logic
11. `DAGValidationService` - DAG validation
12. `TeamService` - Team CRUD
13. `TeamMemberService` - Team member operations
14. `TeamExpansionService` - Team expansion logic
15. `TeamWorkloadService` - Workload calculations
16. `ProductionRulesService` - Production rules
17. `RoutingSetService` - Routing templates
18. `SerialManagementService` - Serial management
19. `SecureSerialGenerator` - Serial generation
20. `JobTicketStatusService` - Job ticket status

### 🆕 **Domain-Specific Services** (1 class)
1. `BOMService` - BOM business logic ✅ (created)

### 🔜 **Recommended New Services**
1. `DashboardService` - Dashboard aggregations
2. `MaterialsService` - Material management
3. `WorkCentersService` - Work center operations
4. `NotificationsService` - Notification logic (if complex)

---

## 💡 Example: When NOT to Create a Service

### ❌ **Bad Example:**
```php
// Don't create ProductService just for this:
class ProductService {
    public function getProducts() {
        return $this->db->query("SELECT * FROM product");
    }
}
```

### ✅ **Good Example:**
```php
// Use DatabaseHelper instead:
$dbHelper = new DatabaseHelper($tenantDb);
$products = $dbHelper->fetchAll("SELECT * FROM product WHERE is_active = 1");
```

---

## 🎯 Summary

**Rule of Thumb:**
- **Simple operations** → Use `DatabaseHelper` or existing Services
- **Complex domain logic** → Create new Domain Service
- **Common operations** → Check `DataService` first
- **Validation** → Use `ValidationService`
- **Error handling** → Use `ErrorHandler`

**Remember:** ไม่จำเป็นต้องสร้าง Service ทุกไฟล์! ใช้ existing Services ให้เต็มที่ก่อน

