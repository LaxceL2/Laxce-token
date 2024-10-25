// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conform
 * the base architecture for crowdsales. They are *not* intended to be modified / overriden.
 * The internal interface conforms the extensible and modifiable surface of crowdsales. Override
 * the methods to add functionality. Consider using 'super' where appropiate to concatenate
 * behavior.
 */
abstract contract Crowdsale is Initializable {
    // The token being sold
    IERC20 public rewardToken;
    using SafeERC20 for IERC20;
    IERC20 public usdtToken;

    // How many token units a buyer gets per USDT
    uint256 public rate; // eg. Rate Representation: If you want 1 USDT = 0.5 Laxce, you set rate = 5000. This way, you can handle two decimal places by scaling the rate by 10^4.
    // Amount of usdt raised
    uint256 public usdtRaised;

    struct UserInfo {
        uint256 usdtContributed;
        uint256 laxceRecieved;
    }

    mapping(address => UserInfo) public users;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value usdts paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokenPurchase(
        address indexed purchaser,
        address indexed beneficiary,
        uint256 value,
        uint256 amount
    );

    /**
     * @param _rate Number of token units a buyer gets per usdt
     * @param _token Address of the token being sold
     */
    function __Crowdsale_init_unchained(uint256 _rate, IERC20 _token) internal {
        require(_rate > 0, "Rate cant be 0");
        rate = _rate;
        rewardToken = _token;
    }

    // -----------------------------------------
    // Crowdsale external interface
    // -----------------------------------------

    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     */
    receive() external payable {}

    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * @param _beneficiary Address performing the token purchase
     */
    function buyTokens(address _beneficiary, uint256 usdtAmount) internal {
        _preValidatePurchase(_beneficiary, usdtAmount);
        usdtToken.safeTransferFrom(msg.sender, address(this), usdtAmount);
        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(usdtAmount);

        // update state
        usdtRaised = usdtRaised + usdtAmount;

        UserInfo storage user = users[_beneficiary];
        user.usdtContributed += usdtAmount;
        user.laxceRecieved += tokens;

        _processPurchase(msg.sender, tokens);

        emit TokenPurchase(msg.sender, _beneficiary, usdtAmount, tokens);
    }

    // -----------------------------------------
    // Internal interface (extensible)
    // -----------------------------------------

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use super to concatenate validations.
     * @param _beneficiary Address performing the token purchase
     * @param _usdtAmount Value in usdt involved in the purchase
     */
    function _preValidatePurchase(
        address _beneficiary,
        uint256 _usdtAmount
    ) internal virtual {
        require(_beneficiary != address(0), "Address cant be zero address");
        require(_usdtAmount != 0, "Amount cant be 0");
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
     * @param _beneficiary Address performing the token purchase
     * @param _tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(
        address _beneficiary,
        uint256 _tokenAmount
    ) internal {
        rewardToken.transfer(_beneficiary, _tokenAmount);
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
     * @param _beneficiary Address receiving the tokens
     * @param _tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(
        address _beneficiary,
        uint256 _tokenAmount
    ) internal {
        _deliverTokens(_beneficiary, _tokenAmount);
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param _usdtAmount Value in usdt to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _usdtAmount
     */
    function _getTokenAmount(
        uint256 _usdtAmount
    ) internal view returns (uint256) {
        uint256 tRate = (rate * 10 ** 6) / 10000; // rate accepts upto two decimals that's why 10000
        uint256 tokens = (_usdtAmount * tRate) / 10 ** 6;
        return tokens * 10 ** 12; // here 10**12 usdt is 6 decimal while convert to Laxce need to add 12 decimal.
    }

    /**
     * @dev Change Rate.
     * @param newRate Crowdsale rate
     */
    function _changeRate(uint256 newRate) internal virtual {
        rate = newRate;
    }

    /**
     * @dev Change Token.
     * @param newToken Crowdsale token
     */
    function _changeToken(IERC20 newToken) internal virtual {
        rewardToken = newToken;
    }

    /**
     * @dev Change Token.
     * @param updateUsdtToken usdt token
     */
    function _changeUsdtToken(IERC20 updateUsdtToken) internal virtual {
        usdtToken = updateUsdtToken;
    }
}

contract LaxceCrowdSale is
    Crowdsale,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    mapping(address account => bool) public isBlacklisted;
    bool public isBlacklistEnabled;
    bool public isBuyLimitEnabled;
    uint256 public minimumBuyLimit;
    uint256 public maximumBuyLimit;

    event WithdrawToken(address token, address to, uint256 amount); // Event for Withdraw token from contract
    event EnableOrDisableBlacklist(bool isBlacklistEnabled);
    event BlacklistAccounts(address[] accounts, bool[] status);
    event UpdateBuyLimit(uint256 minBuyLimit, uint256 maxBuyLimit);
    event EnableOrDisableBuyLimit(bool isEnableBuyLimit);

    /**
     * @dev Initialize the crowdsale contract.
     * @param rate The rate at which tokens are sold per usdt.
     * @param _token The token to be sold.
     * @param _usdtToken The token an user can contribute.
     */
    function initialize(
        uint256 rate,
        IERC20 _token,
        IERC20 _usdtToken
    ) public initializer {
        usdtToken = _usdtToken;
        __Crowdsale_init_unchained(rate, _token);
        __Pausable_init_unchained();
        __Ownable_init_unchained(msg.sender);
        __Context_init_unchained();
        __ReentrancyGuard_init_unchained();
        minimumBuyLimit = 5000;
        maximumBuyLimit = 500000;
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     */
    function _authorizeUpgrade(address) internal virtual override onlyOwner {}

    /**
     * @dev Pause the contract, preventing token purchases and transfers.
     * See {ERC20Pausable-_pause}.
     */
    function pauseContract() external virtual onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract, allowing token purchases and transfers to resume.
     * See {ERC20Pausable-_unpause}.
     */
    function unPauseContract() external virtual onlyOwner {
        _unpause();
    }

    /**
     * @dev Prevents the renouncement of ownership. Overrides the renounceOwnership function from OwnableUpgradeable.
     */
    function renounceOwnership() public view override onlyOwner {
        revert("Renounce ownership is disabled.");
    }

    /**
     * @dev Purchase tokens for a specified beneficiary.
     * @param _beneficiary The address of the beneficiary.
     */
    function buyToken(
        address _beneficiary,
        uint256 usdtAmount
    ) external whenNotPaused nonReentrant {
        if (isBlacklistEnabled) {
            _isAccountBlacklisted(msg.sender);
        }
        if (isBuyLimitEnabled) {
            // Ensure the purchase amount is within the defined limits
            require(
                usdtAmount >= minimumBuyLimit,
                "Purchase amount below minimum limit"
            );
            require(
                usdtAmount <= maximumBuyLimit,
                "Purchase amount exceeds maximum limit"
            );
        }
        buyTokens(_beneficiary, usdtAmount);
    }

    /**
     * @dev Change the rate at which tokens are sold per usdt.
     * @param newRate The new rate to be set.
     */
    function changeRate(
        uint256 newRate
    ) external virtual onlyOwner whenNotPaused {
        require(newRate > 0, "Rate: Amount cannot be 0");
        _changeRate(newRate);
    }

    /**
     * @dev Change the token being sold in the crowdsale.
     * @param newToken The new token contract address to be used.
     */
    function changeToken(
        IERC20 newToken
    ) external virtual onlyOwner whenNotPaused {
        require(
            address(newToken) != address(0),
            "Token: Address cant be zero address"
        );
        _changeToken(newToken);
    }

    /**
     * @dev Change the usdt token address.
     * @param _usdtToken The new token address to be used.
     */
    function changeUsdtToken(
        IERC20 _usdtToken
    ) external virtual onlyOwner whenNotPaused {
        _changeUsdtToken(_usdtToken);
    }

    /**
     * @dev Allows the owner to withdraw ERC-20 tokens from this contract.
     * @param _tokenContract The address of the ERC-20 token contract.
     * @param _amount The amount of tokens to withdraw.
     * @notice The '_tokenContract' address should not be the zero address.
     */
    function withdrawToken(
        address _tokenContract,
        uint256 _amount
    ) external onlyOwner nonReentrant {
        require(_tokenContract != address(0), "Address cant be zero address");
        IERC20 tokenContract = IERC20(_tokenContract);
        tokenContract.safeTransfer(msg.sender, _amount);
        emit WithdrawToken(_tokenContract, msg.sender, _amount);
    }

    /**
     * @notice Withdraw Ether from the contract by the admin
     * @param _to The address to send the withdrawn Ether to
     * @param _amount The amount of Ether to withdraw
     */
    function withdrawEther(
        address payable _to,
        uint256 _amount
    ) external onlyOwner nonReentrant {
        require(_to != address(0), "Invalid recipient address");
        require(_amount > 0, "Amount must be greater than 0");
        require(
            address(this).balance >= _amount,
            "Insufficient Ether balance in the contract"
        );

        // Transfer the specified amount of Ether to the recipient
        _to.transfer(_amount);
    }

    /**
     * @notice Enables or disables the blacklist functionality
     * @dev This function can only be called by the contract owner
     * @param isBlacklist A boolean indicating if the blacklist should be enabled or disabled
     */
    function enableOrDisableBlacklist(
        bool isBlacklist
    ) external onlyOwner nonReentrant {
        isBlacklistEnabled = isBlacklist;
        emit EnableOrDisableBlacklist(isBlacklist);
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
     * @notice Adds or removes multiple accounts from the blacklist
     * @dev Requires that the length of `accounts` and `isBlacklist` arrays be the same
     * @param accounts An array of addresses to be blacklisted or removed from blacklist
     * @param isBlacklist A boolean array specifying the blacklist status for each account
     */
    function blacklistAccounts(
        address[] calldata accounts,
        bool[] calldata isBlacklist
    ) external onlyOwner nonReentrant {
        require(accounts.length == isBlacklist.length, "Invalid parameters");
        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), "Invalid account");
            isBlacklisted[accounts[i]] = isBlacklist[i];
        }
        emit BlacklistAccounts(accounts, isBlacklist);
    }

    /**
     * @notice Enables or disables the buy limit restriction for the token.
     * @dev This function can only be called by the contract owner.
     *      It emits the `EnableOrDisableBuyLimit` event with the updated state.
     * @param isEnableBuyLimit A boolean indicating whether to enable (true) or disable (false) the buy limit.
     */
    function enableOrDisableBuyLimit(
        bool isEnableBuyLimit
    ) external onlyOwner nonReentrant {
        isBuyLimitEnabled = isEnableBuyLimit;
        emit EnableOrDisableBuyLimit(isEnableBuyLimit);
    }
    /**
     * @notice Updates the minimum and maximum buy limits for the token.
     * @dev This function can only be called by the contract owner.
     *      It emits the `UpdateBuyLimit` event with the new limits.
     * @param minBuyLimit The new minimum buy limit (in tokens).
     * @param maxBuyLimit The new maximum buy limit (in tokens).
     */
    function updateBuyLimit(
        uint256 minBuyLimit,
        uint256 maxBuyLimit
    ) external onlyOwner nonReentrant {
        minimumBuyLimit = minBuyLimit;
        maximumBuyLimit = maxBuyLimit;
        emit UpdateBuyLimit(minBuyLimit, maxBuyLimit);
    }
}
