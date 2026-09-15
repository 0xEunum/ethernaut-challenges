// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IToken {
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external returns (uint256);
}

contract TokenCaller {
    constructor(address _token) {
        IToken(_token).transfer(msg.sender, 1);
    }
}
