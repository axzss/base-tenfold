# Base Contracts Deployed

A minimal Foundry project that deploys 10 instances of a single-slot
`Minimal` contract to Base in one broadcast, then auto-verifies on Basescan.

## Layout

```
.
├── foundry.toml          # optimizer + Basescan verifier config
├── remappings.txt        # explicit forge-std path for IDEs
├── Makefile              # common dev tasks (build, test, deploy, verify)
├── .env.example          # template for local secrets
├── .gitignore            # build artefacts, secrets, editor cruft
├── .gitattributes        # LF line endings + linguist stats
├── .editorconfig         # cross-editor formatting
├── LICENSE               # MIT
├── src/Minimal.sol       # single-slot, gas-optimized contract
└── script/Deploy.s.sol   # 10x deploy loop in a single broadcast
```

## Gas profile (`Minimal.sol`)

| Action                | Approx gas (Base)  |
| --------------------- | ------------------ |
| Deploy                | ~130k              |
| `set(uint256)` (warm) | ~22.7k             |
| `x()` getter (warm)   | ~2.1k              |

Optimizations applied:
- `pragma solidity 0.8.24` + `evm_version = "cancun"`
- `optimizer = true` with `optimizer_runs = 1_000_000` (min runtime gas)
- `via_ir = true` (smaller bytecode, fewer JUMPs)
- Single packed storage slot (no other vars to share the slot)
- `external` setter, `calldata` param, no memory copy
- `unchecked` loop counter in the deploy script
- No constructor, no events, no strings, no fallback/receive

## One-time setup

```bash
cp .env.example .env
# fill PRIVATE_KEY and BASESCAN_API_KEY, then:
make install                # runs `forge install foundry-rs/forge-std --no-commit`
```

## Quick reference (`make help`)

| Target              | What it does                                            |
| ------------------- | ------------------------------------------------------- |
| `make build`        | compile contracts                                       |
| `make test`         | run unit tests                                          |
| `make test-gas`     | run tests with gas report                               |
| `make fmt`          | auto-format Solidity                                    |
| `make fmt-check`    | check formatting (CI gate)                              |
| `make snapshot`     | write `.gas-snapshot`                                   |
| `make clean`        | remove `out/`, `cache/`, `broadcast/`                   |
| `make deploy-sepolia` | deploy 10x on Base Sepolia + auto-verify             |
| `make deploy-mainnet` | deploy 10x on Base mainnet + auto-verify             |
| `make verify-sepolia ADDR=0x...` | re-verify a single deployment on Sepolia   |
| `make verify-mainnet ADDR=0x...` | re-verify a single deployment on mainnet   |

## Deploy + verify

Base mainnet:

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url base \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

Base Sepolia (testnet):

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url base_sepolia \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

The 10 deployments share a single signature envelope (one `startBroadcast`/
`stopBroadcast` frame), but produce 10 separate on-chain transactions in
nonce order.

## Dry run (no broadcast)

```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url base_sepolia
```

## Security: `.env` and private keys

`PRIVATE_KEY` in `.env` is loaded directly by `vm.envUint`. It never touches
git as long as `.env` is in `.gitignore` (it is, in this template).

Use a burner wallet. If `.env` leaks, that key is gone. Do not reuse it for
funds or for signing other contracts.

For mainnet, sign with hardware. `--account` (Cast keystore), `--ledger`, or
`--trezor` keep the key off disk entirely. `PRIVATE_KEY` in a plaintext env
file is fine for a testnet mission. It is not fine for a wallet that holds
real money.

Keep `.env` off cloud sync. No iCloud, Drive, Dropbox, or GitHub Actions
secrets unless scoped read-only to a CI job that's destroyed after the run.
And no screenshots.

A leaked key cannot be recovered. Move funds and revoke roles immediately.

Before you `git add .`, check `git status` and `git log -p -- .env`. If the
file slipped out of `.gitignore`, you want to know before the push.
