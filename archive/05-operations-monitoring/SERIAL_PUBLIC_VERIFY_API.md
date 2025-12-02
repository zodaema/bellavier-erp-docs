# 🌐 Public Serial Verification API

**Purpose:** Customer-facing serial number verification endpoint  
**Version:** 1.0.0  
**Last Updated:** November 9, 2025

---

## 🎯 Overview

The Public Serial Verification API allows customers to verify the authenticity and status of serial numbers without requiring authentication. This endpoint is designed for public access while maintaining strict privacy policies.

---

## 📍 Endpoint

```
GET /api/public/serial/verify/{serial_code}
```

**Alternative:** Query parameter format
```
GET /api/public/serial/verify?serial={serial_code}
```

---

## 🔒 Security & Privacy

### **Privacy Modes:**

| Mode | Description | PII Exposure |
|------|-------------|--------------|
| `minimal` | Basic validity and status only | ❌ None |
| `standard` | Adds traceability path (no operator names) | ❌ None |
| `internal` | Full traceability (requires authentication) | ⚠️ Requires auth |

**Default:** `minimal` (for public API)

### **Rate Limiting:**

- **Limit:** 60 requests per hour per IP address
- **Response:** HTTP 429 (Too Many Requests) if exceeded
- **Storage:** Rate limit data stored in `storage/rate_limits/`

### **CORS Support:**

- **Headers:** `Access-Control-Allow-Origin: *`
- **Methods:** GET, OPTIONS
- **Headers:** Content-Type

---

## 📥 Request

### **URL Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `serial_code` | string | ✅ Yes | Serial number to verify (in URL path or query) |

### **Example Requests:**

```bash
# URL path format
curl https://erp.example.com/api/public/serial/verify/MA01-HAT-BAG-20251109-00027-A9K2-X

# Query parameter format
curl https://erp.example.com/api/public/serial/verify?serial=MA01-HAT-BAG-20251109-00027-A9K2-X
```

---

## 📤 Response

### **Success Response (200 OK):**

```json
{
  "ok": true,
  "valid": true,
  "verified": true,
  "serial": "MA01-HAT-BAG-20251109-00027-A9K2-X",
  "status": "active",
  "production_type": "hatthasilpa",
  "scope": "piece",
  "data": {
    "tenant": "MA01",
    "sku": "BAG",
    "manufactured_at": "2025-11-09T08:30:00Z",
    "status": "active",
    "origin": "auto_job",
    "visibility": "public"
  }
}
```

### **Error Responses:**

#### **400 Bad Request - Missing Serial:**
```json
{
  "ok": false,
  "error": "Missing serial code. Usage: /api/public/serial/verify/{serial_code}"
}
```

#### **400 Bad Request - Invalid Format:**
```json
{
  "ok": false,
  "error": "Invalid serial code format"
}
```

#### **404 Not Found:**
```json
{
  "ok": false,
  "error": "Serial not found or invalid",
  "reason": "not_found"
}
```

#### **429 Too Many Requests:**
```json
{
  "ok": false,
  "error": "Rate limit exceeded. Maximum 60 requests per hour per IP."
}
```

#### **500 Internal Server Error:**
```json
{
  "ok": false,
  "error": "Internal server error"
}
```

---

## 📊 Response Fields

### **Top-Level Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `ok` | boolean | Request success status |
| `valid` | boolean | Serial validity (format + checksum + hash) |
| `verified` | boolean | Registry verification status |
| `serial` | string | Serial code (normalized) |
| `status` | string | Serial status: `active`, `used`, `scrapped`, `cancelled` |
| `production_type` | string | Production type: `hatthasilpa` or `oem` |
| `scope` | string | Serial scope: `piece` or `batch` |
| `data` | object | Serial data (privacy-aware) |
| `warning` | string | Optional warning (e.g., `serial_not_active`) |

### **Data Object (Privacy Mode: minimal):**

```json
{
  "tenant": "MA01",
  "sku": "BAG",
  "manufactured_at": "2025-11-09T08:30:00Z",
  "status": "active",
  "origin": "auto_job",
  "visibility": "public"
}
```

### **Data Object (Privacy Mode: standard):**

Includes traceability path (no operator names):

```json
{
  "tenant": "MA01",
  "sku": "BAG",
  "manufactured_at": "2025-11-09T08:30:00Z",
  "status": "active",
  "origin": "auto_job",
  "visibility": "public",
  "traceability": {
    "path": ["Cutting", "Stitching", "Finishing"],
    "nodes": [
      {
        "node_name": "Cutting",
        "completed_at": "2025-11-09T09:00:00Z"
      },
      {
        "node_name": "Stitching",
        "completed_at": "2025-11-09T10:30:00Z"
      }
    ]
  }
}
```

---

## 🔍 Verification Logic

The API performs the following checks:

1. **Format Validation:** Regex pattern matching
2. **Checksum Validation:** Modulo-36 checksum verification
3. **Hash Validation:** HMAC-SHA256 signature verification
4. **Registry Lookup:** Check `serial_registry` table
5. **Status Check:** Verify serial status (active/used/scrapped/cancelled)

---

## ⚠️ Privacy Policy

### **No PII Exposure:**

- ❌ **Never expose:** Operator names, user IDs, email addresses
- ❌ **Never expose:** Internal system IDs (token IDs, job ticket IDs)
- ✅ **Allowed:** Display names/aliases (if configured)
- ✅ **Allowed:** Generalized timestamps (date/time, no timezone details)
- ✅ **Allowed:** Traceability path (node names only)

### **Privacy Mode Behavior:**

- **minimal:** Only basic validity and status
- **standard:** Adds traceability path (no operator names)
- **internal:** Full traceability (requires authentication - not available in public API)

---

## 🧪 Example Usage

### **JavaScript (Browser):**

```javascript
async function verifySerial(serialCode) {
    try {
        const response = await fetch(
            `https://erp.example.com/api/public/serial/verify/${serialCode}`
        );
        const data = await response.json();
        
        if (data.ok && data.valid) {
            console.log('Serial is valid:', data.serial);
            console.log('Status:', data.status);
            console.log('Manufactured:', data.data.manufactured_at);
        } else {
            console.error('Serial invalid:', data.error);
        }
    } catch (error) {
        console.error('Verification failed:', error);
    }
}

// Usage
verifySerial('MA01-HAT-BAG-20251109-00027-A9K2-X');
```

### **cURL:**

```bash
curl -X GET \
  "https://erp.example.com/api/public/serial/verify/MA01-HAT-BAG-20251109-00027-A9K2-X" \
  -H "Accept: application/json"
```

### **PHP:**

```php
$serialCode = 'MA01-HAT-BAG-20251109-00027-A9K2-X';
$url = "https://erp.example.com/api/public/serial/verify/{$serialCode}";

$ch = curl_init($url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Accept: application/json']);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode === 200) {
    $data = json_decode($response, true);
    if ($data['ok'] && $data['valid']) {
        echo "Serial is valid: {$data['serial']}\n";
    }
}
```

---

## 🔗 Related Documents

- `SERIAL_NUMBER_DESIGN.md` - Serial format specification
- `SERIAL_NUMBER_SYSTEM_CONTEXT.md` - System context and privacy modes
- `SERIAL_NUMBER_IMPLEMENTATION.md` - Implementation details

---

## 📝 Notes

- **Rate Limiting:** Rate limit data is stored per IP address and cleaned up automatically
- **CORS:** Full CORS support for cross-origin requests
- **Error Handling:** All errors return JSON format (never HTML)
- **Privacy:** No PII is ever exposed in public API responses

