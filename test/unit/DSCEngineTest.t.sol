// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "@forge/src/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

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

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function setUp() public {
        deployDSC = new DeployDSC();
        (dsc, dscEngine, config) = deployDSC.run();
        (HelperConfig.Token memory weth, HelperConfig.Token memory wbtc) = config.activeNetworkConfig();

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

    function test__invalidMintAmountReverts() public {
        vm.prank(address(dscEngine));
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustMintMoreThanZero.selector);
        dsc.mint(bob, 0);
    }

    function test_CanMintDSC() public mintDSCToAccount(bob, MINT_AMOUNT){
        assert(dsc.balanceOf(bob) == 100);
    }

    function test_mintEmitsEvent() public{
        vm.prank(address(dscEngine));
        vm.expectEmit(true,true,false,false,address(dsc));
        emit TokensMinted(bob, MINT_AMOUNT);
        dsc.mint(bob, MINT_AMOUNT);
    }

    function test_BurnErrorsOndBurningZero() public mintDSCToAccount(address(dscEngine), MINT_AMOUNT){
        vm.prank(address(dscEngine));
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBurnMoreThanZero.selector);
        dsc.burn(0);
    }

    function test_BurnErrorsOndBurningMoreThanBalance() public mintDSCToAccount(address(dscEngine), MINT_AMOUNT){
        vm.prank(address(dscEngine));
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountGreaterThanUserBalance.selector);
        dsc.burn(101);
    }

    function test_CanBurnDSC() public mintDSCToAccount(address(dscEngine), MINT_AMOUNT){
        hoax(address(dscEngine), GAS_MONEY); 
        dsc.burn(20);

        assert(dsc.balanceOf(address(dscEngine)) == 80);
    }

    function test_BurnEmitsEvent() public mintDSCToAccount(address(dscEngine), MINT_AMOUNT){
        vm.prank(address(dscEngine));
        vm.expectEmit(true,true,false,false,address(dsc));
        emit TokensBurned(address(dscEngine), BURN_AMOUNT); 
        dsc.burn(BURN_AMOUNT);

        assert(dsc.balanceOf(address(dscEngine)) == 80);
    }

    // Will implement later
    function test_CanRecoverERC() public{}

    /*//////////////////////////////////////////////////////////////
                               PRICEFEED
    //////////////////////////////////////////////////////////////*/

    function test_GetUsdValue() public view {
        uint256 ethAmount = 10e18;
        // 10e18 * $2000 == 20000e18
        uint256 expectedValue = 20000e18;

        uint256 actualValue = dscEngine.getUsdValue(tokenAddresses[0], ethAmount);

        assertEq(expectedValue, actualValue);
    }

}
