// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

// Buggy version of the Game contract for PoC
contract BuggyGame {
    address public currentKing;
    uint256 public lastClaimTime;
    uint256 public claimFee;
    uint256 public pot;
    bool public gameEnded;
    
    constructor(uint256 _initialClaimFee) {
        claimFee = _initialClaimFee;
        lastClaimTime = block.timestamp;
        // currentKing starts as address(0)
    }
    
    // BUGGY VERSION - has the inverted logic
    function claimThrone() external payable {
        require(msg.value >= claimFee, "Insufficient ETH sent");
        // BUG: This should be != instead of ==
        require(msg.sender == currentKing, "You are already the king. No need to re-claim.");
        
        currentKing = msg.sender;
        lastClaimTime = block.timestamp;
        pot += msg.value;
    }
}

// Fixed version of the Game contract
contract FixedGame {
    address public currentKing;
    uint256 public lastClaimTime;
    uint256 public claimFee;
    uint256 public pot;
    bool public gameEnded;
    
    constructor(uint256 _initialClaimFee) {
        claimFee = _initialClaimFee;
        lastClaimTime = block.timestamp;
        // currentKing starts as address(0)
    }
    
    // FIXED VERSION - correct logic
    function claimThrone() external payable {
        require(msg.value >= claimFee, "Insufficient ETH sent");
        // FIXED: Changed == to !=
        require(msg.sender != currentKing, "You are already the king. No need to re-claim.");
        
        currentKing = msg.sender;
        lastClaimTime = block.timestamp;
        pot += msg.value;
    }
}

contract ClaimThroneBugPoC is Test {
    BuggyGame public buggyGame;
    FixedGame public fixedGame;
    
    address public alice = address(0xBEEF);
    address public bob = address(0xCAFE);
    address public charlie = address(0xDEAD);

    function setUp() public {
        // Deploy both versions
        buggyGame = new BuggyGame(1 ether);
        fixedGame = new FixedGame(1 ether);
        
        // Fund players
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
    }

    function testBuggyVersion_FirstClaimAlwaysFails() public {
        console.log("=== TESTING BUGGY VERSION ===");
        console.log("Initial currentKing:", buggyGame.currentKing());
        console.log("Alice's address:", alice);
        console.log("Is Alice == currentKing (address(0))?", alice == buggyGame.currentKing());
        
        // Alice tries to claim the throne (should fail due to bug)
        vm.prank(alice);
        vm.expectRevert("You are already the king. No need to re-claim.");
        buggyGame.claimThrone{value: 1 ether}();
        
        console.log("Alice's claim FAILED as expected due to bug");
        console.log("Current king after Alice's failed attempt:", buggyGame.currentKing());
        
        // Bob also tries and fails
        vm.prank(bob);
        vm.expectRevert("You are already the king. No need to re-claim.");
        buggyGame.claimThrone{value: 1 ether}();
        
        console.log("Bob's claim also FAILED due to same bug");
        console.log("Current king is still:", buggyGame.currentKing());
        
        // The game is completely broken - no one can ever become king!
        assertEq(buggyGame.currentKing(), address(0), "No one should be able to become king in buggy version");
    }

    function testFixedVersion_WorksCorrectly() public {
        console.log("\n=== TESTING FIXED VERSION ===");
        console.log("Initial currentKing:", fixedGame.currentKing());
        
        // Alice claims the throne successfully
        vm.prank(alice);
        fixedGame.claimThrone{value: 1 ether}();
        
        console.log("Alice successfully claimed the throne!");
        console.log("Current king after Alice's claim:", fixedGame.currentKing());
        assertEq(fixedGame.currentKing(), alice, "Alice should be the king");
        
        // Alice tries to claim again (should fail - correct behavior)
        vm.prank(alice);
        vm.expectRevert("You are already the king. No need to re-claim.");
        fixedGame.claimThrone{value: 1 ether}();
        
        console.log("Alice correctly cannot claim again");
        
        // Bob can claim and become the new king
        vm.prank(bob);
        fixedGame.claimThrone{value: 1 ether}();
        
        console.log("Bob successfully claimed the throne from Alice!");
        console.log("Current king after Bob's claim:", fixedGame.currentKing());
        assertEq(fixedGame.currentKing(), bob, "Bob should be the new king");
        
        // Charlie can also claim
        vm.prank(charlie);
        fixedGame.claimThrone{value: 1 ether}();
        
        console.log("Charlie successfully claimed the throne from Bob!");
        assertEq(fixedGame.currentKing(), charlie, "Charlie should be the new king");
    }

    function testBugExplanation() public {
        console.log("\n=== BUG EXPLANATION ===");
        console.log("BUGGY REQUIRE: require(msg.sender == currentKing, ...)");
        console.log("- Initially currentKing = address(0)");
        console.log("- When Alice (0xBEEF) tries to claim:");
        console.log("  - Check: 0xBEEF == 0x0000 FALSE");
        console.log("  - require(FALSE)  REVERTS");
        console.log("- Game is broken: no one can ever claim!");
        
        console.log("\nFIXED REQUIRE: require(msg.sender != currentKing, ...)");
        console.log("- Initially currentKing = address(0)");
        console.log("- When Alice (0xBEEF) tries to claim:");
        console.log("  - Check: 0xBEEF != 0x0000...  TRUE");
        console.log("  - require(TRUE)  PASSES");
        console.log("- Alice becomes king!");
        console.log("- When Alice tries again:");
        console.log("  - Check: 0xBEEF != 0xBEEF  FALSE");
        console.log("  - require(FALSE)  REVERTS (correct behavior)");
    }

    function testEdgeCases() public {
        console.log("\n=== EDGE CASES ===");
        
        // Test with zero address trying to claim in fixed version
        vm.deal(address(0), 1 ether);
        
        // This should work in fixed version (though unusual)
        vm.prank(address(0));
        fixedGame.claimThrone{value: 1 ether}();
        
        console.log("Even address(0) can claim throne in fixed version");
        assertEq(fixedGame.currentKing(), address(0), "address(0) should be able to become king");
        
        // Now address(0) cannot claim again
        vm.prank(address(0));
        vm.expectRevert("You are already the king. No need to re-claim.");
        fixedGame.claimThrone{value: 1 ether}();
        
        console.log("address(0) correctly cannot claim again");
    }

    function testGameProgression() public {
        console.log("\n=== GAME PROGRESSION TEST ===");
        
        address[5] memory players = [
            address(0x1111),
            address(0x2222), 
            address(0x3333),
            address(0x4444),
            address(0x5555)
        ];
        
        // Fund all players
        for(uint i = 0; i < players.length; i++) {
            vm.deal(players[i], 10 ether);
        }
        
        console.log("Testing multiple sequential claims in fixed version:");
        
        for(uint i = 0; i < players.length; i++) {
            vm.prank(players[i]);
            fixedGame.claimThrone{value: 1 ether}();
            
            console.log("Player", i+1, "successfully claimed throne");
            assertEq(fixedGame.currentKing(), players[i], "Player should be current king");
        }
        
        console.log("All 5 players successfully claimed throne sequentially!");
        console.log("Final king:", fixedGame.currentKing());
        console.log("Total pot:", fixedGame.pot());
    }
}