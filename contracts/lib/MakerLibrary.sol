// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { FullMath } from "@uniswap/lib/contracts/libraries/FullMath.sol";
import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { PerpMath } from "./PerpMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";
import { IPerpdexMarket } from "../interface/IPerpdexMarket.sol";
import { MarketLibrary } from "./MarketLibrary.sol";
import { PerpdexStructs } from "./PerpdexStructs.sol";
import { AccountLibrary } from "./AccountLibrary.sol";
import { TakerLibrary } from "./TakerLibrary.sol";

library MakerLibrary {
    using PerpMath for int256;
    using PerpSafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    struct AddLiquidityParams {
        address market;
        uint256 base;
        uint256 quote;
        uint256 minBase;
        uint256 minQuote;
        uint256 deadline;
        bool isMarketAllowed;
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
        uint256 deadline;
        bool makerIsSender;
        uint24 mmRatio;
        uint8 maxMarketsPerAccount;
    }

    struct RemoveLiquidityResponse {
        uint256 base;
        uint256 quote;
        int256 takerBase;
        int256 takerQuote;
        int256 realizedPnL;
        uint256 priceAfterX96;
    }

    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, "CH_TE");
        _;
    }

    function addLiquidity(PerpdexStructs.AccountInfo storage accountInfo, AddLiquidityParams memory params)
        internal
        checkDeadline(params.deadline)
        returns (AddLiquidityResponse memory)
    {
        require(params.isMarketAllowed);

        (uint256 baseShare, uint256 quoteBalance, uint256 liquidity) =
            IPerpdexMarket(params.market).addLiquidity(params.base, params.quote);

        PerpdexStructs.MakerInfo storage makerInfo = accountInfo.makerInfos[params.market];
        makerInfo.baseDebtShare = makerInfo.baseDebtShare.add(baseShare);
        makerInfo.quoteDebt = makerInfo.quoteDebt.add(quoteBalance);
        makerInfo.liquidity = makerInfo.liquidity.add(liquidity);

        AccountLibrary.updateMarkets(accountInfo, params.market, params.maxMarketsPerAccount);

        require(AccountLibrary.hasEnoughInitialMargin(accountInfo, params.imRatio));

        require(baseShare >= params.minBase);
        require(quoteBalance >= params.minQuote);

        return AddLiquidityResponse({ base: baseShare, quote: quoteBalance, liquidity: liquidity });
    }

    function removeLiquidity(PerpdexStructs.AccountInfo storage accountInfo, RemoveLiquidityParams memory params)
        internal
        checkDeadline(params.deadline)
        returns (RemoveLiquidityResponse memory funcResponse)
    {
        if (!params.makerIsSender) {
            require(!AccountLibrary.hasEnoughMaintenanceMargin(accountInfo, params.mmRatio));
        }

        {
            (uint256 resBaseShare, uint256 resQuoteBalance) =
                IPerpdexMarket(params.market).removeLiquidity(params.liquidity);

            require(resBaseShare >= params.minBase);
            require(resQuoteBalance >= params.minQuote);

            funcResponse.base = resBaseShare;
            funcResponse.quote = resQuoteBalance;
        }

        {
            (uint256 baseDebtShare, uint256 quoteDebt) =
                _removeLiquidityFromOrder(accountInfo.makerInfos[params.market], params.liquidity);
            AccountLibrary.updateMarkets(accountInfo, params.market, params.maxMarketsPerAccount);

            funcResponse.priceAfterX96 = IPerpdexMarket(params.market).getMarkPriceX96();
            funcResponse.takerBase = funcResponse.base.toInt256().sub(
                IPerpdexMarket(params.market).shareToBalance(baseDebtShare).toInt256()
            );
            funcResponse.takerQuote = funcResponse.quote.toInt256().sub(quoteDebt.toInt256());
        }

        {
            int256 takerQuoteCalculatedAtCurrentPrice =
                -funcResponse.takerBase.mulDiv(funcResponse.priceAfterX96.toInt256(), FixedPoint96.Q96);
            funcResponse.realizedPnL = TakerLibrary.addToTakerBalance(
                accountInfo,
                params.market,
                funcResponse.takerBase,
                takerQuoteCalculatedAtCurrentPrice,
                funcResponse.takerQuote.sub(takerQuoteCalculatedAtCurrentPrice),
                params.maxMarketsPerAccount
            );
        }
    }

    function _removeLiquidityFromOrder(PerpdexStructs.MakerInfo storage makerInfo, uint256 liquidity)
        private
        returns (uint256 baseDebtShare, uint256 quoteDebt)
    {
        if (liquidity != 0) {
            if (makerInfo.baseDebtShare != 0) {
                baseDebtShare = FullMath.mulDiv(makerInfo.baseDebtShare, liquidity, makerInfo.liquidity);
                makerInfo.baseDebtShare = makerInfo.baseDebtShare.sub(baseDebtShare);
            }
            if (makerInfo.quoteDebt != 0) {
                quoteDebt = FullMath.mulDiv(makerInfo.quoteDebt, liquidity, makerInfo.liquidity);
                makerInfo.quoteDebt = makerInfo.quoteDebt.sub(quoteDebt);
            }
            makerInfo.liquidity = makerInfo.liquidity.sub(liquidity);
        }

        return (baseDebtShare, quoteDebt);
    }
}
