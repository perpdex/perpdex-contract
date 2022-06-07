// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { PerpMath } from "./PerpMath.sol";
import { PerpdexStructs } from "./PerpdexStructs.sol";

library PriceLimitLibrary {
    using PerpMath for uint256;
    using SafeMath for uint256;

    // should call before all price changes
    function update(
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        uint32 emaSec,
        uint256 price
    ) internal {
        uint256 currentTimestamp = block.number;
        uint256 refTimestamp = priceLimitInfo.referenceTimestamp;
        if (refTimestamp < currentTimestamp) {
            uint256 elapsed = currentTimestamp.sub(refTimestamp);

            if (priceLimitInfo.referencePrice == 0) {
                priceLimitInfo.emaPrice = price;
            } else {
                uint256 denominator = elapsed.add(emaSec);
                priceLimitInfo.emaPrice = FullMath.mulDiv(priceLimitInfo.emaPrice, emaSec, denominator).add(
                    FullMath.mulDiv(price, elapsed, denominator)
                );
            }

            priceLimitInfo.referencePrice = price;
            priceLimitInfo.referenceTimestamp = currentTimestamp;
        }
    }

    function isNormalOrderAllowed(
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        PerpdexStructs.PriceLimitConfig memory config,
        uint256 price
    ) internal view returns (bool) {
        return
            isWithinPriceLimit(priceLimitInfo.referencePrice, price, config.normalOrderRatio) &&
            isWithinPriceLimit(priceLimitInfo.emaPrice, price, config.emaNormalOrderRatio);
    }

    function isLiquidationAllowed(
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        PerpdexStructs.PriceLimitConfig memory config,
        uint256 price
    ) internal view returns (bool) {
        return
            isWithinPriceLimit(priceLimitInfo.referencePrice, price, config.liquidationRatio) &&
            isWithinPriceLimit(priceLimitInfo.emaPrice, price, config.emaLiquidationRatio);
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
