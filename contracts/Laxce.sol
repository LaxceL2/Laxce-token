// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Laxce is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable
{
    bool public isBlacklistEnabled;
    mapping(address account => bool) public isBlacklisted;
    event EnableOrDisableBlacklist(bool isBlacklistEnabled);
    event BlacklistedAccounts(address[] accounts, bool[] isBlacklisted);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init("Laxce", "LAX");
        __Ownable_init(msg.sender);
        __ERC20Permit_init("Laxce");
        __UUPSUpgradeable_init();

        _mint(msg.sender, 500000000 * 10 ** decimals());
    }

    /**
     * @notice Burns a specific amount of tokens from the caller's account, reducing the total supply.
     * @param amount The amount of tokens to burn.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(
        address to,
        uint256 value
    ) public virtual override returns (bool) {
        address owner = _msgSender();
        if (isBlacklistEnabled) {
            _isAccountBlacklisted(owner);
        }
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        if (isBlacklistEnabled) {
            _isAccountBlacklisted(spender);
        }
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @notice Checks if an account is blacklisted
     * @dev Throws an error if the account is blacklisted
     * @param from The address to check for blacklist status
     */ 
    function _isAccountBlacklisted(address from) internal view {
        require(!isBlacklisted[from], "Account is blacklisted");
    }
    
    /**
     * @notice Enables or disables the blacklist functionality
     * @dev This function can only be called by the contract owner
     * @param isBlacklist A boolean indicating if the blacklist should be enabled or disabled
     */
    function enableOrDisableBlacklist(bool isBlacklist) external onlyOwner {
        isBlacklistEnabled = isBlacklist;
        emit EnableOrDisableBlacklist(isBlacklist);
    }

    /**
     * @notice Adds or removes multiple accounts from the blacklist
     * @dev Requires that the length of `accounts` and `isBlacklist` arrays be the same
     * @param accounts An array of addresses to be blacklisted or removed from blacklist
     * @param isBlacklist A boolean array specifying the blacklist status for each account
     */
    function blacklistAccounts(
        address[] calldata accounts,
        bool[] calldata isBlacklist
    ) external onlyOwner {
        require(accounts.length == isBlacklist.length, "Invalid parameters");
        for (uint256 i = 0; i < accounts.length; i++) {
            isBlacklisted[accounts[i]] = isBlacklist[i];
        }
        emit BlacklistedAccounts(accounts, isBlacklist);
    }

    /**
     * @dev Prevents the renouncement of ownership. Overrides the renounceOwnership function from OwnableUpgradeable.
     */
    function renounceOwnership() public view override onlyOwner {
        revert("Renounce ownership is disabled.");
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
