// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

//import "./DAIToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Crowdfund {
    /**
     * @dev 'f' indicates that event is for funding stage
     */
    event NewProject(uint256 projectId, address creator, uint256 goal, uint256 periodInDays);
    event fFund(uint256 indexed projectId, address funder, uint256 amount);
    event Withdraw(uint256 indexed projectId, address funder, uint256 amount);
    event fRefund(uint256 indexed projectId, address funder, uint256 amount);

    uint256 projectId;
    //IDAIToken dai;
    address public tknAddress;
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

    /**
     * @dev Ethereum mainnet DAI: 0x6B175474E89094C44Da98b954EedeAC495271d0F
     *      Polygon mainnet DAI: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063
     */
    /*
    constructor(address _tokenAddress) {
        //dai = IDAIToken(_tokenAddress);
        tknAddress = _tokenAddress;
        tkn = IERC20(_tokenAddress);
    }
    */

    function getFundedAmount(uint256 _projectId) public view returns (uint256) {
        return projects[_projectId].fundedAmount[msg.sender];
    }

    modifier isFunder(uint256 _projectId) {
        require(projects[_projectId].hasFunded[msg.sender] == true, "You did not fund this project.");
        _;
    }

    /**
     * @dev Funding ended, funding goal reached, has funded, never refunded
     */
    modifier fundingRefundable(uint256 _projectId) {
        Project storage thisProject = projects[_projectId];
        require(block.timestamp >= thisProject.endTime, "Funding of this project has not ended.");
        require(thisProject.currentAmount < thisProject.goal, "Funding goal has been reached, refund not allowed.");
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

        emit NewProject(projectId, msg.sender, _goal, _periodInDays);
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
        emit fFund(_projectId, msg.sender, _amount);
    }

    /**
     * @dev Reduce funded amount during funding phase, remove funder if all funded money is withdrawn
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

    /**
     * @dev Claim refund for failed funding
     */
    function fundingRefund(uint256 _projectId) external fundingRefundable(_projectId) isFunder(_projectId) {
        Project storage thisProject = projects[_projectId];

        thisProject.refunded[msg.sender] = true;
        uint256 refundAmount = _refundAmount(_projectId);
        _burn(_projectId, msg.sender, refundAmount);
        tkn.transfer(msg.sender, refundAmount);
        thisProject.currentAmount -= uint128(refundAmount);
        emit fRefund(_projectId, msg.sender, refundAmount);
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

    /**
     * @dev Get refund amount by multiplying current fund pool amount by percentage of ownership of virtual refund token
     */
    function _refundAmount(uint256 _projectId) internal view returns (uint256) {
        Project storage thisProject = projects[_projectId];
        return (thisProject.fundedAmount[msg.sender] / thisProject.totalSupply) * thisProject.currentAmount;
    }
}
