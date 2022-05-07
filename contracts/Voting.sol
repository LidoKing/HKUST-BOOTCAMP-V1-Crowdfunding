// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;

import "./Initiation.sol";

contract Voting is Initiation {
    constructor(address _tokenAddress) Initiation(_tokenAddress) {}

    struct Proposal {
        uint64 voteStart;
        uint64 voteEnd;
        // ID for next improvement proposal
        uint8 ipId;
        bool reworked;
        mapping(uint256 => Improvement) improvements;
        // Voting types: 0 - For, 1 - Against, 2 - Abstain, 3 - Delegated
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
     * @dev Caller is project creator, previous phase has ended
     */
    modifier proceed(uint256 _projectId, uint256 _toPhase) {
        // Only valid in storage due to presence of mappings
        Phase storage prevPhase = projectState[_projectId].phases[_toPhase - 1];
        require(projects[_projectId].creator == msg.sender, "You are not the creator of the project.");
        require(uint64(block.timestamp) > prevPhase.deadline, "Previous phase has not ended.");
        _;
    }

    /**
     * @dev Prerequisites for voting: within voting period, funded project, have not voted
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
     * @dev Proposal initialization
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
        }
    }

    /**
     * @dev Start phase 0
     */
    function initiateDevelopment(
        uint256 _projectId,
        uint256[] calldata _deadlines,
        uint256[] calldata _fundAllocation
    ) external initiable(_projectId) {
        require(_deadlines.length == _fundAllocation.length, "Unmatched number of phases.");
        // Deadlines and fund allocations plan
        _initializeState(_projectId, _deadlines, _fundAllocation);
        // Start voting for proposal
        _initializeProposal(_projectId, 0, false);
    }

    /**
     * @dev Proceed to next phase
     */
    function phaseProposal(uint256 _projectId, uint256 _phase) external proceed(_projectId, _phase) {
        // Start voting for proposal
        _initializeProposal(_projectId, _phase, false);
    }

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

    /**
     * @dev Cast vote (For, Abstain)
     */
    function vote(
        uint256 _projectId,
        uint256 _phase,
        uint256 _type
    ) external votable(_projectId, _phase, msg.sender) {
        _updateVote(_projectId, _phase, _type);
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
        _updateVote(_projectId, _phase, 1);
        Proposal storage thisProposal = proposals[_projectId][_phase];
        thisProposal.improvements[thisProposal.ipId].ipDetail = _improvement;
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
        thisProposal.voteType[msg.sender] = 3;
        uint256 delegateAmount = projects[_projectId].fundedAmount[msg.sender];
        thisProposal.power[msg.sender] = 0;
        thisProposal.power[_delegatee] += delegateAmount;
        thisProposal.delegated[msg.sender] = _delegatee;
        // If delegatee has already voted before delegation, directly add to typeTrack
        if (thisProposal.voted[_delegatee] == true) {
            uint256 delegateeType = thisProposal.voteType[_delegatee];
            thisProposal.typeTrack[delegateeType] += delegateAmount;
        }
    }

    /**
     * @notice Creator has 2 days, upon completion of voting, to submit a revamp of proposal if it was not approved
     * @dev Initiate new voting round and push deadline of remaining phases
     */
    function revampProposal(uint256 _projectId, uint256 _phase) external {
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

        // Push deadline by 7 days for following phases
        uint256 counter = projectState[_projectId].totalPhases;
        for (uint256 i = _phase; i <= counter; i++) {
            // 2 days for submitting rewoek of proposal and 5 days for voting
            projectState[_projectId].phases[i].deadline += uint64(7 days);
        }
    }

    /**
     * @dev Get all suggested improvements
     */
    function getImprovements(uint256 _projectId, uint256 _phase) external view returns (string[] memory) {
        Proposal storage thisProposal = proposals[_projectId][_phase];
        string[] memory result = new string[](thisProposal.ipId);
        for (uint256 i = 0; i < thisProposal.ipId; i++) {
            result[i] = thisProposal.improvements[i].ipDetail;
        }
        return result;
    }
}
