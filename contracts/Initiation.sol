// SPDX-License-Identifier: UNLICENSED

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
    ) external canClaim(_id) {
        require(_deadlines.length == _fundAllocation.length, "Unmatched number of phases.");
        // Declaration for structs with mappings
        State storage thisState = projectState[_id];
        thisState.phases = _deadlines.length;
        thisState.currentPhase = 0;
        thisState.phaseDeadline[0] = block.timestamp + 2 days;

        for (uint256 i = 0; i <= _deadlines.length; i++) {
            thisState.phaseDeadline[i + 1] = _deadlines[i];
            thisState.fundForPhase[i + 1] = _fundAllocation[i];
        }
    }
}
