// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";
import { IPerpdexExchange } from "./interface/IPerpdexExchange.sol";
import { IPerpdexMarket } from "./interface/IPerpdexMarket.sol";
import { PerpdexStructs } from "./lib/PerpdexStructs.sol";
import { AccountLibrary } from "./lib/AccountLibrary.sol";
import { MakerLibrary } from "./lib/MakerLibrary.sol";
import { TakerLibrary } from "./lib/TakerLibrary.sol";
import { VaultLibrary } from "./lib/VaultLibrary.sol";
import { PerpMath } from "./lib/PerpMath.sol";

contract PerpdexExchange is IPerpdexExchange, ReentrancyGuard, Ownable {
    using Address for address;
    using PerpMath for int256;
    using PerpMath for uint256;
    using SafeCast for uint256;

    // states
    // trader
    mapping(address => PerpdexStructs.AccountInfo) public override accountInfos;
    PerpdexStructs.InsuranceFundInfo public override insuranceFundInfo;
    PerpdexStructs.ProtocolInfo public override protocolInfo;

    // config
    address public immutable override settlementToken;
    uint8 public constant override decimals = 18;
    uint8 public override maxMarketsPerAccount = 16;
    uint24 public override imRatio = 10e4;
    uint24 public override mmRatio = 5e4;
    uint24 public override protocolFeeRatio = 0;
    PerpdexStructs.LiquidationRewardConfig public override liquidationRewardConfig =
        PerpdexStructs.LiquidationRewardConfig({ rewardRatio: 20e4, smoothEmaTime: 100 });
    mapping(address => bool) public override isMarketAllowed;

    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, "PE_CD: too late");
        _;
    }

    modifier checkMarketAllowed(address market) {
        require(isMarketAllowed[market], "PE_CMA: market not allowed");
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
        checkMarketAllowed(params.market)
        returns (uint256 oppositeAmount)
    {
        TakerLibrary.OpenPositionResponse memory response = _doOpenPosition(params);

        uint256 baseBalancePerShareX96 = IPerpdexMarket(params.market).baseBalancePerShareX96();
        uint256 shareMarkPriceAfterX96 = IPerpdexMarket(params.market).getShareMarkPriceX96();

        if (response.isLiquidation) {
            emit PositionLiquidated(
                params.trader,
                params.market,
                _msgSender(),
                response.base,
                response.quote,
                response.realizedPnl,
                response.protocolFee,
                baseBalancePerShareX96,
                shareMarkPriceAfterX96,
                response.liquidationPenalty,
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
                baseBalancePerShareX96,
                shareMarkPriceAfterX96
            );
        }

        oppositeAmount = params.isExactInput == params.isBaseToQuote ? response.quote.abs() : response.base.abs();
    }

    function addLiquidity(AddLiquidityParams calldata params)
        external
        override
        nonReentrant
        checkDeadline(params.deadline)
        checkMarketAllowed(params.market)
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
                    imRatio: imRatio,
                    maxMarketsPerAccount: maxMarketsPerAccount
                })
            );

        uint256 baseBalancePerShareX96 = IPerpdexMarket(params.market).baseBalancePerShareX96();
        uint256 shareMarkPriceAfterX96 = IPerpdexMarket(params.market).getShareMarkPriceX96();

        emit LiquidityAdded(
            trader,
            params.market,
            response.base,
            response.quote,
            response.liquidity,
            baseBalancePerShareX96,
            shareMarkPriceAfterX96
        );

        return (response.base, response.quote, response.liquidity);
    }

    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        override
        nonReentrant
        checkDeadline(params.deadline)
        checkMarketAllowed(params.market)
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

        uint256 baseBalancePerShareX96;

        {
            baseBalancePerShareX96 = IPerpdexMarket(params.market).baseBalancePerShareX96();
        }

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
            baseBalancePerShareX96,
            response.shareMarkPriceAfterX96
        );

        return (response.base, response.quote);
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

    function setLiquidationRewardConfig(PerpdexStructs.LiquidationRewardConfig calldata value)
        external
        override
        onlyOwner
        nonReentrant
    {
        require(value.rewardRatio < 1e6, "PE_SLRC: too large reward ratio");
        require(value.smoothEmaTime > 0, "PE_SLRC: ema time is zero");
        liquidationRewardConfig = value;
        emit LiquidationRewardConfigChanged(value.rewardRatio, value.smoothEmaTime);
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

    function previewOpenPosition(PreviewOpenPositionParams calldata params)
        external
        view
        override
        checkMarketAllowed(params.market)
        returns (uint256 oppositeAmount)
    {
        address trader = params.trader;
        address caller = params.caller;

        return
            TakerLibrary.previewOpenPosition(
                accountInfos[trader],
                TakerLibrary.PreviewOpenPositionParams({
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

    function maxOpenPosition(MaxOpenPositionParams calldata params) external view override returns (uint256 amount) {
        if (!isMarketAllowed[params.market]) return 0;

        address trader = params.trader;
        address caller = params.caller;

        return
            TakerLibrary.maxOpenPosition({
                accountInfo: accountInfos[trader],
                market: params.market,
                isBaseToQuote: params.isBaseToQuote,
                isExactInput: params.isExactInput,
                mmRatio: mmRatio,
                protocolFeeRatio: protocolFeeRatio,
                isSelf: trader == caller
            });
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

    // for avoiding stack too deep error
    function _doOpenPosition(OpenPositionParams calldata params)
        private
        returns (TakerLibrary.OpenPositionResponse memory)
    {
        return
            TakerLibrary.openPosition(
                accountInfos[params.trader],
                accountInfos[_msgSender()].vaultInfo,
                insuranceFundInfo,
                protocolInfo,
                TakerLibrary.OpenPositionParams({
                    market: params.market,
                    isBaseToQuote: params.isBaseToQuote,
                    isExactInput: params.isExactInput,
                    amount: params.amount,
                    oppositeAmountBound: params.oppositeAmountBound,
                    mmRatio: mmRatio,
                    imRatio: imRatio,
                    maxMarketsPerAccount: maxMarketsPerAccount,
                    protocolFeeRatio: protocolFeeRatio,
                    liquidationRewardConfig: liquidationRewardConfig,
                    isSelf: params.trader == _msgSender()
                })
            );
    }
}
