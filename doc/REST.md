# REST API Specifications

**Documentation Index:**
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
- `next` (optional) - The offset of the next page. **Omitted entirely** (not set to `null`) when there are no more pages.

The `message` field is always present and contains a human-readable message describing the result of the request. The `"success"` text in the message field indicates that the request was successful.

If an error occurs (e.g. a resource is not found or some other error), the `message` field will contain an error message and the HTTP status code will be set appropriately (400 for bad requests, 404 for not found, 500 for server errors).

**Error Handling**: See [ERROR_HANDLING.md](./ERROR_HANDLING.md) for complete error handling documentation.

Checking that the `message` field contains `"success"` and the HTTP status code is `200` is a good way to check that the request was successful.

### Serialization Notes

> **`next` field omission**: The server uses `serde(skip_serializing_if = "Option::is_none")` for the `next` field. When there are no more pages, the `next` field is **entirely absent** from the response JSON (it is not set to `null`). Client code should check for the absence of the field, e.g. `if (data.next != null)` in JavaScript.

> **`royaltyTo` vs `royalty_to`**: Collection listing endpoints (`/nfts`) use camelCase `royaltyTo`, while operation endpoints (`/ops`, `/deployments`, `/ops/score/:score`, `/ops/txid/:txid`) use snake_case `royalty_to`. This is a serialization inconsistency between different Rust structs on the server.

> **`opScore` type inconsistency**: The `/deployments?direction=backward` endpoint may return `opScore` as a raw JSON number (e.g. `95527572848001`), while `/ops` returns it as a string (e.g. `"24907687056003"`). Clients should handle both formats.

## Pagination

**IMPORTANT**: Pagination is a critical feature. See [PAGINATION.md](./PAGINATION.md) for comprehensive documentation, examples, and common mistakes.

### Quick Overview

Resource listing endpoints are paginated if the number of records exceeds the user-specified limit or the maximum default limit of `50` records.

**Key Points:**
- Use the `next` value from the response as the `offset` parameter for the next request
- Offset formats vary by endpoint (numeric Score, numeric TokenId, or string TickTokenOffset)
- When `next` is absent from the response, there are no more pages
- **Never manually increment offsets** - always use the `next` value provided

### Query Parameters

- **`offset`** (optional): Cursor for pagination. Use the `next` value from the previous response. Format depends on endpoint.
- **`limit`** (optional): Number of records per page. Default: 50, Maximum: 50.
- **`direction`** (optional): Iteration direction. Values: `forward` (default) or `backward`/`back`.

### Offset Types by Endpoint

Different endpoints use different offset formats:

| Endpoint | Offset Type | Format | Example |
|----------|-------------|--------|---------|
| `/nfts` | Score | Numeric string | `"24907845280005"` |
| `/ops` | Score | Numeric string | `"95831359456003"` |
| `/deployments` | Score | Numeric string | `"95474495640001"` |
| `/history/{tick}/{id}` | Score | Numeric string | `"26236285306000"` |
| `/owners/{tick}` | TokenId | Numeric | `4` |
| `/address/{address}/{tick}` | TokenId | Numeric | `10` |
| `/address/{address}` | TickTokenOffset | String `"TICK-tokenId"` | `"NACHO-10"` |

**Critical**: The `/address/{address}` endpoint uses a string format `"TICK-tokenId"` (with hyphen), not a number!

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
  
  if (data.next == null) break;  // No more pages (field absent or null)
  offset = data.next;             // Use next value as offset
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

1. **Wrong**: Manually incrementing offset (`offset += 50`)
   **Correct**: Use `next` value from response

2. **Wrong**: Using numeric offset for `/address/{address}` endpoint
   **Correct**: Use TickTokenOffset format `"TICK-tokenId"`

3. **Wrong**: Checking `data.next === null` only
   **Correct**: Check `data.next == null` (handles both `null` and `undefined`/absent field)

**For complete pagination documentation with examples in multiple languages, see [PAGINATION.md](./PAGINATION.md).**

## REST endpoints

### Indexer Status

```
GET /api/v1/krc721/{network}/status
```

Response:
```json
{
    "message": "success",
    "result": {
        "version": "2.0.0",
        "network": "mainnet",
        "isNodeConnected": true,
        "isNodeSynced": true,
        "isIndexerSynced": true,
        "lastKnownBlockHash": "10f410db94ba152fa9c4159a60fcbd1a35ee29155d15267a4fc2a11037f5765c",
        "blueScore": 386440622,
        "currentOpScore": 95837274503999,
        "daaScore": 388293377,
        "powFeesTotal": 137690523684666,
        "royaltyFeesTotal": 4433059192903052,
        "tokenDeploymentsTotal": 310,
        "tokenMintsTotal": 118178,
        "tokenTransfersTotal": 196483
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
    "message": "success",
    "result": [
        {
            "deployer": "kaspa:qph4jwnrwgfd690e3a5zrwdeetfkpauxu2nku0jasgnp794kp4rr5taw7erxg",
            "royaltyTo": "kaspa:qph4jwnrwgfd690e3a5zrwdeetfkpauxu2nku0jasgnp794kp4rr5taw7erxg",
            "buri": "ipfs://bafybeiau2zfmq6o2gvw7g5rerwem7fa2bd6prm3hvyx6kn42is7yq26sey",
            "max": "10000",
            "royaltyFee": "179900000000",
            "daaMintStart": "0",
            "premint": "500",
            "tick": "KSPR",
            "txIdRev": "3b15799a3e3041fe692890352f9d60de5e487c6f6d63ee5c2310b872ba5b49af",
            "mtsAdd": "1738336231427",
            "minted": "1267",
            "opScoreMod": "58790365648007",
            "state": "deployed",
            "mtsMod": "1759297835433",
            "opScoreAdd": "24907687056003"
        }
    ],
    "next": 24907845280005
}
```

> Note: Collection list results use camelCase `royaltyTo`. The `next` field is omitted when there are no more pages.

#### Get Collection Details
```
GET /api/v1/krc721/{network}/nfts/{tick}
```

Response:
```json
{
    "message": "success",
    "result": {
        "deployer": "kaspa:qr5e65mqknfnsa6d486axdtcqpredz6hfseet2x56u7nh25mmpyazgsmdp9y8",
        "royaltyTo": "kaspa:qr5e65mqknfnsa6d486axdtcqpredz6hfseet2x56u7nh25mmpyazgsmdp9y8",
        "buri": "ipfs://bafybeifwjyipfzlorzaw42amf53lvo3x6hpfg5xhr6km5drjmucsftrfy4",
        "max": "10000",
        "royaltyFee": "212000000000",
        "daaMintStart": "102045126",
        "premint": "0",
        "tick": "NACHO",
        "txIdRev": "145e07ae3278f3d6753ea33b22c66767f2d7a4c002fcfec117c75306dec527e2",
        "mtsAdd": "1738336906070",
        "minted": "10000",
        "opScoreMod": "26885172096005",
        "state": "deployed",
        "mtsMod": "1746310927897",
        "opScoreAdd": "24907847264002"
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
    "message": "success",
    "result": {
        "tick": "NACHO",
        "tokenId": "1",
        "owner": "kaspa:qps6zry9swaqjf5xehae5nsga2sx84xmzes2gc5y8lznaj4t6gm9w7klxrzq5",
        "opScoreMod": "26236285306000",
        "status": {
            "state": "listed",
            "listingTxId": "0000000000000000000000000000000000000000000000000000000000000001",
            "opScore": "789"
        }
    }
}
```

`status.state` is `unlisted` by default. When the NFT is listed, the response also includes the listing transaction id and the listing operation score.

#### Get Token Owners
```
GET /api/v1/krc721/{network}/owners/{tick}
```

**Query Parameters:**
- `offset` (optional): Pagination offset (TokenId format - numeric)
- `limit` (optional): Number of records (1-50, default: 50)
- `direction` (optional): `forward` (default) or `backward`

**Pagination**: This endpoint uses TokenId-based pagination. See [PAGINATION.md](./PAGINATION.md) for details.

Response:
```json
{
    "message": "success",
    "result": [
        {
            "tick": "NACHO",
            "tokenId": "1",
            "owner": "kaspa:qps6zry9swaqjf5xehae5nsga2sx84xmzes2gc5y8lznaj4t6gm9w7klxrzq5",
            "opScoreMod": "26236285306000",
            "status": {
                "state": "unlisted"
            }
        },
        {
            "tick": "NACHO",
            "tokenId": "2",
            "owner": "kaspa:qznft0mg03nlvj5lu0xv4w4ddxffzsut4m7z3tucq0vm7jeh5urt2dpg8cgk0",
            "opScoreMod": "91455826760001",
            "status": {
                "state": "unlisted"
            }
        },
        {
            "tick": "NACHO",
            "tokenId": "3",
            "owner": "kaspa:qplfvwnt6ywwjz76d3358anh0kuymmamfr8ec86907rpfjygzp0ex4d283q3d",
            "opScoreMod": "67448378712007",
            "status": {
                "state": "unlisted"
            }
        }
    ],
    "next": 4
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

**CRITICAL**: This endpoint uses TickTokenOffset format (`"NACHO-10"`), NOT a numeric offset!

**Pagination**: See [PAGINATION.md](./PAGINATION.md) for complete details and examples.

Response:
```json
{
    "message": "success",
    "result": [
        {
            "tick": "NACHO",
            "buri": "ipfs://bafybeifwjyipfzlorzaw42amf53lvo3x6hpfg5xhr6km5drjmucsftrfy4",
            "tokenId": "3",
            "opScoreMod": "67448378712007",
            "status": {
                "state": "unlisted"
            }
        },
        {
            "tick": "NACHO",
            "buri": "ipfs://bafybeifwjyipfzlorzaw42amf53lvo3x6hpfg5xhr6km5drjmucsftrfy4",
            "tokenId": "4",
            "opScoreMod": "67448354408006",
            "status": {
                "state": "listed",
                "listingTxId": "0000000000000000000000000000000000000000000000000000000000000002",
                "opScore": "80000001"
            }
        },
        {
            "tick": "NACHO",
            "buri": "ipfs://bafybeifwjyipfzlorzaw42amf53lvo3x6hpfg5xhr6km5drjmucsftrfy4",
            "tokenId": "8",
            "opScoreMod": "70142421312002",
            "status": {
                "state": "unlisted"
            }
        }
    ],
    "next": "NACHO-10"
}
```

> Note: The `next` field is a string in `"TICK-tokenId"` format, not a number. The `buri` field is included in address listing results.

#### Get Address Collection Holdings
```
GET /api/v1/krc721/{network}/address/{address}/{tick}
```

**Query Parameters:**
- `offset` (optional): Pagination offset (TokenId format - numeric)
- `limit` (optional): Number of records (1-50, default: 50)
- `direction` (optional): `forward` (default) or `backward`

**Pagination**: This endpoint uses TokenId-based pagination.

Response:
```json
{
    "message": "success",
    "result": [
        {
            "tick": "NACHO",
            "tokenId": "3",
            "opScoreMod": "67448378712007",
            "status": {
                "state": "unlisted"
            }
        },
        {
            "tick": "NACHO",
            "tokenId": "4",
            "opScoreMod": "67448354408006",
            "status": {
                "state": "unlisted"
            }
        },
        {
            "tick": "NACHO",
            "tokenId": "8",
            "opScoreMod": "70142421312002",
            "status": {
                "state": "unlisted"
            }
        }
    ],
    "next": 10
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

Response (deploy operation):
```json
{
    "message": "success",
    "result": [
        {
            "p": "krc-721",
            "deployer": "kaspa:qph4jwnrwgfd690e3a5zrwdeetfkpauxu2nku0jasgnp794kp4rr5taw7erxg",
            "royalty_to": "kaspa:qph4jwnrwgfd690e3a5zrwdeetfkpauxu2nku0jasgnp794kp4rr5taw7erxg",
            "tick": "KSPR",
            "txIdRev": "3b15799a3e3041fe692890352f9d60de5e487c6f6d63ee5c2310b872ba5b49af",
            "mtsAdd": "1738336231427",
            "op": "deploy",
            "opData": {
                "buri": "ipfs://bafybeiau2zfmq6o2gvw7g5rerwem7fa2bd6prm3hvyx6kn42is7yq26sey",
                "max": "10000",
                "royaltyFee": "179900000000",
                "daaMintStart": "0",
                "premint": "500"
            },
            "opScore": "24907687056003",
            "feeRev": "600000000000"
        }
    ],
    "next": 24907713096004
}
```

Response (transfer operation, via `direction=backward`):
```json
{
    "message": "success",
    "result": [
        {
            "p": "krc-721",
            "deployer": "kaspa:qq5fysv96t636u4slda59daza6tn5j5p5x5953hs6dstajuw0u6l6cyj4d0ef",
            "to": "kaspa:qplfvwnt6ywwjz76d3358anh0kuymmamfr8ec86907rpfjygzp0ex4d283q3d",
            "tick": "NACHO",
            "txIdRev": "82569c3254315597026e9521cc358b1847bf29bd71fe4a0a6218c7d22764a13a",
            "mtsAdd": "1774247106390",
            "op": "transfer",
            "opData": {
                "tokenId": "1439"
            },
            "opScore": "95832809264001",
            "feeRev": "101624"
        }
    ],
    "next": 95831359456003
}
```

Response (mint operation):
```json
{
    "p": "krc-721",
    "deployer": "kaspa:qr92zkpt83n08fmw50dssekaa4jwrzs5uqtv8j9xl2l4fhschnfvcj6pedllk",
    "to": "kaspa:qr92zkpt83n08fmw50dssekaa4jwrzs5uqtv8j9xl2l4fhschnfvcj6pedllk",
    "tick": "KASBRICKS",
    "txIdRev": "830877ca8adbd5649757dbba606d640f3e481710eaccaa4b9d8b71cba3fc39c2",
    "mtsAdd": "1774246561832",
    "op": "mint",
    "opData": {
        "tokenId": "327",
        "royalty": {
            "royaltyFee": "5000000000"
        }
    },
    "opScore": "95831422944002",
    "feeRev": "1000011378"
}
```

> Note: Operation results use snake_case `royalty_to` (not `royaltyTo`). The `opError` field only appears on failed operations. The `to` field appears on mint and transfer operations. The `royalty` object inside `opData` appears on mint operations when a royalty was paid.

#### Get Deployments List
```
GET /api/v1/krc721/{network}/deployments
```

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
            "deployer": "kaspa:qpw73mje2uw5xjvrk0ttuyl3ejd0lp3ty07zzdqsn0ga5v7zypkt5h5mcrw68",
            "royalty_to": "kaspa:qypsx5q89kulr9t0fuandpmhwuur7t6kqhc0qpaqctcm393fqyl0c5gfpn3xr53",
            "buri": "ipfs://Qmbrt6vchnFerZ4fPDaeGvTa3jXVX8nf1nLnmPHqSP12z4",
            "max": "218",
            "royaltyFee": "42000000000",
            "daaMintStart": "0",
            "premint": "0",
            "tick": "DAGSKULK",
            "txIdRev": "21e8ba72f60baf19c8e1b5c0e4197e3439bd9586add336dfc7f8af8592b9341f",
            "mtsAdd": "1774123975590",
            "opScore": 95527572848001
        }
    ],
    "next": 95474495640001
}
```

> Note: Deployments use snake_case `royalty_to`. The `opScore` field may appear as a raw JSON number (not a string) in deployment results -- this is a serialization inconsistency. The `state` field is not present in deployment operation results.

#### Get Operation Details by Score
```
GET /api/v1/krc721/{network}/ops/score/{score}
```

Response:
```json
{
    "message": "success",
    "result": {
        "p": "krc-721",
        "deployer": "kaspa:qph4jwnrwgfd690e3a5zrwdeetfkpauxu2nku0jasgnp794kp4rr5taw7erxg",
        "royalty_to": "kaspa:qph4jwnrwgfd690e3a5zrwdeetfkpauxu2nku0jasgnp794kp4rr5taw7erxg",
        "tick": "KSPR",
        "txIdRev": "3b15799a3e3041fe692890352f9d60de5e487c6f6d63ee5c2310b872ba5b49af",
        "mtsAdd": "1738336231427",
        "op": "deploy",
        "opData": {
            "buri": "ipfs://bafybeiau2zfmq6o2gvw7g5rerwem7fa2bd6prm3hvyx6kn42is7yq26sey",
            "max": "10000",
            "royaltyFee": "179900000000",
            "daaMintStart": "0",
            "premint": "500"
        },
        "opScore": "24907687056003",
        "feeRev": "600000000000"
    }
}
```

#### Get Operation Details by Transaction ID
```
GET /api/v1/krc721/{network}/ops/txid/{txid}
```

Response: Same structure as `ops/score/{score}` above. Returns the operation associated with the given transaction ID.

#### Get Royalty Fee
```
GET /api/v1/krc721/{network}/royalties/{address}/{tick}
```

Returns the royalty fee (in SOMPI) that a specific address must pay to mint from a collection. This is **not paginated**.

Response:
```json
{
    "message": "success",
    "result": "212000000000"
}
```

> Note: The result is a string representing SOMPI (1 SOMPI = 10^-8 KAS). In this example, 212000000000 SOMPI = 2120 KAS.

#### Get Rejection Reason by Transaction ID

Rejections include the reason for which the indexer has rejected the transaction. Rejections can occur due to an invalid operation (insufficient fee, invalid ticker, already deployed ticker, etc.) or due to a static check failure (e.g. missing `"to"` field in the transfer operation).

A transaction is recorded in the indexer log only if it contains a valid krc721 envelope (all other transactions are ignored).

```
GET /api/v1/krc721/{network}/rejections/txid/{txid}
```

Response (when rejection exists):
```json
{
    "message": "success",
    "result": "InsufficientFee"
}
```

Response (when no rejection exists): HTTP 404 with `Content-Type: text/plain` body:
```
not found
```

> Note: This endpoint returns `text/plain` (not JSON) for 404 responses.

### Reserved Tickers

```
GET /api/v1/krc721/{network}/reserved
```

Returns the list of reserved ticker names that cannot be deployed.

Response:
```json
{
    "message": "success",
    "result": [
        "KII",
        "AED",
        "EUR",
        "IGRA",
        "CAD",
        "KAS",
        "KASPA",
        "USDC",
        "KEF",
        "NACHO",
        "USD",
        "USDT"
    ]
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
            "owner": "kaspa:qps6zry9swaqjf5xehae5nsga2sx84xmzes2gc5y8lznaj4t6gm9w7klxrzq5",
            "opScoreMod": "26236285306000",
            "txIdRev": "d9533a0604a57b24148a9d16d2d5c24e95f27f5bf968f628ca580a64d1e3000b"
        }
    ]
}
```

> Note: When this is the only/last page, the `next` field is omitted entirely from the response.

### Get Available Token ID Ranges
```
GET /api/v1/krc721/{network}/ranges/{tick}
```
Get available token ID ranges for minting in a collection.

Response (when ranges are available):
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

> Note: NACHO (10000/10000 minted) returns an empty string, confirming the collection is fully minted.
