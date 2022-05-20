// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import "@uniswap/lib/contracts/libraries/FullMath.sol";
import "./PerpdexStructs.sol";

library PriceLimitLibrary {
    function isNormalOrderAllowed(
        PerpdexStructs.PriceLimitInfo memory priceLimitInfo,
        PerpdexStructs.PriceLimitConfig memory config,
        uint256 price
    ) public pure returns (bool) {
        return _isWithinPriceLimit(priceLimitInfo.referencePrice, price, config.priceLimitNormalOrderMicro);
    }

    function isLiquidationAllowed(
        PerpdexStructs.PriceLimitInfo memory priceLimitInfo,
        PerpdexStructs.PriceLimitConfig memory config,
        uint256 price
    ) public pure returns (bool) {
        return _isWithinPriceLimit(priceLimitInfo.referencePrice, price, config.priceLimitLiquidationMicro);
    }

    // should call before any price limit checks
    // You only have to call it once at the beginning within the same timestamp.
    function update(PerpdexStructs.PriceLimitInfo storage priceLimitInfo, uint256 price) public {
        if (priceLimitInfo.referenceTimestamp < block.timestamp) {
            priceLimitInfo.referencePrice = price;
            priceLimitInfo.referenceTimestamp = block.timestamp;
        }
    }

    function _isWithinPriceLimit(
        uint256 referencePrice,
        uint256 price,
        uint256 priceLimitMicro
    ) internal view returns (bool) {
        uint256 maxChange = FullMath.mulDiv(referencePrice, priceLimitMicro, 1e6);
        uint256 upperBound = referencePrice.add(maxChange);
        uint256 lowerBound = referencePrice.sub(maxChange);
        return (lowerBound <= price && price <= upperBound);
    }
}
