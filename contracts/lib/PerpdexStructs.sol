// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

library PerpdexStructs {
    struct TakerInfo {
        int256 baseBalanceShare;
        int256 quoteBalance;
    }

    struct MakerInfo {
        uint256 baseDebtShare;
        uint256 quoteDebt;
        uint256 liquidity;
    }

    struct VaultInfo {
        int256 collateralBalance;
    }

    struct AccountInfo {
        // base token
        mapping(address => TakerInfo) takerInfo;
        // base token
        mapping(address => MakerInfo) makerInfo;
        VaultInfo vaultInfo;
        address[] baseTokens;
    }

    struct InsuranceFundInfo {
        int256 balance;
    }

    struct PriceLimitInfo {
        uint256 referencePrice;
        uint256 referenceTimestamp;
    }

    struct PriceLimitConfig {
        uint24 priceLimitNormalOrderRatio;
        uint24 priceLimitLiquidationRatio;
    }
}
