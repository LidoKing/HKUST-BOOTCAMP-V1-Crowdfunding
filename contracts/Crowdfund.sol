// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;

//import "./DAIToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Crowdfund {
    event New(uint256 id, address indexed creator, uint256 goal, uint256 periodInDays);
    event Fund(uint256 indexed id, address indexed funder, uint256 amount);
    event Withdraw(uint256 indexed id, address indexed withdrawer, uint256 amount);
    event Claim(uint256 id);
    event Refund(uint256 indexed id, address funder, uint256 amount);

    uint256 projectId;
    //IDAIToken dai;
    IERC20 tkn;

    struct Project {
        address payable creator; // pack 1
        uint64 funders; // pack 1
        uint128 goal; // pack 2
        uint128 currentAmount; // pack 2
        uint64 startTime; // pack 3
        uint64 endTime; // pack 3
        uint128 claimed; //pack 3
    }

    // State is initiated through "initiateDevelopment(...)" by project creator once funding is completed
    // Phase 0: approve development arrangements and fund allocation
    struct State {
        uint256 phases;
        uint256 currentPhase;
        mapping(uint256 => uint256) phaseDeadline;
        mapping(uint256 => uint256) fundForPhase;
    }

    mapping(uint256 => Project) public projects;
    mapping(Project => State) projectState;
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
        uint256 allowed = tkn.allowance(msg.sender, address(this));
        require(allowed >= _fundAmount, "Amount approved not enough.");
        _;
    }

    modifier enoughBalance(uint256 _fundAmount) {
        uint256 balance = tkn.balanceOf(msg.sender);
        require(balance >= _fundAmount, "You do not have enough money.");
        _;
    }

    constructor(address _tokenAddress) {
        //dai = IDAIToken(_tokenAddress);
        tkn = IERC20(_tokenAddress);
    }

    /*function toSmallestUnit(uint256 _amount) internal pure returns (uint256) {
        return _amount * (10 ** 18);
    }*/

    function createProject(uint256 _goal, uint256 _periodInDays) external {
        projects[projectId] = Project(
            payable(msg.sender),
            0,
            uint128(_goal),
            0,
            uint64(block.timestamp),
            uint64(block.timestamp + _periodInDays * 1 days),
            0
        );
        emit New(projectId, msg.sender, _goal, _periodInDays);
        projectId++;
    }

    function fundProject(uint256 _id, uint256 _amount)
        external
        notEnded(_id)
        approvedEnough(_amount)
        enoughBalance(_amount)
    {
        Project storage thisProject = projects[_id];
        tkn.transferFrom(msg.sender, address(this), _amount);
        thisProject.currentAmount += uint128(_amount);
        // Will not increase same funder more than once
        if (hasFunded[_id][msg.sender] == false) {
            thisProject.funders++;
            hasFunded[_id][msg.sender] = true;
        }
        fundedAmount[_id][msg.sender] += _amount;
        emit Fund(_id, msg.sender, _amount);
    }

    function claimFunds(uint256 _id) external canClaim(_id) {
        Project storage thisProject = projects[_id];
        uint256 amount = thisProject.currentAmount;
        thisProject.currentAmount = 0;

        tkn.transfer(msg.sender, amount);
        thisProject.claimed = uint128(amount);
        emit Claim(_id);
    }

    // Withdraw some funded money
    function reduceFunding(uint256 _id, uint256 _amountToReduce) public notEnded(_id) {
        Project storage thisProject = projects[_id];
        require(fundedAmount[_id][msg.sender] >= _amountToReduce, "Amount funded less than withdrawal amount.");

        fundedAmount[_id][msg.sender] -= _amountToReduce;

        tkn.transfer(msg.sender, _amountToReduce);
        thisProject.currentAmount -= uint128(_amountToReduce);
        emit Withdraw(_id, msg.sender, _amountToReduce);
    }

    // Withdraw all funded money
    /*function reduceFunding(uint256 _id) external notEnded(_id) {
        uint256 totalFunded = fundedAmount[_id][msg.sender];
        reduceFunding(_id, totalFunded);
    }*/

    function claimRefund(uint256 _id) external canRefund(_id) {
        Project storage thisProject = projects[_id];

        uint256 refundAmount = fundedAmount[_id][msg.sender];
        fundedAmount[_id][msg.sender] = 0;
        tkn.transfer(msg.sender, refundAmount);
        thisProject.currentAmount -= uint128(refundAmount);
        emit Refund(_id, msg.sender, refundAmount);
    }
}
