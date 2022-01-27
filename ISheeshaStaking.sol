// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

interface ISheeshaStaking {
    /**
     * @dev Deposits tokens for specific user in staking contract.
     * @param _depositFor Address of user for which deposit is created 
     * @param _pid Pool's unique ID.
     * @param _amount The amount to deposit.
     */
    function depositFor(
        address _depositFor,
        uint256 _pid,
        uint256 _amount
    ) external;
}