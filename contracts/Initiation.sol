// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;

import "./Crowdfund.sol";

contract Initiation is Crowdfund {
    /**
     * @notice Phase 0: approve development arrangements and fund allocation
     * @dev State is initiated through "initiateDevelopment(...)" by project creator once funding is completed
     */
    struct State {
        uint8 phases;
        uint8 currentPhase;
        uint128 totalVotes;
        uint128 threshold;
        mapping(uint256 => uint256) currentVotes;
        mapping(uint256 => uint256) phaseDeadline;
        mapping(uint256 => uint256) fundForPhase;
        mapping(uint256 => bool) phaseClaimed;
    }

    /**
     * @dev porjectId -> project state
     */
    mapping(uint256 => State) projectState;

    modifier initiable(uint256 _projectId) {
        Project memory thisProject = projects[_projectId];
        require(thisProject.creator == msg.sender, "You are not the creator of the project.");
        require(block.timestamp >= thisProject.endTime, "Funding of this project has not ended.");
        require(thisProject.currentAmount >= thisProject.goal, "Funding goal is not reached.");
        _;
    }

    modifier proceed(uint256 _projectId, uint256 _phase) {
        Project memory thisProject = projects[_projectId];
        // Only valid in storage due to presence of mappings
        State storage thisState = projectState[_projectId];
        require(thisProject.creator == msg.sender, "You are not the creator of the project.");
        require(thisState.currentVotes[_phase - 1] >= thisState.threshold, "Previous phase not approved.");
        require(block.timestamp > thisState.phaseDeadline[_phase - 1], "Previous phase has not ended.");
        _;
    }

    /**
     * @notice Submit plan for project before initiation
     * @dev Initialize State struct
     * @param Information of the same phase should have the same index
     */
    function proposeDevelopment(
        uint256 _projectId,
        uint256[] calldata _deadlines,
        uint256[] calldata _fundAllocation
    ) external initiable(_projectId) {
        require(_deadlines.length == _fundAllocation.length, "Unmatched number of phases.");
        Project memory thisProject = projects[_projectId];
        // Declaration for structs with mappings
        State storage thisState = projectState[_projectId];
        thisState.phases = uint8(_deadlines.length);
        thisState.currentPhase = 0;
        thisState.totalVotes = thisProject.currentAmount;
        thisState.threshold = (thisState.totalVotes / 100) * 80;
        thisState.currentVotes[0] = 0;
        thisState.phaseDeadline[0] = block.timestamp + 2 days;

        for (uint256 i = 0; i <= _deadlines.length; i++) {
            thisState.phaseDeadline[i + 1] = _deadlines[i];
            thisState.fundForPhase[i + 1] = _fundAllocation[i];
        }
    }

    /**
     * @dev Start project after phase 0 has passed
     */
    function initiateDevelopment(uint256 _projectId) external proceed(_projectId, 1) {
        State storage thisState = projectState[_projectId];
        thisState.currentPhase = 1;
        thisState.currentVotes[1] = 0;
        _claimFunds(_projectId, 1);
    }

    /**
     * @dev Proceed to next phase, claiming funds and initializing new round of voting
     */
    function nextPhase(uint256 _projectId, uint256 _phase) external proceed(_projectId, _phase) {
        State storage thisState = projectState[_projectId];
        thisState.currentPhase = uint8(_phase);
        thisState.currentVotes[_phase] = 0;
        _claimFunds(_projectId, _phase);
    }

    /**
     * @dev Claim allocated funds for the corresponding phase
     */
    function _claimFunds(uint256 _projectId, uint256 _phase) private {
        Project storage thisProject = projects[_projectId];
        State storage thisState = projectState[_projectId];
        require(thisState.phaseClaimed[_phase] == false, "Funds for this phase has already been claimed.");
        thisState.phaseClaimed[_phase] = true;
        uint256 amount = thisState.fundForPhase[_phase];
        tkn.transfer(msg.sender, amount);
        thisProject.currentAmount -= uint128(amount);
    }

    /**
     * @dev Getter function for phase detail
     */
    function phaseDetail(uint256 _projectId, uint256 _phase)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        State storage thisState = projectState[_projectId];
        require(uint8(_phase) <= thisState.phases);
        return (thisState.phaseDeadline[_phase], thisState.fundForPhase[_phase], thisState.currentVotes[_phase]);
    }
}
