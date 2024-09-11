// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "@forge/src/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";

contract DSCEngineTest is Test {
    DeployDSC deployDSC;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    uint256 constant GAS_MONEY = 1 ether;

    function setUp() public {
        deployDSC = new DeployDSC();
        (dsc, dscEngine) = deployDSC.run();
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

    function test_CanMintDSC() public mintDSCToAccount(bob, 100){
        assert(dsc.balanceOf(bob) == 100);
    }

    function test_BurnErrorsOndBurningZero() public mintDSCToAccount(address(dscEngine), 100){
        vm.prank(address(dscEngine));
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBurnMoreThanZero.selector);
        dsc.burn(0);
    }

    function test_BurnErrorsOndBurningMoreThanBalance() public mintDSCToAccount(address(dscEngine), 100){
        vm.prank(address(dscEngine));
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountGreaterThanUserBalance.selector);
        dsc.burn(101);
    }

    function test_CanBurnDSC() public mintDSCToAccount(address(dscEngine), 100){
        hoax(address(dscEngine), GAS_MONEY); 
        dsc.burn(20);

        assert(dsc.balanceOf(address(dscEngine)) == 80);
    }
    // Will implement later
    function test_CanRecoverERC() public{}

    /*//////////////////////////////////////////////////////////////
                               PRICEFEED
    //////////////////////////////////////////////////////////////*/

}
