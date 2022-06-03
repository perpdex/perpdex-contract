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
        uint256 cumDeleveragedBasePerLiquidityX96;
        uint256 cumDeleveragedQuotePerLiquidityX96;
        uint256 baseBalancePerShare;
    }
}
