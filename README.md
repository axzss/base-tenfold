# Base Contracts Deployed

A minimal Foundry project. Deploys 10 instances of a single-slot `Minimal`
contract to Base in one broadcast, then auto-verifies on Basescan. Verified
end-to-end on a local anvil node: 10 contracts deployed, `set(42)` → `x()`
round-trip works, broadcast artifact saved.

## Prerequisites

- **Foundry 1.7+** (`forge`, `cast`, `anvil`)
- A funded wallet on Base Sepolia for testnet, or Base mainnet for real
- A [Basescan API key](https://basescan.org/myapikey) for `--verify`

The git history assumes `lib/forge-std` is a submodule. If you cloned
without `--recurse-submodules`, run `git submodule update --init` first.

## Install

Foundry installs via the `foundryup` one-liner:

```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

Then, from the project root:

```bash
make install
```

That runs `forge install foundry-rs/forge-std`. You should end up with a
populated `lib/forge-std/` and a `.gitmodules` file pointing at it.

## Configure

Copy the env template and fill in real values:

```bash
cp .env.example .env
```

You need two things in `.env`:

| Variable            | Where to get it                                              |
| ------------------- | ------------------------------------------------------------ |
| `PRIVATE_KEY`       | A burner wallet. Export from MetaMask → Account details → "Show private key". Fund it with a small amount of Base ETH. |
| `ETHERSCAN_API_KEY` | [etherscan.io/myapikey](https://etherscan.io/myapikey). Free. One key works for all Etherscan-family chains via the V2 unified API. |

For a real deployment, the burner wallet should hold enough ETH for the gas
of 10 deploys plus a buffer. On Base, deploys cost roughly 0.0001 ETH at
current gas prices, so 0.001 ETH is plenty.

## Run locally first

Before paying for a real testnet deployment, exercise the script against
`anvil` (local node, free, deterministic):

```bash
# Terminal 1 — start the local node
anvil --port 8545

# Terminal 2 — deploy the 10 contracts (dry run, no broadcast)
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545
```

The first key printed by `anvil` is the well-known dev key
(`0xac0974bec...`) corresponding to address `0xf39Fd6...92266`. Pre-funded
with 10,000 ETH. Safe to use locally. Never use it on a real network.

To actually broadcast against `anvil` (writes to the local chain):

```bash
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  forge script script/Deploy.s.sol:DeployScript \
    --rpc-url http://localhost:8545 \
    --broadcast
```

You should see 10 contract addresses in the output, ending with:

```
ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
Transactions saved to: broadcast/Deploy.s.sol/31337/run-latest.json
```

Verify a contract responds by reading the storage slot:

```bash
cast call --rpc-url http://localhost:8545 <deployed_address> 'x()(uint256)'
# 0

cast send --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  <deployed_address> 'set(uint256)' 42

cast call --rpc-url http://localhost:8545 <deployed_address> 'x()(uint256)'
# 42
```

If all that works, the script is wired up correctly.

## Deploy to Base

### Base Sepolia (testnet — start here)

```bash
make deploy-sepolia
```

Or directly:

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url base_sepolia \
  --broadcast \
  --verify
```

The RPC URL `base_sepolia` is defined in `foundry.toml` and points at
`https://sepolia.base.org` by default. Override via `BASE_SEPOLIA_RPC_URL`
in `.env` if you want a private endpoint (Alchemy, QuickNode).

### Base mainnet

```bash
make deploy-mainnet
```

Same shape. Different chain ID (8453 vs 84532), different Basescan verifier.

### What happens during a real deploy

`forge script` does three things in sequence:

1. Simulates the entire transaction set against the live fork. If any tx
   would revert, the script aborts before signing anything.
2. Signs all 10 deploy transactions inside a single `startBroadcast` /
   `stopBroadcast` envelope. The wallet signs once, the EIP-155 envelope
   covers nonces `n, n+1, ..., n+9`.
3. Submits the transactions in order, waits for receipts, then calls
   Basescan's verifier with the deployment bytecode so each contract shows
   up as "Verified" within a few seconds.

If the script gets to step 3 and verification fails, the contracts are
still on chain. You can re-verify later with `make verify-sepolia ADDR=0x...`.

## Gas profile (measured on local anvil)

| Action                 | Gas          | Notes                          |
| ---------------------- | ------------ | ------------------------------ |
| Deploy (single)        | 98,827       | Includes constructor costs      |
| Deploy (10 contracts)  | 988,270      | Total, all in one broadcast     |
| `set(uint256)` (cold)  | ~43,500      | First call from a new EOA       |
| `set(uint256)` (warm)  | ~22,700      | Subsequent calls                |
| `x()` (warm)           | ~2,100       | Auto-generated public getter    |

The original estimate in this README was 130k per deploy. Actual is closer
to 99k. The `optimizer_runs = 1_000_000` and `via_ir = true` settings in
`foundry.toml` pay off.

## Verify a contract after the fact

If `--verify` failed, or you deployed without it, re-verify manually:

```bash
make verify-sepolia ADDR=0xYourContractAddress
make verify-mainnet ADDR=0xYourContractAddress
```

These call `forge verify-contract` against the canonical `Minimal.sol`
source. Make sure `ETHERSCAN_API_KEY` is in your environment.

## Troubleshooting

A few things I hit while building this project. Saving them so you don't
waste an afternoon.

**`forge install` fails with "invalid remapping format"**
You have comments in `remappings.txt`. Forge 1.7+ parses it strictly. Keep
only `key=value` lines, no `#` comments.

**`forge build` fails with "unknown variant: `params_per_line`"**
That formatter option is gone in forge 1.7. Use `params_first` instead
(already set in `foundry.toml`).

**`forge install foundry-rs/forge-std --no-commit` errors**
The `--no-commit` flag was removed in forge 1.7. Just run
`forge install foundry-rs/forge-std` without it.

**`--verify` fails with "deprecated V1 endpoint, switch to V2"**
The V1 Basescan/Etherscan endpoints were retired. Update your `.env` to use
`ETHERSCAN_API_KEY` (not `BASESCAN_API_KEY`) and grab the key from
[etherscan.io/myapikey](https://etherscan.io/myapikey). The `foundry.toml`
in this repo already points at the V2 unified endpoint
(`https://api.etherscan.io/v2/api`) with `chainid` baked into the URL
itself. One key works for both Base and Base Sepolia.

**`--verify` fails with "Missing chainid parameter (required for v2 api)"**
Your `foundry.toml` etherscan URL is missing the `?chainid=<id>` query
parameter. With V2, chainid MUST be in the URL — forge 1.7.x does not
auto-append it from the `chain =` field. Use the URL format
`https://api.etherscan.io/v2/api?chainid=84532` (or `?chainid=8453` for
mainnet). The `foundry.toml` in this repo already has the correct format.

**Deploy succeeds but verification hangs**
Basescan's free tier is rate-limited. Wait a few minutes and re-run with
`make verify-sepolia ADDR=0x...`.

**Base mainnet verification returns "Free API access is not supported"**
The Etherscan V2 free plan covers Base Sepolia but not all mainnet chains.
Workarounds for Base mainnet: upgrade your Etherscan API plan, or pass
`--verifier sourcify` to `forge script` / `forge verify-contract` to use
the open-source Sourcify verifier instead.

**Want to re-verify all 10 contracts from a previous run without
redeploying?**
Use `make reverify-sepolia`. It reads `contractAddress` entries from
`broadcast/Deploy.s.sol/84532/run-latest.json` and calls
`forge verify-contract` for each. Pass `BROADCAST=path/to/other-run.json`
to use a non-default file. Same target exists for mainnet
(`make reverify-mainnet`).

**`vm.envUint("PRIVATE_KEY")` panics**
`.env` is missing or `PRIVATE_KEY` is not set. Foundry auto-loads `.env`
from the project root when `forge script` runs.

## Security

`PRIVATE_KEY` in `.env` is read by `vm.envUint`. It never touches git as
long as `.env` is in `.gitignore` (it is).

Use a burner wallet. If `.env` leaks, that key is gone. Do not reuse it
for funds or for signing other contracts.

For mainnet, sign with hardware. `--account` (Cast keystore), `--ledger`, or
`--trezor` keep the key off disk entirely. `PRIVATE_KEY` in a plaintext
env file is fine for a testnet mission. It is not fine for a wallet that
holds real money.

Keep `.env` off cloud sync. No iCloud, Drive, Dropbox, or GitHub Actions
secrets unless scoped read-only to a CI job that's destroyed after the run.
And no screenshots.

A leaked key cannot be recovered. Move funds and revoke roles immediately.

Before you `git add .`, check `git status` and `git log -p -- .env`. If the
file slipped out of `.gitignore`, you want to know before the push.

## Project layout

```
.
├── foundry.toml          # optimizer + Basescan verifier config
├── remappings.txt        # forge-std path for IDEs
├── Makefile              # common dev tasks
├── .env.example          # secrets template
├── .gitignore            # build artefacts, secrets, editor cruft
├── .gitattributes        # LF line endings + linguist stats
├── .editorconfig         # cross-editor formatting
├── LICENSE               # MIT
├── src/Minimal.sol       # single-slot, gas-optimized contract
├── script/Deploy.s.sol   # 10x deploy loop in a single broadcast
└── lib/forge-std/        # git submodule, not tracked
```

## Make targets

Run `make help` for the full list. The ones you'll use most:

| Target                | What it does                                      |
| --------------------- | ------------------------------------------------- |
| `make install`        | install forge-std dependency                      |
| `make build`          | compile contracts                                 |
| `make test`           | run unit tests                                    |
| `make test-gas`       | run tests with gas report                         |
| `make deploy-sepolia` | deploy 10x on Base Sepolia + auto-verify          |
| `make deploy-mainnet` | deploy 10x on Base mainnet + auto-verify          |
| `make verify-sepolia ADDR=0x...` | re-verify a single deployment on Sepolia |
| `make verify-mainnet ADDR=0x...` | re-verify a single deployment on mainnet |
| `make reverify-sepolia` | re-verify ALL 10 contracts from `broadcast/Deploy.s.sol/84532/run-latest.json` |
| `make reverify-mainnet` | re-verify ALL 10 contracts from `broadcast/Deploy.s.sol/8453/run-latest.json` |
| `make clean`          | remove `out/`, `cache/`, `broadcast/`             |
