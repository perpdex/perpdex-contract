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
        bool isLiquidation;
    }

    function addLiquidity(PerpdexStructs.AccountInfo storage accountInfo, AddLiquidityParams memory params)
        internal
        returns (AddLiquidityResponse memory)
    {
        PerpdexStructs.MakerInfo storage makerInfo = accountInfo.makerInfos[params.market];
        _applyDeleveraged(makerInfo, params.market);

        (uint256 baseShare, uint256 quoteBalance, uint256 liquidity) =
            IPerpdexMarket(params.market).addLiquidity(params.base, params.quote);

        require(baseShare >= params.minBase, "ML_AL: too small output base");
        require(quoteBalance >= params.minQuote, "ML_AL: too small output quote");

        (uint256 cumDeleveragedBaseSharePerLiquidityX96, uint256 cumDeleveragedQuotePerLiquidityX96) =
            IPerpdexMarket(params.market).getCumDeleveragedPerLiquidityX96();

        makerInfo.baseDebtShare = makerInfo.baseDebtShare.add(baseShare.toInt256());
        makerInfo.quoteDebt = makerInfo.quoteDebt.add(quoteBalance.toInt256());
        makerInfo.liquidity = makerInfo.liquidity.add(liquidity);
        makerInfo.cumDeleveragedBaseSharePerLiquidityX96 = cumDeleveragedBaseSharePerLiquidityX96;
        makerInfo.cumDeleveragedQuotePerLiquidityX96 = cumDeleveragedQuotePerLiquidityX96;

        AccountLibrary.updateMarkets(accountInfo, params.market, params.maxMarketsPerAccount);

        require(AccountLibrary.hasEnoughInitialMargin(accountInfo, params.imRatio), "ML_AL: not enough im");

        return AddLiquidityResponse({ base: baseShare, quote: quoteBalance, liquidity: liquidity });
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
            _applyDeleveraged(accountInfo.makerInfos[params.market], params.market);
        }

        {
            (response.base, response.quote) = IPerpdexMarket(params.market).removeLiquidity(params.liquidity);

            require(response.base >= params.minBase, "ML_RL: too small output base");
            require(response.quote >= params.minQuote, "ML_RL: too small output base");
        }

        {
            (uint256 cumDeleveragedBaseSharePerLiquidityX96, uint256 cumDeleveragedQuotePerLiquidityX96) =
                IPerpdexMarket(params.market).getCumDeleveragedPerLiquidityX96();

            PerpdexStructs.MakerInfo storage makerInfo = accountInfo.makerInfos[params.market];
            makerInfo.cumDeleveragedBaseSharePerLiquidityX96 = cumDeleveragedBaseSharePerLiquidityX96;
            makerInfo.cumDeleveragedQuotePerLiquidityX96 = cumDeleveragedQuotePerLiquidityX96;
        }

        {
            (int256 baseDebtShare, int256 quoteDebt) =
                _removeLiquidityFromOrder(accountInfo.makerInfos[params.market], params.liquidity);
            AccountLibrary.updateMarkets(accountInfo, params.market, params.maxMarketsPerAccount);

            response.takerBase = response.base.toInt256().sub(baseDebtShare);
            response.takerQuote = response.quote.toInt256().sub(quoteDebt);
        }

        {
            uint256 shareMarkPriceX96 = IPerpdexMarket(params.market).getMarkPriceX96();
            int256 takerQuoteCalculatedAtCurrentPrice =
                -response.takerBase.mulDiv(shareMarkPriceX96.toInt256(), FixedPoint96.Q96);
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

    function _applyDeleveraged(PerpdexStructs.MakerInfo storage makerInfo, address market) private {
        (uint256 deleveragedBaseShare, uint256 deleveragedQuoteBalance) =
            IPerpdexMarket(market).getLiquidityDeleveraged(
                makerInfo.liquidity,
                makerInfo.cumDeleveragedBaseSharePerLiquidityX96,
                makerInfo.cumDeleveragedQuotePerLiquidityX96
            );
        makerInfo.baseDebtShare = makerInfo.baseDebtShare.sub(deleveragedBaseShare.toInt256());
        makerInfo.quoteDebt = makerInfo.quoteDebt.sub(deleveragedQuoteBalance.toInt256());
    }

    function _removeLiquidityFromOrder(PerpdexStructs.MakerInfo storage makerInfo, uint256 liquidity)
        private
        returns (int256 baseDebtShare, int256 quoteDebt)
    {
        baseDebtShare = makerInfo.baseDebtShare.mulDiv(liquidity.toInt256(), makerInfo.liquidity);
        makerInfo.baseDebtShare = makerInfo.baseDebtShare.sub(baseDebtShare);

        quoteDebt = makerInfo.quoteDebt.mulDiv(liquidity.toInt256(), makerInfo.liquidity);
        makerInfo.quoteDebt = makerInfo.quoteDebt.sub(quoteDebt);

        makerInfo.liquidity = makerInfo.liquidity.sub(liquidity);

        return (baseDebtShare, quoteDebt);
    }
}
