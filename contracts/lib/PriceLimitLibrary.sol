// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { PerpMath } from "./PerpMath.sol";
import "./PerpdexStructs.sol";

// internal
library PriceLimitLibrary {
    using PerpMath for uint256;
    using SafeMath for uint256;

    function isNormalOrderAllowed(
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        PerpdexStructs.PriceLimitConfig memory config,
        uint256 price
    ) internal view returns (bool) {
        return _isWithinPriceLimit(priceLimitInfo.referencePrice, price, config.priceLimitNormalOrderRatio);
    }

    function isLiquidationAllowed(
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        PerpdexStructs.PriceLimitConfig memory config,
        uint256 price
    ) internal view returns (bool) {
        return _isWithinPriceLimit(priceLimitInfo.referencePrice, price, config.priceLimitLiquidationRatio);
    }

    // should call before all price changes
    function update(PerpdexStructs.PriceLimitInfo storage priceLimitInfo, uint256 price) internal {
        if (priceLimitInfo.referenceTimestamp < block.timestamp) {
            priceLimitInfo.referencePrice = price;
            priceLimitInfo.referenceTimestamp = block.timestamp;
        }
    }

    function _isWithinPriceLimit(
        uint256 referencePrice,
        uint256 price,
        uint24 priceLimitRatio
    ) private pure returns (bool) {
        uint256 maxChange = referencePrice.mulRatio(priceLimitRatio);
        uint256 upperBound = referencePrice.add(maxChange);
        uint256 lowerBound = referencePrice.sub(maxChange);
        return (lowerBound <= price && price <= upperBound);
    }
}
