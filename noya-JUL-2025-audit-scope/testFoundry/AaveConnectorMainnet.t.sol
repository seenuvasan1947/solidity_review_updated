// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts-5.0/utils/Strings.sol";
import "@openzeppelin/contracts-5.0/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-5.0/token/ERC20/IERC20.sol";

import { AaveConnector, BaseConnectorCP } from "contracts/connectors/AaveConnector.sol";
import { IPool } from "contracts/external/interfaces/Aave/IPool.sol";
import { IRewardsController } from "contracts/external/interfaces/Aave/IRewardsController.sol";
import { IAToken } from "contracts/external/interfaces/Aave/IAToken.sol";
import "./utils/testStarter.sol";
import "./utils/resources/MainnetAddresses.sol";

contract TestAaveConnectorMainnet is testStarter, MainnetAddresses {
    // using SafeERC20 for IERC20;

    AaveConnector connector;

    function setUp() public {
        console.log("----------- Initialization -----------");
        // --------------------------------- set env --------------------------------
        uint256 fork = vm.createFork(RPC_URL, startingBlock);
        vm.selectFork(fork);

        console.log("Test timestamp: %s", block.timestamp);

        // --------------------------------- deploy the contracts ---------------------------------
        vm.startPrank(owner);

        deployEverythingNormal(USDC);

        // --------------------------------- init connector ---------------------------------
        connector = new AaveConnector(aavePool, address(840), BaseConnectorCP(registry, 0, swapHandler, noyaOracle));

        console.log("AaveConnector deployed: %s", address(connector));
        // ------------------- add connector to registry -------------------
        addConnectorToRegistry(vaultId, address(connector));
        // ------------------- addTokensToSupplyOrBorrow -------------------
        addTrustedTokens(vaultId, address(accountingManager), USDC);
        addTrustedTokens(vaultId, address(accountingManager), DAI);

        addTokenToChainlinkOracle(address(USDC), address(840), address(USDC_USD_FEED));
        addTokenToNoyaOracle(address(USDC), address(chainlinkOracle));

        addTokenToChainlinkOracle(address(DAI), address(840), address(DAI_USD_FEED));
        addTokenToNoyaOracle(address(DAI), address(chainlinkOracle));

        addRoutesToNoyaOracle(address(DAI), address(USDC), address(840));

        console.log("Tokens added to registry");
        registry.addTrustedPosition(vaultId, connector.AAVE_POSITION_ID(), address(connector), true, false, "", "");
        registry.addTrustedPosition(vaultId, 0, address(accountingManager), false, false, abi.encode(USDC), "");
        registry.addTrustedPosition(vaultId, 0, address(accountingManager), false, false, abi.encode(DAI), "");
        console.log("Positions added to registry");
        vm.stopPrank();
    }

    function testIsolationMode() public {
        console.log("----------- Isolation Mode Test --------------");
        // Token dashboard: https://www.config.fyi/
        address isolatedToken = CRV;
        uint256 _amount = 1000 * 1e18;
        uint256 _borrowAmount = 10 * 1e18;

        _dealERC20(isolatedToken, address(connector), _amount);

        vm.startPrank(address(owner));

        connector.supply(isolatedToken, _amount);

        uint256 _tvl = accountingManager.totalAssets();
        assertTrue(_tvl == 0, "testIsolationMode: E0");

        vm.expectRevert(); // revert with "COLLATERAL_BALANCE_IS_ZERO = '34';"
        connector.borrow(_borrowAmount, 2, DAI);

        connector.adjustIsolationModeAssetAsCollateral(CRV, true);

        _tvl = accountingManager.totalAssets();
        assertTrue(_tvl > 0, "testIsolationMode: E1");

        connector.borrow(_borrowAmount, 2, DAI);

        addTrustedTokens(vaultId, address(accountingManager), WETH);
        vm.expectRevert(); // revert with "ASSET_NOT_BORROWABLE_IN_ISOLATION = '60';"
        connector.borrow(1 * 1e18, 2, WETH);

        vm.expectRevert(); // revert with "HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD = '35';"
        connector.adjustIsolationModeAssetAsCollateral(CRV, false);

        connector.repay(DAI, _borrowAmount, 2);

        connector.adjustIsolationModeAssetAsCollateral(CRV, false);

        vm.stopPrank();
    }
}
