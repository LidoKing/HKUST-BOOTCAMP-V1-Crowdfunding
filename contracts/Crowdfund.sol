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
        uint128 goal; // pack 1
        uint128 currentAmount; // pack 2
        uint64 startTime; // pack 2
        uint64 endTime; // pack 2
        // Refund amount is always a percetage of fund pool (fundedAmount/totalSupply)
        uint256 totalSupply; // pack 3
        mapping(address => bool) hasFunded;
        mapping(address => uint256) fundedAmount;
        mapping(address => bool) refunded;
    }

    mapping(uint256 => Project) public projects;

    constructor(address _tokenAddress) {
        //dai = IDAIToken(_tokenAddress);
        tkn = IERC20(_tokenAddress);
    }

    /**
     * @dev Funding ended, funding goal reached, has funded, never refunded
     */
    modifier fundingRefundable(uint256 _projectId) {
        Project storage thisProject = projects[_projectId];
        require(block.timestamp >= thisProject.endTime, "Funding of this project has not ended.");
        require(thisProject.currentAmount < thisProject.goal, "Funding goal has been reached, refund not allowed.");
        require(thisProject.hasFunded[msg.sender] != true, "You did not fund this project.");
        require(thisProject.refunded[msg.sender] == false, "Refund has already been claimed");
        _;
    }

    modifier notEnded(uint256 _projectId) {
        Project storage thisProject = projects[_projectId];
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

    /**
     * @dev Initialize new project
     */
    function createProject(uint256 _goal, uint256 _periodInDays) external {
        Project storage thisProject = projects[projectId];
        thisProject.creator = payable(msg.sender);
        thisProject.funders = 0;
        thisProject.goal = uint128(_goal);
        thisProject.currentAmount = 0;
        thisProject.startTime = uint64(block.timestamp);
        thisProject.endTime = uint64(block.timestamp + _periodInDays * 1 days);
        thisProject.totalSupply = 0;

        emit New(projectId, msg.sender, _goal, _periodInDays);
        projectId++;
    }

    /**
     * @dev Fund project and mint refund tokens
     */
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
        if (thisProject.hasFunded[msg.sender] == false) {
            thisProject.funders++;
            thisProject.hasFunded[msg.sender] = true;
        }
        _mint(_projectId, msg.sender, _amount);
        emit Fund(_projectId, msg.sender, _amount);
    }

    /**
     * @dev Reduce funded amount, remove funder if all funded money is taken away
     */
    function reduceFunding(uint256 _projectId, uint256 _amountToReduce) public notEnded(_projectId) {
        Project storage thisProject = projects[_projectId];
        require(thisProject.fundedAmount[msg.sender] >= _amountToReduce, "Amount funded less than withdrawal amount.");

        _burn(_projectId, msg.sender, _amountToReduce);
        tkn.transfer(msg.sender, _amountToReduce);
        thisProject.currentAmount -= uint128(_amountToReduce);
        if (thisProject.fundedAmount[msg.sender] == 0) {
            thisProject.funders--;
            thisProject.hasFunded[msg.sender] = false;
        }
        emit Withdraw(_projectId, msg.sender, _amountToReduce);
    }

    // Withdraw all funded money
    /*function reduceFunding(uint256 _projectId) external notEnded(_projectId) {
        uint256 totalFunded = thisProject.fundedAmount[msg.sender];
        reduceFunding(_projectId, totalFunded);
    }*/

    /**
     * @dev Refund for funding phase
     */
    function fundingRefund(uint256 _projectId) external fundingRefundable(_projectId) {
        Project storage thisProject = projects[_projectId];

        thisProject.refunded[msg.sender] = true;
        uint256 refundAmount = _refundAmount(_projectId);
        _burn(_projectId, msg.sender, refundAmount);
        tkn.transfer(msg.sender, refundAmount);
        thisProject.currentAmount -= uint128(refundAmount);
        emit Refund(_projectId, msg.sender, refundAmount);
    }

    /**
     * @dev Mint virtual refund tokens
     */
    function _mint(
        uint256 _projectId,
        address _to,
        uint256 _amount
    ) private {
        Project storage thisProject = projects[_projectId];
        thisProject.fundedAmount[_to] += _amount;
        thisProject.totalSupply += _amount;
    }

    /**
     * @dev Burn virtual refund tokens
     */
    function _burn(
        uint256 _projectId,
        address _from,
        uint256 _amount
    ) private {
        Project storage thisProject = projects[_projectId];
        thisProject.fundedAmount[_from] -= _amount;
        thisProject.totalSupply -= _amount;
    }

    function _refundAmount(uint256 _projectId) internal returns (uint256) {
        Project storage thisProject = projects[_projectId];
        return (thisProject.fundedAmount[msg.sender] / thisProject.totalSupply) * thisProject.currentAmount;
    }
}
