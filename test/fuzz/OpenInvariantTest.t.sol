// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// What should the invariants be?
// 1. Amount of DSC < amount of collateral
// 2. Getter view functions should never revert <- evergreen invarient 

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

contract OpenInvariantsTest is StdInvariant, Test {
    DeployDSC deployDSC;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    MockFailingTransferERC20 failingErc20;
    HelperConfig.Token weth;
    HelperConfig.Token wbtc;
    HelperConfig.Token wfail;

    function setUp() public {
        deployDSC = new DeployDSC();
        (dsc, dscEngine, failingErc20, config) = deployDSC.run();
        (weth, wbtc, wfail) = config.activeNetworkConfig();
        targetContract(address(dscEngine));
    }

    function openInvarient_ProtocolMustHaveMoreCollateralThanDscMinted() public view {
        uint256 totalweth = ERC20Mock(weth.tokenAddress).balanceOf(address(dscEngine));
        uint256 totalwbtc = ERC20Mock(wbtc.tokenAddress).balanceOf(address(dscEngine));
        uint256 totalDscMint = ERC20(address(dsc)).totalSupply();

        assert(totalDscMint <= (dscEngine.getUsdValue(weth.tokenAddress, totalweth) + dscEngine.getUsdValue(wbtc.tokenAddress, totalwbtc)));
    }
}