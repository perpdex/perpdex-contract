// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { Math } from "../amm/uniswap_v2/libraries/Math.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { PerpMath } from "./PerpMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";
import { MarketStructs } from "./MarketStructs.sol";
import { IPerpdexPriceFeed } from "../interface/IPerpdexPriceFeed.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

library FundingLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
    using PerpSafeCast for int256;
    using PerpSafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    struct ProcessFundingParams {
        address priceFeedBase;
        address priceFeedQuote;
        uint256 markPriceX96;
        uint24 maxPremiumRatio;
        uint32 maxElapsedSec;
        uint32 rolloverSec;
    }

    function initializeFunding(MarketStructs.FundingInfo storage fundingInfo) internal {
        fundingInfo.prevIndexPriceTimestamp = block.timestamp;
    }

    function processFunding(MarketStructs.FundingInfo storage fundingInfo, ProcessFundingParams memory params)
        internal
        returns (int256 fundingRateX96)
    {
        uint256 now = block.timestamp;
        uint256 elapsedSec = now.sub(fundingInfo.prevIndexPriceTimestamp);
        if (elapsedSec == 0) return 0;

        uint256 indexPriceBase =
            params.priceFeedBase != address(0) ? IPerpdexPriceFeed(params.priceFeedBase).getPrice() : 1;
        uint256 indexPriceQuote =
            params.priceFeedQuote != address(0) ? IPerpdexPriceFeed(params.priceFeedQuote).getPrice() : 1;
        if (
            (fundingInfo.prevIndexPriceBase == indexPriceBase && fundingInfo.prevIndexPriceQuote == indexPriceQuote) ||
            indexPriceBase == 0 ||
            indexPriceQuote == 0
        ) {
            return 0;
        }

        elapsedSec = Math.min(elapsedSec, params.maxElapsedSec);

        int256 premiumX96 =
            _calcPremiumX96(
                params.priceFeedBase,
                params.priceFeedQuote,
                indexPriceBase,
                indexPriceQuote,
                params.markPriceX96
            );

        int256 maxPremiumX96 = FixedPoint96.Q96.mulRatio(params.maxPremiumRatio).toInt256();
        premiumX96 = (-maxPremiumX96).max(maxPremiumX96.min(premiumX96));
        fundingRateX96 = premiumX96.mulDiv(elapsedSec.toInt256(), params.rolloverSec);

        fundingInfo.prevIndexPriceBase = indexPriceBase;
        fundingInfo.prevIndexPriceQuote = indexPriceQuote;
        fundingInfo.prevIndexPriceTimestamp = now;
    }

    function validateInitialLiquidityPrice(
        address priceFeedBase,
        address priceFeedQuote,
        uint256 base,
        uint256 quote
    ) internal view {
        uint256 indexPriceBase = priceFeedBase != address(0) ? IPerpdexPriceFeed(priceFeedBase).getPrice() : 1;
        uint256 indexPriceQuote = priceFeedQuote != address(0) ? IPerpdexPriceFeed(priceFeedQuote).getPrice() : 1;
        require(indexPriceBase > 0, "FL_VILP: invalid base price");
        require(indexPriceQuote > 0, "FL_VILP: invalid quote price");

        uint256 markPriceX96 = FullMath.mulDiv(quote, FixedPoint96.Q96, base);
        int256 premiumX96 =
            _calcPremiumX96(priceFeedBase, priceFeedQuote, indexPriceBase, indexPriceQuote, markPriceX96);

        require(premiumX96.abs() <= FixedPoint96.Q96.mulRatio(1e5), "FL_VILP: too far from index");
    }

    function _calcPremiumX96(
        address priceFeedBase,
        address priceFeedQuote,
        uint256 indexPriceBase,
        uint256 indexPriceQuote,
        uint256 markPriceX96
    ) private view returns (int256 premiumX96) {
        uint256 priceRatioX96 = markPriceX96;
        if (priceFeedBase != address(0)) {
            priceRatioX96 = FullMath.mulDiv(
                priceRatioX96,
                10**IPerpdexPriceFeed(priceFeedBase).decimals(),
                indexPriceBase
            );
        }
        if (priceFeedQuote != address(0)) {
            priceRatioX96 = FullMath.mulDiv(
                priceRatioX96,
                indexPriceQuote,
                10**IPerpdexPriceFeed(priceFeedQuote).decimals()
            );
        }
        premiumX96 = priceRatioX96.toInt256().sub(FixedPoint96.Q96.toInt256());
    }
}
