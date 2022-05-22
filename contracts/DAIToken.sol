// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

// Reference: https://github.com/makerdao/dss/blob/master/src/dai.sol

interface IDAIToken {
    function allowance(address arg1, address arg2) external returns (uint256);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);

    function transfer(address dst, uint256 wad) external returns (bool);
}
