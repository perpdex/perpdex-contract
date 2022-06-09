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

    function checkAndUpdate(
        MarketStructs.PriceLimitInfo storage priceLimitInfo,
        MarketStructs.PriceLimitConfig storage config,
        uint256 priceBefore,
        uint256 priceAfter,
        bool isLiquidation
    ) internal {
        (uint256 referencePrice, uint256 referenceTimestamp, uint256 emaPrice) =
            check(priceLimitInfo, config, priceBefore, priceAfter, isLiquidation);
        if (referenceTimestamp > 0) {
            priceLimitInfo.referencePrice = referencePrice;
            priceLimitInfo.referenceTimestamp = referenceTimestamp;
            priceLimitInfo.emaPrice = emaPrice;
        }
    }

    function check(
        MarketStructs.PriceLimitInfo storage priceLimitInfo,
        MarketStructs.PriceLimitConfig storage config,
        uint256 priceBefore,
        uint256 priceAfter,
        bool isLiquidation
    )
        internal
        view
        returns (
            uint256 referencePrice,
            uint256 referenceTimestamp,
            uint256 emaPrice
        )
    {
        (referencePrice, referenceTimestamp, emaPrice) = updateDry(priceLimitInfo, config, priceBefore);

        if (isPriceLimitNeeded(referencePrice, priceBefore, priceAfter)) {
            require(
                isWithinPriceLimit(
                    referencePrice,
                    priceAfter,
                    isLiquidation ? config.liquidationRatio : config.normalOrderRatio
                ),
                "PLL_C: price limit"
            );
        }
        if (isPriceLimitNeeded(emaPrice, priceBefore, priceAfter)) {
            require(
                isWithinPriceLimit(
                    emaPrice,
                    priceAfter,
                    isLiquidation ? config.emaLiquidationRatio : config.emaNormalOrderRatio
                ),
                "PLL_C: price band"
            );
        }
    }

    function maxPrice(
        MarketStructs.PriceLimitInfo storage priceLimitInfo,
        MarketStructs.PriceLimitConfig storage config,
        uint256 priceBefore,
        bool isLiquidation
    ) internal view returns (uint256 price) {
        (uint256 referencePrice, uint256 referenceTimestamp, uint256 emaPrice) =
            updateDry(priceLimitInfo, config, priceBefore);

        uint256 upperBound =
            referencePrice.add(
                referencePrice.mulRatio(isLiquidation ? config.liquidationRatio : config.normalOrderRatio)
            );
        uint256 upperBoundEma =
            emaPrice.add(emaPrice.mulRatio(isLiquidation ? config.emaLiquidationRatio : config.emaNormalOrderRatio));
        return Math.min(upperBound, upperBoundEma);
    }

    function minPrice(
        MarketStructs.PriceLimitInfo storage priceLimitInfo,
        MarketStructs.PriceLimitConfig storage config,
        uint256 priceBefore,
        bool isLiquidation
    ) internal view returns (uint256 price) {
        (uint256 referencePrice, uint256 referenceTimestamp, uint256 emaPrice) =
            updateDry(priceLimitInfo, config, priceBefore);

        uint256 upperBound =
            referencePrice.sub(
                referencePrice.mulRatio(isLiquidation ? config.liquidationRatio : config.normalOrderRatio)
            );
        uint256 upperBoundEma =
            emaPrice.sub(emaPrice.mulRatio(isLiquidation ? config.emaLiquidationRatio : config.emaNormalOrderRatio));
        return Math.max(upperBound, upperBoundEma);
    }

    // referenceTimestamp == 0 indicates not updated
    function updateDry(
        MarketStructs.PriceLimitInfo storage priceLimitInfo,
        MarketStructs.PriceLimitConfig storage config,
        uint256 price
    )
        internal
        view
        returns (
            uint256 referencePrice,
            uint256 referenceTimestamp,
            uint256 emaPrice
        )
    {
        uint256 currentTimestamp = block.number;
        uint256 refTimestamp = priceLimitInfo.referenceTimestamp;
        if (currentTimestamp <= refTimestamp) return (priceLimitInfo.referencePrice, 0, priceLimitInfo.emaPrice);

        uint256 elapsed = currentTimestamp.sub(refTimestamp);

        if (priceLimitInfo.referencePrice == 0) {
            emaPrice = price;
        } else {
            uint32 emaSec = config.emaSec;
            uint256 denominator = elapsed.add(emaSec);
            emaPrice = FullMath.mulDiv(priceLimitInfo.emaPrice, emaSec, denominator).add(
                FullMath.mulDiv(price, elapsed, denominator)
            );
        }

        referencePrice = price;
        referenceTimestamp = currentTimestamp;
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
