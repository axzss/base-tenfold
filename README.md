# Base Contracts Deployed

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Solidity 0.8.24](https://img.shields.io/badge/Solidity-0.8.24-blue.svg)]()
[![Foundry 1.7+](https://img.shields.io/badge/Foundry-1.7+-green.svg)]()

A Foundry project that deploys ten instances of a single-slot Solidity
contract to Base in a single broadcast, then auto-verifies each one on
Etherscan. Targets Base Sepolia (testnet) and Base mainnet.

## Overview

`src/Minimal.sol` is a gas-optimized contract: one `uint256` storage
variable with one external setter, no constructor, no events, no
fallback. `script/Deploy.s.sol` broadcasts ten `CREATE` transactions
inside a single `startBroadcast` / `stopBroadcast` envelope, then
submits the bytecode to Etherscan V2 for verification.

### Measured gas profile

| Operation              | Gas         |
| ---------------------- | ----------- |
| Deploy (single)        | 98,827      |
| Deploy (10 in batch)   | 988,270     |
| `set(uint256)` (cold)  | 43,458      |
| `set(uint256)` (warm)  | ~22,700     |
| `x()` getter (warm)    | ~2,100      |

`foundry.toml` sets `optimizer_runs = 1_000_000` and `via_ir = true` to
minimize runtime gas at the cost of a slightly larger deployment
bytecode.

## Quick start

### Prerequisites

- Foundry 1.7 or later (`forge`, `cast`, `anvil`)
- A wallet funded with ETH on the target network
- An [Etherscan API key](https://etherscan.io/myapikey) (free)

### Install

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

From the project root:

```bash
make install
```

### Configure

```bash
cp .env.example .env
```

| Variable               | Description                                                |
| ---------------------- | ---------------------------------------------------------- |
| `PRIVATE_KEY`          | Burner wallet, funded with Base ETH for gas                |
| `ETHERSCAN_API_KEY`    | Etherscan V2 key. One key works for all Etherscan chains  |
| `BASE_RPC_URL`         | Optional. Override the public RPC for mainnet              |
| `BASE_SEPOLIA_RPC_URL` | Optional. Override the public RPC for Sepolia              |

For legacy `.env` files with `BASESCAN_API_KEY`, run `make migrate-env`
to rename the variable. The key value is preserved.

## Deployment

### Base Sepolia (testnet)

```bash
make deploy-sepolia
```

Deploys ten contracts and submits verification requests to Etherscan.
Verification typically completes in under a minute but may queue
longer during high load. Output ends with `All (10) contracts were
verified!` on success.

### Base mainnet

```bash
make deploy-mainnet
```

The free Etherscan V2 tier covers Base Sepolia but not all mainnet
chains. For mainnet verification, either upgrade your Etherscan API
plan or pass `--verifier sourcify` to use the open-source Sourcify
verifier.

## Verification

The deployment script auto-verifies via the `forge script --verify`
flag. To re-verify contracts from a previous run without redeploying:

```bash
make verify
```

Finds the most recent broadcast file, detects the chain, and calls
`forge verify-contract` for each entry. For a single address:

```bash
make verify-sepolia ADDR=0xYourContractAddress
```

## Local development

```bash
anvil --port 8545 &
```

Anvil prints a list of pre-funded dev private keys on startup. Use one
to deploy against the local node:

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url http://localhost:8545 \
  --private-key $ANVIL_KEY \
  --broadcast
```

These keys are deterministic and valid only against a local anvil
instance. Do not use them on any real network.

## Commands

| Target                          | Description                                                |
| ------------------------------- | ---------------------------------------------------------- |
| `make install`                  | Install forge-std as a submodule                           |
| `make build`                    | Compile contracts                                          |
| `make test`                     | Run unit tests                                             |
| `make test-gas`                 | Run tests with gas reporting                               |
| `make deploy-sepolia`           | Deploy 10 contracts to Base Sepolia + auto-verify          |
| `make deploy-mainnet`           | Deploy 10 contracts to Base mainnet + auto-verify          |
| `make verify`                   | Verify all contracts from the most recent broadcast        |
| `make verify-sepolia ADDR=...`  | Verify a single address on Sepolia                         |
| `make verify-mainnet ADDR=...`  | Verify a single address on mainnet                         |
| `make reverify-sepolia`         | Re-verify all 10 contracts from the Sepolia broadcast file |
| `make reverify-mainnet`         | Re-verify all 10 contracts from the mainnet broadcast file |
| `make migrate-env`              | Rename `BASESCAN_API_KEY` to `ETHERSCAN_API_KEY` in `.env` |
| `make clean`                    | Remove `out/`, `cache/`, `broadcast/`                      |

Run `make help` for the complete list.

## Project structure

```
.
├── foundry.toml        # Optimizer + Etherscan V2 verifier config
├── remappings.txt      # forge-std path for IDEs
├── Makefile            # Common dev tasks
├── .env.example        # Environment template
├── .gitignore          # Build artifacts, secrets, editor files
├── .gitattributes      # Line endings + linguist settings
├── .editorconfig       # Cross-editor formatting
├── LICENSE             # MIT
├── src/Minimal.sol     # Single-slot gas-optimized contract
├── script/Deploy.s.sol # 10-deploy script in a single broadcast
└── lib/forge-std/      # Submodule, not tracked
```

## Security

`PRIVATE_KEY` in `.env` is loaded by `vm.envUint`. The file is in
`.gitignore` and will not be committed to version control as long as
that file remains in place. Additional precautions:

- Use a dedicated burner wallet. If the key leaks, the wallet is
  compromised. Do not reuse it for funds or other contracts.
- Sign mainnet deployments with hardware. `--ledger`, `--trezor`, or a
  Cast keystore keep the key off disk. Plaintext `PRIVATE_KEY` in a
  `.env` file is appropriate for testnet only.
- Do not sync `.env` to cloud storage, paste it in chat, or include it
  in screenshots.
- If a key is compromised, move funds and revoke any granted roles
  immediately. A leaked key cannot be recovered.

## License

MIT. See [LICENSE](./LICENSE).
