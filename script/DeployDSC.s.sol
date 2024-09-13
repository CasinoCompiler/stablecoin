// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "@forge/src/Test.sol";
import {Script} from "@forge/src/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MockFailingTransferERC20} from "../src/MockFailingTransferERC20.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    MockFailingTransferERC20 failingERC20;

    function run() external returns (DecentralizedStableCoin, DSCEngine, MockFailingTransferERC20, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (HelperConfig.Token memory weth, HelperConfig.Token memory wbtc,  HelperConfig.Token memory wfail) = config.activeNetworkConfig();

        tokenAddresses = [weth.tokenAddress, wbtc.tokenAddress, wfail.tokenAddress];
        priceFeedAddresses = [weth.pricefeedAddress, wbtc.pricefeedAddress, wfail.pricefeedAddress];

        vm.startBroadcast();
        dsc = new DecentralizedStableCoin();
        dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));

        dsc.transferOwnership(address(dscEngine));

        vm.stopBroadcast();
        return (dsc, dscEngine, failingERC20,config);
    }
}
