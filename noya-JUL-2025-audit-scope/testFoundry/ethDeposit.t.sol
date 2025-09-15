// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "./utils/testStarter.sol";
import "contracts/helpers/BaseConnector.sol";
import "contracts/accountingManager/NoyaFeeReceiver.sol";
import "./utils/resources/OptimismAddresses.sol";
import "contracts/governance/Keepers.sol";
import "contracts/accountingManager/ETHDepositContract.sol";
import "./utils/mocks/EmergancyMock.sol";
import "./utils/mocks/ConnectorMock2.sol";

contract TestAccounting is testStarter, OptimismAddresses {
    using SafeERC20 for IERC20;

    address connector;
    address connector2;
    NoyaFeeReceiver managementFeeReceiver;
    NoyaFeeReceiver performanceFeeReceiver;
    address withdrawFeeReceiver = bob;
    ETHDepositContract ethdepositContract;

    uint256 privateKey1 =
        0x99ba14aff4aba765903a41b48aacdf600b6fcdb2b0c2424cd2f8f2c089f20476;
    uint256 privateKey2 =
        0x68ab62e784b873b929e98fc6b6696abcc624cf71af05bf8d88b4287e9b58ab99;
    uint256 privateKey3 =
        0x952b55e8680117e6de5bde1d3e7902baa89bfde931538a5bb42ba392ef3464a4;
    uint256 privateKey4 =
        0x885f1d08ebc23709517fedbec64418e4a09ac1e47e976c868fd8c93de0f88f09;

    function setUp() public {
        // --------------------------------- set env --------------------------------
        uint256 fork = vm.createFork(RPC_URL, startingBlock);
        vm.selectFork(fork);

        console.log("Test timestamp: %s", block.timestamp);

        // --------------------------------- deploy the contracts ---------------------------------
        vm.startPrank(owner);

        deployEverythingNormal(WETH);

        // --------------------------------- init connector ---------------------------------
        connector = address(
            new BaseConnector(
                BaseConnectorCP(registry, 0, swapHandler, noyaOracle)
            )
        );
        connector2 = address(new ConnectorMock2(address(registry), 0));

        // ------------------- add connector to registry -------------------
        addConnectorToRegistry(vaultId, connector);
        addConnectorToRegistry(vaultId, connector2);
        console.log("AaveConnector added to registry");

        addTrustedTokens(vaultId, address(accountingManager), USDC);
        addTrustedTokens(vaultId, address(accountingManager), WETH);
        addTrustedTokens(vaultId, address(accountingManager), DAI);

        addTokenToChainlinkOracle(
            address(USDC),
            address(840),
            address(USDC_USD_FEED)
        );
        addTokenToNoyaOracle(address(USDC), address(chainlinkOracle));

        addTokenToChainlinkOracle(
            address(DAI),
            address(840),
            address(DAI_USD_FEED)
        );
        addTokenToNoyaOracle(address(DAI), address(chainlinkOracle));

        console.log("Tokens added to registry");
        registry.addTrustedPosition(
            vaultId,
            0,
            address(accountingManager),
            false,
            false,
            abi.encode(WETH),
            ""
        );
        console.log("Positions added to registry");

        managementFeeReceiver = new NoyaFeeReceiver(
            address(accountingManager),
            baseToken,
            owner
        );
        performanceFeeReceiver = new NoyaFeeReceiver(
            address(accountingManager),
            baseToken,
            owner
        );

        accountingManager.updateValueOracle(noyaOracle);
        accountingManager.setDepositLimits(1e30, 1e30);

        ethdepositContract = new ETHDepositContract(WETH, address(registry));
        vm.stopPrank();
    }

    function testVaultETHDeposit() public {
        console.log("-----------Base Workflow--------------");

        uint256 _amount = 10 * 1e18;
        _dealEth(address(alice), _amount);

        vm.startPrank(alice);

        // ------------------------------ deposit ------------------------------
        ethdepositContract.deposit{value: _amount}(vaultId, address(0));

        // ------------------------------ check deposit queue ------------------------------
        uint256[] memory arr = new uint256[](1);
        arr[0] = 0;
        (DepositRequest[] memory depositItem, ) = accountingManager
            .getQueueItems(true, arr);
        assertDepositRequest(
            depositItem[0],
            DepositRequest({
                receiver: address(alice),
                recordTime: block.timestamp,
                calculationTime: 0,
                amount: _amount,
                shares: 0
            })
        );
        (
            uint256 first,
            uint256 middle,
            uint256 last,
            uint256 tokenAmountWaitingForDeposit
        ) = accountingManager.depositQueue();

        assertTrue(
            tokenAmountWaitingForDeposit == _amount,
            "DepositQueue tokenAmountWaitingForConfirmation is not correct"
        );
        assertTrue(first == 0, "DepositQueue first is not correct");
        assertTrue(last == 1, "DepositQueue last is not correct");
        assertTrue(middle == 0, "DepositQueue length is not correct");

        console.log("Deposit time: %s", block.timestamp);

        // ------------------------------ calculate shares ------------------------------
        vm.expectRevert();
        accountingManager.calculateDepositShares(10);

        // ------------------------------ change the address ------------------------------

        vm.stopPrank();
        vm.startPrank(owner);

        accountingManager.calculateDepositShares(10);

        // // ------------------------------ check deposit queue ------------------------------
        (depositItem, ) = accountingManager.getQueueItems(true, arr);
        assertDepositRequest(
            depositItem[0],
            DepositRequest({
                receiver: address(alice),
                recordTime: block.timestamp,
                calculationTime: block.timestamp,
                amount: _amount,
                shares: _amount
            })
        );

        (first, middle, last, tokenAmountWaitingForDeposit) = accountingManager
            .depositQueue();
        assertTrue(
            tokenAmountWaitingForDeposit == _amount,
            "DepositQueue tokenAmountWaitingForConfirmation is not correct"
        );
        assertTrue(first == 0, "DepositQueue first is not correct");
        assertTrue(last == 1, "DepositQueue last is not correct");
        assertTrue(middle == 1, "DepositQueue length is not correct");

        // // ------------------------------ execute deposit ------------------------------
        // // won't effect because the time is not passed yet
        vm.expectRevert();
        accountingManager.executeDeposit(10, connector, "");
        vm.expectRevert();
        accountingManager.executeDeposit(10, connector, "");

        (first, middle, last, tokenAmountWaitingForDeposit) = accountingManager
            .depositQueue();
        assertTrue(
            tokenAmountWaitingForDeposit == _amount,
            "DepositQueue tokenAmountWaitingForConfirmation is not correct"
        );
        assertTrue(first == 0, "DepositQueue first is not correct");
        assertTrue(last == 1, "DepositQueue last is not correct");
        assertTrue(middle == 1, "DepositQueue length is not correct");

        // // ------------------------------ warp the vm time ------------------------------

        vm.warp(block.timestamp + 35 minutes);

        accountingManager.executeDeposit(10, connector, "");

        (first, middle, last, tokenAmountWaitingForDeposit) = accountingManager
            .depositQueue();

        assertTrue(
            tokenAmountWaitingForDeposit == 0,
            "DepositQueue tokenAmountWaitingForConfirmation is not correct"
        );
        assertTrue(first == 1, "DepositQueue first is not correct");
        assertTrue(last == 1, "DepositQueue last is not correct");
        assertTrue(middle == 1, "DepositQueue length is not correct");

        accountingManager.updateValueOracle(noyaOracle);

        accountingManager.setFeeReceivers(owner, owner, owner);

        accountingManager.setFees(0, 0, 0);

        vm.stopPrank();
    }

    function assertDepositRequest(
        DepositRequest memory _depositRequest1,
        DepositRequest memory _depositRequest2
    ) internal {
        assertEq(
            _depositRequest1.receiver,
            _depositRequest2.receiver,
            "Deposit request alice is not correct"
        );
        assertEq(
            _depositRequest1.recordTime,
            _depositRequest2.recordTime,
            "Deposit request timestamp is not correct"
        );
        assertEq(
            _depositRequest1.calculationTime,
            _depositRequest2.calculationTime,
            "Deposit request calculationTime is not correct"
        );
        assertEq(
            _depositRequest1.amount,
            _depositRequest2.amount,
            "Deposit request amount is not correct"
        );
        assertEq(
            _depositRequest1.shares,
            _depositRequest2.shares,
            "Deposit request shares is not correct"
        );
    }
}
