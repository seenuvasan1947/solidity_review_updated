// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "./utils/testStarter.sol";
import "contracts/helpers/BaseConnector.sol";
import "contracts/accountingManager/NoyaFeeReceiver.sol";
// import "./utils/resources/OptimismAddresses.sol";
import "./utils/resources/BaseAddresses.sol";
import "contracts/governance/Keepers.sol";
import "./utils/mocks/EmergancyMock.sol";
import "./utils/mocks/ConnectorMock2.sol";

contract TestAccounting is testStarter, BaseAddresses {
    using SafeERC20 for IERC20;

    address connector;
    address connector2;
    NoyaFeeReceiver managementFeeReceiver;
    NoyaFeeReceiver performanceFeeReceiver;
    address withdrawFeeReceiver = bob;
    address userBlackList = 0xc685132E908cCe284c063415ea353aF5F555C6C6;
    WithdrawErrorHandler withdrawErrorsHandler;

    function setUp() public {
        // --------------------------------- set env --------------------------------
        uint256 fork = vm.createFork(RPC_URL, 32816063);
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

        accountingManager.updateValueOracle(noyaOracle);

        withdrawErrorsHandler = new WithdrawErrorHandler();
        withdrawErrorsHandler.grantRole(withdrawErrorsHandler.ACCOUNTING_ROLE(), address(accountingManager));
        accountingManager.updateWithdrawErrorsHandler(address(withdrawErrorsHandler));

        vm.stopPrank();
    }

    function testBlackAttack() public {
        console.log("-----------Base Workflow--------------");
        uint256 _amount = 1e8;

        _dealWhale(baseToken, address(alice), address(0x0B0A5886664376F59C351ba3f598C8A8B4D0A6f3),  2 * _amount);


        vm.startPrank(alice);

        // ------------------------------ deposit ------------------------------
        vm.expectRevert();
        IERC20(USDC).transfer( address(userBlackList), _amount);
        SafeERC20.forceApprove(IERC20(USDC), address(accountingManager), _amount);
        accountingManager.deposit(address(alice), _amount, address(0));

        vm.stopPrank();
        vm.startPrank(owner);
        accountingManager.calculateDepositShares(1);
        vm.warp(block.timestamp + 35 minutes);
        accountingManager.executeDeposit(10, connector, "");

        vm.stopPrank();
        vm.startPrank(alice);

        // ------------------------------ withdraw ------------------------------
        accountingManager.withdraw( _amount/2, address(alice));
        accountingManager.withdraw( _amount/2, address(userBlackList));
        vm.stopPrank();

        vm.startPrank(owner);
        accountingManager.calculateWithdrawShares(2);
        accountingManager.startCurrentWithdrawGroup();
        RetrieveData[] memory retrieveData = new RetrieveData[](1);
        retrieveData[0] = RetrieveData({
            withdrawAmount: _amount,
            connectorAddress: address(connector),
            data: abi.encode(_amount, "")
        });
        accountingManager.retrieveTokensForWithdraw(
            retrieveData,
            connector,
            ""
        );
        accountingManager.fulfillCurrentWithdrawGroup();
        vm.warp(block.timestamp + 7 hours);
        accountingManager.executeWithdraw(10);
        vm.stopPrank();


        (
            uint256 lastId,
            uint256 totalCalculatedBaseTokenAmount,
            ,
            uint256 totalAvailableBaseTokenAmount,
            bool isStarted,
            bool isFullfilled
        ) = accountingManager.currentWithdrawGroup();
        console.log("Last ID: %s", lastId);
        console.log("Total Calculated Base Token Amount: %s", totalCalculatedBaseTokenAmount / 1e6);
        console.log("Total Available Base Token Amount: %s", totalAvailableBaseTokenAmount / 1e6);
        console.log("Is Started: %s", isStarted);
        console.log("Is Fullfilled: %s", isFullfilled);


        vm.startPrank(alice);

        // ------------------------------ deposit ------------------------------
        SafeERC20.forceApprove(IERC20(USDC), address(accountingManager), _amount);
        accountingManager.deposit(address(alice), _amount, address(0));
        vm.stopPrank();
        vm.startPrank(owner);
        accountingManager.calculateDepositShares(1);
        vm.warp(block.timestamp + 35 minutes);
        accountingManager.executeDeposit(10, connector, "");
        vm.stopPrank();
        vm.startPrank(alice);
        accountingManager.withdraw( _amount, address(alice));
        vm.stopPrank();
        vm.startPrank(owner);
        accountingManager.calculateWithdrawShares(1);
        accountingManager.startCurrentWithdrawGroup();
        retrieveData = new RetrieveData[](1);
        retrieveData[0] = RetrieveData({
            withdrawAmount: _amount,
            connectorAddress: address(connector),
            data: abi.encode(_amount, "")
        });
        accountingManager.retrieveTokensForWithdraw(
            retrieveData,
            connector,
            ""
        );
        accountingManager.fulfillCurrentWithdrawGroup();
        vm.warp(block.timestamp + 7 hours);
        accountingManager.executeWithdraw(10);
        vm.stopPrank();
    }
}
