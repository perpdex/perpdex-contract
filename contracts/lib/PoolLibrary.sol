// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { Math } from "../amm/uniswap_v2/libraries/Math.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { PerpMath } from "./PerpMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";
import { MarketStructs } from "./MarketStructs.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

library PoolLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
    using PerpSafeCast for int256;
    using PerpSafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    uint256 public constant MINIMUM_LIQUIDITY = 1e3;

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

    function initializePool(MarketStructs.PoolInfo storage poolInfo) internal {
        poolInfo.baseBalancePerShare = 1 << 64;
    }

    function applyFunding(MarketStructs.PoolInfo storage poolInfo, int256 fundingRateX96) internal {
        if (fundingRateX96 == 0) return;

        if (fundingRateX96 > 0) {
            uint256 poolQuote = poolInfo.quote;
            uint256 deleveratedQuote = FullMath.mulDiv(poolQuote, fundingRateX96.abs(), FixedPoint96.Q96);
            poolInfo.quote = poolQuote - deleveratedQuote;
            poolInfo.cumDeleveragedQuotePerLiquidity = poolInfo.cumDeleveragedQuotePerLiquidity.add(
                deleveratedQuote.div(poolInfo.totalLiquidity)
            );
        } else {
            uint256 poolBase = poolInfo.base;
            uint256 deleveratedBase =
                poolBase.sub(FullMath.mulDiv(poolBase, FixedPoint96.Q96, FixedPoint96.Q96.add(fundingRateX96.abs())));
            poolInfo.base = poolBase - deleveratedBase;
            poolInfo.cumDeleveragedBasePerLiquidity = poolInfo.cumDeleveragedBasePerLiquidity.add(
                deleveratedBase.div(poolInfo.totalLiquidity)
            );
        }

        poolInfo.baseBalancePerShare = FullMath.mulDiv(
            poolInfo.baseBalancePerShare,
            FixedPoint96.Q96,
            FixedPoint96.Q96.toInt256().sub(fundingRateX96).toUint256()
        );
    }

    function swap(MarketStructs.PoolInfo storage poolInfo, SwapParams memory params) internal returns (uint256) {
        uint256 output = swapDry(poolInfo.base, poolInfo.quote, params);
        if (params.isExactInput) {
            if (params.isBaseToQuote) {
                poolInfo.base = poolInfo.base.add(params.amount);
                poolInfo.quote = poolInfo.quote.sub(output);
            } else {
                poolInfo.base = poolInfo.base.sub(output);
                poolInfo.quote = poolInfo.quote.add(params.amount);
            }
        } else {
            if (params.isBaseToQuote) {
                poolInfo.base = poolInfo.base.add(output);
                poolInfo.quote = poolInfo.quote.sub(params.amount);
            } else {
                poolInfo.base = poolInfo.base.sub(params.amount);
                poolInfo.quote = poolInfo.quote.add(output);
            }
        }
        return output;
    }

    function swapDry(
        uint256 base,
        uint256 quote,
        SwapParams memory params
    ) internal view returns (uint256 output) {
        uint24 onePlusFeeRatio = 1e6 + params.feeRatio;

        if (params.isExactInput) {
            uint256 amountDivFee = params.amount.divRatio(onePlusFeeRatio);
            if (params.isBaseToQuote) {
                output = quote.sub(FullMath.mulDivRoundingUp(base, quote, base.add(amountDivFee)));
            } else {
                output = base.sub(FullMath.mulDivRoundingUp(base, quote, quote.add(amountDivFee)));
            }
        } else {
            if (params.isBaseToQuote) {
                output = FullMath.mulDivRoundingUp(base, quote, quote.sub(params.amount)).sub(base);
            } else {
                output = FullMath.mulDivRoundingUp(base, quote, base.sub(params.amount)).sub(quote);
            }
            output = output.mulRatio(onePlusFeeRatio);
        }
        require(output > 0, "PL_SD: output is zero");
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

        if (poolTotalLiquidity == 0) {
            uint256 totalLiquidity = Math.sqrt(params.base.mul(params.quote));
            uint256 liquidity = totalLiquidity.sub(MINIMUM_LIQUIDITY);
            require(params.base > 0 && params.quote > 0 && liquidity > 0, "PL_AL: liquidity zero");

            poolInfo.base = params.base;
            poolInfo.quote = params.quote;
            poolInfo.totalLiquidity = totalLiquidity;
            return (params.base, params.quote, liquidity);
        }

        uint256 poolBase = poolInfo.base;
        uint256 poolQuote = poolInfo.quote;

        uint256 base = Math.min(params.base, FullMath.mulDiv(params.quote, poolBase, poolQuote));
        uint256 quote = Math.min(params.quote, FullMath.mulDiv(params.base, poolQuote, poolBase));
        uint256 liquidity =
            Math.min(
                FullMath.mulDiv(base, poolTotalLiquidity, poolBase),
                FullMath.mulDiv(quote, poolTotalLiquidity, poolQuote)
            );
        require(base > 0 && quote > 0 && liquidity > 0);

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
        require(base > 0 && quote > 0);
        poolInfo.base = poolBase.sub(base);
        poolInfo.quote = poolQuote.sub(quote);
        poolInfo.totalLiquidity = poolTotalLiquidity.sub(params.liquidity);
        return (base, quote);
    }

    function getMarkPriceX96(
        uint256 base,
        uint256 quote,
        uint256 baseBalancePerShare
    ) internal pure returns (uint256) {
        return quote.div(base.mul(baseBalancePerShare));
    }

    function getShareMarkPriceX96(uint256 base, uint256 quote) internal pure returns (uint256) {
        return quote.div(base);
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

    function getLiquidityDeleveraged(
        uint256 poolCumDeleveragedBasePerLiquidity,
        uint256 poolCumDeleveragedQuotePerLiquidity,
        uint256 liquidity,
        uint256 cumDeleveragedBasePerLiquidity,
        uint256 cumDeleveragedQuotePerLiquidity
    ) internal pure returns (uint256, uint256) {
        uint256 deleveragedBasePerLiquidity = cumDeleveragedBasePerLiquidity - poolCumDeleveragedBasePerLiquidity;
        uint256 deleveragedQuotePerLiquidity = cumDeleveragedQuotePerLiquidity - poolCumDeleveragedQuotePerLiquidity;

        return (liquidity.mul(deleveragedBasePerLiquidity), liquidity.mul(deleveragedQuotePerLiquidity));
    }
}
