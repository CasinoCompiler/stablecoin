// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title   DSCEngine
 * @author  CC
 * @dev     Implementation of the {IDSCEngine} interface.
 *          Function explanation wihtin interface
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * - It is an overcollateralised system, users must have 2:1 :: collateral:DSC
 *      =>  Users are incentivised to maintain overcollateralisation by being able to liquidate any actor whose is no
 *          longer above the threshold.
 *      =>  The system would fail if if the protocol were to fall heavily under collateralisation i.e. no incentive
 *          for third party to cover the debt for sosmeone else.
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice  This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 *          for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice  This contract is based on the MakerDAO DSS system
 */

/**
 * Imports
 */
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@oz/contracts/utils/ReentrancyGuard.sol";
import {IDSCEngine} from "./IDSCEngine.sol";
import {IERC20} from "@oz/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
// @Order Imports, Interfaces, Libraries, Contracts

contract DSCEngine is ReentrancyGuard, IDSCEngine {
    /**
     * Errors
     */
    error DSCEngine__MustSendCollateralGreaterThanZero();
    error DSCEngine__CollateralTypeNotAllowed();
    error DSCEngine__PricefeedCollectionError();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor();
    error DSCEngine__MintDscFailed();
    error DSCEngine__BurnAmountGreaterThanDebtorMinted();
    error DSCEngine__HealthFactorIsAboveThreshold();
    error DSCEngine__HealthFactorNotImproved();
    error DSCEngine__UserNotInSystemAlready();
    error DSCEngine__InsufficientDscDebt();

    /**
     * State Variables
     */
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATOR_BONUS = 10;

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATOR_PRECISION = 100;

    mapping(address => bool) private s_allowedCollateral;
    mapping(address token => address pricefeed) private s_pricefeeds;
    mapping(address user => mapping(address collateral => uint256 amountOfCollateral)) private
        s_userToCollateralDeposited;
    mapping(address user => uint256 amountOfDscToMint) private s_dscMinted;
    mapping(address user => bool inSystem) private s_userInSystem;

    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    /**
     *
     * Constructor
     *
     * @param collateralTokenAddresses  array of the collateral token addresses
     * @param collateralPricefeeds      array of Chainlink pricefeed addresses in USD
     * @param dscTokenAddress           address of deployed decentralised stablecoin
     */
    constructor(
        address[] memory collateralTokenAddresses,
        address[] memory collateralPricefeeds,
        address dscTokenAddress
    ) {
        if (collateralTokenAddresses.length != collateralPricefeeds.length) {
            revert DSCEngine__PricefeedCollectionError();
        }
        uint256 i = 0;
        for (i; i < collateralTokenAddresses.length; i++) {
            s_pricefeeds[collateralTokenAddresses[i]] = collateralPricefeeds[i];
            s_allowedCollateral[collateralTokenAddresses[i]] = true;
            s_collateralTokens.push(collateralTokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscTokenAddress);
    }
    /**
     * Modifiers
     */

    /**
     * @dev Modifier to ensure 0 collateral is not sent by msg.sender.
     * @param _collateralAmount Amount of collateral, matches keyword arg from msg.sender.
     */
    modifier validAmount(uint256 _collateralAmount) {
        if (_collateralAmount == 0) {
            revert DSCEngine__MustSendCollateralGreaterThanZero();
        }
        _;
    }

    /**
     * @dev Modifier to ensure the collateral being sent is of allowed type.
     * @param _collateralTokenAddress Token address of collateral address, matches keyword arg from msg.sender.
     */
    modifier allowedCollateral(address _collateralTokenAddress) {
        if (s_pricefeeds[_collateralTokenAddress] == address(0)) {
            revert DSCEngine__CollateralTypeNotAllowed();
        }
        _;
    }

    /**
     * @dev Modifier to ensure the user already has a health factor and is in the system i.e. has some DSC minted therefore not dividing by zero.
     * @param _user Token address of collateral address, matches keyword arg from msg.sender.
     */
    modifier alreadyInSystem(address _user) {
        if (!isUserInSystem(_user)) {
            revert DSCEngine__UserNotInSystemAlready();
        }
        _;
    }

    /**
     * Functions
     */
    // @Order recieve, fallback, external, public, internal, private

    function depositCollateralAndMintDsc(address collateralTokenAddress, uint256 collateralAmount, uint256 dscToMint)
        public
    {
        s_userInSystem[msg.sender] = true;
        depositCollateral(collateralTokenAddress, collateralAmount);
        mintDsc(dscToMint);
    }

    function depositCollateral(address collateralTokenAddress, uint256 collateralAmount)
        public
        validAmount(collateralAmount)
        allowedCollateral(collateralTokenAddress)
        alreadyInSystem(msg.sender)
        nonReentrant
    {
        s_userToCollateralDeposited[msg.sender][collateralTokenAddress] += collateralAmount;
        emit CollateralDeposited(msg.sender, collateralTokenAddress, collateralAmount);

        bool success = IERC20(collateralTokenAddress).transferFrom(msg.sender, address(this), collateralAmount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function mintDsc(uint256 amountOfDscToMint)
        public
        validAmount(amountOfDscToMint)
        alreadyInSystem(msg.sender)
        nonReentrant
    {
        s_dscMinted[msg.sender] += amountOfDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountOfDscToMint);
        if (!minted) {
            revert DSCEngine__MintDscFailed();
        }
    }

    function userRedeemCollateralForDsc(address collateralTokenAddress, uint256 amountOfCollateral, uint256 amountOfDsc)
        public
    {
        _redeemCollateral(collateralTokenAddress, amountOfCollateral, msg.sender, msg.sender);
        _burnDSC(amountOfDsc, msg.sender, msg.sender);
    }

    function redeemCollateralForEqualDsc(address collateralTokenAddress, uint256 amountOfdsc) public {
        uint256 collateralToRedeem = getTokenAmountFromUsd(collateralTokenAddress, amountOfdsc);
        userRedeemCollateralForDsc(collateralTokenAddress, collateralToRedeem, amountOfdsc);
    }

    function userRedeemCollateral(address collateralTokenAddress, uint256 amountOfCollateral) public {
        _redeemCollateral(collateralTokenAddress, amountOfCollateral, msg.sender, msg.sender);
    }

    function userExitSystem() public alreadyInSystem(msg.sender) {
        // Check health factor is okay

        // Yes? withdraw all collateral and burn dsc
        // No? revert DSCEngine__UserNotHealthy()
        // set userInSystem to false

        _revertIfHealthFactorIsBroken(msg.sender);
        uint256 dscTotalDebt = s_dscMinted[msg.sender];
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address collateralTokenAddress = s_collateralTokens[i];
            uint256 amountOfCollateral = s_userToCollateralDeposited[msg.sender][collateralTokenAddress];
            bool success = IERC20(collateralTokenAddress).transfer(msg.sender, amountOfCollateral);
            if (!success) {
                revert DSCEngine__TransferFailed();
            }
            s_userToCollateralDeposited[msg.sender][collateralTokenAddress] -= amountOfCollateral;
        }
        _burnDSC(dscTotalDebt, msg.sender, msg.sender);
        s_userInSystem[msg.sender] = false;
    }

    function liquidate(address collateralTokenAddress, address userToLiquidate, uint256 dscToCover)
        external
        validAmount(dscToCover)
        nonReentrant
    {
        uint256 startingHealthFactor = getHealthFactor(userToLiquidate);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsAboveThreshold();
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateralTokenAddress, dscToCover);
        uint256 bonus = (tokenAmountFromDebtCovered * LIQUIDATOR_BONUS) / LIQUIDATOR_PRECISION;
        uint256 total = tokenAmountFromDebtCovered + bonus;
        _redeemCollateral(collateralTokenAddress, total, userToLiquidate, msg.sender);
        _burnDSC(dscToCover, msg.sender, userToLiquidate);

        uint256 endingHealthFactor = getHealthFactor(userToLiquidate);
        if (endingHealthFactor < startingHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice  Purpose :- Check health factor (Do they have enough collateral - revert if they do not
     * @param   user Address of user to check
     */
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = getHealthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor();
        }
    }

    function _redeemCollateral(address collateralTokenAddress, uint256 amountOfCollateral, address _from, address _to)
        private
        validAmount(amountOfCollateral)
        nonReentrant
    {
        s_userToCollateralDeposited[_from][collateralTokenAddress] -= amountOfCollateral;
        emit CollateralRedemeed(_from, _to, collateralTokenAddress, amountOfCollateral);
        bool success = IERC20(collateralTokenAddress).transfer(_to, amountOfCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(_from);
    }

    function _burnDSC(uint256 _amount, address _dscDebtPayee, address _debtor) private validAmount(_amount) {
        if (_amount > s_dscMinted[_debtor]) {
            revert DSCEngine__BurnAmountGreaterThanDebtorMinted();
        }
        s_dscMinted[_debtor] -= _amount;
        bool success = i_dsc.transferFrom(_dscDebtPayee, address(this), _amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(_amount);
    }

    /**
     * Getter Functions
     */
    function isCollateralAllowed(address collateralTokenAddress) public view returns (bool) {
        return s_allowedCollateral[collateralTokenAddress];
    }

    function getMinHealthFactor() public pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function isUserInSystem(address user) public view returns (bool) {
        return s_userInSystem[user];
    }

    function decimals() public pure returns (uint256) {
        return 18;
    }

    /**
     * @notice  Returns the health factor; if < 1, user can get liquidated
     * @param   user Address of user
     */
    function getHealthFactor(address user) public view returns (uint256 healthFactor) {
        (uint256 totalDsc, uint256 collateralValue) = getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValue * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        healthFactor = collateralAdjustedForThreshold / totalDsc;
        return healthFactor;
    }

    function getAccountInformation(address user)
        public
        view
        returns (uint256 totalDscMinted, uint256 totalCollateralValueInUsd)
    {
        totalDscMinted = s_dscMinted[user];
        totalCollateralValueInUsd = getAccountCollateralValue(user);
        return (totalDscMinted, totalCollateralValueInUsd);
    }

    function getAccountCollateralDeposited(address user, address collateralTokenAddress)
        public
        view
        returns (uint256 collateralDeposited)
    {
        return s_userToCollateralDeposited[user][collateralTokenAddress];
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address collateralTokenAddress = s_collateralTokens[i];
            uint256 amountOfCollateral = s_userToCollateralDeposited[user][collateralTokenAddress];
            uint256 collateralValueUsd = getUsdValue(collateralTokenAddress, amountOfCollateral);
            totalCollateralValueUsd += collateralValueUsd;
        }
        return totalCollateralValueUsd;
    }

    function getUsdValue(address collateralTokenAddress, uint256 collateralAmount)
        public
        view
        returns (uint256 collateralValueInUsd)
    {
        AggregatorV3Interface pricefeed = AggregatorV3Interface(s_pricefeeds[collateralTokenAddress]);
        (, int256 answer,,,) = pricefeed.latestRoundData();
        collateralValueInUsd += ((uint256(answer) * ADDITIONAL_FEED_PRECISION) * collateralAmount) / PRECISION;
        return collateralValueInUsd;
    }

    function getLatestRoundDataValue(address collateralTokenAddress) public view returns (uint256) {
        AggregatorV3Interface pricefeed = AggregatorV3Interface(s_pricefeeds[collateralTokenAddress]);
        (, int256 answer,,,) = pricefeed.latestRoundData();
        return uint256(answer);
    }

    function getTokenAmountFromUsd(address tokenAddress, uint256 dscAmount) public view returns (uint256) {
        uint256 price = getLatestRoundDataValue(tokenAddress);
        return ((dscAmount * 1e18) * PRECISION) / (price * ADDITIONAL_FEED_PRECISION);
    }
}
