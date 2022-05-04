// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;

import "./Crowdfund.sol";

contract Initiation is Crowdfund {
    constructor(address _tokenAddress) Crowdfund(_tokenAddress) {}

    // State is initiated through "initiateDevelopment(...)" by project creator once funding is completed
    // Phase 0: approve development arrangements and fund allocation
    struct State {
        uint8 phases;
        uint8 currentPhase;
        uint128 totalVotes;
        mapping(uint256 => uint256) currentVotes;
        mapping(uint256 => uint256) phaseDeadline;
        mapping(uint256 => uint256) fundForPhase;
    }

    // porjectId -> project state
    mapping(uint256 => State) projectState;

    modifier initiable(uint256 _id) {
        Project memory thisProject = projects[_id];
        require(thisProject.creator == msg.sender, "You are not the creator of the project.");
        require(block.timestamp >= thisProject.endTime, "Funding of this project has not ended.");
        require(thisProject.currentAmount >= thisProject.goal, "Funding goal is not reached.");
        _;
    }

    modifier proceed(uint256 _id) {}

    function proposeDevelopment(
        uint256 _id,
        uint256[] calldata _deadlines,
        uint256[] calldata _fundAllocation
    ) external initiable(_id) {
        require(_deadlines.length == _fundAllocation.length, "Unmatched number of phases.");
        Project memory thisProject = projects[_id];
        // Declaration for structs with mappings
        State storage thisState = projectState[_id];
        thisState.phases = _deadlines.length;
        thisState.currentPhase = 0;
        thisState.totalVotes = thisProject.currentAmount;
        thisState.currentVotes[0] = thisState.totalVotes;
        thisState.phaseDeadline[0] = block.timestamp + 2 days;

        for (uint256 i = 0; i <= _deadlines.length; i++) {
            thisState.phaseDeadline[i + 1] = _deadlines[i];
            thisState.fundForPhase[i + 1] = _fundAllocation[i];
        }
    }

    /*function initiateDevelopment(uint _id) external {

    }*/

    function phaseDetail(uint256 _id, uint256 _phase) public view returns (uint256, uint256) {
        State memory thisState = projectState[_id];
        require(uint8(_phase) <= thisState.phases);
        return (thisState.phaseDeadline[_phase], thisState.fundForPhase[_phase]);
    }
}
