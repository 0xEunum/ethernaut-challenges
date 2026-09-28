// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 0x5D62335E8A64519257277C8675d952140F5b39E5

/**
 * @title MagicNum
 * Objective-1: Deploy a solver contract with runtime bytecode <= 10 bytes that returns 42 on whatIsTheMeaningOfLife().
 * Objective-2: Register the solver contract via setSolver() and submit the level.
 */

contract MagicNum {
    address public solver;

    constructor() {}

    function setSolver(address _solver) public {
        solver = _solver;
    }
}
