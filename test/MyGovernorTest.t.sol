// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Counter} from "../src/HelperContracts/Counter.sol";
import {SimpleStorage} from "../src/HelperContracts/SimpleStorage.sol";
import {PayableContract} from "../src/HelperContracts/PayableContract.sol";

contract MyGovernorTest is Test {
    Box box;
    GovToken govToken;
    MyGovernor governor;
    TimeLock timeLock;

    Counter counter;
    SimpleStorage simpleStorage;
    PayableContract payableContract;

    address public owner = makeAddr("owner"); // Token owner, deploys all contracts and receives initial supply
    address public user = makeAddr("user"); // Regular community member
    address public treasury = makeAddr("treasury"); // DAO Treasury (could be a multisig)

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    uint256 public constant MIN_DELAY = 3600; // 1 hour - after a vote passes
    uint48 public constant VOTING_DELAY = 1; // how many blocks till a vote is active
    uint32 public constant VOTING_PERIOD = 50400; // 1 week voting period
    uint256 public constant PROPOSAL_THRESHOLD = 0;
    uint256 public constant QUORUM_PERCENTAGE = 10;

    address[] public proposers;
    address[] public executors;

    function setUp() public {
        // Give user enough token for quorum
        uint256 amount = 120000 ether;

        // deploy the GovToken
        govToken = new GovToken(owner);
        vm.prank(owner);
        govToken.transfer(user, amount);

        vm.startPrank(user);
        govToken.delegate(user);
        // next is to deploy our TimeLock because inorder to deploy MyGovernor we need to deloy GovToken and TimeLock first
        timeLock = new TimeLock(MIN_DELAY, proposers, executors);
        // now deploy MyGovernor contract
        governor =
            new MyGovernor(govToken, timeLock, VOTING_DELAY, VOTING_PERIOD, PROPOSAL_THRESHOLD, QUORUM_PERCENTAGE);

        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        timeLock.grantRole(proposerRole, address(governor));
        timeLock.grantRole(executorRole, address(0));
        timeLock.revokeRole(adminRole, user);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timeLock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.storeNumber(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 758;
        string memory description = "store 758 in Box";
        bytes memory encodeFunctionCall = abi.encodeWithSignature("storeNumber(uint256)", valueToStore);

        values.push(0);
        calldatas.push(encodeFunctionCall);
        targets.push(address(box));

        // 1. propose to the DAO
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // we can view the state of this proposal right now by calling the state function
        // state here should be pending
        console.log("proposal state", uint256(governor.state(proposalId)));

        // Advance to voting start
        vm.roll(block.number + VOTING_DELAY + 1);
        // You don't need to warp time here, only roll blocks

        // state here is now active
        console.log("proposal state", uint256(governor.state(proposalId)));

        // 2. Voting starts - cast vote
        string memory reason = "Cause I enjoy writing smart contracts";

        uint8 voteWay = 1; // voting yes
        vm.prank(user);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        // Advance to after voting period ends
        vm.roll(block.number + VOTING_PERIOD + 1);
        // IMPORTANT: No need to warp time here

        // 3. Queue the transaction
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        // Now we need to wait for the timelock delay (which is in TIME, not blocks)
        // This is where we use vm.warp()
        vm.warp(block.timestamp + MIN_DELAY + 1);
        // The block number doesn't matter for timelock, but we can advance it too
        vm.roll(block.number + 1);

        // 4. Execute
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(box.getNumber(), valueToStore);
        console.log("Box Value", box.getNumber());
    }

    function testGovernanceCanChangeName() public {
        string memory newName = "DAO-Controlled Box";
        string memory description = "Change Box name to DAO-Controlled Box";

        bytes memory data = abi.encodeWithSignature("changeName(string)", newName);

        values.push(0);
        calldatas.push(data);
        targets.push(address(box));

        // 1. Propose
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Advance to voting start
        vm.roll(block.number + VOTING_DELAY + 1);

        // 2. Vote starts - cast vote
        uint8 voteWay = 1; // voting yes
        vm.prank(user);
        governor.castVote(proposalId, voteWay);

        // Advance to after voting period ends
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));

        governor.queue(targets, values, calldatas, descriptionHash);

        // Wait for timelock
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // 4. Execute

        governor.execute(targets, values, calldatas, descriptionHash);

        // Assert
        assertEq(box.getName(), newName);
        console.log("New Box Name:", box.getName());
    }

    function testGovernanceCanChangeTreasury() public {
        address newTreasury = makeAddr("newTreasury");
        string memory description = "Change treasury address";

        bytes memory data = abi.encodeWithSignature("changeTreasury(address)", newTreasury);

        values.push(0);
        calldatas.push(data);
        targets.push(address(box));

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + VOTING_DELAY + 1);

        uint8 voteWay = 1;
        vm.prank(user);
        governor.castVote(proposalId, voteWay);

        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));

        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);

        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(box.getTreasury(), newTreasury);
        console.log("New Treasury:", box.getTreasury());
    }

    function testGovernanceCanPauseAndUnpauseContract() public {
        ////////////////////////////////////////////////
        // STEP 1: Test pause contract via governance //
        ///////////////////////////////////////////////
        string memory description = "Pause the contract";

        bytes memory data = abi.encodeWithSignature("pause()");

        values.push(0);
        calldatas.push(data);
        targets.push(address(box));

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + VOTING_DELAY + 1);

        uint8 voteWay = 1;
        vm.prank(user);
        governor.castVote(proposalId, voteWay);

        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));

        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);

        governor.execute(targets, values, calldatas, descriptionHash);

        assertTrue(box.paused());
        console.log("Contract paused:", box.paused());

        // Test that functions revert when paused
        vm.prank(address(timeLock)); // timeLock is the new owner
        vm.expectRevert(abi.encodeWithSignature("Box__Paused()"));
        box.storeNumber(24);

        ///////////////////////////////////////////
        // STEP 2: Test unpausing via governance //
        ///////////////////////////////////////////
        // Reset arrays for new proposal
        values = new uint256[](0); // Create new empty array
        calldatas = new bytes[](0); // Create new empty array
        targets = new address[](0); // Create new empty array

        string memory unpauseDescription = "Unpause the contract";
        bytes memory unpauseData = abi.encodeWithSignature("unpause()");

        values.push(0);
        calldatas.push(unpauseData);
        targets.push(address(box));

        // Propose unpause
        uint256 unpauseProposalId = governor.propose(targets, values, calldatas, unpauseDescription);

        // Vote
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(user);
        governor.castVote(unpauseProposalId, voteWay);

        // Wait for voting period
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Queue
        bytes32 unpauseHash = keccak256(abi.encodePacked(unpauseDescription));

        governor.queue(targets, values, calldatas, unpauseHash);

        // Wait for timelock
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // Execute (unpause the contract)
        governor.execute(targets, values, calldatas, unpauseHash);

        // Verify contract is unpaused
        assertFalse(box.paused());
        console.log("Contract paused:", box.paused());

        //////////////////////////////////////////////
        // STEP 3: Verify functionality is restored //
        /////////////////////////////////////////////
        // Now the owner (TimeLock) can call storeNumber
        vm.prank(address(timeLock));
        box.storeNumber(42);

        assertEq(box.getNumber(), 42);
        console.log("Number updated to:", box.getNumber());
        console.log("Contract successfully unpaused and functional");
    }

    function testGovernanceCanGrantAllowance() public {
        address trustedUser = makeAddr("trustedUser");
        uint256 allowanceAmount = 100 ether;
        string memory description = "Grant allowance to trusted user";

        bytes memory data = abi.encodeWithSignature("grantAllowance(address,uint256)", trustedUser, allowanceAmount);

        values.push(0);
        calldatas.push(data);
        targets.push(address(box));

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + VOTING_DELAY + 1);

        uint8 voteWay = 1;
        vm.prank(user);
        governor.castVote(proposalId, voteWay);

        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));

        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);

        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(box.getAllowance(trustedUser), allowanceAmount);
        console.log("Allowance granted:", box.getAllowance(trustedUser));
    }

    function testGovernanceCanWithdrawFunds() public {
        // First send some ETH to the Box
        vm.deal(address(box), 200 ether);

        uint256 withdrawalAmount = 25 ether;
        string memory description = "Withdraw 25 ETH to treasury";

        bytes memory data = abi.encodeWithSignature("withdrawFunds(address,uint256)", treasury, withdrawalAmount);

        values.push(0);
        calldatas.push(data);
        targets.push(address(box));

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + VOTING_DELAY + 1);

        uint8 voteWay = 1;
        vm.prank(user);
        governor.castVote(proposalId, voteWay);

        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));

        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);

        uint256 beforeBalance = treasury.balance;

        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(treasury.balance, beforeBalance + withdrawalAmount);
        console.log("Treasury balance:", treasury.balance);
    }

    //////////////////////////////////////////////////////////////
    //   TEST: executeTransaction() calls external contract   ///
    ////////////////////////////////////////////////////////////
    // Counter contract test
    function testExecuteTransactionCallsCounter() public {
        counter = new Counter();

        // Prepare call data
        bytes memory data = abi.encodeWithSignature("increment()");

        // TimeLock executes the transaction
        vm.prank(address(timeLock));
        box.executeTransaction(address(counter), 0, data);

        assertEq(counter.getCount(), 1);
    }

    function testExecuteTransactionCallsCounterWithParams() public {
        counter = new Counter();
        uint256 value = 9;
        // Prepare call data with parameter
        bytes memory data = abi.encodeWithSignature("incrementBy(uint256)", value);

        vm.prank(address(timeLock));
        box.executeTransaction(address(counter), 0, data);

        assertEq(counter.getCount(), value);
    }

    // SimpleStorage contract test
    function testExecuteTransactionCallsSimpleStorage() public {
        simpleStorage = new SimpleStorage();
        uint256 newValue = 48;
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", newValue);

        vm.prank(address(timeLock));
        box.executeTransaction(address(simpleStorage), 0, data);

        assertEq(simpleStorage.getValue(), newValue);
        console.log("New value stored:", newValue);
    }

    // PayableContract test
    function testExecuteTransactionSendsEth() public {
        // Fund the Box contract
        vm.deal(address(box), 10 ether);

        payableContract = new PayableContract();
        uint256 amount = 3 ether;

        // Prepare empty call data (just send ETH)
        bytes memory data = "";

        vm.prank(address(timeLock));
        box.executeTransaction(address(payableContract), amount, data);

        assertEq(address(payableContract).balance, amount);
        console.log("This contract just received:", amount);
    }

    function testExecuteTransactionSendsEthWithFunctionCall() public {
        // Fund the Box contract
        vm.deal(address(box), 10 ether);

        payableContract = new PayableContract();
        uint256 amount = 2 ether;
        uint256 value = 250;

        // Prepare call data with parameter
        bytes memory data = abi.encodeWithSignature("receivePayment(uint256)", value);

        vm.prank(address(timeLock));
        box.executeTransaction(address(payableContract), amount, data);

        assertEq(address(payableContract).balance, amount);
        assertEq(payableContract.getLastValue(), value);

        console.log("This contract just received", amount, "and update value to", value);
    }

    // More executeTransaction() test
    function testExecuteTransactionRevertsWithZeroAddress() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(address(timeLock));
        vm.expectRevert(abi.encodeWithSignature("Box__InvalidAddress()"));
        box.executeTransaction(address(0), 0, data);
    }

    function testExecuteTransactionRevertsIfPaused() public {
        // Pause the contract
        vm.prank(address(timeLock));
        box.pause();

        counter = new Counter();
        bytes memory data = abi.encodeWithSignature("increment()");

        // Try to execute while paused
        vm.prank(address(timeLock));
        vm.expectRevert(abi.encodeWithSignature("Box__Paused()"));
        box.executeTransaction(address(counter), 0, data);
    }

    function testExecuteTransactionRevertsIfNotOwner() public {
        counter = new Counter();
        bytes memory data = abi.encodeWithSignature("increment()");

        // Random user tries to execute
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user));
        box.executeTransaction(address(counter), 0, data);
    }
}

