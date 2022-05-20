// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

library PerpdexStructs {
    struct TakerInfo {
        int256 baseBalanceShare;
        int256 quoteBalance;
    }

    struct OrderInfo {
        int256 baseDebtShare;
        int256 quoteDebt;
        uint128 liquidity;
    }

    struct VaultInfo {
        int256 collateralBalance;
    }

    struct AccountInfo {
        // base token
        mapping(address => TakerInfo) takerInfo;
        // base token
        mapping(address => OrderInfo) orderInfo;
        VaultInfo vaultInfo;
    }

    struct InsuranceFundInfo {
        int256 balance;
    }

    struct PriceLimitInfo {
        uint256 referencePrice;
        uint256 referenceTimestamp;
    }

    struct PriceLimitConfig {
        uint256 priceLimitNormalOrderMicro;
        uint256 priceLimitLiquidationMicro;
    }
}
