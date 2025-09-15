// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "./utils/testStarter.sol";
import "contracts/connectors/CurveConnectorArbitrum.sol";
import "contracts/external/interfaces/Curve/ICurveSwap.sol";

import "./utils/resources/ArbitrumAddresses.sol";

contract TestCurveArbitrumConnector is testStarter, ArbitrumAddresses {
    CurveConnectorArbitrum connector;

    function setUp() public {
        console.log("----------- Initialization -----------");
        uint256 fork = vm.createFork(RPC_URL, startingBlock);
        vm.selectFork(fork);

        // --------------------------------- deploy the contracts ---------------------------------
        vm.startPrank(owner);
        deployEverythingNormal(USDC);

        connector = new CurveConnectorArbitrum(
            convexArbitrumBooster, CVX, CRV, address(840), BaseConnectorCP(registry, vaultId, swapHandler, noyaOracle)
        );
        console.log("CurveConnector deployed: %s", address(connector));

        addConnectorToRegistry(vaultId, address(connector));

        addTrustedTokens(vaultId, address(accountingManager), USDC);
        addTrustedTokens(vaultId, address(accountingManager), FRAX);

        addTokenToChainlinkOracle(address(USDC), address(840), address(USDC_USD_FEED));
        addTokenToNoyaOracle(address(USDC), address(chainlinkOracle));

        addTokenToChainlinkOracle(address(FRAX), address(840), address(FRAX_USD_FEED));
        addTokenToNoyaOracle(address(FRAX), address(chainlinkOracle));

        addRoutesToNoyaOracle(address(FRAX), address(USDC), address(840));
        addRoutesToNoyaOracle(address(USDC), address(USDC), address(840));

        registry.addTrustedPosition(0, 0, address(accountingManager), false, false, abi.encode(USDC), "");
        registry.addTrustedPosition(0, 0, address(accountingManager), false, false, abi.encode(FRAX), "");


        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);
        tokens[1] = address(USDC);

        PoolInfo memory pool = PoolInfo(
            curveFraxUsdcPool,
            2,
            fraxUsdcLpToken,
            curveFraxUsdcGauge,
            fraxUsdcLpToken, //convex LP
            fraxUsdcConvexRewardBooster,
            address(0),
            address(0),
            tokens,
            address(0),
            1,
            address(0)
        );
        registry.addTrustedPosition(
            0,
            connector.CURVE_LP_POSITION(),
            address(connector),
            false,
            false,
            abi.encode(curveFraxUsdcPool),
            abi.encode(pool)
        );

        console.log("CurveConnector deployed: %s", address(connector));
    }

    function test_CurveConvex() public {
        uint256 _amount = 100_000_000;

        _dealWhale(baseToken, address(connector), address(0x1AB4973a48dc892Cd9971ECE8e01DcC7688f8F23), _amount);
        _dealERC20(FRAX, address(connector), _amount);

        vm.startPrank(address(owner));

        connector.openCurvePosition(curveFraxUsdcPool, 0, _amount, 0);
        uint256 lpBalance = IERC20(curveFraxUsdcPool).balanceOf(address(connector));

        connector.depositIntoConvexBooster(curveFraxUsdcPool, 10, lpBalance / 2, false);
        connector.depositIntoConvexBooster(curveFraxUsdcPool, 10, lpBalance / 2, true);
        address[] memory tokens = new address[](1);
        tokens[0] = fraxUsdcConvexRewardBooster;

        connector.harvestConvexRewards(tokens);
        uint256 convexBalance = IERC20(fraxUsdcConvexRewardBooster).balanceOf(address(connector));
        console.log("Convex balance: %s", convexBalance);
        connector.withdrawFromConvexBooster(fraxUsdcConvexRewardBooster, convexBalance);

        vm.stopPrank();
    }
}
