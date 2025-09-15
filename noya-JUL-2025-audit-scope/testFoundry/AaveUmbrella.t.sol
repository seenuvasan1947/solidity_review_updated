// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts-5.0/utils/Strings.sol";
import "@openzeppelin/contracts-5.0/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-5.0/token/ERC20/IERC20.sol";

import {AaveUmbrellaConnector, BaseConnectorCP} from "contracts/connectors/AaveUmbrellaConnector.sol";
import "./utils/testStarter.sol";
import "./utils/resources/MainnetAddresses.sol";

contract TestAaveConnectorMainnet is testStarter, MainnetAddresses {
    // using SafeERC20 for IERC20;

    AaveUmbrellaConnector connector;

    function setUp() public {
        console.log("----------- Initialization -----------");
        // --------------------------------- set env --------------------------------
        uint256 fork = vm.createFork(RPC_URL, 22744978);
        vm.selectFork(fork);

        console.log("Test timestamp: %s", block.timestamp);

        // --------------------------------- deploy the contracts ---------------------------------
        vm.startPrank(owner);

        deployEverythingNormal(USDC);

        // --------------------------------- init connector ---------------------------------
        connector = new AaveUmbrellaConnector(
            address(0xD400fc38ED4732893174325693a63C30ee3881a8),
            BaseConnectorCP(registry, 0, swapHandler, noyaOracle)
        );

        // ------------------- add connector to registry -------------------
        addConnectorToRegistry(vaultId, address(connector));
        // ------------------- addTokensToSupplyOrBorrow -------------------
        addTrustedTokens(vaultId, address(accountingManager), USDC);

        addTokenToChainlinkOracle(
            address(USDC),
            address(840),
            address(USDC_USD_FEED)
        );
        addTokenToNoyaOracle(address(USDC), address(chainlinkOracle));

        console.log("Tokens added to registry");
        registry.addTrustedPosition(
            vaultId,
            connector.ERC4626PositionID(),
            address(connector),
            true,
            false,
            abi.encode(0x6bf183243FdD1e306ad2C4450BC7dcf6f0bf8Aa6),
            abi.encode(USDC)
        );
        registry.addTrustedPosition(
            vaultId,
            0,
            address(accountingManager),
            false,
            false,
            abi.encode(USDC),
            ""
        );
        console.log("Positions added to registry");
        vm.stopPrank();
    }

    function testUmbrellaDeposit() public {
        console.log("----------- Umbrella Deposit Test --------------");

        uint256 _amount = 200_000_000;
        _dealWhale(baseToken, address(connector), USDC_Whale, _amount);

        vm.startPrank(address(owner));
        connector.supply(
            0x6bf183243FdD1e306ad2C4450BC7dcf6f0bf8Aa6,
            _amount,
            USDC
        );

        uint256 _tvl = accountingManager.totalAssets();
        assertTrue(isCloseTo(_tvl, _amount, 100));

        uint256 balance = IERC20(0x6bf183243FdD1e306ad2C4450BC7dcf6f0bf8Aa6)
            .balanceOf(address(connector));

        vm.expectRevert();
        connector.withdraw(0x6bf183243FdD1e306ad2C4450BC7dcf6f0bf8Aa6, balance);

        connector.cooldown(0x6bf183243FdD1e306ad2C4450BC7dcf6f0bf8Aa6);

        vm.warp(block.timestamp + 20 days + 1000 seconds);

        connector.withdraw(0x6bf183243FdD1e306ad2C4450BC7dcf6f0bf8Aa6, balance);

        uint256 _tvl2 = accountingManager.totalAssets();
        assertTrue(isCloseTo(_tvl2, _amount, 100));
    }
}
