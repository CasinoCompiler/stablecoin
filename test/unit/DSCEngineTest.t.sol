// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "@forge/src/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@oz/contracts/mocks/token/ERC20Mock.sol";
import {MockFailingTransferERC20} from "../../src/MockFailingTransferERC20.sol";

contract DSCEngineTest is Test {
    DeployDSC deployDSC;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    MockFailingTransferERC20 failingErc20;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    uint256 constant MINT_AMOUNT = 100;
    uint256 constant BURN_AMOUNT = 20;
    uint256 constant GAS_MONEY = 1 ether;
    uint256 constant AMOUNT_OF_COLLATERAL = 1 ether;
    uint256 constant SECOND_AMOUNT_OF_COLLATERAL = 1 ether;
    uint256 constant BROKEN_AMOUNT_OF_COLLATERAL = 0.09 ether;

    HelperConfig.Token weth;
    HelperConfig.Token wbtc;
    HelperConfig.Token wfail;

    modifier isNotAnvil() {
        if (!config.is_anvil()) {
            return;
        }
        _;
    }

    function setUp() public {
        deployDSC = new DeployDSC();
        (dsc, dscEngine, failingErc20, config) = deployDSC.run();
        (weth, wbtc, wfail) = config.activeNetworkConfig();
    }

    /*//////////////////////////////////////////////////////////////
                                  INIT
    //////////////////////////////////////////////////////////////*/

    function test_dscContractOwner() public view {
        console.log("Owner:", address(dscEngine));

        assertEq(address(dscEngine), dsc.getOwner());
    }

    function test_MockEthAndMockBtcMintedToAddress() public view isNotAnvil {
        //Eth
        assert(ERC20Mock(weth.tokenAddress).balanceOf(bob) == 20e18);
        //btc
        assert(ERC20Mock(wbtc.tokenAddress).balanceOf(bob) == 10e18);
    }

    address[] t_collateralTokenAddresses;
    address[] t_collateralPricefeeds;

    function test_DoesNotInitIfPricefeedDataNotCollecedtedCorrectly() public {
        t_collateralTokenAddresses.push(weth.tokenAddress);
        t_collateralTokenAddresses.push(wbtc.tokenAddress);
        t_collateralPricefeeds.push(weth.pricefeedAddress);

        vm.expectRevert(DSCEngine.DSCEngine__PricefeedCollectionError.selector);
        new DSCEngine(t_collateralTokenAddresses, t_collateralPricefeeds, address(dsc));
    }

    /*//////////////////////////////////////////////////////////////
                             DSC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    event TokensMinted(address indexed to, uint256 indexed amount);
    event TokensBurned(address indexed from, uint256 indexed amount);

    modifier mintDSCToAccount(address _to, uint256 _amount) {
        hoax(address(dscEngine), GAS_MONEY);
        dsc.mint(_to, _amount);
        _;
    }

    function test_invalidMintAmountReverts() public {
        vm.prank(address(dscEngine));
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustMintMoreThanZero.selector);
        dsc.mint(bob, 0);
    }

    function test_CanMintDSC() public mintDSCToAccount(bob, MINT_AMOUNT) {
        assert(dsc.balanceOf(bob) == 100);
    }

    function test_mintEmitsEvent() public {
        vm.prank(address(dscEngine));
        vm.expectEmit(true, true, false, false, address(dsc));
        emit TokensMinted(bob, MINT_AMOUNT);
        dsc.mint(bob, MINT_AMOUNT);
    }

    function test_BurnErrorsOndBurningZero() public mintDSCToAccount(address(dscEngine), MINT_AMOUNT) {
        vm.prank(address(dscEngine));
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBurnMoreThanZero.selector);
        dsc.burn(0);
    }

    function test_BurnErrorsOndBurningMoreThanBalance() public mintDSCToAccount(address(dscEngine), MINT_AMOUNT) {
        vm.prank(address(dscEngine));
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountGreaterThanUserBalance.selector);
        dsc.burn(101);
    }

    function test_CanBurnDSC() public mintDSCToAccount(address(dscEngine), MINT_AMOUNT) {
        hoax(address(dscEngine), GAS_MONEY);
        dsc.burn(20);

        assert(dsc.balanceOf(address(dscEngine)) == 80);
    }

    function test_BurnEmitsEvent() public mintDSCToAccount(address(dscEngine), MINT_AMOUNT) {
        vm.prank(address(dscEngine));
        vm.expectEmit(true, true, false, false, address(dsc));
        emit TokensBurned(address(dscEngine), BURN_AMOUNT);
        dsc.burn(BURN_AMOUNT);

        assert(dsc.balanceOf(address(dscEngine)) == 80);
    }

    /**
     * @dev will implement later.
     */
    function test_CanRecoverERC() public {}

    /*//////////////////////////////////////////////////////////////
                               PRICEFEED
    //////////////////////////////////////////////////////////////*/

    function test_GetUsdValue() public view {
        uint256 ethAmount = 10e18;
        // 10e18 * $2000 == 20000e18
        uint256 expectedValue =
            (((uint256(dscEngine.getLatestRoundDataValue(weth.tokenAddress)) * 1e10) * ethAmount)) / 1e18;

        uint256 actualValue = dscEngine.getUsdValue(weth.tokenAddress, ethAmount);

        assertEq(expectedValue, actualValue);
    }

    function test_GetTokenAmountFromUsd() public view {
        uint256 usdAmount = MINT_AMOUNT;
        uint256 expectedWeth;
        uint256 actualWeth;
        if (config.is_anvil()) {
            expectedWeth = 0.05e18;
        } else {
            expectedWeth = (((uint256((usdAmount * 1e8) / (dscEngine.getLatestRoundDataValue(weth.tokenAddress))))));
        }

        actualWeth = uint256(dscEngine.getTokenAmountFromUsd(weth.tokenAddress, usdAmount));

        assertEq(expectedWeth, actualWeth);
    }

    /*//////////////////////////////////////////////////////////////
                           DEPOSIT COLLATERAL
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(
        address indexed depositer, address indexed collateralTokenAddress, uint256 indexed collateralAmount
    );

    modifier bobEnterSystem() {
        vm.startPrank(bob);
        ERC20Mock(weth.tokenAddress).approve(address(dscEngine), AMOUNT_OF_COLLATERAL);
        dscEngine.depositCollateralAndMintDsc(weth.tokenAddress, AMOUNT_OF_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();
        _;
    }

    modifier bobDepositEth() {
        vm.startPrank(bob);
        ERC20Mock(weth.tokenAddress).approve(address(dscEngine), SECOND_AMOUNT_OF_COLLATERAL);
        dscEngine.depositCollateral(weth.tokenAddress, SECOND_AMOUNT_OF_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier bobDepositbtc() {
        vm.startPrank(bob);
        ERC20Mock(wbtc.tokenAddress).approve(address(dscEngine), SECOND_AMOUNT_OF_COLLATERAL);
        dscEngine.depositCollateral(wbtc.tokenAddress, SECOND_AMOUNT_OF_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function test_RevertsIfCollateralIsZero() public {
        vm.startPrank(bob);
        ERC20Mock(weth.tokenAddress).approve(address(dscEngine), AMOUNT_OF_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__MustSendCollateralGreaterThanZero.selector);
        dscEngine.depositCollateral(weth.tokenAddress, 0);
        vm.stopPrank();
    }

    function test_RevertsOnUnapprovedCollateral() public {
        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__CollateralTypeNotAllowed.selector);
        dscEngine.depositCollateral(address(0), 100);
    }

    function test_CantDepositCollateralIfNotAlreadyInSystem() public {
        vm.startPrank(bob);
        ERC20Mock(weth.tokenAddress).approve(address(dscEngine), AMOUNT_OF_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__UserNotInSystemAlready.selector);
        dscEngine.depositCollateral(weth.tokenAddress, AMOUNT_OF_COLLATERAL);
        vm.stopPrank();
    }

    function test_DepositAndMintDscFunctionworks() public {
        vm.startPrank(bob);
        ERC20Mock(weth.tokenAddress).approve(address(dscEngine), AMOUNT_OF_COLLATERAL);
        dscEngine.depositCollateralAndMintDsc(weth.tokenAddress, AMOUNT_OF_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();

        // Ensure they are in system
        assert(dscEngine.isUserInSystem(bob) == true);
        // Ensure s_dscMinted mapping is updated correctly
        (uint256 dscMinted,) = dscEngine.getAccountInformation(bob);
        assert(dscMinted == MINT_AMOUNT);
    }

    function test_DepositAndMintDscFunctionRevertsIfHealthFactorBroken() public {
        vm.startPrank(bob);
        ERC20Mock(weth.tokenAddress).approve(address(dscEngine), BROKEN_AMOUNT_OF_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        dscEngine.depositCollateralAndMintDsc(weth.tokenAddress, BROKEN_AMOUNT_OF_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();
    }

    function test_CanDepositCollateralAndEmitEvent() public isNotAnvil bobEnterSystem {
        vm.startPrank(bob);
        ERC20Mock(weth.tokenAddress).approve(address(dscEngine), AMOUNT_OF_COLLATERAL);
        vm.expectEmit(true, true, true, false, address(dscEngine));
        emit CollateralDeposited(bob, weth.tokenAddress, AMOUNT_OF_COLLATERAL);
        dscEngine.depositCollateral(weth.tokenAddress, AMOUNT_OF_COLLATERAL);
        vm.stopPrank();
    }

    function test_DepositCollateralUpdatesInformationAsExpected() public isNotAnvil bobEnterSystem bobDepositEth {
        // Expected is 100 as Bob is in system but mo dsc minted when depositCollateral() called.
        uint256 expectedDscMinted = MINT_AMOUNT;
        uint256 totalDscMinted;
        uint256 expectedCollateralValueInUsd =
            (dscEngine.getUsdValue(weth.tokenAddress, AMOUNT_OF_COLLATERAL + SECOND_AMOUNT_OF_COLLATERAL));
        uint256 collateralValueInUsd;
        uint256 expectedAmountOfCollateral = AMOUNT_OF_COLLATERAL + SECOND_AMOUNT_OF_COLLATERAL;
        uint256 amountOfCollateral = dscEngine.getAccountCollateralDeposited(bob, weth.tokenAddress);

        vm.prank(bob);
        (totalDscMinted, collateralValueInUsd) = dscEngine.getAccountInformation(bob);

        assertEq(totalDscMinted, expectedDscMinted);
        assertEq(expectedAmountOfCollateral, amountOfCollateral);
        assertEq(collateralValueInUsd, expectedCollateralValueInUsd);
    }

    function test_DepositingCollateralUpdatesHealthFactor() public bobEnterSystem bobDepositEth {
        uint256 bobExpectedHealthFactor = (
            dscEngine.getUsdValue(weth.tokenAddress, ((AMOUNT_OF_COLLATERAL + SECOND_AMOUNT_OF_COLLATERAL))) / 2
        ) / MINT_AMOUNT;

        uint256 bobActualHealthFactor = dscEngine.getHealthFactor(bob);

        assertEq(bobExpectedHealthFactor, bobActualHealthFactor);
    }

    /**
     * @dev Function to test DSCEngine__TransferFailed() but seems impossible to trigger such event.
     */

    // function test_RevertIfCollateralTransferFailed() public isNotAnvil {
    //     // Transfer would fail if not approval?
    //     vm.startPrank(bob);
    //     MockFailingTransferERC20(tokenAddresses[2]).approve(address(dscEngine), AMOUNT_OF_COLLATERAL);
    //     vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
    //     dscEngine.depositCollateral(tokenAddresses[2], AMOUNT_OF_COLLATERAL);
    //     vm.stopPrank();
    // }

    /*//////////////////////////////////////////////////////////////
                        MULTIPLE DEPOSIT TYPES
    //////////////////////////////////////////////////////////////*/

    function test_DepositEthAndBtc() public bobEnterSystem bobDepositbtc {
        uint256 wethExpected = AMOUNT_OF_COLLATERAL;
        uint256 wbtcExpected = AMOUNT_OF_COLLATERAL;
        uint256 wethDeposited = dscEngine.getAccountCollateralDeposited(bob, weth.tokenAddress);
        uint256 wbtcDeposited = dscEngine.getAccountCollateralDeposited(bob, wbtc.tokenAddress);

        assertEq(wethExpected, wethDeposited);
        assertEq(wbtcExpected, wbtcDeposited);
    }

    function test_MultipleDepositGivesRightHealthFactor() public bobEnterSystem bobDepositbtc {
        uint256 bobExpectedHealthFactor = (
            (
                dscEngine.getUsdValue(weth.tokenAddress, AMOUNT_OF_COLLATERAL)
                    + dscEngine.getUsdValue(wbtc.tokenAddress, AMOUNT_OF_COLLATERAL)
            ) / 2
        ) / MINT_AMOUNT;

        uint256 bobActualHealthFactor = dscEngine.getHealthFactor(bob);

        assertEq(bobExpectedHealthFactor, bobActualHealthFactor);
    }

    /*//////////////////////////////////////////////////////////////
                                MINTDSC
    //////////////////////////////////////////////////////////////*/

    function test_MintDscFailsOnBrokenHealthFactor() public isNotAnvil bobEnterSystem {}

    function test_MintDscExecutes() public isNotAnvil bobEnterSystem {}

    /*//////////////////////////////////////////////////////////////
                           REDEEM COLLATERAL
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                BURNDSC
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                               LIQUIDATE
    //////////////////////////////////////////////////////////////*/
}
