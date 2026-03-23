# KRC-721 Protocol - AI Agent Skill Reference

Machine-readable reference for the KRC-721 NFT indexer REST API on the Kaspa blockchain.

## Base URLs

- **Mainnet**: `https://krc721.kat.foundation`
- **Testnet-10**: `https://krc721-testnet.kat.foundation`

All endpoints use the path prefix `/api/v1/krc721/{network}/` where `{network}` is `mainnet` or `testnet-10`.

## Data Types

| Type | Description | Example |
|------|-------------|---------|
| SOMPI | Smallest KAS unit (10^-8 KAS) | `"212000000000"` = 2120 KAS |
| Score | u64 operation score (DAA-based) | `"24907847264002"` |
| TokenId | u64 token identifier | `"1"`, `"9999"` |
| TickTokenOffset | Pagination cursor for cross-collection queries | `"NACHO-10"` |
| Kaspa address | Bech32 address with network prefix | `kaspa:qr5e65mqknfnsa6d...` |
| txIdRev | Reversed hex transaction ID | `"145e07ae3278f3d6..."` |
| Timestamp | Milliseconds since epoch | `"1738336906070"` |
| Tick | 1-10 char uppercase collection identifier | `"NACHO"`, `"WOLFPACK"` |

## Response Envelope

Every JSON response wraps results in:

```json
{
    "message": "success",
    "result": <data>,
    "next": <offset_or_absent>
}
```

- `message`: Always present. `"success"` on HTTP 200.
- `result`: The payload. May be an object, array, string, or absent on 404.
- `next`: **Only present on paginated responses when more pages exist.** Entirely omitted (not `null`) on the last page. Use `data.next != null` to check in JavaScript.

## Pagination Model

Cursor-based. Never manually increment offsets.

**Query parameters** (on paginated endpoints only):
- `offset`: Value from previous response's `next` field
- `limit`: 1-50, default 50
- `direction`: `forward` (default, chronological) or `backward` (reverse)

**Three offset types:**

| Offset Type | Endpoints | Format | Example `next` |
|------------|-----------|--------|-----------------|
| Score (u64) | `/nfts`, `/ops`, `/deployments`, `/history/:tick/:id` | Numeric string | `24907845280005` |
| TokenId (u64) | `/owners/:tick`, `/address/:address/:tick` | Numeric | `4`, `10` |
| TickTokenOffset | `/address/:address` | String `"TICK-id"` | `"NACHO-10"` |

**Pagination loop pattern:**

```javascript
let offset = null;
const all = [];
do {
    const params = new URLSearchParams({ limit: '50' });
    if (offset != null) params.set('offset', offset);
    const res = await fetch(`${BASE}/api/v1/krc721/mainnet/nfts?${params}`);
    const data = await res.json();
    all.push(...(data.result || []));
    offset = data.next;
} while (offset != null);
```

## All 16 Endpoints

### 1. GET /status
Indexer health, sync status, network statistics.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/status
```

Response fields: `version`, `network`, `isNodeConnected`, `isNodeSynced`, `isIndexerSynced`, `lastKnownBlockHash`, `blueScore`, `currentOpScore`, `daaScore`, `powFeesTotal`, `royaltyFeesTotal`, `tokenDeploymentsTotal`, `tokenMintsTotal`, `tokenTransfersTotal`

### 2. GET /nfts
All deployed collections. **Paginated (Score).**

```bash
curl "https://krc721.kat.foundation/api/v1/krc721/mainnet/nfts?limit=2"
```

Result array fields: `deployer`, `royaltyTo`, `buri`, `max`, `royaltyFee`, `daaMintStart`, `premint`, `tick`, `txIdRev`, `mtsAdd`, `minted`, `opScoreMod`, `state`, `mtsMod`, `opScoreAdd`

### 3. GET /nfts/:tick
Single collection details. Not paginated.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/nfts/NACHO
```

Same fields as `/nfts` list item.

### 4. GET /nfts/:tick/:id
Single token with current owner. Not paginated.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/nfts/NACHO/1
```

Result fields: `tick`, `tokenId`, `owner`, `opScoreMod`

### 5. GET /owners/:tick
All token owners in a collection. **Paginated (TokenId).**

```bash
curl "https://krc721.kat.foundation/api/v1/krc721/mainnet/owners/NACHO?limit=3"
```

Result array fields: `tick`, `tokenId`, `owner`, `opScoreMod`
Example `next`: `4`

### 6. GET /address/:address
All NFTs owned by an address across all collections. **Paginated (TickTokenOffset).**

```bash
curl "https://krc721.kat.foundation/api/v1/krc721/mainnet/address/kaspa:qplfvwnt6ywwjz76d3358anh0kuymmamfr8ec86907rpfjygzp0ex4d283q3d?limit=3"
```

Result array fields: `tick`, `buri`, `tokenId`, `opScoreMod`
Example `next`: `"NACHO-10"`

**CRITICAL**: The offset for this endpoint is a string in `"TICK-tokenId"` format, not a number.

### 7. GET /address/:address/:tick
NFTs owned by an address in a specific collection. **Paginated (TokenId).**

```bash
curl "https://krc721.kat.foundation/api/v1/krc721/mainnet/address/kaspa:qplfvwnt6ywwjz76d3358anh0kuymmamfr8ec86907rpfjygzp0ex4d283q3d/NACHO?limit=3"
```

Result array fields: `tick`, `tokenId`, `opScoreMod`
Example `next`: `10`

### 8. GET /royalties/:address/:tick
Royalty fee for minting. **Not paginated.** Result is a single string (SOMPI amount).

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/royalties/kaspa:qplfvwnt6ywwjz76d3358anh0kuymmamfr8ec86907rpfjygzp0ex4d283q3d/NACHO
```

```json
{"message":"success","result":"212000000000"}
```

### 9. GET /deployments
All deployment operations. **Paginated (Score).**

```bash
curl "https://krc721.kat.foundation/api/v1/krc721/mainnet/deployments?limit=1&direction=backward"
```

Result array fields: `deployer`, `royalty_to` (snake_case), `buri`, `max`, `royaltyFee`, `daaMintStart`, `premint`, `tick`, `txIdRev`, `mtsAdd`, `opScore`

> Note: Uses snake_case `royalty_to` (not camelCase `royaltyTo`). The `opScore` may appear as a raw number instead of a string.

### 10. GET /ops
All operations (deploy, mint, transfer, discount). **Paginated (Score).**

```bash
curl "https://krc721.kat.foundation/api/v1/krc721/mainnet/ops?limit=1"
```

Result array fields: `p`, `deployer`, `royalty_to`/`to`, `tick`, `txIdRev`, `mtsAdd`, `op`, `opData`, `opScore`, `feeRev`, `opError` (only on failures)

Operation types in `op` field: `"deploy"`, `"mint"`, `"transfer"`, `"discount"`

The `opData` object varies by operation type:
- **deploy**: `{ buri, max, royaltyFee, daaMintStart, premint }`
- **mint**: `{ tokenId, royalty?: { royaltyFee } }`
- **transfer**: `{ tokenId }`

### 11. GET /ops/score/:score
Single operation by score. Not paginated.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/ops/score/24907687056003
```

Same structure as `/ops` list item.

### 12. GET /ops/txid/:txid
Single operation by transaction ID. Not paginated.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/ops/txid/3b15799a3e3041fe692890352f9d60de5e487c6f6d63ee5c2310b872ba5b49af
```

Same structure as `/ops` list item.

### 13. GET /rejections/txid/:txid
Rejection reason for a failed operation. Not paginated.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/rejections/txid/SOME_TXID
```

Returns `{"message":"success","result":"InsufficientFee"}` if rejection exists.
Returns HTTP 404 with `Content-Type: text/plain` body `"not found"` if no rejection.

### 14. GET /reserved
Reserved ticker names. Not paginated. Returns a string array.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/reserved
```

### 15. GET /history/:tick/:id
Ownership history of a token. **Paginated (Score).**

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/history/NACHO/1
```

Result array fields: `owner`, `opScoreMod`, `txIdRev`

### 16. GET /ranges/:tick
Available token ID ranges for minting. Not paginated. Returns a comma-separated string of `start,size` pairs.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/ranges/NACHO
```

Returns `""` when fully minted, or `"100,50,200,20"` meaning IDs 100-149 and 200-219 are available.

## Error Handling

| HTTP Status | Content-Type | Meaning |
|-------------|--------------|---------|
| 200 | application/json | Success |
| 400 | application/json | Bad request (invalid params) |
| 404 | text/plain | Resource not found (body: `"not found"`) |
| 404 | application/json | Resource not found (JSON envelope) |
| 500 | text/plain | Server error |

The 404 content type depends on the endpoint: `to_json` endpoints return `text/plain`, while other errors return JSON.

## Serialization Inconsistencies

Be aware of these when parsing responses:

1. **`royaltyTo` vs `royalty_to`**: Collection endpoints use camelCase; operation/deployment endpoints use snake_case.
2. **`opScore` type**: Usually a string, but `/deployments` may return it as a raw JSON number.
3. **`next` field**: Omitted entirely (not `null`) when no more pages. Check with `!= null` (covers both `undefined` and `null`).
4. **`buri` field presence**: Included in `/address/:address` results but not in `/address/:address/:tick` results.

## Common Patterns

**Check if indexer is synced:**
```bash
curl -s .../status | jq '.result.isIndexerSynced'
```

**Get latest operations:**
```bash
curl ".../ops?limit=10&direction=backward"
```

**Check if collection is fully minted:**
```bash
curl -s .../ranges/NACHO | jq '.result == ""'
```

**Get all tokens owned by an address:**
```bash
# First page
curl ".../address/kaspa:qplfvwnt6...?limit=50"
# If response has "next" field, use it:
curl ".../address/kaspa:qplfvwnt6...?limit=50&offset=NACHO-10"
```
