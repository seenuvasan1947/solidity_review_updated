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
import "./utils/resources/ArbitrumAddresses.sol";

contract TestAaveConnectorArbitrum is testStarter, ArbitrumAddresses {
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

    function testGetRewards() public {
        console.log("----------- Get Rewards Test --------------");

        uint256 _amount = 100 * 1e6; // USDC

        _dealWhale(baseToken, address(connector), address(0x1AB4973a48dc892Cd9971ECE8e01DcC7688f8F23), _amount);

        vm.startPrank(address(owner));

        // registering reward token (ARB)
        addTrustedTokens(vaultId, address(accountingManager), ARB);
        addTokenToChainlinkOracle(address(ARB), address(840), address(ARB_USD_FEED));
        addTokenToNoyaOracle(address(ARB), address(chainlinkOracle));
        addRoutesToNoyaOracle(address(ARB), address(USDC), address(840));
        registry.addTrustedPosition(vaultId, 0, address(accountingManager), false, false, abi.encode(ARB), "");

        connector.supply(USDC, _amount);

        address _aToken = IPool(aavePool).getReserveData(USDC).aTokenAddress;
        address[] memory _aTokens = new address[](1);
        _aTokens[0] = _aToken;
        address _rewardController = address(IAToken(_aToken).getIncentivesController());

        address[] memory _rewardsList = IRewardsController(_rewardController).getRewardsList();
        assertTrue(_rewardsList.length > 0, "testGetRewards: E0");

        for (uint256 i = 0; i < _rewardsList.length; i++) {
            console.log("RewardsList[%s]: %s", i, _rewardsList[i]);
        }

        uint256 _tvl0 = accountingManager.totalAssets();
        console.log("TVL before claim: %s", _tvl0);

        connector.claimRewards(_rewardController, _aTokens); // no rewards to claim yet

        uint256 _tvl1 = accountingManager.totalAssets();

        assertTrue(_tvl0 == _tvl1, "testGetRewards: E1");

        vm.warp(block.timestamp + 1 days);

        connector.claimRewards(_rewardController, _aTokens);
        console.log("Rewards claimed");

        uint256 _tvl2 = accountingManager.totalAssets();
        console.log("TVL after claim: %s", _tvl2);

        assertTrue(_tvl2 > _tvl0, "testGetRewards: E2");

        vm.stopPrank();
    }
}
