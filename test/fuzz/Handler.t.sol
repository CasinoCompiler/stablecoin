// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "@forge/src/Test.sol";
import {StdInvariant} from "@forge/src/StdInvariant.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@oz/contracts/mocks/token/ERC20Mock.sol";
import {ERC20Burnable, ERC20} from "@oz/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {MockFailingTransferERC20} from "../../src/MockFailingTransferERC20.sol";
import {MockV3Aggregator} from "../mocks/MockAggregatorV3Interface.sol";

contract Handler is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;
    ERC20Mock wfail;

    uint256 MAX_SIZE = type(uint96).max;
    

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dscEngine.getLisOfCollateralTokenAddress();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
        wfail = ERC20Mock(collateralTokens[2]);

    }

    function depositCollateralandDscMinted(uint256 collateralSeed, uint256 amountOfCollateral, uint256 amountOfDsc) public {

        ERC20Mock collateral = _getCollateralSeed(collateralSeed);
        console.log("collateral address;", address(collateral));
        amountOfCollateral = bound(amountOfCollateral, 1, MAX_SIZE);
        console.log("Amount of collateral:", amountOfCollateral);
        uint256 MAX_DSC = dscEngine.getMaxDscForCollateral(address(collateral), amountOfCollateral);
        console.log("Max dsc: ", MAX_DSC);
        amountOfDsc = bound(amountOfDsc, 1, MAX_DSC);
        console.log("Amount of dsc: ", amountOfDsc);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountOfCollateral);
        collateral.approve(address(dscEngine), amountOfCollateral);
        dscEngine.depositCollateralAndMintDsc(address(collateral), amountOfCollateral, amountOfDsc);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountOfCollateral) public {
        ERC20Mock collateral = _getCollateralSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dscEngine.getAccountCollateralDeposited(msg.sender, address(collateral));
        amountOfCollateral = bound(amountOfCollateral, 0, maxCollateralToRedeem);
        if (amountOfCollateral == 0){
            return;
        }
        dscEngine.userRedeemCollateral(address(collateral), amountOfCollateral);
    }

    function _getCollateralSeed(uint256 collateralSeed) private view returns(ERC20Mock) {
        if (collateralSeed % 3 == 0) {
            return weth;
        }
        return wbtc;
    }
}