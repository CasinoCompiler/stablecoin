// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @dev Interface of the DSCEngine as defined in DSCEngine.sol.
 */
interface IDSCEngine {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Emitted when depositCollateral() function is called.
     * @param depositer                 address that called function
     * @param collateralTokenAddress    address of collateral type deposited
     * @param collateralAmount          amount of collateral deposited
     */
    event CollateralDeposited(
        address indexed depositer, address indexed collateralTokenAddress, uint256 indexed collateralAmount
    );
    /**
     * @dev Emitted when redeemCollateral() is called.
     * @param redeemee                  Address that redeemed collateral
     * @param collateralTokenAddress    token addres of the collateral that was redeemed
     * @param amountOfCollateral        amount that was was redeemed
     */
    event CollateralRedemeed(
        address indexed redeemee, address indexed collateralTokenAddress, uint256 indexed amountOfCollateral
    );

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *
     * @param collateralTokenAddress    Token address of the collateral
     * @param collateralAmount          Amount of collateral wished to be deposited
     * @param dscToMint                 Amount of DSC wished to be minted
     * @notice  Allows user to deposit collateral and mint dsc in one transaction.
     *          Implements depositCollateral() and mintDsc() functions.
     */
    function depositCollateralAndMintDsc(address collateralTokenAddress, uint256 collateralAmount, uint256 dscToMint)
        external;

    /**
     *
     * @param collateralTokenAddress    The address of the token that is being used as collateral
     * @param collateralAmount          Amount of collateral
     */
    function depositCollateral(address collateralTokenAddress, uint256 collateralAmount) external;


    /**
     * @dev function to mintDSC.
     * IMPORTANT * Must make sure health factor is in tact after minting DSC.
     * 
     * @param amountOfDscToMint Amount of dsc to be minted
     */
    function mintDsc(uint256 amountOfDscToMint) external;

    function redeemCollateralForDsc(address collateralTokenAddress, uint256 amountOfCollateral, uint256 amountOfDsc)
        external;

    function redeemCollateral(address collateralTokenAddress, uint256 amountOfcollateral) external;

    function burnDsc(uint256 amount) external;

    /**
     *
     * @param collateralTokenAddress    Token address of the collateral
     * @param userToLiquidate           Address of user with health < min health factor
     * @param dscToCover                DSC position minted by userToLiquidate, this DSC will be covered by 3rd party
     *                                  to redeem userToLiquidate's collateral
     */
    function liquidate(address collateralTokenAddress, address userToLiquidate, uint256 dscToCover) external;

    function getHealthFactor() external;
}
