// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IPerpdexExchange } from "./interface/IPerpdexExchange.sol";
import { IPerpdexMarket } from "./interface/IPerpdexMarket.sol";
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
        PerpdexStructs.PriceLimitConfig({ normalOrderRatio: 5e4, liquidationRatio: 10e4 });
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
        TakerLibrary.OpenPositionResponse memory response =
            TakerLibrary.openPosition(
                accountInfos[params.trader],
                accountInfos[_msgSender()].vaultInfo,
                insuranceFundInfo,
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
                    protocolFeeRatio: protocolFeeRatio,
                    liquidationRewardRatio: liquidationRewardRatio,
                    isSelf: params.trader == _msgSender()
                })
            );

        if (response.isLiquidation) {
            emit PositionLiquidated(
                params.trader,
                params.market,
                _msgSender(),
                response.base,
                response.quote,
                response.realizedPnl,
                response.protocolFee,
                IPerpdexMarket(params.market).baseBalancePerShareX96(),
                response.priceAfterX96,
                response.liquidationReward,
                response.insuranceFundReward
            );
        } else {
            emit PositionChanged(
                params.trader,
                params.market,
                response.base,
                response.quote,
                response.realizedPnl,
                response.protocolFee,
                IPerpdexMarket(params.market).baseBalancePerShareX96(),
                response.priceAfterX96
            );
        }

        return (response.base, response.quote);
    }

    function addLiquidity(AddLiquidityParams calldata params)
        external
        override
        nonReentrant
        checkDeadline(params.deadline)
        returns (
            uint256 base,
            uint256 quote,
            uint256 liquidity
        )
    {
        address trader = _msgSender();

        MakerLibrary.AddLiquidityResponse memory response =
            MakerLibrary.addLiquidity(
                accountInfos[trader],
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

        emit LiquidityAdded(
            trader,
            params.market,
            response.base,
            response.quote,
            response.liquidity,
            IPerpdexMarket(params.market).baseBalancePerShareX96(),
            IPerpdexMarket(params.market).getMarkPriceX96()
        );

        return (response.base, response.quote, response.liquidity);
    }

    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        override
        nonReentrant
        checkDeadline(params.deadline)
        returns (uint256 base, uint256 quote)
    {
        MakerLibrary.RemoveLiquidityResponse memory response =
            MakerLibrary.removeLiquidity(
                accountInfos[params.trader],
                MakerLibrary.RemoveLiquidityParams({
                    market: params.market,
                    liquidity: params.liquidity,
                    minBase: params.minBase,
                    minQuote: params.minQuote,
                    isSelf: params.trader == _msgSender(),
                    mmRatio: mmRatio,
                    maxMarketsPerAccount: maxMarketsPerAccount
                })
            );

        emit LiquidityRemoved(
            params.trader,
            params.market,
            response.isLiquidation ? _msgSender() : address(0),
            response.base,
            response.quote,
            params.liquidity,
            response.takerBase,
            response.takerQuote,
            response.realizedPnl,
            IPerpdexMarket(params.market).baseBalancePerShareX96(),
            IPerpdexMarket(params.market).getMarkPriceX96()
        );

        return (response.base, response.quote);
    }

    function setPriceLimitConfig(PerpdexStructs.PriceLimitConfig calldata value)
        external
        override
        onlyOwner
        nonReentrant
    {
        require(value.liquidationRatio <= 5e5, "PE_SPLC: too large liquidation");
        require(value.normalOrderRatio <= value.liquidationRatio, "PE_SPLC: invalid");
        priceLimitConfig = value;
        emit PriceLimitConfigChanged(value.normalOrderRatio, value.liquidationRatio);
    }

    function setMaxMarketsPerAccount(uint8 value) external override onlyOwner nonReentrant {
        maxMarketsPerAccount = value;
        emit MaxMarketsPerAccountChanged(value);
    }

    function setImRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value < 1e6, "PE_SIR: too large");
        require(value >= mmRatio, "PE_SIR: smaller than mmRatio");
        imRatio = value;
        emit ImRatioChanged(value);
    }

    function setMmRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value <= imRatio, "PE_SMR: bigger than imRatio");
        require(value > 0, "PE_SMR: zero");
        mmRatio = value;
        emit MmRatioChanged(value);
    }

    function setLiquidationRewardRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value < 1e6, "PE_SLRR: too large");
        liquidationRewardRatio = value;
        emit LiquidationRewardRatioChanged(value);
    }

    function setProtocolFeeRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value <= 1e4, "PE_SPFR: too large");
        protocolFeeRatio = value;
        emit ProtocolFeeRatioChanged(value);
    }

    function setIsMarketAllowed(address market, bool value) external override onlyOwner nonReentrant {
        require(market.isContract(), "PE_SIMA: market address invalid");
        isMarketAllowed[market] = value;
        emit IsMarketAllowedChanged(market, value);
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

    function openPositionDry(OpenPositionDryParams calldata params)
        external
        view
        override
        returns (int256 base, int256 quote)
    {
        address trader = params.trader;
        address caller = params.caller;

        return
            TakerLibrary.openPositionDry(
                accountInfos[trader],
                TakerLibrary.OpenPositionDryParams({
                    market: params.market,
                    isBaseToQuote: params.isBaseToQuote,
                    isExactInput: params.isExactInput,
                    amount: params.amount,
                    oppositeAmountBound: params.oppositeAmountBound,
                    mmRatio: mmRatio,
                    protocolFeeRatio: protocolFeeRatio,
                    isSelf: trader == caller
                })
            );
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
