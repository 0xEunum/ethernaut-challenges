// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ForceCaller {
    constructor(address payable _force) payable {
        selfdestruct(_force);
    }
}
