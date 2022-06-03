// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LINDToken is ERC20 {
    mapping(address => bool) isTester;

    constructor(address[5] memory _testers) ERC20("Lindogogo", "LIND") {
        uint256 mintAmount = 1000 * (10**18);
        for (uint256 i = 0; i < _testers.length; i++) {
            isTester[_testers[i]] = true;
            _mint(_testers[i], mintAmount);
        }
    }

    modifier onlyTesters() {
        require(isTester[msg.sender] == true, "You are not qualified");
        _;
    }

    function getTokens(uint256 _amount) external onlyTesters {
        _mint(msg.sender, _amount);
    }
}
