// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "./Voting.sol";

contract Lidogogo is Voting {
    constructor(address _tokenAddress, address _aavePoolAddress) Voting(_tokenAddress, _aavePoolAddress) {}
}
