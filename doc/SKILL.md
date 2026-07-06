# KRC-721 Protocol - Complete Reference

Comprehensive reference for the KRC-721 NFT standard on the Kaspa blockchain. Covers the protocol specification, transaction inscription format, REST API, pagination, data types, error handling, and code examples.

## Overview

KRC-721 is a token standard for non-fungible tokens (NFTs) on the Kaspa BlockDAG network. Operations are inscribed as JSON envelopes in Kaspa transactions. An indexer processes these transactions and exposes a REST API for querying state.

**Key features:**
- Security budget-driven transactions (fixed PoW fees for miners)
- Optional pre-minting during deployment
- Optional royalty fees per mint (paid to deployer or designated address)
- Optional discounted minting per address
- Optional DAA-based mint start time
- Metadata: external IPFS URI (`buri`) or on-chain inscribed (`metadata`)
- Full randomization of token IDs during minting
- Creator-defined max supply per collection

**Restriction:** Only IPFS CIDs (`ipfs://...` prefix) are accepted for `buri` and `metadata.image` fields.

## Deployments

- **Mainnet**: `https://krc721.kat.foundation`
- **Testnet-10**: `https://krc721-testnet.kat.foundation`

All API endpoints use the path prefix `/api/v1/krc721/{network}/` where `{network}` is `mainnet` or `testnet-10`.

---

## Part 1: Protocol Specification (Write Side)

Operations are submitted by inscribing a JSON envelope in a Kaspa transaction. The indexer parses these envelopes and updates state accordingly.

### Operation Types

Four operation types exist: `deploy`, `mint`, `transfer`, `discount`.

### Deploy

Creates a new NFT collection.

```json
{
    "p": "krc-721",
    "op": "deploy",
    "tick": "MYCOL",
    "max": "10000",
    "buri": "ipfs://QmExampleCID",
    "royaltyFee": "1000000000",
    "royaltyTo": "kaspa:qDestAddress...",
    "mintDaaScore": "525037124",
    "premint": "50",
    "to": "kaspa:qDeployerAddress..."
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `p` | string | Yes | Protocol identifier, must be `"krc-721"` |
| `op` | string | Yes | Must be `"deploy"` |
| `tick` | string | Yes | Ticker symbol, 1-10 alphanumeric characters, case-insensitive uniqueness |
| `max` | uint64 string | Yes | Maximum supply of tokens |
| `buri` | string | One of buri/metadata | Base URI for external metadata (must start with `ipfs://`) |
| `metadata` | object | One of buri/metadata | On-chain inscribed metadata (see Metadata Object below) |
| `royaltyFee` | uint64 string | No | Royalty fee per mint in SOMPI (0.1 KAS to 10,000,000 KAS range) |
| `royaltyTo` | string | No | Kaspa address to receive royalties. Defaults to deployer if omitted |
| `mintDaaScore` | uint64 string | No | DAA score after which minting is allowed. Minting is immediate if omitted |
| `premint` | uint64 string | No | Number of tokens pre-minted to deployer on deploy. Must be <= `max` |
| `to` | string | No | Address that receives deployer permissions and pre-minted tokens. Defaults to transaction sender |

**Validation rules:**
- Tick must be 1-10 alphanumeric characters, unique (case-insensitive), and not reserved
- Max supply must be a positive number
- `buri` must start with `ipfs://`, or `metadata` must contain `name`, `description`, and `image` (with `ipfs://` prefix)
- `royaltyFee` must be between 10,000,000 SOMPI (0.1 KAS) and 1,000,000,000,000 SOMPI (10,000,000 KAS) if specified
- `premint` cannot exceed `max`
- Reveal transaction fees must be >= 1,000 KAS (security budget)
- Pre-mint adds 10 KAS per token to the required deployment fee

### Mint

Mints a new token from an existing collection. The token ID is assigned randomly by the indexer from available ranges.

```json
{
    "p": "krc-721",
    "op": "mint",
    "tick": "MYCOL",
    "to": "kaspa:qRecipient..."
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `p` | string | Yes | `"krc-721"` |
| `op` | string | Yes | `"mint"` |
| `tick` | string | Yes | Collection ticker |
| `to` | string | No | Recipient address. Defaults to transaction sender |

**Validation rules:**
- Collection must exist and have unminted tokens available
- Total minted cannot exceed max supply
- Reveal transaction fees must be >= 10 KAS (security budget)
- If collection has `royaltyFee`, the **first output** of the mint reveal transaction must pay at least `royaltyFee` SOMPI to the royalty beneficiary address
- Must occur after `mintDaaScore` if one was set during deployment

### Transfer

Transfers ownership of a specific token.

```json
{
    "p": "krc-721",
    "op": "transfer",
    "tick": "MYCOL",
    "id": "42",
    "to": "kaspa:qNewOwner..."
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `p` | string | Yes | `"krc-721"` |
| `op` | string | Yes | `"transfer"` |
| `tick` | string | Yes | Collection ticker |
| `id` | uint64 string | Yes | Token ID to transfer |
| `to` | string | Yes | Recipient Kaspa address |

**Validation rules:**
- Collection and token must exist
- Transaction sender must be the current owner of the token
- Recipient address must be valid
- No fee required (standard Kaspa transaction fee only)

### Discount

Deployer assigns a discounted royalty fee to a specific address for minting.

```json
{
    "p": "krc-721",
    "op": "discount",
    "tick": "MYCOL",
    "to": "kaspa:qDiscountedAddress...",
    "discountFee": "500000000"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `p` | string | Yes | `"krc-721"` |
| `op` | string | Yes | `"discount"` |
| `tick` | string | Yes | Collection ticker |
| `to` | string | Yes | Address receiving the discount |
| `discountFee` | uint64 string | Yes | Discounted royalty fee in SOMPI |

**Validation rules:**
- Collection must exist
- Transaction sender must be the deployer of the collection
- Recipient address must be valid
- No fee required (standard Kaspa transaction fee only)

### Security Budget (PoW Fees)

Mandatory operation fees to sustain Kaspa mining security:

| Operation | Minimum Reveal Transaction Fee |
|-----------|-------------------------------|
| Deploy | 1,000 KAS |
| Pre-mint (during deploy) | +10 KAS per token |
| Mint | 10 KAS |
| Discount | Standard tx fee (no extra) |
| Transfer | Standard tx fee (no extra) |

Transactions not meeting the required fee are rejected by the indexer.

### Royalty Mechanics

- Set during deployment via `royaltyFee` (SOMPI) and optional `royaltyTo` (defaults to deployer)
- Fee range: 0.1 KAS (10,000,000 SOMPI) to 10,000,000 KAS (1,000,000,000,000,000 SOMPI)
- On each mint, the **first output** of the reveal transaction must pay >= `royaltyFee` to the royalty beneficiary
- The `/royalties/:address/:tick` API endpoint returns the effective fee for a given minter (accounts for discounts)

### Metadata

Two patterns for collection metadata:

**1. External IPFS metadata (`buri`):**
- Deploy with `"buri": "ipfs://QmCollectionCID"`
- Collection-level metadata is at the `buri` URI directly
- Individual token metadata is at `{buri}/{tokenId}`
- Metadata JSON structure is flexible but marketplaces expect `name`, `description`, `image`, and optional `attributes`

**2. On-chain inscribed metadata (`metadata`):**

```json
{
    "metadata": {
        "name": "Collection Name",
        "description": "Description text",
        "image": "ipfs://QmImageCID",
        "attributes": [
            {
                "traitType": "Background",
                "value": "Blue",
                "displayType": "string"
            }
        ]
    }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Collection name |
| `description` | string | Yes | Collection description |
| `image` | string | Yes | Image URI (must start with `ipfs://`) |
| `attributes` | array | No | Array of trait objects |

Each attribute object:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `traitType` | string | Yes | Trait name (e.g. "Background", "Rarity") |
| `value` | string | Yes | Trait value (e.g. "Blue", "Rare") |
| `displayType` | string | No | Display hint (e.g. "date", "boost_percentage") |

When using inscribed metadata, all tokens in the collection share the same attributes.

### Reserved Tickers

Some ticker names are reserved and cannot be deployed. Query `/reserved` to get the current list.

---

## Part 2: Data Types

| Type | Description | Example |
|------|-------------|---------|
| SOMPI | Smallest KAS unit (10^-8 KAS). 100,000,000 SOMPI = 1 KAS | `"212000000000"` = 2,120 KAS |
| Score | u64 operation score, DAA-based chronological ordering | `"24907847264002"` |
| TokenId | u64 token identifier within a collection | `"1"`, `"9999"` |
| TickTokenOffset | Pagination cursor string for cross-collection queries | `"NACHO-10"` |
| Kaspa address | Bech32 address with network prefix | `kaspa:qr5e65mqknfnsa6d...` |
| txIdRev | Transaction ID with reversed byte order (hex) | `"145e07ae3278f3d6..."` |
| Timestamp | Milliseconds since Unix epoch, as uint64 string | `"1738336906070"` |
| Tick | 1-10 char alphanumeric collection identifier | `"NACHO"`, `"WOLFPACK"` |
| DAA Score | Difficulty Adjustment Algorithm score (blockchain time) | `"388293377"` |

**All numeric fields** are serialized as strings in API responses to avoid JavaScript precision issues with u64 values.

**Amount conversions:**
- `"100000000"` = 1 KAS
- `"1000000000"` = 10 KAS
- `"10000000000"` = 100 KAS
- `"100000000000"` = 1,000 KAS

---

## Part 3: REST API (Read Side)

### Response Envelope

Every JSON response wraps results in:

```json
{
    "message": "success",
    "result": "<data>",
    "next": "<offset_or_absent>"
}
```

- `message`: Always present. `"success"` on HTTP 200.
- `result`: The payload. May be an object, array, string, or absent on 404.
- `next`: **Only present on paginated responses when more pages exist.** Entirely omitted (not `null`) on the last page due to `serde(skip_serializing_if = "Option::is_none")`. Use `data.next != null` in JavaScript.

### Pagination Model

Cursor-based. Never manually increment offsets.

**Query parameters** (on paginated endpoints only):
- `offset`: Value from previous response's `next` field
- `limit`: 1-50, default 50
- `direction`: `forward` (default, chronological) or `backward`/`back` (reverse)

**Three offset types:**

| Offset Type | Endpoints | Format | Example `next` |
|------------|-----------|--------|-----------------|
| Score (u64) | `/nfts`, `/ops`, `/deployments`, `/history/:tick/:id` | Numeric string | `24907845280005` |
| TokenId (u64) | `/owners/:tick`, `/address/:address/:tick` | Numeric | `4`, `10` |
| TickTokenOffset | `/address/:address` | String `"TICK-id"` | `"NACHO-10"` |

**Pagination loop:**

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

### All 16 Endpoints

#### 1. GET /status
Indexer health, sync status, network statistics. Not paginated.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/status
```

Response fields: `version`, `network`, `isNodeConnected` (bool), `isNodeSynced` (bool), `isIndexerSynced` (bool), `lastKnownBlockHash`, `blueScore`, `currentOpScore`, `daaScore`, `powFeesTotal` (SOMPI), `royaltyFeesTotal` (SOMPI), `tokenDeploymentsTotal`, `tokenMintsTotal`, `tokenTransfersTotal`

#### 2. GET /nfts
All deployed collections. **Paginated (Score).**

```bash
curl "https://krc721.kat.foundation/api/v1/krc721/mainnet/nfts?limit=2"
```

Result array fields: `deployer`, `royaltyTo`, `buri`, `metadata`, `max`, `royaltyFee`, `daaMintStart`, `premint`, `tick`, `txIdRev`, `mtsAdd`, `minted`, `opScoreMod`, `state`, `mtsMod`, `opScoreAdd`

#### 3. GET /nfts/:tick
Single collection details. Not paginated. Same fields as `/nfts` list item.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/nfts/NACHO
```

#### 4. GET /nfts/:tick/:id
Single token with current owner. Not paginated.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/nfts/NACHO/1
```

Result fields: `tick`, `tokenId`, `owner`, `opScoreMod`, `buri` or `metadata`

#### 5. GET /owners/:tick
All token owners in a collection. **Paginated (TokenId).**

```bash
curl "https://krc721.kat.foundation/api/v1/krc721/mainnet/owners/NACHO?limit=3"
```

Result array fields: `tick`, `tokenId`, `owner`, `opScoreMod`

#### 6. GET /address/:address
All NFTs owned by an address across all collections. **Paginated (TickTokenOffset).**

```bash
curl "https://krc721.kat.foundation/api/v1/krc721/mainnet/address/kaspa:qplfvwnt6ywwjz76d3358anh0kuymmamfr8ec86907rpfjygzp0ex4d283q3d?limit=3"
```

Result array fields: `tick`, `buri`, `tokenId`, `opScoreMod`

**CRITICAL**: The offset for this endpoint is a string in `"TICK-tokenId"` format (e.g. `"NACHO-10"`), not a number.

#### 7. GET /address/:address/:tick
NFTs owned by an address in a specific collection. **Paginated (TokenId).**

```bash
curl "https://krc721.kat.foundation/api/v1/krc721/mainnet/address/kaspa:qplfvwnt6ywwjz76d3358anh0kuymmamfr8ec86907rpfjygzp0ex4d283q3d/NACHO?limit=3"
```

Result array fields: `tick`, `tokenId`, `opScoreMod`

#### 8. GET /royalties/:address/:tick
Royalty fee (in SOMPI) that a specific address must pay to mint from a collection. **Not paginated.** Returns a single string.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/royalties/kaspa:qplfvwnt6ywwjz76d3358anh0kuymmamfr8ec86907rpfjygzp0ex4d283q3d/NACHO
```

```json
{"message":"success","result":"212000000000"}
```

#### 9. GET /deployments
All deployment operations. **Paginated (Score).**

```bash
curl "https://krc721.kat.foundation/api/v1/krc721/mainnet/deployments?limit=1&direction=backward"
```

Result array fields: `deployer`, `royalty_to` (snake_case), `buri`, `max`, `royaltyFee`, `daaMintStart`, `premint`, `tick`, `txIdRev`, `mtsAdd`, `opScore`

> Note: Uses snake_case `royalty_to` (not `royaltyTo`). `opScore` may appear as a raw number.

#### 10. GET /ops
All operations (deploy, mint, transfer, discount). **Paginated (Score).**

```bash
curl "https://krc721.kat.foundation/api/v1/krc721/mainnet/ops?limit=1"
```

Result array fields: `p`, `deployer`, `royalty_to`/`to`, `tick`, `txIdRev`, `mtsAdd`, `op`, `opData`, `opScore`, `feeRev`, `opError` (only on failures)

Operation types: `"deploy"`, `"mint"`, `"transfer"`, `"discount"`

`opData` varies by operation type:
- **deploy**: `{ buri, max, royaltyFee, daaMintStart, premint }`
- **mint**: `{ tokenId, royalty?: { royaltyFee } }`
- **transfer**: `{ tokenId }`
- **discount**: `{ to, discountFee }`

#### 11. GET /ops/score/:score
Single operation by its unique operation score. Not paginated.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/ops/score/24907687056003
```

#### 12. GET /ops/txid/:txid
Single operation by transaction ID. Not paginated.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/ops/txid/3b15799a3e3041fe692890352f9d60de5e487c6f6d63ee5c2310b872ba5b49af
```

#### 13. GET /rejections/txid/:txid
Rejection reason for a failed operation. Not paginated.

Returns `{"message":"success","result":"InsufficientFee"}` if rejection exists.
Returns HTTP 404 with `Content-Type: text/plain` body `"not found"` if no rejection.

#### 14. GET /reserved
Reserved ticker names that cannot be deployed. Not paginated. Returns a string array.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/reserved
```

#### 15. GET /history/:tick/:id
Ownership history of a specific token. **Paginated (Score).**

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/history/NACHO/1
```

Result array fields: `owner`, `opScoreMod`, `txIdRev`

#### 16. GET /ranges/:tick
Available token ID ranges for minting. Not paginated. Returns a comma-separated string of `start,size` pairs.

```bash
curl https://krc721.kat.foundation/api/v1/krc721/mainnet/ranges/NACHO
```

Returns `""` when fully minted, or `"100,50,200,20"` meaning IDs 100-149 and 200-219 are available.

---

## Part 4: Field Reference

### Collection Fields

| Field | Type | Description |
|-------|------|-------------|
| `tick` | string | Ticker symbol (1-10 alphanumeric) |
| `deployer` | string | Deployer Kaspa address |
| `royaltyTo` | string or null | Royalty beneficiary address |
| `buri` | string or null | Base URI for external metadata (IPFS CID) |
| `metadata` | object or null | Inscribed metadata object |
| `max` | uint64 string | Maximum supply |
| `minted` | uint64 string | Number of tokens minted so far |
| `premint` | uint64 string | Number of pre-minted tokens |
| `daaMintStart` | uint64 string | DAA score when minting becomes available |
| `royaltyFee` | uint64 string or null | Royalty fee per mint (SOMPI) |
| `state` | string | Collection state (`"deployed"`) |
| `txIdRev` | string | Deployment transaction ID (reversed hex) |
| `mtsAdd` | uint64 string | Timestamp when deployed (ms since epoch) |
| `mtsMod` | uint64 string | Timestamp when last modified |
| `opScoreAdd` | uint64 string | Operation score at deployment |
| `opScoreMod` | uint64 string | Operation score at last modification |

### Token Fields

| Field | Type | Description |
|-------|------|-------------|
| `tick` | string | Collection ticker |
| `tokenId` | uint64 string | Token ID within collection |
| `owner` | string | Current owner Kaspa address |
| `opScoreMod` | uint64 string | Operation score at last ownership change |
| `buri` | string or null | Base URI (present in some endpoints) |

### Operation Fields

| Field | Type | Description |
|-------|------|-------------|
| `p` | string | Protocol identifier (`"krc-721"`) |
| `op` | string | Operation type: `"deploy"`, `"mint"`, `"transfer"`, `"discount"` |
| `tick` | string | Collection ticker |
| `deployer` | string | Deployer/sender address |
| `royalty_to` | string or null | Royalty beneficiary (snake_case in ops) |
| `to` | string or null | Recipient address (mint/transfer) |
| `opScore` | uint64 string | Unique operation score |
| `txIdRev` | string | Transaction ID (reversed hex) |
| `mtsAdd` | uint64 string | Timestamp (ms since epoch) |
| `feeRev` | uint64 string | Fee paid (SOMPI) |
| `opError` | string or null | Error message if operation failed (e.g. `"InsufficientFee"`) |
| `opData` | object | Operation-specific data (varies by `op` type) |

### Special Field Explanations

- **`opScore` / `opScoreAdd` / `opScoreMod`**: Unique chronological operation identifiers (u64). Higher = more recent. Used as Score-type pagination cursors.
- **`daaScore` / `daaMintStart`**: Kaspa's Difficulty Adjustment Algorithm score representing blockchain time/progress.
- **`mtsAdd` / `mtsMod`**: Milliseconds since Unix epoch. Convert: `new Date(parseInt(mtsAdd))`.
- **`txIdRev`**: Transaction ID with reversed byte order (64-char hex). Internal optimization for lexicographic ordering.
- **`feeRev`**: Fee paid in SOMPI for the operation's reveal transaction.
- **`state`**: Currently only `"deployed"` for active collections.

### Field Naming Conventions

- `op` = operation, `mts` = milliseconds timestamp, `daa` = Difficulty Adjustment Algorithm
- `rev` = reversed, `mod` = modified, `add` = added, `buri` = base URI
- Collection endpoints use camelCase `royaltyTo`; operation endpoints use snake_case `royalty_to`

---

## Part 5: Error Handling

| HTTP Status | Content-Type | Meaning |
|-------------|--------------|---------|
| 200 | application/json | Success |
| 400 | application/json | Bad request (invalid params, malformed URL) |
| 403 | — | IP filtering (if enabled) |
| 404 | text/plain | Resource not found (body: `"not found"`) |
| 404 | application/json | Resource not found (JSON envelope) |
| 429 | — | Rate limited (if enabled) |
| 500 | text/plain | Server error |

The 404 content type depends on the endpoint: single-resource lookups (`to_json`) return `text/plain`; other errors return JSON.

**Robust error handling pattern:**

```typescript
async function apiCall<T>(url: string): Promise<T | null> {
    const response = await fetch(url);
    const contentType = response.headers.get('content-type');

    if (contentType?.includes('application/json')) {
        const data = await response.json();
        if (response.status === 404 || data.message === 'not found') return null;
        if (data.message !== 'success') throw new Error(`API: ${data.message}`);
        return data.result;
    } else {
        const text = await response.text();
        if (response.status === 404) return null;
        throw new Error(`HTTP ${response.status}: ${text}`);
    }
}
```

---

## Part 6: Serialization Inconsistencies

Be aware of these when parsing responses:

1. **`royaltyTo` vs `royalty_to`**: Collection endpoints (`/nfts`) use camelCase; operation endpoints (`/ops`, `/deployments`) use snake_case.
2. **`opScore` type**: Usually a string, but `/deployments` may return it as a raw JSON number.
3. **`next` field**: Omitted entirely (not `null`) when no more pages exist.
4. **`buri` field presence**: Included in `/address/:address` results but not in `/address/:address/:tick` results.

---

## Part 7: TypeScript Interfaces

```typescript
type SOMPI = string;    // uint64 as string
type DAA = string;      // uint64 as string
type U64 = string;      // uint64 as string
type Address = string;  // Kaspa address with prefix

type UserOperation = Deploy | Mint | Transfer | Discount;

interface Deploy {
    p: 'krc-721';
    op: 'deploy';
    tick: string;
    buri: string | undefined;
    metadata: Metadata | undefined;
    max: U64 | undefined;
    royaltyTo: Address | undefined;
    royaltyFee: SOMPI | undefined;
    daaMintStart: DAA | undefined;
    premint: U64 | undefined;
}

interface Mint {
    p: 'krc-721';
    op: 'mint';
    tick: string;
    to: Address | undefined;
}

interface Transfer {
    p: 'krc-721';
    op: 'transfer';
    tick: string;
    tokenid: string | undefined;
    to: Address | undefined;
}

interface Discount {
    p: 'krc-721';
    op: 'discount';
    tick: string;
    to: Address | undefined;
    discountFee: SOMPI;
}

interface Metadata {
    name: string;
    description: string;
    image: string;
    attributes: Attribute[];
}

interface Attribute {
    traitType: string;
    value: string;
    displayType?: string;
}
```

## Part 8: Rust Data Structures

```rust
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OpDeploy {
    #[serde(rename = "p")]
    pub protocol: String,
    pub op: Op,
    pub tick: String,
    #[serde(flatten)]
    pub metadata: Metadata,
    #[serde_as(as = "DisplayFromStr")]
    pub max: u64,
    #[serde(default, rename = "royaltyTo", skip_serializing_if = "Option::is_none")]
    pub royalty_to: Option<String>,
    #[serde(default, rename = "royaltyFee", skip_serializing_if = "Option::is_none")]
    #[serde_as(as = "Option<DisplayFromStr>")]
    pub royalty_fee: Option<u64>,
    #[serde(rename = "daaMintStart", skip_serializing_if = "Option::is_none")]
    #[serde_as(as = "Option<DisplayFromStr>")]
    pub daa_mint_start: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    #[serde_as(as = "Option<DisplayFromStr>")]
    pub premint: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub to: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OpMint {
    #[serde(rename = "p")]
    pub protocol: String,
    pub op: Op,
    pub tick: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub to: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OpTransfer {
    #[serde(rename = "p")]
    pub protocol: String,
    pub op: Op,
    pub tick: String,
    #[serde(rename = "id")]
    #[serde_as(as = "DisplayFromStr")]
    pub tokenid: u64,
    pub to: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OpDiscount {
    #[serde(rename = "p")]
    pub protocol: String,
    pub op: Op,
    pub tick: String,
    pub to: String,
    #[serde_as(as = "DisplayFromStr")]
    #[serde(rename = "discountFee")]
    pub fee: u64,
}

#[derive(Debug, Clone, Copy, Eq, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Op { Deploy, Mint, Transfer, Discount }

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Metadata {
    #[serde(rename = "buri")]
    Remote(String),
    #[serde(rename = "metadata")]
    Local(LocalMetadata),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LocalMetadata {
    pub name: String,
    pub description: String,
    pub image: String,
    pub attributes: Option<Vec<Attribute>>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Attribute {
    #[serde(rename = "traitType")]
    pub trait_type: String,
    pub value: String,
    #[serde(skip_serializing_if = "Option::is_none", rename = "displayType")]
    pub display_type: Option<String>,
}
```

Serialization dependencies:
```toml
[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
serde_with = "3.8"
```

---

## Part 9: Common Patterns

**Check if indexer is synced before querying:**
```bash
curl -s .../status | jq '.result.isIndexerSynced'
```

**Get latest operations:**
```bash
curl ".../ops?limit=10&direction=backward"
```

**Check if a collection is fully minted:**
```bash
curl -s .../ranges/NACHO | jq '.result == ""'
```

**Get all tokens owned by an address (full pagination):**
```bash
curl ".../address/kaspa:qplfvwnt6...?limit=50"
# If response has "next": "NACHO-10", continue:
curl ".../address/kaspa:qplfvwnt6...?limit=50&offset=NACHO-10"
# Repeat until "next" is absent
```

**Check royalty fee before minting:**
```bash
curl ".../royalties/kaspa:qMyAddress.../NACHO"
# Result is the SOMPI amount to include as first output of mint reveal tx
```

**Parse available ranges for minting:**
```javascript
function parseRanges(rangeString) {
    if (!rangeString) return [];
    const parts = rangeString.split(',');
    const ranges = [];
    for (let i = 0; i < parts.length; i += 2) {
        ranges.push({ start: parseInt(parts[i]), size: parseInt(parts[i + 1]) });
    }
    return ranges;
}
// "100,50,200,20" -> [{start:100, size:50}, {start:200, size:20}]
```

**Convert SOMPI to KAS:**
```javascript
function sompiToKas(sompi) { return parseFloat(sompi) / 1e8; }
// "212000000000" -> 2120 KAS
```
