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

    /**
     * @dev Withdraws tokens from staking.
     * @notice If User has some pending rewards they would be transfered to his wallet
     * @notice This would take 4% fee which will be sent to fee wallet.
     * @notice No fee for pending rewards.
     * @param _pid Pool's unique ID.
     * @param _amount The amount to withdraw.
     */
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user
            .amount
            .mul(pool.accSheeshaPerShare)
            .div(PERCENTAGE_DIVIDER)
            .sub(user.rewardDebt);
        if (pending > 0) {
            safeSheeshaTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            uint256 fees = _amount.mul(4).div(100);
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(feeWallet, fees);
            pool.lpToken.safeTransfer(msg.sender, _amount.sub(fees));
        }
        user.rewardDebt = user.amount.mul(pool.accSheeshaPerShare).div(
            PERCENTAGE_DIVIDER
        );
        emit Withdraw(msg.sender, _pid, _amount);
    }

    /**
     * @dev Withdraws all user available amount of tokens without caring about rewards.
     * @notice This would take 4% fee which will be burnt.
     * @param _pid Pool's unique ID.
     */
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 fees = user.amount.mul(4).div(100);
        pool.lpToken.safeTransfer(feeWallet, fees);
        pool.lpToken.safeTransfer(msg.sender, user.amount.sub(fees));
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    /**
     * @dev Used to display user pending rewards on FE
     * @param _pid Pool's unique ID.
     * @param _user Address of user for which dosplay rewards.
     * @return Amount of rewards available
     */
    function pendingSheesha(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accSheeshaPerShare = pool.accSheeshaPerShare;
        uint256 tokenSupply;
        if (pool.token.balanceOf(address(this)) >= tokenRewards) {
            tokenSupply = pool.token.balanceOf(address(this)).sub(tokenRewards);
        }
    }
}