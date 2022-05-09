// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;

import "./Initiation.sol";

contract Voting is Initiation {
    event Propose(uint256 indexed projectId, uint256 phase, uint256 deadline);
    event Vote(uint256 indexed projectId, uint256 phase, address funder, uint256 voteType);
    event ProposeImprovement(uint256 indexed projectId, uint256 phase, address fromFunder, uint256 improvementId);
    event Delegate(uint256 indexed projectId, uint256 phase, address delegater, address delegatee);
    event Rework(uint256 indexed projectId, uint256 phase, uint256 newPhaseDeadline);

    struct Proposal {
        uint64 voteStart;
        uint64 voteEnd;
        // ID for next improvement proposal
        uint8 ipId;
        bool reworked;
        mapping(uint256 => Improvement) improvements;
        // Voting types: 1 - For, 2 - Against, 3 - Abstain, 4 - Delegated
        mapping(address => uint256) voteType;
        mapping(uint256 => uint256) typeTrack;
        mapping(address => address) delegated;
        mapping(address => uint256) power;
        mapping(address => bool) voted;
    }

    struct Improvement {
        string ipDetail;
    }

    // project ID -> phase -> proposal
    mapping(uint256 => mapping(uint256 => Proposal)) proposals;
    mapping(uint256 => mapping(uint256 => Proposal)) reworks;

    constructor(address _tokenAddress, address _aavePoolAddress) Initiation(_tokenAddress, _aavePoolAddress) {}

    /**
     * @dev Getter for all suggested improvements
     */
    function getImprovements(uint256 _projectId, uint256 _phase) public view returns (string[] memory result) {
        Proposal storage thisProposal = proposals[_projectId][_phase];
        result = new string[](thisProposal.ipId);
        for (uint256 i = 0; i < thisProposal.ipId; i++) {
            result[i] = thisProposal.improvements[i].ipDetail;
        }
        return result;
    }

    /**
     * @dev Getter for proposal status of specific phase
     */
    function getProposal(uint256 _projectId, uint256 _phase)
        public
        view
        returns (
            uint64 start,
            uint64 end,
            uint256[3] memory types
        )
    {
        Proposal storage thisProposal = proposals[_projectId][_phase];
        start = thisProposal.voteStart;
        end = thisProposal.voteEnd;
        for (uint256 i = 0; i < 3; i++) {
            types[i] = thisProposal.typeTrack[i];
        }
        return (start, end, types);
    }

    /**
     * @dev Caller is project creator, fundign has ended, funding goal reached
     */
    modifier initiable(uint256 _projectId) {
        Project storage thisProject = projects[_projectId];
        require(thisProject.creator == msg.sender, "You are not the creator of the project.");
        require(uint64(block.timestamp) >= thisProject.endTime, "Funding of this project has not ended.");
        require(thisProject.currentAmount >= thisProject.goal, "Funding goal is not reached.");
        _;
    }

    /**
     * @dev Caller is project creator, previous phase has ended, previous phase passed
     */
    modifier proceed(uint256 _projectId, uint256 _toPhase) {
        // Only valid in storage due to presence of mappings
        Phase storage prevPhase = projectState[_projectId].phases[_toPhase - 1];
        require(projects[_projectId].creator == msg.sender, "You are not the creator of the project.");
        require(uint64(block.timestamp) > prevPhase.deadline, "Previous phase has not ended.");
        require(
            uint128(proposals[_projectId][_toPhase - 1].typeTrack[_toPhase - 1]) >=
                projectState[_projectId].threshold ||
                uint128(reworks[_projectId][_toPhase - 1].typeTrack[_toPhase - 1]) >=
                projectState[_projectId].threshold,
            "Previous phase not passed, cannot proceed."
        );
        _;
    }

    /**
     * @dev Within voting period, funded project, have not voted
     */
    modifier votable(
        uint256 _projectId,
        uint256 _phase,
        address _funder
    ) {
        Proposal storage thisProposal = proposals[_projectId][_phase];
        require(
            uint64(block.timestamp) >= thisProposal.voteStart && uint64(block.timestamp) <= thisProposal.voteEnd,
            "Not within voting period"
        );
        require(projects[_projectId].hasFunded[msg.sender] == true, "You did not fund this project.");
        require(proposals[_projectId][_phase].voted[msg.sender] == false, "You have already voted.");
        _;
    }

    /**
     * @dev Scenario 1: Rework passed -> claim phase fund (voting ended, sum of vote types less than or equal totalVotes, rework passed)
     *      Scenario 2: Proposal passed -> claim phase fund (voting ended, sum of vote types less than or equal totalVotes, proposal passed)
     */
    modifier claimable(
        uint256 _projectId,
        uint256 _phase,
        address _claimer
    ) {
        Proposal storage thisProposal = proposals[_projectId][_phase];
        require(msg.sender == projects[_projectId].creator, "You are not the creator of the project.");
        require(
            projectState[_projectId].phases[_phase].status == PhaseStatus.Voting,
            "Funds for this phase has already been claimed."
        );
        if (thisProposal.reworked == true) {
            Proposal storage thisReworked = reworks[_projectId][_phase];
            require(thisReworked.voteEnd < uint64(block.timestamp), "Voting period has not ended");
            require(
                uint128(thisReworked.typeTrack[0] + thisReworked.typeTrack[1] + thisReworked.typeTrack[2]) <=
                    projectState[_projectId].totalVotes,
                "Unequal total votes, abnormality detected."
            );
            require(
                uint128(thisReworked.typeTrack[0]) >= projectState[_projectId].threshold,
                "Reworked proposal rejected, development terminated"
            );
        } else {
            require(thisProposal.voteEnd < uint64(block.timestamp), "Voting period has not ended");
            require(
                uint128(thisProposal.typeTrack[0] + thisProposal.typeTrack[1] + thisProposal.typeTrack[2]) <=
                    projectState[_projectId].totalVotes,
                "Unequal total votes, abnormality detected."
            );
            require(
                uint128(thisProposal.typeTrack[0]) >= projectState[_projectId].threshold,
                "Proposal rejected, submission of rework of proposal is expected."
            );
        }
        _;
    }

    /**
     * @dev Voting ended, rework rejected, has funded, not yet refunded
     */
    modifier devRefundable(uint256 _projectId) {
        uint256 phase = projectState[_projectId].currentPhase;
        Proposal storage thisProposal = reworks[_projectId][phase];
        require(thisProposal.voteEnd < uint64(block.timestamp), "Voting period has not ended.");
        require(
            thisProposal.typeTrack[0] < projectState[_projectId].threshold,
            "Proposal passed, refund not available."
        );
        require(projects[_projectId].hasFunded[msg.sender] == true, "You did not fund this project.");
        require(projects[_projectId].refunded[msg.sender] == false, "Refund has already been claimed.");
        _;
    }

    /**
     * @dev Start phase 0
     * @param _deadlines and _fundAllocation of the same phase should have the same index
     * @param _deadlines include the 5 days voting period
     */
    function initiateDevelopment(
        uint256 _projectId,
        uint256[] calldata _deadlines,
        uint256[] calldata _fundAllocation
    ) external initiable(_projectId) {
        require(_deadlines.length == _fundAllocation.length, "Unmatched number of phases.");
        // Deadlines and fund allocations plan
        _initializeState(_projectId, _deadlines, _fundAllocation);
        // Deposit all funds to aave staking pool
        _depositToAave(_projectId);
        // Start voting for proposal
        _initializeProposal(_projectId, 0, false);

        emit Propose(_projectId, 0, block.timestamp + uint256(votingPeriod));
    }

    /**
     * @notice New proposal means new phase initiated
     * @dev Proceed to next phase
     * @param _phase The phase to proceed to
     */
    function phaseProposal(uint256 _projectId, uint256 _phase) external proceed(_projectId, _phase) {
        projectState[_projectId].currentPhase = uint8(_phase);
        // Start voting for proposal
        _initializeProposal(_projectId, _phase, false);

        emit Propose(_projectId, _phase, projectState[_projectId].phases[_phase].deadline);
    }

    /**
     * @dev Cast vote (For, Abstain)
     */
    function vote(
        uint256 _projectId,
        uint256 _phase,
        uint256 _type
    ) external votable(_projectId, _phase, msg.sender) {
        _updateVote(_projectId, _phase, _type);

        emit Vote(_projectId, _phase, msg.sender, _type);
    }

    /**
     * @dev Cast vote (Agaisnt)
     * @param _improvement - what should be added
     */
    function against(
        uint256 _projectId,
        uint256 _phase,
        string calldata _improvement
    ) external {
        _updateVote(_projectId, _phase, 2);

        emit Vote(_projectId, _phase, msg.sender, 2);

        Proposal storage thisProposal = proposals[_projectId][_phase];
        thisProposal.improvements[thisProposal.ipId].ipDetail = _improvement;

        emit ProposeImprovement(_projectId, _phase, msg.sender, thisProposal.ipId);

        thisProposal.ipId++;
    }

    /**
     * @dev Give all votes to delegatee, increase typeTrack directly if delegatee has already voted
     */
    function delegate(
        uint256 _projectId,
        uint256 _phase,
        address _delegatee
    ) external votable(_projectId, _phase, msg.sender) {
        require(projects[_projectId].hasFunded[_delegatee] == true, "Delegatee is not a funder of the project.");
        Proposal storage thisProposal = proposals[_projectId][_phase];
        thisProposal.voted[msg.sender] = true;
        thisProposal.voteType[msg.sender] = 4;
        uint256 delegateAmount = projects[_projectId].fundedAmount[msg.sender];
        thisProposal.power[msg.sender] = 0;
        thisProposal.power[_delegatee] += delegateAmount;
        thisProposal.delegated[msg.sender] = _delegatee;

        emit Delegate(_projectId, _phase, msg.sender, _delegatee);

        // If delegatee has already voted before delegation, directly add to typeTrack
        if (thisProposal.voted[_delegatee] == true) {
            uint256 delegateeType = thisProposal.voteType[_delegatee];
            thisProposal.typeTrack[delegateeType] += delegateAmount;

            emit Vote(_projectId, _phase, msg.sender, delegateeType);
        }
    }

    /**
     * @notice Creator has 2 days, upon completion of voting, to submit a rework of proposal if it was not approved
     * @dev Initiate new voting round and push deadline of remaining phases
     */
    function reworkProposal(uint256 _projectId, uint256 _phase) external {
        Proposal storage thisProposal = proposals[_projectId][_phase];
        require(msg.sender == projects[_projectId].creator, "You are not the creator of the project.");
        require(thisProposal.reworked == false, "Proposal has been reworked for once already.");
        // Period for submission of revemped proposal
        require(
            uint64(block.timestamp) > thisProposal.voteEnd &&
                uint64(block.timestamp) <= thisProposal.voteEnd + uint64(2 days),
            "Period of submitting rework of proposal has passed."
        );
        thisProposal.reworked = true;
        _initializeProposal(_projectId, _phase, true);

        // Push deadline by (block.timestamp - voteEnd + 5 days) for following phases, 5 days for voting
        uint64 delay = uint64(block.timestamp - thisProposal.voteEnd + 5 days);
        uint256 counter = projectState[_projectId].totalPhases;
        for (uint256 i = _phase; i <= counter; i++) {
            projectState[_projectId].phases[i].deadline += delay;
        }

        emit Rework(_projectId, _phase, uint256(projectState[_projectId].phases[_phase].deadline));
    }

    /**
     * @dev Fund claim with voting and time condition check
     */
    function claimFunds(uint256 _projectId, uint256 _phase) external claimable(_projectId, _phase, msg.sender) {
        _claimPhase(_projectId, _phase);
    }

    /**
     * @dev Retrieve remaining funds if rework of proposal also rejected
     *      No need to modify project currentAmount which will remain as 0 due to immediate transfer after withdrawal from aave
     */
    function developmentRefund(uint256 _projectId) external devRefundable(_projectId) {
        Project storage thisProject = projects[_projectId];
        thisProject.refunded[msg.sender] = true;
        uint256 refundAmount = _refundAmount(_projectId);
        thisProject.totalSupply -= refundAmount;
        _withdrawFromAave(refundAmount, false);
        tkn.transfer(msg.sender, refundAmount);

        emit devRefund(_projectId, msg.sender, refundAmount);
    }

    /**
     * @dev Proposal initialization
     * @param _rework Determines if proposal is first submission or reworked version
     */
    function _initializeProposal(
        uint256 _projectId,
        uint256 _phase,
        bool _rework
    ) private {
        if (_rework) {
            Proposal storage thisProposal = reworks[_projectId][_phase];
            thisProposal.voteStart = uint64(block.timestamp);
            thisProposal.voteEnd = uint64(block.timestamp) + votingPeriod;
            thisProposal.ipId = 0;
            thisProposal.reworked = false;
        } else {
            Proposal storage thisProposal = proposals[_projectId][_phase];
            thisProposal.voteStart = uint64(block.timestamp);
            thisProposal.voteEnd = uint64(block.timestamp) + votingPeriod;
            thisProposal.ipId = 0;
            thisProposal.reworked = false;
            projectState[_projectId].phases[_phase].status = PhaseStatus.Voting;
        }
    }

    /**
     * @dev Update voting state of Proposal struct
     */
    function _updateVote(
        uint256 _projectId,
        uint256 _phase,
        uint256 _type
    ) private {
        Proposal storage thisProposal = proposals[_projectId][_phase];
        thisProposal.voted[msg.sender] = true;
        thisProposal.power[msg.sender] = projects[_projectId].fundedAmount[msg.sender];
        thisProposal.voteType[msg.sender] = _type;
        uint256 voteAmount = thisProposal.power[msg.sender];
        thisProposal.typeTrack[_type] += voteAmount;
    }
}
