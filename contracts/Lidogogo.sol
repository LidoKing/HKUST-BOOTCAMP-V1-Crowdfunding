// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "./Voting.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Lidogogo is Voting, Initializable {
    function initialize(address _tokenAddress, address _aavePoolAddress) external initializer {
        tknAddress = _tokenAddress;
        tkn = IERC20(_tokenAddress);

        aavePoolAddress = _aavePoolAddress;
        pool = IPool(_aavePoolAddress);
    }
    //constructor(address _tokenAddress, address _aavePoolAddress) Voting(_tokenAddress, _aavePoolAddress) {}
}
