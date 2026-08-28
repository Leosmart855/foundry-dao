// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Config} from "./HelperConfig.s.sol";
import {GovToken} from "../src/GovToken.sol";
import {Box} from "../src/Box.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract DeployGovernance is Script, Config {
    // Contract instances
    GovToken public govToken;
    Box public box;
    MyGovernor public governor;
    TimeLock public timeLock;

    // Configuration
    NetworkConfig public networkConfig;

    function run() external {
        // Load configuration
        // config here is a struct and getConfig() returns the struct "config"
        //config = getConfig();
        networkConfig = getConfig();

        address deployer = msg.sender;

        // Start broadcasting transactions
        vm.startBroadcast(deployer);

        // Step 1: Deploy Governance Token
        console.log("\n[1/4] Deploying GovToken...");
        govToken = new GovToken(deployer);
        console.log("GovToken deployed at:", address(govToken));
        console.log("  Total Supply:", networkConfig.tokenSupply / 1 ether, "GVT");
        console.log("  Owner:", deployer);

        // Step 2: Deploy TimeLock
        console.log("\n[2/4] Deploying TimeLock...");
        address[] memory proposers = new address[](1);
        proposers[0] = networkConfig.proposer != address(0) ? networkConfig.proposer : deployer;

        address[] memory executors = new address[](1);
        executors[0] = networkConfig.executor;

        timeLock = new TimeLock(networkConfig.minDelay, proposers, executors);
        console.log("TimeLock deployed at:", address(timeLock));
        console.log("  Min Delay:", networkConfig.minDelay, "seconds");
        console.log("  Proposer:", proposers[0]);
        console.log("  Executor:", executors[0] == address(0) ? "Anyone" : vm.toString(executors[0]));

        // Step 3: Deploy Governor
        console.log("\n[3/4] Deploying MyGovernor...");
        governor = new MyGovernor(
            IVotes(address(govToken)),
            timeLock,
            uint48(networkConfig.votingDelay),
            uint32(networkConfig.votingPeriod),
            networkConfig.proposalThreshold,
            networkConfig.quorumPercentage
        );
        console.log("MyGovernor deployed at:", address(governor));
        console.log("  Voting Delay:", networkConfig.votingDelay, "blocks");
        console.log("  Voting Period:", networkConfig.votingPeriod, "blocks (~1 week)");
        console.log("  Quorum:", networkConfig.quorumPercentage, "%");

        // Step 4: Deploy Box
        console.log("\n[4/4] Deploying Box...");
        box = new Box();
        console.log("Box deployed at:", address(box));
        console.log("  Initial Owner:", box.owner());

        // Step 5: Transfer Box ownership to TimeLock
        console.log("\nTransferring Box ownership to TimeLock...");
        box.transferOwnership(address(timeLock));
        console.log("Box owner now:", box.owner());

        // Step 6: Setup TimeLock roles
        console.log("\nSetting up TimeLock roles...");
        setupRoles(deployer);

        vm.stopBroadcast();
    }

    function setupRoles(address deployer) internal {
        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        // Grant PROPOSER_ROLE to Governor
        timeLock.grantRole(proposerRole, address(governor));
        console.log("Granted PROPOSER_ROLE to Governor");

        // Grant EXECUTOR_ROLE to address(0) - anyone can execute
        timeLock.grantRole(executorRole, address(0));
        console.log("Granted EXECUTOR_ROLE to address(0) - anyone can execute");

        // Revoke DEFAULT_ADMIN_ROLE from deployer (for security)
        timeLock.revokeRole(adminRole, deployer);
        console.log("Revoked DEFAULT_ADMIN_ROLE from deployer");

        // Verify roles were set correctly
        verifyRoles(deployer);
    }

    function verifyRoles(address deployer) internal view {
        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        console.log("\nVerifying roles...");
        console.log(
            "  Governor has PROPOSER_ROLE:", timeLock.hasRole(proposerRole, address(governor)) ? "ACTIVE" : "INACTIVE"
        );
        console.log("  Anyone has EXECUTOR_ROLE:", timeLock.hasRole(executorRole, address(0)) ? "ENABLED" : "DISABLED");
        console.log(
            "  Deployer NOT DEFAULT_ADMIN:", !timeLock.hasRole(adminRole, deployer) ? "SECURE" : "WARNING: STILL ACTIVE"
        );
    }
}
