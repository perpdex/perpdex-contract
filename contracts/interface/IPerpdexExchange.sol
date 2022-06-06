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
        address trader;
        address market;
        uint256 liquidity;
        uint256 minBase;
        uint256 minQuote;
        uint256 deadline;
    }

    struct OpenPositionParams {
        address trader;
        address market;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
    }

    struct OpenPositionDryParams {
        address trader;
        address market;
        address caller;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
    }

    event Deposited(address indexed trader, uint256 amount);
    event Withdrawn(address indexed trader, uint256 amount);
    event InsuranceFundTransferred(address indexed trader, uint256 amount);
    event ProtocolFeeTransferred(address indexed trader, uint256 amount);

    event LiquidityAdded(
        address indexed trader,
        address indexed market,
        uint256 base,
        uint256 quote,
        uint256 liquidity,
        uint256 baseBalancePerShareX96,
        uint256 sharePriceAfterX96
    );

    event LiquidityRemoved(
        address indexed trader,
        address indexed market,
        address liquidator,
        uint256 base,
        uint256 quote,
        uint256 liquidity,
        int256 takerBase,
        int256 takerQuote,
        int256 realizedPnl,
        uint256 baseBalancePerShareX96,
        uint256 sharePriceAfterX96
    );

    event PositionLiquidated(
        address indexed trader,
        address indexed market,
        address indexed liquidator,
        int256 base,
        int256 quote,
        int256 realizedPnl,
        uint256 protocolFee,
        uint256 baseBalancePerShareX96,
        uint256 sharePriceAfterX96,
        uint256 liquidationReward,
        uint256 insuranceFundReward
    );

    event PositionChanged(
        address indexed trader,
        address indexed market,
        int256 base,
        int256 quote,
        int256 realizedPnl,
        uint256 protocolFee,
        uint256 baseBalancePerShareX96,
        uint256 sharePriceAfterX96
    );

    event PriceLimitConfigChanged(uint24 normalOrderRatio, uint24 liquidationRatio);
    event MaxMarketsPerAccountChanged(uint8 value);
    event ImRatioChanged(uint24 value);
    event MmRatioChanged(uint24 value);
    event LiquidationRewardRatioChanged(uint24 value);
    event ProtocolFeeRatioChanged(uint24 value);
    event IsMarketAllowedChanged(address indexed market, bool isMarketAllowed);

    function deposit(uint256 amount) external payable;

    function withdraw(uint256 amount) external;

    function transferInsuranceFund(uint256 amount) external;

    function transferProtocolFee(uint256 amount) external;

    function addLiquidity(AddLiquidityParams calldata params)
        external
        returns (
            uint256 base,
            uint256 quote,
            uint256 liquidity
        );

    function removeLiquidity(RemoveLiquidityParams calldata params) external returns (uint256 base, uint256 quote);

    function openPosition(OpenPositionParams calldata params) external returns (int256 base, int256 quote);

    // setters

    function setPriceLimitConfig(PerpdexStructs.PriceLimitConfig calldata value) external;

    function setMaxMarketsPerAccount(uint8 value) external;

    function setImRatio(uint24 value) external;

    function setMmRatio(uint24 value) external;

    function setLiquidationRewardRatio(uint24 value) external;

    function setProtocolFeeRatio(uint24 value) external;

    function setIsMarketAllowed(address market, bool value) external;

    // dry run getters

    function openPositionDry(OpenPositionDryParams calldata params) external view returns (int256 base, int256 quote);

    // default getters

    function accountInfos(address trader) external view returns (PerpdexStructs.VaultInfo memory);

    function priceLimitInfos(address market)
        external
        view
        returns (uint256 referencePrice, uint256 referenceBlockNumber);

    function insuranceFundInfo() external view returns (int256 balance);

    function protocolInfo() external view returns (uint256 protocolFee);

    function settlementToken() external view returns (address);

    function priceLimitConfig() external view returns (uint24 normalOrderRatio, uint24 liquidationRatio);

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
