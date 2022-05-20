// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { UniswapV2Broker } from "./UniswapV2Broker.sol";
import { IBaseToken } from "../interface/IBaseToken.sol";
import "./PerpdexStructs.sol";
import "./AccountLibrary.sol";
import "./PriceLimitLibrary.sol";

library TakerLibrary {
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
        address baseToken;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
        address poolFactory;
        PerpdexStructs.PriceLimitConfig priceLimitConfig;
    }

    struct ClosePositionParams {
        address baseToken;
        address quoteToken;
        uint256 oppositeAmountBound;
        uint256 deadline;
        address poolFactory;
        PerpdexStructs.PriceLimitConfig priceLimitConfig;
    }

    struct LiquidateParams {
        address baseToken;
        address quoteToken;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
        address poolFactory;
        PerpdexStructs.PriceLimitConfig priceLimitConfig;
    }

    modifier checkDeadline(uint256 deadline) {
        // transaction expires
        require(block.timestamp <= deadline, "CH_TE");
        _;
    }

    function openPosition(
        PerpdexStructs.AccountInfo storage accountInfo,
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        OpenPositionParams memory params
    ) public checkDeadline(params.deadline) returns (uint256) {
        require(!AccountLibrary.isLiquidatable(accountInfo));

        uint256 price;
        PriceLimitLibrary.update(priceLimitInfo, price);
        require(PriceLimitLibrary.isNormalOrderAllowed(priceLimitInfo, params.priceLimitConfig, price));

        _doSwap(
            accountInfo.takerInfo[params.baseToken],
            params.poolFactory,
            params.baseToken,
            params.quoteToken,
            params.isBaseToQuote,
            params.isExactInput,
            params.amount
        );

        require(PriceLimitLibrary.isNormalOrderAllowed(priceLimitInfo, params.priceLimitConfig, price));

        require(AccountLibrary.hasEnoughInitialMargin(accountInfo));

        return 0;
    }

    function closePosition(
        PerpdexStructs.AccountInfo storage accountInfo,
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        ClosePositionParams memory params
    ) public checkDeadline(params.deadline) returns (uint256) {
        require(!AccountLibrary.isLiquidatable(accountInfo));

        uint256 price;
        PriceLimitLibrary.update(priceLimitInfo, price);
        require(PriceLimitLibrary.isNormalOrderAllowed(priceLimitInfo, params.priceLimitConfig, price));

        PerpdexStructs.TakerInfo storage takerInfo = accountInfo.takerInfo[params.baseToken];
        bool isLong = takerInfo.baseBalanceShare > 0 ? true : false;
        uint256 amount = IBaseToken(params.baseToken).shareToBalance(takerInfo.baseBalanceShare.abs());

        _doSwap(
            takerInfo,
            params.poolFactory,
            params.baseToken,
            params.quoteToken,
            isLong, // isBaseToQuote,
            isLong, // isExactInput,
            amount
        );

        require(PriceLimitLibrary.isNormalOrderAllowed(priceLimitInfo, params.priceLimitConfig, price));

        return 0;
    }

    function liquidate(
        PerpdexStructs.AccountInfo storage accountInfo,
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        LiquidateParams memory params
    ) public checkDeadline(params.deadline) returns (uint256) {
        require(AccountLibrary.isLiquidatable(accountInfo));

        uint256 price;
        PriceLimitLibrary.update(priceLimitInfo, price);
        require(PriceLimitLibrary.isLiquidationAllowed(priceLimitInfo, params.priceLimitConfig, price));

        PerpdexStructs.TakerInfo storage takerInfo = accountInfo.takerInfo[params.baseToken];
        bool isLong = takerInfo.baseBalanceShare > 0 ? true : false;
        require(params.amount <= IBaseToken(params.baseToken).shareToBalance(takerInfo.baseBalanceShare.abs()));

        (int256 base, int256 quote) =
            _doSwap(
                takerInfo,
                params.poolFactory,
                params.baseToken,
                params.quoteToken,
                isLong, // isBaseToQuote,
                isLong, // isExactInput,
                params.amount
            );

        require(PriceLimitLibrary.isLiquidationAllowed(priceLimitInfo, params.priceLimitConfig, price));

        // TODO: liquidation
        //        _processLiquidationFee();

        return 0;
    }

    function _doSwap(
        PerpdexStructs.TakerInfo storage takerInfo,
        address poolFactory,
        address baseToken,
        address quoteToken,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount
    ) private returns (int256 base, int256 quote) {
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

        return (exchangedPositionSize, exchangedPositionNotional);
    }

    //    function _processLiquidationFee(
    //        address trader,
    //        address liquidator,
    //        int256 exchangedPositionNotional
    //    ) private returns (uint256) {
    //        // trader's pnl-- as liquidation penalty
    //        uint256 liquidationFee =
    //        exchangedPositionNotional.abs().mulRatio(
    //            IClearingHouseConfig(_clearingHouseConfig).getLiquidationPenaltyRatio()
    //        );
    //
    //        IAccountBalance(_accountBalance).modifyOwedRealizedPnl(trader, liquidationFee.neg256());
    //
    //        uint256 liquidatorReward = liquidationFee / 2;
    //        uint256 insuranceFundReward = liquidationFee - liquidatorReward;
    //
    //        // increase liquidator's pnl liquidation reward
    //        IAccountBalance(_accountBalance).modifyOwedRealizedPnl(liquidator, liquidatorReward.toInt256());
    //        IAccountBalance(_accountBalance).modifyOwedRealizedPnl(_insuranceFund, insuranceFundReward.toInt256());
    //
    //        return liquidationFee;
    //    }

    function addToTakerBalance(
        PerpdexStructs.TakerInfo storage takerInfo,
        address baseToken,
        int256 baseBalance,
        int256 quoteBalance
    ) public {
        int256 share;
        if (baseBalance < 0) {
            share = -IBaseToken(baseToken).balanceToShare((-baseBalance));
        } else {
            share = IBaseToken(baseToken).balanceToShare(baseBalance);
        }
        takerInfo.baseBalanceShare = takerInfo.baseBalanceShare.add(share);
        takerInfo.quoteBalance = takerInfo.quoteBalance.add(quoteBalance);
    }
}
