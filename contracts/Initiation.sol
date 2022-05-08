// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;
import "./Crowdfund.sol";

contract Initiation is Crowdfund {
    enum PhaseStatus {
        Voting,
        Claimed,
        Refunding
    }

    /**
     * @notice Phase 0: approve development arrangements and fund allocation
     * @dev State is initiated through "proposeDevelopment(...)" by project creator once funding is completed
     */
    struct State {
        uint8 totalPhases; // excluding phase 0
        uint8 currentPhase;
        uint128 totalVotes;
        uint128 threshold;
        mapping(uint256 => Phase) phases;
    }

    struct Phase {
        uint64 deadline;
        uint128 fundAllocated;
        phaseStatus status;
    }

    uint64 constant votingPeriod = 5 days;

    /**
     * @dev porjectId -> project state
     */
    mapping(uint256 => State) projectState;

    constructor(address _tokenAddress) Crowdfund(_tokenAddress) {}

    /**
     * @dev Getter for phase detail
     */
    function phaseDetail(uint256 _projectId, uint256 _phase)
        public
        view
        returns (
            uint64,
            uint128,
            bool,
            bool
        )
    {
        Phase storage thisPhase = projectState[_projectId].phases[_phase];
        require(uint8(_phase) <= projectState[_projectId].totalPhases, "There is no such phase.");
        return (thisPhase.deadline, thisPhase.fundAllocated, thisPhase.voting, thisPhase.claimed);
    }

    /**
     * @dev Getter for current phase
     */
    function currentPhaseDetail(uint256 _projectId)
        public
        view
        returns (
            uint64,
            uint128,
            bool
        )
    {
        Phase storage thisPhase = projectState[_projectId].phases[projectState[_projectId].currentPhase];
        return (thisPhase.deadline, thisPhase.fundAllocated, thisPhase.voting);
    }

    /**
     * @notice Submit plan for project before initiation
     * @dev Initialize State struct
     * @param _deadlines and _fundAllocation of the same phase should have the same index
     * @param _deadlines include the 5 days voting period
     *        e.g. _deadlines[20/5, 20/6, 10/7], block.timestamp = 8/5
     *             Phase 0: 8/5-13/5; Phase 1: 13/5-20/5; Phase 2: 20/5-20/6; Phase 3: 20/6-10/7
     */
    function _initializeState(
        uint256 _projectId,
        uint256[] calldata _deadlines,
        uint256[] calldata _fundAllocation
    ) internal {
        Project storage thisProject = projects[_projectId];

        // Declaration for structs with mappings
        State storage thisState = projectState[_projectId];
        thisState.totalPhases = uint8(_deadlines.length);
        thisState.currentPhase = 0;
        thisState.totalVotes = thisProject.currentAmount;
        thisState.threshold = (thisState.totalVotes / 100) * 80;
        thisState.phases[0].deadline = uint64(block.timestamp + 5 days);

        for (uint256 i = 0; i <= _deadlines.length; i++) {
            Phase storage thisPhase = thisState.phases[i + 1];
            // 5 days for voting
            thisPhase.deadline = uint64(_deadlines[i]);
            thisPhase.fundAllocated = uint128(_fundAllocation[i]);
        }
    }

    /**
     * @dev Claim allocated funds for the corresponding phase
     */
    function _claimPhase(uint256 _projectId, uint256 _phase) internal {
        Project storage thisProject = projects[_projectId];
        Phase storage thisPhase = projectState[_projectId].phases[_phase];
        thisPhase.status = phaseStatus.Claimed;
        uint128 amount = thisPhase.fundAllocated;
        tkn.transfer(msg.sender, amount);
        thisProject.currentAmount -= amount;
    }
}
