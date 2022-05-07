// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;

import "./Crowdfund.sol";

contract Initiation is Crowdfund {
    constructor(address _tokenAddress) Crowdfund(_tokenAddress) {}

    /**
     * @notice Phase 0: approve development arrangements and fund allocation
     * @dev State is initiated through "proposeDevelopment(...)" by project creator once funding is completed
     */
    struct State {
        uint8 totalPhases;
        uint8 currentPhase;
        uint128 totalVotes;
        uint128 threshold;
        mapping(uint256 => Phase) phases;
    }

    struct Phase {
        uint256 deadline;
        uint256 fundAllocated;
        bool reachedThreshold;
        bool claimed;
    }

    /**
     * @dev porjectId -> project state
     */
    mapping(uint256 => State) projectState;

    modifier proposable(uint256 _projectId) {
        Project storage thisProject = projects[_projectId];
        require(thisProject.creator == msg.sender, "You are not the creator of the project.");
        require(block.timestamp >= thisProject.endTime, "Funding of this project has not ended.");
        require(thisProject.currentAmount >= thisProject.goal, "Funding goal is not reached.");
        _;
    }

    modifier proceed(uint256 _projectId, uint256 _toPhase) {
        Project storage thisProject = projects[_projectId];
        // Only valid in storage due to presence of mappings
        Phase storage thisPhase = projectState[_projectId].phases[_toPhase - 1];
        require(thisProject.creator == msg.sender, "You are not the creator of the project.");
        require(thisPhase.reachedThreshold == true, "Previous phase not approved.");
        require(block.timestamp > thisPhase.deadline, "Previous phase has not ended.");
        _;
    }

    /**
     * @notice Submit plan for project before initiation
     * @dev Initialize State struct
     * @param _deadlines and _fundAllocation of the same phase should have the same index
     */
    function proposeDevelopment(
        uint256 _projectId,
        uint256[] calldata _deadlines,
        uint256[] calldata _fundAllocation
    ) external proposable(_projectId) {
        require(_deadlines.length == _fundAllocation.length, "Unmatched number of phases.");
        Project storage thisProject = projects[_projectId];

        // Declaration for structs with mappings
        State storage thisState = projectState[_projectId];
        thisState.totalPhases = uint8(_deadlines.length);
        thisState.currentPhase = 0;
        thisState.totalVotes = thisProject.currentAmount;
        thisState.threshold = (thisState.totalVotes / 100) * 80;
        thisState.phases[0].deadline = block.timestamp + 2 days;

        for (uint256 i = 0; i <= _deadlines.length; i++) {
            Phase storage thisPhase = thisState.phases[i + 1];
            // 5 days for voting
            thisPhase.deadline = _deadlines[i] + 5 days;
            thisPhase.fundAllocated = _fundAllocation[i];
            thisPhase.claimed = false;
        }
    }

    /**
     * @dev Start project after phase 0 has passed
     */
    function initiateDevelopment(uint256 _projectId) external proceed(_projectId, 1) {
        State storage thisState = projectState[_projectId];
        thisState.currentPhase = 1;
        _claimFunds(_projectId, 1);
    }

    /**
     * @dev Proceed to next phase, claiming funds and initializing new round of voting
     */
    /*
    function nextPhase(uint256 _projectId, uint256 _toPhase) external proceed(_projectId, _toPhase) {
        State storage thisState = projectState[_projectId];
        thisState.currentPhase = uint8(_toPhase);
        _claimFunds(_projectId, _toPhase);
    }*/

    /**
     * @dev Claim allocated funds for the corresponding phase
     */
    function _claimFunds(uint256 _projectId, uint256 _toPhase) private {
        Project storage thisProject = projects[_projectId];
        Phase storage thisPhase = projectState[_projectId].phases[_toPhase];
        require(thisPhase.claimed == false, "Funds for this phase has already been claimed.");
        thisPhase.claimed = true;
        uint256 amount = thisPhase.fundAllocated;
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
            bool
        )
    {
        Phase storage thisPhase = projectState[_projectId].phases[_phase];
        require(uint8(_phase) <= projectState[_projectId].totalPhases, "There is no such phase.");
        return (thisPhase.deadline, thisPhase.fundAllocated, thisPhase.claimed);
    }
}
