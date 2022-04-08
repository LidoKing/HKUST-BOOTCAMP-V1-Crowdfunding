// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;

import "./DAIToken.sol";

contract Crowdfund {
    uint256 projectId;
    DAIToken dai;

    struct Project {
        address payable creator;
        uint64 funders;
        uint128 goal;
        uint128 currentAmount;
        uint256 startTime;
        uint256 endTime;
        bool ended;
    }

    mapping(uint256 => Project) projects;
    mapping(uint256 => mapping(address => bool)) hasFunded;
    mapping(address => mapping(uint256 => uint256)) fundedAmount;

    constructor(address _daiContractAddress) {
        DAIToken dai = DAIToken(_daiContractAddress);
    }

    function toSmallestUnit(uint256 _amount) internal returns (uint256) {
        return (_amount * 10) ^ 18;
    }

    function createProject(uint128 _goal, uint256 _periodInDays) external {
        Project memory newProject = Project(
            payable(msg.sender),
            0,
            _goal,
            0,
            block.timestamp,
            block.timestamp + _periodInDays * 1 days,
            false
        );

        projects[projectId] = newProject;
        projectId++;
    }

    function fundProject(uint256 _id, uint256 _amount) external {}
}
