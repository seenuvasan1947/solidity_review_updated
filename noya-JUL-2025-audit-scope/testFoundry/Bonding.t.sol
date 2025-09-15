// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts-5.0/utils/Strings.sol";
import "@openzeppelin/contracts-5.0/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-5.0/token/ERC20/IERC20.sol";

import "contracts/accountingManager/Bonding.sol";
import "./utils/testStarter.sol";
import "./utils/resources/MainnetAddresses.sol";

contract TestBonding is testStarter, MainnetAddresses {
    Bonding bonding;

    function setUp() public {
        uint256 fork = vm.createFork(RPC_URL, startingBlock);
        vm.selectFork(fork);
        bonding = new Bonding(IERC20(USDC), "Bonding", "BOND");
    }

    function testBonding() public {
        IERC20 usdc = IERC20(USDC);
        uint256 amount = 10_000;
        uint256 duration = 10_000;
        _dealWhale(USDC, address(owner), address(0x1AB4973a48dc892Cd9971ECE8e01DcC7688f8F23), 100 * amount);

        vm.startPrank(owner);

        console.log("USDC balance: %s", address(bonding));
        SafeERC20.forceApprove(IERC20(USDC), address(bonding), amount);
        Bonding(bonding).depositFor(address(owner), amount, duration);

        assertEq(Bonding(bonding).balanceOf(owner), amount);
        uint256[] memory depositIds = new uint256[](1);
        depositIds[0] = 1;
        vm.expectRevert();
        Bonding(bonding).withdrawMultiple(address(owner), depositIds);

        depositIds[0] = 0;
        vm.expectRevert();
        Bonding(bonding).withdrawMultiple(address(owner), depositIds);

        vm.warp(block.timestamp + duration + 1);

        Bonding(bonding).withdrawMultiple(address(owner), depositIds);

        uint256[] memory depositIds2 = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            SafeERC20.forceApprove(IERC20(USDC), address(bonding), amount);

            Bonding(bonding).depositFor(address(owner), amount, duration);
            depositIds2[i] = i + 1;
        }

        vm.warp(block.timestamp + duration + 1);

        Bonding(bonding).withdrawMultiple(address(owner), depositIds2);

        vm.stopPrank();
    }
}
