# ====================================================================
# get-proposal-id.sh - Get proposal ID from proposal transaction hash
# ====================================================================

#!/bin/bash
source .env
PROPOSAL_ID=$(cast receipt $1 --rpc-url $RPC_URL --json | jq -r '.logs[0].data' | cut -c 3-66 | xargs cast to-dec)
echo $PROPOSAL_ID




# USAGE:
#   1. Load environment first: source .env
#   2. run the script and store in variable: PROPOSAL_ID=$(./get-proposal-id.sh <proposal_tx_hash>)
#
# EXAMPLES:
#
#   PROPOSAL_ID=$(./get-proposal-id.sh    0xcc0b81e0163306db843f9f46d5ea58e8b7022082561fa61ec6bb938e5799e8b8) 
#   echo $PROPOSAL_ID 
#
#   Then use it: cast call $GOVERNOR "state(uint256)(uint8)" $PROPOSAL_ID --rpc-url $RPC_URL
# ==============================================
