// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { UniswapV2Broker } from "./UniswapV2Broker.sol";
import { IBaseTokenNew } from "../interface/IBaseTokenNew.sol";
import { PerpMath } from "./PerpMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";
import "./PerpdexStructs.sol";
import "./AccountLibrary.sol";
import "./PriceLimitLibrary.sol";

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
        OpenPositionParams calldata params
    ) public checkDeadline(params.deadline) returns (OpenPositionResponse memory) {
        require(!AccountLibrary.isLiquidatable(accountInfo));

        (int256 exchangedBase, int256 exchangedQuote, int256 realizedPnL) =
            _doSwap(
                accountInfo.takerInfo[params.baseToken],
                priceLimitInfo,
                params.poolFactory,
                params.baseToken,
                params.quoteToken,
                params.isBaseToQuote,
                params.isExactInput,
                params.amount
            );

        uint256 priceAfterX96 = _getPriceX96(params.poolFactory, params.baseToken, params.quoteToken);
        require(PriceLimitLibrary.isNormalOrderAllowed(priceLimitInfo, params.priceLimitConfig, priceAfterX96));

        require(AccountLibrary.hasEnoughInitialMargin(accountInfo));

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
        LiquidateParams calldata params
    ) public checkDeadline(params.deadline) returns (LiquidateResponse memory) {
        require(AccountLibrary.isLiquidatable(accountInfo));

        PerpdexStructs.TakerInfo storage takerInfo = accountInfo.takerInfo[params.baseToken];
        bool isLong = takerInfo.baseBalanceShare > 0 ? true : false;
        require(params.amount <= IBaseTokenNew(params.baseToken).shareToBalance(takerInfo.baseBalanceShare.abs()));

        (int256 exchangedBase, int256 exchangedQuote, int256 realizedPnL) =
            _doSwap(
                takerInfo,
                priceLimitInfo,
                params.poolFactory,
                params.baseToken,
                params.quoteToken,
                isLong, // isBaseToQuote,
                isLong, // isExactInput,
                params.amount
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
        PerpdexStructs.TakerInfo storage takerInfo,
        address baseToken,
        int256 baseBalance,
        int256 quoteBalance
    ) public {
        int256 share;
        if (baseBalance < 0) {
            share = IBaseTokenNew(baseToken).balanceToShare(baseBalance.abs()).neg256();
        } else {
            share = IBaseTokenNew(baseToken).balanceToShare(baseBalance.abs()).toInt256();
        }
        takerInfo.baseBalanceShare = takerInfo.baseBalanceShare.add(share);
        takerInfo.quoteBalance = takerInfo.quoteBalance.add(quoteBalance);
    }

    function _getPriceX96(
        address poolFactory,
        address baseToken,
        address quoteToken
    ) private returns (uint256) {
        return UniswapV2Broker.getMarkPriceX96(poolFactory, baseToken, quoteToken);
    }

    function _doSwap(
        PerpdexStructs.TakerInfo storage takerInfo,
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        address poolFactory,
        address baseToken,
        address quoteToken,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount
    )
        private
        returns (
            int256,
            int256,
            int256
        )
    {
        uint256 priceBeforeX96 = _getPriceX96(poolFactory, baseToken, quoteToken);
        PriceLimitLibrary.update(priceLimitInfo, priceBeforeX96);

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

        int256 exchangedPositionSize;
        int256 exchangedPositionNotional;
        if (isBaseToQuote) {
            // short: exchangedPositionSize <= 0 && exchangedPositionNotional >= 0
            exchangedPositionSize = response.base.neg256();
            exchangedPositionNotional = response.quote.toInt256();
        } else {
            // long: exchangedPositionSize >= 0 && exchangedPositionNotional <= 0
            exchangedPositionSize = response.base.toInt256();
            exchangedPositionNotional = response.quote.neg256();
        }

        addToTakerBalance(takerInfo, baseToken, exchangedPositionSize, exchangedPositionNotional);

        int256 realizedPnL = 0; // TODO: implement

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
