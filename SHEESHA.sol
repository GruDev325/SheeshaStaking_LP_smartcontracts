// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SHEESHA is ERC20Burnable, Ownable {
    using SafeMath for uint256;

    uint256 private constant INITIAL_SUPPLY = 1_000_000_000e18;
    address public immutable partnershipEcosystemMarketing;
    address public immutable treasury;
    address public immutable forLiquidityPool;
    bool public vaultTransferDone;
    bool public vaultLPTransferDone;
    bool public vestingTransferDone;

    /**
     * @dev Constructor of the contract.
     * @param partnershipEcosystemMarketing_ Address where partnership
     * tokens to send (10% of supply).
     * @param treasury_ Address where treasury tokens to send (10% of supply).
     * @param forLiquidityPool_ Address where tokens for future liquidity
     * to send(0.5% of total supply).
     */
    constructor(
        address partnershipEcosystemMarketing_,
        address treasury_,
        address forLiquidityPool_
    ) ERC20("SHEESHA POLYGON", "mSHEESHA") {
        partnershipEcosystemMarketing = partnershipEcosystemMarketing_;
        treasury = treasury_;
        forLiquidityPool = forLiquidityPool_;
        _mint(address(this), INITIAL_SUPPLY);
        _transfer(
            address(this),
            partnershipEcosystemMarketing_,
            INITIAL_SUPPLY.mul(10).div(100)
        );
        _transfer(
            address(this),
            treasury_,
            INITIAL_SUPPLY.mul(10).div(100)
        );
        _transfer(
            address(this),
            forLiquidityPool_,
            INITIAL_SUPPLY.mul(5).div(1000)
        );
    } 

}