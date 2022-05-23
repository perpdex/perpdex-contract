// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { VirtualTokenPerpdex } from "./VirtualTokenPerpdex.sol";
import { IBaseTokenNew } from "./interface/IBaseTokenNew.sol";

contract BaseTokenPerpdex is IBaseTokenNew, VirtualTokenPerpdex {
    constructor(
        string memory name,
        string memory symbol,
        address recipient
    ) VirtualTokenPerpdex(name, symbol, recipient) {}

    function shareToBalance(uint256 share) external view override returns (uint256) {
        return share;
    }

    function balanceToShare(uint256 balance) external view override returns (uint256) {
        return balance;
    }
}
