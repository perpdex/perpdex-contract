// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import { IUniswapV2Pair } from "../amm/uniswap_v2/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "../amm/uniswap_v2/interfaces/IUniswapV2Factory.sol";
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
        address factory;
        address baseToken;
        address quoteToken;
        uint256 base;
        uint256 quote;
        address to;
    }

    struct AddLiquidityResponse {
        uint256 base;
        uint256 quote;
        uint256 liquidity;
    }

    struct RemoveLiquidityParams {
        address factory;
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
        address factory;
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
            _addLiquidity(
                params.factory,
                params.baseToken, // tokenA
                params.quoteToken, // tokenB
                params.base, // amountADesired
                params.quote, // amountBDesired
                1, // amountAMin
                1, // amountBMin
                address(params.to), // to
                block.timestamp // deadline
            );

        return AddLiquidityResponse({ base: amountBase, quote: amountQuote, liquidity: liquidity });
    }

    function removeLiquidity(RemoveLiquidityParams memory params) internal returns (RemoveLiquidityResponse memory) {
        (uint256 amountBase, uint256 amountQuote) =
            _removeLiquidity(
                params.factory,
                params.baseToken, // tokenA,
                params.quoteToken, // tokenB,
                params.liquidity, // liquidity,
                1, // amountAMin,
                1, // amountBMin,
                params.recipient, // to,
                block.timestamp // deadline
            );

        return RemoveLiquidityResponse({ base: amountBase, quote: amountQuote });
    }

    function swap(SwapParams memory params) internal returns (SwapResponse memory response) {
        uint256 amountIn;
        address[] memory path = new address[](2);
        uint256[] memory amounts;

        if (params.isBaseToQuote) {
            path[0] = params.baseToken;
            path[1] = params.quoteToken;
        } else {
            path[0] = params.quoteToken;
            path[1] = params.baseToken;
        }

        if (params.isExactInput) {
            amounts = _swapExactTokensForTokens(
                params.factory,
                params.amount, // amountIn
                1, // amountOutMin
                path, // path
                params.recipient, // to
                block.timestamp // deadline
            );
        } else {
            amounts = _swapTokensForExactTokens(
                params.factory,
                params.amount, // amountOut
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
        if (IUniswapV2Pair(pair).price0CumulativeLast() == 0) {
            priceCumulative = 0;
            blockTimestamp = 0;
        } else {
            (price0Cumulative, price1Cumulative, blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(pair);
            priceCumulative = IUniswapV2Pair(pair).token0() == baseToken ? price0Cumulative : price1Cumulative;
        }
    }

    //
    // PRIVATE NON-VIEW
    //

    // copied from UniswapV2Router02
    // modified to transfer tokens from "to" param

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        _;
    }

    // **** ADD LIQUIDITY ****
    function _doAddLiquidity(
        address factory,
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) private returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IUniswapV2Factory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "UniswapV2Router: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "UniswapV2Router: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _addLiquidity(
        address factory,
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        private
        ensure(deadline)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (amountA, amountB) = _doAddLiquidity(
            factory,
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, to, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, to, pair, amountB);
        liquidity = IUniswapV2Pair(pair).mint(to);
    }

    // **** REMOVE LIQUIDITY ****
    function _removeLiquidity(
        address factory,
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) private ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        IUniswapV2Pair(pair).transferFrom(to, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IUniswapV2Pair(pair).burn(to);
        (address token0, ) = UniswapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "UniswapV2Router: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "UniswapV2Router: INSUFFICIENT_B_AMOUNT");
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        address factory,
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) private {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = UniswapV2Library.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output)).swap(
                amount0Out,
                amount1Out,
                to,
                new bytes(0)
            );
        }
    }

    function _swapExactTokensForTokens(
        address factory,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) private ensure(deadline) returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(path[0], to, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(factory, amounts, path, to);
    }

    function _swapTokensForExactTokens(
        address factory,
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) private ensure(deadline) returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(path[0], to, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(factory, amounts, path, to);
    }

    //
    // PRIVATE VIEW
    //
}
