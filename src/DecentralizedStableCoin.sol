// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title   Decentralized Stablecoin
 * @author  CC
 * @notice  This contract is the ERC20 implementation of the stable coin.
 *              |Relative Stability  :   Peg (USD)                   |
 *              |Minting             :   Algorithmic                 |
 *              |Collateral          :   Exogenous (wBTC && wETH)    |
 *
 *          The contract is governed by DSCEngine.
 *          The contract implements the OpenZeppelin Ownable Contract
 *          to ensure OnlyOwner can mint and burn tokens.
 * 
 *          WARNING:    Although contract is able to recover ERC20 tokens
 *                      DO NOT SEND ERC20 TOKENS TO THIS CONTRACT    
 */

/**
 * Imports
 */
import {ERC20Burnable, ERC20} from "@oz/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@oz/contracts/access/Ownable.sol";
import {IERC20} from "@oz/contracts/token/ERC20/IERC20.sol";
// @Order Imports, Interfaces, Libraries, Contracts

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    /**
     * Errors
     */
    error DecentralizedStableCoin__MustBurnMoreThanZero();
    error DecentralizedStableCoin__MustMintMoreThanZero();
    error DecentralizedStableCoin__BurnAmountGreaterThanUserBalance();
    error DecentralizedStableCoin__CannotRecoverFromStablecoinAddress();

    /**
     * Type Declarations
     */

    /**
     * State Variables
     */

    /**
     * Events
     */

    /**
     * Constructor
     */
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {}

    /**
     * Modifiers
     */

    /**
     * Functions
     */
    // @Order recieve, fallback, external, public, internal, private

    function mint(address _to, uint256 _amount) external Ownable.onlyOwner() returns (bool) {
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustMintMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }

    /**
     * @dev Overrides burn function from ERC20Burnable.
     *      Implements checks for the amount burned.
     *      Implements parent burn logic thereafter.
     */
    function burn(uint256 _amount) public override Ownable.onlyOwner() {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBurnMoreThanZero();
        }
        if (_amount > balance) {
            revert DecentralizedStableCoin__BurnAmountGreaterThanUserBalance();
        } else {
            super.burn(_amount);
        }
    }

    /**
     * @notice  Recovers ERC20 tokens sent to this contract by mistake
     *          Token to be sent to owner of stablecoin contract
     * @param   tokenAddress The address of the token to recover
     * @param   tokenAmount The amount of tokens to recover
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external Ownable.onlyOwner() {
        if (tokenAddress == address(this)) {
            revert DecentralizedStableCoin__CannotRecoverFromStablecoinAddress();
        }
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }

    /**
     * Getter Functions
     */
    function getOwner() public view returns (address) {
        return owner();
    }
}
