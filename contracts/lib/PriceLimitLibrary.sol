// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { PerpMath } from "./PerpMath.sol";
import { PerpdexStructs } from "./PerpdexStructs.sol";

library PriceLimitLibrary {
    using PerpMath for uint256;
    using SafeMath for uint256;

    // should call before all price changes
    function update(PerpdexStructs.PriceLimitInfo storage priceLimitInfo, uint256 price) internal {
        if (priceLimitInfo.referenceBlockNumber < block.number) {
            priceLimitInfo.referencePrice = price;
            priceLimitInfo.referenceBlockNumber = block.number;
        }
    }

    function isNormalOrderAllowed(
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        PerpdexStructs.PriceLimitConfig memory config,
        uint256 price
    ) internal view returns (bool) {
        return isWithinPriceLimit(priceLimitInfo.referencePrice, price, config.normalOrderRatio);
    }

    function isLiquidationAllowed(
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        PerpdexStructs.PriceLimitConfig memory config,
        uint256 price
    ) internal view returns (bool) {
        return isWithinPriceLimit(priceLimitInfo.referencePrice, price, config.liquidationRatio);
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
