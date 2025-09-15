// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

interface IBonding {
    error InvalidDepositId();
    error NotTheOwner();
    error BondingDurationIsNotFinished();

    event Staked(address indexed user, uint256 amount, uint256 duration, uint256 depositId);
    event Restaked(address indexed user, uint256 amount, uint256 duration, uint256 depositId);
    event Unbonded(address indexed user, uint256 amount, uint256 depositId);

    struct Stake {
        address owner;
        uint256 amount;
        uint256 startTimestamp;
        uint256 unbondTimestamp;
    }
}
