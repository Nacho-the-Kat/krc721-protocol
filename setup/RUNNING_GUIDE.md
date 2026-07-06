# KRC-721 Indexer - Complete Running Guide

This guide walks you through properly setting up and running the KRC-721 indexer following the correct sequence of operations.

## Prerequisites

1. ✅ Binary built: `target/release/krc721d` exists
2. ✅ Config file: `krc721d.toml` exists in the project root
3. ✅ Network: Choose either `--mainnet` or `--testnet-10`

## Important Notes

- **The sequence matters**: You must follow these steps in order
- **Kaspa node sync is slow**: The first step can take hours/days depending on network conditions
- **Database location**: Data is stored in `~/.krc721/` directory (network-specific subdirectories)
- **File descriptor limits**: The daemon requires at least 8,192 file descriptors (16,384 recommended)
- **Multiple networks**: You can run both mainnet and testnet-10 simultaneously on the same server (they use different ports)

## 🚀 Quick Start: Automated Setup (Recommended)

**For unattended setup** - Run the automated script and close your SSH session:

```bash
# Mainnet (default)
./setup/setup-krc721-indexer.sh --mainnet

# Or testnet-10
./setup/setup-krc721-indexer.sh --testnet-10

# Run in background with nohup (so you can close SSH)
nohup ./setup/setup-krc721-indexer.sh --mainnet > setup-output.log 2>&1 &
```

The script will:
1. ✅ Check prerequisites
2. ✅ Sync the Kaspa node (monitors for completion automatically)
3. ✅ Purge any existing database (safety measure)
4. ✅ Sync indexer state from remote
5. ✅ Start the full indexer with HTTP server

**Check status anytime:**
```bash
# List all running indexers
./setup/krc721-indexer-ctl.sh list

# Check specific network status
./setup/krc721-indexer-ctl.sh status --mainnet
./setup/krc721-indexer-ctl.sh status --testnet-10

# View logs for specific network
./setup/krc721-indexer-ctl.sh logs --mainnet
./setup/krc721-indexer-ctl.sh logs --testnet-10

# Tail logs in real-time
./setup/krc721-indexer-ctl.sh tail --mainnet
./setup/krc721-indexer-ctl.sh tail --testnet-10

# Stop specific network
./setup/krc721-indexer-ctl.sh stop --mainnet
./setup/krc721-indexer-ctl.sh stop --testnet-10
```

**Logs are saved to:** Network-specific directories:
- Mainnet: `setup/setup-logs-mainnet/`
- Testnet-10: `setup/setup-logs-testnet-10/`

You can safely close your SSH session - the script runs in the background and handles everything automatically.

### Running Multiple Networks Simultaneously

**✅ You can run both mainnet and testnet-10 indexers on the same server!**

The indexers use separate:
- **Ports**: Mainnet uses `8800` (HTTP) and `17110` (Kaspa wRPC), testnet-10 uses `8801` (HTTP) and `17210` (Kaspa wRPC)
- **Data directories**: `~/.krc721/mainnet/` vs `~/.krc721/testnet-10/`
- **Log directories**: `setup/setup-logs-mainnet/` vs `setup/setup-logs-testnet-10/`
- **Processes**: Each runs independently

**To run both networks:**

```bash
# Terminal 1: Start mainnet
./setup/setup-krc721-indexer.sh --mainnet

# Terminal 2: Start testnet-10 (in another terminal or background)
./setup/setup-krc721-indexer.sh --testnet-10

# Or run both in background
nohup ./setup/setup-krc721-indexer.sh --mainnet > mainnet-setup.log 2>&1 &
nohup ./setup/setup-krc721-indexer.sh --testnet-10 > testnet-setup.log 2>&1 &

# Check both
./setup/krc721-indexer-ctl.sh list
```

**No conflicts** - Each network operates completely independently with its own ports, data, and logs.

---

## Manual Step-by-Step Process

If you prefer to run each step manually, follow the instructions below:

### Step 1: Sync the Kaspa Node

**Purpose**: Start and synchronize the integrated Rusty Kaspa node with the blockchain.

**⚠️ IMPORTANT**: The command `--mainnet --local` starts BOTH the Kaspa node AND the indexer. Once the node syncs, the indexer will automatically start indexing and create a database. If this happens, you'll need to purge the database before Step 2.

**Option A: Monitor and Stop Manually (Recommended)**

**Command**:
```bash
./target/release/krc721d --mainnet --local
```

**What happens**:
- Starts the Rusty Kaspa daemon as a child process
- Starts the indexer (but it waits for node sync)
- Connects to the Kaspa network and begins syncing blocks
- Logs will show sync progress

**How to know when it's done**:
- Watch the logs for: `kaspad '1.0.0' on 'mainnet';  SYNC: true  DAA: <score>`
- When you see `SYNC: true`, the node is fully synced
- **STOP IMMEDIATELY** at this point (Ctrl+C) before the indexer starts indexing
- This can take many hours or even days for mainnet

**To stop**: Press `Ctrl+C` or send SIGTERM as soon as you see `SYNC: true`

**Option B: Use a Monitoring Script**

If you'll be away, you can create a simple script to monitor and auto-stop when sync completes:

```bash
# Create a monitoring script
cat > monitor_sync.sh << 'EOF'
#!/bin/bash
./target/release/krc721d --mainnet --local 2>&1 | tee sync.log &
PID=$!
echo "Started krc721d with PID: $PID"
echo "Monitoring for SYNC: true..."

# Monitor logs for sync completion
tail -f sync.log | while read line; do
    if echo "$line" | grep -q "SYNC: true"; then
        echo "Node is synced! Stopping..."
        kill $PID
        exit 0
    fi
done
EOF

chmod +x monitor_sync.sh
./monitor_sync.sh
```

**Note**: This approach still uses `--mainnet --local` but automatically stops when sync completes.

**Important**: 
- Do NOT proceed to step 2 until the Kaspa node is fully synced
- If the indexer started indexing (you'll see database activity), purge before Step 2:
  ```bash
  ./target/release/krc721d --mainnet --purge
  ```

---

### Step 2: Sync Indexer State from Another Indexer

**Purpose**: Download a snapshot of the indexer database from a remote indexer to bootstrap your local database.

**Command**:
```bash
./target/release/krc721d --mainnet --sync=https://krc721.kat.foundation
```

**What happens**:
- Downloads a snapshot archive from the remote indexer
- Restores the snapshot to your local database (`~/.krc721/data/`)
- This is much faster than indexing from scratch

**Requirements**:
- **Database must NOT exist** - If you have an existing database (from Step 1 if indexer started), you must purge it first:
  ```bash
  ./target/release/krc721d --mainnet --purge
  ```
- The Kaspa node from Step 1 should be synced (though it doesn't need to be running for this step)

**⚠️ If Step 1 Created a Database**: If you left Step 1 running and the indexer started indexing, you'll see database files in `~/.krc721/mainnet/`. You MUST purge before running sync:
```bash
# Check if database exists
ls -la ~/.krc721/mainnet/

# If it exists, purge it
./target/release/krc721d --mainnet --purge

# Then proceed with sync
./target/release/krc721d --mainnet --sync=https://krc721.kat.foundation
```

**How to know when it's done**:
- You'll see progress bars showing download and restore progress
- The process will exit with a success message when complete
- Check `~/.krc721/data/` to verify the database was created

**Note**: This step downloads a snapshot, so your indexer will be up-to-date as of that snapshot's creation time.

---

### Step 3: Start the Full Indexer

**Purpose**: Start both the Kaspa node and the indexer together, with HTTP server enabled.

**Command**:
```bash
./target/release/krc721d --mainnet --local --http
```

**What happens**:
- Starts the Rusty Kaspa daemon (if not already running)
- Starts the KRC-721 indexer
- Enables the HTTP server (default: `localhost:8800` for mainnet)
- The indexer will:
  - Connect to the Kaspa node
  - Verify the node is synced
  - Start processing blocks and indexing NFTs
  - Serve HTTP API requests

**Flags explained**:
- `--mainnet`: Operate on mainnet (use `--testnet-10` for testnet)
- `--local`: Spawn Rusty Kaspa daemon as child process
- `--http`: Enable HTTP server for API access

**Optional flags**:
- `--http-listen=0.0.0.0:8800`: Custom HTTP listen address
- `--rpc-listen=0.0.0.0:7878`: Custom wRPC listen address
- `--trace`: Enable trace-level logging
- `--debug`: Enable debug mode
- `--details`: Enable detailed logging

**How to verify it's working**:
- Check logs for "KRC721D - starting krc-721 indexer"
- Look for "HTTP server is enabled" message
- Verify node connection: "Connected to ws://localhost:..."
- Check sync status in logs
- Test HTTP endpoint:
  - Mainnet: `curl http://localhost:8800/api/v1/krc721/mainnet/status`
  - Testnet-10: `curl http://localhost:8801/api/v1/krc721/testnet-10/status`

**Default ports**:
- **Mainnet**:
  - HTTP API: `8800`
  - Kaspa wRPC: `17110`
  - Kaspa P2P: `16111`
- **Testnet-10**:
  - HTTP API: `8801`
  - Kaspa wRPC: `17210`
  - Kaspa P2P: `16211`

**Note**: These ports are automatically configured based on the network flag (`--mainnet` or `--testnet-10`).

---

## Troubleshooting

### Database exists error during sync
If you get "Database exists, please purge before syncing":
```bash
./target/release/krc721d --mainnet --purge
```
Then retry Step 2.

### Node not synced error
If the indexer complains the node isn't synced:
- Make sure Step 1 completed successfully
- Check that the Kaspa node is still running and synced
- You may need to wait longer for the node to sync

### File descriptor limit warnings
If you see warnings about file descriptor limits:
```bash
ulimit -n 16384
```
Or add to `/etc/security/limits.conf`:
```
* soft nofile 16384
* hard nofile 16384
```

### Checking sync status
You can check if your indexer is synced via HTTP:
```bash
# Mainnet
curl http://localhost:8800/api/v1/krc721/mainnet/status

# Testnet-10
curl http://localhost:8801/api/v1/krc721/testnet-10/status
```

The response will include `isNodeSynced` and `isIndexerSynced` fields.

---

## Alternative: Using Remote Node

If you don't want to run a local Kaspa node, you can use a remote node:

**Step 1**: Skip (no local node needed)

**Step 2**: Same sync command

**Step 3**: Use `--remote` instead of `--local`:
```bash
./target/release/krc721d --mainnet --remote --http
```

This connects to `wss://krc721.kat.foundation/kaspa/mainnet/wrpc/borsh` instead of running a local node.

---

## Production Considerations

1. **Run as a service**: Use systemd (see `doc/deployment/systemd.service`)
2. **Reverse proxy**: Use nginx (see `doc/deployment/nginx.conf`)
3. **Monitoring**: Monitor logs in `~/.krc721/logs/`
4. **Backups**: Regularly archive your database:
   ```bash
   ./target/release/krc721d --mainnet --archive=backup.krc721
   ```

---

## Quick Reference

### Automated Setup (Recommended)
```bash
# Mainnet
./setup/setup-krc721-indexer.sh --mainnet

# Testnet-10
./setup/setup-krc721-indexer.sh --testnet-10

# Check status
./setup/krc721-indexer-ctl.sh list
./setup/krc721-indexer-ctl.sh status --mainnet
./setup/krc721-indexer-ctl.sh status --testnet-10
```

### Manual Setup
```bash
# Step 1: Sync Kaspa node (takes hours/days)
./target/release/krc721d --mainnet --local
# or
./target/release/krc721d --testnet-10 --local

# Step 2: Sync indexer state (takes minutes)
./target/release/krc721d --mainnet --sync=https://krc721.kat.foundation
# or
./target/release/krc721d --testnet-10 --sync=https://krc721-testnet.kat.foundation

# Step 3: Start full indexer
./target/release/krc721d --mainnet --local --http
# or
./target/release/krc721d --testnet-10 --local --http

# Check status
curl http://localhost:8800/api/v1/krc721/mainnet/status
curl http://localhost:8801/api/v1/krc721/testnet-10/status

# View help
./target/release/krc721d --help
```

### Running Both Networks
```bash
# Start both networks (they use different ports, no conflicts)
./setup/setup-krc721-indexer.sh --mainnet &
./setup/setup-krc721-indexer.sh --testnet-10 &

# Monitor both
./setup/krc721-indexer-ctl.sh list
```

