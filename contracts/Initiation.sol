pragma solidity >=0.8.4 <0.9.0;

import "./Crowdfund.sol";

contract Initiation is Crowdfund {
    constructor(address _tokenAddress) Crowdfund(_tokenAddress) {}

    // State is initiated through "initiateDevelopment(...)" by project creator once funding is completed
    // Phase 0: approve development arrangements and fund allocation
    struct State {
        uint256 phases;
        uint256 currentPhase;
        mapping(uint256 => uint256) phaseDeadline;
        mapping(uint256 => uint256) fundForPhase;
    }

    // porjectId -> project state
    mapping(uint256 => State) projectState;

    function initiateDevelopment(
        uint256 _id,
        uint256[] calldata _deadlines,
        uint256[] calldata _fundAllocation
    ) external canClaim(_id) {}
}
