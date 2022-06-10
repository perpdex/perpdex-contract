// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.6;

library PerpdexStructs {
    struct TakerInfo {
        int256 baseBalanceShare;
        int256 quoteBalance;
    }

    struct MakerInfo {
        int256 baseDebtShare;
        int256 quoteDebt;
        uint256 liquidity;
        uint256 cumBaseSharePerLiquidityX96;
        uint256 cumQuotePerLiquidityX96;
    }

    struct VaultInfo {
        int256 collateralBalance;
    }

    struct AccountInfo {
        // market
        mapping(address => TakerInfo) takerInfos;
        // market
        mapping(address => MakerInfo) makerInfos;
        VaultInfo vaultInfo;
        address[] markets;
    }

    struct InsuranceFundInfo {
        int256 balance;
        uint256 liquidationRewardBalance;
    }

    struct ProtocolInfo {
        uint256 protocolFee;
    }

    struct LiquidationRewardConfig {
        uint24 rewardRatio;
        uint16 smoothEmaTime;
    }
}
