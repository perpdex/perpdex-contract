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

    // referenceTimestamp == 0 indicates not updated
    function updateDry(
        MarketStructs.PriceLimitInfo storage priceLimitInfo,
        MarketStructs.PriceLimitConfig storage config,
        uint256 price
    ) internal view returns (MarketStructs.PriceLimitInfo memory updated) {
        uint256 currentTimestamp = block.timestamp;
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

    function priceBound(
        uint256 referencePrice,
        uint256 emaPrice,
        MarketStructs.PriceLimitConfig storage config,
        bool isLiquidation,
        bool isUpperBound
    ) internal view returns (uint256 price) {
        uint256 referenceRange =
            referencePrice.mulRatio(isLiquidation ? config.liquidationRatio : config.normalOrderRatio);
        uint256 emaRange = emaPrice.mulRatio(isLiquidation ? config.emaLiquidationRatio : config.emaNormalOrderRatio);

        if (isUpperBound) {
            return Math.min(referencePrice.add(referenceRange), emaPrice.add(emaRange));
        } else {
            return Math.max(referencePrice.sub(referenceRange), emaPrice.sub(emaRange));
        }
    }
}
