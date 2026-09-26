// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//0x148f9b2169EAcf6FB8bFf33e3bbAcb4a22F68830

/**
 * @title Recovery
 * Objective-1: Recover the 0.001 ETH lost in the created contract by finding its address and calling destroy().
 */

contract Recovery {
    //generate tokens
    function generateToken(string memory _name, uint256 _initialSupply) public {
        new SimpleToken(_name, msg.sender, _initialSupply);
    }
}

//0xca25e5c999a132c1f0af9e5c7104d01983abcd66

contract SimpleToken {
    string public name;
    mapping(address => uint256) public balances;

    // constructor
    constructor(string memory _name, address _creator, uint256 _initialSupply) {
        name = _name;
        balances[_creator] = _initialSupply;
    }

    // collect ether in return for tokens
    receive() external payable {
        balances[msg.sender] = msg.value * 10;
    }

    // allow transfers of tokens
    function transfer(address _to, uint256 _amount) public {
        require(balances[msg.sender] >= _amount);
        balances[msg.sender] = balances[msg.sender] - _amount;
        balances[_to] = _amount;
    }

    // clean up after ourselves
    function destroy(address payable _to) public {
        selfdestruct(_to);
    }
}
