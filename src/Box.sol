// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    // State variables
    uint256 private sNumber;
    string private sName;
    address private sTreasury;
    bool private sPaused; // defaults to false as contract is not paused at first
    uint256 private sWithdrawalLimit;
    mapping(address => uint256) private sAllowances;

    // Events
    event NumberChanged(uint256 newNumber, address indexed changedBy);
    event NameChanged(string newName, address indexed changedBy);
    event TreasuryChanged(address newTreasury, address indexed changedBy);
    event ContractPaused(bool paused, address indexed changedBy);
    event WithdrawalLimitChanged(uint256 newLimit, address indexed changedBy);
    event FundsWithdrawn(address indexed to, uint256 amount, address indexed by);
    event AllowanceGranted(address indexed user, uint256 amount, address indexed by);
    event AllowanceRevoked(address indexed user, address indexed by);

    // Errors
    error Box__Paused();
    error Box__NotPaused();
    error Box__NameCanNotBeEmpty();
    error Box__InsufficientAllowance();
    error Box__WithdrawalFailed();
    error Box__InvalidAddress();
    error Box__CanNotCallSelf();
    error Box__InvalidAmount();

    ///////////////////////////////
    /////      MODIFIERS     /////
    /////////////////////////////
    modifier whenNotPaused() {
        _whenNotPaused();
        _;
    }

    modifier whenPaused() {
        _whenPaused();
        _;
    }

    ///////////////////////////////////////
    // INTERNAL FUNCTIONS FOR MODIFIERS //
    //////////////////////////////////////
    function _whenNotPaused() internal view {
        if (sPaused) {
            revert Box__Paused();
        }
    }

    function _whenPaused() internal view {
        if (!sPaused) {
            revert Box__NotPaused();
        }
    }

    constructor() Ownable(msg.sender) {
        sTreasury = msg.sender;
        sWithdrawalLimit = 50 ether; // Default 1 ETH limit
        sName = "Governance Box";
    }

    //////////////////////////////////////////////
    ///           STORE NUMBER             //////
    ////////////////////////////////////////////
    function storeNumber(uint256 newNumber) public onlyOwner whenNotPaused {
        sNumber = newNumber;
        emit NumberChanged(newNumber, msg.sender);
    }

    //////////////////////////////////////////////
    ///             CHANGE NAME            //////
    ////////////////////////////////////////////
    function changeName(string memory newName) public onlyOwner whenNotPaused {
        if (bytes(newName).length == 0) {
            revert Box__NameCanNotBeEmpty();
        }
        sName = newName;
        emit NameChanged(newName, msg.sender);
    }

    ///////////////////////////////////////////////
    ///           CHANGE TREASURY           ///////
    //////////////////////////////////////////////
    function changeTreasury(address newTreasury) public onlyOwner whenNotPaused {
        if (newTreasury == address(0)) {
            revert Box__InvalidAddress();
        }
        sTreasury = newTreasury;
        emit TreasuryChanged(newTreasury, msg.sender);
    }

    ///////////////////////////////////////////////////
    //      PAUSE/UNPAUSE - Emergency feature        //
    //////////////////////////////////////////////////
    function pause() public onlyOwner whenNotPaused {
        sPaused = true;
        emit ContractPaused(true, msg.sender);
    }

    function unpause() public onlyOwner whenPaused {
        sPaused = false;
        emit ContractPaused(false, msg.sender);
    }

    /////////////////////////////////////////////////
    ///         SET WITHDRAWAL LIMIT           /////
    ///////////////////////////////////////////////
    function setWithdrawalLimit(uint256 newLimit) public onlyOwner whenNotPaused {
        sWithdrawalLimit = newLimit;
        emit WithdrawalLimitChanged(newLimit, msg.sender);
    }

    ////////////////////////////////////////////////////
    //   GRANT/REVOKE ALLOWANCES - Permission system  //
    ///////////////////////////////////////////////////
    function grantAllowance(address user, uint256 amount) public onlyOwner whenNotPaused {
        if (user == address(0)) {
            revert Box__InvalidAddress();
        }
        if (amount == 0) {
            revert Box__InvalidAmount();
        }
        sAllowances[user] = amount;
        emit AllowanceGranted(user, amount, msg.sender);
    }

    function revokeAllowance(address user) public onlyOwner whenNotPaused {
        if (user == address(0)) {
            revert Box__InvalidAddress();
        }
        delete sAllowances[user];
        emit AllowanceRevoked(user, msg.sender);
    }

    ////////////////////////////////////////////
    //  WITHDRAW FUNDS - Treasury management  //
    ///////////////////////////////////////////
    function withdrawFunds(address to, uint256 amount) public onlyOwner whenNotPaused {
        if (to == address(0)) {
            revert Box__InvalidAddress();
        }
        if (amount <= 0) {
            revert Box__InvalidAmount();
        }
        if (amount > sWithdrawalLimit) {
            revert Box__InvalidAmount();
        }
        if (amount > address(this).balance) {
            revert Box__InvalidAmount();
        }

        (bool success,) = to.call{value: amount}("");
        if (!success) {
            revert Box__WithdrawalFailed();
        }

        emit FundsWithdrawn(to, amount, msg.sender);
    }

    ///////////////////////////////////////////////////////
    //   EXECUTE ANY TRANSACTION - Advanced governance   //
    //        Only for calling external contracts        //
    //////////////////////////////////////////////////////
    function executeTransaction(address target, uint256 value, bytes memory data)
        public
        onlyOwner
        whenNotPaused
        returns (bytes memory)
    {
        if (target == address(0)) {
            revert Box__InvalidAddress();
        }
        if (target == address(this)) {
            revert Box__CanNotCallSelf();
        }

        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            // If the call failed, revert with the actual error message
            if (result.length > 0) {
                assembly {
                    revert(add(32, result), mload(result))
                }
            } else {
                revert("Transaction execution failed");
            }
        }
        return result;
    }

    ///////////////////////////////////////////////////////////
    //   RECEIVE ETHER - Allow contract to receive funds   ///
    //////////////////////////////////////////////////////////
    receive() external payable {
        // Contract can receive ETH
    }

    //////////////////////////////////////////////
    ///         GETTER FUNCTIONS           //////
    ////////////////////////////////////////////
    function getNumber() public view returns (uint256) {
        return sNumber;
    }

    function getName() public view returns (string memory) {
        return sName;
    }

    function getTreasury() public view returns (address) {
        return sTreasury;
    }

    function paused() public view returns (bool) {
        return sPaused;
    }

    function getWithdrawalLimit() public view returns (uint256) {
        return sWithdrawalLimit;
    }

    function getAllowance(address user) public view returns (uint256) {
        return sAllowances[user];
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    //////////////////////////////////////////////
    //    VIEW FUNCTIONS - Contract info     /////
    /////////////////////////////////////////////
    function getContractInfo()
        public
        view
        returns (
            uint256 number,
            string memory name,
            address treasury,
            bool isPaused,
            uint256 withdrawalLimit,
            uint256 balance
        )
    {
        return (sNumber, sName, sTreasury, sPaused, sWithdrawalLimit, address(this).balance);
    }
}
