// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;

interface DAIToken {
    function allowance(address arg1, address arg2) external returns (uint256);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);
}
