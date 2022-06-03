// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { PerpdexMarket } from "../PerpdexMarket.sol";

contract TestPerpdexMarket is PerpdexMarket {
    constructor(
        string memory symbolArg,
        address exchangeArg,
        address priceFeedBaseArg,
        address priceFeedQuoteArg
    ) PerpdexMarket(symbolArg, exchangeArg, priceFeedBaseArg, priceFeedQuoteArg) {}

    function processFunding() external {
        _processFunding();
    }
}
