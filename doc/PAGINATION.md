# Pagination Guide

## Overview

The KRC-721 API uses cursor-based pagination to efficiently retrieve large datasets. Understanding pagination is crucial for working with collections, operations, and other list endpoints.

## How Pagination Works

### Basic Concept

1. **Request a page**: Make a request to a paginated endpoint (optionally with `offset`, `limit`, and `direction` parameters)
2. **Check for more data**: Look for the `next` field in the response
3. **Fetch next page**: If `next` is present, use its value as the `offset` parameter for the next request
4. **Repeat**: Continue until `next` is `null` or `undefined`

### Response Structure

All paginated responses follow this structure:

```json
{
  "message": "success",
  "result": [...],  // Array of items
  "next": "offset_value"  // null if no more pages
}
```

**Key Points:**
- `next` is `null` or `undefined` when there are no more pages
- `next` contains the offset value to use for the next request
- The offset format varies by endpoint (see Offset Types below)

## Offset Types

Different endpoints use different offset formats. **This is critical to understand.**

### 1. Score-Based Offsets (Numeric)

**Format**: Unsigned 64-bit integer (string representation)

**Used by:**
- `/api/v1/krc721/{network}/nfts` - Collections list
- `/api/v1/krc721/{network}/ops` - Operations list
- `/api/v1/krc721/{network}/deployments` - Deployments list
- `/api/v1/krc721/{network}/history/{tick}/{id}` - Ownership history

**Example**:
```json
{
  "message": "success",
  "result": [...],
  "next": "13000000000000"
}
```

**Usage**:
```bash
# First page
GET /api/v1/krc721/mainnet/nfts

# Next page (using next from previous response)
GET /api/v1/krc721/mainnet/nfts?offset=13000000000000
```

### 2. TokenId-Based Offsets (Numeric)

**Format**: Unsigned 64-bit integer (string representation)

**Used by:**
- `/api/v1/krc721/{network}/owners/{tick}` - Token owners list
- `/api/v1/krc721/{network}/address/{address}/{tick}` - Address collection holdings

**Example**:
```json
{
  "message": "success",
  "result": [...],
  "next": "51"
}
```

**Usage**:
```bash
# First page
GET /api/v1/krc721/mainnet/owners/MYCOLLECTION

# Next page
GET /api/v1/krc721/mainnet/owners/MYCOLLECTION?offset=51
```

### 3. TickTokenOffset-Based Offsets (String)

**Format**: `"TICK-tokenId"` (tick symbol, hyphen, token ID)

**Used by:**
- `/api/v1/krc721/{network}/address/{address}` - All NFTs for an address

**Example**:
```json
{
  "message": "success",
  "result": [...],
  "next": "FOO-123"
}
```

**Usage**:
```bash
# First page
GET /api/v1/krc721/mainnet/address/kaspa:abc123...

# Next page
GET /api/v1/krc721/mainnet/address/kaspa:abc123...?offset=FOO-123
```

**Important**: The format is `TICK-tokenId`, not `TICK_tokenId` or `TICK:tokenId`. Use a hyphen!

## Query Parameters

All paginated endpoints support these query parameters:

### `offset` (optional)

The cursor for pagination. Use the `next` value from the previous response.

- **Type**: String (format depends on endpoint - see Offset Types above)
- **Default**: 
  - `forward` direction: Start from beginning (offset = 0 or minimum)
  - `backward` direction: Start from end (offset = maximum)
- **Example**: `?offset=13000000000000` or `?offset=FOO-123`

### `limit` (optional)

Number of records to return per page.

- **Type**: Integer (passed as string in query: `?limit=20`)
- **Default**: 50
- **Maximum**: 50 (values greater than 50 are automatically capped at 50)
- **Example**: `?limit=20`

### `direction` (optional)

Direction of iteration.

- **Values**: `forward` (default) or `backward` (or `back`)
- **Forward**: Iterate from first to last record (chronological order)
- **Backward**: Iterate from last to first record (reverse chronological order - newest first)
- **Example**: `?direction=backward` or `?direction=back`

**Note**: These parameters work together. You can combine them:
- `?limit=10&direction=backward` - Get latest 10 items
- `?offset=123&limit=20&direction=forward` - Get next 20 items starting from offset 123

## Complete Examples

### Example 1: Fetching All Collections (Score-Based)

**JavaScript/TypeScript**:
```typescript
async function fetchAllCollections(network: string) {
  const collections = [];
  let offset: string | null = null;
  let hasMore = true;

  while (hasMore) {
    const url = offset 
      ? `https://krc721.kat.foundation/api/v1/krc721/${network}/nfts?offset=${offset}`
      : `https://krc721.kat.foundation/api/v1/krc721/${network}/nfts`;
    
    const response = await fetch(url);
    const data = await response.json();
    
    if (data.result) {
      collections.push(...data.result);
    }
    
    // Check if there's a next page
    hasMore = data.next !== null && data.next !== undefined;
    offset = data.next;
  }

  return collections;
}
```

**Python**:
```python
import requests

def fetch_all_collections(network: str):
    collections = []
    offset = None
    base_url = f"https://krc721.kat.foundation/api/v1/krc721/{network}/nfts"
    
    while True:
        url = f"{base_url}?offset={offset}" if offset else base_url
        response = requests.get(url)
        data = response.json()
        
        if data.get("result"):
            collections.extend(data["result"])
        
        # Check if there's a next page
        if not data.get("next"):
            break
        
        offset = data["next"]
    
    return collections
```

**cURL**:
```bash
# First page
curl "https://krc721.kat.foundation/api/v1/krc721/mainnet/nfts"

# Response includes: "next": "13000000000000"

# Second page
curl "https://krc721.kat.foundation/api/v1/krc721/mainnet/nfts?offset=13000000000000"

# Continue until "next" is null
```

### Example 2: Fetching All NFTs for an Address (TickTokenOffset-Based)

**JavaScript/TypeScript**:
```typescript
async function fetchAllAddressNFTs(network: string, address: string) {
  const nfts = [];
  let offset: string | null = null;
  let hasMore = true;

  while (hasMore) {
    const url = offset
      ? `https://krc721.kat.foundation/api/v1/krc721/${network}/address/${address}?offset=${offset}`
      : `https://krc721.kat.foundation/api/v1/krc721/${network}/address/${address}`;
    
    const response = await fetch(url);
    const data = await response.json();
    
    if (data.result) {
      nfts.push(...data.result);
    }
    
    hasMore = data.next !== null && data.next !== undefined;
    offset = data.next;
  }

  return nfts;
}
```

**Important**: Notice the offset format is `"FOO-123"` (string with hyphen), not a number!

### Example 3: Backward Pagination (Latest First)

**JavaScript/TypeScript**:
```typescript
async function fetchLatestDeployments(network: string, limit: number = 10) {
  const url = `https://krc721.kat.foundation/api/v1/krc721/${network}/deployments?direction=backward&limit=${limit}`;
  const response = await fetch(url);
  const data = await response.json();
  return data.result || [];
}
```

**Note**: When using `direction=backward`, you get the most recent items first. No offset needed for the first page.

### Example 4: Fetching with Custom Limit

```typescript
async function fetchWithLimit(network: string, limit: number = 20) {
  // Limit is capped at 50, so 20 is valid
  const url = `https://krc721.kat.foundation/api/v1/krc721/${network}/nfts?limit=${limit}`;
  const response = await fetch(url);
  const data = await response.json();
  return data;
}
```

## Common Mistakes

### ❌ Mistake 1: Using Wrong Offset Format

**Wrong**:
```javascript
// Using numeric offset for address endpoint
const offset = 123;
fetch(`/api/v1/krc721/mainnet/address/${address}?offset=${offset}`);
```

**Correct**:
```javascript
// Using TickTokenOffset format
const offset = "FOO-123";
fetch(`/api/v1/krc721/mainnet/address/${address}?offset=${offset}`);
```

### ❌ Mistake 2: Not Checking for Null

**Wrong**:
```javascript
while (data.next) {  // This fails if next is null!
  // ...
}
```

**Correct**:
```javascript
while (data.next !== null && data.next !== undefined) {
  // ...
}
// Or simply:
while (data.next) {
  // But be careful - empty string "" is falsy!
}
```

### ❌ Mistake 3: Incrementing Offset Manually

**Wrong**:
```javascript
let offset = 0;
while (true) {
  const data = await fetch(`/api/v1/krc721/mainnet/nfts?offset=${offset}`);
  offset += 50;  // NO! Don't do this!
  // ...
}
```

**Correct**:
```javascript
let offset = null;
while (true) {
  const url = offset 
    ? `/api/v1/krc721/mainnet/nfts?offset=${offset}`
    : `/api/v1/krc721/mainnet/nfts`;
  const data = await fetch(url);
  offset = data.next;  // Use the next value from response
  if (!offset) break;
}
```

### ❌ Mistake 4: Assuming Offset Type

**Wrong**:
```javascript
// Assuming all offsets are numbers
const offset = parseInt(data.next);
```

**Correct**:
```javascript
// Use the offset as-is (it's already a string)
const offset = data.next;
```

## Endpoint-Specific Notes

### Collections List (`/nfts`)
- **Offset Type**: Score (numeric string)
- **Default Direction**: Forward (oldest first)
- **Use Case**: Browse all collections chronologically

### Operations List (`/ops`)
- **Offset Type**: Score (numeric string)
- **Default Direction**: Forward (oldest first)
- **Use Case**: Monitor all operations

### Deployments List (`/deployments`)
- **Offset Type**: Score (numeric string)
- **Default Direction**: Forward (oldest first)
- **Use Case**: Track new collection deployments
- **Tip**: Use `direction=backward` to get latest deployments first

### Address NFT List (`/address/{address}`)
- **Offset Type**: TickTokenOffset (string format: "TICK-tokenId")
- **Default Direction**: Forward
- **Use Case**: Get all NFTs owned by an address
- **Important**: Offset format is `"FOO-123"`, not numeric!

### Token Owners (`/owners/{tick}`)
- **Offset Type**: TokenId (numeric string)
- **Default Direction**: Forward
- **Use Case**: List all tokens and their owners in a collection

### Ownership History (`/history/{tick}/{id}`)
- **Offset Type**: Score (numeric string)
- **Default Direction**: Forward
- **Use Case**: Track ownership changes for a specific token

## Performance Considerations

1. **Limit Size**: Use appropriate limits (default 50 is usually good)
2. **Caching**: Consider caching paginated results
3. **Parallel Requests**: Don't make parallel requests with the same offset
4. **Rate Limiting**: Be aware of rate limits (if configured)

## Testing Pagination

Use the sandbox (`/sandbox`) to test pagination:

1. Navigate to a paginated endpoint
2. Enter query parameters: `limit=10&direction=forward`
3. Execute the request
4. Copy the `next` value
5. Use it as `offset` in the next request

## Summary

- **Always use the `next` value from the response** as the `offset` for the next request
- **Offset formats vary**: Score (numeric), TokenId (numeric), or TickTokenOffset (string "TICK-tokenId")
- **Check endpoint documentation** to know which offset type to expect
- **`next` is null when there are no more pages**
- **Don't manually increment offsets** - use the `next` value provided
- **Use `direction=backward`** to get latest items first

For endpoint-specific details, see [REST.md](./REST.md).

