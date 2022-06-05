// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.6;
pragma abicoder v2;

import { PerpdexStructs } from "../lib/PerpdexStructs.sol";

interface IPerpdexExchange {
    struct AddLiquidityParams {
        address market;
        uint256 base;
        uint256 quote;
        uint256 minBase;
        uint256 minQuote;
        uint256 deadline;
    }

    struct RemoveLiquidityParams {
        address market;
        uint256 liquidity;
        uint256 minBase;
        uint256 minQuote;
        uint256 deadline;
    }

    struct AddLiquidityResponse {
        uint256 base;
        uint256 quote;
        uint256 liquidity;
    }

    struct RemoveLiquidityResponse {
        uint256 base;
        uint256 quote;
    }

    struct OpenPositionParams {
        address market;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
    }

    struct OpenPositionDryParams {
        address market;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
    }

    struct LiquidateParams {
        address trader;
        address market;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
    }

    event Deposited(address indexed trader, uint256 amount);
    event Withdrawn(address indexed trader, uint256 amount);
    event InsuranceFundTransferred(address indexed trader, uint256 amount);
    event ProtocolFeeTransferred(address indexed trader, uint256 amount);

    event PositionLiquidated(
        address trader,
        address market,
        int256 amount,
        uint256 positionSize,
        uint256 positionNotional,
        uint256 liquidationFee,
        address liquidator,
        int256 oppositeAmountBound,
        uint256 deadline,
        uint24 priceLimitNormalOrderRatio,
        uint24 priceLimitLiquidationRatio,
        uint24 mmRatio,
        uint24 liquidationRewardRatio,
        uint8 maxMarketsPerAccount,
        uint24 protocolFeeRatio,
        bool isBaseToQuote,
        bool isExactInput,
        int256 penalty,
        int256 intliquidatorReward,
        int256 insuranceFundReward
    );

    event LiquidityChanged(
        address trader,
        address market,
        uint256 base,
        uint256 quote,
        uint256 liquidity,
        uint256 minBase,
        uint256 minQuote,
        uint256 deadline,
        uint24 imRatio,
        uint8 maxMarketsPerAccount,
        uint256 cumDeleveragedBaseSharePerLiquidityX96,
        uint256 cumDeleveragedQuotePerLiquidityX96
    );

    event PositionChanged(
        address indexed trader,
        address indexed market,
        int256 exchangedPositionSize,
        int256 exchangedPositionNotional,
        int256 openNotional,
        int256 realizedPnl,
        uint256 priceAfterX96,
        int256 tradingFee,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 oppositeAmountBound,
        uint256 deadline,
        uint8 maxMarketsPerAccount,
        uint24 protocolFeeRatio,
        uint24 priceLimitNormalOrderRatio,
        uint24 priceLimitLiquidationRatio,
        uint24 mmRatio,
        uint24 imRatio
    );

    event IsMarketAllowedChanged(address indexed market, bool isMarketAllowed);

    function deposit(uint256 amount) external payable;

    function withdraw(uint256 amount) external;

    function transferInsuranceFund(uint256 amount) external;

    function transferProtocolFee(uint256 amount) external;

    function addLiquidity(AddLiquidityParams calldata params) external returns (AddLiquidityResponse memory);

    function removeLiquidity(RemoveLiquidityParams calldata params, address maker)
        external
        returns (RemoveLiquidityResponse memory response);

    function openPosition(OpenPositionParams calldata params) external returns (int256 base, int256 quote);

    function liquidate(LiquidateParams calldata params) external returns (int256 base, int256 quote);

    // setters

    function setPriceLimitConfig(PerpdexStructs.PriceLimitConfig calldata value) external;

    function setMaxMarketsPerAccount(uint8 value) external;

    function setImRatio(uint24 value) external;

    function setMmRatio(uint24 value) external;

    function setLiquidationRewardRatio(uint24 value) external;

    function setProtocolFeeRatio(uint24 value) external;

    function setIsMarketAllowed(address market, bool value) external;

    // dry run getters

    function openPositionDry(OpenPositionDryParams calldata params, address trader)
        external
        view
        returns (int256 base, int256 quote);

    // default getters

    function accountInfos(address trader) external view returns (PerpdexStructs.VaultInfo memory);

    function priceLimitInfos(address market)
        external
        view
        returns (uint256 referencePrice, uint256 referenceBlockNumber);

    function insuranceFundInfo() external view returns (int256 balance);

    function protocolInfo() external view returns (uint256 protocolFee);

    function settlementToken() external view returns (address);

    function priceLimitConfig()
        external
        view
        returns (uint24 priceLimitNormalOrderRatio, uint24 priceLimitLiquidationRatio);

    function maxMarketsPerAccount() external view returns (uint8);

    function imRatio() external view returns (uint24);

    function mmRatio() external view returns (uint24);

    function liquidationRewardRatio() external view returns (uint24);

    function protocolFeeRatio() external view returns (uint24);

    function isMarketAllowed(address market) external view returns (bool);

    // getters not covered by default getters

    function getTakerInfo(address trader, address market) external view returns (PerpdexStructs.TakerInfo memory);

    function getMakerInfo(address trader, address market) external view returns (PerpdexStructs.MakerInfo memory);

    function getAccountMarkets(address trader) external view returns (address[] memory);

    // convenient getters

    function getTotalAccountValue(address trader) external view returns (int256);

    function getPositionShare(address trader, address market) external view returns (int256);

    function getPositionNotional(address trader, address market) external view returns (int256);

    function getTotalPositionNotional(address trader) external view returns (uint256);

    function getOpenPositionShare(address trader, address market) external view returns (uint256);

    function getOpenPositionNotional(address trader, address market) external view returns (uint256);

    function getTotalOpenPositionNotional(address trader) external view returns (uint256);

    function hasEnoughMaintenanceMargin(address trader) external view returns (bool);

    function hasEnoughInitialMargin(address trader) external view returns (bool);
}
