// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { PerpdexExchange } from "../PerpdexExchange.sol";
import { PerpdexStructs } from "../lib/PerpdexStructs.sol";

contract TestPerpdexExchange is PerpdexExchange {
    constructor(address settlementTokenArg) PerpdexExchange(settlementTokenArg) {}
}
