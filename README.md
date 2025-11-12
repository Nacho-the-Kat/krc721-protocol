## KRC-721 - Kaspa NFT indexer

```
cargo run --release -- --remote --http --testnet-10 
```

```
https://testnet-10.krc721.stream
https://testnet-11.krc721.stream
```


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

Configuration files can be found in the [`doc/deployment`](`doc/deployment`) directory.