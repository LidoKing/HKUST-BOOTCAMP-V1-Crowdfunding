// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4 <0.9.0;

import { IPool } from "@aave/core-v3/contracts/interfaces/IPool.sol";

contract Farming {
    address public aavePoolAddress;
    IPool pool;

    /**
     * @dev Mainnets address (same for different blockchains): 0x794a61358D6845594F94dc1DB02A252b5b4814aD
     */
    constructor(address _poolContractAddress) {
        aavePoolAddress = _poolContractAddress;
        pool = IPool(_poolContractAddress);
    }

    /**
     * @dev Supply tokens to aave staking pool
     * @param _user is crowdfunding platform contract
     */
    function _supply(
        address _token,
        address _user,
        uint256 _amount
    ) internal {
        pool.supply(_token, _amount, _user, 0);
    }

    /**
     * @dev Withdraw tokens from aave staking pool
     * @param _to is crowdfunding platform contract
     */
    function _withdraw(
        address _token,
        uint256 _amount,
        address _to
    ) internal returns (uint256) {
        uint256 withdrawed = pool.withdraw(_token, _amount, _to);
        return withdrawed;
    }
}
