// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "../helpers/BaseConnector.sol";
import "../external/interfaces/Balancer/IBalancerVault.sol";
import "../external/interfaces/Balancer/IBalancerPool.sol";

    struct PoolInfo {
        address pool;
        address[] tokens;
        uint256 tokenIndex;
        bytes32 poolId;
        address auraPoolAddress;
        uint256 boosterPoolId;
        address poolBaseToken;
        uint256 poolBaseTokenDecimalsDiff;
    }

    struct DecreasePositionParams {
        bytes32 poolId;
        uint256 _lpAmount;
        uint256 withdrawIndex;
        uint256 outerIndex;
        uint256 minAmount;
        uint256 _auraAmount;
    }

contract BalancerConnector is BaseConnector {

    address internal balancerVault;

    address public BAL;
    address public AURA;

    uint256 public BALANCER_LP_POSITION = 1;

    event OpenPosition(
        bytes32 poolId, uint256[] amounts, uint256[] amountsWithoutBPT, uint256 minBPT, uint256 auraAmount
    );
    event DecreasePosition(DecreasePositionParams p);

    /**
     * Constructor *********************************
     */
    constructor(address _balancerVault, address bal, address aura, BaseConnectorCP memory baseConnectorParams)
    BaseConnector(baseConnectorParams)
    {
        require(_balancerVault != address(0));
        require(bal != address(0));
        require(aura != address(0));
        AURA = aura;
        BAL = bal;
        balancerVault = _balancerVault;
        connectorType = "BALANCER";
    }

    function harvestAuraRewards(address[] calldata rewardsPools) public onlyManager nonReentrant whenNotPaused {
        for (uint256 i = 0; i < rewardsPools.length; i++) {
            IRewardPool baseRewardPool = IRewardPool(rewardsPools[i]);
            baseRewardPool.getReward();

            // Issue #1402:
            uint256 extraRewardsLength = baseRewardPool.extraRewardsLength();
            for (uint256 y = 0; y < extraRewardsLength; y++) {
                address extraRewardsPool = baseRewardPool.extraRewards(y);
                address extraRewardToken = IRewardPool(extraRewardsPool).rewardToken();
                address baseToken = IRewardPool(extraRewardToken).baseToken();
                _updateTokenInRegistry(baseToken);
            }
        }
        //Issue #1402:
        _updateTokenInRegistry(address(BAL));
        _updateTokenInRegistry(address(AURA));
    }

    /**
     * Internal Functions *********************************
     */
    function openPosition(
        bytes32 poolId,
        uint256[] memory amounts,
        uint256[] memory amountsWithoutBPT,
        uint256 minBPT,
        uint256 auraAmount
    ) public onlyManager nonReentrant whenNotPaused {
        address[] memory tokens;
        {
            (tokens,,) = IBalancerVault(balancerVault).getPoolTokens(poolId);
        }
        (address pool,) = IBalancerVault(balancerVault).getPool(poolId);

        for (uint256 i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0) _approveOperations(tokens[i], balancerVault, amounts[i]);
        }

        IBalancerVault(balancerVault).joinPool(
            poolId,
            address(this), // sender
            address(this), // recipient
            IBalancerVault.JoinPoolRequest(
                tokens,
                amounts,
                abi.encode(
                    IBalancerVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
                    amountsWithoutBPT, //_noBptAmounts,
                    minBPT // minimumBPT
                ),
                false
            )
        );
        bytes32 positionId = registry.calculatePositionId(address(this), BALANCER_LP_POSITION, abi.encode(poolId));
        registry.updateHoldingPosition(vaultId, positionId, "", "", false);

        if (auraAmount > 0) {
            (PoolInfo memory _poolInfo,) = _getPoolInfo(poolId);

            uint256 amount = IERC20(pool).balanceOf(address(this));
            _approveOperations(pool, _poolInfo.auraPoolAddress, amount);
            IRewardPool(_poolInfo.auraPoolAddress).deposit(auraAmount, address(this));
        }
        // Issue #1404:
        // _updateTokenInRegistry(pool);

        emit OpenPosition(poolId, amounts, amountsWithoutBPT, minBPT, auraAmount);
    }

    function depositIntoAuraBooster(bytes32 poolId, uint256 _amount) public onlyManager nonReentrant whenNotPaused {
        (PoolInfo memory _poolInfo,) = _getPoolInfo(poolId);
        _approveOperations(_poolInfo.pool, _poolInfo.auraPoolAddress, _amount);
        IRewardPool(_poolInfo.auraPoolAddress).deposit(_amount, address(this));
    }

    function decreasePosition(DecreasePositionParams memory p) public onlyManager nonReentrant whenNotPaused {
        if (p._auraAmount > 0) {
            (PoolInfo memory _poolInfo, bytes32 positionId) = _getPoolInfo(p.poolId);

            IRewardPool(_poolInfo.auraPoolAddress).withdrawAndUnwrap(p._auraAmount, true);
        }

        if (p._lpAmount > 0) {
            address[] memory tokens;
            {
                (tokens,,) = IBalancerVault(balancerVault).getPoolTokens(p.poolId);
            }
            uint256[] memory _amounts = new uint256[](tokens.length);
            _amounts[p.outerIndex] = p.minAmount;

            IBalancerVault(balancerVault).exitPool(
                p.poolId,
                address(this), // sender
                payable(address(this)), // recipient
                IBalancerVault.ExitPoolRequest(
                    tokens,
                    _amounts,
                    abi.encode(
                        IBalancerVault.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
                        p._lpAmount,
                        p.withdrawIndex // enterTokenIndex
                    ),
                    false
                )
            );

            if (totalLpBalanceOf(p.poolId) == 0) {
                registry.updateHoldingPosition(
                    vaultId,
                    registry.calculatePositionId(address(this), BALANCER_LP_POSITION, abi.encode(p.poolId)),
                    "",
                    "",
                    true
                );
            }
            _updateTokenInRegistry(tokens[p.outerIndex]);
        }
        _updateTokenInRegistry(AURA);
        _updateTokenInRegistry(BAL);
        emit DecreasePosition(p);
    }

    function _getPositionTVL(HoldingPI memory p, address base) public view override returns (uint256) {
        PositionBP memory PTI = registry.getPositionBP(vaultId, p.positionId);
        PoolInfo memory pool = abi.decode(PTI.additionalData, (PoolInfo));
        uint256 lpBalance = totalLpBalanceOf(pool);

        (address poolAddress,) = IBalancerVault(balancerVault).getPool(pool.poolId);
        return _getValue(
            pool.poolBaseToken, base, lpBalance * IBalancerPool(poolAddress).getRate() / pool.poolBaseTokenDecimalsDiff
        );
    }

    function totalLpBalanceOf(PoolInfo memory pool) public view returns (uint256) {
        uint256 auraShares;
        if (pool.auraPoolAddress != address(0)) {
            auraShares = IERC20(pool.auraPoolAddress).balanceOf(address(this));
            auraShares = IRewardPool(pool.auraPoolAddress).convertToAssets(auraShares);
        }
        return IERC20(pool.pool).balanceOf(address(this)) + auraShares;
    }

    function totalLpBalanceOf(bytes32 poolId) public view returns (uint256) {
        (PoolInfo memory pool,) = _getPoolInfo(poolId);
        return totalLpBalanceOf(pool);
    }

    function _getPoolInfo(bytes32 poolId) internal view returns (PoolInfo memory, bytes32) {
        bytes32 positionId = registry.calculatePositionId(address(this), BALANCER_LP_POSITION, abi.encode(poolId));
        PositionBP memory p = registry.getPositionBP(vaultId, positionId);
        return (abi.decode(p.additionalData, (PoolInfo)), positionId);
    }
}
