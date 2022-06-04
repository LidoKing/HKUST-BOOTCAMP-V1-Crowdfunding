// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LINDToken is ERC20 {
    address owner;

    constructor(address _owner) ERC20("Lindogogo", "LIND") {
        owner = _owner;
        uint256 mintAmount = 5000 * (10**18);
        _mint(_owner, mintAmount);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not qualified");
        _;
    }

    function getTokens(uint256 _amount) external onlyOwner {
        _mint(msg.sender, _amount);
    }
}
