// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IClearingHousePerpdexNew } from "./interface/IClearingHousePerpdexNew.sol";
import { PerpdexStructs } from "./lib/PerpdexStructs.sol";
import { AccountLibrary } from "./lib/AccountLibrary.sol";
import { MakerLibrary } from "./lib/MakerLibrary.sol";
import { TakerLibrary } from "./lib/TakerLibrary.sol";
import { VaultLibrary } from "./lib/VaultLibrary.sol";
import { PerpMath } from "./lib/PerpMath.sol";
import { PerpSafeCast } from "./lib/PerpSafeCast.sol";

contract ClearingHousePerpdexNew is IClearingHousePerpdexNew, ReentrancyGuard, Ownable {
    using Address for address;
    using PerpMath for uint256;
    using PerpSafeCast for uint256;

    // states
    // trader
    mapping(address => PerpdexStructs.AccountInfo) public accountInfos;
    // market
    mapping(address => PerpdexStructs.PriceLimitInfo) public priceLimitInfos;
    PerpdexStructs.InsuranceFundInfo public insuranceFundInfo;

    // config
    address public immutable settlementToken;
    PerpdexStructs.PriceLimitConfig public priceLimitConfig;
    uint8 public maxMarketsPerAccount;
    uint24 public imRatio;
    uint24 public mmRatio;
    uint24 public liquidationRewardRatio;
    uint24 public maxFundingRateRatio;
    mapping(address => bool) public isMarketAllowed;

    //
    // MODIFIER
    //

    //
    // EXTERNAL NON-VIEW
    //

    constructor(address settlementTokenArg) {
        // CH_SANC: Settlement token address is not contract
        require(settlementTokenArg.isContract(), "CH_SANC");

        settlementToken = settlementTokenArg;

        priceLimitConfig.priceLimitLiquidationRatio = 10e4;
        priceLimitConfig.priceLimitLiquidationRatio = 5e4;
        maxMarketsPerAccount = 16;
        imRatio = 10e4;
        mmRatio = 5e4;
        liquidationRewardRatio = 20e4;
        maxFundingRateRatio = 5e4;
    }

    function deposit(uint256 amount) external override nonReentrant {
        address trader = _msgSender();
        VaultLibrary.deposit(
            accountInfos[trader],
            VaultLibrary.DepositParams({ settlementToken: settlementToken, amount: amount, from: trader })
        );
    }

    function withdraw(uint256 amount) external override nonReentrant {
        address trader = _msgSender();
        VaultLibrary.withdraw(
            accountInfos[trader],
            VaultLibrary.WithdrawParams({
                settlementToken: settlementToken,
                amount: amount,
                to: trader,
                imRatio: imRatio
            })
        );
    }

    /// @inheritdoc IClearingHousePerpdexNew
    function openPosition(OpenPositionParams calldata params)
        external
        override
        nonReentrant
        returns (int256 base, int256 quote)
    {
        address trader = _msgSender();

        TakerLibrary.OpenPositionResponse memory response =
            TakerLibrary.openPosition(
                accountInfos[trader],
                priceLimitInfos[params.market],
                TakerLibrary.OpenPositionParams({
                    market: params.market,
                    isBaseToQuote: params.isBaseToQuote,
                    isExactInput: params.isExactInput,
                    amount: params.amount,
                    oppositeAmountBound: params.oppositeAmountBound,
                    deadline: params.deadline,
                    priceLimitConfig: priceLimitConfig,
                    isMarketAllowed: isMarketAllowed[params.market],
                    mmRatio: mmRatio,
                    imRatio: imRatio,
                    maxMarketsPerAccount: maxMarketsPerAccount
                })
            );

        emit PositionChanged(
            trader,
            params.market,
            response.exchangedBase,
            response.exchangedQuote,
            accountInfos[trader].takerInfo[params.market].quoteBalance,
            response.realizedPnL,
            response.priceAfterX96
        );

        return (response.exchangedBase, response.exchangedQuote);
    }

    /// @inheritdoc IClearingHousePerpdexNew
    function liquidate(LiquidateParams calldata params)
        external
        override
        nonReentrant
        returns (int256 base, int256 quote)
    {
        address trader = params.trader;
        address liquidator = _msgSender();

        TakerLibrary.LiquidateResponse memory response =
            TakerLibrary.liquidate(
                accountInfos[trader],
                accountInfos[liquidator],
                priceLimitInfos[params.market],
                insuranceFundInfo,
                TakerLibrary.LiquidateParams({
                    market: params.market,
                    amount: params.amount,
                    oppositeAmountBound: params.oppositeAmountBound,
                    deadline: params.deadline,
                    priceLimitConfig: priceLimitConfig,
                    mmRatio: mmRatio,
                    liquidationRewardRatio: liquidationRewardRatio,
                    maxMarketsPerAccount: maxMarketsPerAccount
                })
            );

        emit PositionChanged(
            trader,
            params.market,
            response.exchangedBase,
            response.exchangedQuote,
            accountInfos[trader].takerInfo[params.market].quoteBalance,
            response.realizedPnL,
            response.priceAfterX96
        );

        return (response.exchangedBase, response.exchangedQuote);
    }

    /// @inheritdoc IClearingHousePerpdexNew
    function addLiquidity(AddLiquidityParams calldata params)
        external
        override
        nonReentrant
        returns (AddLiquidityResponse memory)
    {
        address maker = _msgSender();

        MakerLibrary.AddLiquidityResponse memory response =
            MakerLibrary.addLiquidity(
                accountInfos[maker],
                MakerLibrary.AddLiquidityParams({
                    market: params.market,
                    base: params.base,
                    quote: params.quote,
                    minBase: params.minBase,
                    minQuote: params.minQuote,
                    deadline: params.deadline,
                    isMarketAllowed: isMarketAllowed[params.market],
                    imRatio: imRatio,
                    maxMarketsPerAccount: maxMarketsPerAccount
                })
            );

        emit LiquidityChanged(
            maker,
            params.market,
            response.base.toInt256(),
            response.quote.toInt256(),
            response.liquidity.toInt256()
        );

        return AddLiquidityResponse({ base: response.base, quote: response.quote, liquidity: response.liquidity });
    }

    /// @inheritdoc IClearingHousePerpdexNew
    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        override
        returns (RemoveLiquidityResponse memory)
    {
        return removeLiquidity(params, _msgSender());
    }

    /// @inheritdoc IClearingHousePerpdexNew
    function removeLiquidity(RemoveLiquidityParams calldata params, address maker)
        public
        override
        nonReentrant
        returns (RemoveLiquidityResponse memory)
    {
        MakerLibrary.RemoveLiquidityResponse memory response =
            MakerLibrary.removeLiquidity(
                accountInfos[maker],
                MakerLibrary.RemoveLiquidityParams({
                    market: params.market,
                    liquidity: params.liquidity,
                    minBase: params.minBase,
                    minQuote: params.minQuote,
                    deadline: params.deadline,
                    makerIsSender: maker == _msgSender(),
                    mmRatio: mmRatio,
                    maxMarketsPerAccount: maxMarketsPerAccount
                })
            );

        emit LiquidityChanged(
            maker,
            params.market,
            response.base.neg256(),
            response.quote.neg256(),
            params.liquidity.neg256()
        );

        emit PositionChanged(
            maker,
            params.market,
            response.takerBase, // exchangedPositionSize
            response.takerQuote, // exchangedPositionNotional
            accountInfos[maker].takerInfo[params.market].quoteBalance,
            response.realizedPnL, // realizedPnl
            response.priceAfterX96
        );

        return RemoveLiquidityResponse({ base: response.base, quote: response.quote });
    }

    function setPriceLimitConfig(PerpdexStructs.PriceLimitConfig calldata value)
        external
        override
        onlyOwner
        nonReentrant
    {
        priceLimitConfig = value;
    }

    function setMaxMarketsPerAccount(uint8 value) external override onlyOwner nonReentrant {
        maxMarketsPerAccount = value;
    }

    function setImRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value < 1e6);
        require(value >= mmRatio);
        imRatio = value;
    }

    function setMmRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value <= imRatio);
        require(value > 0);
        mmRatio = value;
    }

    function setLiquidationRewardRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value < 1e6);
        liquidationRewardRatio = value;
    }

    function setMaxFundingRateRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value < 1e6);
        maxFundingRateRatio = value;
    }

    function setIsMarketAllowed(address market, bool value) external override onlyOwner nonReentrant {
        isMarketAllowed[market] = value;
    }

    //
    // EXTERNAL VIEW
    //

    // all raw information can be retrieved through getters (including default getters)

    function getTakerInfo(address trader, address market) external returns (PerpdexStructs.TakerInfo memory) {
        return accountInfos[trader].takerInfo[market];
    }

    function getMakerInfo(address trader, address market) external returns (PerpdexStructs.MakerInfo memory) {
        return accountInfos[trader].makerInfo[market];
    }

    function getAccountMarkets(address trader) external returns (address[] memory) {
        return accountInfos[trader].markets;
    }

    // convenient getters

    function getTotalAccountValue(address trader) external view override returns (int256) {
        return AccountLibrary.getTotalAccountValue(accountInfos[trader]);
    }

    function getPositionSize(address trader, address market) external view override returns (int256) {
        return AccountLibrary.getPositionSize(accountInfos[trader], market);
    }

    function getPositionNotional(address trader, address market) external view override returns (int256) {
        return AccountLibrary.getPositionNotional(accountInfos[trader], market);
    }

    function getTotalPositionNotional(address trader) external view override returns (uint256) {
        return AccountLibrary.getTotalPositionNotional(accountInfos[trader]);
    }

    function getOpenPositionSize(address trader, address market) external view override returns (uint256) {
        return AccountLibrary.getOpenPositionSize(accountInfos[trader], market);
    }

    function getOpenPositionNotional(address trader, address market) external view override returns (uint256) {
        return AccountLibrary.getOpenPositionNotional(accountInfos[trader], market);
    }

    function getTotalOpenPositionNotional(address trader) external view override returns (uint256) {
        return AccountLibrary.getTotalOpenPositionNotional(accountInfos[trader]);
    }

    function hasEnoughMaintenanceMargin(address trader) external view override returns (bool) {
        return AccountLibrary.hasEnoughMaintenanceMargin(accountInfos[trader], mmRatio);
    }

    function hasEnoughInitialMargin(address trader) external view override returns (bool) {
        return AccountLibrary.hasEnoughInitialMargin(accountInfos[trader], imRatio);
    }
}
