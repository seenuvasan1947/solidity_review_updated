// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "./utils/testStarter.sol";
import "./utils/resources/MainnetAddresses.sol";

import "contracts/connectors/BalancerConnector.sol";

contract TestBalancerConnector is testStarter, MainnetAddresses {
    BalancerConnector connector;
    uint256 newStartingBlock = 21_035_750;

    function setUp() public {
        console.log("----------- Initialization -----------");
        // --------------------------------- set env ---------------------------------
        uint256 fork = vm.createFork(RPC_URL, newStartingBlock);
        vm.selectFork(fork);

        // --------------------------------- deploy the contracts ---------------------------------
        vm.startPrank(owner);
        deployEverythingNormal(USDC);

        connector =
            new BalancerConnector(balancerVault, BAL, AURA, BaseConnectorCP(registry, vaultId, swapHandler, noyaOracle));
        console.log("BalancerConnector deployed: %s", address(connector));

        addConnectorToRegistry(vaultId, address(connector));
        // --------------------------------- set trusted tokens ---------------------------------

        addTrustedTokens(vaultId, address(accountingManager), USDC);
        addTrustedTokens(vaultId, address(accountingManager), DAI);
        addTrustedTokens(vaultId, address(accountingManager), USDT);
        addTrustedTokens(vaultId, address(accountingManager), WETH);
        addTrustedTokens(vaultId, address(accountingManager), WSTETH);

        // --------------------------------- init NoyaValueOracle ---------------------------------

        addTokenToChainlinkOracle(address(USDC), address(840), address(USDC_USD_FEED));
        addTokenToNoyaOracle(address(USDC), address(chainlinkOracle));

        addTokenToChainlinkOracle(address(DAI), address(840), address(DAI_USD_FEED));
        addTokenToNoyaOracle(address(DAI), address(chainlinkOracle));

        addTokenToChainlinkOracle(address(USDT), address(840), address(USDT_USD_FEED));
        addTokenToNoyaOracle(address(USDT), address(chainlinkOracle));

        addTokenToChainlinkOracle(address(CRVUSD), address(840), address(CRVUSD_USD_FEED));
        addTokenToNoyaOracle(address(CRVUSD), address(chainlinkOracle));

        addTokenToChainlinkOracle(address(WSTETH), address(840), address(WSTETH_USD_FEED));
        addTokenToNoyaOracle(address(WSTETH), address(chainlinkOracle));

        addTokenToChainlinkOracle(address(WETH), address(840), address(WETH_USD_FEED));
        addTokenToNoyaOracle(address(WETH), address(chainlinkOracle));

        addTokenToChainlinkOracle(address(aave), address(WETH), address(AAVE_ETH_FEED));
        addTokenToNoyaOracle(address(aave), address(chainlinkOracle));

        address[] memory route = new address[](1);
        route[0] = address(840);
        noyaOracle.updatePriceRoute(WETH, USDC, route);
        noyaOracle.updatePriceRoute(WSTETH, USDC, route);
        noyaOracle.updatePriceRoute(WSTETH, WETH, route);

        // --------------------------------- init ChainlinkchainlinkOracle ---------------------------------
        registry.addTrustedPosition(0, 0, address(accountingManager), false, false, abi.encode(USDC), "");
        registry.addTrustedPosition(0, 0, address(accountingManager), false, false, abi.encode(DAI), "");
        registry.addTrustedPosition(0, 0, address(accountingManager), false, false, abi.encode(USDT), "");
        registry.addTrustedPosition(0, 0, address(accountingManager), false, false, abi.encode(WETH), "");
        registry.addTrustedPosition(0, 0, address(accountingManager), false, false, abi.encode(WSTETH), "");
        address[] memory tokens = new address[](3);
        tokens[0] = address(DAI);
        tokens[1] = address(USDC);
        tokens[2] = address(USDT);
        registry.addTrustedPosition(
            0,
            connector.BALANCER_LP_POSITION(),
            address(connector),
            false,
            false,
            abi.encode(vanillaUsdcDaiUsdtId),
            abi.encode(
                PoolInfo({
                    pool: vanillaUsdcDaiUsdt,
                    tokens: tokens,
                    tokenIndex: 2,
                    poolId: vanillaUsdcDaiUsdtId,
                    auraPoolAddress: address(0),
                    boosterPoolId: 0,
                    poolBaseTokenDecimalsDiff: 1e28,
                    poolBaseToken: address(840)
                })
            )
        );
        vm.stopPrank();
    }

    function testTVLBalancer(uint256 _amount) public {
        vm.assume(_amount > 1 * 1e6 && _amount < 10_000 * 1e6);
        console.log("-----------testTVL--------------");
        // uint256 _amount = 10_000 * 1e6;
        _dealWhale(baseToken, address(connector), USDC_Whale, 3 * _amount);

        uint256 _tvl1 = accountingManager.totalAssets();
        assertEq(_tvl1, 0, "E0");
        console.log("TVL before position open: %s", _tvl1);
        console.log("depositing amount: %s", _amount);
        vm.startPrank(address(owner));

        uint256[] memory amounts = new uint256[](4);
        amounts[2] = _amount;
        uint256[] memory amountsW = new uint256[](3);
        amountsW[1] = _amount;

        connector.openPosition(vanillaUsdcDaiUsdtId, amounts, amountsW, 0, 0);

        uint256 balance = connector.totalLpBalanceOf(vanillaUsdcDaiUsdtId);
        console.log("totalLpBalanceOf() result: %s", balance);

        uint256 bptBalance = IERC20(vanillaUsdcDaiUsdt).balanceOf(address(connector));
        console.log("bptBalance: %s", bptBalance);

        assertEq(balance, bptBalance, "E1");

        uint256 tvl = accountingManager.totalAssets();
        console.log("TVL after position open: %s", tvl);

        assertApproxEqAbs(_amount, tvl, 10e6);

        connector.decreasePosition(DecreasePositionParams(vanillaUsdcDaiUsdtId, bptBalance, 1, 0, 0, 0));

        uint256 tvl2 = accountingManager.totalAssets();
        console.log("TVL after position decrease: %s", tvl2);
        assertEq(tvl2, 0, "E0");

        vm.stopPrank();
    }
}
