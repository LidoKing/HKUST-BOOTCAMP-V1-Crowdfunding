pragma solidity >=0.8.4 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./UnitConverter.sol";

contract TestToken is ERC20, UnitConverter {
    constructor(address[] testers) ERC20("Test Token", "TKN") {
        uint256 mintAmount = to18Decimals(1000);
        for (uint256 i = 0; i < testers.length; i++) {
            _mint(testers[i], mintAmount);
        }
    }
}
