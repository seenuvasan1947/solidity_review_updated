// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Game.sol";

contract WithdrawWinningsTest is Test {
    Game public game;
    address public owner = address(0xABCD);
    address public alice = address(0xBEEF);
    address public bob = address(0xCAFE);

    function setUp() public {
        vm.prank(owner);
        game = new Game(
            1 ether,    // initialClaimFee (1 ETH)
            30,         // gracePeriod (30 seconds for testing)
            10,         // feeIncreasePercentage (10%)
            5           // platformFeePercentage (5%)
        );

        // Fund players
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testWinnerCanWithdrawAfterGameEnds() public {
        // Alice claims the throne first
        vm.prank(alice);
        game.claimThrone{value: 1 ether}();
        
        // Verify Alice is the current king
        assertEq(game.currentKing(), alice, "Alice should be the current king");
        
        // Fast forward past the grace period
        vm.warp(block.timestamp + 31); // 31 seconds (grace period is 30)
        
        // Anyone can declare the winner (let's have Bob do it)
        vm.prank(bob);
        game.declareWinner();
        
        // Verify game has ended
        assertTrue(game.gameEnded(), "Game should have ended");
        
        // Check Alice's pending winnings
        uint256 pendingWinnings = game.pendingWinnings(alice);
        assertGt(pendingWinnings, 0, "Alice should have pending winnings");
        
        // Track Alice's balance before withdrawal
        uint256 aliceBalanceBefore = alice.balance;
        
        // Alice withdraws her winnings
        vm.prank(alice);
        game.withdrawWinnings();
        
        uint256 aliceBalanceAfter = alice.balance;
        
        // Assert Alice received the funds
        assertEq(aliceBalanceAfter - aliceBalanceBefore, pendingWinnings, "Alice should have received her winnings");
        
        // Verify Alice's pending winnings are now zero
        assertEq(game.pendingWinnings(alice), 0, "Alice's pending winnings should be zero after withdrawal");
    }

    function testNonWinnerCannotWithdraw() public {
        // Alice claims the throne
        vm.prank(alice);
        game.claimThrone{value: 1 ether}();
        
        // Bob tries to withdraw without having any winnings
        vm.prank(bob);
        vm.expectRevert("Game: No winnings to withdraw.");
        game.withdrawWinnings();
    }

    function testMultipleClaimsAndWinnerWithdrawal() public {
        // Alice claims first
        vm.prank(alice);
        game.claimThrone{value: 1 ether}();
        
        // Bob claims (fee increased by 10%)
        uint256 newClaimFee = game.claimFee();
        vm.prank(bob);
        game.claimThrone{value: newClaimFee}();
        
        // Verify Bob is now the king
        assertEq(game.currentKing(), bob, "Bob should be the current king");
        
        // Fast forward past grace period
        vm.warp(block.timestamp + 31);
        
        // Declare Bob as winner
        vm.prank(alice);
        game.declareWinner();
        
        // Bob should be able to withdraw his winnings
        uint256 bobPendingWinnings = game.pendingWinnings(bob);
        assertGt(bobPendingWinnings, 0, "Bob should have pending winnings");
        
        uint256 bobBalanceBefore = bob.balance;
        
        vm.prank(bob);
        game.withdrawWinnings();
        
        uint256 bobBalanceAfter = bob.balance;
        
        assertEq(bobBalanceAfter - bobBalanceBefore, bobPendingWinnings, "Bob should have received his winnings");
    }

    function testCannotWithdrawTwice() public {
        // Setup: Alice becomes winner
        vm.prank(alice);
        game.claimThrone{value: 1 ether}();
        
        vm.warp(block.timestamp + 31);
        
        vm.prank(bob);
        game.declareWinner();
        
        // Alice withdraws once
        vm.prank(alice);
        game.withdrawWinnings();
        
        // Alice tries to withdraw again
        vm.prank(alice);
        vm.expectRevert("Game: No winnings to withdraw.");
        game.withdrawWinnings();
    }

    function testWithdrawWinningsReentrancyProtection() public {
        // Deploy a malicious contract that tries to re-enter
        MaliciousWithdrawer malicious = new MaliciousWithdrawer(address(game));
        vm.deal(address(malicious), 5 ether);
        
        // Make the malicious contract the winner
        vm.prank(address(malicious));
        game.claimThrone{value: 1 ether}();
        
        vm.warp(block.timestamp + 31);
        
        vm.prank(alice);
        game.declareWinner();
        
        // The malicious contract tries to withdraw and re-enter
        vm.prank(address(malicious));
        vm.expectRevert("ReentrancyGuard: reentrant call");
        malicious.attemptReentrantWithdraw();
    }
}

// Malicious contract for testing reentrancy protection
contract MaliciousWithdrawer {
    Game public game;
    uint256 public attempts = 0;
    
    constructor(address _game) {
        game = Game(payable(_game));
    }
    
    function attemptReentrantWithdraw() external {
        game.withdrawWinnings();
    }
    
    // This will be called when the contract receives ETH
    receive() external payable {
        attempts++;
        if (attempts == 1) {
            // Try to re-enter on first call
            game.withdrawWinnings();
        }
    }
}