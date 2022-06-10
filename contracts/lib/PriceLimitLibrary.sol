// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { Math } from "@openzeppelin/contracts/math/Math.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { PerpMath } from "./PerpMath.sol";
import { MarketStructs } from "./MarketStructs.sol";

library PriceLimitLibrary {
    using PerpMath for uint256;
    using SafeMath for uint256;

    function update(MarketStructs.PriceLimitInfo storage priceLimitInfo, MarketStructs.PriceLimitInfo memory value)
        internal
    {
        if (value.referenceTimestamp == 0) return;
        priceLimitInfo.referencePrice = value.referencePrice;
        priceLimitInfo.referenceTimestamp = value.referenceTimestamp;
        priceLimitInfo.emaPrice = value.emaPrice;
    }

    function maxPrice(
        uint256 referencePrice,
        uint256 emaPrice,
        MarketStructs.PriceLimitConfig storage config,
        bool isLiquidation
    ) internal view returns (uint256 price) {
        uint256 upperBound =
            referencePrice.add(
                referencePrice.mulRatio(isLiquidation ? config.liquidationRatio : config.normalOrderRatio)
            );
        uint256 upperBoundEma =
            emaPrice.add(emaPrice.mulRatio(isLiquidation ? config.emaLiquidationRatio : config.emaNormalOrderRatio));
        return Math.min(upperBound, upperBoundEma);
    }

    function minPrice(
        uint256 referencePrice,
        uint256 emaPrice,
        MarketStructs.PriceLimitConfig storage config,
        bool isLiquidation
    ) internal view returns (uint256 price) {
        uint256 lowerBound =
            referencePrice.sub(
                referencePrice.mulRatio(isLiquidation ? config.liquidationRatio : config.normalOrderRatio)
            );
        uint256 lowerBoundEma =
            emaPrice.sub(emaPrice.mulRatio(isLiquidation ? config.emaLiquidationRatio : config.emaNormalOrderRatio));
        return Math.max(lowerBound, lowerBoundEma);
    }

    // referenceTimestamp == 0 indicates not updated
    function updateDry(
        MarketStructs.PriceLimitInfo storage priceLimitInfo,
        MarketStructs.PriceLimitConfig storage config,
        uint256 price
    ) internal view returns (MarketStructs.PriceLimitInfo memory updated) {
        uint256 currentTimestamp = block.number;
        uint256 refTimestamp = priceLimitInfo.referenceTimestamp;
        if (currentTimestamp <= refTimestamp) {
            updated.referencePrice = priceLimitInfo.referencePrice;
            updated.emaPrice = priceLimitInfo.emaPrice;
            return updated;
        }

        uint256 elapsed = currentTimestamp.sub(refTimestamp);

        if (priceLimitInfo.referencePrice == 0) {
            updated.emaPrice = price;
        } else {
            uint32 emaSec = config.emaSec;
            uint256 denominator = elapsed.add(emaSec);
            updated.emaPrice = FullMath.mulDiv(priceLimitInfo.emaPrice, emaSec, denominator).add(
                FullMath.mulDiv(price, elapsed, denominator)
            );
        }

        updated.referencePrice = price;
        updated.referenceTimestamp = currentTimestamp;
    }

    function isPriceLimitNeeded(
        uint256 referencePrice,
        uint256 priceBefore,
        uint256 priceAfter
    ) internal pure returns (bool) {
        if (referencePrice == priceAfter) return false;
        if (referencePrice < priceAfter) return priceBefore < priceAfter;
        return priceBefore > priceAfter;
    }

    function isWithinPriceLimit(
        uint256 referencePrice,
        uint256 price,
        uint24 priceLimitRatio
    ) internal pure returns (bool) {
        uint256 maxChange = referencePrice.mulRatio(priceLimitRatio);
        uint256 upperBound = referencePrice.add(maxChange);
        uint256 lowerBound = referencePrice.sub(maxChange);
        return lowerBound <= price && price <= upperBound;
    }
}
