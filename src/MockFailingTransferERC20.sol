// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockFailingTransferERC20 is ERC20 {
    bool public failTransfer;

    constructor() ERC20("MockToken", "MTK") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function setFailTransfer(bool _fail) external {
        failTransfer = _fail;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        if (failTransfer) {
            return false;
        }
        return super.transferFrom(sender, recipient, amount);
    }
}
