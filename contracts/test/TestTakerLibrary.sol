// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { TakerLibrary } from "../lib/TakerLibrary.sol";
import { PerpdexStructs } from "../lib/PerpdexStructs.sol";

contract TestTakerLibrary {
    constructor() {}

    event AddToTakerBalanceResult(int256 realizedPnl);
    event ProcessLiquidationFeeResult(uint256 liquidatorReward, uint256 insuranceFundReward);

    PerpdexStructs.AccountInfo public accountInfo;
    PerpdexStructs.VaultInfo public liquidatorVaultInfo;
    PerpdexStructs.InsuranceFundInfo public insuranceFundInfo;

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

    function processLiquidationFee(
        uint24 mmRatio,
        uint24 liquidatorRewardRatio,
        uint256 exchangedQuote
    ) external {
        (uint256 liquidatorReward, uint256 insuranceFundReward) =
            TakerLibrary.processLiquidationFee(
                accountInfo.vaultInfo,
                liquidatorVaultInfo,
                insuranceFundInfo,
                mmRatio,
                liquidatorRewardRatio,
                exchangedQuote
            );
        emit ProcessLiquidationFeeResult(liquidatorReward, insuranceFundReward);
    }

    function validateSlippage(
        bool isExactInput,
        uint256 oppositeAmount,
        uint256 oppositeAmountBound
    ) external pure {
        TakerLibrary.validateSlippage(isExactInput, oppositeAmount, oppositeAmountBound);
    }

    function setAccountInfo(PerpdexStructs.VaultInfo memory value, address[] memory markets) external {
        accountInfo.vaultInfo = value;
        accountInfo.markets = markets;
    }

    function setLiquidatorVaultInfo(PerpdexStructs.VaultInfo memory value) external {
        liquidatorVaultInfo = value;
    }

    function setTakerInfo(address market, PerpdexStructs.TakerInfo memory value) external {
        accountInfo.takerInfos[market] = value;
    }

    function getTakerInfo(address market) external view returns (PerpdexStructs.TakerInfo memory) {
        return accountInfo.takerInfos[market];
    }
}
