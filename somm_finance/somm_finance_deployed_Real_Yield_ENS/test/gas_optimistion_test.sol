// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import {Test} from "lib/forge-std/src/Test.sol";
import {Uint32Array} from "src/utils/Uint32Array.sol";

contract PositionsHarness {
    using Uint32Array for uint32[];

    uint256 public constant MAX_POSITIONS = 16;

    uint32[] public creditPositions;
    uint32[] public debtPositions;

    // Mimic the current if/else pattern
    function addIfElse(bool isDebt, uint32 index, uint32 positionId) external {
        if (isDebt) {
            if (debtPositions.length >= MAX_POSITIONS) revert("full");
            debtPositions.add(index, positionId);
        } else {
            if (creditPositions.length >= MAX_POSITIONS) revert("full");
            creditPositions.add(index, positionId);
        }
    }

    // Optimized single-branch using a storage pointer
    function addPointer(bool isDebt, uint32 index, uint32 positionId) external {
        uint32[] storage positions = isDebt ? debtPositions : creditPositions;
        if (positions.length >= MAX_POSITIONS) revert("full");
        positions.add(index, positionId);
    }

    function seed(uint32 n) external {
        // fill both arrays equally for stable comparisons
        for (uint32 i = 0; i < n; ++i) {
            creditPositions.push(i + 1);
            debtPositions.push(i + 1);
        }
    }

    function creditLen() external view returns (uint256) { return creditPositions.length; }
    function debtLen() external view returns (uint256) { return debtPositions.length; }
}

contract GasOptimisationTest is Test {
    using Uint32Array for uint32[];

    PositionsHarness private h;

    function setUp() public {
        h = new PositionsHarness();
        h.seed(8); // start at length 8 for both
    }

    // Compare on credit side (isDebt = false)
    function testGas_ifElse_credit_append() public {
        uint32 idx = uint32(h.creditLen());
        uint256 g0 = gasleft();
        h.addIfElse(false, idx, 999);
        uint256 used = g0 - gasleft();
        emit log_named_uint("gas if/else (credit, append)", used);
    }

    function testGas_pointer_credit_append() public {
        uint32 idx = uint32(h.creditLen());
        uint256 g0 = gasleft();
        h.addPointer(false, idx, 999);
        uint256 used = g0 - gasleft();
        emit log_named_uint("gas pointer (credit, append)", used);
    }

    // Compare on debt side (isDebt = true)
    function testGas_ifElse_debt_append() public {
        uint32 idx = uint32(h.debtLen());
        uint256 g0 = gasleft();
        h.addIfElse(true, idx, 999);
        uint256 used = g0 - gasleft();
        emit log_named_uint("gas if/else (debt, append)", used);
    }

    function testGas_pointer_debt_append() public {
        uint32 idx = uint32(h.debtLen());
        uint256 g0 = gasleft();
        h.addPointer(true, idx, 999);
        uint256 used = g0 - gasleft();
        emit log_named_uint("gas pointer (debt, append)", used);
    }

    // Assertion: pointer approach should be <= if/else
    function test_pointer_isCheaper_or_equal_credit_append() public {
        // fresh appends
        uint32 idx1 = uint32(h.creditLen());
        uint256 g1 = gasleft();
        h.addIfElse(false, idx1, 777);
        uint256 usedIfElse = g1 - gasleft();

        uint32 idx2 = uint32(h.creditLen());
        uint256 g2 = gasleft();
        h.addPointer(false, idx2, 778);
        uint256 usedPtr = g2 - gasleft();

        emit log_named_uint("if/else credit append", usedIfElse);
        emit log_named_uint("pointer credit append", usedPtr);
        assertLe(usedPtr, usedIfElse, "storage pointer should be <= if/else on credit append");
    }

    function test_pointer_isCheaper_or_equal_debt_append() public {
        uint32 idx1 = uint32(h.debtLen());
        uint256 g1 = gasleft();
        h.addIfElse(true, idx1, 777);
        uint256 usedIfElse = g1 - gasleft();

        uint32 idx2 = uint32(h.debtLen());
        uint256 g2 = gasleft();
        h.addPointer(true, idx2, 778);
        uint256 usedPtr = g2 - gasleft();

        emit log_named_uint("if/else debt append", usedIfElse);
        emit log_named_uint("pointer debt append", usedPtr);
        assertLe(usedPtr, usedIfElse, "storage pointer should be <= if/else on debt append");
    }
}


