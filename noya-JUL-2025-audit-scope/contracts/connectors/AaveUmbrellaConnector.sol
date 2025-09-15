// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "../helpers/BaseConnector.sol";
import {IRewardsDistributor} from "../external/interfaces/Aave/IRewardDistributor.sol";
import {IERC4626StakeToken} from "../external/interfaces/Aave/StakeToken.sol";
import {IERC4626} from "@openzeppelin/contracts-5.0/interfaces/IERC4626.sol";

/*
 * @title AaveUmbrellaConnector
 * @notice Connector for Aave Umbrella safety protocol
 */
contract AaveUmbrellaConnector is BaseConnector {
    using SafeERC20 for IERC20;

    event Supply(address supplyToken, address vault, uint256 amount);
    event Withdraw(address withdrawToken, address vault, uint256 amount);
    // ------------ state variables -------------- //
    /**
     * @notice Aave Umbrella reward controller address
     */
    address public immutable rewardController;

    uint256 public constant ERC4626PositionID = 1;

    // ------------ Constructor -------------- //
    constructor(
        address _rewardController,
        BaseConnectorCP memory baseConnectorParams
    ) BaseConnector(baseConnectorParams) {
        require(
            _rewardController != address(0),
            "Reward controller cannot be zero address"
        );
        rewardController = _rewardController;
        connectorType = "AAVE_UMBRELLA";
    }

    // ------------ Connector functions -------------- //

    /**
     * @notice Supply tokens to the vault
     */
    function supply(
        address vault,
        uint256 amount,
        address asset
    ) external onlyManager nonReentrant whenNotPaused {
        require(vault != address(0), "Vault address cannot be zero");

        // address asset = abi.decode(positionBP.additionalData, (address));
        address asset2 = IERC4626(vault).asset();
        _approveOperations(asset, asset2, amount);
        uint256 shares = IERC4626(asset2).deposit(amount, address(this));
        _approveOperations(asset2, vault, shares);
        IERC4626(vault).deposit(shares, address(this));
        registry.updateHoldingPosition(
            vaultId,
            registry.calculatePositionId(
                address(this),
                ERC4626PositionID,
                abi.encode(vault)
            ),
            "",
            "",
            false
        );
        _updateTokenInRegistry(asset);
        emit Supply(asset, vault, amount);
    }

    /**
     * @notice Withdraw collateral from the vault
     * @notice This function is used when we want to withdraw some of the collateral
     * @param vault - vault to withdraw
     * @param shareAmount - amount to withdraw
     */
    function withdraw(
        address vault,
        uint256 shareAmount
    ) external onlyManager nonReentrant  whenNotPaused{
        require(vault != address(0), "Vault address cannot be zero");

        uint256 asset2Amount = IERC4626(vault).redeem(
            shareAmount,
            address(this),
            address(this)
        );
        uint256 shareBalance = IERC4626(vault).balanceOf(address(this));
        if (shareBalance == 0) {
            registry.updateHoldingPosition(
                vaultId,
                registry.calculatePositionId(
                    address(this),
                    ERC4626PositionID,
                    abi.encode(vault)
                ),
                "",
                "",
                true
            );
        }
        address asset2 = IERC4626(vault).asset();
        IERC4626(asset2).redeem(asset2Amount, address(this), address(this));

        address asset = IERC4626(asset2).asset();
        _updateTokenInRegistry(asset);
        emit Withdraw(asset, vault, shareAmount);
    }

    function _getPositionTVL(
        HoldingPI memory p,
        address base
    ) public view override returns (uint256 tvl) {
        PositionBP memory positionBP = registry.getPositionBP(
            vaultId,
            p.positionId
        );
        address vaultAddress = abi.decode(positionBP.data, (address));
        uint256 balance = IERC4626(vaultAddress).convertToAssets(
            IERC4626(vaultAddress).balanceOf(address(this))
        );
        address asset2 = IERC4626(vaultAddress).asset();
        address asset = IERC4626(asset2).asset();
        uint256 balance2 = IERC4626(asset2).convertToAssets(balance);
        tvl = _getValue(asset, base, balance2);
    }

    function claimRewards(address asset) external onlyManager {
        // claimAllRewards (0x7e9dc742)
        (
            address[] memory rewards,
            uint256[] memory amounts
        ) = IRewardsDistributor(rewardController).claimAllRewards(
                asset,
                address(this)
            );
        for (uint256 i = 0; i < rewards.length; i++) {
            if (amounts[i] > 0) {
                _updateTokenInRegistry(rewards[i]);
            }
        }
    }

    function cooldown(address stakeToken) external onlyManager {
        require(stakeToken != address(0), "Stake token address cannot be zero");
        IERC4626StakeToken(stakeToken).cooldown();
    }

    function _getUnderlyingTokens(
        uint256,
        bytes memory positionData
    ) public view override returns (address[] memory) {
        address[] memory tokens = new address[](1);
        address vaultAddress = abi.decode(positionData, (address));
        address vault2 = IERC4626(vaultAddress).asset();
        tokens[0] = IERC4626(vault2).asset();
        return tokens;
    }
}
