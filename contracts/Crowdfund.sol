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

    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => bool)) hasFunded;
    mapping(uint256 => mapping(address => uint256)) fundedAmount;

    // Refund amount is always a percetage of fund pool (fundedAmount/totalSupply)
    mapping(uint256 => uint256) totalSupply;

    function _mint(
        uint256 _projectId,
        address _to,
        uint256 _amount
    ) private {
        fundedAmount[_projectId][_to] += _amount;
        totalSupply[_projectId] += _amount;
    }

    function _burn(
        uint256 _projectId,
        address _from,
        uint256 _amount
    ) private {
        fundedAmount[_projectId][_from] -= _amount;
        totalSupply[_projectId] -= _amount;
    }

    modifier refundable(uint256 _projectId) {
        Project memory thisProject = projects[_projectId];
        require(block.timestamp >= thisProject.endTime, "Funding of this project has not ended.");
        require(thisProject.currentAmount < thisProject.goal, "Funding goal has been reached, refund not allowed.");
        require(fundedAmount[_projectId][msg.sender] != 0, "You never funded this project / Refund already claimed.");
        _;
    }

    modifier notEnded(uint256 _projectId) {
        Project memory thisProject = projects[_projectId];
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

    function fundProject(uint256 _projectId, uint256 _amount)
        external
        notEnded(_projectId)
        approvedEnough(_amount)
        enoughBalance(_amount)
    {
        Project storage thisProject = projects[_projectId];
        tkn.transferFrom(msg.sender, address(this), _amount);
        thisProject.currentAmount += uint128(_amount);
        // Will not increase same funder more than once
        if (hasFunded[_projectId][msg.sender] == false) {
            thisProject.funders++;
            hasFunded[_projectId][msg.sender] = true;
        }
        _mint(_projectId, msg.sender, _amount);
        emit Fund(_projectId, msg.sender, _amount);
    }

    /*function claimFunds(uint256 _projectId) external initiable(_projectId) {
        Project storage thisProject = projects[_projectId];
        uint256 amount = thisProject.currentAmount;
        thisProject.currentAmount = 0;

        tkn.transfer(msg.sender, amount);
        thisProject.claimed = uint128(amount);
        emit Claim(_projectId);
    }*/

    // Withdraw some funded money
    function reduceFunding(uint256 _projectId, uint256 _amountToReduce) public notEnded(_projectId) {
        Project storage thisProject = projects[_projectId];
        require(fundedAmount[_projectId][msg.sender] >= _amountToReduce, "Amount funded less than withdrawal amount.");

        _burn(_projectId, msg.sender, _amountToReduce);
        tkn.transfer(msg.sender, _amountToReduce);
        if (fundedAmount[_projectId][msg.sender] == 0) {
            thisProject.funders--;
        }
        thisProject.currentAmount -= uint128(_amountToReduce);
        emit Withdraw(_projectId, msg.sender, _amountToReduce);
    }

    // Withdraw all funded money
    /*function reduceFunding(uint256 _projectId) external notEnded(_projectId) {
        uint256 totalFunded = fundedAmount[_projectId][msg.sender];
        reduceFunding(_projectId, totalFunded);
    }*/

    function claimRefund(uint256 _projectId) external refundable(_projectId) {
        Project storage thisProject = projects[_projectId];

        uint256 refundAmount = fundedAmount[_projectId][msg.sender];
        fundedAmount[_projectId][msg.sender] = 0;
        tkn.transfer(msg.sender, refundAmount);
        thisProject.currentAmount -= uint128(refundAmount);
        emit Refund(_projectId, msg.sender, refundAmount);
    }
}
