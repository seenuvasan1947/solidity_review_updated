// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "../BaseConnector.sol";
import {IERC20} from "@openzeppelin/contracts-5.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-5.0/token/ERC20/utils/SafeERC20.sol";

contract MockConnector is BaseConnector {
    using SafeERC20 for IERC20;

    // ------------ Constructor -------------- //
    constructor(BaseConnectorCP memory baseConnectorParams)
    BaseConnector(baseConnectorParams)
    {
    }

    function refund(address token, uint256 amount) external onlyManager {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}
