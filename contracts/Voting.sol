// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;

import "./Initiation.sol";

contract Voting is Initiation {
    constructor(address _tokenAddress) Crowdfund(_tokenAddress) {}

    // Track voting power for delegation
    mapping(uint256 => mapping(address => uint256)) power;
    // Track voting types: 0 - For, 1 - Against, 2 - Abstain
    mapping(uint256 => mapping(address => uint256)) stance;
    // Track funder voting condition
    mapping(uint256 => mapping(address => bool)) voted;

    modifier votable(uint256 _projectId, address _caller) {
        require(hasFunded[_projectId][_caller] == true, "You did not fund this project.");
        require(voted[_projectId][_caller] == false, "You have already voted.");
        _;
    }

    modifier checkPhase(uint256 _projectId, uint256 _phase) {
        State storage thisState = projectState[_projectId];
        require(block.timestamp <= thisState.phaseDeadline[_phase], "Voting for this phase has ended.");
        _;
    }
}
