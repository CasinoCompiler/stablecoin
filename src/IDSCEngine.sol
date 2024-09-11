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
     * @param depositer address that called function
     * @param collateralTokenAddress address of collateral type deposited
     * @param collateralAmount amount of collateral deposited
     */
    event CollateralDeposited(
        address indexed depositer, address indexed collateralTokenAddress, uint256 indexed collateralAmount
    );

    event CollateralRedemeed(
        address indexed redeemee, address indexed collateralTokenAddress, uint256 indexed amountOfCollateral
    );

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositCollateralAndMintDsc(address collateralTokenAddress, uint256 collateralAmount, uint256 dscToMint)
        external;

    /**
     *
     * @param collateralTokenAddress The address of the token that is being used as collateral
     * @param collateralAmount Amount of collateral
     */
    function depositCollateral(address collateralTokenAddress, uint256 collateralAmount) external;

    function mintDsc(uint256 amountOfDscToMint) external;

    function redeemCollateralForDsc(address collateralTokenAddress, uint256 amountOfCollateral, uint256 amountOfDsc)
        external;

    function redeemCollateral(address collateralTokenAddress, uint256 amountOfcollateral) external;

    function burnDsc(uint256 amount) external;

    function liquidate() external;

    function getHealthFactor() external;
}
