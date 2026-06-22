# ============================================================
#  Base Contracts Deployed — Foundry project
# ============================================================
#  Common dev tasks. Run `make help` for a target list.
#
#  Secrets (.env) are loaded with `-include` so the makefile still
#  works without one (e.g. in CI). `export` lifts every var to the
#  subprocess env so forge picks them up.
# ============================================================

-include .env
export

# ------------------------------------------------------------
#  Backward-compat: BASESCAN_API_KEY -> ETHERSCAN_API_KEY
# ------------------------------------------------------------
#  As of 2025-09 the Etherscan V1 endpoints (basescan.org/api,
#  api.etherscan.io/api) are deprecated. The V2 unified endpoint
#  uses the ETHERSCAN_API_KEY env var (one key for all Etherscan-
#  family chains).
#
#  If the user has only the old BASESCAN_API_KEY set in .env, alias
#  it to ETHERSCAN_API_KEY so forge sees the V2 var. New setups
#  should use ETHERSCAN_API_KEY directly.
# ------------------------------------------------------------
ifdef BASESCAN_API_KEY
ifndef ETHERSCAN_API_KEY
export ETHERSCAN_API_KEY = $(BASESCAN_API_KEY)
$(warning BASESCAN_API_KEY is deprecated, rename to ETHERSCAN_API_KEY in .env)
endif
endif

# ---- Forge version pin (uncomment to enforce) ----
# FOUNDRY_VERSION = nightly

.PHONY: help install build build-optimized test test-gas fmt fmt-check snapshot clean \
        deploy-sepolia deploy-mainnet verify-sepolia verify-mainnet \
        reverify-sepolia reverify-mainnet verify migrate-env

# ------------------------------------------------------------
#  Rate-limit config (avoid spam flagging on block explorers)
# ------------------------------------------------------------
#  The chain and Etherscan treat ten back-to-back transactions from
#  the same address as suspicious. Spacing them out keeps the
#  deployment below the spam threshold. Override on the command line
#  to disable or tune:
#
#    make deploy-sepolia DEPLOY_DELAY_MIN=0 DEPLOY_DELAY_MAX=0
#    make reverify-sepolia VERIFY_DELAY_MIN=30 VERIFY_DELAY_MAX=60
# ------------------------------------------------------------
DEPLOY_DELAY_MIN ?= 15
DEPLOY_DELAY_MAX ?= 30
VERIFY_DELAY_MIN ?= 15
VERIFY_DELAY_MAX ?= 30

help: ## show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} \
	/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ------------------------------------------------------------
#  Setup
# ------------------------------------------------------------
install: ## install forge-std dependency
	forge install foundry-rs/forge-std --no-commit

# ------------------------------------------------------------
#  Build & test
# ------------------------------------------------------------
build: ## compile contracts
	forge build

build-optimized: ## compile with aggressive optimizer for size report
	forge build --sizes

test: ## run unit tests
	forge test -vvv

test-gas: ## run tests and print gas report
	forge test --gas-report

# ------------------------------------------------------------
#  Code style
# ------------------------------------------------------------
fmt: ## auto-format Solidity
	forge fmt

fmt-check: ## check formatting without modifying files (CI-friendly)
	forge fmt --check

# ------------------------------------------------------------
#  Gas snapshot
# ------------------------------------------------------------
snapshot: ## write .gas-snapshot from current test run
	forge snapshot

# ------------------------------------------------------------
#  Cleanup
# ------------------------------------------------------------
clean: ## remove out/, cache/, broadcast/
	forge clean
	rm -rf broadcast/

# ------------------------------------------------------------
#  Deploy + verify
# ------------------------------------------------------------
#  `$${VAR}` in a Makefile escapes to `${VAR}` in the shell, so the
#  variable is expanded at execution time from the exported env
#  (i.e. from `.env`). Never inline the raw key into the Makefile.
# ------------------------------------------------------------
deploy-sepolia: ## deploy 10 instances to Base Sepolia with 15-30s sleep between (rate-limited)
	@CHAIN=84532; \
	SCRIPT_DIR=broadcast/DeploySingle.s.sol/$$CHAIN; \
	rm -f "$$SCRIPT_DIR" deployments-$$CHAIN.txt; \
	mkdir -p "$$SCRIPT_DIR"; \
	i=0; \
	while [ $$i -lt 10 ]; do \
		i=$$((i + 1)); \
		echo ""; \
		echo "=== Deploy $$i/10 -> Base Sepolia (chain $$CHAIN) ==="; \
		forge script script/DeploySingle.s.sol:DeploySingle \
			--rpc-url base_sepolia \
			--broadcast --verify || exit $$?; \
		if [ $$i -lt 10 ]; then \
			DELAY=$$(( (RANDOM % (DEPLOY_DELAY_MAX - DEPLOY_DELAY_MIN + 1)) + DEPLOY_DELAY_MIN )); \
			printf "[delay] sleeping %d sec before next deploy (set DEPLOY_DELAY_MIN/MAX=0 to skip)...\n" $$DELAY; \
			sleep $$DELAY; \
		fi; \
	done; \
	echo ""; \
	echo "Aggregating addresses from $$SCRIPT_DIR/ ..."; \
	python3 -c "import json,glob; \
out=[]; \
[out.append(t['contractAddress']) for f in sorted(glob.glob('$$SCRIPT_DIR/run-*.json')) if 'latest' not in f for t in json.load(open(f)).get('transactions',[]) if t.get('contractAddress')]; \
open('deployments-$$CHAIN.txt','w').write('\n'.join(out)+'\n')"; \
	echo "All 10 deployed. Addresses saved to: deployments-$$CHAIN.txt"; \
	cat deployments-$$CHAIN.txt

deploy-mainnet: ## deploy 10 instances to Base mainnet with 15-30s sleep between (rate-limited)
	@CHAIN=8453; \
	SCRIPT_DIR=broadcast/DeploySingle.s.sol/$$CHAIN; \
	rm -f "$$SCRIPT_DIR" deployments-$$CHAIN.txt; \
	mkdir -p "$$SCRIPT_DIR"; \
	i=0; \
	while [ $$i -lt 10 ]; do \
		i=$$((i + 1)); \
		echo ""; \
		echo "=== Deploy $$i/10 -> Base mainnet (chain $$CHAIN) ==="; \
		forge script script/DeploySingle.s.sol:DeploySingle \
			--rpc-url base \
			--broadcast --verify || exit $$?; \
		if [ $$i -lt 10 ]; then \
			DELAY=$$(( (RANDOM % (DEPLOY_DELAY_MAX - DEPLOY_DELAY_MIN + 1)) + DEPLOY_DELAY_MIN )); \
			printf "[delay] sleeping %d sec before next deploy (set DEPLOY_DELAY_MIN/MAX=0 to skip)...\n" $$DELAY; \
			sleep $$DELAY; \
		fi; \
	done; \
	echo ""; \
	echo "Aggregating addresses from $$SCRIPT_DIR/ ..."; \
	python3 -c "import json,glob; \
out=[]; \
[out.append(t['contractAddress']) for f in sorted(glob.glob('$$SCRIPT_DIR/run-*.json')) if 'latest' not in f for t in json.load(open(f)).get('transactions',[]) if t.get('contractAddress')]; \
open('deployments-$$CHAIN.txt','w').write('\n'.join(out)+'\n')"; \
	echo "All 10 deployed. Addresses saved to: deployments-$$CHAIN.txt"; \
	cat deployments-$$CHAIN.txt

# ------------------------------------------------------------
#  Re-verify an already-deployed contract
# ------------------------------------------------------------
#  Usage:
#    make verify-sepolia ADDR=0xabc...123
#    make verify-mainnet ADDR=0xabc...123
# ------------------------------------------------------------
verify-sepolia: ## verify an existing deployment on Base Sepolia
	@if [ -z "$(ADDR)" ]; then \
		echo "Usage: make verify-sepolia ADDR=0x..." >&2; \
		exit 1; \
	fi
	forge verify-contract $(ADDR) src/Minimal.sol:Minimal \
		--chain-id 84532 \
		--etherscan-api-key $${ETHERSCAN_API_KEY}

verify-mainnet: ## verify an existing deployment on Base mainnet
	@if [ -z "$(ADDR)" ]; then \
		echo "Usage: make verify-mainnet ADDR=0x..." >&2; \
		exit 1; \
	fi
	forge verify-contract $(ADDR) src/Minimal.sol:Minimal \
		--chain-id 8453 \
		--etherscan-api-key $${ETHERSCAN_API_KEY}

# ------------------------------------------------------------
#  migrate-env — one-shot .env migration
# ------------------------------------------------------------
#  Renames BASESCAN_API_KEY to ETHERSCAN_API_KEY in your .env.
#  Value (the actual key) is preserved. All other lines untouched.
#  Safe to run multiple times (idempotent).
# ------------------------------------------------------------
migrate-env: ## rename BASESCAN_API_KEY to ETHERSCAN_API_KEY in .env (preserves key value)
	@if [ ! -f .env ]; then \
		echo "No .env found. Run: cp .env.example .env" >&2; \
		exit 1; \
	fi; \
	if grep -q '^BASESCAN_API_KEY=' .env; then \
		sed -i 's/^BASESCAN_API_KEY=/ETHERSCAN_API_KEY=/' .env; \
		echo "Migrated: BASESCAN_API_KEY -> ETHERSCAN_API_KEY (key value preserved)"; \
		echo "--- .env diff (BASESCAN_API_KEY / ETHERSCAN_API_KEY lines only) ---"; \
		grep -E '^(BASESCAN_API_KEY|ETHERSCAN_API_KEY)=' .env || true; \
	else \
		echo "Nothing to migrate. Either already ETHERSCAN_API_KEY, or no key set."; \
	fi

# ------------------------------------------------------------
#  verify — simplest possible verification
# ------------------------------------------------------------
#  No args, no flags. Auto-detects the chain from the broadcast dir,
#  aggregates addresses from all `run-*.json` files (or from the
#  `deployments-<chain>.txt` manifest if present), and verifies each
#  contract with 15-30s sleep between calls. Rate-limited to avoid
#  hitting the Etherscan free tier rate limit.
#
#  Override the broadcast file with BROADCAST=path/to/file.json
# ------------------------------------------------------------
verify: ## auto-detect: verify all contracts from the most recent broadcast (rate-limited)
	@CHAIN_DIR=$$(ls -1d broadcast/DeploySingle.s.sol/*/  broadcast/Deploy.s.sol/*/ 2>/dev/null | head -1); \
	if [ -z "$$CHAIN_DIR" ]; then \
		echo "No broadcast/ directory. Run 'make deploy-sepolia' (or mainnet) first." >&2; \
		exit 1; \
	fi; \
	CHAIN=$$(basename "$$CHAIN_DIR"); \
	MANIFEST=deployments-$$CHAIN.txt; \
	if [ -f "$$MANIFEST" ]; then \
		ADDRS=$$(grep -E '^0x' "$$MANIFEST"); \
		SRC="$$MANIFEST"; \
	else \
		ADDRS=$$(python3 -c "import json,glob; \
[print(t['contractAddress']) for f in sorted(glob.glob('$$CHAIN_DIR/run-*.json')) if 'latest' not in f for t in json.load(open(f)).get('transactions',[]) if t.get('contractAddress')]"); \
		SRC="$$CHAIN_DIR (all run-*.json files)"; \
	fi; \
	if [ -z "$$ADDRS" ]; then \
		echo "No contracts found in $$SRC" >&2; \
		exit 1; \
	fi; \
	TOTAL=$$(echo "$$ADDRS" | wc -l); \
	echo "Source: $$SRC"; \
	echo "Chain:  $$CHAIN"; \
	echo "Found:  $$TOTAL contracts"; \
	echo "---"; \
	OK=0; FAIL=0; \
	for addr in $$ADDRS; do \
		OK=$$((OK + 1)); \
		printf "[%2d/%2d] %s ... " $$OK $$TOTAL $$addr; \
		if forge verify-contract $$addr src/Minimal.sol:Minimal \
			--chain-id $$CHAIN \
			--etherscan-api-key $${ETHERSCAN_API_KEY} >/dev/null 2>&1; then \
			echo "OK"; \
		else \
			echo "FAIL"; \
			FAIL=$$((FAIL + 1)); \
		fi; \
		if [ $$OK -lt $$TOTAL ] && [ $$FAIL -lt 3 ]; then \
			DELAY=$$(( (RANDOM % (VERIFY_DELAY_MAX - VERIFY_DELAY_MIN + 1)) + VERIFY_DELAY_MIN )); \
			printf "[delay] sleeping %d sec (set VERIFY_DELAY_MIN/MAX=0 to skip)...\n" $$DELAY; \
			sleep $$DELAY; \
		fi; \
	done; \
	echo "---"; \
	echo "Done. Verified $$TOTAL contracts, $$FAIL failed."; \
	exit $$FAIL

# ------------------------------------------------------------
#  Re-verify all contracts in a broadcast file or manifest
# ------------------------------------------------------------
#  After switching the verifier config (e.g. V1 -> V2), use this to
#  submit verification for every contract from a previous run without
#  redeploying. Reads the `contractAddress` from each tx in the
#  broadcast JSON (or from the manifest) and calls
#  `forge verify-contract` for each.
#
#  Usage:
#    make reverify-sepolia
#    make reverify-sepolia BROADCAST=broadcast/Deploy.s.sol/84532/run-1234.json
# ------------------------------------------------------------
reverify-sepolia: ## re-verify all contracts on Base Sepolia (rate-limited)
	@CHAIN=84532; \
	MANIFEST=deployments-$$CHAIN.txt; \
	if [ -n "$(BROADCAST)" ]; then \
		BROADCAST_FILE=$(BROADCAST); \
		if [ ! -f "$$BROADCAST_FILE" ]; then \
			echo "Broadcast file not found: $$BROADCAST_FILE" >&2; \
			exit 1; \
		fi; \
		ADDRS=$$(python3 -c "import json; d=json.load(open('$$BROADCAST_FILE')); [print(t.get('contractAddress','')) for t in d.get('transactions',[]) if t.get('contractAddress')]"); \
		SRC="$$BROADCAST_FILE"; \
	elif [ -f "$$MANIFEST" ]; then \
		ADDRS=$$(grep -E '^0x' "$$MANIFEST"); \
		SRC="$$MANIFEST"; \
	else \
		ADDRS=$$(python3 -c "import json,glob; \
[print(t['contractAddress']) for f in sorted(glob.glob('broadcast/*/$$CHAIN/run-*.json')) if 'latest' not in f for t in json.load(open(f)).get('transactions',[]) if t.get('contractAddress')]"); \
		SRC="broadcast/*/$$CHAIN (all run-*.json files)"; \
	fi; \
	if [ -z "$$ADDRS" ]; then \
		echo "No contracts found in $$SRC" >&2; \
		exit 1; \
	fi; \
	TOTAL=$$(echo "$$ADDRS" | wc -l); \
	echo "Source: $$SRC"; \
	echo "Chain:  $$CHAIN (Base Sepolia)"; \
	echo "Found:  $$TOTAL contracts"; \
	echo "---"; \
	COUNT=0; FAILED=0; \
	for addr in $$ADDRS; do \
		COUNT=$$((COUNT + 1)); \
		printf "[%2d/%2d] verifying %s ... " $$COUNT $$TOTAL $$addr; \
		if forge verify-contract $$addr src/Minimal.sol:Minimal \
			--chain-id $$CHAIN \
			--etherscan-api-key $${ETHERSCAN_API_KEY} >/dev/null 2>&1; then \
			echo "OK"; \
		else \
			echo "FAILED"; \
			FAILED=$$((FAILED + 1)); \
		fi; \
		if [ $$COUNT -lt $$TOTAL ] && [ $$FAILED -lt 3 ]; then \
			DELAY=$$(( (RANDOM % (VERIFY_DELAY_MAX - VERIFY_DELAY_MIN + 1)) + VERIFY_DELAY_MIN )); \
			printf "[delay] sleeping %d sec (set VERIFY_DELAY_MIN/MAX=0 to skip)...\n" $$DELAY; \
			sleep $$DELAY; \
		fi; \
	done; \
	echo "---"; \
	echo "Verified $$TOTAL contracts, $$FAILED failed."; \
	exit $$FAILED

reverify-mainnet: ## re-verify all contracts on Base mainnet (rate-limited)
	@CHAIN=8453; \
	MANIFEST=deployments-$$CHAIN.txt; \
	if [ -n "$(BROADCAST)" ]; then \
		BROADCAST_FILE=$(BROADCAST); \
		if [ ! -f "$$BROADCAST_FILE" ]; then \
			echo "Broadcast file not found: $$BROADCAST_FILE" >&2; \
			exit 1; \
		fi; \
		ADDRS=$$(python3 -c "import json; d=json.load(open('$$BROADCAST_FILE')); [print(t.get('contractAddress','')) for t in d.get('transactions',[]) if t.get('contractAddress')]"); \
		SRC="$$BROADCAST_FILE"; \
	elif [ -f "$$MANIFEST" ]; then \
		ADDRS=$$(grep -E '^0x' "$$MANIFEST"); \
		SRC="$$MANIFEST"; \
	else \
		ADDRS=$$(python3 -c "import json,glob; \
[print(t['contractAddress']) for f in sorted(glob.glob('broadcast/*/$$CHAIN/run-*.json')) if 'latest' not in f for t in json.load(open(f)).get('transactions',[]) if t.get('contractAddress')]"); \
		SRC="broadcast/*/$$CHAIN (all run-*.json files)"; \
	fi; \
	if [ -z "$$ADDRS" ]; then \
		echo "No contracts found in $$SRC" >&2; \
		exit 1; \
	fi; \
	TOTAL=$$(echo "$$ADDRS" | wc -l); \
	echo "Source: $$SRC"; \
	echo "Chain:  $$CHAIN (Base mainnet)"; \
	echo "Found:  $$TOTAL contracts"; \
	echo "---"; \
	COUNT=0; FAILED=0; \
	for addr in $$ADDRS; do \
		COUNT=$$((COUNT + 1)); \
		printf "[%2d/%2d] verifying %s ... " $$COUNT $$TOTAL $$addr; \
		if forge verify-contract $$addr src/Minimal.sol:Minimal \
			--chain-id $$CHAIN \
			--etherscan-api-key $${ETHERSCAN_API_KEY} >/dev/null 2>&1; then \
			echo "OK"; \
		else \
			echo "FAILED"; \
			FAILED=$$((FAILED + 1)); \
		fi; \
		if [ $$COUNT -lt $$TOTAL ] && [ $$FAILED -lt 3 ]; then \
			DELAY=$$(( (RANDOM % (VERIFY_DELAY_MAX - VERIFY_DELAY_MIN + 1)) + VERIFY_DELAY_MIN )); \
			printf "[delay] sleeping %d sec (set VERIFY_DELAY_MIN/MAX=0 to skip)...\n" $$DELAY; \
			sleep $$DELAY; \
		fi; \
	done; \
	echo "---"; \
	echo "Verified $$TOTAL contracts, $$FAILED failed."; \
	exit $$FAILED
