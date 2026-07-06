## KRC-721 - Kaspa NFT indexer

This is an archive repository created for public access.

## Features

- NFT Collection deployments with pre-minting
- NFT minting
- NFT transfers
- Minimum PoW fees for indexer operations 
- Custom-definable royalty fees for content creators (collected during mints)
- Unlimited mints
- Randomized minting token order
- Fully compatible with Testnet-11 (10+ BPS)
- High-availability load-balancing (cluster mode operation)


## Installation

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

```bash
sudo apt update && sudo apt upgrade -y
```

```bash
sudo apt install jq curl git build-essential libssl-dev pkg-config \
protobuf-compiler libprotobuf-dev \
clang-format clang-tidy \
clang-tools clang clangd libc++-dev \
libc++1 libc++abi-dev libc++abi1 \
libclang-dev libclang1 liblldb-dev \
libllvm-ocaml-dev libomp-dev libomp5 \
lld lldb llvm-dev llvm-runtime \
llvm python3-clang
```

Optionally:

```bash
sudo apt install nginx
```

Configuration files can be found in the [`doc/deployment`](doc/deployment) directory.

## Documentation

- **[API Documentation](doc/README.md)** - Complete REST API documentation
- **[Running Guide](setup/RUNNING_GUIDE.md)** - Detailed setup and running instructions
- **[Setup Scripts](setup/)** - Automated setup and control scripts

## Running KRC-721 indexer daemon

### 🚀 Quick Start (Recommended)

For automated, unattended setup, use the setup scripts in the `setup/` directory:

```bash
# Automated setup (recommended)
./setup/setup-krc721-indexer.sh --mainnet

# Or for testnet-10
./setup/setup-krc721-indexer.sh --testnet-10
```

This script automates the complete setup process:
1. ✅ Syncs the Kaspa node (monitors for completion)
2. ✅ Purges any existing database (safety)
3. ✅ Syncs indexer state from remote
4. ✅ Starts the full indexer with HTTP server

**Check status anytime:**
```bash
./setup/krc721-indexer-ctl.sh status    # Check current status
./setup/krc721-indexer-ctl.sh logs      # View recent logs
./setup/krc721-indexer-ctl.sh tail      # Tail logs in real-time
./setup/krc721-indexer-ctl.sh stop      # Stop the indexer
```

📚 **For detailed instructions**, see [`setup/RUNNING_GUIDE.md`](setup/RUNNING_GUIDE.md)

### Manual Setup

You can also run the indexer manually. First, build the binary:

```bash
# Build the binary
cargo build --release

# Or run via cargo directly
cargo run --release -- --help
```

**IMPORTANT**: Before running the indexer, you must run and synchronize the integrated Rusty Kaspa node.
Once the node is synced, stop the indexer, sync its state with another indexer and restart it.
The sequence of these steps is important due to the fact that the Rusty Kaspa node may take a long
time to synchronize, resulting in the indexer state becoming outdated.

#### 1. Sync Kaspa node
```bash
./target/release/krc721d --mainnet --local
```

Wait for the node to fully sync (check logs for `SYNC: true`).

#### 2. Sync indexer state from another indexer
```bash
./target/release/krc721d --mainnet --sync=https://krc721.kat.foundation
```

#### 3. Start the indexer
```bash
./target/release/krc721d --mainnet --local --http
```

## Node Failure and Pruning

If the node fails for any reason, stopped or disconnected from the network, eventually the indexer state will become outdated.

- You can use `--retention-period-days` flag to extend the node pruning period
- You should run at least 2 instances to be able to recover one from another in case of a failure.

## Test Deployments

You should always run your own indexer in production mode. The following indexers are available for development purposes:

- https://krc721.kat.foundation
- https://krc721-testnet.kat.foundation

