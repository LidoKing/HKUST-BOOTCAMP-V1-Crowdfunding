// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;

library SS {
    struct Proposal {
        uint64 time;
        uint8 ipId;
        mapping(uint256 => Improvement) improvements;
        // Voting types: 0 - For, 1 - Against, 2 - Abstain, 3 - Delegated
        mapping(address => uint256) voteType;
        mapping(uint256 => uint256) stanceTrack;
        mapping(address => address) delegated;
        mapping(address => uint256) power;
        mapping(address => bool) voted;
    }

    struct Improvement {
        string ipDetail;
        bool adopted;
    }
}
