// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;

import "./Initiation.sol";

contract Voting is Initiation {
    constructor(address _tokenAddress) Crowdfund(_tokenAddress) {}

    mapping(uint256 => mapping(address => uint256)) power;
    mapping(uint256 => mapping(address => bool)) voted;

    modifier votable(uint256 _id, address _caller) {
        require(hasFunded[_id][_caller] == true, "You did not fund this project.");
        require(voted[_id][_caller] == false, "You have already voted.");
        _;
    }

    modifier checkPhase(uint256 _id, uint256 _phase) {
        State storage thisState = projectState[_id];
        require(block.timestamp <= thisState.phaseDeadline[_phase], "Voting for this phase has ended.");
        _;
    }

    function _register(uint256 _id, address _funder) private {
        power[_id][_funder] = fundedAmount[_id][_funder];
    }
}
