// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { PriceLimitLibrary } from "../lib/PriceLimitLibrary.sol";
import { PerpdexStructs } from "../lib/PerpdexStructs.sol";

contract TestPriceLimitLibrary {
    constructor() {}

    PerpdexStructs.PriceLimitInfo public priceLimitInfo;

    function update(PerpdexStructs.PriceLimitInfo memory priceLimitInfoArg, uint256 price) external {
        priceLimitInfo = priceLimitInfoArg;
        PriceLimitLibrary.update(priceLimitInfo, price);
    }

    function isWithinPriceLimit(
        uint256 referencePrice,
        uint256 price,
        uint24 priceLimitRatio
    ) external pure returns (bool) {
        return PriceLimitLibrary.isWithinPriceLimit(referencePrice, price, priceLimitRatio);
    }
}
