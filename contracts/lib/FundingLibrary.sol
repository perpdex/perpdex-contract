// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.6;
pragma abicoder v2;

import { Math } from "../amm/uniswap_v2/libraries/Math.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";
import { PerpMath } from "./PerpMath.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { MarketStructs } from "./MarketStructs.sol";
import { IPerpdexPriceFeed } from "../interfaces/IPerpdexPriceFeed.sol";
import { PRBMath } from "prb-math/contracts/PRBMath.sol";
import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

library FundingLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
    using SafeCast for int256;
    using SafeCast for uint256;
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

    uint8 public constant MAX_DECIMALS = 77; // 10^MAX_DECIMALS < 2^256

    function initializeFunding(MarketStructs.FundingInfo storage fundingInfo) internal {
        fundingInfo.prevIndexPriceTimestamp = block.timestamp;
    }

    // must not revert even if priceFeed is malicious
    function processFunding(MarketStructs.FundingInfo storage fundingInfo, ProcessFundingParams memory params)
        internal
        returns (
            int256 fundingRateX96,
            uint32 elapsedSec,
            int256 premiumX96
        )
    {
        uint256 currentTimestamp = block.timestamp;
        uint256 elapsedSec256 = currentTimestamp.sub(fundingInfo.prevIndexPriceTimestamp);
        if (elapsedSec256 == 0) return (0, 0, 0);

        uint256 indexPriceBase = _getIndexPriceSafe(params.priceFeedBase);
        uint256 indexPriceQuote = _getIndexPriceSafe(params.priceFeedQuote);
        uint8 decimalsBase = _getDecimalsSafe(params.priceFeedBase);
        uint8 decimalsQuote = _getDecimalsSafe(params.priceFeedQuote);
        if (
            (fundingInfo.prevIndexPriceBase == indexPriceBase && fundingInfo.prevIndexPriceQuote == indexPriceQuote) ||
            indexPriceBase == 0 ||
            indexPriceQuote == 0 ||
            decimalsBase > MAX_DECIMALS ||
            decimalsQuote > MAX_DECIMALS
        ) {
            return (0, 0, 0);
        }

        elapsedSec256 = Math.min(elapsedSec256, params.maxElapsedSec);
        elapsedSec = elapsedSec256.toUint32();

        premiumX96 = _calcPremiumX96(decimalsBase, decimalsQuote, indexPriceBase, indexPriceQuote, params.markPriceX96);

        int256 maxPremiumX96 = FixedPoint96.Q96.mulRatio(params.maxPremiumRatio).toInt256();
        premiumX96 = (-maxPremiumX96).max(maxPremiumX96.min(premiumX96));
        fundingRateX96 = premiumX96.mulDiv(elapsedSec256.toInt256(), params.rolloverSec);

        fundingInfo.prevIndexPriceBase = indexPriceBase;
        fundingInfo.prevIndexPriceQuote = indexPriceQuote;
        fundingInfo.prevIndexPriceTimestamp = currentTimestamp;
    }

    function validateInitialLiquidityPrice(
        address priceFeedBase,
        address priceFeedQuote,
        uint256 base,
        uint256 quote
    ) internal view {
        uint256 indexPriceBase = _getIndexPriceSafe(priceFeedBase);
        uint256 indexPriceQuote = _getIndexPriceSafe(priceFeedQuote);
        require(indexPriceBase > 0, "FL_VILP: invalid base price");
        require(indexPriceQuote > 0, "FL_VILP: invalid quote price");
        uint8 decimalsBase = _getDecimalsSafe(priceFeedBase);
        uint8 decimalsQuote = _getDecimalsSafe(priceFeedQuote);
        require(decimalsBase <= MAX_DECIMALS, "FL_VILP: invalid base decimals");
        require(decimalsQuote <= MAX_DECIMALS, "FL_VILP: invalid quote decimals");

        uint256 markPriceX96 = PRBMath.mulDiv(quote, FixedPoint96.Q96, base);
        int256 premiumX96 = _calcPremiumX96(decimalsBase, decimalsQuote, indexPriceBase, indexPriceQuote, markPriceX96);

        require(premiumX96.abs() <= FixedPoint96.Q96.mulRatio(1e5), "FL_VILP: too far from index");
    }

    function _getIndexPriceSafe(address priceFeed) private view returns (uint256) {
        if (priceFeed == address(0)) return 1; // indicate valid

        bytes memory payload = abi.encodeWithSignature("getPrice()");
        (bool success, bytes memory data) = address(priceFeed).staticcall(payload);
        if (!success) return 0; // invalid

        return abi.decode(data, (uint256));
    }

    function _getDecimalsSafe(address priceFeed) private view returns (uint8) {
        if (priceFeed == address(0)) return 0; // indicate valid

        bytes memory payload = abi.encodeWithSignature("decimals()");
        (bool success, bytes memory data) = address(priceFeed).staticcall(payload);
        if (!success) return 255; // invalid

        return abi.decode(data, (uint8));
    }

    // TODO: must not revert
    function _calcPremiumX96(
        uint8 decimalsBase,
        uint8 decimalsQuote,
        uint256 indexPriceBase,
        uint256 indexPriceQuote,
        uint256 markPriceX96
    ) private pure returns (int256 premiumX96) {
        uint256 priceRatioX96 = markPriceX96;

        if (decimalsBase != 0 || indexPriceBase != 1) {
            priceRatioX96 = PRBMath.mulDiv(priceRatioX96, 10**decimalsBase, indexPriceBase);
        }
        if (decimalsQuote != 0 || indexPriceQuote != 1) {
            priceRatioX96 = PRBMath.mulDiv(priceRatioX96, indexPriceQuote, 10**decimalsQuote);
        }

        premiumX96 = priceRatioX96.toInt256().sub(FixedPoint96.Q96.toInt256());
    }
}
