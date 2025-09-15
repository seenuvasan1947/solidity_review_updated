// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "./CurveConnector.sol";

contract CurveConnectorArbitrum is CurveConnectorMainnet {
    event WithdrawFromConvexBoosterWithPoolAddress(address pool, uint256 amount);

    constructor(
        address _convexBooster,
        address cvx,
        address crv,
        address prisma,
        BaseConnectorCP memory baseConnectorParams
    ) CurveConnectorMainnet(_convexBooster, cvx, crv, prisma, baseConnectorParams) {}

    /**
     * @notice Deposit tokens into Convex gauge
     * @param pool - Curve pool address
     * @param pid - convex pid
     * @param amount - amount of tokens to deposit
     * @param stake - stake or not
     */
    function depositIntoConvexBooster(address pool, uint256 pid, uint256 amount, bool stake)
    public
    override
    onlyManager
    whenNotPaused
    {
        PoolInfo memory poolInfo = _getPoolInfo(pool);

        _approveOperations(poolInfo.lpToken, address(convexBooster), amount);
        convexBooster.deposit(pid, amount);
    }

    /**
     * @notice Withdraw tokens from Convex gauge
     * @param rewardsPools - convex reward pool address
     * @param amount - amount of tokens to withdraw
     */
    function withdrawFromConvexBooster(address rewardsPools, uint256 amount) public onlyManager  whenNotPaused{
        IConvexBasicRewards(rewardsPools).withdraw(amount, true);
        emit WithdrawFromConvexBoosterWithPoolAddress(rewardsPools, amount);
    }

    /**
     * @notice Harvest rewards from Convex reward pool
     * @param rewardsPools - array of Convex reward pool addresses
     */
    function harvestConvexRewards(address[] calldata rewardsPools) public override onlyManager nonReentrant  whenNotPaused{
        for (uint256 i = 0; i < rewardsPools.length; i++) {
            IConvexBasicRewards baseRewardPool = IConvexBasicRewards(rewardsPools[i]);
            baseRewardPool.getReward(address(this));
            uint256 rewardLength = baseRewardPool.rewardLength();
            for (uint256 y = 0; y < rewardLength; y++) {
                (address rewardsToken,,) = baseRewardPool.rewards(y);
                _updateTokenInRegistry(rewardsToken);
            }
        }
        _updateTokenInRegistry(CVX);
        _updateTokenInRegistry(CRV);
        emit HarvestConvexRewards(rewardsPools);
    }

    function harvestPrismaRewards(address[] calldata pools) public override onlyManager nonReentrant {
        revert();
    }

    function withdrawFromPrisma(address prismaPool, uint256 amount) public override onlyManager {
        revert();
    }
}
