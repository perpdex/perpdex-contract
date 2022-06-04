// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IPerpdexExchange } from "./interface/IPerpdexExchange.sol";
import { PerpdexStructs } from "./lib/PerpdexStructs.sol";
import { AccountLibrary } from "./lib/AccountLibrary.sol";
import { MakerLibrary } from "./lib/MakerLibrary.sol";
import { TakerLibrary } from "./lib/TakerLibrary.sol";
import { VaultLibrary } from "./lib/VaultLibrary.sol";
import { PerpMath } from "./lib/PerpMath.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";

contract PerpdexExchange is IPerpdexExchange, ReentrancyGuard, Ownable {
    using Address for address;
    using PerpMath for uint256;
    using SafeCast for uint256;

    // states
    // trader
    mapping(address => PerpdexStructs.AccountInfo) public override accountInfos;
    // market
    mapping(address => PerpdexStructs.PriceLimitInfo) public override priceLimitInfos;
    PerpdexStructs.InsuranceFundInfo public override insuranceFundInfo;
    PerpdexStructs.ProtocolInfo public override protocolInfo;

    // config
    address public immutable override settlementToken;
    PerpdexStructs.PriceLimitConfig public override priceLimitConfig =
        PerpdexStructs.PriceLimitConfig({ priceLimitNormalOrderRatio: 5e4, priceLimitLiquidationRatio: 10e4 });
    uint8 public override maxMarketsPerAccount = 16;
    uint24 public override imRatio = 10e4;
    uint24 public override mmRatio = 5e4;
    uint24 public override liquidationRewardRatio = 20e4;
    uint24 public override protocolFeeRatio = 0;
    mapping(address => bool) public override isMarketAllowed;

    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, "PE_CD: too late");
        _;
    }

    constructor(address settlementTokenArg) {
        require(settlementTokenArg == address(0) || settlementTokenArg.isContract(), "PE_C: token address invalid");

        settlementToken = settlementTokenArg;
    }

    function deposit(uint256 amount) external payable override nonReentrant {
        address trader = _msgSender();

        if (settlementToken == address(0)) {
            require(amount == 0, "PE_D: amount not zero");
            VaultLibrary.depositEth(accountInfos[trader], msg.value);
            emit Deposited(trader, msg.value);
        } else {
            require(msg.value == 0, "PE_D: msg.value not zero");
            VaultLibrary.deposit(
                accountInfos[trader],
                VaultLibrary.DepositParams({ settlementToken: settlementToken, amount: amount, from: trader })
            );
            emit Deposited(trader, amount);
        }
    }

    function withdraw(uint256 amount) external override nonReentrant {
        address payable trader = _msgSender();

        VaultLibrary.withdraw(
            accountInfos[trader],
            VaultLibrary.WithdrawParams({
                settlementToken: settlementToken,
                amount: amount,
                to: trader,
                imRatio: imRatio
            })
        );
        emit Withdrawn(trader, amount);
    }

    function transferInsuranceFund(uint256 amount) external override onlyOwner nonReentrant {
        address trader = _msgSender();
        VaultLibrary.transferInsuranceFund(accountInfos[trader], insuranceFundInfo, amount);
        emit InsuranceFundTransferred(trader, amount);
    }

    function transferProtocolFee(uint256 amount) external override onlyOwner nonReentrant {
        address trader = _msgSender();
        VaultLibrary.transferProtocolFee(accountInfos[trader], protocolInfo, amount);
        emit ProtocolFeeTransferred(trader, amount);
    }

    function openPosition(OpenPositionParams calldata params)
        external
        override
        nonReentrant
        checkDeadline(params.deadline)
        returns (int256 base, int256 quote)
    {
        address trader = _msgSender();

        TakerLibrary.OpenPositionResponse memory response =
            TakerLibrary.openPosition(
                accountInfos[trader],
                priceLimitInfos[params.market],
                protocolInfo,
                TakerLibrary.OpenPositionParams({
                    market: params.market,
                    isBaseToQuote: params.isBaseToQuote,
                    isExactInput: params.isExactInput,
                    amount: params.amount,
                    oppositeAmountBound: params.oppositeAmountBound,
                    priceLimitConfig: priceLimitConfig,
                    isMarketAllowed: isMarketAllowed[params.market],
                    mmRatio: mmRatio,
                    imRatio: imRatio,
                    maxMarketsPerAccount: maxMarketsPerAccount,
                    protocolFeeRatio: protocolFeeRatio
                })
            );

        emit PositionChanged(
            trader,
            params.market,
            response.exchangedBase,
            response.exchangedQuote,
            accountInfos[trader].takerInfos[params.market].quoteBalance,
            response.realizedPnL,
            response.priceAfterX96
        );

        return (response.exchangedBase, response.exchangedQuote);
    }

    function liquidate(LiquidateParams calldata params)
        external
        override
        nonReentrant
        checkDeadline(params.deadline)
        returns (int256 base, int256 quote)
    {
        address trader = params.trader;
        address liquidator = _msgSender();

        TakerLibrary.LiquidateResponse memory response =
            TakerLibrary.liquidate(
                accountInfos[trader],
                accountInfos[liquidator],
                priceLimitInfos[params.market],
                protocolInfo,
                insuranceFundInfo,
                TakerLibrary.LiquidateParams({
                    market: params.market,
                    amount: params.amount,
                    oppositeAmountBound: params.oppositeAmountBound,
                    priceLimitConfig: priceLimitConfig,
                    mmRatio: mmRatio,
                    liquidationRewardRatio: liquidationRewardRatio,
                    maxMarketsPerAccount: maxMarketsPerAccount,
                    protocolFeeRatio: protocolFeeRatio
                })
            );

        emit PositionChanged(
            trader,
            params.market,
            response.exchangedBase,
            response.exchangedQuote,
            accountInfos[trader].takerInfos[params.market].quoteBalance,
            response.realizedPnL,
            response.priceAfterX96
        );

        return (response.exchangedBase, response.exchangedQuote);
    }

    function addLiquidity(AddLiquidityParams calldata params)
        external
        override
        nonReentrant
        checkDeadline(params.deadline)
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

    function removeLiquidity(RemoveLiquidityParams calldata params, address maker)
        external
        override
        nonReentrant
        checkDeadline(params.deadline)
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
            accountInfos[maker].takerInfos[params.market].quoteBalance,
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
        require(value.priceLimitLiquidationRatio <= 5e5, "PE_SPLC: too large liquidation");
        require(value.priceLimitNormalOrderRatio <= value.priceLimitLiquidationRatio, "PE_SPLC: invalid");
        priceLimitConfig = value;
    }

    function setMaxMarketsPerAccount(uint8 value) external override onlyOwner nonReentrant {
        maxMarketsPerAccount = value;
    }

    function setImRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value < 1e6, "PE_SIR: too large");
        require(value >= mmRatio, "PE_SIR: smaller than mmRatio");
        imRatio = value;
    }

    function setMmRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value <= imRatio, "PE_SMR: bigger than imRatio");
        require(value > 0, "PE_SMR: zero");
        mmRatio = value;
    }

    function setLiquidationRewardRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value < 1e6, "PE_SLRR: too large");
        liquidationRewardRatio = value;
    }

    function setProtocolFeeRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value < 1e4, "PE_SPFR: too large");
        protocolFeeRatio = value;
    }

    function setIsMarketAllowed(address market, bool value) external override onlyOwner nonReentrant {
        require(market.isContract(), "PE_SIMA: market address invalid");
        if (isMarketAllowed[market] != value) {
            isMarketAllowed[market] = value;
            emit IsMarketAllowedChanged(market, value);
        }
    }

    //
    // EXTERNAL VIEW
    //

    // all raw information can be retrieved through getters (including default getters)

    function getTakerInfo(address trader, address market)
        external
        view
        override
        returns (PerpdexStructs.TakerInfo memory)
    {
        return accountInfos[trader].takerInfos[market];
    }

    function getMakerInfo(address trader, address market)
        external
        view
        override
        returns (PerpdexStructs.MakerInfo memory)
    {
        return accountInfos[trader].makerInfos[market];
    }

    function getAccountMarkets(address trader) external view override returns (address[] memory) {
        return accountInfos[trader].markets;
    }

    // dry run

    function openPositionDry(OpenPositionDryParams calldata params, address trader)
        external
        view
        override
        returns (int256 base, int256 quote)
    {
        TakerLibrary.OpenPositionResponse memory response =
            TakerLibrary.openPositionDry(
                accountInfos[trader],
                priceLimitInfos[params.market],
                TakerLibrary.OpenPositionParams({
                    market: params.market,
                    isBaseToQuote: params.isBaseToQuote,
                    isExactInput: params.isExactInput,
                    amount: params.amount,
                    oppositeAmountBound: params.oppositeAmountBound,
                    priceLimitConfig: priceLimitConfig,
                    isMarketAllowed: isMarketAllowed[params.market],
                    mmRatio: mmRatio,
                    imRatio: imRatio,
                    maxMarketsPerAccount: maxMarketsPerAccount,
                    protocolFeeRatio: protocolFeeRatio
                })
            );

        return (response.exchangedBase, response.exchangedQuote);
    }

    // convenient getters

    function getTotalAccountValue(address trader) external view override returns (int256) {
        return AccountLibrary.getTotalAccountValue(accountInfos[trader]);
    }

    function getPositionShare(address trader, address market) external view override returns (int256) {
        return AccountLibrary.getPositionShare(accountInfos[trader], market);
    }

    function getPositionNotional(address trader, address market) external view override returns (int256) {
        return AccountLibrary.getPositionNotional(accountInfos[trader], market);
    }

    function getTotalPositionNotional(address trader) external view override returns (uint256) {
        return AccountLibrary.getTotalPositionNotional(accountInfos[trader]);
    }

    function getOpenPositionShare(address trader, address market) external view override returns (uint256) {
        return AccountLibrary.getOpenPositionShare(accountInfos[trader], market);
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
