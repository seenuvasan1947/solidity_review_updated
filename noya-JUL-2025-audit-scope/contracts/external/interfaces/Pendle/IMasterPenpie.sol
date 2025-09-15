// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMasterPenpie {

    function penpieOFT() external view returns (address);
    function multiclaim(address[] memory _stakingTokens) external;
    function allPendingTokens(address _stakingToken, address _user)
        external
        view
        returns (
            uint256 pendingPenpie,
            address[] memory bonusTokenAddresses,
            string[] memory bonusTokenSymbols,
            uint256[] memory pendingBonusRewards
        );

}