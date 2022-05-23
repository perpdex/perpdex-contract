// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { UniswapV2Broker } from "./UniswapV2Broker.sol";
import { IBaseTokenNew } from "../interface/IBaseTokenNew.sol";
import { PerpMath } from "./PerpMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";
import { BaseTokenLibrary } from "./BaseTokenLibrary.sol";
import "./PerpdexStructs.sol";
import "./AccountLibrary.sol";
import "./PriceLimitLibrary.sol";

// internal
library TakerLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
    using PerpSafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    struct OpenPositionParams {
        address baseToken;
        address quoteToken;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
        address poolFactory;
        PerpdexStructs.PriceLimitConfig priceLimitConfig;
        bool isBaseTokenAllowed;
        uint24 mmRatio;
        uint24 imRatio;
        uint8 maxMarketsPerAccount;
    }

    struct OpenPositionResponse {
        int256 exchangedBase;
        int256 exchangedQuote;
        int256 realizedPnL;
        uint256 priceAfterX96;
    }

    struct LiquidateParams {
        address baseToken;
        address quoteToken;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
        address poolFactory;
        PerpdexStructs.PriceLimitConfig priceLimitConfig;
        uint24 mmRatio;
        uint24 liquidationRewardRatio;
        uint8 maxMarketsPerAccount;
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
        OpenPositionParams memory params
    ) internal checkDeadline(params.deadline) returns (OpenPositionResponse memory) {
        require(
            !AccountLibrary.hasEnoughMaintenanceMargin(
                accountInfo,
                params.poolFactory,
                params.quoteToken,
                params.mmRatio
            )
        );

        (int256 exchangedBase, int256 exchangedQuote, int256 realizedPnL) =
            _doSwap(
                accountInfo,
                priceLimitInfo,
                params.poolFactory,
                params.baseToken,
                params.quoteToken,
                params.isBaseToQuote,
                params.isExactInput,
                params.amount,
                params.maxMarketsPerAccount
            );

        if (!params.isBaseTokenAllowed) {
            require(accountInfo.takerInfo[params.baseToken].baseBalanceShare.sign() * exchangedBase.sign() <= 0);
        }

        uint256 priceAfterX96 = _getPriceX96(params.poolFactory, params.baseToken, params.quoteToken);
        require(PriceLimitLibrary.isNormalOrderAllowed(priceLimitInfo, params.priceLimitConfig, priceAfterX96));

        require(
            AccountLibrary.hasEnoughInitialMargin(accountInfo, params.poolFactory, params.quoteToken, params.imRatio)
        );

        return
            OpenPositionResponse({
                exchangedBase: exchangedBase,
                exchangedQuote: exchangedQuote,
                realizedPnL: realizedPnL,
                priceAfterX96: priceAfterX96
            });
    }

    function liquidate(
        PerpdexStructs.AccountInfo storage accountInfo,
        PerpdexStructs.AccountInfo storage liquidatorAccountInfo,
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        PerpdexStructs.InsuranceFundInfo storage insuranceFundInfo,
        LiquidateParams memory params
    ) internal checkDeadline(params.deadline) returns (LiquidateResponse memory) {
        require(
            !AccountLibrary.hasEnoughMaintenanceMargin(
                accountInfo,
                params.poolFactory,
                params.quoteToken,
                params.mmRatio
            )
        );

        bool isLong;
        {
            PerpdexStructs.TakerInfo storage takerInfo = accountInfo.takerInfo[params.baseToken];
            isLong = takerInfo.baseBalanceShare > 0 ? true : false;
            require(params.amount <= IBaseTokenNew(params.baseToken).shareToBalance(takerInfo.baseBalanceShare.abs()));
        }

        (int256 exchangedBase, int256 exchangedQuote, int256 realizedPnL) =
            _doSwap(
                accountInfo,
                priceLimitInfo,
                params.poolFactory,
                params.baseToken,
                params.quoteToken,
                isLong, // isBaseToQuote,
                isLong, // isExactInput,
                params.amount,
                params.maxMarketsPerAccount
            );

        uint256 priceAfterX96 = _getPriceX96(params.poolFactory, params.baseToken, params.quoteToken);
        require(PriceLimitLibrary.isLiquidationAllowed(priceLimitInfo, params.priceLimitConfig, priceAfterX96));

        _processLiquidationFee(
            accountInfo.vaultInfo,
            liquidatorAccountInfo.vaultInfo,
            insuranceFundInfo,
            params.mmRatio,
            params.liquidationRewardRatio,
            exchangedQuote.abs()
        );

        return
            LiquidateResponse({
                exchangedBase: exchangedBase,
                exchangedQuote: exchangedQuote,
                realizedPnL: realizedPnL,
                priceAfterX96: priceAfterX96
            });
    }

    function addToTakerBalance(
        PerpdexStructs.AccountInfo storage accountInfo,
        address baseToken,
        int256 baseBalance,
        int256 quoteBalance,
        int256 quoteFee,
        uint8 maxMarketsPerAccount
    ) internal returns (int256) {
        require(baseBalance.sign() * quoteBalance.sign() == -1);

        int256 baseShare = BaseTokenLibrary.balanceToShare(baseToken, baseBalance);
        PerpdexStructs.TakerInfo storage takerInfo = accountInfo.takerInfo[baseToken];

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

        AccountLibrary.updateBaseTokens(accountInfo, baseToken, maxMarketsPerAccount);

        return realizedPnL;
    }

    function _getPriceX96(
        address poolFactory,
        address baseToken,
        address quoteToken
    ) private returns (uint256) {
        return UniswapV2Broker.getMarkPriceX96(poolFactory, baseToken, quoteToken);
    }

    function _doSwap(
        PerpdexStructs.AccountInfo storage accountInfo,
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        address poolFactory,
        address baseToken,
        address quoteToken,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        uint8 maxMarketsPerAccount
    )
        private
        returns (
            int256,
            int256,
            int256
        )
    {
        {
            uint256 priceBeforeX96 = _getPriceX96(poolFactory, baseToken, quoteToken);
            PriceLimitLibrary.update(priceLimitInfo, priceBeforeX96);
        }

        int256 exchangedPositionSize;
        int256 exchangedPositionNotional;

        {
            UniswapV2Broker.SwapResponse memory response =
                UniswapV2Broker.swap(
                    UniswapV2Broker.SwapParams(
                        poolFactory,
                        baseToken,
                        quoteToken,
                        address(this), // recipient
                        isBaseToQuote,
                        isExactInput,
                        amount // amount
                    )
                );

            if (isBaseToQuote) {
                // short: exchangedPositionSize <= 0 && exchangedPositionNotional >= 0
                exchangedPositionSize = response.base.neg256();
                exchangedPositionNotional = response.quote.toInt256();
            } else {
                // long: exchangedPositionSize >= 0 && exchangedPositionNotional <= 0
                exchangedPositionSize = response.base.toInt256();
                exchangedPositionNotional = response.quote.neg256();
            }
        }

        int256 realizedPnL =
            addToTakerBalance(
                accountInfo,
                baseToken,
                exchangedPositionSize,
                exchangedPositionNotional,
                0,
                maxMarketsPerAccount
            );

        return (exchangedPositionSize, exchangedPositionNotional, realizedPnL);
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
}
