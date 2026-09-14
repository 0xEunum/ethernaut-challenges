// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Telephone
 * Objective-1: Claim the ownership of the contract.
 */

contract Telephone {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function changeOwner(address _owner) public {
        if (tx.origin != msg.sender) {
            owner = _owner;
        }
    }
}
