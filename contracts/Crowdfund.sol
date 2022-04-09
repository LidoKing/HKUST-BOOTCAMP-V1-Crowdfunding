// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;

import "./DAIToken.sol";

contract Crowdfund {
    uint256 projectId;
    DAIToken dai;

    struct Project {
        address payable creator; // pack 1
        uint64 funders; // pack 1
        uint128 goal; // pack 2
        uint128 currentAmount; // pack 2
        uint64 startTime; // pack 3
        uint64 endTime; // pack 3
        uint128 claimed; //pack 3
    }

    mapping(uint256 => Project) projects;
    mapping(uint256 => mapping(address => bool)) hasFunded;
    mapping(uint256 => mapping(address => uint256)) fundedAmount;

    modifier canRefund(uint256 _id) {
        Project memory thisProject = projects[_id];
        require(block.timestamp >= thisProject.endTime, "Funding of this project has not ended.");
        require(thisProject.currentAmount < thisProject.goal, "Funding goal has been reached, refund not allowed.");
        require(fundedAmount[_id][msg.sender] != 0, "You never funded this project / Refund already claimed.");
        _;
    }

    modifier canClaim(uint256 _id) {
        Project memory thisProject = projects[_id];
        require(thisProject.creator == msg.sender, "You are not the creator of the project.");
        require(block.timestamp >= thisProject.endTime, "Funding of this project has not ended.");
        require(
            thisProject.currentAmount >= thisProject.goal,
            "Funding goal is not reached / Funds already been claimed."
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
            uint64(block.timestamp),
            uint64(block.timestamp + _periodInDays * 1 days),
            0
        );

        projects[projectId] = newProject;
        projectId++;
    }

    function fundProject(uint256 _id, uint256 _amount) external notEnded(_id) approvedEnough(_amount) {
        Project storage thisProject = projects[_id];
        uint256 amountSU = toSmallestUnit(_amount);

        dai.transferFrom(msg.sender, address(this), amountSU);
        thisProject.currentAmount += uint128(amountSU);
        // Will not increase same funder more than once
        if (hasFunded[_id][msg.sender] == false) {
            thisProject.funders++;
        }
        hasFunded[_id][msg.sender] = true;
        fundedAmount[_id][msg.sender] += amountSU;
    }

    function claimFunds(uint256 _id) external canClaim(_id) {
        Project storage thisProject = projects[_id];
        uint256 amount = thisProject.currentAmount;
        thisProject.currentAmount = 0;

        dai.transfer(msg.sender, amount);
        thisProject.claimed = uint128(amount);
    }

    function reduceFunding(uint256 _id, uint256 _amountToReduce) external notEnded(_id) {
        Project storage thisProject = projects[_id];
        uint256 _amountToReduceSU = toSmallestUnit(_amountToReduce);
        require(fundedAmount[_id][msg.sender] >= _amountToReduceSU, "Amount funded less than withdrawal amount.");

        fundedAmount[_id][msg.sender] -= _amountToReduceSU;

        dai.transfer(msg.sender, _amountToReduceSU);
        thisProject.currentAmount -= uint128(_amountToReduceSU);
    }

    function claimRefund(uint256 _id) external canRefund(_id) {
        uint256 refundAmount = fundedAmount[_id][msg.sender];
        fundedAmount[_id][msg.sender] = 0;
        dai.transfer(msg.sender, refundAmount);
    }
}
