# Base Contracts Deployed

Ten instances of a single-slot contract on Base, deployed in one
broadcast, verified on Etherscan. Foundry project, ~99k gas per deploy,
~988k for all ten. Verified on Base Sepolia.

## Run it

Three commands from a fresh clone:

```bash
curl -L https://foundry.paradigm.xyz | bash && foundryup
cp .env.example .env
make install && make deploy-sepolia
```

Fill `PRIVATE_KEY` (a burner wallet with a little Base Sepolia ETH) and
`ETHERSCAN_API_KEY` (free at [etherscan.io/myapikey](https://etherscan.io/myapikey))
into `.env`, then run `make deploy-sepolia` again.

You should see 10 contracts deploy, then 10 verifications queue and
confirm. The whole thing takes a few minutes and ends with:

```
All (10) contracts were verified!
```

Already have an old `.env` with `BASESCAN_API_KEY`? `make migrate-env`
renames it in place. The key value is preserved.

## Verify a previous run

```bash
make verify
```

Finds your most recent broadcast, detects the chain, re-verifies every
contract. For a single address instead: `make verify-sepolia ADDR=0x...`.

## Mainnet

```bash
make deploy-mainnet
```

Same shape, different network. The free Etherscan V2 plan covers Base
Sepolia but not mainnet. For mainnet, either upgrade the API plan or
pass `--verifier sourcify` to use the open-source verifier.

## Local test (optional)

```bash
anvil --port 8545 &
```

Anvil prints a list of pre-funded dev private keys when it starts. Copy
the first one into your shell and use it for the deploy:

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url http://localhost:8545 \
  --private-key $YOUR_ANVIL_KEY \
  --broadcast
```

Those keys are well-known, deterministic, and only valid on a local
anvil node. Do not paste them anywhere that talks to a real network.

## Security

`PRIVATE_KEY` in `.env` is loaded by `vm.envUint`. As long as `.env` is
in `.gitignore` (it is), it never touches git. The rest is on you:

- Burner wallet only. If the key leaks, the wallet is gone.
- Sign mainnet with hardware. `--ledger`, `--trezor`, or Cast keystore.
- No cloud sync, no screenshots.
- If a key leaks, move funds immediately. Cannot be undone.

## Layout

- `src/Minimal.sol`: the contract (single `uint256` slot)
- `script/Deploy.s.sol`: the 10-deploy script
- `foundry.toml`: optimizer + Etherscan V2 verifier
- `Makefile`: `make help` lists everything
- `.env.example`: secrets template
