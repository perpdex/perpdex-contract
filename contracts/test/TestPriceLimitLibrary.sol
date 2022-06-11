// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { PriceLimitLibrary } from "../lib/PriceLimitLibrary.sol";
import { MarketStructs } from "../lib/MarketStructs.sol";

contract TestPriceLimitLibrary {
    constructor() {}

    MarketStructs.PriceLimitInfo public priceLimitInfo;
    MarketStructs.PriceLimitConfig public priceLimitConfig;

    function updateDry(uint256 price) external view returns (MarketStructs.PriceLimitInfo memory) {
        return PriceLimitLibrary.updateDry(priceLimitInfo, priceLimitConfig, price);
    }

    function priceBound(
        uint256 referencePrice,
        uint256 emaPrice,
        bool isLiquidation,
        bool isUpperBound
    ) external view returns (uint256 price) {
        return PriceLimitLibrary.priceBound(referencePrice, emaPrice, priceLimitConfig, isLiquidation, isUpperBound);
    }

    function setPriceLimitInfo(MarketStructs.PriceLimitInfo memory value) external {
        priceLimitInfo = value;
    }

    function setPriceLimitConfig(MarketStructs.PriceLimitConfig memory value) external {
        priceLimitConfig = value;
    }
}
