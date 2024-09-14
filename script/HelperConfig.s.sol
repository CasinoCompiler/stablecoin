// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "@forge/src/Script.sol";
import {console} from "@forge/src/Test.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {MockV3Aggregator} from "../test/mocks/MockAggregatorV3Interface.sol";
import {ERC20Mock} from "@oz/contracts/mocks/token/ERC20Mock.sol";
import {MockFailingTransferERC20} from "../src/MockFailingTransferERC20.sol";

// 1. Deploy mocks when we are on a local anvil network
// 2. Keep track of contract addresses across different chains

// If we are on a local anvil chain, deploy mock
// Otherwise, grab existing address fom the live network
contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;
    bool public is_anvil;

    MockV3Aggregator public mockEthPricefeed;
    MockV3Aggregator public mockBtcPricefeed;

    struct NetworkConfig {
        Token weth;
        Token wbtc;
        Token wfail;
    }

    struct Token {
        address tokenAddress;
        address pricefeedAddress;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    int256 public constant FAILING_USD_PRICE = 1e8;
    uint256 public constant ERC20_PRECISION = 1e18;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    constructor() {
        if (block.chainid == 11155111) {
            (activeNetworkConfig, is_anvil) = getSepoliaConfig();
        } else {
            (activeNetworkConfig, is_anvil) = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory, bool) {
        return (
            NetworkConfig({
                weth: Token({
                    tokenAddress: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
                    pricefeedAddress: 0x694AA1769357215DE4FAC081bf1f309aDC325306
                }),
                wbtc: Token({
                    tokenAddress: 0x669d5DbF0f69e994aEbE5875556aA2ADFd449BFA,
                    pricefeedAddress: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
                }),
                // **IMPORTANT** token address and pricefeedaddress just duplicate of wbtc. wfail isn't a real deployed token.
                wfail: Token({
                    tokenAddress: 0x669d5DbF0f69e994aEbE5875556aA2ADFd449BFA,
                    pricefeedAddress: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
                })
            }),
            is_anvil
        );
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory, bool) {
        NetworkConfig memory anvilConfig;
        is_anvil = true;

        // Ensure an anvil mock address hasn't already been deployed. if it has, return existing config.
        if (activeNetworkConfig.weth.pricefeedAddress != address(0)) {
            return (anvilConfig, is_anvil);
        }

        vm.startBroadcast();
        mockEthPricefeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        mockBtcPricefeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        MockV3Aggregator mockFailingPricefeed = new MockV3Aggregator(DECIMALS, FAILING_USD_PRICE);
        ERC20Mock mockEthToken = new ERC20Mock();
        ERC20Mock mockBtcToken = new ERC20Mock();
        MockFailingTransferERC20 mockFailingToken = new MockFailingTransferERC20();

        // Mint mockETH and mockBTC to accounts for testing on anvil
        mockEthToken.mint(bob, 20 * ERC20_PRECISION);
        mockBtcToken.mint(bob, 10 * ERC20_PRECISION);
        mockEthToken.mint(alice, 20 * ERC20_PRECISION);
        mockBtcToken.mint(alice, 10 * ERC20_PRECISION);

        //Mint failing to bob
        mockFailingToken.mint(bob, 10 * ERC20_PRECISION);

        vm.stopBroadcast();

        anvilConfig = NetworkConfig({
            weth: Token({tokenAddress: address(mockEthToken), pricefeedAddress: address(mockEthPricefeed)}),
            wbtc: Token({tokenAddress: address(mockBtcToken), pricefeedAddress: address(mockBtcPricefeed)}),
            wfail: Token({tokenAddress: address(mockFailingToken), pricefeedAddress: address(mockFailingPricefeed)})
        });

        return (anvilConfig, is_anvil);
    }
}
