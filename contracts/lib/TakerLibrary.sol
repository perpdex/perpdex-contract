// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { PerpMath } from "./PerpMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";
import { IPerpdexMarket } from "../interface/IPerpdexMarket.sol";
import { MarketLibrary } from "./MarketLibrary.sol";
import { PerpdexStructs } from "./PerpdexStructs.sol";
import { AccountLibrary } from "./AccountLibrary.sol";
import { PriceLimitLibrary } from "./PriceLimitLibrary.sol";

library TakerLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
    using PerpSafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    struct OpenPositionParams {
        address market;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
        PerpdexStructs.PriceLimitConfig priceLimitConfig;
        bool isMarketAllowed;
        uint24 mmRatio;
        uint24 imRatio;
        uint8 maxMarketsPerAccount;
        uint24 protocolFeeRatio;
    }

    struct OpenPositionResponse {
        int256 exchangedBase;
        int256 exchangedQuote;
        int256 realizedPnL;
        uint256 priceAfterX96;
    }

    struct LiquidateParams {
        address market;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
        PerpdexStructs.PriceLimitConfig priceLimitConfig;
        uint24 mmRatio;
        uint24 liquidationRewardRatio;
        uint8 maxMarketsPerAccount;
        uint24 protocolFeeRatio;
    }

    struct LiquidateResponse {
        int256 exchangedBase;
        int256 exchangedQuote;
        int256 realizedPnL;
        uint256 priceAfterX96;
    }

    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, "CH_TE");
        _;
    }

    function openPosition(
        PerpdexStructs.AccountInfo storage accountInfo,
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        PerpdexStructs.ProtocolInfo storage protocolInfo,
        OpenPositionParams memory params
    ) internal checkDeadline(params.deadline) returns (OpenPositionResponse memory) {
        require(!AccountLibrary.hasEnoughMaintenanceMargin(accountInfo, params.mmRatio));

        (int256 exchangedBase, int256 exchangedQuote, int256 realizedPnL) =
            _doSwap(
                accountInfo,
                priceLimitInfo,
                protocolInfo,
                params.market,
                params.isBaseToQuote,
                params.isExactInput,
                params.amount,
                params.oppositeAmountBound,
                params.maxMarketsPerAccount,
                params.protocolFeeRatio
            );

        if (!params.isMarketAllowed) {
            require(accountInfo.takerInfos[params.market].baseBalanceShare.sign() * exchangedBase.sign() <= 0);
        }

        uint256 priceAfterX96 = _getPriceX96(params.market);
        require(PriceLimitLibrary.isNormalOrderAllowed(priceLimitInfo, params.priceLimitConfig, priceAfterX96));

        require(AccountLibrary.hasEnoughInitialMargin(accountInfo, params.imRatio));

        return
            OpenPositionResponse({
                exchangedBase: exchangedBase,
                exchangedQuote: exchangedQuote,
                realizedPnL: realizedPnL,
                priceAfterX96: priceAfterX96
            });
    }

    function openPositionDry(
        PerpdexStructs.AccountInfo storage accountInfo,
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        OpenPositionParams memory params
    ) internal view checkDeadline(params.deadline) returns (OpenPositionResponse memory) {
        require(!AccountLibrary.hasEnoughMaintenanceMargin(accountInfo, params.mmRatio));

        (int256 exchangedBase, int256 exchangedQuote) =
            _doSwapDry(
                accountInfo,
                priceLimitInfo,
                params.market,
                params.isBaseToQuote,
                params.isExactInput,
                params.amount,
                params.oppositeAmountBound,
                params.maxMarketsPerAccount
            );

        if (!params.isMarketAllowed) {
            require(accountInfo.takerInfos[params.market].baseBalanceShare.sign() * exchangedBase.sign() <= 0);
        }

        // disable price limit

        require(AccountLibrary.hasEnoughInitialMargin(accountInfo, params.imRatio));

        return
            OpenPositionResponse({
                exchangedBase: exchangedBase,
                exchangedQuote: exchangedQuote,
                realizedPnL: 0,
                priceAfterX96: 0
            });
    }

    function liquidate(
        PerpdexStructs.AccountInfo storage accountInfo,
        PerpdexStructs.AccountInfo storage liquidatorAccountInfo,
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        PerpdexStructs.ProtocolInfo storage protocolInfo,
        PerpdexStructs.InsuranceFundInfo storage insuranceFundInfo,
        LiquidateParams memory params
    ) internal checkDeadline(params.deadline) returns (LiquidateResponse memory result) {
        require(!AccountLibrary.hasEnoughMaintenanceMargin(accountInfo, params.mmRatio));

        bool isLong;
        {
            PerpdexStructs.TakerInfo storage takerInfo = accountInfo.takerInfos[params.market];
            isLong = takerInfo.baseBalanceShare > 0 ? true : false;
            require(params.amount <= takerInfo.baseBalanceShare.abs());
        }

        (result.exchangedBase, result.exchangedQuote, result.realizedPnL) = _doSwap(
            accountInfo,
            priceLimitInfo,
            protocolInfo,
            params.market,
            isLong, // isBaseToQuote,
            isLong, // isExactInput,
            params.amount,
            params.oppositeAmountBound,
            params.maxMarketsPerAccount,
            params.protocolFeeRatio
        );

        result.priceAfterX96 = _getPriceX96(params.market);
        require(PriceLimitLibrary.isLiquidationAllowed(priceLimitInfo, params.priceLimitConfig, result.priceAfterX96));

        _processLiquidationFee(
            accountInfo.vaultInfo,
            liquidatorAccountInfo.vaultInfo,
            insuranceFundInfo,
            params.mmRatio,
            params.liquidationRewardRatio,
            result.exchangedQuote.abs()
        );
    }

    function addToTakerBalance(
        PerpdexStructs.AccountInfo storage accountInfo,
        address market,
        int256 baseShare,
        int256 quoteBalance,
        int256 quoteFee,
        uint8 maxMarketsPerAccount
    ) internal returns (int256) {
        require(baseShare.sign() * quoteBalance.sign() == -1);

        PerpdexStructs.TakerInfo storage takerInfo = accountInfo.takerInfos[market];

        int256 realizedPnL;

        if (takerInfo.baseBalanceShare.sign() * baseShare.sign() == -1) {
            uint256 FULLY_CLOSED_RATIO = 1e18;
            uint256 closedRatio =
                FullMath.mulDiv(baseShare.abs(), FULLY_CLOSED_RATIO, takerInfo.baseBalanceShare.abs());

            if (closedRatio <= FULLY_CLOSED_RATIO) {
                int256 reducedOpenNotional = takerInfo.quoteBalance.mulDiv(closedRatio.toInt256(), FULLY_CLOSED_RATIO);
                realizedPnL = quoteBalance.add(reducedOpenNotional).add(quoteFee);
            } else {
                int256 closedPositionNotional = quoteBalance.mulDiv(int256(FULLY_CLOSED_RATIO), closedRatio);
                realizedPnL = takerInfo.quoteBalance.add(closedPositionNotional).add(quoteFee);
            }
        } else {
            realizedPnL = quoteFee;
        }

        takerInfo.baseBalanceShare = takerInfo.baseBalanceShare.add(baseShare);
        takerInfo.quoteBalance = takerInfo.quoteBalance.add(quoteBalance).add(quoteFee).sub(realizedPnL);
        accountInfo.vaultInfo.collateralBalance = accountInfo.vaultInfo.collateralBalance.add(realizedPnL);

        AccountLibrary.updateMarkets(accountInfo, market, maxMarketsPerAccount);

        return realizedPnL;
    }

    function _getPriceX96(address market) private view returns (uint256) {
        return IPerpdexMarket(market).getMarkPriceX96();
    }

    function _doSwap(
        PerpdexStructs.AccountInfo storage accountInfo,
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        PerpdexStructs.ProtocolInfo storage protocolInfo,
        address market,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        uint256 oppositeAmountBound,
        uint8 maxMarketsPerAccount,
        uint24 protocolFeeRatio
    )
        private
        returns (
            int256 base,
            int256 quote,
            int256 realizedPnL
        )
    {
        {
            uint256 priceBeforeX96 = _getPriceX96(market);
            PriceLimitLibrary.update(priceLimitInfo, priceBeforeX96);
        }

        if (protocolFeeRatio > 0) {
            (base, quote) = _swapWithProtocolFee(
                protocolInfo,
                market,
                isBaseToQuote,
                isExactInput,
                amount,
                protocolFeeRatio
            );
        } else {
            (base, quote) = MarketLibrary.swap(market, isBaseToQuote, isExactInput, amount);
        }

        _validateSlippage(isBaseToQuote, isExactInput, base, quote, oppositeAmountBound);

        realizedPnL = addToTakerBalance(accountInfo, market, base, quote, 0, maxMarketsPerAccount);
    }

    function _swapWithProtocolFee(
        PerpdexStructs.ProtocolInfo storage protocolInfo,
        address market,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        uint24 protocolFeeRatio
    ) private returns (int256 base, int256 quote) {
        uint256 protocolFee;

        if (isBaseToQuote == isExactInput) {
            // exact base
            (base, quote) = MarketLibrary.swap(market, isBaseToQuote, isExactInput, amount);

            protocolFee = quote.abs().mulRatio(protocolFeeRatio);
            quote = quote.sub(protocolFee.toInt256());
        } else {
            // exact quote
            protocolFee = amount - amount.divRatio(1e6 + protocolFeeRatio);

            (base, ) = MarketLibrary.swap(market, isBaseToQuote, isExactInput, amount.sub(protocolInfo.protocolFee));
            quote = isBaseToQuote ? amount.toInt256() : amount.neg256();
        }

        protocolInfo.protocolFee = protocolInfo.protocolFee.add(protocolFee);
    }

    function _doSwapDry(
        PerpdexStructs.AccountInfo storage accountInfo,
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        address market,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        uint256 oppositeAmountBound,
        uint8 maxMarketsPerAccount
    ) private view returns (int256 base, int256 quote) {
        // disable price limit

        (base, quote) = MarketLibrary.swapDry(market, isBaseToQuote, isExactInput, amount);

        _validateSlippage(isBaseToQuote, isExactInput, base, quote, oppositeAmountBound);
    }

    function _processLiquidationFee(
        PerpdexStructs.VaultInfo storage vaultInfo,
        PerpdexStructs.VaultInfo storage liquidatorVaultInfo,
        PerpdexStructs.InsuranceFundInfo storage insuranceFundInfo,
        uint24 mmRatio,
        uint24 liquidatorRewardRatio,
        uint256 exchangedQuote
    ) private returns (uint256) {
        uint256 penalty = exchangedQuote.mulRatio(mmRatio);
        uint256 liquidatorReward = penalty.mulRatio(liquidatorRewardRatio);
        uint256 insuranceFundReward = penalty.sub(liquidatorReward);

        vaultInfo.collateralBalance = vaultInfo.collateralBalance.sub(penalty.toInt256());
        liquidatorVaultInfo.collateralBalance = liquidatorVaultInfo.collateralBalance.add(liquidatorReward.toInt256());
        insuranceFundInfo.balance = insuranceFundInfo.balance.add(insuranceFundReward.toInt256());

        return penalty;
    }

    function _validateSlippage(
        bool isBaseToQuote,
        bool isExactInput,
        int256 base,
        int256 quote,
        uint256 oppositeAmountBound
    ) private pure {
        uint256 oppositeAmount = isBaseToQuote == isExactInput ? quote.abs() : base.abs();
        if (isExactInput) {
            require(oppositeAmount >= oppositeAmountBound);
        } else {
            require(oppositeAmount <= oppositeAmountBound);
        }
    }
}
