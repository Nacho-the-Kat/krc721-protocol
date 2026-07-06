# Error Handling Guide

Complete guide to handling errors when using the KRC-721 API.

## HTTP Status Codes

The API uses standard HTTP status codes:

| Status Code | Meaning | When It Occurs |
|-------------|---------|----------------|
| `200 OK` | Success | Request succeeded, `message` is `"success"` |
| `400 Bad Request` | Invalid Request | Invalid path parameters, malformed URLs |
| `403 Forbidden` | Access Denied | IP filtering enabled and IP not allowed |
| `404 Not Found` | Resource Not Found | Collection/token/operation doesn't exist |
| `500 Internal Server Error` | Server Error | Indexer error, database error, etc. |
| `429 Too Many Requests` | Rate Limited | Too many requests (if rate limiting enabled) |

## Response Format

### Success Response

```json
{
  "message": "success",
  "result": { ... },
  "next": "..." // if paginated
}
```

### Error Response

Error responses have two formats:

#### Format 1: JSON Error (for 400, 500)

```json
{
  "message": "error message here",
  "result": null,
  "next": null
}
```

#### Format 2: Plain Text Error (for 404, some 500)

```
not found
```

**Note**: When `result` is `null` and `message` is `"not found"`, HTTP status is `404`.

## Common Errors

### Resource Not Found (404)

**When**: Requesting a collection, token, or operation that doesn't exist.

**Response**:
- HTTP Status: `404`
- Content-Type: `text/plain`
- Body: `"not found"`

**Example**:
```bash
GET /api/v1/krc721/mainnet/nfts/INVALIDTICK
# Response: 404 Not Found
# Body: "not found"
```

**Handling**:
```typescript
async function getCollection(network: string, tick: string) {
  const response = await fetch(`.../nfts/${tick}`);
  
  if (response.status === 404) {
    return null; // Not found
  }
  
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  
  const data = await response.json();
  return data.result || null;
}
```

### Invalid Path Parameters (400)

**When**: Invalid URL path parameters (e.g., invalid tick format, malformed address).

**Response**:
- HTTP Status: `400`
- Content-Type: `application/json`
- Body: JSON with error details

**Example**:
```json
{
  "message": "Failed to deserialize path parameters",
  "location": "tick"
}
```

**Handling**:
```typescript
try {
  const response = await fetch(url);
  const data = await response.json();
  
  if (response.status === 400) {
    console.error('Invalid request:', data.message);
    if (data.location) {
      console.error('Error in field:', data.location);
    }
  }
} catch (error) {
  // Handle error
}
```

### Network Errors

**When**: Connection failures, timeouts, DNS errors.

**Handling**:
```typescript
async function safeFetch(url: string, timeoutMs: number = 10000) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  
  try {
    const response = await fetch(url, { signal: controller.signal });
    clearTimeout(timeoutId);
    return response;
  } catch (error) {
    clearTimeout(timeoutId);
    if (error.name === 'AbortError') {
      throw new Error('Request timeout');
    }
    throw new Error(`Network error: ${error.message}`);
  }
}
```

### Rate Limiting (429)

**When**: Too many requests (if rate limiting is configured on the server).

**Response**:
- HTTP Status: `429`
- Headers: May include `Retry-After` header

**Handling**:
```typescript
async function fetchWithRetry(url: string, maxRetries: number = 3) {
  for (let i = 0; i < maxRetries; i++) {
    const response = await fetch(url);
    
    if (response.status === 429) {
      const retryAfter = response.headers.get('Retry-After');
      const delay = retryAfter ? parseInt(retryAfter) * 1000 : (i + 1) * 1000;
      
      console.log(`Rate limited, retrying after ${delay}ms`);
      await new Promise(resolve => setTimeout(resolve, delay));
      continue;
    }
    
    return response;
  }
  
  throw new Error('Max retries exceeded');
}
```

### Server Errors (500)

**When**: Internal server error, database error, indexer error.

**Response**:
- HTTP Status: `500`
- Content-Type: `text/plain` or `application/json`
- Body: Error message

**Handling**:
```typescript
async function handleServerError(response: Response) {
  const contentType = response.headers.get('content-type');
  
  if (contentType?.includes('application/json')) {
    const data = await response.json();
    throw new Error(`Server error: ${data.message}`);
  } else {
    const text = await response.text();
    throw new Error(`Server error: ${text}`);
  }
}
```

## Error Handling Patterns

### Pattern 1: Check HTTP Status First

```typescript
async function apiCall(url: string) {
  const response = await fetch(url);
  
  // Check HTTP status
  if (response.status === 404) {
    return null; // Not found
  }
  
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  
  const data = await response.json();
  
  // Check API message
  if (data.message !== 'success') {
    throw new Error(`API Error: ${data.message}`);
  }
  
  return data.result;
}
```

### Pattern 2: Comprehensive Error Handler

```typescript
class ApiError extends Error {
  constructor(
    message: string,
    public statusCode?: number,
    public apiMessage?: string,
    public response?: any
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

async function safeApiCall<T>(url: string): Promise<T | null> {
  try {
    const response = await fetch(url);
    const contentType = response.headers.get('content-type');
    
    // Handle different response types
    if (contentType?.includes('application/json')) {
      const data = await response.json();
      
      if (response.status === 404 || data.message === 'not found') {
        return null; // Not found
      }
      
      if (response.status !== 200 || data.message !== 'success') {
        throw new ApiError(
          `API Error: ${data.message}`,
          response.status,
          data.message,
          data
        );
      }
      
      return data.result;
    } else {
      // Plain text response (usually 404)
      const text = await response.text();
      
      if (response.status === 404) {
        return null;
      }
      
      throw new ApiError(
        `Server error: ${text}`,
        response.status,
        text
      );
    }
  } catch (error) {
    if (error instanceof ApiError) {
      throw error;
    }
    
    // Network errors
    throw new ApiError(
      `Network error: ${error instanceof Error ? error.message : 'Unknown'}`,
      undefined,
      undefined,
      error
    );
  }
}
```

### Pattern 3: Retry Logic

```typescript
async function fetchWithRetry<T>(
  url: string,
  options: {
    maxRetries?: number;
    retryDelay?: number;
    retryableStatuses?: number[];
  } = {}
): Promise<T> {
  const {
    maxRetries = 3,
    retryDelay = 1000,
    retryableStatuses = [429, 500, 502, 503, 504]
  } = options;
  
  let lastError: Error | null = null;
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetch(url);
      
      if (!response.ok && retryableStatuses.includes(response.status)) {
        if (attempt < maxRetries) {
          const delay = retryDelay * Math.pow(2, attempt); // Exponential backoff
          await new Promise(resolve => setTimeout(resolve, delay));
          continue;
        }
      }
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      const data = await response.json();
      
      if (data.message !== 'success') {
        throw new Error(`API Error: ${data.message}`);
      }
      
      return data.result;
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      
      if (attempt < maxRetries && error instanceof Error) {
        // Check if error is retryable
        if (error.message.includes('timeout') || 
            error.message.includes('network') ||
            error.message.includes('ECONNREFUSED')) {
          const delay = retryDelay * Math.pow(2, attempt);
          await new Promise(resolve => setTimeout(resolve, delay));
          continue;
        }
      }
      
      throw lastError;
    }
  }
  
  throw lastError || new Error('Max retries exceeded');
}
```

## Common Error Scenarios

### Scenario 1: Collection Doesn't Exist

```typescript
const collection = await getCollection('mainnet', 'INVALID');
if (collection === null) {
  console.log('Collection not found');
  // Handle gracefully
}
```

### Scenario 2: Invalid Tick Format

```typescript
try {
  const collection = await getCollection('mainnet', 'invalid-tick-with-dashes');
} catch (error) {
  if (error.statusCode === 400) {
    console.error('Invalid tick format (must be 1-10 alphanumeric)');
  }
}
```

### Scenario 3: Network Timeout

```typescript
try {
  const collections = await fetchAllCollections('mainnet');
} catch (error) {
  if (error.message.includes('timeout')) {
    console.error('Request timed out, try again later');
    // Implement retry logic
  }
}
```

### Scenario 4: Rate Limited

```typescript
try {
  const data = await fetchWithRetry(url, {
    maxRetries: 5,
    retryDelay: 2000
  });
} catch (error) {
  if (error.statusCode === 429) {
    console.error('Rate limited, please slow down requests');
    // Implement exponential backoff
  }
}
```

## Best Practices

1. **Always check HTTP status codes** before parsing JSON
2. **Check `message === 'success'`** even when status is 200
3. **Handle 404 gracefully** - it's a normal case (resource doesn't exist)
4. **Implement retry logic** for network errors and 5xx errors
5. **Use exponential backoff** for rate limiting
6. **Log errors** with context for debugging
7. **Validate inputs** before making requests
8. **Set timeouts** on all requests
9. **Handle JSON parsing errors** separately from network errors
10. **Provide user-friendly error messages**

## Error Response Examples

### Example 1: Not Found

```bash
$ curl https://krc721.kat.foundation/api/v1/krc721/mainnet/nfts/INVALID

HTTP/1.1 404 Not Found
Content-Type: text/plain

not found
```

### Example 2: Invalid Path Parameter

```bash
$ curl https://krc721.kat.foundation/api/v1/krc721/mainnet/nfts/invalid-tick-format

HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "message": "Failed to deserialize path parameters",
  "location": "tick"
}
```

### Example 3: Server Error

```bash
$ curl https://krc721.kat.foundation/api/v1/krc721/mainnet/status

HTTP/1.1 500 Internal Server Error
Content-Type: text/plain

Database connection error
```

## Troubleshooting

### Problem: Getting 404 for existing collection

**Possible causes**:
1. Wrong network specified in URL
2. Collection tick is case-sensitive
3. Collection was recently deployed and indexer hasn't synced yet

**Solution**:
```typescript
// Check indexer sync status first
const status = await fetch('/api/v1/krc721/mainnet/status').then(r => r.json());
if (!status.result.isIndexerSynced) {
  console.log('Indexer is still syncing, try again later');
}
```

### Problem: Pagination returns same results

**Possible causes**:
1. Using wrong offset format
2. Manually incrementing offset instead of using `next`
3. Offset format mismatch (using numeric for TickTokenOffset endpoint)

**Solution**: See [PAGINATION.md](./PAGINATION.md) for correct pagination implementation.

### Problem: CORS errors in browser

**Possible causes**:
1. Making requests from different origin
2. Server CORS not configured

**Solution**: CORS is enabled by default. If issues persist, check server configuration.

### Problem: Timeout errors

**Possible causes**:
1. Network connectivity issues
2. Server overloaded
3. Request taking too long (default timeout: 10 seconds)

**Solution**: Implement retry logic with exponential backoff.

## See Also

- [REST.md](./REST.md) - Complete API documentation
- [PAGINATION.md](./PAGINATION.md) - Pagination guide with code examples
- [FIELD_REFERENCE.md](./FIELD_REFERENCE.md) - Complete field reference

