// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "../interface/Accounting/IBonding.sol";
import "@openzeppelin/contracts-5.0/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-5.0/access/Ownable.sol";
import "@openzeppelin/contracts-5.0/utils/Pausable.sol";

contract Bonding is IBonding, Ownable, Pausable, ERC20 {
    using SafeERC20 for IERC20;

    Stake[] public userStakes;
    IERC20 private immutable _underlying;

    uint256 public maxBondingDuration = 1642 days; // 4.5 years

    /**
     * @dev The underlying token couldn't be wrapped.
     */
    error ERC20InvalidUnderlying(address token);
    error BondingDurationExceedsMax();

    constructor(IERC20 underlyingToken, string memory name_, string memory symbol_)
        Ownable(msg.sender)
        ERC20(name_, symbol_)
    {
        _underlying = underlyingToken;
    }

    function setMaxBondingDuration(uint256 duration) external onlyOwner {
        maxBondingDuration = duration;
    }

    /**
     * @dev See {ERC20-decimals}.
     */
    function decimals() public view virtual override returns (uint8) {
        try IERC20Metadata(address(_underlying)).decimals() returns (uint8 value) {
            return value;
        } catch {
            return super.decimals();
        }
    }

    /**
     * @dev Returns the address of the underlying ERC-20 token that is being wrapped.
     */
    function underlying() public view returns (IERC20) {
        return _underlying;
    }

    /**
     * @dev Allow a user to deposit underlying tokens and mint the corresponding number of wrapped tokens.
     */
    function depositFor(address account, uint256 value, uint256 duration) public virtual returns (bool) {
        if (duration > maxBondingDuration) {
            revert BondingDurationExceedsMax();
        }
        address sender = _msgSender();
        if (sender == address(this)) {
            revert ERC20InvalidSender(address(this));
        }
        if (account == address(this)) {
            revert ERC20InvalidReceiver(account);
        }
        SafeERC20.safeTransferFrom(_underlying, sender, address(this), value);
        userStakes.push(Stake(account, value, block.timestamp, block.timestamp + duration));
        emit Staked(account, value, duration, userStakes.length - 1);

        _mint(account, value);
        return true;
    }

    /**
     * @dev Allow a user to burn a number of wrapped tokens and withdraw the corresponding number of underlying tokens.
     */
    function withdrawMultiple(address account, uint256[] memory depositIds) public virtual returns (bool) {
        if (account != _msgSender()) {
            revert NotTheOwner();
        }
        uint256 value = 0;
        for (uint256 i = 0; i < depositIds.length; i++) {
            Stake memory stake = userStakes[depositIds[i]];
            if (stake.owner != account) {
                revert NotTheOwner();
            }
            if (stake.unbondTimestamp >= block.timestamp) {
                revert BondingDurationIsNotFinished();
            }
            value += stake.amount;
            emit Unbonded(account, stake.amount, depositIds[i]);
            delete userStakes[depositIds[i]];
        }
        _burn(account, value);
        SafeERC20.safeTransfer(_underlying, account, value);
        return true;
    }

    function restake(uint256 depositId, uint256 newDuration) external {
        Stake storage stake = userStakes[depositId];
        if (stake.owner != msg.sender) {
            revert NotTheOwner();
        }
        if (stake.unbondTimestamp >= block.timestamp) {
            revert BondingDurationIsNotFinished();
        }

        stake.unbondTimestamp = block.timestamp + newDuration;
        emit Restaked(msg.sender, stake.amount, newDuration, depositId);
    }

    /**
     * @dev Mint wrapped token to cover any underlyingTokens that would have been transferred by mistake or acquired from
     * rebasing mechanisms. Internal function that can be exposed with access control if desired.
     */
    function _recover(address account) public virtual onlyOwner returns (uint256) {
        uint256 value = _underlying.balanceOf(address(this)) - totalSupply();
        _mint(account, value);
        userStakes.push(Stake(account, value, block.timestamp, block.timestamp));
        emit Staked(account, value, 0, userStakes.length - 1);
        return value;
    }
}
