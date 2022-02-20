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

    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(uint256 => address) public userList;
    mapping(address => bool) internal isExisting;

    /**
     * @dev Emitted when a user deposits tokens.
     * @param user Address of user for which deposit was made.
     * @param pid Pool's unique ID.
     * @param amount The amount of deposited tokens.
     */
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);

    /**
     * @dev Emitted when a user withdraw tokens from staking.
     * @param user Address of user for which deposit was made.
     * @param pid Pool's unique ID.
     * @param amount The amount of deposited tokens.
     */
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    /**
     * @dev Emitted when a user withdraw tokens from staking without caring about rewards.
     * @param user Address of user for which deposit was made.
     * @param pid Pool's unique ID.
     * @param amount The amount of deposited tokens.
     */
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    /**
     * @dev Constructor of the contract.
     * @param _sheesha Sheesha native token.\

     
     * @param _feeWallet Address where fee would be transfered.
     * @param _startBlock Start block of staking contract.
     * @param _sheeshaPerBlock Amount of Sheesha rewards per block.
     */
    constructor(
        SHEESHA _sheesha,
        address _feeWallet,
        uint256 _startBlock,
        uint256 _sheeshaPerBlock
    ) {
        require(address(_sheesha) != address(0), "Sheesha can't be address 0");
        require(_feeWallet != address(0), "Fee wallet can't be address 0");
        sheesha = _sheesha;
        feeWallet = _feeWallet;
        startBlock = _startBlock;
        sheeshaPerBlock = _sheeshaPerBlock;
    }

    function changeFeeWallet(address _feeWallet) external onlyOwner {
        require(_feeWallet != address(0), "Fee wallet can't be address 0");
        feeWallet = _feeWallet;
    }

    /**
     * @dev Creates new pool for staking.
     * @param _allocPoint Allocation points of new pool.
     * @param _lpToken Address of pool token.
     * @param _withUpdate Declare if it needed to update all other pools
     */
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) external onlyOwner {
        for (uint256 i; i < poolInfo.length; i++) {
            require(poolInfo[i].lpToken != _lpToken, "Pool already exist");
        }
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accSheeshaPerShare: 0
            })
        );
    }

    /**
     * @dev Updates allocation points of chosen pool
     * @param _pid Pool's unique ID.
     * @param _allocPoint Desired allocation points of new pool.
     * @param _withUpdate Declare if it needed to update all other pools
     */
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    /**
     * @dev Add rewards for Sheesha staking
     * @param _amount Amount of rewards to be added.
     */
    function addRewards(uint256 _amount) external {
        require(_amount > 0, "Invalid amount");
        IERC20(sheesha).safeTransferFrom(msg.sender, address(this), _amount);
        lpRewards = lpRewards.add(_amount);
    }

    /**
     * @dev Deposits tokens by user to staking contract.
     * @notice User first need to approve deposited amount of tokens
     * @notice If User has some pending rewards they would be transfered to his wallet
     * @param _pid Pool's unique ID.
     * @param _amount The amount to deposit.
     */
    function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
        _deposit(msg.sender, _pid, _amount);
    }

    /**
     * @dev Deposits tokens for specific user in staking contract.
     * @notice Caller of method first need to approve deposited amount of tokens
     * @notice If User has some pending rewards they would be transfered to his wallet
     * @param _depositFor Address of user for which deposit is created
     * @param _pid Pool's unique ID.
     * @param _amount The amount to deposit.
     */
    function depositFor(
        address _depositFor,
        uint256 _pid,
        uint256 _amount
    ) external nonReentrant {
        _deposit(_depositFor, _pid, _amount);
    }
}