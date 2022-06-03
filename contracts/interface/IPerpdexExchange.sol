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
        address indexed trader,
        address indexed market,
        uint256 positionNotional,
        uint256 positionSize,
        uint256 liquidationFee,
        address liquidator
    );

    event LiquidityChanged(address indexed maker, address indexed market, int256 base, int256 quote, int256 liquidity);

    event PositionChanged(
        address indexed trader,
        address indexed market,
        int256 exchangedPositionSize,
        int256 exchangedPositionNotional,
        int256 openNotional,
        int256 realizedPnl,
        uint256 priceAfterX96
    );

    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function transferInsuranceFund(uint256 amount) external;

    function transferProtocolFee(uint256 amount) external;

    function addLiquidity(AddLiquidityParams calldata params) external returns (AddLiquidityResponse memory);

    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        returns (RemoveLiquidityResponse memory response);

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

    function openPositionDry(OpenPositionParams calldata params, address trader)
        external view returns (int256 base, int256 quote);

    // default getters

    function accountInfos(address trader) external view returns (PerpdexStructs.VaultInfo memory);

    function priceLimitInfos(address market) external view returns (uint256 referencePrice, uint256 referenceTimestamp);

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

    // convenient getters

    function getTotalAccountValue(address trader) external view returns (int256);

    function getPositionSize(address trader, address market) external view returns (int256);

    function getPositionNotional(address trader, address market) external view returns (int256);

    function getTotalPositionNotional(address trader) external view returns (uint256);

    function getOpenPositionSize(address trader, address market) external view returns (uint256);

    function getOpenPositionNotional(address trader, address market) external view returns (uint256);

    function getTotalOpenPositionNotional(address trader) external view returns (uint256);

    function hasEnoughMaintenanceMargin(address trader) external view returns (bool);

    function hasEnoughInitialMargin(address trader) external view returns (bool);
}
