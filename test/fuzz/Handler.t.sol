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

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dscEngine.getLisOfCollateralTokenAddress();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

    }

    function depositCollateral(uint256 collateralSeed, uint256 amountOfCollateral) public {
        ERC20Mock collateral = _getCollateralSeed(collateralSeed);
        dscEngine.depositCollateral(address(collateral), amountOfCollateral);
    }

    function _getCollateralSeed(uint256 collateralSeed) private view returns(ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}