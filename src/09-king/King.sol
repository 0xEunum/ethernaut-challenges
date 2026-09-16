// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title King
 * Objective: When you submit the instance back to the level,
 * the level will claim back kingship.
 * Prevent the level from reclaiming kingship to complete the level.
 */

contract King {
    address king;
    uint256 public prize;
    address public owner;

    constructor() payable {
        owner = msg.sender;
        king = msg.sender;
        prize = msg.value;
    }

    receive() external payable {
        require(msg.value >= prize || msg.sender == owner);
        payable(king).transfer(msg.value);
        king = msg.sender;
        prize = msg.value;
    }

    function _king() public view returns (address) {
        return king;
    }
}
