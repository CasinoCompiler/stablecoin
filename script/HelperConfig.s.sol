// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "@forge/src/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {MockV3Aggregator} from "../test/mocks/MockAggregatorV3Interface.sol";
import {ERC20Mock} from "@oz/contracts/mocks/token/ERC20Mock.sol";

// 1. Deploy mocks when we are on a local anvil network
// 2. Keep track of contract addresses across different chains

// If we are on a local anvil chain, deploy mock
// Otherwise, grab existing address fom the live network
contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        Token weth;
        Token wbtc;
    }

    struct Token {
        address tokenAddress;
        address pricefeedAddress;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            weth: Token({
                tokenAddress: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
                pricefeedAddress: 0x694AA1769357215DE4FAC081bf1f309aDC325306
            }),
            wbtc: Token({
                tokenAddress: 0x669d5DbF0f69e994aEbE5875556aA2ADFd449BFA,
                pricefeedAddress: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
            })
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        NetworkConfig memory anvilConfig;

        // Ensure an anvil mock address hasn't already been deployed. if it has, return existing config.
        if (activeNetworkConfig.weth.pricefeedAddress != address(0)) {
            return anvilConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator mockEthPricefeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        MockV3Aggregator mockBtcPricefeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock mockEthToken = new ERC20Mock();
        ERC20Mock mockBtcToken = new ERC20Mock();

        // Mint mockETH and mockBTC to accounts for testing on anvil
        mockEthToken.mint(bob, 20);
        mockBtcToken.mint(bob, 10);
        mockEthToken.mint(alice, 20);
        mockBtcToken.mint(alice, 10);

        vm.stopBroadcast();

        anvilConfig = NetworkConfig({
            weth: Token({tokenAddress: address(mockEthToken), pricefeedAddress: address(mockEthPricefeed)}),
            wbtc: Token({tokenAddress: address(mockBtcToken), pricefeedAddress: address(mockBtcPricefeed)})
        });

        return anvilConfig;
    }
}
