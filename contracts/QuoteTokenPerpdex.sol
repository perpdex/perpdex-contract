// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
import { VirtualTokenPerpdex } from "./VirtualTokenPerpdex.sol";

contract QuoteTokenPerpdex is VirtualTokenPerpdex {
    constructor(string memory name, string memory symbol) VirtualTokenPerpdex(name, symbol) {}
}
