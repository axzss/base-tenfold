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
deploy-sepolia: ## deploy 10 instances to Base Sepolia + auto-verify
	forge script script/Deploy.s.sol:DeployScript \
		--rpc-url base_sepolia \
		--private-key $${PRIVATE_KEY} \
		--broadcast \
		--verify

deploy-mainnet: ## deploy 10 instances to Base mainnet + auto-verify
	forge script script/Deploy.s.sol:DeployScript \
		--rpc-url base \
		--private-key $${PRIVATE_KEY} \
		--broadcast \
		--verify

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
#  No args, no flags. Finds the most recent broadcast file, figures
#  out the chain from the directory name (84532 or 8453), and
#  verifies every deployed contract. Use this if you don't want
#  to think about which network.
#
#  Override the broadcast file with BROADCAST=path/to/file.json
# ------------------------------------------------------------
verify: ## auto-detect: verify all contracts from the most recent broadcast
	@if [ ! -d broadcast/Deploy.s.sol ]; then \
		echo "No broadcast/ directory. Run 'make deploy-sepolia' (or mainnet) first." >&2; \
		exit 1; \
	fi; \
	if [ -n "$(BROADCAST)" ]; then \
		LATEST=$(BROADCAST); \
	else \
		LATEST=$$(ls -1t broadcast/Deploy.s.sol/*/run-*.json 2>/dev/null | head -1); \
		if [ -z "$$LATEST" ]; then \
			echo "No broadcast file found. Run a deploy first." >&2; \
			exit 1; \
		fi; \
	fi; \
	CHAIN=$$(dirname "$$LATEST" | xargs basename); \
	echo "File:   $$LATEST"; \
	echo "Chain:  $$CHAIN"; \
	echo "---"; \
	ADDRS=$$(python3 -c "import json; d=json.load(open('$$LATEST')); [print(t.get('contractAddress','')) for t in d.get('transactions',[]) if t.get('contractAddress')]"); \
	if [ -z "$$ADDRS" ]; then \
		echo "No contracts in $$LATEST" >&2; \
		exit 1; \
	fi; \
	TOTAL=$$(echo "$$ADDRS" | wc -l); \
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
	done; \
	echo "---"; \
	echo "Done. Verified $$TOTAL contracts, $$FAIL failed."; \
	exit $$FAIL

# ------------------------------------------------------------
#  Re-verify all contracts in a broadcast file
# ------------------------------------------------------------
#  After switching the verifier config (e.g. V1 -> V2), use this to
#  submit verification for every contract in a previous run without
#  redeploying. Reads the `contractAddress` from each tx in the
#  broadcast JSON and calls `forge verify-contract` for each.
#
#  Usage:
#    make reverify-sepolia
#      # default: broadcast/Deploy.s.sol/84532/run-latest.json
#    make reverify-sepolia BROADCAST=broadcast/Deploy.s.sol/84532/run-1234.json
# ------------------------------------------------------------
reverify-sepolia: ## re-verify all contracts in a Base Sepolia broadcast file
	@BROADCAST_FILE=$${BROADCAST:-broadcast/Deploy.s.sol/84532/run-latest.json}; \
	if [ ! -f "$$BROADCAST_FILE" ]; then \
		echo "Broadcast file not found: $$BROADCAST_FILE" >&2; \
		echo "Usage: make reverify-sepolia [BROADCAST=path/to/run-latest.json]" >&2; \
		exit 1; \
	fi; \
	echo "Reading addresses from $$BROADCAST_FILE ..."; \
	ADDRS=$$(python3 -c "import json,sys; d=json.load(open('$$BROADCAST_FILE')); [print(t.get('contractAddress','')) for t in d.get('transactions',[]) if t.get('contractAddress')]"); \
	if [ -z "$$ADDRS" ]; then \
		echo "No contractAddress entries found in $$BROADCAST_FILE" >&2; \
		exit 1; \
	fi; \
	COUNT=0; FAILED=0; \
	for addr in $$ADDRS; do \
		COUNT=$$((COUNT + 1)); \
		printf "[%2d/%2d] verifying %s ... " $$COUNT $$(echo "$$ADDRS" | wc -l) $$addr; \
		if forge verify-contract $$addr src/Minimal.sol:Minimal \
			--chain-id 84532 \
			--etherscan-api-key $${ETHERSCAN_API_KEY} >/dev/null 2>&1; then \
			echo "OK"; \
		else \
			echo "FAILED"; \
			FAILED=$$((FAILED + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "Verified $$COUNT contracts, $$FAILED failed."; \
	exit $$FAILED

reverify-mainnet: ## re-verify all contracts in a Base mainnet broadcast file
	@BROADCAST_FILE=$${BROADCAST:-broadcast/Deploy.s.sol/8453/run-latest.json}; \
	if [ ! -f "$$BROADCAST_FILE" ]; then \
		echo "Broadcast file not found: $$BROADCAST_FILE" >&2; \
		echo "Usage: make reverify-mainnet [BROADCAST=path/to/run-latest.json]" >&2; \
		exit 1; \
	fi; \
	echo "Reading addresses from $$BROADCAST_FILE ..."; \
	ADDRS=$$(python3 -c "import json,sys; d=json.load(open('$$BROADCAST_FILE')); [print(t.get('contractAddress','')) for t in d.get('transactions',[]) if t.get('contractAddress')]"); \
	if [ -z "$$ADDRS" ]; then \
		echo "No contractAddress entries found in $$BROADCAST_FILE" >&2; \
		exit 1; \
	fi; \
	COUNT=0; FAILED=0; \
	for addr in $$ADDRS; do \
		COUNT=$$((COUNT + 1)); \
		printf "[%2d/%2d] verifying %s ... " $$COUNT $$(echo "$$ADDRS" | wc -l) $$addr; \
		if forge verify-contract $$addr src/Minimal.sol:Minimal \
			--chain-id 8453 \
			--etherscan-api-key $${ETHERSCAN_API_KEY} >/dev/null 2>&1; then \
			echo "OK"; \
		else \
			echo "FAILED"; \
			FAILED=$$((FAILED + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "Verified $$COUNT contracts, $$FAILED failed."; \
	exit $$FAILED
