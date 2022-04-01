// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { IUniswapV2Pair } from "../amm/uniswap_v2/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "../amm/uniswap_v2/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Router02 } from "../amm/uniswap_v2_periphery/interfaces/IUniswapV2Router02.sol";
import { UniswapV2LiquidityMathLibrary } from "../amm/uniswap_v2_periphery/libraries/UniswapV2LiquidityMathLibrary.sol";
import { UniswapV2OracleLibrary } from "../amm/uniswap_v2_periphery/libraries/UniswapV2OracleLibrary.sol";
import { UniswapV2Library } from "../amm/uniswap_v2_periphery/libraries/UniswapV2Library.sol";
import { Math } from "../amm/uniswap_v2/libraries/Math.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";
import { SafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import { PerpMath } from "../lib/PerpMath.sol";
import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

/**
 * Uniswap's v2 pool: token0 & token1
 * -> token0's price = token1 / token0
 * Our system: base & quote
 * -> base's price = quote / base
 * Thus, we require that (base, quote) = (token0, token1) is always true for convenience
 */
library UniswapV2Broker {
    using SafeMathUpgradeable for uint256;
    using PerpMath for int256;
    using PerpMath for uint256;
    using PerpSafeCast for uint256;
    using PerpSafeCast for int256;

    //
    // STRUCT
    //

    struct AddLiquidityParams {
        address router;
        address baseToken;
        address quoteToken;
        uint256 base;
        uint256 quote;
    }

    struct AddLiquidityResponse {
        uint256 base;
        uint256 quote;
        uint256 liquidity;
    }

    struct RemoveLiquidityParams {
        address router;
        address baseToken;
        address quoteToken;
        address recipient;
        uint256 liquidity;
    }

    /// @param base amount of base token received from burning the liquidity (excl. fee)
    /// @param quote amount of quote token received from burning the liquidity (excl. fee)
    struct RemoveLiquidityResponse {
        uint256 base;
        uint256 quote;
    }

    struct SwapParams {
        address router;
        address baseToken;
        address quoteToken;
        address recipient;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
    }

    struct SwapResponse {
        uint256 base;
        uint256 quote;
    }

    //
    // CONSTANT
    //

    //
    // INTERNAL NON-VIEW
    //

    function addLiquidity(AddLiquidityParams memory params) internal returns (AddLiquidityResponse memory) {
        (uint256 amountBase, uint256 amountQuote, uint256 liquidity) =
            IUniswapV2Router02(params.router).addLiquidity(
                params.baseToken, // tokenA
                params.quoteToken, // tokenB
                params.base, // amountADesired
                params.quote, // amountBDesired
                1, // amountAMin
                1, // amountBMin
                address(this), // to
                block.timestamp // deadline
            );

        return AddLiquidityResponse({ base: amountBase, quote: amountQuote, liquidity: liquidity });
    }

    function removeLiquidity(RemoveLiquidityParams memory params) internal returns (RemoveLiquidityResponse memory) {
        (uint256 amountBase, uint256 amountQuote) =
            IUniswapV2Router02(params.router).removeLiquidity(
                params.baseToken, // tokenA,
                params.quoteToken, // tokenB,
                params.liquidity, // liquidity,
                1, // amountAMin,
                1, // amountBMin,
                params.recipient, // to,
                block.timestamp // deadline
            );

        // TODO: Consider whether to include fee
        return RemoveLiquidityResponse({ base: amountBase, quote: amountQuote });
    }

    function swap(SwapParams memory params) internal returns (SwapResponse memory response) {
        uint256 amountIn;
        address[] memory path = new address[](2);
        uint256[] memory amounts;

        if (params.isBaseToQuote) {
            path[0] = params.baseToken;
            path[1] = params.quoteToken;
            amountIn = params.amount;
        } else {
            path[0] = params.quoteToken;
            path[1] = params.baseToken;
            amountIn = params.amount;
        }

        if (params.isExactInput) {
            amounts = IUniswapV2Router02(params.router).swapExactTokensForTokens(
                amountIn, // amountIn
                1, // amountOutMin
                path, // path
                params.recipient, // to
                block.timestamp // deadline
            );
        } else {
            // TODO: consider if pass amountIn to amountOut is right
            amounts = IUniswapV2Router02(params.router).swapTokensForExactTokens(
                amountIn, // amountOut
                type(uint256).max, // amountInMax
                path, // path
                params.recipient, // to
                block.timestamp // deadline
            );
        }

        if (params.isBaseToQuote) {
            return SwapResponse(amounts[0], amounts[1]);
        } else {
            return SwapResponse(amounts[1], amounts[0]);
        }
    }

    //
    // INTERNAL VIEW
    //

    function getLiquidityValue(
        address factory,
        address baseToken,
        address quoteToken,
        uint256 liquidityAmount
    ) internal view returns (uint256 baseAmount, uint256 quoteAmount) {
        return UniswapV2LiquidityMathLibrary.getLiquidityValue(factory, baseToken, quoteToken, liquidityAmount);
    }

    function getSqrtMarkPriceX96(
        address factory,
        address baseToken,
        address quoteToken
    ) internal view returns (uint160 sqrtMarkPrice) {
        (uint256 baseAmount, uint256 quoteAmount) = UniswapV2Library.getReserves(factory, baseToken, quoteToken);
        return uint160(Math.sqrt(FullMath.mulDiv(quoteAmount, FixedPoint96.Q96 * FixedPoint96.Q96, baseAmount)));
    }

    function getCurrentCumulativePrice(
        address factory,
        address baseToken,
        address quoteToken
    ) internal view returns (uint256 priceCumulative, uint32 blockTimestamp) {
        address pair = IUniswapV2Factory(factory).getPair(baseToken, quoteToken);
        uint256 price0Cumulative;
        uint256 price1Cumulative;
        (price0Cumulative, price1Cumulative, blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(pair);
        priceCumulative = IUniswapV2Pair(pair).token0() == baseToken ? price0Cumulative : price1Cumulative;
    }

    //
    // PRIVATE VIEW
    //
}
