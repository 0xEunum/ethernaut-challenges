// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {GatekeeperTwo} from "./GatekeeperTwo.sol";

contract GatekeeperTwoCaller {
    constructor(address _gatekeeperTwo) {
        // require(uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max);
        // A ^ B = C;
        // A ^ C = B;
        // require(uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ type(uint64).max) == uint64(_gateKey);

        bytes8 _key = bytes8((uint64(bytes8(keccak256(abi.encodePacked(address(this))))) ^ type(uint64).max));
        GatekeeperTwo(_gatekeeperTwo).enter(_key);
    }
}
