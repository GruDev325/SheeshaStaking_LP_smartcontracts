// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./SHEESHA.sol";

/**
 * @title Sheesha staking contract
 * @author Sheesha Finance
 */
contract SHEESHAVaultLP is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for SHEESHA;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 checkpoint;
        bool status;
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accSheeshaPerShare;
    }

    uint256 private constant PERCENTAGE_DIVIDER = 1e12;

    SHEESHA public immutable sheesha;
    uint256 public immutable startBlock;
    uint256 public immutable sheeshaPerBlock;

    uint256 public lpRewards = 200_000_000e18;
    uint256 public totalAllocPoint;
    uint256 public userCount;
    address public feeWallet;
    PoolInfo[] public poolInfo;
}