// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "@forge/src/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@oz/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployDSC;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig config;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    uint256 constant MINT_AMOUNT = 100;
    uint256 constant BURN_AMOUNT = 20;
    uint256 constant GAS_MONEY = 1 ether;
    uint256 constant AMOUNT_OF_COLLATERAL = 10 ether;

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    HelperConfig.Token weth;
    HelperConfig.Token wbtc;

    function setUp() public {
        deployDSC = new DeployDSC();
        (dsc, dscEngine, config) = deployDSC.run();
        (weth, wbtc) = config.activeNetworkConfig();

        tokenAddresses = [weth.tokenAddress, wbtc.tokenAddress];
        priceFeedAddresses = [weth.pricefeedAddress, wbtc.pricefeedAddress];
    }

    /*//////////////////////////////////////////////////////////////
                                  INIT
    //////////////////////////////////////////////////////////////*/

    function test_dscContractOwner() public view {
        console.log("Owner:", address(dscEngine));

        assertEq(address(dscEngine), dsc.getOwner());
    }

    function test_MockEthAndMockBtcMintedToAddress() public view {
        if (!config.is_anvil()) {
            return;
        }
        //Eth
        assert(ERC20Mock(tokenAddresses[0]).balanceOf(bob) == 20);
        //btc
        assert(ERC20Mock(tokenAddresses[1]).balanceOf(bob) == 10);
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

    // Will implement later
    function test_CanRecoverERC() public {}

    /*//////////////////////////////////////////////////////////////
                               PRICEFEED
    //////////////////////////////////////////////////////////////*/

    function test_GetUsdValue() public view {
        uint256 ethAmount = 10e18;
        // 10e18 * $2000 == 20000e18
        uint256 expectedValue =
            (((uint256(dscEngine.getLatestRoundDataValue(tokenAddresses[0])) * 1e10) * ethAmount)) / 1e18;

        uint256 actualValue = dscEngine.getUsdValue(tokenAddresses[0], ethAmount);

        assertEq(expectedValue, actualValue);
    }

    function test_GetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100e18;
        uint256 expectedWeth;
        uint256 actualWeth;
        if (config.is_anvil()) {
            expectedWeth = 0.05e18;
        } else {
            expectedWeth = (((uint256((usdAmount * 1e8) / (dscEngine.getLatestRoundDataValue(tokenAddresses[0]))))));
        }

        actualWeth = uint256(dscEngine.getTokenAmountFromUsd(weth.tokenAddress, usdAmount));

        assertEq(expectedWeth, actualWeth);
    }

    /*//////////////////////////////////////////////////////////////
                           DEPOSIT COLLATERAL
    //////////////////////////////////////////////////////////////*/

    function test_RevertsIfCollateralIsZero() public {
        vm.startPrank(bob);
        ERC20Mock(tokenAddresses[0]).approve(address(dscEngine), AMOUNT_OF_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__MustSendCollateralGreaterThanZero.selector);
        dscEngine.depositCollateral(tokenAddresses[0], 0);
        vm.stopPrank();
    }
}
