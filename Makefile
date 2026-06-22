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

# ---- Forge version pin (uncomment to enforce) ----
# FOUNDRY_VERSION = nightly

.PHONY: help install build build-optimized test test-gas fmt fmt-check snapshot clean \
        deploy-sepolia deploy-mainnet verify-sepolia verify-mainnet

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
		--etherscan-api-key $${BASESCAN_API_KEY}

verify-mainnet: ## verify an existing deployment on Base mainnet
	@if [ -z "$(ADDR)" ]; then \
		echo "Usage: make verify-mainnet ADDR=0x..." >&2; \
		exit 1; \
	fi
	forge verify-contract $(ADDR) src/Minimal.sol:Minimal \
		--chain-id 8453 \
		--etherscan-api-key $${BASESCAN_API_KEY}
