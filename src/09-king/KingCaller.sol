// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {King} from "./King.sol";

contract KingCaller {
    constructor(address payable _king) payable {
        uint256 prize = King(_king).prize();
        (bool success,) = _king.call{value: prize}("");
        require(success, "Transfer failed");
    }
}
