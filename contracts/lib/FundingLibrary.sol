// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { Math } from "../amm/uniswap_v2/libraries/Math.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { PerpMath } from "./PerpMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";
import { MarketStructs } from "./MarketStructs.sol";
import { IPriceFeed } from "@perp/perp-oracle-contract/contracts/interface/IPriceFeed.sol";
import { FullMath } from "@uniswap/lib/contracts/libraries/FullMath.sol";
import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

// internal
library FundingLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
    using PerpSafeCast for int256;
    using PerpSafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    struct RebaseParams {
        address priceFeed;
        uint256 markPriceX96;
        uint24 maxPremiumRatio;
        uint32 maxElapsedSec;
        uint32 rolloverSec;
    }

    function rebase(MarketStructs.FundingInfo storage fundingInfo, RebaseParams memory params) internal {
        uint256 now = block.timestamp;
        uint256 indexPrice = IPriceFeed(params.priceFeed).getPrice(0);
        uint256 elapsedSec = now.sub(fundingInfo.prevIndexPriceTimestamp);

        if (fundingInfo.prevIndexPrice == indexPrice || indexPrice == 0 || elapsedSec == 0) {
            return;
        }

        elapsedSec = Math.min(elapsedSec, params.maxElapsedSec);

        int256 premiumX96 =
            FullMath.mulDiv(params.markPriceX96, FixedPoint96.Q96, indexPrice).toInt256() - FixedPoint96.Q96.toInt256();
        int256 maxPremiumX96 = FixedPoint96.Q96.mulRatio(params.maxPremiumRatio).toInt256();
        premiumX96 = (-maxPremiumX96).max(maxPremiumX96.min(premiumX96));
        int256 fundingRateX96 = premiumX96.mulDiv(elapsedSec.toInt256(), params.rolloverSec);

        fundingInfo.balancePerShare = FullMath.mulDiv(
            fundingInfo.balancePerShare,
            FixedPoint96.Q96,
            FixedPoint96.Q96.toInt256().sub(fundingRateX96).toUint256()
        );
        fundingInfo.prevIndexPrice = indexPrice;
        fundingInfo.prevIndexPriceTimestamp = now;
    }
}
