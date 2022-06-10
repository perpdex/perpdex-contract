// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { PerpMath } from "./PerpMath.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";
import { IPerpdexMarket } from "../interface/IPerpdexMarket.sol";
import { PerpdexStructs } from "./PerpdexStructs.sol";
import { AccountLibrary } from "./AccountLibrary.sol";
import { TakerLibrary } from "./TakerLibrary.sol";

library MakerLibrary {
    using PerpMath for int256;
    using SafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    struct AddLiquidityParams {
        address market;
        uint256 base;
        uint256 quote;
        uint256 minBase;
        uint256 minQuote;
        uint24 imRatio;
        uint8 maxMarketsPerAccount;
    }

    struct AddLiquidityResponse {
        uint256 base;
        uint256 quote;
        uint256 liquidity;
        uint256 cumBasePerLiquidityX96;
        uint256 cumQuotePerLiquidityX96;
    }

    struct RemoveLiquidityParams {
        address market;
        uint256 liquidity;
        uint256 minBase;
        uint256 minQuote;
        uint24 mmRatio;
        uint8 maxMarketsPerAccount;
        bool isSelf;
    }

    struct RemoveLiquidityResponse {
        uint256 base;
        uint256 quote;
        int256 takerBase;
        int256 takerQuote;
        int256 realizedPnl;
        uint256 shareMarkPriceAfterX96;
        uint256 cumBasePerLiquidityX96;
        uint256 cumQuotePerLiquidityX96;
        bool isLiquidation;
    }

    function addLiquidity(PerpdexStructs.AccountInfo storage accountInfo, AddLiquidityParams memory params)
        internal
        returns (AddLiquidityResponse memory response)
    {
        PerpdexStructs.MakerInfo storage makerInfo = accountInfo.makerInfos[params.market];

        (response.base, response.quote, response.liquidity) = IPerpdexMarket(params.market).addLiquidity(
            params.base,
            params.quote
        );

        require(response.base >= params.minBase, "ML_AL: too small output base");
        require(response.quote >= params.minQuote, "ML_AL: too small output quote");

        (response.cumBasePerLiquidityX96, response.cumQuotePerLiquidityX96) = IPerpdexMarket(params.market)
            .getCumDeleveragedPerLiquidityX96();

        uint256 liquidityBefore = makerInfo.liquidity;
        makerInfo.liquidity = liquidityBefore.add(response.liquidity);
        {
            makerInfo.cumBaseSharePerLiquidityX96 = blendCumPerLiquidity(
                liquidityBefore,
                response.liquidity,
                response.base,
                makerInfo.cumBaseSharePerLiquidityX96,
                response.cumBasePerLiquidityX96
            );
            makerInfo.cumQuotePerLiquidityX96 = blendCumPerLiquidity(
                liquidityBefore,
                response.liquidity,
                response.quote,
                makerInfo.cumQuotePerLiquidityX96,
                response.cumQuotePerLiquidityX96
            );
        }

        AccountLibrary.updateMarkets(accountInfo, params.market, params.maxMarketsPerAccount);

        require(AccountLibrary.hasEnoughInitialMargin(accountInfo, params.imRatio), "ML_AL: not enough im");
    }

    // difficult to calculate without error
    // underestimate the value to maintain the liquidation free condition
    // the error will be a burden to the insurance fund
    // the error is much smaller than the gas fee, so it is impossible to attack
    function blendCumPerLiquidity(
        uint256 liquidityBefore,
        uint256 addedLiquidity,
        uint256 addedToken,
        uint256 cumBefore,
        uint256 cumAfter
    ) internal pure returns (uint256) {
        uint256 liquidityAfter = liquidityBefore.add(addedLiquidity);
        cumAfter = cumAfter.add(FullMath.mulDiv(addedToken, FixedPoint96.Q96, addedLiquidity));

        return
            FullMath.mulDiv(cumBefore, liquidityBefore, liquidityAfter).add(
                FullMath.mulDiv(cumAfter, addedLiquidity, liquidityAfter)
            );
    }

    function removeLiquidity(PerpdexStructs.AccountInfo storage accountInfo, RemoveLiquidityParams memory params)
        internal
        returns (RemoveLiquidityResponse memory response)
    {
        response.isLiquidation = !AccountLibrary.hasEnoughMaintenanceMargin(accountInfo, params.mmRatio);

        if (!params.isSelf) {
            require(response.isLiquidation, "ML_RL: enough mm");
        }

        {
            PerpdexStructs.MakerInfo storage makerInfo = accountInfo.makerInfos[params.market];
            (response.takerBase, response.takerQuote) = IPerpdexMarket(params.market).getLiquidityDeleveraged(
                params.liquidity,
                makerInfo.cumBaseSharePerLiquidityX96,
                makerInfo.cumQuotePerLiquidityX96
            );
        }

        {
            (response.base, response.quote) = IPerpdexMarket(params.market).removeLiquidity(params.liquidity);

            require(response.base >= params.minBase, "ML_RL: too small output base");
            require(response.quote >= params.minQuote, "ML_RL: too small output base");

            response.takerBase = response.takerBase.add(response.base.toInt256());
            response.takerQuote = response.takerQuote.add(response.quote.toInt256());

            PerpdexStructs.MakerInfo storage makerInfo = accountInfo.makerInfos[params.market];
            makerInfo.liquidity = makerInfo.liquidity.sub(params.liquidity);
        }

        {
            response.shareMarkPriceAfterX96 = IPerpdexMarket(params.market).getMarkPriceX96();
            int256 takerQuoteCalculatedAtCurrentPrice =
                -response.takerBase.mulDiv(response.shareMarkPriceAfterX96.toInt256(), FixedPoint96.Q96);

            // AccountLibrary.updateMarkets called
            response.realizedPnl = TakerLibrary.addToTakerBalance(
                accountInfo,
                params.market,
                response.takerBase,
                takerQuoteCalculatedAtCurrentPrice,
                response.takerQuote.sub(takerQuoteCalculatedAtCurrentPrice),
                params.maxMarketsPerAccount
            );
        }
    }
}
