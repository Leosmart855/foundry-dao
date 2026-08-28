// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// Helper contracts for testing
contract PayableContract {
    uint256 public lastValue;
    event Received(address indexed sender, uint256 amount);

    function receivePayment(uint256 value) external payable {
        lastValue = value;
        emit Received(msg.sender, msg.value);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function getLastValue() external view returns (uint256) {
        return lastValue;
    }
}
