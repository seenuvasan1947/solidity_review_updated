// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;
import {IWETH} from "../external/interfaces/WETH.sol";
import {PositionRegistry, Vault} from "./Registry.sol";
import "@openzeppelin/contracts-5.0/token/ERC20/utils/SafeERC20.sol";
import {AccountingManager} from "./AccountingManager.sol";

contract ETHDepositContract {
    using SafeERC20 for IERC20;
    // WETH and registry addresses
    address public immutable WETH;
    address public immutable registry;

    // Constructor to initialize WETH and registry addresses
    constructor(address _weth, address _registry) {
        WETH = _weth;
        registry = _registry;
    }

    // Event emitted when ETH is deposited
    event EthDeposited(address indexed depositor, uint256 amount);

    // Function to deposit ETH
    function deposit(uint256 vaultId, address referrer) external payable {
        emit EthDeposited(msg.sender, msg.value);

        // Convert ETH to WETH
        IWETH(WETH).deposit{value: msg.value}();

        (address accountingManager, address baseToken) = PositionRegistry(
            registry
        ).getVaultAddresses(vaultId);
        require(
            baseToken == WETH, // Ensure the vault type is WETH
            "Vault base token must be WETH"
        );

        // Approve the registry to spend WETH
        IERC20(WETH).forceApprove(accountingManager, msg.value);

        // Call the AccountingManager to handle the deposit
        AccountingManager(accountingManager).deposit(
            msg.sender,
            msg.value,
            referrer
        );
    }
}
