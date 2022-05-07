// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;

import "./Initiation.sol";

contract Voting is Initiation {
    constructor(address _tokenAddress) Initiation(_tokenAddress) {}

    struct Proposal {
        uint64 time;
        uint8 ipId;
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
        bool adopted;
    }

    // project ID -> phase -> proposal
    mapping(uint256 => mapping(uint256 => Proposal)) proposals;

    /**
     * @dev Prerequisites for voting: funded project, have not voted, before phase deadline
     */
    modifier votable(
        uint256 _projectId,
        uint256 _phase,
        address _funder
    ) {
        Phase storage thisPhase = projectState[_projectId].phases[_phase];
        require(block.timestamp <= thisPhase.deadline, "Voting for this phase has ended.");
        require(projects[_projectId].hasFunded[msg.sender] == true, "You did not fund this project.");
        require(proposals[_projectId][_phase].voted[msg.sender] == false, "You have already voted.");
        _;
    }

    /**
     * @dev Passive registration for voting power when casting vote
     */
    /*function _register(uint256 _projectId, uint256 _phase, address _funder) private {
        power[_projectId][_phase][_funder] = fundedAmount[_projectId][_phase][_funder];
    }*/

    /*function _updateVote(uint256 _projectId, address _funder, uint _type) {
        voted[_projectId][_phase][_funder] = true;
        typeTrack[_projectId][_phase][_type] += power[_funder];
    }*/

    /**
     * @dev Cast vote (For, Against, Abstain)
     */
    function vote(
        uint256 _projectId,
        uint256 _phase,
        uint256 _type
    ) external votable(_projectId, _phase, msg.sender) {
        Proposal storage thisProposal = proposals[_projectId][_phase];
        thisProposal.voted[msg.sender] = true;
        thisProposal.power[msg.sender] = projects[_projectId].fundedAmount[msg.sender];
        thisProposal.voteType[msg.sender] = _type;
        uint256 voteAmount = thisProposal.power[msg.sender];
        thisProposal.typeTrack[_type] += voteAmount;
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
}
