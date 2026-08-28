//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";

abstract contract CodeConstants {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract Config is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 minDelay;
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 quorumPercentage;
        uint256 tokenSupply;
        uint256 proposalThreshold;
        address proposer;
        address executor;
    }

    function getConfigByChainId(uint256 chainId) public pure returns (NetworkConfig memory) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) {
            return getSepoliaEthConfig();
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getAnvilEthConfig();
        } else if (chainId == ETH_MAINNET_CHAIN_ID) {
            return getMainnetEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            minDelay: 3600, // 1 hour
            votingDelay: 300, // 300 blocks ~ 1 hour
            votingPeriod: 750, // 750 blocks ~ 2 and a half hours
            quorumPercentage: 10,
            tokenSupply: 1_000_000 ether,
            proposalThreshold: 0,
            proposer: address(0), // Set this to your multi-sig address
            executor: address(0)
        });
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            minDelay: 86400, // proposal queue ~ 24 hours before execution i.e timelock delay
            votingDelay: 7200, // 7200 blocks ~ 1 day before voting starts
            votingPeriod: 50400, // 50400 blocks ~1 week
            quorumPercentage: 10,
            tokenSupply: 1_000_000 ether,
            proposalThreshold: 0,
            proposer: address(0), // Set this to your multi-sig address
            executor: address(0)
        });
    }

    function getAnvilEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            minDelay: 20, // 20 seconds for quick test on anvil
            votingDelay: 1, // 1 block ~ 1 sec in respect to anvil chain
            votingPeriod: 300, // 300 blocks ~  Quick for testing on anvil
            quorumPercentage: 10, // 10% of maximum supply
            tokenSupply: 1_000_000 ether,
            proposalThreshold: 0,
            proposer: address(0),
            executor: address(0)
        });
    }
}
