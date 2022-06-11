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

    function setPriceLimitInfo(MarketStructs.PriceLimitInfo memory value) external {
        priceLimitInfo = value;
    }

    function setPriceLimitConfig(MarketStructs.PriceLimitConfig memory value) external {
        priceLimitConfig = value;
    }
}
