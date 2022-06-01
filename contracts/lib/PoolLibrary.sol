// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { Math } from "../amm/uniswap_v2/libraries/Math.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { PerpMath } from "./PerpMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";
import { MarketStructs } from "./MarketStructs.sol";
import { FullMath } from "@uniswap/lib/contracts/libraries/FullMath.sol";

library PoolLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
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

    function swap(MarketStructs.PoolInfo storage poolInfo, SwapParams memory params) internal returns (uint256) {
        uint256 output = swapDry(poolInfo, params);
        if (params.isExactInput) {
            if (params.isBaseToQuote) {
                poolInfo.base = poolInfo.base.sub(params.amount);
                poolInfo.quote = poolInfo.quote.add(output);
            } else {
                poolInfo.base = poolInfo.base.add(output);
                poolInfo.quote = poolInfo.quote.sub(params.amount);
            }
        } else {
            if (params.isBaseToQuote) {
                poolInfo.base = poolInfo.base.sub(output);
                poolInfo.quote = poolInfo.quote.add(params.amount);
            } else {
                poolInfo.base = poolInfo.base.add(params.amount);
                poolInfo.quote = poolInfo.quote.sub(output);
            }
        }
        return output;
    }

    function swapDry(MarketStructs.PoolInfo storage poolInfo, SwapParams memory params)
        internal
        view
        returns (uint256)
    {
        uint256 output;
        uint256 base = poolInfo.base;
        uint256 quote = poolInfo.quote;
        uint256 invariant = base.mul(quote);
        uint24 onePlusFeeRatio = 1e6 + params.feeRatio;

        if (params.isExactInput) {
            if (params.isBaseToQuote) {
                output = quote.sub(invariant.div(base + params.amount.divRatio(onePlusFeeRatio)));
            } else {
                output = base.sub(invariant.div(quote + params.amount.divRatio(onePlusFeeRatio)));
            }
        } else {
            if (params.isBaseToQuote) {
                output = invariant.div(quote - params.amount).sub(base);
            } else {
                output = invariant.div(base - params.amount).sub(quote);
            }
            output = output.mulRatio(onePlusFeeRatio);
        }
        require(output > 0);

        return output;
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
            poolInfo.base = params.base;
            poolInfo.quote = params.quote;
            uint256 totalLiquidity = Math.sqrt(params.base.mul(params.quote));
            require(totalLiquidity > MINIMUM_LIQUIDITY);
            poolInfo.totalLiquidity = totalLiquidity;
            return (params.base, params.quote, totalLiquidity.sub(MINIMUM_LIQUIDITY));
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

    function getMarkPriceX96(MarketStructs.PoolInfo storage poolInfo) internal view returns (uint256) {
        return poolInfo.quote.div(poolInfo.base);
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
}
