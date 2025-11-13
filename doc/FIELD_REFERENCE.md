# API Field Reference

Complete reference for all fields in KRC-721 API responses.

## Common Response Fields

### Response Wrapper

All API responses follow this structure:

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `message` | `string` | Human-readable message describing the result | `"success"` or `"not found"` |
| `result` | `object` or `array` | The actual response data (null if error) | See endpoint-specific docs |
| `next` | `string` or `null` | Pagination offset for next page (null if no more pages) | `"13000000000000"` or `null` |

**Note**: When `message` is `"success"` and HTTP status is `200`, the request succeeded.

## Indexer Status Fields

**Endpoint**: `/api/v1/krc721/{network}/status`

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `version` | `string` | Indexer version | `"2.0.0"` |
| `network` | `string` | Network identifier | `"mainnet"` or `"testnet-10"` |
| `isNodeConnected` | `boolean` | Whether Kaspa node is connected | `true` |
| `isNodeSynced` | `boolean` | Whether Kaspa node is synced | `true` |
| `isIndexerSynced` | `boolean` | Whether indexer is synced | `true` |
| `lastKnownBlockHash` | `string` or `null` | Last known block hash (hex) | `"abc123..."` or `null` |
| `blueScore` | `string` | Current blue score (uint64 as string) | `"1312860"` |
| `currentOpScore` | `string` | Current operation score (uint64 as string) | `"13000000000000"` |
| `daaScore` | `string` | Current DAA score (uint64 as string) | `"1312860"` |
| `powFeesTotal` | `string` | Total PoW fees collected (SOMPI, uint64 as string) | `"100000000000"` |
| `royaltyFeesTotal` | `string` | Total royalty fees collected (SOMPI, uint64 as string) | `"50000000000"` |
| `tokenDeploymentsTotal` | `string` | Total number of collections deployed (uint64 as string) | `"150"` |
| `tokenMintsTotal` | `string` | Total number of tokens minted (uint64 as string) | `"50000"` |
| `tokenTransfersTotal` | `string` | Total number of transfers (uint64 as string) | `"12000"` |

## Collection Fields

### Collection List Item (`/nfts`)

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `tick` | `string` | Collection ticker symbol (1-10 alphanumeric) | `"FOO"` |
| `deployer` | `string` | Deployer Kaspa address | `"kaspa:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqhqrxplya"` |
| `royaltyTo` | `string` or `null` | Royalty beneficiary address (if royalties enabled) | `"kaspa:..."` or `null` |
| `buri` | `string` or `null` | Base URI for metadata (IPFS CID) | `"ipfs://Qm..."` or `null` |
| `metadata` | `object` or `null` | Inscribed metadata object (if not using buri) | See Metadata Object below |
| `max` | `string` | Maximum supply (uint64 as string) | `"1000"` |
| `minted` | `string` | Number of tokens minted (uint64 as string) | `"456"` |
| `premint` | `string` | Number of pre-minted tokens (uint64 as string) | `"10"` |
| `daaMintStart` | `string` | DAA score when minting starts (uint64 as string) | `"525037124"` |
| `royaltyFee` | `string` or `null` | Royalty fee per mint (SOMPI, uint64 as string) | `"1000000000"` or `null` |
| `state` | `string` | Collection state | `"deployed"` |
| `txIdRev` | `string` | Deployment transaction ID (reversed byte order, hex) | `"0000000000000000000000000000000000000000000000000000000000000000"` |
| `mtsAdd` | `string` | Timestamp when collection was added (milliseconds, uint64 as string) | `"1712808987852"` |
| `mtsMod` | `string` | Timestamp when collection was last modified (milliseconds, uint64 as string) | `"1712808987852"` |
| `opScoreAdd` | `string` | Operation score when collection was deployed (uint64 as string) | `"13000000000000"` |
| `opScoreMod` | `string` | Operation score when collection was last modified (uint64 as string) | `"13000000000000"` |

### Collection Details (`/nfts/{tick}`)

Same fields as Collection List Item, plus all fields are always present (not flattened).

## Token Fields

### Token (`/nfts/{tick}/{id}`)

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `tick` | `string` | Collection ticker symbol | `"FOO"` |
| `tokenId` | `string` | Token ID within collection (uint64 as string) | `"123"` |
| `owner` | `string` | Current owner Kaspa address | `"kaspa:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqhqrxplya"` |
| `buri` | `string` or `null` | Base URI for token metadata (IPFS CID) | `"ipfs://Qm..."` or `null` |
| `metadata` | `object` or `null` | Inscribed metadata (if collection uses inscribed metadata) | See Metadata Object below |

**Note**: Token metadata URI is typically `{buri}/{tokenId}` for external metadata, or uses collection's inscribed metadata.

### Token Owner (`/owners/{tick}`)

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `tick` | `string` | Collection ticker symbol | `"FOO"` |
| `tokenId` | `string` | Token ID (uint64 as string) | `"123"` |
| `owner` | `string` | Owner Kaspa address | `"kaspa:..."` |
| `opScoreMod` | `string` | Operation score when ownership was last modified (uint64 as string) | `"13000000000000"` |

## Address Holdings Fields

### Address NFT Info (`/address/{address}`)

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `tick` | `string` | Collection ticker symbol | `"FOO"` |
| `tokenId` | `string` | Token ID (uint64 as string) | `"123"` |
| `buri` | `string` or `null` | Base URI for metadata (IPFS CID) | `"ipfs://Qm..."` or `null` |
| `metadata` | `object` or `null` | Inscribed metadata (if collection uses inscribed metadata) | See Metadata Object below |
| `opScoreMod` | `string` | Operation score when ownership was last modified (uint64 as string) | `"13000000000000"` |

### Address Collection Holdings (`/address/{address}/{tick}`)

Same as Address NFT Info, but filtered to a specific collection.

## Operation Fields

### Operation (`/ops`, `/ops/score/{id}`, `/ops/txid/{txid}`)

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `p` | `string` | Protocol identifier | `"krc-721"` |
| `op` | `string` | Operation type | `"deploy"`, `"mint"`, `"transfer"`, or `"discount"` |
| `tick` | `string` | Collection ticker symbol | `"FOO"` |
| `deployer` | `string` | Deployer address (for deploy operations) | `"kaspa:..."` |
| `royaltyTo` | `string` or `null` | Royalty beneficiary (for deploy operations with royalties) | `"kaspa:..."` or `null` |
| `to` | `string` or `null` | Recipient address (for mint/transfer operations) | `"kaspa:..."` or `null` |
| `opScore` | `string` | Operation score (uint64 as string) | `"13000000000000"` |
| `txIdRev` | `string` | Transaction ID (reversed byte order, hex) | `"0000000000000000000000000000000000000000000000000000000000000000"` |
| `mtsAdd` | `string` | Timestamp when operation was added (milliseconds, uint64 as string) | `"1712808987852"` |
| `feeRev` | `string` | Fee paid (SOMPI, uint64 as string) | `"10000000000"` |
| `opError` | `string` or `null` | Error message if operation failed | `"InsufficientFee"` or `null` |
| `opData` | `object` | Operation-specific data | See Operation Data below |

### Operation Data (`opData`)

The `opData` field structure depends on the operation type:

#### Deploy Operation Data

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `buri` | `string` or `null` | Base URI for metadata (IPFS CID) | `"ipfs://Qm..."` or `null` |
| `metadata` | `object` or `null` | Inscribed metadata object | See Metadata Object below |
| `max` | `string` | Maximum supply (uint64 as string) | `"1000"` |
| `royaltyFee` | `string` or `null` | Royalty fee per mint (SOMPI, uint64 as string) | `"1000000000"` or `null` |
| `daaMintStart` | `string` | DAA score when minting starts (uint64 as string) | `"525037124"` |
| `premint` | `string` | Number of pre-minted tokens (uint64 as string) | `"10"` |

#### Mint Operation Data

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `tokenId` | `string` | Token ID minted (uint64 as string) | `"123"` |
| `to` | `string` | Recipient address | `"kaspa:..."` |

#### Transfer Operation Data

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `tokenId` | `string` | Token ID transferred (uint64 as string) | `"123"` |
| `to` | `string` | Recipient address | `"kaspa:..."` |

#### Discount Operation Data

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `to` | `string` | Address receiving discount | `"kaspa:..."` |
| `discountFee` | `string` | Discounted fee amount (SOMPI, uint64 as string) | `"500000000"` |

## Ownership History Fields

### History Entity (`/history/{tick}/{id}`)

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `owner` | `string` | Owner Kaspa address at this point in history | `"kaspa:..."` |
| `opScoreMod` | `string` | Operation score when ownership changed (uint64 as string) | `"13000000000000"` |
| `txIdRev` | `string` | Transaction ID of the transfer (reversed byte order, hex) | `"0000000000000000000000000000000000000000000000000000000000000000"` |

## Metadata Object

When a collection uses inscribed metadata (not `buri`), the metadata object structure is:

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `name` | `string` | Collection name | `"Artsy Kaspa"` |
| `description` | `string` | Collection description | `"Bring NFT to Kaspa"` |
| `image` | `string` | Collection image URI (IPFS CID) | `"ipfs://Qm..."` |
| `attributes` | `array` or `null` | Array of attribute objects | See Attribute Object below |

### Attribute Object

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `traitType` | `string` | Trait name/type | `"Background"`, `"Eyes"`, `"Rarity"` |
| `value` | `string` | Trait value | `"Blue"`, `"Gold"`, `"Rare"` |
| `displayType` | `string` or `null` | Display hint (optional) | `"date"`, `"boost_percentage"`, or `null` |

## Special Field Explanations

### Score Fields

**Operation Scores** (`opScore`, `opScoreAdd`, `opScoreMod`):
- Unique identifier for operations in chronological order
- Used for pagination in score-based endpoints
- Format: Unsigned 64-bit integer (string representation)
- Higher values = more recent operations

**DAA Score** (`daaScore`, `daaMintStart`):
- Kaspa's Difficulty Adjustment Algorithm score
- Represents blockchain time/progress
- Format: Unsigned 64-bit integer (string representation)
- Used to determine when minting can start (`daaMintStart`)

### Timestamp Fields

**`mtsAdd`** (Milliseconds Timestamp Added):
- Timestamp when item was added to the indexer
- Format: Milliseconds since Unix epoch (uint64 as string)
- Example: `"1712808987852"` = May 10, 2024

**`mtsMod`** (Milliseconds Timestamp Modified):
- Timestamp when item was last modified
- Format: Milliseconds since Unix epoch (uint64 as string)

### Transaction ID Fields

**`txIdRev`** (Transaction ID Reversed):
- Transaction ID with bytes in reverse order
- Format: 64-character hexadecimal string
- Example: `"0000000000000000000000000000000000000000000000000000000000000000"`

**Why reversed?** Internal database optimization for lexicographic ordering.

### Amount Fields

All amounts are in **SOMPI** (10^-8 KAS):
- Format: Unsigned 64-bit integer (string representation)
- To convert to KAS: `sompi / 100000000`
- Examples:
  - `"100000000"` = 1 KAS
  - `"10000000000"` = 100 KAS
  - `"1000000000"` = 10 KAS

### State Fields

**`state`** (Collection State):
- Possible values: `"deployed"`
- Indicates collection deployment status

### Collection State Values

- `"deployed"`: Collection is active and can accept mints/transfers

## Field Naming Conventions

- **camelCase**: Most fields use camelCase (e.g., `tokenId`, `opScoreMod`)
- **Abbreviations**: Common abbreviations:
  - `op` = operation
  - `mts` = milliseconds timestamp
  - `daa` = Difficulty Adjustment Algorithm
  - `rev` = reversed
  - `mod` = modified
  - `add` = added
  - `buri` = base URI

## Data Type Notes

- **All numeric fields** are returned as strings to avoid JavaScript number precision issues
- **All addresses** are Kaspa addresses with network prefix (e.g., `kaspa:...` or `kaspatest:...`)
- **All IPFS URIs** must start with `ipfs://` prefix
- **All transaction IDs** are 64-character hexadecimal strings (may be reversed)

## Common Patterns

### Checking for Optional Fields

```javascript
// Check if field exists and has value
if (collection.royaltyTo) {
  // Royalties are enabled
}

// Check for null/undefined
if (collection.buri === null || collection.buri === undefined) {
  // Using inscribed metadata instead
}
```

### Converting Amounts

```javascript
// Convert SOMPI to KAS
function sompiToKas(sompi) {
  return parseFloat(sompi) / 100000000;
}

// Example
const royaltyFeeKas = sompiToKas(collection.royaltyFee); // 10 KAS
```

### Working with Timestamps

```javascript
// Convert milliseconds timestamp to Date
const addedDate = new Date(parseInt(collection.mtsAdd));
```

### Parsing Available Ranges

```javascript
// Parse available token ID ranges
function parseRanges(rangeString) {
  if (!rangeString) return []; // Fully minted
  
  const parts = rangeString.split(',');
  const ranges = [];
  for (let i = 0; i < parts.length; i += 2) {
    ranges.push({
      start: parseInt(parts[i]),
      size: parseInt(parts[i + 1])
    });
  }
  return ranges;
}

// Example: "100,50,200,20" = [{start: 100, size: 50}, {start: 200, size: 20}]
```

## See Also

- [REST.md](./REST.md) - Complete API endpoint documentation
- [PAGINATION.md](./PAGINATION.md) - Pagination guide
- [KRC-721.md](./KRC-721.md) - Protocol specification

