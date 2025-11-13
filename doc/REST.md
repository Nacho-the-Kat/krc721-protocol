# REST API Specifications

**📚 Documentation Index:**
- [PAGINATION.md](./PAGINATION.md) - Complete pagination guide with examples
- [FIELD_REFERENCE.md](./FIELD_REFERENCE.md) - All response fields explained
- [ERROR_HANDLING.md](./ERROR_HANDLING.md) - Error handling guide
- [KRC-721.md](./KRC-721.md) - Protocol specification

## Kaspa Networks

The Kaspa network id must be specified in the URL path. Currently, the following networks ids are supported:

- `mainnet`
- `testnet-10`

The indexer must be running on the same network as the network specified in the URL path. Specifying a different network id will result in an error.

## Response Format

All responses are in JSON format. The response result is wrapped in a `Response` object with the following fields:

- `message` - A human-readable message describing the result of the request.
- `result` (optional) - The result of the request.
- `next` (optional) - The offset of the next page.

The `message` field is always present and contains a human-readable message describing the result of the request. The `"success"` text in the message field indicates that the request was successful.

If an error occurs (e.g. a resource is not found or some other error), the `message` field will contain an error message and the HTTP status code will be set appropriately (400 for bad requests, 404 for not found, 500 for server errors).

**Error Handling**: See [ERROR_HANDLING.md](./ERROR_HANDLING.md) for complete error handling documentation.

Checking that the `message` field contains `"success"` and the HTTP status code is `200` is a good way to check that the request was successful.

## Pagination

**⚠️ IMPORTANT**: Pagination is a critical feature. See [PAGINATION.md](./PAGINATION.md) for comprehensive documentation, examples, and common mistakes.

### Quick Overview

Resource listing endpoints are paginated if the number of records exceeds the user-specified limit or the maximum default limit of `50` records.

**Key Points:**
- Use the `next` value from the response as the `offset` parameter for the next request
- Offset formats vary by endpoint (numeric Score, numeric TokenId, or string TickTokenOffset)
- When `next` is `null` or `undefined`, there are no more pages
- **Never manually increment offsets** - always use the `next` value provided

### Query Parameters

- **`offset`** (optional): Cursor for pagination. Use the `next` value from the previous response. Format depends on endpoint.
- **`limit`** (optional): Number of records per page. Default: 50, Maximum: 50.
- **`direction`** (optional): Iteration direction. Values: `forward` (default) or `backward`/`back`.

### Offset Types by Endpoint

Different endpoints use different offset formats:

| Endpoint | Offset Type | Format | Example |
|----------|-------------|--------|---------|
| `/nfts` | Score | Numeric string | `"13000000000000"` |
| `/ops` | Score | Numeric string | `"13000000000000"` |
| `/deployments` | Score | Numeric string | `"13000000000000"` |
| `/history/{tick}/{id}` | Score | Numeric string | `"13000000000000"` |
| `/owners/{tick}` | TokenId | Numeric string | `"51"` |
| `/address/{address}/{tick}` | TokenId | Numeric string | `"51"` |
| `/address/{address}` | TickTokenOffset | String `"TICK-tokenId"` | `"FOO-123"` |

**⚠️ Critical**: The `/address/{address}` endpoint uses a string format `"TICK-tokenId"` (with hyphen), not a number!

### Basic Example

```javascript
// Fetch all pages
let offset = null;
let allItems = [];

while (true) {
  const url = offset 
    ? `/api/v1/krc721/mainnet/nfts?offset=${offset}`
    : `/api/v1/krc721/mainnet/nfts`;
  
  const response = await fetch(url);
  const data = await response.json();
  
  allItems.push(...(data.result || []));
  
  if (!data.next) break;  // No more pages
  offset = data.next;      // Use next value as offset
}
```

### Direction

- **`forward`** (default): Iterate from first to last record (chronological order)
- **`backward`** or **`back`**: Iterate from last to first record (reverse chronological order)

Use `direction=backward` to get the latest items first without pagination.

### Limits

- **Default**: 50 records per page
- **Maximum**: 50 records (values greater than 50 are ignored)
- **Minimum**: 1 record

### Common Mistakes

1. ❌ **Wrong**: Manually incrementing offset (`offset += 50`)
   ✅ **Correct**: Use `next` value from response

2. ❌ **Wrong**: Using numeric offset for `/address/{address}` endpoint
   ✅ **Correct**: Use TickTokenOffset format `"TICK-tokenId"`

3. ❌ **Wrong**: Not checking if `next` is null
   ✅ **Correct**: Check `if (!data.next) break;`

**For complete pagination documentation with examples in multiple languages, see [PAGINATION.md](./PAGINATION.md).**

## REST endpoints

### Indexer Status

```
GET /api/v1/krc721/{network}/status
```

Response:
```json
{
    "message": "text",
    "result": {
        "version": "string",
        "network": "string",
        "isNodeConnected": true,
        "isNodeSynced": true,
        "isIndexerSynced": true,
        "lastKnownBlockHash": "string",
        "daaScore": "uint64",
        "powFeesTotal": "uint64",
        "royaltyFeesTotal": "uint64",
        "tokenDeploymentsTotal": "uint64",
        "tokenMintsTotal": "uint64",
        "tokenTransfersTotal": "uint64"
    }
}
```

### Collections

#### Get Collections List
```
GET /api/v1/krc721/{network}/nfts
```

**Query Parameters:**
- `offset` (optional): Pagination offset (Score format - numeric string)
- `limit` (optional): Number of records (1-50, default: 50)
- `direction` (optional): `forward` (default) or `backward`

**Pagination**: This endpoint uses Score-based pagination. See [PAGINATION.md](./PAGINATION.md) for details.

**Field Reference**: See [FIELD_REFERENCE.md](./FIELD_REFERENCE.md) for field descriptions.

Response:
```json
{
    "message": "text",
    "prev": "text",
    "next": "text",
    "result": [
        {
            "deployer": "kaspatest:qqqqqqqqqqqqqqq",
            "buri": "ipfs://QOWmd",
            "max": "250",
            "daaMintStart": "0",
            "premint": "6",
            "tick": "FOO",
            "txIdRev": "0000000000000000000000000000000000000000000000000000000000000000",
            "mtsAdd": "1000000000",
            "minted": "6",
            "opScoreMod": "1000000000",
            "state": "deployed",
            "mtsMod": "1000000000",
            "opScoreAdd": "1000000000"
        }
    ],
    "next": 13000000000000
}
```

#### Get Collection Details
```
GET /api/v1/krc721/{network}/nfts/{tick}
```

Response:
```json
{
    "message": "text",
    "result":
    {
        "deployer": "kaspatest:qqqqqqqqqqqqqqqqq",
        "royaltyTo": "kaspatest:qqqqqqqqqqqqqqqqqqq",
        "buri": "ipfs://dz1...",
        "max": "800",
        "royaltyFee": "2500000000",
        "daaMintStart": "0",
        "premint": "10",
        "tick": "FOO",
        "txIdRev": "0000000000000000000000000000000000000000000000000000000000000000",
        "mtsAdd": "1000000000",
        "minted": "556",
        "opScoreMod": "1000000000",
        "state": "deployed",
        "mtsMod": "1000000000",
        "opScoreAdd": "1000000000"
    }
}
```

### Tokens

#### Get Token Details
```
GET /api/v1/krc721/{network}/nfts/{tick}/{id}
```

Response:
```json
{
    "message": "text",
    "result":
    {
        "tick": "FOO",
        "tokenId": "123",
        "owner": "kaspatest:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
        "buri": "ipfs://..."
    }
}
```

#### Get Token Owners
```
GET /api/v1/krc721/{network}/owners/{tick}
```

**Query Parameters:**
- `offset` (optional): Pagination offset (TokenId format - numeric string)
- `limit` (optional): Number of records (1-50, default: 50)
- `direction` (optional): `forward` (default) or `backward`

**Pagination**: This endpoint uses TokenId-based pagination. See [PAGINATION.md](./PAGINATION.md) for details.

Response:
```json
{
    "message": "text",
    "result": [
        {
            "tick": "FOO",
            "tokenId": "123",
            "owner": "kaspatest:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
            "opScoreMod": "1000000000"
        }
    ],
    "next": 51
}
```

### Address Holdings

#### Get Address NFT List
```
GET /api/v1/krc721/{network}/address/{address}
```

**Query Parameters:**
- `offset` (optional): Pagination offset (**TickTokenOffset format** - string `"TICK-tokenId"`)
- `limit` (optional): Number of records (1-50, default: 50)
- `direction` (optional): `forward` (default) or `backward`

**⚠️ CRITICAL**: This endpoint uses TickTokenOffset format (`"FOO-123"`), NOT a numeric offset!

**Pagination**: See [PAGINATION.md](./PAGINATION.md) for complete details and examples.

Response:
```json
{
    "message": "text",
    "result": [
        {
            "tick": "FOO",
            "tokenId": "381",
            "buri": "ipfs://..."
        },
        {
            "tick": "FOO",
            "tokenId": "382",
            "buri": "ipfs://..."
        },
        {
            "tick": "FOO",
            "tokenId": "31010",
            "buri": "ipfs://..."
        }
    ],
    "next":"FOO-123"
}

```


#### Get Address Collection Holdings
```
GET /api/v1/krc721/{network}/address/{address}/{tick}
```

Response:
```json
{
    "message": "text",
    "result":
    {
        "tick": "FOO",
        "tokenId": "381",
        "opScoreMod": "79993666"
    }
}

```


### Operations

#### Get Operations List
```
GET /api/v1/krc721/{network}/ops
```

**Query Parameters:**
- `offset` (optional): Pagination offset (Score format - numeric string)
- `limit` (optional): Number of records (1-50, default: 50)
- `direction` (optional): `forward` (default) or `backward`

**Pagination**: This endpoint uses Score-based pagination. Use `direction=backward` to get latest operations first.

Response:
```json
{
    "message": "text",
    "result": [
        {
            "p": "krc-721",
            "deployer": "kaspatest:kaspatest:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
            "op": "deploy",
            "tick": "FOO",
            "opData": {
                "buri": "ipfs://...",
                "max": "456"
            },
            "opScore": "123",
            "txIdRev": "0000000000000000000000000000000000000000000000000000000000000000",
            "mtsAdd": "00000000000000", 
            "opError": "InsufficientFee",
            "feeRev": "123"
        },
        {
            "p": "krc-721",
            "deployer": "kaspatest:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
            "op": "mint",
            "tick": "FOO",
            "opData": {
                "tokenId": "1234",
                "to": "0000"
            },
            "opScore": "123",
            "txIdRev": "0000000000000000000000000000000000000000000000000000000000000000",
            "opError": "InsufficientFee",
            "mtsAdd": "00000000000000",
            "feeRev": "123"
        },    
        {
            "p": "krc-721",
            "deployer": "kaspatest:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
            "op": "transfer",
            "tick": "FOO",
            "opData": {
                "tokenId": "1234",
                "to": "0000"
            },
            "opScore": "123",      
            "txIdRev": "0000000000000000000000000000000000000000000000000000000000000000",
            "opError": "InsufficientFee",
            "mtsAdd": "00000000000000",
            "feeRev": "123"
        }
    ],
    "next": 13000000000000
}

```

#### Get Operation Details by Score
```
GET /api/v1/krc721/{network}/ops/score/{id}
```

Response:
```json
{
    "message": "text",
    "result":
    {
        "p": "krc-721",
        "deployer": "kaspatest:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
        "royalty_to": "kaspatest:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
        "tick": "FOO",
        "txIdRev": "0000000000000000000000000000000000000000000000000000000000000000",
        "mtsAdd": "00000000000000",
        "op": "deploy",
        "opData": {
            "buri": "ipfs://",
            "max": "10000",
            "royaltyFee": "12300000",
            "daaMintStart": "0",
            "premint": "123"
        },
        "opError": "InsufficientFee",
        "opScore": "123",
        "feeRev": "123"
    }
}

```

#### Get Operation Details by Transaction ID
```
GET /api/v1/krc721/{network}/ops/txid/{txid}
```

Response:
```json
{
    "message": "text",
    "result":
    {
        "p": "krc-721",
        "deployer": "kaspatest:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
        "to": "kaspatest:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
        "tick": "FOO",
        "txIdRev": "0000000000000000000000000000000000000000000000000000000000000000",
        "mtsAdd": "0000000000000",
        "op": "deploy",
        "opData": {
            "buri": "ipfs://",
            "max": "1230",
            "daaMintStart": "0"
        },
        "opError": "InsufficientFee",
        "opScore": "123",
        "feeRev": "123"
    }
}

```

#### Get Royalty Fees for a given address and tick
```
GET /api/v1/krc721/{network}/royalties/{address}/{tick}
```

Response:
```json
{
    "message": "text",
    "result": "1000000000"
}
```

#### Get Rejection Reason by Transaction ID

Rejections include the reason for which the indexer has rejected the transaction. Rejections can occur due to an invalid operation (insufficient fee, invalid ticker, already deployed ticker, etc.) or due to a static check failure (e.g. missing `"to"` field in the transfer operation).

A transaction is recorded in the indexer log only if it contains a valid krc721 envelope (all other transactions are ignored).

```
GET /api/v1/krc721/{network}/rejections/txid/{txid}
```

Response:
```json
{
    "message": "text",
    "result": "rejection reason"
}
```

### Get Ownership History
```
GET /api/v1/krc721/{network}/history/{tick}/{id}
```

Get ownership history of a token (all ownership changes).

**Query Parameters:**
- `offset` (optional): Pagination offset (Score format - numeric string)
- `limit` (optional): Number of records (1-50, default: 50)
- `direction` (optional): `forward` (default) or `backward`

**Pagination**: This endpoint uses Score-based pagination.

Response:
```json
{
  "message": "success",
  "result": [
    {
      "owner": "kaspa:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
      "opScoreMod": "2000000000",
      "txIdRev": "0000000000000000000000000000000000000000000000000000000000000000"
    },
    {
      "owner": "kaspa:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
      "opScoreMod": "1002200000",
      "txIdRev": "0000000000000000000000000000000000000000000000000000000000000000"
    },
    {
      "owner": "kaspa:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
      "opScoreMod": "1000000001",
      "txIdRev": "0000000000000000000000000000000000000000000000000000000000000000"
    }
  ],
  "next": "100000000"
}
```

### Get Available Token ID Ranges
```
GET /api/v1/krc721/{network}/ranges/{tick}
```
Get available token ID ranges for minting in a collection.
Response:

```json 
{
    "message": "success",
    "result": "100,50,200,20,5000,99990"
}
```
The result string represents available ranges in format start1,size1,start2,size2,.... For each range, start is the starting token ID and size is how many consecutive token IDs are available starting from that ID.

Response when fully minted:
```json
{
    "message": "success",
    "result": ""
}
```
