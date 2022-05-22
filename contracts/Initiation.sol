// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "./Crowdfund.sol";
import "./Farming.sol";

contract Initiation is Crowdfund, Farming {
    /**
     * @dev 'dev' indicates that event is for development stage
     */
    event Initiate(uint256 projectId, uint256 numberOfPhases);
    event devClaim(uint256 indexed projectId, uint256 phase, uint256 amount);
    event devRefund(uint256 indexed projectId, address funder, uint256 amount);

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
        PhaseStatus status;
    }

    uint64 constant votingPeriod = 5 days;

    mapping(uint256 => State) projectState;

    constructor(address _tokenAddress, address _aavePoolAddress) Crowdfund(_tokenAddress) Farming(_aavePoolAddress) {}

    /**
     * @dev Getter for phase detail
     */
    function phaseDetail(uint256 _projectId, uint256 _phase)
        public
        view
        returns (
            uint64,
            uint128,
            PhaseStatus
        )
    {
        Phase storage thisPhase = projectState[_projectId].phases[_phase];
        require(uint8(_phase) <= projectState[_projectId].totalPhases, "There is no such phase.");
        return (thisPhase.deadline, thisPhase.fundAllocated, thisPhase.status);
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
            PhaseStatus
        )
    {
        Phase storage thisPhase = projectState[_projectId].phases[projectState[_projectId].currentPhase];
        return (thisPhase.deadline, thisPhase.fundAllocated, thisPhase.status);
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

        emit Initiate(_projectId, thisState.totalPhases);
    }

    /**
     * @dev Claim allocated funds for the corresponding phase
     */
    function _claimPhase(uint256 _projectId, uint256 _phase) internal {
        State storage thisState = projectState[_projectId];
        thisState.phases[_phase].status = PhaseStatus.Claimed;
        uint256 claimAmount;
        // If current phase is last phase, creator claims all remaining funds including all accrued interest
        if (thisState.currentPhase == thisState.totalPhases) {
            claimAmount = _withdrawFromAave(0, true);
        } else {
            uint256 allocatedAmount = uint256(thisState.phases[_phase].fundAllocated);
            claimAmount = _withdrawFromAave(allocatedAmount, false);
        }
        tkn.transfer(msg.sender, claimAmount);

        emit devClaim(_projectId, _phase, claimAmount);
    }

    /**
     * @dev Approve aave contract to spend funds, reduce project currentAmount to 0
     */
    function _depositToAave(uint256 _projectId) internal {
        uint256 depositAmount = uint256(projects[_projectId].currentAmount);
        // Increase allowance for aave contract to call transferFrom
        tkn.approve(aavePoolAddress, depositAmount);
        _supply(tknAddress, address(this), depositAmount);
        projects[_projectId].currentAmount = 0;
    }

    /**
     * @dev No need to modify project currentAmount which will remain as 0 due to immediate transfer after withdrawal from aave
     */
    function _withdrawFromAave(uint256 _withdrawAmount, bool _withdrawAll) internal returns (uint256) {
        uint256 withdrawed;

        if (_withdrawAll) {
            // According to aave doc, a withdrawal amount of type(uint).max means all reamaining user balance
            withdrawed = _withdraw(tknAddress, type(uint256).max, address(this));
        } else {
            withdrawed = _withdraw(tknAddress, _withdrawAmount, address(this));
        }

        return withdrawed;
    }
}
