# Load environment variables (optional)
-include .env

# Default Anvil private key
DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Common forge flags
FORGE_FLAGS := --via-ir --optimizer-runs 200

# =============================================
# NETWORK ARGUMENTS
# =============================================

# Default: Anvil (local)
NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast $(FORGE_FLAGS) -vvvv

# Sepolia override
ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account mywallet --sender $(SEPOLIA_WALLET_ADDRESS) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) $(FORGE_FLAGS) -vvvv
endif

# Mainnet override
ifeq ($(findstring --network mainnet,$(ARGS)),--network mainnet)
	NETWORK_ARGS := --rpc-url $(MAINNET_RPC_URL) --account mywallet --sender $(MAINNET_WALLET_ADDRESS) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --slow $(FORGE_FLAGS) -vvvv
endif

# =============================================
# TARGETS
# =============================================

clean:
	forge clean

build:
	forge build

test:
	forge test -vvvv

test-gas:
	forge test --gas-report -vvvv

snapshot:
	forge snapshot

format:
	forge fmt

anvil:
	anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# Deploy (uses ARGS to determine network)
deploy:
	@echo "Deploying to: $(ARGS)"
	forge script script/DeployGovernance.s.sol:DeployGovernance $(NETWORK_ARGS)

# Help
help:
	@echo "Usage:"
	@echo "  make deploy                         Deploy to Anvil (default)"
	@echo "  make deploy ARGS="--network sepolia" Deploy to Sepolia"
	@echo "  make deploy ARGS="--network mainnet" Deploy to Mainnet"
	@echo ""
	@echo "Utilities:"
	@echo "  make test                  Run tests"
	@echo "  make anvil                 Start Anvil node"
	@echo "  make clean                 Clean build files"
	@echo "  make help                  Show this help"

.PHONY: clean build test test-gas snapshot format anvil deploy help