// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "./utils/testStarter.sol";
import "./utils/resources/MainnetAddresses.sol";

import {PendleConnector, IPStandardizedYield, IPPrincipalToken, IPYieldToken, LimitOrderData, ApproxParams, FillOrderParams, HoldingPI, IPMarket, BaseConnectorCP} from "contracts/connectors/PendleConnector.sol";

interface IUSDT {
    function approve(address _spender, uint256 _value) external;
}

contract TestPendleConnector is testStarter, MainnetAddresses {
    PendleConnector connector;
    uint256 public startingBlock1 = 19_312_332;

    function setUp() public {
        console.log("----------- Initialization -----------");
        // --------------------------------- set env --------------------------------
        uint256 fork = vm.createFork(RPC_URL, startingBlock1);
        vm.selectFork(fork);

        console.log("Test timestamp: %s", block.timestamp);

        // --------------------------------- deploy the contracts ---------------------------------
        vm.startPrank(owner);

        deployEverythingNormal(USDC);

        // --------------------------------- init connector ---------------------------------
        connector = new PendleConnector(
            pendleRouter,
            pendleStaticRouter,
            BaseConnectorCP(registry, vaultId, swapHandler, noyaOracle)
        );

        console.log("PendleConnector deployed: %s", address(connector));
        addConnectorToRegistry(vaultId, address(connector));

        // ------------------- addTokensToSupplyOrBorrow -------------------
        addTrustedTokens(vaultId, address(accountingManager), USDC);
        addTrustedTokens(vaultId, address(accountingManager), DAI);
        addTrustedTokens(vaultId, address(accountingManager), GHO);
        addTrustedTokens(vaultId, address(accountingManager), USDT);
        addTrustedTokens(vaultId, address(accountingManager), STG);
        addTrustedTokens(vaultId, address(accountingManager), PENDLE);

        addTokenToChainlinkOracle(
            address(USDC),
            address(840),
            address(USDC_USD_FEED)
        );
        addTokenToNoyaOracle(address(USDC), address(chainlinkOracle));

        addTokenToChainlinkOracle(
            address(USDT),
            address(840),
            address(USDT_USD_FEED)
        );
        addTokenToNoyaOracle(address(USDT), address(chainlinkOracle));

        addTokenToChainlinkOracle(
            address(DAI),
            address(840),
            address(DAI_USD_FEED)
        );
        addTokenToNoyaOracle(address(DAI), address(chainlinkOracle));

        addTokenToChainlinkOracle(
            address(GHO),
            address(840),
            address(GHO_USD_FEED)
        );
        addTokenToNoyaOracle(address(GHO), address(chainlinkOracle));

        addTokenToChainlinkOracle(
            address(STG),
            address(840),
            address(STG_USD_FEED)
        );
        addTokenToNoyaOracle(address(STG), address(chainlinkOracle));

        addRoutesToNoyaOracle(address(STG), address(USDC), address(840));
        addRoutesToNoyaOracle(address(GHO), address(USDC), address(840));
        addRoutesToNoyaOracle(address(DAI), address(USDC), address(840));
        addRoutesToNoyaOracle(address(USDT), address(USDC), address(840));

        registry.addTrustedPosition(
            0,
            0,
            address(accountingManager),
            false,
            false,
            abi.encode(GHO),
            ""
        );
        registry.addTrustedPosition(
            0,
            0,
            address(accountingManager),
            false,
            false,
            abi.encode(USDC),
            ""
        );
        registry.addTrustedPosition(
            0,
            0,
            address(accountingManager),
            false,
            false,
            abi.encode(DAI),
            ""
        );
        registry.addTrustedPosition(
            0,
            0,
            address(accountingManager),
            false,
            false,
            abi.encode(USDT),
            ""
        );
        registry.addTrustedPosition(
            0,
            0,
            address(accountingManager),
            false,
            false,
            abi.encode(STG),
            ""
        );
        registry.addTrustedPosition(
            0,
            0,
            address(accountingManager),
            false,
            false,
            abi.encode(PENDLE),
            ""
        );
        registry.addTrustedPosition(
            0,
            12,
            address(connector),
            true,
            false,
            abi.encode(pendleUsdtMarket),
            ""
        );
        registry.addTrustedPosition(
            0,
            connector.PENDLE_POSITION_ID(),
            address(connector),
            true,
            false,
            abi.encode(pendleUsdtMarket),
            ""
        );
    }

    function testDeposit123() public {
        uint256 amount = 1000;

        _dealERC20(USDT, address(connector), amount);
        vm.startPrank(owner);

        uint256 tvl_before = connector.getPositionTVL( //  Covered coverage bug number 29.3
                HoldingPI({
                    calculatorConnector: address(connector),
                    positionId: registry.calculatePositionId(
                        address(connector),
                        connector.PENDLE_POSITION_ID(),
                        abi.encode(pendleUsdtMarket)
                    ),
                    ownerConnector: address(connector),
                    data: "",
                    additionalData: "",
                    positionTimestamp: 0
                }),
                address(USDC)
            );
        assertEq(tvl_before, 0);

        (
            IPStandardizedYield _SY,
            IPPrincipalToken _PT,
            IPYieldToken _YT
        ) = IPMarket(pendleUsdtMarket).readTokens();

        uint256 minAmount = (_SY.previewDeposit(USDT, amount) * 95) / 100;
        console.log("Slippage control minAmount:", minAmount);

        connector.supply(pendleUsdtMarket, amount, minAmount);
        uint256 syBalance = _SY.balanceOf(address(connector));
        console.log("syBalance: %s", syBalance);

        console.log("call to mintPTAndYT");
        connector.mintPTAndYT(pendleUsdtMarket, syBalance);

        uint256 PTBalance = _PT.balanceOf(address(connector));
        uint256 YTBalance = _YT.balanceOf(address(connector));

        console.log("PTBalance: %s", PTBalance);
        console.log("YTBalance: %s", YTBalance);

        assertTrue(isCloseTo(PTBalance, syBalance, 100));
        assertTrue(isCloseTo(YTBalance, syBalance, 100));

        uint256 tvl = accountingManager.totalAssets();
        assertTrue(isCloseTo(tvl, amount, 100));

        connector.getPositionTVL( //  Covered coverage bug number 29.2
                HoldingPI({
                    calculatorConnector: address(connector),
                    positionId: registry.calculatePositionId(
                        address(connector),
                        12,
                        abi.encode(pendleUsdtMarket)
                    ),
                    ownerConnector: address(connector),
                    data: "",
                    additionalData: "",
                    positionTimestamp: 0
                }),
                address(USDC)
            );

        vm.stopPrank();
    }

    function testDepositAndWithdraw() public {
        uint256 amount = 1000;

        _dealERC20(USDT, address(connector), amount);
        vm.startPrank(owner);

        (
            IPStandardizedYield _SY,
            IPPrincipalToken _PT,
            IPYieldToken _YT
        ) = IPMarket(pendleUsdtMarket).readTokens();

        connector.supply(pendleUsdtMarket, amount, 1);
        uint256 syBalance = _SY.balanceOf(address(connector));
        uint256 tvlBefore = accountingManager.TVL();

        console.log("tvl before decreasePosition:", tvlBefore);
        connector.decreasePosition(
            IPMarket(pendleUsdtMarket),
            syBalance / 4,
            1,
            true
        ); //  Covered coverage bug number 29
        uint256 tvlAfter = accountingManager.TVL();
        console.log("tvl after decreasePosition:", tvlAfter);
        assertTrue(isCloseTo(tvlBefore, tvlAfter, 100));

        connector.decreasePosition(
            IPMarket(pendleUsdtMarket),
            syBalance / 4,
            1,
            false
        );
        syBalance = _SY.balanceOf(address(connector));
        connector.decreasePosition(
            IPMarket(pendleUsdtMarket),
            syBalance,
            1,
            true
        );

        vm.stopPrank();
    }

    function testSwapYTToPT() public {
        uint256 amount = 1000;

        _dealERC20(USDT, address(connector), amount);
        vm.startPrank(owner);

        (
            IPStandardizedYield _SY,
            IPPrincipalToken _PT,
            IPYieldToken _YT
        ) = IPMarket(pendleUsdtMarket).readTokens();

        connector.supply(pendleUsdtMarket, amount, 1);
        uint256 syBalance = _SY.balanceOf(address(connector));

        connector.mintPTAndYT(pendleUsdtMarket, syBalance);

        uint256 PTBalance = _PT.balanceOf(address(connector));
        uint256 YTBalance = _YT.balanceOf(address(connector));

        connector.swapYTForPT(
            pendleUsdtMarket,
            YTBalance,
            0,
            ApproxParams({
                guessOffchain: 1000,
                guessMin: 0,
                guessMax: 0,
                maxIteration: 8,
                eps: 1e18
            })
        );

        uint256 PTBalanceAfter = _PT.balanceOf(address(connector));
        assertTrue(PTBalanceAfter > PTBalance);

        vm.stopPrank();
    }

    function testSwapYTToSY() public {
        uint256 amount = 1000;

        _dealERC20(USDT, address(connector), amount);
        vm.startPrank(owner);

        (
            IPStandardizedYield _SY,
            IPPrincipalToken _PT,
            IPYieldToken _YT
        ) = IPMarket(pendleUsdtMarket).readTokens();

        connector.supply(pendleUsdtMarket, amount, 1);
        uint256 syBalance = _SY.balanceOf(address(connector));

        connector.mintPTAndYT(pendleUsdtMarket, syBalance);

        uint256 PTBalance = _PT.balanceOf(address(connector));
        uint256 YTBalance = _YT.balanceOf(address(connector));
        syBalance = _SY.balanceOf(address(connector));
        connector.swapYTForSY(
            pendleUsdtMarket,
            YTBalance,
            0,
            LimitOrderData(
                address(pendleStaticRouter),
                0, // only used for swap operations, will be ignored otherwise
                new FillOrderParams[](0),
                new FillOrderParams[](0),
                ""
            )
        );

        uint256 syBalanceAfter = _SY.balanceOf(address(connector));
        assertTrue(syBalanceAfter > syBalance);

        vm.stopPrank();
    }

    function testDepositIntoMarket() public {
        uint256 amount = 10_000;

        _dealERC20(USDT, address(connector), amount);
        vm.startPrank(owner);

        (
            IPStandardizedYield _SY,
            IPPrincipalToken _PT,
            IPYieldToken _YT
        ) = IPMarket(pendleUsdtMarket).readTokens();

        connector.supply(pendleUsdtMarket, amount, 1);
        uint256 syBalance = _SY.balanceOf(address(connector));

        vm.roll(block.number + 20);
        vm.warp(block.timestamp + 1 hours);

        uint256 tvl = accountingManager.totalAssets();
        assertTrue(isCloseTo(tvl, amount, 100));
        connector.mintPTAndYT(pendleUsdtMarket, syBalance / 2);
        vm.roll(block.number + 20);
        vm.warp(block.timestamp + 1 hours);

        tvl = accountingManager.totalAssets();
        assertTrue(isCloseTo(tvl, amount, 100));

        syBalance = _SY.balanceOf(address(connector));

        uint256 PTBalance = _PT.balanceOf(address(connector));
        uint256 YTBalance = _YT.balanceOf(address(connector));
        console.log("--- Deposit Into Market: ---");
        console.log("syBalance: ", syBalance);
        console.log("PTBalance: ", PTBalance);
        console.log("TVL before deposit: ", accountingManager.TVL());

        vm.recordLogs();
        connector.depositIntoMarket(
            IPMarket(pendleUsdtMarket),
            syBalance,
            PTBalance,
            0
        );
        Vm.Log[] memory entries = vm.getRecordedLogs();
        (, uint256 netSyUsed, uint256 netPtUsed) = abi.decode(
            entries[13].data,
            (bytes32, uint256, uint256)
        );
        console.log("netSyUsed (fact): ", netSyUsed);
        console.log("netPtUsed (fact): ", netPtUsed);

        vm.roll(block.number + 20);
        vm.warp(block.timestamp + 1 hours);

        tvl = accountingManager.totalAssets();
        assertTrue(isCloseTo(tvl, amount, 5000));

        uint256 LPBalance = IERC20(pendleUsdtMarket).balanceOf(
            address(connector)
        );
        // connector.depositIntoPenpie(pendleUsdtMarket, LPBalance);

        // vm.roll(block.number + 20);
        // vm.warp(block.timestamp + 1 hours);

        // tvl = accountingManager.totalAssets();
        // assertTrue(isCloseTo(tvl, amount, 5000));

        // uint256 pnpBefore = IERC20(PNP).balanceOf(address(connector));
        // assertTrue(pnpBefore == 0, "E0");
        // connector.withdrawFromPenpie(pendleUsdtMarket, LPBalance);
        // uint256 pnpAfter = IERC20(PNP).balanceOf(address(connector));
        // assertTrue(pnpAfter > 0, "E1");
        // vm.roll(block.number + 20);
        // vm.warp(block.timestamp + 1 hours);

        tvl = accountingManager.totalAssets();
        assertTrue(isCloseTo(tvl, amount, 5000));

        assertTrue(_PT.balanceOf(address(connector)) == 0);
        connector.burnLP(IPMarket(pendleUsdtMarket), LPBalance, 0, 0);
        assertTrue(_PT.balanceOf(address(connector)) > 0);

        vm.roll(block.number + 20);
        vm.warp(block.timestamp + 1 hours);

        tvl = accountingManager.totalAssets();
        console.log("tvl2: %s", tvl);
        vm.stopPrank();
    }

    function testDepositIntoMarketAndClaimRewards() public {
        uint256 amount = 10_000;

        _dealERC20(USDT, address(connector), amount);
        vm.startPrank(owner);

        (
            IPStandardizedYield _SY,
            IPPrincipalToken _PT,
            IPYieldToken _YT
        ) = IPMarket(pendleUsdtMarket).readTokens();

        connector.supply(pendleUsdtMarket, amount, 1);
        uint256 syBalance = _SY.balanceOf(address(connector));

        connector.mintPTAndYT(pendleUsdtMarket, syBalance / 2);

        syBalance = _SY.balanceOf(address(connector));

        uint256 PTBalance = _PT.balanceOf(address(connector));
        uint256 YTBalance = _YT.balanceOf(address(connector));

        connector.depositIntoMarket(
            IPMarket(pendleUsdtMarket),
            syBalance,
            PTBalance,
            0
        );

        uint256 LPBalance = IERC20(pendleUsdtMarket).balanceOf(
            address(connector)
        );

        vm.stopPrank();
    }

    // function test_DoSAfterExpiry() public {
    //     chainlinkOracle.updateDefaultChainlinkPriceAgeThreshold(10 days - 1);
    //     uint256 amount = 100e6;
    //     _dealERC20(USDT, address(connector), amount);
    //     vm.startPrank(owner);
    //     connector.updateTokenInRegistry(address(USDT));
    //     connector.supply(pendleUsdtMarket, amount, 1);
    //     connector.mintPTAndYT(pendleUsdtMarket, 10e6);
    //     vm.warp(block.timestamp + IPMarket(pendleUsdtMarket).expiry());
    //     assertTrue(IPMarket(pendleUsdtMarket).isExpired());
    //     vm.expectRevert();
    //     accountingManager.TVL();
    // }

    function testSwapPtForSY() public {
        uint256 amount = 10_000;

        _dealERC20(USDT, address(connector), amount);
        vm.startPrank(owner);

        (
            IPStandardizedYield _SY,
            IPPrincipalToken _PT,
            IPYieldToken _YT
        ) = IPMarket(pendleUsdtMarket).readTokens();

        connector.supply(pendleUsdtMarket, amount, 1);
        uint256 syBalance = _SY.balanceOf(address(connector));

        connector.mintPTAndYT(pendleUsdtMarket, syBalance / 2);

        syBalance = _SY.balanceOf(address(connector));

        uint256 PTBalance = _PT.balanceOf(address(connector));
        uint256 YTBalance = _YT.balanceOf(address(connector));
        vm.expectRevert();
        connector.swapExactPTForSY(
            IPMarket(pendleUsdtMarket),
            PTBalance,
            "",
            1e10
        );

        connector.swapExactPTForSY(
            IPMarket(pendleUsdtMarket),
            PTBalance,
            "",
            0
        );

        assertTrue(_SY.balanceOf(address(connector)) > syBalance);

        assertEq(
            connector._getPositionTVL(
                HoldingPI({
                    calculatorConnector: address(connector),
                    ownerConnector: address(connector),
                    positionId: 0,
                    data: "",
                    additionalData: "",
                    positionTimestamp: 0
                }),
                USDC
            ),
            0
        );

        vm.stopPrank();
    }

    function testSlippageControl() public {
        // address attacker = makeAddr("sandwitchBot");
        uint256 amount = 1000;
        uint256 attackersDeposit = amount * 10_000_000;
        _dealERC20(USDT, address(connector), amount);
        // _dealERC20(USDT, attacker, attackersDeposit);

        (
            IPStandardizedYield _SY,
            IPPrincipalToken _PT,
            IPYieldToken _YT
        ) = IPMarket(pendleUsdtMarket).readTokens();

        // uint256 nonSandwichedAmount = _SY.previewDeposit(USDT, amount);
        // console.log("Expected amount (no frontrunning happening): %s", nonSandwichedAmount);

        // vm.startPrank(attacker);
        // IUSDT(USDT).approve(address(_SY), attackersDeposit);
        // (uint256 attackersShares) = _SY.deposit(attacker, USDT, attackersDeposit, 1);
        // vm.stopPrank();

        // vm.roll(block.number + 1);

        // uint256 sandwichedAmount = _SY.previewDeposit(USDT, amount);
        // console.log("Expected amount after atttacker depositted: %s", sandwichedAmount);

        // vm.startPrank(owner);
        // vm.expectRevert();
        connector.supply(pendleUsdtMarket, amount, 1);
        // uint256 syBalance = _SY.balanceOf(address(connector));
        // console.log("syBalance",syBalance);
        // console.log("TVL:",accountingManager.TVL());
        vm.stopPrank();
    }
}
