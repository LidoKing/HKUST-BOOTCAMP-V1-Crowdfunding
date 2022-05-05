pragma solidity >=0.8.4 <0.9.0;

contract Refund {
    mapping(uint256 => uint256) totalSupply;
    mapping(uint256 => mapping(address => uint256)) balanceOf;
}
