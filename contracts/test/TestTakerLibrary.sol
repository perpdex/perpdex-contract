// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.6;
pragma abicoder v2;

import { TakerLibrary } from "../lib/TakerLibrary.sol";
import { PerpdexStructs } from "../lib/PerpdexStructs.sol";

contract TestTakerLibrary {
    constructor() {}

    event AddToTakerBalanceResult(int256 realizedPnl);
    event SwapWithProtocolFeeResult(uint256 oppositeAmount, uint256 protocolFee);
    event ProcessLiquidationRewardResult(
        uint256 liquidationPenalty,
        uint256 liquidationReward,
        uint256 insuranceFundReward
    );

    PerpdexStructs.AccountInfo public accountInfo;
    PerpdexStructs.VaultInfo public liquidatorVaultInfo;
    PerpdexStructs.InsuranceFundInfo public insuranceFundInfo;
    PerpdexStructs.ProtocolInfo public protocolInfo;

    function addToTakerBalance(
        address market,
        int256 baseShare,
        int256 quoteBalance,
        int256 quoteFee,
        uint8 maxMarketsPerAccount
    ) external {
        int256 realizedPnl =
            TakerLibrary.addToTakerBalance(
                accountInfo,
                market,
                baseShare,
                quoteBalance,
                quoteFee,
                maxMarketsPerAccount
            );
        emit AddToTakerBalanceResult(realizedPnl);
    }

    function swapWithProtocolFee(
        address market,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        uint24 protocolFeeRatio,
        bool isLiquidation
    ) external {
        (uint256 oppositeAmount, uint256 protocolFee) =
            TakerLibrary.swapWithProtocolFee(
                protocolInfo,
                market,
                isBaseToQuote,
                isExactInput,
                amount,
                protocolFeeRatio,
                isLiquidation
            );
        emit SwapWithProtocolFeeResult(oppositeAmount, protocolFee);
    }

    function previewSwapWithProtocolFee(
        address market,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        uint24 protocolFeeRatio,
        bool isLiquidation
    ) external view returns (uint256 oppositeAmount, uint256 protocolFee) {
        return
            TakerLibrary.previewSwapWithProtocolFee(
                market,
                isBaseToQuote,
                isExactInput,
                amount,
                protocolFeeRatio,
                isLiquidation
            );
    }

    function processLiquidationReward(
        uint24 mmRatio,
        PerpdexStructs.LiquidationRewardConfig memory liquidationRewardConfig,
        uint256 exchangedQuote
    ) external {
        (uint256 liquidationPenalty, uint256 liquidationReward, uint256 insuranceFundReward) =
            TakerLibrary.processLiquidationReward(
                accountInfo.vaultInfo,
                liquidatorVaultInfo,
                insuranceFundInfo,
                mmRatio,
                liquidationRewardConfig,
                exchangedQuote
            );
        emit ProcessLiquidationRewardResult(liquidationPenalty, liquidationReward, insuranceFundReward);
    }

    function validateSlippage(
        bool isExactInput,
        uint256 oppositeAmount,
        uint256 oppositeAmountBound
    ) external pure {
        TakerLibrary.validateSlippage(isExactInput, oppositeAmount, oppositeAmountBound);
    }

    function swapResponseToBaseQuote(
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        uint256 oppositeAmount
    ) external pure returns (int256, int256) {
        return TakerLibrary.swapResponseToBaseQuote(isBaseToQuote, isExactInput, amount, oppositeAmount);
    }

    function setAccountInfo(PerpdexStructs.VaultInfo memory value, address[] memory markets) external {
        accountInfo.vaultInfo = value;
        accountInfo.markets = markets;
    }

    function setLiquidatorVaultInfo(PerpdexStructs.VaultInfo memory value) external {
        liquidatorVaultInfo = value;
    }

    function setInsuranceFundInfo(PerpdexStructs.InsuranceFundInfo memory value) external {
        insuranceFundInfo = value;
    }

    function setProtocolInfo(PerpdexStructs.ProtocolInfo memory value) external {
        protocolInfo = value;
    }

    function setTakerInfo(address market, PerpdexStructs.TakerInfo memory value) external {
        accountInfo.takerInfos[market] = value;
    }

    function getTakerInfo(address market) external view returns (PerpdexStructs.TakerInfo memory) {
        return accountInfo.takerInfos[market];
    }

    function getAccountMarkets() external view returns (address[] memory) {
        return accountInfo.markets;
    }
}
