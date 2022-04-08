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
    }

    mapping(uint256 => Project) projects;
    mapping(uint256 => mapping(address => bool)) hasFunded;
    mapping(address => mapping(uint256 => uint256)) fundedAmount;

    modifier canRefund(uint256 _id) {
        Project memory thisProject = projects[_id];
        require(block.timestamp >= thisProject.endTime, "Funding of this project has not ended.");
        require(thisProject.currentAmount < thisProject.goal, "Funding goal has been reached, refund not allowed.");
        _;
    }

    modifier canClaim(uint256 _id) {
        Project memory thisProject = projects[_id];
        require(block.timestamp >= thisProject.endTime, "Funding of this project has not ended.");
        require(
            thisProject.currentAmount >= thisProject.goal,
            "Funding goal is not reached, you cannot claim the funds."
        );
        _;
    }

    modifier notEnded(uint256 _id) {
        Project memory thisProject = projects[_id];
        require(block.timestamp < thisProject.endTime, "Project has ended funding");
        _;
    }

    modifier approvedEnough(uint256 _fundAmount) {
        uint256 allowed = dai.allowance(msg.sender, address(this));
        require(allowed >= toSmallestUnit(_fundAmount), "Amount approved not enough.");
        _;
    }

    constructor(address _daiContractAddress) {
        dai = DAIToken(_daiContractAddress);
    }

    function toSmallestUnit(uint256 _amount) internal pure returns (uint256) {
        return (_amount * 10) ^ 18;
    }

    function createProject(uint256 _goal, uint256 _periodInDays) external {
        Project memory newProject = Project(
            payable(msg.sender),
            0,
            uint128(toSmallestUnit(_goal)),
            0,
            block.timestamp,
            block.timestamp + _periodInDays * 1 days
        );

        projects[projectId] = newProject;
        projectId++;
    }

    function fundProject(uint256 _id, uint256 _amount) external notEnded(_id) approvedEnough(_amount) {
        Project storage thisProject = projects[_id];
        uint256 amountInSmallestUnit = toSmallestUnit(_amount);

        dai.transferFrom(msg.sender, address(this), amountInSmallestUnit);
        thisProject.currentAmount += uint128(amountInSmallestUnit);
        // Will not increase same funder more than once
        if (hasFunded[_id][msg.sender] == false) {
            thisProject.funders++;
        }
        hasFunded[_id][msg.sender] = true;
        fundedAmount[msg.sender][_id] += amountInSmallestUnit;
    }
}
