// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts-5.0/utils/Strings.sol";
import "@openzeppelin/contracts-5.0/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-5.0/token/ERC20/IERC20.sol";

import "contracts/accountingManager/Bonding.sol";
import "./utils/testStarter.sol";
import "./utils/resources/MainnetAddresses.sol";
import "./utils/resources/BaseAddresses.sol";

contract TestBonding is testStarter, BaseAddresses {
    Bonding bonding;
    address depositor = 0x1C66eAE2BAc8b2CCeAd447a1C1FB40Eb86b7d820;

    function setUp() public {
        uint256 fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);
        bonding = Bonding(0xb14423D87e5b6B9ED75BBB9a1733b4a0D7A7245B);
    }

    function testBondingNoya() public {
        IERC20 usdc = IERC20(USDC);
        uint256 amount = 10_000;
        uint256 duration = 10_000;
        address noya = 0x9929020a9B7FaD6B9c78b38D9748Fb91FAfe8CE2;
        vm.startPrank(depositor);

        console.log("USDC balance: %s", address(bonding));
        SafeERC20.forceApprove(IERC20(noya), address(bonding), amount);
        Bonding(bonding).depositFor(address(depositor), amount, duration);

        // assertEq(Bonding(bonding).balanceOf(owner), amount);
        // uint256[] memory depositIds = new uint256[](1);
        // depositIds[0] = 1;
        // vm.expectRevert();
        // Bonding(bonding).withdrawMultiple(address(owner), depositIds);

        // depositIds[0] = 0;
        // vm.expectRevert();
        // Bonding(bonding).withdrawMultiple(address(owner), depositIds);

        // vm.warp(block.timestamp + duration + 1);

        // Bonding(bonding).withdrawMultiple(address(owner), depositIds);

        // uint256[] memory depositIds2 = new uint256[](10);
        // for (uint256 i = 0; i < 10; i++) {
        //     SafeERC20.forceApprove(IERC20(noya), address(bonding), amount);

        //     Bonding(bonding).depositFor(address(owner), amount, duration);
        //     depositIds2[i] = i + 1;
        // }

        // vm.warp(block.timestamp + duration + 1);

        // Bonding(bonding).withdrawMultiple(address(owner), depositIds2);

        // vm.stopPrank();
    }
}
