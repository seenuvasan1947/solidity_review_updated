// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

library Uint32Array {
    function addOriginal(
        uint32[] storage array,
        uint32 index,
        uint32 value
    ) internal {
        uint256 len = array.length;

        if (len > 0) {
            array.push(array[len - 1]);

            for (uint256 i = len - 1; i > index; i--) array[i] = array[i - 1];

            array[index] = value;
        } else {
            array.push(value);
        }
    }

    function addOptimized(
        uint32[] storage array,
        uint32 index,
        uint32 value
    ) internal {
        uint256 len = array.length;

        if (len == 0) {
            array.push(value);
            return;
        }

        array.push(array[len - 1]);

        unchecked {
            for (uint256 i = len - 1; i > index; i--) {
                array[i] = array[i - 1];
            }
        }

        array[index] = value;
    }
}

contract Uint32ArrayTest is Test {
    using Uint32Array for uint32[];

    uint32[] arr;

    function setUp() public {
        arr = [uint32(1), uint32(2), uint32(3), uint32(4), uint32(5)];
    }

    function testAddOriginal() public {
        uint32[] memory expected = new uint32[](6);
        expected[0] = 1;
        expected[1] = 2;
        expected[2] = 99;
        expected[3] = 3;
        expected[4] = 4;
        expected[5] = 5;

        arr.addOriginal(2, 99);

        for (uint256 i = 0; i < arr.length; i++) {
            assertEq(arr[i], expected[i]);
        }
    }

    function testAddOptimized() public {
        uint32[] memory expected = new uint32[](6);
        expected[0] = 1;
        expected[1] = 2;
        expected[2] = 88;
        expected[3] = 3;
        expected[4] = 4;
        expected[5] = 5;

        arr.addOptimized(2, 88);

        for (uint256 i = 0; i < arr.length; i++) {
            assertEq(arr[i], expected[i]);
        }
    }

    function testGasComparison() public {
        vm.recordLogs();

        arr = [uint32(1), uint32(2), uint32(3), uint32(4), uint32(5)];
        uint256 startGas = gasleft();
        arr.addOriginal(2, 77);
        uint256 originalGas = startGas - gasleft();

        arr = [uint32(1), uint32(2), uint32(3), uint32(4), uint32(5)];
        startGas = gasleft();
        arr.addOptimized(2, 77);
        uint256 optimizedGas = startGas - gasleft();

        emit log_named_uint("Original add gas:", originalGas);
        emit log_named_uint("Optimized add gas:", optimizedGas);
    }
}
