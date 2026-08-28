// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

//import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Helper contracts for testing
contract Counter {
    uint256 public count;

    function increment() external {
        count++;
    }

    function incrementBy(uint256 amount) external {
        count += amount;
    }

    function getCount() external view returns (uint256) {
        return count;
    }
}

