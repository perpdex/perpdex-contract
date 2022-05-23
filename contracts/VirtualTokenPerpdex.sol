// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IVirtualToken } from "./interface/IVirtualToken.sol";

contract VirtualTokenPerpdex is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        address recipient
    ) public ERC20(name, symbol) {
        _mint(recipient, type(uint256).max);
    }
}
