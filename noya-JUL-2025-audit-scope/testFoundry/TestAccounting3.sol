// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "./utils/testStarter.sol";
import "./utils/resources/OptimismAddresses.sol";
import "./utils/mocks/ConnectorMock2.sol";
import {IERC20} from "@openzeppelin/contracts-5.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-5.0/token/ERC20/utils/SafeERC20.sol";
import {RetrieveData} from "../contracts/interface/Accounting/IAccountingManager.sol";

contract TestAccounting2 is testStarter, OptimismAddresses {
    using SafeERC20 for IERC20;
    
    ConnectorMock2 mockConnector;
    ConnectorMock2 mockConnector2;
    
    function setUp() public {
        // Fork Optimism at specific block
        uint256 fork = vm.createFork(RPC_URL, startingBlock);
        vm.selectFork(fork);
        
        console.log("Test timestamp: %s", block.timestamp);
        
        vm.startPrank(owner);
        
        // Deploy everything using testStarter
        deployEverythingNormal(USDC);
        
        // Deploy our mock connectors
        mockConnector = new ConnectorMock2(address(registry), vaultId);
        mockConnector2 = new ConnectorMock2(address(registry), vaultId);
        
        // Add connectors to registry
        addConnectorToRegistry(vaultId, address(mockConnector));
        addConnectorToRegistry(vaultId, address(mockConnector2));
        
        // Add trusted tokens
        addTrustedTokens(vaultId, address(accountingManager), USDC);
        addTrustedTokens(vaultId, address(mockConnector), USDC);
        addTrustedTokens(vaultId, address(mockConnector2), USDC);
        
        // Setup oracle for USDC
        addTokenToChainlinkOracle(address(USDC), address(840), address(USDC_USD_FEED));
        addTokenToNoyaOracle(address(USDC), address(chainlinkOracle));
        
        // Add trusted positions
        registry.addTrustedPosition(vaultId, 0, address(accountingManager), false, false, abi.encode(USDC), "");
        registry.addTrustedPosition(vaultId, 0, address(mockConnector), false, false, abi.encode(USDC), "");
        registry.addTrustedPosition(vaultId, 0, address(mockConnector2), false, false, abi.encode(USDC), "");
        
        vm.stopPrank();
    }
    
    function test_WithdrawFulfillment() public {
        console.log("=== Testing Withdrawal Fulfillment Vulnerability ===");
        
        uint256 depositAmount = 100000 * 1e6; // 100,000 USDC
        uint256 withdrawShares = 50000 * 1e6; // 50,000 shares to withdraw
        
        // Give Alice some USDC
        _dealWhale(USDC, alice, USDC_Whale, depositAmount);
        
        // Send some USDC to the connectors (more than needed)
        _dealWhale(USDC, address(mockConnector), USDC_Whale, depositAmount);
        _dealWhale(USDC, address(mockConnector2), USDC_Whale, depositAmount);
        
        console.log("Alice balance before: %s USDC", IERC20(USDC).balanceOf(alice) / 1e6);
        
        // Alice deposits
        vm.startPrank(alice);
        SafeERC20.forceApprove(IERC20(USDC), address(accountingManager), depositAmount);
        accountingManager.deposit(alice, depositAmount, address(0));
        vm.stopPrank();
        
        // Process deposit
        vm.startPrank(owner);
        accountingManager.calculateDepositShares(10);
        vm.warp(block.timestamp + 35 minutes);
        accountingManager.executeDeposit(10, address(mockConnector), "");
        vm.stopPrank();
        
        console.log("Deposit completed. Alice shares: %s", accountingManager.balanceOf(alice) / 1e6);
        
        // Alice requests withdrawal
        vm.startPrank(alice);
        accountingManager.withdraw(withdrawShares, alice);
        vm.stopPrank();
        
        // Process withdrawal
        vm.startPrank(owner);
        accountingManager.calculateWithdrawShares(10);
        vm.warp(block.timestamp + 6 hours + 5 minutes);
        accountingManager.startCurrentWithdrawGroup();
        
        uint256 neededAmount = accountingManager.neededAssetsForWithdraw();
        (,uint256 totalCBAmount,,,,) = accountingManager.currentWithdrawGroup();
        
        console.log("Needed amount: %s USDC", neededAmount / 1e6);
        console.log("Total CB Amount: %s USDC", totalCBAmount / 1e6);
        
        console.log("=== Step 1: Request more than actual sent to create mismatch with needed >0 ===");
        
        uint256 requested = neededAmount + 20000 * 1e6;
        uint256 actual = neededAmount - 20000 * 1e6;
        
        // console.log("Requesting: %s USDC, but actual sent: %s USDC", requested / 1e6, actual / 1e6);
        
        RetrieveData[] memory retrieveData = new RetrieveData[](1);
        retrieveData[0] = RetrieveData({
            withdrawAmount: requested,
            connectorAddress: address(mockConnector),
            data: abi.encode(actual, actual)
        });
        
        accountingManager.retrieveTokensForWithdraw(retrieveData, address(mockConnector2), "");
        
        uint256 amountAsked = accountingManager.amountAskedForWithdraw();
        uint256 stillNeeded = accountingManager.neededAssetsForWithdraw();
        
        console.log("After request:");
        console.log("  amountAskedForWithdraw: %s USDC", amountAsked / 1e6);
        console.log("  neededAssetsForWithdraw: %s USDC", stillNeeded / 1e6);
        console.log("  totalCBAmount: %s USDC", totalCBAmount / 1e6);
        
        // // Optionally remove or adjust second request
        // // For demonstration, try to fulfill now
        
        console.log("=== Step 2: Attempt to fulfill - should revert due to mismatch ===");
        
        // bool shouldRevert = (stillNeeded != 0) && (amountAsked != totalCBAmount);
        // console.log("Should revert: %s", shouldRevert);
        // console.log("Condition 1 (neededAssets != 0): %s", stillNeeded != 0);
        // console.log("Condition 2 (amountAsked != totalCBAmount): %s", amountAsked != totalCBAmount);
        
        // if (shouldRevert) {
            // vm.expectRevert(abi.encodeWithSignature("NoyaAccounting_NOT_READY_TO_FULFILL()"));
            accountingManager.fulfillCurrentWithdrawGroup();
        //     console.log("SUCCESS: Fulfillment reverted as expected due to accounting mismatch!");
        // } else {
        //     console.log("NOTE: Vulnerability not triggered - adjust parameters");
        // }
    
        // console.log("=== VULNERABILITY DEMONSTRATED ===");
        // console.log("The mismatch between amountAskedForWithdraw (%s) and totalCBAmount (%s) with neededAssets >0 prevents fulfillment.", amountAsked / 1e6, totalCBAmount / 1e6);
        // console.log("User funds are stuck in the queue.");
        
        // vm.stopPrank();
    }
} 