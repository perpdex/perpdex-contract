// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { Math } from "../amm/uniswap_v2/libraries/Math.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { PerpMath } from "./PerpMath.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";
import { MarketStructs } from "./MarketStructs.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

library PoolLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    struct SwapParams {
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint24 feeRatio;
    }

    struct AddLiquidityParams {
        uint256 base;
        uint256 quote;
    }

    struct RemoveLiquidityParams {
        uint256 liquidity;
    }

    uint256 public constant MINIMUM_LIQUIDITY = 1e3;

    function initializePool(MarketStructs.PoolInfo storage poolInfo) internal {
        poolInfo.baseBalancePerShareX96 = FixedPoint96.Q96;
    }

    function applyFunding(MarketStructs.PoolInfo storage poolInfo, int256 fundingRateX96) internal {
        if (fundingRateX96 == 0) return;

        if (fundingRateX96 > 0) {
            uint256 poolQuote = poolInfo.quote;
            uint256 deleveratedQuote = FullMath.mulDiv(poolQuote, fundingRateX96.abs(), FixedPoint96.Q96);
            poolInfo.quote = poolQuote.sub(deleveratedQuote);
            poolInfo.cumDeleveragedQuotePerLiquidityX96 = poolInfo.cumDeleveragedQuotePerLiquidityX96.add(
                FullMath.mulDiv(deleveratedQuote, FixedPoint96.Q96, poolInfo.totalLiquidity)
            );
        } else {
            uint256 poolBase = poolInfo.base;
            uint256 deleveratedBase =
                poolBase.sub(FullMath.mulDiv(poolBase, FixedPoint96.Q96, FixedPoint96.Q96.add(fundingRateX96.abs())));
            poolInfo.base = poolBase.sub(deleveratedBase);
            poolInfo.cumDeleveragedBasePerLiquidityX96 = poolInfo.cumDeleveragedBasePerLiquidityX96.add(
                FullMath.mulDiv(deleveratedBase, FixedPoint96.Q96, poolInfo.totalLiquidity)
            );
        }

        poolInfo.baseBalancePerShareX96 = FullMath.mulDiv(
            poolInfo.baseBalancePerShareX96,
            FixedPoint96.Q96.toInt256().sub(fundingRateX96).toUint256(),
            FixedPoint96.Q96
        );
    }

    function swap(MarketStructs.PoolInfo storage poolInfo, SwapParams memory params)
        internal
        returns (uint256 oppositeAmount)
    {
        oppositeAmount = previewSwap(poolInfo.base, poolInfo.quote, params);
        (poolInfo.base, poolInfo.quote) = calcPoolAfter(
            params.isBaseToQuote,
            params.isExactInput,
            poolInfo.base,
            poolInfo.quote,
            params.amount,
            oppositeAmount
        );
    }

    function calcPoolAfter(
        bool isBaseToQuote,
        bool isExactInput,
        uint256 base,
        uint256 quote,
        uint256 amount,
        uint256 oppositeAmount
    ) internal pure returns (uint256 baseAfter, uint256 quoteAfter) {
        if (isExactInput) {
            if (isBaseToQuote) {
                baseAfter = base.add(amount);
                quoteAfter = quote.sub(oppositeAmount);
            } else {
                baseAfter = base.sub(oppositeAmount);
                quoteAfter = quote.add(amount);
            }
        } else {
            if (isBaseToQuote) {
                baseAfter = base.add(oppositeAmount);
                quoteAfter = quote.sub(amount);
            } else {
                baseAfter = base.sub(amount);
                quoteAfter = quote.add(oppositeAmount);
            }
        }
    }

    function addLiquidity(MarketStructs.PoolInfo storage poolInfo, AddLiquidityParams memory params)
        internal
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 poolTotalLiquidity = poolInfo.totalLiquidity;
        uint256 liquidity;

        if (poolTotalLiquidity == 0) {
            uint256 totalLiquidity = Math.sqrt(params.base.mul(params.quote));
            liquidity = totalLiquidity.sub(MINIMUM_LIQUIDITY);
            require(params.base > 0 && params.quote > 0 && liquidity > 0, "PL_AL: initial liquidity zero");

            poolInfo.base = params.base;
            poolInfo.quote = params.quote;
            poolInfo.totalLiquidity = totalLiquidity;
            return (params.base, params.quote, liquidity);
        }

        uint256 poolBase = poolInfo.base;
        uint256 poolQuote = poolInfo.quote;

        uint256 base = Math.min(params.base, FullMath.mulDiv(params.quote, poolBase, poolQuote));
        uint256 quote = Math.min(params.quote, FullMath.mulDiv(params.base, poolQuote, poolBase));
        liquidity = Math.min(
            FullMath.mulDiv(base, poolTotalLiquidity, poolBase),
            FullMath.mulDiv(quote, poolTotalLiquidity, poolQuote)
        );
        require(base > 0 && quote > 0 && liquidity > 0, "PL_AL: liquidity zero");

        poolInfo.base = poolBase.add(base);
        poolInfo.quote = poolQuote.add(quote);
        poolInfo.totalLiquidity = poolTotalLiquidity.add(liquidity);

        return (base, quote, liquidity);
    }

    function removeLiquidity(MarketStructs.PoolInfo storage poolInfo, RemoveLiquidityParams memory params)
        internal
        returns (uint256, uint256)
    {
        uint256 poolBase = poolInfo.base;
        uint256 poolQuote = poolInfo.quote;
        uint256 poolTotalLiquidity = poolInfo.totalLiquidity;
        uint256 base = FullMath.mulDiv(params.liquidity, poolBase, poolTotalLiquidity);
        uint256 quote = FullMath.mulDiv(params.liquidity, poolQuote, poolTotalLiquidity);
        require(base > 0 && quote > 0, "PL_RL: output is zero");
        poolInfo.base = poolBase.sub(base);
        poolInfo.quote = poolQuote.sub(quote);
        uint256 totalLiquidity = poolTotalLiquidity.sub(params.liquidity);
        require(totalLiquidity >= MINIMUM_LIQUIDITY, "PL_RL: min liquidity");
        poolInfo.totalLiquidity = totalLiquidity;
        return (base, quote);
    }

    function getLiquidityValue(MarketStructs.PoolInfo storage poolInfo, uint256 liquidity)
        internal
        view
        returns (uint256, uint256)
    {
        return (
            FullMath.mulDiv(liquidity, poolInfo.base, poolInfo.totalLiquidity),
            FullMath.mulDiv(liquidity, poolInfo.quote, poolInfo.totalLiquidity)
        );
    }

    function previewSwap(
        uint256 base,
        uint256 quote,
        SwapParams memory params
    ) internal pure returns (uint256 output) {
        uint24 oneSubFeeRatio = PerpMath.subRatio(1e6, params.feeRatio);

        if (params.isExactInput) {
            uint256 amountSubFee = params.amount.mulRatio(oneSubFeeRatio);
            if (params.isBaseToQuote) {
                output = quote.sub(FullMath.mulDivRoundingUp(base, quote, base.add(amountSubFee)));
            } else {
                output = base.sub(FullMath.mulDivRoundingUp(base, quote, quote.add(amountSubFee)));
            }
        } else {
            if (params.isBaseToQuote) {
                output = FullMath.mulDivRoundingUp(base, quote, quote.sub(params.amount)).sub(base);
            } else {
                output = FullMath.mulDivRoundingUp(base, quote, base.sub(params.amount)).sub(quote);
            }
            output = output.divRatioRoundingUp(oneSubFeeRatio);
        }
        require(output > 0, "PL_SD: output is zero");
    }

    function maxSwap(
        uint256 base,
        uint256 quote,
        bool isBaseToQuote,
        bool isExactInput,
        uint24 feeRatio,
        uint256 priceBoundX96
    ) internal pure returns (uint256 output) {
        if (isExactInput) {
            if (isBaseToQuote) {
                uint256 baseAfter = Math.sqrt(FullMath.mulDiv(base.mul(quote), FixedPoint96.Q96, priceBoundX96));
                return baseAfter.sub(base);
            } else {
                uint256 quoteAfter = Math.sqrt(FullMath.mulDiv(base.mul(quote), priceBoundX96, FixedPoint96.Q96));
                return quoteAfter.sub(quote);
            }
        } else {
            if (isBaseToQuote) {
                uint256 quoteAfter =
                    Math.sqrtRoundingUp(FullMath.mulDivRoundingUp(base.mul(quote), priceBoundX96, FixedPoint96.Q96));
                return quote.sub(quoteAfter);
            } else {
                uint256 baseAfter =
                    Math.sqrtRoundingUp(FullMath.mulDivRoundingUp(base.mul(quote), FixedPoint96.Q96, priceBoundX96));
                return base.sub(baseAfter);
            }
        }
    }

    function getMarkPriceX96(
        uint256 base,
        uint256 quote,
        uint256 baseBalancePerShareX96
    ) internal pure returns (uint256) {
        return FullMath.mulDiv(getShareMarkPriceX96(base, quote), FixedPoint96.Q96, baseBalancePerShareX96);
    }

    function getShareMarkPriceX96(uint256 base, uint256 quote) internal pure returns (uint256) {
        return FullMath.mulDiv(quote, FixedPoint96.Q96, base);
    }

    function getLiquidityDeleveraged(
        uint256 poolCumDeleveragedBasePerLiquidityX96,
        uint256 poolCumDeleveragedQuotePerLiquidityX96,
        uint256 liquidity,
        uint256 cumDeleveragedBasePerLiquidityX96,
        uint256 cumDeleveragedQuotePerLiquidityX96
    ) internal pure returns (uint256, uint256) {
        uint256 deleveragedBasePerLiquidityX96 =
            poolCumDeleveragedBasePerLiquidityX96.sub(cumDeleveragedBasePerLiquidityX96);
        uint256 deleveragedQuotePerLiquidityX96 =
            poolCumDeleveragedQuotePerLiquidityX96.sub(cumDeleveragedQuotePerLiquidityX96);

        return (
            FullMath.mulDiv(liquidity, deleveragedBasePerLiquidityX96, FixedPoint96.Q96),
            FullMath.mulDiv(liquidity, deleveragedQuotePerLiquidityX96, FixedPoint96.Q96)
        );
    }
}
