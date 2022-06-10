// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

library MarketStructs {
    struct FundingInfo {
        uint256 prevIndexPriceBase;
        uint256 prevIndexPriceQuote;
        uint256 prevIndexPriceTimestamp;
    }

    struct PoolInfo {
        uint256 base;
        uint256 quote;
        uint256 totalLiquidity;
        uint256 cumBasePerLiquidityX96;
        uint256 cumQuotePerLiquidityX96;
        uint256 baseBalancePerShareX96;
    }

    struct PriceLimitInfo {
        uint256 referencePrice;
        uint256 referenceTimestamp;
        uint256 emaPrice;
    }

    struct PriceLimitConfig {
        uint24 normalOrderRatio;
        uint24 liquidationRatio;
        uint24 emaNormalOrderRatio;
        uint24 emaLiquidationRatio;
        uint32 emaSec;
    }
}
