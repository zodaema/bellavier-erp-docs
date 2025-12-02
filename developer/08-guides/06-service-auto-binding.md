# 🔗 Service Class Auto-Binding Guide

**Version:** 1.0  
**Last Updated:** November 8, 2025  
**Status:** ✅ Production Ready

---

## 📋 Overview

**Service Class Auto-Binding** automatically binds API file names to Service classes using PSR-4 naming convention. This eliminates the need for manual service instantiation and ensures consistent naming across the codebase.

---

## 🎯 Benefits

- ✅ **No Manual Instantiation** - Service is automatically created from API file name
- ✅ **Consistent Naming** - snake_case → PascalCase conversion handled automatically
- ✅ **Type-Safe Access** - Service methods are type-checked
- ✅ **Easy Testing** - Mock service classes for unit tests
- ✅ **Reduced Boilerplate** - Less code to write and maintain

---

## 🔧 How It Works

### Naming Convention

| API File | Service Class |
|----------|---------------|
| `source/example.php` | `BGERP\Service\ExampleService` |
| `source/work_center.php` | `BGERP\Service\WorkCenterService` |
| `source/qc_rework.php` | `BGERP\Service\QcReworkService` |
| `source/hatthasilpa_job_ticket.php` | `BGERP\Service\HatthasilpaJobTicketService` |

### Conversion Rules

1. Extract base filename (remove `.php` extension)
2. Convert snake_case/kebab-case to PascalCase:
   - `example` → `Example`
   - `work_center` → `WorkCenter`
   - `qc_rework` → `QcRework`
3. Append `Service` suffix
4. Resolve to `BGERP\Service\{Name}Service`

---

## 📝 Implementation

### Step 1: Create Base Service Class

**File:** `source/BGERP/Service/BaseService.php`

```php
<?php
namespace BGERP\Service;

use mysqli;

abstract class BaseService
{
    protected mysqli $db;
    protected int $tenantId;

    public function __construct(mysqli $tenantDb, int $tenantId = 0)
    {
        $this->db = $tenantDb;
        $this->tenantId = $tenantId;
    }

    protected function tx(callable $fn)
    {
        $this->db->begin_transaction();
        try {
            $result = $fn($this->db);
            $this->db->commit();
            return $result;
        } catch (\Throwable $e) {
            $this->db->rollback();
            throw $e;
        }
    }
}
```

### Step 2: Create Service Factory

**File:** `source/BGERP/Service/ServiceFactory.php`

```php
<?php
namespace BGERP\Service;

use mysqli;

final class ServiceFactory
{
    public static function fromApiFile(string $apiFile, mysqli $tenantDb, int $tenantId = 0): BaseService
    {
        $base = basename($apiFile, '.php');
        $class = self::toPascalCase($base) . 'Service';
        $fqcn = __NAMESPACE__ . '\\' . $class;

        if (!class_exists($fqcn)) {
            throw new \RuntimeException("Service class not found: {$fqcn}");
        }

        $svc = new $fqcn($tenantDb, $tenantId);

        if (!($svc instanceof BaseService)) {
            throw new \RuntimeException("{$fqcn} must extend BaseService");
        }

        return $svc;
    }

    private static function toPascalCase(string $name): string
    {
        $name = str_replace(['-', '_'], ' ', strtolower($name));
        $name = str_replace(' ', '', ucwords($name));
        return $name;
    }
}
```

### Step 3: Create Service Class

**File:** `source/BGERP/Service/ExampleService.php`

```php
<?php
namespace BGERP\Service;

class ExampleService extends BaseService
{
    public function list(): array
    {
        $sql = "SELECT id_example, code, name, is_active FROM example ORDER BY id_example DESC";
        $res = $this->db->query($sql);
        return $res ? $res->fetch_all(MYSQLI_ASSOC) : [];
    }

    public function get(int $id): ?array
    {
        $stmt = $this->db->prepare("SELECT * FROM example WHERE id_example=?");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        return $row ?: null;
    }

    public function create(string $code, string $name, ?string $desc = ''): int
    {
        return $this->tx(function($db) use ($code, $name, $desc) {
            $stmt = $db->prepare("INSERT INTO example (code, name, description, is_active) VALUES (?, ?, ?, 1)");
            $stmt->bind_param('sss', $code, $name, $desc);
            if (!$stmt->execute()) {
                throw new \RuntimeException('EXECUTE_FAIL');
            }
            $id = $stmt->insert_id;
            $stmt->close();
            return $id;
        });
    }
}
```

### Step 4: Use in API File

**File:** `source/example.php`

```php
<?php
use BGERP\Service\ServiceFactory;

// ... authentication, rate limiting, etc. ...

// --- Service Auto-Binding ------------------------------------------
try {
    $service = ServiceFactory::fromApiFile(__FILE__, $tenantDb, (int)($member['id_org'] ?? 0));
} catch (\RuntimeException $e) {
    error_log(sprintf('[CID:%s][%s] Service auto-binding failed: %s', $cid, basename(__FILE__), $e->getMessage()));
    json_error('service_unavailable', 503, ['app_code' => 'CORE_503_SERVICE_NOT_FOUND']);
}

// Use service methods
switch ($action) {
    case 'list':
        $rows = $service->list();
        json_success(['data' => $rows]);
        break;
    
    case 'get':
        $id = (int)($_GET['id'] ?? 0);
        $row = $service->get($id);
        if (!$row) json_error('not_found', 404);
        json_success(['data' => $row]);
        break;
    
    case 'create':
        $id = $service->create($data['code'], $data['name'], $data['description'] ?? '');
        json_success(['id_example' => $id], 201);
        break;
}
```

---

## 🎨 Best Practices

### 1. Keep Business Logic in Service

**✅ Good:**
```php
// API Controller
case 'create':
    $validation = RequestValidator::make($_POST, [...]);
    if (!$validation['valid']) json_error(...);
    $id = $service->create($validation['data']['code'], $validation['data']['name']);
    json_success(['id' => $id], 201);
    break;

// Service Class
public function create(string $code, string $name): int
{
    return $this->tx(function($db) use ($code, $name) {
        // Business logic here
    });
}
```

**❌ Bad:**
```php
// Don't put business logic in API controller
case 'create':
    $stmt = $tenantDb->prepare("INSERT INTO ...");
    // Complex business logic here
    break;
```

### 2. Use Transactions for Multi-Step Operations

```php
public function createWithDetails(string $code, array $details): int
{
    return $this->tx(function($db) use ($code, $details) {
        // Step 1: Create main record
        $stmt = $db->prepare("INSERT INTO example (code) VALUES (?)");
        $stmt->bind_param('s', $code);
        $stmt->execute();
        $id = $stmt->insert_id;
        $stmt->close();
        
        // Step 2: Create related records
        foreach ($details as $detail) {
            $stmt = $db->prepare("INSERT INTO example_detail (id_example, ...) VALUES (?, ...)");
            // ...
        }
        
        return $id;
    });
}
```

### 3. Handle Errors Appropriately

**Service Layer:**
```php
public function create(string $code, string $name): int
{
    return $this->tx(function($db) use ($code, $name) {
        $stmt = $db->prepare("INSERT INTO example (code, name) VALUES (?, ?)");
        $stmt->bind_param('ss', $code, $name);
        
        if (!$stmt->execute()) {
            $errno = $stmt->errno ?? 0;
            $stmt->close();
            
            if ($errno === 1062) {
                throw new \RuntimeException('DUPLICATE: code');
            }
            
            throw new \RuntimeException('EXECUTE_FAIL');
        }
        
        return $stmt->insert_id;
    });
}
```

**API Controller:**
```php
try {
    $id = $service->create($data['code'], $data['name']);
} catch (\RuntimeException $e) {
    if (strpos($e->getMessage(), 'DUPLICATE') !== false) {
        json_error('duplicate_code', 409, ['app_code' => 'EX_409_DUP']);
    }
    json_error('db_operation_failed', 500, ['app_code' => 'EX_500_EXECUTE']);
}
```

---

## 🔍 Troubleshooting

### Service Class Not Found

**Error:** `Service class not found: BGERP\Service\ExampleService`

**Solutions:**
1. Check service class exists: `source/BGERP/Service/ExampleService.php`
2. Verify class name matches naming convention
3. Run `composer dump-autoload`
4. Check PSR-4 autoload in `composer.json`

### Service Doesn't Extend BaseService

**Error:** `ExampleService must extend BaseService`

**Solution:**
```php
// Change from:
class ExampleService
{
    // ...
}

// To:
class ExampleService extends BaseService
{
    // ...
}
```

### Override Service Class (Special Cases)

If you need to use a different service class:

```php
// Option 1: Use explicit class name
$service = ServiceFactory::create(
    'BGERP\Service\CustomService',
    $tenantDb,
    $tenantId
);

// Option 2: Use header override (for testing)
$override = $_SERVER['HTTP_X_SERVICE_CLASS'] ?? null;
if ($override && class_exists($override)) {
    $service = new $override($tenantDb, $tenantId);
} else {
    $service = ServiceFactory::fromApiFile(__FILE__, $tenantDb, $tenantId);
}
```

---

## 📚 Related Documentation

- **[API Development Guide](./API_DEVELOPMENT_GUIDE.md)** - Complete API development guide
- **[Service Reuse Guide](./SERVICE_REUSE_GUIDE.md)** - When to reuse vs create new services
- **[PSR-4 Migration Audit](./PSR4_API_MIGRATION_AUDIT.md)** - PSR-4 structure reference

---

## ✅ Checklist

When implementing Service Auto-Binding:

- [ ] Service class extends `BaseService`
- [ ] Service class follows naming convention (`{Module}Service`)
- [ ] Service class is in `source/BGERP/Service/` directory
- [ ] `composer dump-autoload` has been run
- [ ] API file uses `ServiceFactory::fromApiFile(__FILE__, ...)`
- [ ] Error handling for service not found
- [ ] Business logic is in service, not API controller
- [ ] Transactions used for multi-step operations

---

**Last Updated:** November 8, 2025
